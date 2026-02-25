package com.shelfscanai.dto;

import java.util.List;

public record GeminiEnrichDto(
        String author,
        String description,
        List<String> tags,
        double confidence
) {}