package com.shelfscanai.controller;

import com.shelfscanai.dto.ScanConfirmRequest;
import com.shelfscanai.dto.ScanPreviewResponse;
import com.shelfscanai.dto.ScanResponse;
import com.shelfscanai.exception.GeminiScanException;
import com.shelfscanai.service.EasyAuthUserExtractor;
import com.shelfscanai.service.ScanService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api/scan")
public class ScanController {

    private final ScanService scanService;
    private final EasyAuthUserExtractor easyAuthUserExtractor;

    @PostMapping(value = "/preview", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> preview(
            @RequestPart("image") MultipartFile image,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) String author,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,  //HEADER AGGIUNTI DA EASY AUTH
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) throws Exception {

        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        ScanPreviewResponse resp = scanService.preview(image, title, author, userKey);
        return ResponseEntity.ok(resp);
    }

    @ExceptionHandler(GeminiScanException.class)
    public ResponseEntity<?> handleGeminiScanException(GeminiScanException e) {
        return ResponseEntity.status(502).body(e.getMessage());
    }

    @PostMapping(value = "/confirm", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> confirm(
            @RequestPart("image") MultipartFile image,
            @RequestParam(required = false) Long matchedBookId,

            @RequestParam String canonicalTitle,
            @RequestParam(required = false) String canonicalAuthor,
            @RequestParam(required = false) String canonicalDescription,
            @RequestParam(required = false) String canonicalTagsJson,

            @RequestParam(required = false) String customTitle,
            @RequestParam(required = false) String customTagsJson,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) throws Exception {

        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        ScanConfirmRequest req = new ScanConfirmRequest(
                matchedBookId,
                canonicalTitle,
                canonicalAuthor,
                canonicalDescription,
                canonicalTagsJson,
                customTitle,
                customTagsJson
        );

        ScanResponse resp = scanService.confirm(image, req, userKey);
        return ResponseEntity.ok(resp);
    }
}