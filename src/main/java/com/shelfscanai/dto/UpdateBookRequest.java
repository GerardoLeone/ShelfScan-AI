package com.shelfscanai.dto;

import java.util.List;

public record UpdateBookRequest(
        String title,
        String author,
        String description,
        List<String> tags
) {}