package com.shelfscanai.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.shelfscanai.dto.*;
import com.shelfscanai.entity.Book;
import com.shelfscanai.entity.ReadingStatus;
import com.shelfscanai.entity.UserBook;
import com.shelfscanai.repository.BookRepository;
import com.shelfscanai.repository.UserBookRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.Base64;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ScanService {

    private final BlobStorageService blobStorageService;
    private final BookRepository bookRepository;
    private final UserBookRepository userBookRepository;
    private final GeminiClient geminiClient;
    private final ObjectMapper objectMapper;
    private final Environment env;

    public ScanResponse scan(MultipartFile image, String titleHint, String authorHint, String userKey) throws Exception {
        long t0 = System.currentTimeMillis();

        try {
            if (image == null || image.isEmpty()) throw new IllegalArgumentException("Image is required");
            if (userKey == null || userKey.isBlank()) throw new IllegalArgumentException("Not authenticated");

            log.info("scan.start userKey={} titleHint='{}' authorHint='{}' filename={} size={}",
                    userKey, titleHint, authorHint,
                    image.getOriginalFilename(), image.getSize());

            String mimeType = image.getContentType() != null ? image.getContentType() : "image/jpeg";
            String base64 = Base64.getEncoder().encodeToString(image.getBytes());

            // 1) Se mi passi title+author già validi, provo subito lookup DB e potenzialmente salto Gemini
            Book book = null;
            if (notBlank(titleHint) && notBlank(authorHint)) {
                book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(titleHint.trim(), authorHint.trim())
                        .orElse(null);

                if (book != null) {
                    log.info("scan.lookup.hint.hit userKey={} bookId={} hasDesc={}",
                            userKey, book.getId(), notBlank(book.getDescription()));
                } else {
                    log.info("scan.lookup.hint.miss userKey={}", userKey);
                }

                if (book != null && notBlank(book.getDescription())) {
                    ensureUserBook(userKey, book);

                    log.info("scan.dedup.hit userKey={} bookId={} reason={} elapsedMs={}",
                            userKey, book.getId(), "hint:title+author",
                            (System.currentTimeMillis() - t0));

                    return new ScanResponse(
                            book.getId(),
                            book.getTitle(),
                            book.getAuthor(),
                            book.getCoverUrl(),
                            book.getDescription(),
                            parseTags(book.getTags())
                    );
                }
            }

            // 2) EXTRACT (1 chiamata) solo se non ho già trovato un book arricchito
            log.info("scan.gemini.extract.call userKey={} model={}", userKey, model());
            GeminiExtractDto extract = callExtractWithMaxRetry(mimeType, base64, 1);

            String extractedTitle = pickBest(titleHint, extract.title());
            String extractedAuthor = pickBest(authorHint, extract.author());

            log.info("scan.extract.done userKey={} title='{}' author='{}' conf={} notes='{}'",
                    userKey, extractedTitle, extractedAuthor, extract.confidence(), extract.notes());

            String nt = normalizeTitle(extractedTitle);

            if (notBlank(extractedTitle) && notBlank(extractedAuthor)) {
                book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(extractedTitle.trim(), extractedAuthor.trim())
                        .orElse(null);
                log.info("scan.lookup.extract.title_author userKey={} hit={}",
                        userKey, (book != null));
            } else if (nt != null) {
                // fallback dedup senza autore
                List<Book> candidates = bookRepository.findByNormalizedTitle(nt);
                if (!candidates.isEmpty()) book = candidates.getFirst();
                log.info("scan.lookup.extract.normalized userKey={} nt='{}' candidates={} hit={}",
                        userKey, nt, (candidates != null ? candidates.size() : 0), (book != null));
            } else {
                log.info("scan.lookup.extract.skip userKey={} reason=no-title", userKey);
            }

            if (book != null && notBlank(book.getDescription())) {
                ensureUserBook(userKey, book);

                log.info("scan.dedup.hit userKey={} bookId={} reason={} elapsedMs={}",
                        userKey, book.getId(), "extract:title+author|normalizedTitle",
                        (System.currentTimeMillis() - t0));

                return new ScanResponse(
                        book.getId(),
                        book.getTitle(),
                        book.getAuthor(),
                        book.getCoverUrl(),
                        book.getDescription(),
                        parseTags(book.getTags())
                );
            }

            // 3) Upload cover solo se devo creare/aggiornare
            String coverUrl = blobStorageService.upload(image);
            log.info("scan.blob.uploaded userKey={} coverUrl={}", userKey, coverUrl);

            if (book == null) {
                // creo entry minima “globale”
                book = bookRepository.save(Book.builder()
                        .normalizedTitle(normalizeTitle(extractedTitle))
                        .title(notBlank(extractedTitle) ? extractedTitle.trim() : "UNKNOWN_TITLE")
                        .author(notBlank(extractedAuthor) ? extractedAuthor.trim() : null)
                        .coverUrl(coverUrl)
                        .build());

                log.info("scan.book.created bookId={} title='{}' author='{}'",
                        book.getId(), book.getTitle(), book.getAuthor());
            } else if (book.getCoverUrl() == null) {
                book.setCoverUrl(coverUrl);
                book = bookRepository.save(book);

                log.info("scan.book.cover.updated bookId={} coverUrl={}",
                        book.getId(), book.getCoverUrl());
            } else {
                log.info("scan.book.exists bookId={} hasDesc={}",
                        book.getId(), notBlank(book.getDescription()));
            }

            // 4) PROVO PRIMA “COPY” DA UN LIBRO SIMILE GIA' ARRICCHITO (evita chiamata Gemini enrich)
            if (!notBlank(book.getDescription())) {

                Book donor = null;

                // Caso 1: autore noto -> cerco candidati arricchiti con stesso autore
                if (notBlank(extractedAuthor) && notBlank(extractedTitle)) {
                    List<Book> candidates = bookRepository.findEnrichedCandidatesByAuthorAndTitleLike(
                            extractedAuthor.trim(),
                            extractedTitle.trim()
                    );

                    double best = 0.0;
                    for (Book c : candidates) {
                        double score = tokenOverlapScore(extractedTitle, c.getTitle());
                        if (score > best) {
                            best = score;
                            donor = c;
                        }
                    }

                    // soglia “alta”: se vuoi più permissivo metti 0.6
                    if (donor != null && best >= 0.75) {
                        book.setDescription(donor.getDescription());
                        book.setTags(donor.getTags());

                        // se autore estratto manca ma donor ce l'ha, lo copio
                        if (!notBlank(book.getAuthor()) && notBlank(donor.getAuthor())) {
                            book.setAuthor(donor.getAuthor());
                        }

                        book = bookRepository.save(book);
                        ensureUserBook(userKey, book);
                        return new ScanResponse(
                                book.getId(),
                                book.getTitle(),
                                book.getAuthor(),
                                book.getCoverUrl(),
                                book.getDescription(),
                                parseTags(book.getTags())
                        );
                    }
                }

                // Caso 2: autore mancante -> provo una ricerca “soft” solo sul titolo tra libri arricchiti
                if (donor == null && notBlank(extractedTitle)) {
                    List<Book> all = bookRepository.search(extractedTitle.trim());
                    double best = 0.0;
                    for (Book c : all) {
                        if (!notBlank(c.getDescription())) continue;
                        double score = tokenOverlapScore(extractedTitle, c.getTitle());
                        if (score > best) {
                            best = score;
                            donor = c;
                        }
                    }

                    if (donor != null && best >= 0.85) { // più alto perché autore non conferma
                        book.setDescription(donor.getDescription());
                        book.setTags(donor.getTags());

                        if (!notBlank(book.getAuthor()) && notBlank(donor.getAuthor())) {
                            book.setAuthor(donor.getAuthor());
                        }

                        book = bookRepository.save(book);
                        ensureUserBook(userKey, book);
                        return new ScanResponse(
                                book.getId(),
                                book.getTitle(),
                                book.getAuthor(),
                                book.getCoverUrl(),
                                book.getDescription(),
                                parseTags(book.getTags())
                        );
                    }
                }

                // 4B) se non ho donor valido, chiamo Gemini per ARRICCHIRE
                String t = notBlank(extractedTitle) ? extractedTitle : "Titolo non riconosciuto";
                String a = notBlank(extractedAuthor) ? extractedAuthor : "";

                GeminiEnrichDto enrich = callEnrichWithMaxRetry(mimeType, base64, t, a, 1);

                // NB: author può essere "unknown" dal prompt
                if (notBlank(enrich.author())) book.setAuthor(enrich.author().trim());
                book.setDescription(enrich.description());
                book.setTags(objectMapper.writeValueAsString(enrich.tags()));
                book = bookRepository.save(book);
            }

            ensureUserBook(userKey, book);

            log.info("scan.done userKey={} bookId={} elapsedMs={}",
                    userKey, book.getId(), (System.currentTimeMillis() - t0));

            return new ScanResponse(
                    book.getId(),
                    book.getTitle(),
                    book.getAuthor(),
                    book.getCoverUrl(),
                    book.getDescription(),
                    parseTags(book.getTags())
            );

        } catch (Exception e) {
            log.error("scan.fail userKey={} msg={} elapsedMs={}",
                    userKey, e.getMessage(), (System.currentTimeMillis() - t0), e);
            throw e;
        }
    }

    private String model() {
        return env.getProperty("app.gemini.model", "gemini-2.5-flash-lite");
    }

    private GeminiExtractDto callExtractWithMaxRetry(String mimeType, String base64, int maxRetries) throws Exception {
        Exception last = null;
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                String model = model();
                var req = GeminiRequests.buildExtractRequest(mimeType, base64);

                log.info("gemini.extract.try attempt={} model={}", attempt, model);

                var resp = geminiClient.generateContent(model, req).block();
                String json = firstText(resp);

                log.debug("gemini.extract.rawJson {}", json);

                return objectMapper.readValue(json, GeminiExtractDto.class);
            } catch (Exception e) {
                last = e;

                Integer status = tryGetStatusCode(e);
                if (status != null) {
                    log.warn("gemini.extract.fail attempt={} status={} msg={}",
                            attempt, status, e.getMessage());
                } else {
                    log.warn("gemini.extract.fail attempt={} msg={}", attempt, e.getMessage());
                }
            }
        }
        throw last;
    }

    private GeminiEnrichDto callEnrichWithMaxRetry(String mimeType, String base64, String title, String author, int maxRetries) throws Exception {
        Exception last = null;
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                String model = model();
                var req = GeminiRequests.buildEnrichRequest(mimeType, base64, title, author);

                log.info("gemini.enrich.try attempt={} model={} title='{}' author='{}'",
                        attempt, model, title, author);

                var resp = geminiClient.generateContent(model, req).block();
                String json = firstText(resp);

                log.debug("gemini.enrich.rawJson {}", json);

                return objectMapper.readValue(json, GeminiEnrichDto.class);
            } catch (Exception e) {
                last = e;

                Integer status = tryGetStatusCode(e);
                if (status != null) {
                    log.warn("gemini.enrich.fail attempt={} status={} msg={}",
                            attempt, status, e.getMessage());
                } else {
                    log.warn("gemini.enrich.fail attempt={} msg={}", attempt, e.getMessage());
                }
            }
        }
        throw last;
    }

    private Integer tryGetStatusCode(Exception e) {
        // evita dipendenze extra: usa instanceof diretto
        if (e instanceof org.springframework.web.reactive.function.client.WebClientResponseException wex) {
            return wex.getStatusCode().value();
        }
        Throwable c = e.getCause();
        if (c instanceof org.springframework.web.reactive.function.client.WebClientResponseException wex) {
            return wex.getStatusCode().value();
        }
        return null;
    }

    private void ensureUserBook(String userKey, Book book) {
        Book finalBook = book;

        boolean exists = userBookRepository.findByUserKeyAndBook_Id(userKey, finalBook.getId()).isPresent();
        if (exists) {
            log.info("userbook.exists userKey={} bookId={}", userKey, finalBook.getId());
            return;
        }

        userBookRepository.save(UserBook.builder()
                .userKey(userKey)
                .book(finalBook)
                .status(ReadingStatus.TO_READ)
                .build());

        log.info("userbook.created userKey={} bookId={} status={}",
                userKey, finalBook.getId(), ReadingStatus.TO_READ);
    }

    private static String firstText(GeminiGenerateContentResponse resp) {
        if (resp == null || resp.candidates() == null || resp.candidates().isEmpty()) return "{}";
        var c0 = resp.candidates().get(0);
        if (c0.content() == null || c0.content().parts() == null || c0.content().parts().isEmpty()) return "{}";
        String t = c0.content().parts().get(0).text();
        return t != null ? t.trim() : "{}";
    }

    private static boolean notBlank(String s) {
        return s != null && !s.trim().isEmpty();
    }

    private static String pickBest(String hint, String extracted) {
        if (notBlank(hint)) return hint;
        return extracted;
    }

    private List<String> parseTags(String tagsJson) {
        try {
            if (!notBlank(tagsJson)) return List.of();
            return objectMapper.readValue(tagsJson, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return List.of(); // fail-safe
        }
    }

    private String normalizeTitle(String t) {
        if (t == null) return null;
        String s = t.toLowerCase().trim();
        s = s.replaceAll("[^a-z0-9\\s]", " ");
        s = s.replaceAll("\\b(volume|vol|vol\\.|#)\\b", " ");
        s = s.replaceAll("\\s+", " ").trim();
        return s.isBlank() ? null : s;
    }

    private static String normalizeTitleKey(String s) {
        if (s == null) return "";
        String x = s.toLowerCase();
        x = x.replaceAll("[^a-z0-9àèéìòù\\s]", " ");   // toglie punteggiatura
        x = x.replaceAll("\\b(vol(ume)?|tome|tom\\.?|n\\.?|no\\.?|#)\\s*\\d+\\b", " "); // vol 1, n.2 ecc
        x = x.replaceAll("\\b(antologia|edizione|edition|illustrata|integrale|nuova|classici)\\b", " ");
        x = x.replaceAll("\\s+", " ").trim();
        return x;
    }

    private static double tokenOverlapScore(String a, String b) {
        String na = normalizeTitleKey(a);
        String nb = normalizeTitleKey(b);
        if (na.isBlank() || nb.isBlank()) return 0.0;

        var sa = new java.util.HashSet<>(java.util.Arrays.asList(na.split(" ")));
        var sb = new java.util.HashSet<>(java.util.Arrays.asList(nb.split(" ")));
        sa.removeIf(t -> t.length() <= 2);
        sb.removeIf(t -> t.length() <= 2);
        if (sa.isEmpty() || sb.isEmpty()) return 0.0;

        int inter = 0;
        for (String t : sa) if (sb.contains(t)) inter++;
        int union = sa.size() + sb.size() - inter;
        return union == 0 ? 0.0 : (double) inter / (double) union;
    }

    private static boolean authorCompatible(String a1, String a2) {
        if (!notBlank(a1) || !notBlank(a2)) return false;
        return a1.trim().equalsIgnoreCase(a2.trim());
    }
}