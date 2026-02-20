package com.shelfscanai.controller;

import com.shelfscanai.dto.ScanResponse;
import com.shelfscanai.entity.Book;
import com.shelfscanai.entity.ReadingStatus;
import com.shelfscanai.entity.UserBook;
import com.shelfscanai.repository.BookRepository;
import com.shelfscanai.repository.UserBookRepository;
import com.shelfscanai.service.BlobStorageService;
import com.shelfscanai.service.EasyAuthUserExtractor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api")
public class ScanController {

    private final BlobStorageService blobStorageService;

    private final BookRepository bookRepository;
    private final UserBookRepository userBookRepository;

    private final EasyAuthUserExtractor easyAuthUserExtractor;

    @PostMapping(value = "/scan", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> scan(
            @RequestPart("image") MultipartFile image,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) String author,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) throws Exception {

        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);

        if (userKey == null) {
            return ResponseEntity.status(401).body("Not authenticated");
        }

        if (image == null || image.isEmpty()) {
            return ResponseEntity.badRequest().body("Image is required");
        }

        Book book;
        if (title != null && !title.isBlank() && author != null && !author.isBlank()) {
            book = bookRepository.findByTitleIgnoreCaseAndAuthorIgnoreCase(title.trim(), author.trim())
                    .orElse(null);
        } else {
            book = null;
        }

        if (book == null) {
            String coverUrl = blobStorageService.upload(image);

            book = bookRepository.save(Book.builder()
                    .title(title != null && !title.isBlank() ? title.trim() : "UNKNOWN_TITLE")
                    .author(author != null && !author.isBlank() ? author.trim() : null)
                    .coverUrl(coverUrl)
                    .build());

            // qui: se (description null) -> chiama OpenAI e aggiorna book
        } else {
            // opzionale: se vuoi aggiornare coverUrl quando scansionano, io lo eviterei per tenere il catalogo stabile
        }

        Book finalBook = book;
        userBookRepository.findByUserKeyAndBook_Id(userKey, book.getId())
                .orElseGet(() -> userBookRepository.save(UserBook.builder()
                        .userKey(userKey).book(finalBook).status(ReadingStatus.TO_READ).build()
                ));

        return ResponseEntity.ok(new ScanResponse(book.getId(), book.getTitle(), book.getAuthor(), book.getCoverUrl()));

    }
}
