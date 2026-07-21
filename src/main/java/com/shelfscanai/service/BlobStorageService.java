package com.shelfscanai.service;

import com.azure.storage.blob.*;
import com.azure.storage.blob.models.BlobStorageException;
import com.azure.storage.blob.sas.BlobSasPermission;
import com.azure.storage.blob.sas.BlobServiceSasSignatureValues;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URI;
import java.time.OffsetDateTime;
import java.util.Objects;
import java.util.UUID;

@Service
public class BlobStorageService {

    private final BlobContainerClient containerClient;

    //All'avvio del Bean crea il servizio
    public BlobStorageService( //Spring inietta connection string e containerName
            @Value("${app.blob.connection-string}") String connStr,
            @Value("${app.blob.container}") String containerName
    ) {
        BlobServiceClient serviceClient = new BlobServiceClientBuilder()
                .connectionString(connStr)
                .buildClient(); //creazione client

        this.containerClient = serviceClient.getBlobContainerClient(containerName); //recupera il container

        try {
            if (!this.containerClient.exists()) {
                this.containerClient.create(); //se non esiste, lo crea
            }
        } catch (BlobStorageException ex) {
            throw new IllegalStateException("Errore inizializzando Blob container: " + ex.getMessage(), ex);
        }
    }

    public String upload(MultipartFile file) throws IOException {
        String original = Objects.requireNonNullElse(file.getOriginalFilename(), "cover.jpg"); //prende il nome originale del file (se manca usa cover.jpg)
        String blobName = UUID.randomUUID() + "-" + original; //genera nome univoco (con un randomUUID)

        //Carica il file
        BlobClient blobClient = containerClient.getBlobClient(blobName);
        blobClient.upload(file.getInputStream(), file.getSize(), true); //sovrascrittura abilitata (altamente improbabile)

        // Nel DB continuiamo a salvare l'URL pulito, senza SAS.
        //Questo perchè il container è privato, l'URL pulito da solo non permette la lettura pubblica.
        return blobClient.getBlobUrl();
    }

    // prende l'URL salvato dal DB
    public String generateReadSasUrl(String storedCoverUrl) {
        if (storedCoverUrl == null || storedCoverUrl.isBlank()) {
            return null;
        }

        //Ricava il nome del blob
        String blobName = extractBlobName(storedCoverUrl);

        //crea blob client con permesso SOLO LETTURA
        BlobClient blobClient = containerClient.getBlobClient(blobName);

        BlobSasPermission permissions = new BlobSasPermission()
                .setReadPermission(true);

        // token scade dopo 30 minuti
        BlobServiceSasSignatureValues values = new BlobServiceSasSignatureValues(
                OffsetDateTime.now().plusMinutes(30),
                permissions
        );

        // Genera token
        String sasToken = blobClient.generateSas(values);

        return blobClient.getBlobUrl() + "?" + sasToken;
    }

    //Nel database potrebbe esserci nome-file.jpg oppure /container/nome-file.jpg oppure l'url completo (https://account.blob.core.windows.net/container/nome-file.jpg)
    // questo metodo normalizza tutti questi casi e restituisce il nome relativo del blob
    private String extractBlobName(String storedCoverUrl) {
        String value = storedCoverUrl.trim();

        if (!value.startsWith("http://") && !value.startsWith("https://")) {
            return removeLeadingSlash(value);
        }

        URI uri = URI.create(value);
        String path = removeLeadingSlash(uri.getPath());

        String containerName = containerClient.getBlobContainerName();

        if (path.startsWith(containerName + "/")) {
            return path.substring(containerName.length() + 1);
        }

        return path;
    }

    private String removeLeadingSlash(String value) {
        while (value.startsWith("/")) {
            value = value.substring(1);
        }
        return value;
    }
}