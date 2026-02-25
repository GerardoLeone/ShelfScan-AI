package com.shelfscanai.service;

import com.shelfscanai.dto.GeminiGenerateContentResponse;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

@Service
public class GeminiClient {

    private final WebClient webClient;
    private final String apiKey;

    public GeminiClient(WebClient.Builder builder,
                        org.springframework.core.env.Environment env) {
        this.webClient = builder
                .baseUrl("https://generativelanguage.googleapis.com")
                .build();
        this.apiKey = env.getProperty("app.gemini.api-key");
        if (this.apiKey == null || this.apiKey.isBlank()) {
            throw new IllegalStateException("Missing app.gemini.api-key");
        }
    }

    public Mono<GeminiGenerateContentResponse> generateContent(String model, Object requestBody) {
        return webClient.post()
                .uri(uriBuilder -> uriBuilder
                        .path("/v1beta/models/{model}:generateContent")
                        .queryParam("key", apiKey)
                        .build(model))
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .bodyValue(requestBody)
                .retrieve()
                .onStatus(
                        status -> status.is4xxClientError() || status.is5xxServerError(),
                        resp -> resp.bodyToMono(String.class).flatMap(body -> {
                            // LOG: qui avrai la spiegazione vera del 400
                            return Mono.error(new RuntimeException("Gemini error " + resp.statusCode() + ": " + body));
                        })
                )
                .bodyToMono(GeminiGenerateContentResponse.class);
    }
}