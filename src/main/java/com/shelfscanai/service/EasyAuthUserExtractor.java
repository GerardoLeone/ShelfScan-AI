package com.shelfscanai.service;

import org.springframework.stereotype.Component;

@Component
public class EasyAuthUserExtractor {
    public String getUserKey(String principalId, String principalName) {
        if (principalId != null && !principalId.isBlank()) return principalId;
        if (principalName != null && !principalName.isBlank()) return principalName;
        return null;
    }
}