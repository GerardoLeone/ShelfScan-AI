package com.shelfscanai.dto;

public record ScanConfirmRequest(
        Long matchedBookId,

        String canonicalTitle,
        String canonicalAuthor,
        String canonicalDescription,
        String canonicalTagsJson,

        String customTitle,
        String customTagsJson
) {}