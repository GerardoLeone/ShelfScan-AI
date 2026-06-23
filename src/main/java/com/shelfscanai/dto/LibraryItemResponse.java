package com.shelfscanai.dto;

import com.shelfscanai.entity.ReadingStatus;

import java.time.OffsetDateTime;
import java.util.List;

public record LibraryItemResponse(
        Long bookId,
        String title,
        String author,
        String coverUrl,
        String description,
        List<String> tags,
        ReadingStatus status,
        Integer currentPage,
        OffsetDateTime updatedAt
) {}