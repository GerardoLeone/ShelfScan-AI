package com.shelfscanai.controller;

import com.shelfscanai.dto.ScanResponse;
import com.shelfscanai.service.EasyAuthUserExtractor;
import com.shelfscanai.service.ScanService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequiredArgsConstructor
@RequestMapping("/api")
public class ScanController {

    private final ScanService scanService;
    private final EasyAuthUserExtractor easyAuthUserExtractor;

    @PostMapping(value = "/scan", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> scan(
            @RequestPart("image") MultipartFile image,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) String author,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName
    ) throws Exception {

        String userKey = easyAuthUserExtractor.getUserKey(principalId, principalName);
        if (userKey == null) return ResponseEntity.status(401).body("Not authenticated");

        ScanResponse resp = scanService.scan(image, title, author, userKey);
        return ResponseEntity.ok(resp);
    }
}