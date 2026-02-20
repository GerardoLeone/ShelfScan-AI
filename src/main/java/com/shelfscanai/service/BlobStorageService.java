package com.shelfscanai.service;

import com.azure.storage.blob.*;
import com.azure.storage.blob.models.BlobStorageException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
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

        return blobClient.getBlobUrl();
    }
}