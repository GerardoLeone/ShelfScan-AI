package com.shelfscanai.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "books")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Book {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    private String author;
    private String genre;

    @Column(name="cover_url")
    private String coverUrl;

    @Column(columnDefinition = "nvarchar(max)")
    private String description;

    // JSON array salvato come stringa (es: ["thriller","crime"])
    @Column(columnDefinition = "nvarchar(max)")
    private String tags;
}
