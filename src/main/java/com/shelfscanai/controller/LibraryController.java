package com.shelfscanai.controller;

import com.shelfscanai.dto.LibraryItemResponse;
import com.shelfscanai.dto.UpdateStatusRequest;
import com.shelfscanai.entity.Book;
import com.shelfscanai.entity.ReadingStatus;
import com.shelfscanai.entity.UserBook;
import com.shelfscanai.repository.BookRepository;
import com.shelfscanai.repository.UserBookRepository;
import com.shelfscanai.service.EasyAuthUserExtractor;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api")
public class LibraryController {

    private final UserBookRepository userBookRepository;
    private final BookRepository bookRepository;
    private final EasyAuthUserExtractor easyAuthUserExtractor;

    @GetMapping("/library")
    public ResponseEntity<?> getLibrary(
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        List<LibraryItemResponse> items = userBookRepository.findByUserKeyOrderByUpdatedAtDesc(userKey)
                .stream()
                .map(ub -> new LibraryItemResponse(
                        ub.getBook().getId(),
                        ub.getBook().getTitle(),
                        ub.getBook().getAuthor(),
                        ub.getBook().getCoverUrl(),
                        ub.getStatus(),
                        ub.getUpdatedAt()
                ))
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
        if (req == null || req.status() == null) return ResponseEntity.badRequest().body("status is required");

        UserBook ub = userBookRepository.findByUserKeyAndBook_Id(userKey, bookId)
                .orElse(null);

        if (ub == null) return ResponseEntity.status(404).body("Book not in library");

        ub.setStatus(req.status());
        userBookRepository.save(ub);

        return ResponseEntity.ok().build();
    }

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

        return ResponseEntity.ok(new LibraryItemResponse(
                ub.getBook().getId(),
                ub.getBook().getTitle(),
                ub.getBook().getAuthor(),
                ub.getBook().getCoverUrl(),
                ub.getStatus(),
                ub.getUpdatedAt()
        ));
    }

    @PostMapping("/library/{bookId}")
    public ResponseEntity<?> addToLibrary(
            @PathVariable Long bookId,
            @RequestHeader(value="X-MS-CLIENT-PRINCIPAL-ID", required=false) String principalId,
            @RequestHeader(value="X-MS-CLIENT-PRINCIPAL-NAME", required=false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        Book book = bookRepository.findById(bookId).orElse(null);
        if (book == null) return ResponseEntity.status(404).body("Book not found");

        userBookRepository.findByUserKeyAndBook_Id(userKey, bookId)
                .orElseGet(() -> userBookRepository.save(
                        UserBook.builder().userKey(userKey).book(book).status(ReadingStatus.TO_READ).build()
                ));

        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/library/{bookId}")
    public ResponseEntity<?> removeFromLibrary(
            @PathVariable Long bookId,
            @RequestHeader(value="X-MS-CLIENT-PRINCIPAL-ID", required=false) String principalId,
            @RequestHeader(value="X-MS-CLIENT-PRINCIPAL-NAME", required=false) String principalName
    ) {
        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        UserBook ub = userBookRepository.findByUserKeyAndBook_Id(userKey, bookId).orElse(null);
        if (ub == null) return ResponseEntity.status(404).body("Book not in library");

        userBookRepository.delete(ub);
        return ResponseEntity.ok().build();
    }


}
