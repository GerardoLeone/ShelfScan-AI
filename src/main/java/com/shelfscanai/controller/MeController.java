package com.shelfscanai.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class MeController {

    @GetMapping("/api/me")
    public ResponseEntity<Map<String, Object>> me(
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-NAME", required = false) String principalName,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL-ID", required = false) String principalId,
            @RequestHeader(value = "X-MS-CLIENT-PRINCIPAL", required = false) String rawPrincipal
    ) {
        Map<String, Object> res = new LinkedHashMap<>();
        res.put("principalName", principalName);
        res.put("principalId", principalId);
        res.put("hasRawPrincipal", rawPrincipal != null && !rawPrincipal.isBlank());
        res.put("rawLength", rawPrincipal == null ? 0 : rawPrincipal.length());
        return ResponseEntity.ok(res);
    }
}
