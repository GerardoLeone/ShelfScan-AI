package com.shelfscanai.dto;

import java.util.List;

public record UpdateLibraryItemRequest(
        String customTitle,
        List<String> customTags
) {}