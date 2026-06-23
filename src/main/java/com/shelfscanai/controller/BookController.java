package com.shelfscanai.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.shelfscanai.dto.UpdateBookRequest;
import com.shelfscanai.entity.Book;
import com.shelfscanai.repository.BookRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/books")
public class BookController {

    private final BookRepository bookRepository;
    private final ObjectMapper objectMapper;

    @GetMapping("/{id}")
    public ResponseEntity<?> getOne(@PathVariable Long id) {
        return bookRepository.findById(id)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.status(404).body("Book not found"));
    }

    @GetMapping
    public ResponseEntity<?> search(@RequestParam(name = "query", required = false) String query) {
        if (query == null || query.isBlank()) return ResponseEntity.ok(bookRepository.findAll());
        return ResponseEntity.ok(bookRepository.search(query.trim()));
    }

    @PatchMapping("/{id}")
    public ResponseEntity<?> updateBook(
            @PathVariable Long id,
            @RequestBody UpdateBookRequest req
    ) throws Exception {
        Book book = bookRepository.findById(id).orElse(null);
        if (book == null) return ResponseEntity.status(404).body("Book not found");

        if (req.title() != null && !req.title().isBlank()) {
            book.setTitle(req.title().trim());
            book.setNormalizedTitle(normalizeTitle(req.title()));
        }

        if (req.author() != null) {
            book.setAuthor(req.author().trim().isEmpty() ? null : req.author().trim());
        }

        if (req.description() != null) {
            book.setDescription(req.description().trim().isEmpty() ? null : req.description().trim());
        }

        if (req.tags() != null) {
            List<String> cleaned = req.tags()
                    .stream()
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList();

            book.setTags(objectMapper.writeValueAsString(cleaned));
        }

        return ResponseEntity.ok(bookRepository.save(book));
    }

    private String normalizeTitle(String t) {
        if (t == null) return null;
        String s = t.toLowerCase().trim();
        s = s.replaceAll("[^a-z0-9\\s]", " ");
        s = s.replaceAll("\\b(volume|vol|vol\\.|#)\\b", " ");
        s = s.replaceAll("\\s+", " ").trim();
        return s.isBlank() ? null : s;
    }
}