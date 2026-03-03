package com.shelfscanai.dto;

import java.util.List;

public record ScanResponse(
        Long bookId,
        String title,
        String author,
        String coverUrl,
        String description,
        List<String> tags
) {}