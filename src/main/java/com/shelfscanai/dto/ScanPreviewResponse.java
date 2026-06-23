package com.shelfscanai.dto;

import java.util.List;

public record ScanPreviewResponse(
        Long matchedBookId,
        String title,
        String author,
        String coverUrl,
        String description,
        List<String> tags,
        double confidence,
        boolean existingBook
) {}