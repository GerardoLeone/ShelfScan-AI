package com.shelfscanai.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.shelfscanai.dto.*;
import com.shelfscanai.entity.Book;
import com.shelfscanai.entity.ReadingStatus;
import com.shelfscanai.entity.UserBook;
import com.shelfscanai.exception.GeminiScanException;
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

    private void ensureUserBookWithCustomMetadata(
            String userKey,
            Book book,
            ScanConfirmRequest req
    ) throws Exception {
        UserBook ub = userBookRepository.findByUserKeyAndBook_Id(userKey, book.getId())
                .orElse(null);

        if (ub == null) {
            ub = UserBook.builder()
                    .userKey(userKey)
                    .book(book)
                    .status(ReadingStatus.TO_READ)
                    .build();
        }

        ub.setCustomTitle(cleanOrNull(req.customTitle()));
        ub.setCustomTags(normalizeTagsJson(req.customTagsJson()));

        userBookRepository.save(ub);

        log.info("userbook.upsert.custom userKey={} bookId={}", userKey, book.getId());
    }

    private String cleanOrNull(String value) {
        if (value == null) return null;
        String cleaned = value.trim();
        return cleaned.isEmpty() ? null : cleaned;
    }

    public ScanPreviewResponse preview(
            MultipartFile image,
            String titleHint,
            String authorHint,
            String userKey
    ) throws Exception {
        long t0 = System.currentTimeMillis();

        try {
            if (image == null || image.isEmpty()) throw new IllegalArgumentException("Image is required");
            if (userKey == null || userKey.isBlank()) throw new IllegalArgumentException("Not authenticated");

            log.info("scan.preview.start userKey={} titleHint='{}' authorHint='{}' filename={} size={}",
                    userKey, titleHint, authorHint, image.getOriginalFilename(), image.getSize());

            String mimeType = image.getContentType() != null ? image.getContentType() : "image/jpeg";
            String base64 = Base64.getEncoder().encodeToString(image.getBytes());

            Book book = null;

            /**
             * PREVIEW SENZA USARE GEMINI (RISPARMIO)
             */
            if (!geminiEnabled()) {
                log.warn("scan.preview.mock.enabled userKey={} titleHint='{}' authorHint='{}'",
                        userKey, titleHint, authorHint);

                String mockTitle = notBlank(titleHint) ? titleHint.trim() : "Dragon Ball 2";
                String mockAuthor = notBlank(authorHint) ? authorHint.trim() : "Akira Toriyama";

                Book donor = null;

                if (notBlank(mockAuthor) && notBlank(mockTitle)) {
                    String normalized = normalizeTitleKey(mockTitle);
                    log.warn("MOCK SEARCH normalized='{}' original='{}'", normalized, mockTitle);

                    List<Book> candidates = bookRepository.findEnrichedCandidatesByAuthorAndTitleLike(
                            mockAuthor,
                            normalized
                    );

                    double best = 0.0;
                    for (Book c : candidates) {
                        double score = tokenOverlapScore(mockTitle, c.getTitle());
                        if (score > best) {
                            best = score;
                            donor = c;
                        }
                    }

                    if (donor != null) {
                        String a = normalizeTitleKey(mockTitle);
                        String b = normalizeTitleKey(donor.getTitle());

                        if (a.equals(b) || a.contains(b) || b.contains(a) || best >= 0.45) {
                            log.info("scan.preview.mock.donor.hit donorId={} score={} a='{}' b='{}'",
                                    donor.getId(), best, a, b);

                            return new ScanPreviewResponse(
                                    null,
                                    mockTitle,
                                    mockAuthor,
                                    null,
                                    donor.getDescription(),
                                    parseTags(donor.getTags()),
                                    1.0,
                                    false
                            );
                        }
                    }
                }

                return new ScanPreviewResponse(
                        null,
                        mockTitle,
                        mockAuthor,
                        null,
                        "Descrizione mock in italiano per test senza Gemini.",
                        List.of("manga", "avventura", "combattimento"),
                        1.0,
                        false
                );
            }

            if (notBlank(titleHint) && notBlank(authorHint)) {
                book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(
                        titleHint.trim(),
                        authorHint.trim()
                ).orElse(null);

                if (book != null && notBlank(book.getDescription())) {
                    log.info("scan.preview.hint.hit userKey={} bookId={} elapsedMs={}",
                            userKey, book.getId(), System.currentTimeMillis() - t0);

                    return new ScanPreviewResponse(
                            book.getId(),
                            book.getTitle(),
                            book.getAuthor(),
                            blobStorageService.generateReadSasUrl(book.getCoverUrl()),
                            book.getDescription(),
                            parseTags(book.getTags()),
                            1.0,
                            true
                    );
                }
            }

            log.info("scan.preview.gemini.extract.call userKey={} model={}", userKey, model());
            GeminiExtractDto extract = callExtractWithMaxRetry(mimeType, base64, 1);

            String extractedTitle = pickBest(titleHint, extract.title());
            String extractedAuthor = pickBest(authorHint, extract.author());

            log.info("scan.preview.extract.done userKey={} title='{}' author='{}' conf={} notes='{}'",
                    userKey, extractedTitle, extractedAuthor, extract.confidence(), extract.notes());

            String nt = normalizeTitle(extractedTitle);

            if (notBlank(extractedTitle) && notBlank(extractedAuthor)) {
                book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(
                        extractedTitle.trim(),
                        extractedAuthor.trim()
                ).orElse(null);
            } else if (nt != null) {
                List<Book> candidates = bookRepository.findByNormalizedTitle(nt);
                if (!candidates.isEmpty()) book = candidates.getFirst();
            }

            if (book != null && notBlank(book.getDescription())) {
                log.info("scan.preview.existing.enriched userKey={} bookId={} elapsedMs={}",
                        userKey, book.getId(), System.currentTimeMillis() - t0);

                return new ScanPreviewResponse(
                        book.getId(),
                        book.getTitle(),
                        book.getAuthor(),
                        blobStorageService.generateReadSasUrl(book.getCoverUrl()),
                        book.getDescription(),
                        parseTags(book.getTags()),
                        extract.confidence(),
                        true
                );
            }

            String previewTitle = notBlank(extractedTitle) ? extractedTitle.trim() : "Titolo non riconosciuto";
            String previewAuthor = notBlank(extractedAuthor) ? extractedAuthor.trim() : null;
            String previewDescription = null;
            List<String> previewTags = List.of();

            Book donor = null;

            if (notBlank(previewAuthor) && notBlank(previewTitle)) {
                String normalized = normalizeTitleKey(previewTitle);

                log.info("DONOR SEARCH normalized='{}' original='{}' author='{}'",
                        normalized, previewTitle, previewAuthor);

                List<Book> candidates = bookRepository.findEnrichedCandidatesByAuthorAndTitleLike(
                        previewAuthor,
                        normalized
                );

                double best = 0.0;
                for (Book c : candidates) {
                    double score = tokenOverlapScore(previewTitle, c.getTitle());
                    if (score > best) {
                        best = score;
                        donor = c;
                    }
                }

                if (donor != null) {
                    String a = normalizeTitleKey(previewTitle);
                    String b = normalizeTitleKey(donor.getTitle());

                    if (a.equals(b) || a.contains(b) || b.contains(a) || best >= 0.45) {
                        previewDescription = donor.getDescription();
                        previewTags = parseTags(donor.getTags());

                        if (notBlank(donor.getAuthor()) && !authorCompatible(previewAuthor, donor.getAuthor())) {
                            previewAuthor = donor.getAuthor();
                        }

                        log.info("scan.preview.donor.author.hit userKey={} donorId={} score={} elapsedMs={}",
                                userKey, donor.getId(), best, System.currentTimeMillis() - t0);

                        return new ScanPreviewResponse(
                                book != null ? book.getId() : null,
                                previewTitle,
                                previewAuthor,
                                book != null ? blobStorageService.generateReadSasUrl(book.getCoverUrl()) : null,
                                previewDescription,
                                previewTags,
                                extract.confidence(),
                                book != null
                        );
                    }
                }
            }

            if (donor == null && notBlank(previewTitle)) {
                String normalized = normalizeTitleKey(previewTitle);

                log.info("DONOR SEARCH NO AUTHOR normalized='{}' original='{}'",
                        normalized, previewTitle);

                List<Book> all = bookRepository.findEnrichedCandidatesByTitleLikeNoAuthor(normalized);

                double best = 0.0;

                for (Book c : all) {
                    if (!notBlank(c.getDescription())) continue;

                    double score = tokenOverlapScore(previewTitle, c.getTitle());
                    if (score > best) {
                        best = score;
                        donor = c;
                    }
                }

                if (donor != null && best >= 0.65) {
                    previewDescription = donor.getDescription();
                    previewTags = parseTags(donor.getTags());

                    if (!notBlank(previewAuthor) && notBlank(donor.getAuthor())) {
                        previewAuthor = donor.getAuthor();
                    }

                    log.info("scan.preview.donor.title.hit userKey={} donorId={} score={} elapsedMs={}",
                            userKey, donor.getId(), best, System.currentTimeMillis() - t0);

                    return new ScanPreviewResponse(
                            book != null ? book.getId() : null,
                            previewTitle,
                            previewAuthor,
                            book != null ? blobStorageService.generateReadSasUrl(book.getCoverUrl()) : null,
                            previewDescription,
                            previewTags,
                            extract.confidence(),
                            book != null
                    );
                }
            }

            log.info("scan.preview.gemini.enrich.call userKey={} title='{}' author='{}'",
                    userKey, previewTitle, previewAuthor);

            GeminiEnrichDto enrich = callEnrichWithMaxRetry(
                    mimeType,
                    base64,
                    previewTitle,
                    notBlank(previewAuthor) ? previewAuthor : "",
                    1
            );

            if (notBlank(enrich.author())) {
                previewAuthor = enrich.author().trim();
            }

            previewDescription = enrich.description();
            previewTags = enrich.tags() != null ? enrich.tags() : List.of();

            log.info("scan.preview.done userKey={} matchedBookId={} elapsedMs={}",
                    userKey,
                    book != null ? book.getId() : null,
                    System.currentTimeMillis() - t0);

            return new ScanPreviewResponse(
                    book != null ? book.getId() : null,
                    previewTitle,
                    previewAuthor,
                    book != null ? blobStorageService.generateReadSasUrl(book.getCoverUrl()) : null,
                    previewDescription,
                    previewTags,
                    extract.confidence(),
                    book != null
            );

        } catch (Exception e) {
            log.error("scan.preview.fail userKey={} msg={} elapsedMs={}",
                    userKey, e.getMessage(), System.currentTimeMillis() - t0, e);
            throw e;
        }
    }

    public ScanResponse confirm(
            MultipartFile image,
            ScanConfirmRequest req,
            String userKey
    ) throws Exception {
        long t0 = System.currentTimeMillis();

        try {
            if (image == null || image.isEmpty()) throw new IllegalArgumentException("Image is required");
            if (userKey == null || userKey.isBlank()) throw new IllegalArgumentException("Not authenticated");
            if (req == null || !notBlank(req.canonicalTitle())) throw new IllegalArgumentException("Canonical title is required");

            log.info("scan.confirm.start userKey={} matchedBookId={} title='{}' author='{}' filename={} size={}",
                    userKey, req.matchedBookId(), req.canonicalTitle(), req.canonicalAuthor(),
                    image.getOriginalFilename(), image.getSize());

            Book book = null;

            if (req.matchedBookId() != null) {
                book = bookRepository.findById(req.matchedBookId()).orElse(null);
            }

            if (book == null && notBlank(req.canonicalTitle()) && notBlank(req.canonicalAuthor())) {
                book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(
                        req.canonicalTitle().trim(),
                        req.canonicalAuthor().trim()
                ).orElse(null);
            }

            if (book == null) {
                String nt = normalizeTitle(req.canonicalTitle());
                if (nt != null) {
                    List<Book> candidates = bookRepository.findByNormalizedTitle(nt);
                    if (!candidates.isEmpty()) book = candidates.getFirst();
                }
            }

            String coverUrl = null;

            if (book == null || !notBlank(book.getCoverUrl())) {
                coverUrl = blobStorageService.upload(image);
                log.info("scan.confirm.blob.uploaded userKey={} coverUrl={}", userKey, coverUrl);
            }

            if (book == null) {
                book = Book.builder()
                        .title(req.canonicalTitle().trim())
                        .normalizedTitle(normalizeTitle(req.canonicalTitle()))
                        .author(notBlank(req.canonicalAuthor()) ? req.canonicalAuthor().trim() : null)
                        .coverUrl(coverUrl)
                        .description(req.canonicalDescription())
                        .tags(normalizeTagsJson(req.canonicalTagsJson()))
                        .build();

                book = bookRepository.save(book);

                log.info("scan.confirm.book.created bookId={} title='{}' author='{}'",
                        book.getId(), book.getTitle(), book.getAuthor());

            } else {
                /*
                 * Libro già esistente.
                 * Non sovrascriviamo aggressivamente titolo/autore globali,
                 * perché il Book è globale e potrebbe essere già usato da altri utenti.
                 * Aggiorniamo solo campi mancanti.
                 */

                if (!notBlank(book.getCoverUrl()) && notBlank(coverUrl)) {
                    book.setCoverUrl(coverUrl);
                }

                if (!notBlank(book.getAuthor()) && notBlank(req.canonicalAuthor())) {
                    book.setAuthor(req.canonicalAuthor().trim());
                }

                if (!notBlank(book.getDescription()) && notBlank(req.canonicalDescription())) {
                    book.setDescription(req.canonicalDescription());
                }

                if (!notBlank(book.getTags()) && notBlank(req.canonicalTagsJson())) {
                    book.setTags(normalizeTagsJson(req.canonicalTagsJson()));
                }

                if (!notBlank(book.getNormalizedTitle())) {
                    book.setNormalizedTitle(normalizeTitle(book.getTitle()));
                }

                book = bookRepository.save(book);

                log.info("scan.confirm.book.updated bookId={} hasCover={} hasDesc={}",
                        book.getId(), notBlank(book.getCoverUrl()), notBlank(book.getDescription()));
            }

            ensureUserBookWithCustomMetadata(userKey, book, req);

            log.info("scan.confirm.done userKey={} bookId={} elapsedMs={}",
                    userKey, book.getId(), System.currentTimeMillis() - t0);

            return new ScanResponse(
                    book.getId(),
                    book.getTitle(),
                    book.getAuthor(),
                    blobStorageService.generateReadSasUrl(book.getCoverUrl()),
                    book.getDescription(),
                    parseTags(book.getTags())
            );

        } catch (Exception e) {
            log.error("scan.confirm.fail userKey={} msg={} elapsedMs={}",
                    userKey, e.getMessage(), System.currentTimeMillis() - t0, e);
            throw e;
        }
    }

    private String normalizeTagsJson(String tagsJson) {
        try {
            if (!notBlank(tagsJson)) return objectMapper.writeValueAsString(List.of());

            List<String> tags = objectMapper.readValue(
                    tagsJson,
                    new TypeReference<List<String>>() {}
            );

            return objectMapper.writeValueAsString(tags);
        } catch (Exception e) {
            try {
                return objectMapper.writeValueAsString(List.of());
            } catch (Exception ignored) {
                return "[]";
            }
        }
    }

    private String model() {
        return env.getProperty("app.gemini.model", "gemini-2.5-flash-lite");
    }

    private boolean geminiEnabled() {
        return Boolean.parseBoolean(env.getProperty("app.gemini.enabled", "true"));
    }

    private GeminiExtractDto callExtractWithMaxRetry(String mimeType, String base64, int maxRetries) throws Exception {
        try {
            String model = model();
            var req = GeminiRequests.buildExtractRequest(mimeType, base64);

            log.info("gemini.extract.call model={}", model);

            var resp = geminiClient.generateContent(model, req).block();
            String json = firstText(resp);

            log.debug("gemini.extract.rawJson {}", json);

            return objectMapper.readValue(json, GeminiExtractDto.class);

        } catch (Exception e) {
            String message = cleanGeminiError(e);
            log.warn("gemini.extract.fail msg={}", message, e);
            throw new GeminiScanException(message);
        }
    }

    private GeminiEnrichDto callEnrichWithMaxRetry(
            String mimeType,
            String base64,
            String title,
            String author,
            int maxRetries
    ) throws Exception {
        try {
            String model = model();
            var req = GeminiRequests.buildEnrichRequest(mimeType, base64, title, author);

            log.info("gemini.enrich.call model={} title='{}' author='{}'",
                    model, title, author);

            var resp = geminiClient.generateContent(model, req).block();
            String json = firstText(resp);

            log.debug("gemini.enrich.rawJson {}", json);

            return objectMapper.readValue(json, GeminiEnrichDto.class);

        } catch (Exception e) {
            String message = cleanGeminiError(e);
            log.warn("gemini.enrich.fail msg={}", message, e);
            throw new GeminiScanException(message);
        }
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
        x = x.replaceAll("\\b\\d+\\b", " ");
        x = x.replaceAll("\\b(antologia|edizione|edition|illustrata|integrale|nuova|classici|sd)\\b", " ");
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

    private String cleanGeminiError(Exception e) {
        String raw = e.getMessage();

        Throwable cause = e.getCause();
        if ((raw == null || raw.isBlank()) && cause != null) {
            raw = cause.getMessage();
        }

        if (raw == null || raw.isBlank()) {
            return "Gemini non ha restituito un messaggio di errore leggibile.";
        }

        if (raw.contains("429") || raw.toLowerCase().contains("quota")) {
            return "Quota Gemini esaurita o limite temporaneo raggiunto. Riprova più tardi.";
        }

        if (raw.contains("400")) {
            return "Richiesta Gemini non valida. Controlla immagine o formato della richiesta.";
        }

        if (raw.contains("401") || raw.contains("403")) {
            return "Gemini ha rifiutato la richiesta. Controlla API key o permessi.";
        }

        if (raw.contains("500") || raw.contains("503")) {
            return "Gemini non è temporaneamente disponibile. Riprova più tardi.";
        }

        return raw.length() > 400 ? raw.substring(0, 400) + "..." : raw;
    }
}