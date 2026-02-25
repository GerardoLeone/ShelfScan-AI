package com.shelfscanai.dto;

public record GeminiExtractDto(
        String title,
        String author,
        double confidence,
        String notes
) {}