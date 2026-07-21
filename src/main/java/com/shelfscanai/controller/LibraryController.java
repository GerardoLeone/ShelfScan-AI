package com.shelfscanai.controller;

import com.shelfscanai.dto.LibraryItemResponse;
import com.shelfscanai.dto.UpdateLibraryItemRequest;
import com.shelfscanai.dto.UpdateStatusRequest;
import com.shelfscanai.entity.Book;
import com.shelfscanai.entity.ReadingStatus;
import com.shelfscanai.entity.UserBook;
import com.shelfscanai.repository.BookRepository;
import com.shelfscanai.repository.UserBookRepository;
import com.shelfscanai.service.BlobStorageService;
import com.shelfscanai.service.EasyAuthUserExtractor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api")
public class LibraryController {

    private final UserBookRepository userBookRepository;
    private final BookRepository bookRepository;
    private final EasyAuthUserExtractor easyAuthUserExtractor;
    private final BlobStorageService blobStorageService;
    private final ObjectMapper objectMapper;

    //Modifica soltanto Title e Tags
    @PatchMapping("/library/{bookId}/metadata")
    public ResponseEntity<?> updateLibraryItemMetadata(
            @PathVariable Long bookId,
            @RequestBody UpdateLibraryItemRequest req,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) throws Exception {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        //Restituisce USerBook a partire da UserKey e bookId
        UserBook ub = userBookRepository.findByUserKeyAndBook_Id(userKey, bookId).orElse(null);
        if (ub == null) return ResponseEntity.status(404).body("Book not in library");

        //Modifica title
        ub.setCustomTitle(cleanOrNull(req.customTitle()));

        //Modifica tags
        if (req.customTags() != null) {
            List<String> cleaned = req.customTags() //Pulizia dei tag rimuovendo spazi e tag vuoti, salva poi come JSON
                    .stream()
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList();

            ub.setCustomTags(objectMapper.writeValueAsString(cleaned));
        }

        userBookRepository.save(ub);

        return ResponseEntity.ok().build();
    }

    private String cleanOrNull(String value) {
        if (value == null) return null;
        String cleaned = value.trim();
        return cleaned.isEmpty() ? null : cleaned;
    }

    // Se esiste personale mostra i personali, altrimenti canonici
    private String pick(String personal, String canonical) {
        return personal != null && !personal.isBlank() ? personal : canonical;
    }

    private List<String> pickTags(String personalTags, String canonicalTags) {
        if (personalTags != null && !personalTags.isBlank()) {
            return parseTags(personalTags);
        }
        return parseTags(canonicalTags);
    }

    @GetMapping("/library")
    public ResponseEntity<?> getLibrary(
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        // Recupera solo i libri dell'utente autenticato
        List<LibraryItemResponse> items = userBookRepository.findByUserKeyOrderByUpdatedAtDesc(userKey)
                .stream()
                .map(ub -> { //per ogni UserBook...
                    Book book = ub.getBook(); //...recupera il GlobalBook collegato
                    String signedCoverUrl = blobStorageService.generateReadSasUrl(book.getCoverUrl()); //Genera il SAS

                    return new LibraryItemResponse(
                            book.getId(),
                            pick(ub.getCustomTitle(), book.getTitle()), //costruisce la risposta con PICK (se esiste personal, restituisce personal, altrimenti canonical)
                            book.getAuthor(),
                            signedCoverUrl,
                            book.getDescription(),
                            pickTags(ub.getCustomTags(), book.getTags()),
                            ub.getStatus(),
                            ub.getCurrentPage(),
                            ub.getUpdatedAt()
                    );
                })
                .toList();

        return ResponseEntity.ok(items);
    }

    @PatchMapping("/library/{bookId}/status")
    public ResponseEntity<?> updateStatus(
            @PathVariable Long bookId,
            @RequestBody UpdateStatusRequest req,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        if (req == null || req.status() == null)
            return ResponseEntity.badRequest().body("status is required");

        UserBook ub = userBookRepository.findByUserKeyAndBook_Id(userKey, bookId)
                .orElse(null);

        if (ub == null)
            return ResponseEntity.status(404).body("Book not in library");

        ub.setStatus(req.status());

        if (req.status() == ReadingStatus.READING) {
            ub.setCurrentPage(req.currentPage());
        } else {
            ub.setCurrentPage(null);
        }

        userBookRepository.save(ub);

        return ResponseEntity.ok().build();
    }

    // CHIAMATA GET sul singolo Id
    @GetMapping("/library/{bookId}")
    public ResponseEntity<?> getLibraryItem(
            @PathVariable Long bookId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        UserBook ub = userBookRepository.findByUserKeyAndBook_Id(userKey, bookId).orElse(null);
        if (ub == null) return ResponseEntity.status(404).body("Book not in library");

        Book book = ub.getBook();
        String signedCoverUrl = blobStorageService.generateReadSasUrl(book.getCoverUrl());

        return ResponseEntity.ok(new LibraryItemResponse(
                book.getId(),
                pick(ub.getCustomTitle(), book.getTitle()),
                book.getAuthor(),
                signedCoverUrl,
                book.getDescription(),
                pickTags(ub.getCustomTags(), book.getTags()),
                ub.getStatus(),
                ub.getCurrentPage(),
                ub.getUpdatedAt()
        ));
    }

    // CHIAMATA POST
    // Aggiunge un libro esistente alla libreria dell'utente (se esiste già, non crea duplicato)
    @PostMapping("/library/{bookId}")
    public ResponseEntity<?> addToLibrary(
            @PathVariable Long bookId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        Book book = bookRepository.findById(bookId).orElse(null);
        if (book == null) return ResponseEntity.status(404).body("Book not found");

        userBookRepository.findByUserKeyAndBook_Id(userKey, bookId)
                .orElseGet(() -> userBookRepository.save(
                        UserBook.builder()
                                .userKey(userKey)
                                .book(book)
                                .status(ReadingStatus.TO_READ)
                                .build()
                ));

        return ResponseEntity.ok().build();
    }

    // elimina solo UserBook
    @DeleteMapping("/library/{bookId}")
    public ResponseEntity<?> removeFromLibrary(
            @PathVariable Long bookId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        UserBook ub = userBookRepository.findByUserKeyAndBook_Id(userKey, bookId).orElse(null);
        if (ub == null) return ResponseEntity.status(404).body("Book not in library");

        userBookRepository.delete(ub);
        return ResponseEntity.ok().build();
    }

    private List<String> parseTags(String tagsJson) {
        try {
            if (tagsJson == null || tagsJson.isBlank()) return List.of();
            return objectMapper.readValue(tagsJson, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return List.of();
        }
    }
}