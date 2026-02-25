package com.shelfscanai.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class GeminiRequests {

    public static Map<String, Object> buildExtractRequest(String mimeType, String base64) {
        return Map.of(
                "contents", List.of(
                        Map.of(
                                "role", "user",
                                "parts", List.of(
                                        Map.of("text", Prompts.EXTRACT_PROMPT),
                                        Map.of("inline_data", Map.of(
                                                "mime_type", mimeType,
                                                "data", base64
                                        ))
                                )
                        )
                ),
                "generationConfig", new LinkedHashMap<>(Map.of(
                        "temperature", 0.1,
                        "maxOutputTokens", 256,
                        "response_mime_type", "application/json",
                        "response_schema", Map.of(
                                "type", "OBJECT",
                                "properties", Map.of(
                                        "title", Map.of("type", "STRING", "nullable", true),
                                        "author", Map.of("type", "STRING", "nullable", true),
                                        "confidence", Map.of("type", "NUMBER"),
                                        "notes", Map.of("type", "STRING")
                                ),
                                "required", List.of("confidence", "notes")
                        )
                ))
        );
    }

    public static Map<String, Object> buildEnrichRequest(String mimeType, String base64, String title, String author) {
        String prompt = Prompts.enrichPrompt(title, author);

        return Map.of(
                "contents", List.of(
                        Map.of(
                                "role", "user",
                                "parts", List.of(
                                        Map.of("text", prompt),
                                        Map.of("inline_data", Map.of(
                                                "mime_type", mimeType,
                                                "data", base64
                                        ))
                                )
                        )
                ),
                "generationConfig", new LinkedHashMap<>(Map.of(
                        "temperature", 0.4,
                        "maxOutputTokens", 512,
                        "response_mime_type", "application/json",
                        "response_schema", Map.of(
                                "type", "OBJECT",
                                "properties", Map.of(
                                        "author", Map.of("type", "STRING"),
                                        "description", Map.of("type", "STRING"),
                                        "tags", Map.of(
                                                "type", "ARRAY",
                                                "items", Map.of("type", "STRING")
                                        ),
                                        "confidence", Map.of("type", "NUMBER")
                                ),
                                "required", List.of("description", "tags", "confidence")
                        )
                ))
        );
    }
}