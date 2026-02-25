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
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;

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
        if (image == null || image.isEmpty()) throw new IllegalArgumentException("Image is required");
        if (userKey == null || userKey.isBlank()) throw new IllegalArgumentException("Not authenticated");

        String mimeType = image.getContentType() != null ? image.getContentType() : "image/jpeg";
        String base64 = Base64.getEncoder().encodeToString(image.getBytes());

        // 1) Se mi passi title+author già validi, provo subito lookup DB e potenzialmente salto Gemini
        Book book = null;
        if (notBlank(titleHint) && notBlank(authorHint)) {
            book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(titleHint.trim(), authorHint.trim())
                    .orElse(null);
            if (book != null && notBlank(book.getDescription())) {
                ensureUserBook(userKey, book);
                return new ScanResponse(book.getId(), book.getTitle(), book.getAuthor(), book.getCoverUrl());
            }
        }

        // 2) EXTRACT (1 chiamata) solo se non ho già trovato un book arricchito
        GeminiExtractDto extract = callExtractWithMaxRetry(mimeType, base64, 1);

        String extractedTitle = pickBest(titleHint, extract.title());
        String extractedAuthor = pickBest(authorHint, extract.author());

        if (notBlank(extractedTitle) && notBlank(extractedAuthor)) {
            book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(extractedTitle.trim(), extractedAuthor.trim())
                    .orElse(null);

            if (book != null && notBlank(book.getDescription())) {
                ensureUserBook(userKey, book);
                return new ScanResponse(book.getId(), book.getTitle(), book.getAuthor(), book.getCoverUrl());
            }
        }

        // 3) Upload cover solo se devo creare/aggiornare
        String coverUrl = blobStorageService.upload(image);

        if (book == null) {
            // creo entry minima “globale”
            book = bookRepository.save(Book.builder()
                    .title(notBlank(extractedTitle) ? extractedTitle.trim() : "UNKNOWN_TITLE")
                    .author(notBlank(extractedAuthor) ? extractedAuthor.trim() : null)
                    .coverUrl(coverUrl)
                    .build());
        } else if (book.getCoverUrl() == null) {
            // opzionale: aggiorna cover se non presente
            book.setCoverUrl(coverUrl);
        }

        // 4) ENRICH (2a chiamata) SOLO se description mancante
        if (!notBlank(book.getDescription())) {
            String t = notBlank(extractedTitle) ? extractedTitle : "Titolo non riconosciuto";
            String a = notBlank(extractedAuthor) ? extractedAuthor : "";

            GeminiEnrichDto enrich = callEnrichWithMaxRetry(mimeType, base64, t, a, 1);

            book.setAuthor(enrich.author().trim());
            book.setDescription(enrich.description());
            // tags come JSON array stringa per semplicità
            book.setTags(objectMapper.writeValueAsString(enrich.tags()));
            book = bookRepository.save(book);
        }

        ensureUserBook(userKey, book);
        return new ScanResponse(book.getId(), book.getTitle(), book.getAuthor(), book.getCoverUrl());
    }

    private GeminiExtractDto callExtractWithMaxRetry(String mimeType, String base64, int maxRetries) throws Exception {
        Exception last = null;
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                String model = env.getProperty("app.gemini.model", "gemini-2.5-flash-lite");
                var req = GeminiRequests.buildExtractRequest(mimeType, base64);
                var resp = geminiClient.generateContent(model, req).block();
                String json = firstText(resp);
                return objectMapper.readValue(json, GeminiExtractDto.class);
            } catch (Exception e) {
                last = e;
            }
        }
        throw last;
    }

    private GeminiEnrichDto callEnrichWithMaxRetry(String mimeType, String base64, String title, String author, int maxRetries) throws Exception {
        Exception last = null;
        for (int attempt = 0; attempt <= maxRetries; attempt++) {
            try {
                String model = env.getProperty("app.gemini.model", "gemini-2.5-flash-lite");
                var req = GeminiRequests.buildEnrichRequest(mimeType, base64, title, author);
                var resp = geminiClient.generateContent(model, req).block();
                String json = firstText(resp);
                return objectMapper.readValue(json, GeminiEnrichDto.class);
            } catch (Exception e) {
                last = e;
            }
        }
        throw last;
    }

    private void ensureUserBook(String userKey, Book book) {
        Book finalBook = book;
        userBookRepository.findByUserKeyAndBook_Id(userKey, finalBook.getId())
                .orElseGet(() -> userBookRepository.save(UserBook.builder()
                        .userKey(userKey)
                        .book(finalBook)
                        .status(ReadingStatus.TO_READ)
                        .build()));
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
}