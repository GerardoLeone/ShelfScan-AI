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

    public BlobStorageService(
            @Value("${app.blob.connection-string}") String connStr,
            @Value("${app.blob.container}") String containerName
    ) {
        BlobServiceClient serviceClient = new BlobServiceClientBuilder()
                .connectionString(connStr)
                .buildClient();

        this.containerClient = serviceClient.getBlobContainerClient(containerName);

        try {
            if (!this.containerClient.exists()) {
                this.containerClient.create();
            }
        } catch (BlobStorageException ex) {
            throw new IllegalStateException("Errore inizializzando Blob container: " + ex.getMessage(), ex);
        }
    }

    public String upload(MultipartFile file) throws IOException {
        String original = Objects.requireNonNullElse(file.getOriginalFilename(), "cover.jpg");
        String blobName = UUID.randomUUID() + "-" + original;

        BlobClient blobClient = containerClient.getBlobClient(blobName);
        blobClient.upload(file.getInputStream(), file.getSize(), true);

        // Nel DB continuiamo a salvare l'URL pulito, senza SAS.
        return blobClient.getBlobUrl();
    }

    public String generateReadSasUrl(String storedCoverUrl) {
        if (storedCoverUrl == null || storedCoverUrl.isBlank()) {
            return null;
        }

        String blobName = extractBlobName(storedCoverUrl);

        BlobClient blobClient = containerClient.getBlobClient(blobName);

        BlobSasPermission permissions = new BlobSasPermission()
                .setReadPermission(true);

        BlobServiceSasSignatureValues values = new BlobServiceSasSignatureValues(
                OffsetDateTime.now().plusMinutes(30),
                permissions
        );

        String sasToken = blobClient.generateSas(values);

        return blobClient.getBlobUrl() + "?" + sasToken;
    }

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