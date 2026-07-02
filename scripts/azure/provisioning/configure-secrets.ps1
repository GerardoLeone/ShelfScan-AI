# scripts/azure/provisioning/configure-secrets.ps1

$ErrorActionPreference = "Stop"

$ResourceGroup = "rg-shelfscan-dev"
$KeyVault = "shelfscan-kv-dev"
$StorageAccount = "shelfscanaccountstorage"
$BlobContainer = "covers"
$SqlServer = "shelfscan-sql-dev"
$SqlDatabase = "shelfscan-dev-db"

Write-Host "== ShelfScan AI Key Vault Secret Configuration ==" -ForegroundColor Cyan
Write-Host "No secret value will be written to the repository."

az account show 1>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Running az login..."
    az login
}

# Storage connection string generated automatically
Write-Host "Generating Blob Storage connection string..."
$blobConnectionString = az storage account show-connection-string `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --query "connectionString" `
    -o tsv

# SQL values
$sqlUsername = Read-Host "SQL username"
$sqlPasswordSecure = Read-Host "SQL password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPasswordSecure)
$sqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$sqlUrl = "jdbc:sqlserver://$SqlServer.database.windows.net:1433;database=$SqlDatabase;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"

# Gemini API key
$geminiApiKeySecure = Read-Host "Gemini API key" -AsSecureString
$BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($geminiApiKeySecure)
$geminiApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)

Write-Host "Updating Key Vault secrets..."

az keyvault secret set `
    --vault-name $KeyVault `
    --name "spring-datasource-url" `
    --value "$sqlUrl" `
    1>$null

az keyvault secret set `
    --vault-name $KeyVault `
    --name "spring-datasource-username" `
    --value "$sqlUsername" `
    1>$null

az keyvault secret set `
    --vault-name $KeyVault `
    --name "spring-datasource-password" `
    --value "$sqlPassword" `
    1>$null

az keyvault secret set `
    --vault-name $KeyVault `
    --name "app-blob-connection-string" `
    --value "$blobConnectionString" `
    1>$null

az keyvault secret set `
    --vault-name $KeyVault `
    --name "app-blob-container" `
    --value "$BlobContainer" `
    1>$null

az keyvault secret set `
    --vault-name $KeyVault `
    --name "app-gemini-api-key" `
    --value "$geminiApiKey" `
    1>$null

Write-Host ""
Write-Host "Key Vault secrets configured successfully." -ForegroundColor Green