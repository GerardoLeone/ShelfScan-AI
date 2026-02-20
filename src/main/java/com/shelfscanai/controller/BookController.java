package com.shelfscanai.controller;

import com.shelfscanai.repository.BookRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/books")
public class BookController {

    private final BookRepository bookRepository;

    @GetMapping("/{id}")
    public ResponseEntity<?> getOne(@PathVariable Long id) {
        return bookRepository.findById(id)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.status(404).body("Book not found"));
    }

    @GetMapping
    public ResponseEntity<?> search(@RequestParam(name="query", required=false) String query) {
        if (query == null || query.isBlank()) return ResponseEntity.ok(bookRepository.findAll());
        return ResponseEntity.ok(bookRepository.search(query.trim()));
    }
}
