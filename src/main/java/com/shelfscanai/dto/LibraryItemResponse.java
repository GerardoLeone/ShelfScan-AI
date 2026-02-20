package com.shelfscanai.dto;

import com.shelfscanai.entity.ReadingStatus;

import java.time.OffsetDateTime;

public record LibraryItemResponse(
        Long bookId,
        String title,
        String author,
        String coverUrl,
        ReadingStatus status,
        OffsetDateTime updatedAt
) {}
