package com.shelfscanai.service;

import org.springframework.stereotype.Component;

// Riceve due header che EasyAuth aggiunge alla richiesta inoltrata al backend (X-MS-CLIENT-PRINCIPAL-ID e X-MS-CLIENT-PRINCIPAL-NAME)
@Component
public class EasyAuthUserExtractor {
    public String getUserKey(String principalId, String principalName) {
        if (principalId != null && !principalId.isBlank()) return principalId; //identificativo principale perchè più stabile.
        if (principalName != null && !principalName.isBlank()) return principalName; //se manca usa quest'altro
        return null; //mancano entrambi = NON AUTENTICATO!
    }
}