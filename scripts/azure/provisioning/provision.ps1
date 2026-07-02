# scripts/azure/provisioning/provision.ps1

$ErrorActionPreference = "Stop"

# =========================
# ShelfScan AI - Azure Provisioning
# Non-destructive provisioning script
# =========================

$ResourceGroup = "rg-shelfscan-dev"
$Location = "francecentral"

$StorageAccount = "shelfscanaccountstorage"
$BlobContainer = "covers"

$KeyVault = "shelfscan-kv-dev"

$SqlServer = "shelfscan-sql-dev"
$SqlDatabase = "shelfscan-dev-db"
$SqlAdminUser = "shelfscanadmin"

$AppServicePlan = "ASP-rgshelfscandev-bdeb"
$WebApp = "shelfscanai-dev"

$AppInsights = "shelfscan-insights-dev"

Write-Host "== ShelfScan AI Azure Provisioning ==" -ForegroundColor Cyan

# Check Azure CLI login
Write-Host "Checking Azure login..."
az account show 1>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in. Running az login..."
    az login
}

# Resource Group
Write-Host "Checking Resource Group: $ResourceGroup"
$rgExists = az group exists --name $ResourceGroup | ConvertFrom-Json

if (-not $rgExists) {
    Write-Host "Creating Resource Group..."
    az group create `
        --name $ResourceGroup `
        --location $Location `
        1>$null
} else {
    Write-Host "Resource Group already exists."
}

# Storage Account
Write-Host "Checking Storage Account: $StorageAccount"
$storageExists = az storage account show `
    --name $StorageAccount `
    --resource-group $ResourceGroup `
    --query "name" `
    -o tsv 2>$null

if (-not $storageExists) {
    Write-Host "Creating Storage Account..."
    az storage account create `
        --name $StorageAccount `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --min-tls-version TLS1_2 `
        --https-only true `
        --allow-blob-public-access false `
        --public-network-access Enabled `
        1>$null
} else {
    Write-Host "Storage Account already exists."
}

# Blob container
Write-Host "Checking Blob Container: $BlobContainer"
az storage container create `
    --name $BlobContainer `
    --account-name $StorageAccount `
    --auth-mode login `
    --public-access off `
    1>$null

# Key Vault
Write-Host "Checking Key Vault: $KeyVault"
$kvExists = az keyvault show `
    --name $KeyVault `
    --resource-group $ResourceGroup `
    --query "name" `
    -o tsv 2>$null

if (-not $kvExists) {
    Write-Host "Creating Key Vault..."
    az keyvault create `
        --name $KeyVault `
        --resource-group $ResourceGroup `
        --location $Location `
        --enable-rbac-authorization false `
        1>$null
} else {
    Write-Host "Key Vault already exists."
}

# SQL Server
Write-Host "Checking SQL Server: $SqlServer"
$sqlServerExists = az sql server show `
    --name $SqlServer `
    --resource-group $ResourceGroup `
    --query "name" `
    -o tsv 2>$null

if (-not $sqlServerExists) {
    Write-Host "SQL Server missing."
    Write-Host "SQL admin password is required only when creating the server."
    $SecurePassword = Read-Host "Enter SQL admin password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $SqlAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    az sql server create `
        --name $SqlServer `
        --resource-group $ResourceGroup `
        --location $Location `
        --admin-user $SqlAdminUser `
        --admin-password $SqlAdminPassword `
        1>$null
} else {
    Write-Host "SQL Server already exists."
}

# SQL firewall: allow Azure services
Write-Host "Configuring SQL firewall: Allow Azure services"
az sql server firewall-rule create `
    --resource-group $ResourceGroup `
    --server $SqlServer `
    --name "AllowAzureServices" `
    --start-ip-address 0.0.0.0 `
    --end-ip-address 0.0.0.0 `
    1>$null 2>$null

# SQL Database
Write-Host "Checking SQL Database: $SqlDatabase"
$sqlDbExists = az sql db show `
    --name $SqlDatabase `
    --server $SqlServer `
    --resource-group $ResourceGroup `
    --query "name" `
    -o tsv 2>$null

if (-not $sqlDbExists) {
    Write-Host "Creating SQL Database..."
    az sql db create `
        --resource-group $ResourceGroup `
        --server $SqlServer `
        --name $SqlDatabase `
        --edition GeneralPurpose `
        --family Gen5 `
        --capacity 1 `
        --compute-model Serverless `
        --auto-pause-delay 60 `
        --backup-storage-redundancy Local `
        --zone-redundant false `
        1>$null
} else {
    Write-Host "SQL Database already exists."
}

# App Service Plan
Write-Host "Checking App Service Plan: $AppServicePlan"
$planExists = az appservice plan show `
    --name $AppServicePlan `
    --resource-group $ResourceGroup `
    --query "name" `
    -o tsv 2>$null

if (-not $planExists) {
    Write-Host "Creating App Service Plan..."
    az appservice plan create `
        --name $AppServicePlan `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku B1 `
        --is-linux `
        --number-of-workers 1 `
        1>$null
} else {
    Write-Host "App Service Plan already exists."
}

# Web App
Write-Host "Checking Web App: $WebApp"
$webAppExists = az webapp show `
    --name $WebApp `
    --resource-group $ResourceGroup `
    --query "name" `
    -o tsv 2>$null

if (-not $webAppExists) {
    Write-Host "Creating Web App..."
    az webapp create `
        --name $WebApp `
        --resource-group $ResourceGroup `
        --plan $AppServicePlan `
        --runtime "JAVA:25-java25" `
        1>$null
} else {
    Write-Host "Web App already exists."
}

# Managed Identity
Write-Host "Enabling Managed Identity on Web App..."
$principalId = az webapp identity assign `
    --name $WebApp `
    --resource-group $ResourceGroup `
    --query "principalId" `
    -o tsv

# Key Vault access policy
Write-Host "Assigning Key Vault secret permissions to Web App Managed Identity..."
az keyvault set-policy `
    --name $KeyVault `
    --object-id $principalId `
    --secret-permissions get list `
    1>$null

# Application Insights
Write-Host "Checking Application Insights: $AppInsights"
$appInsightsExists = az resource show `
    --resource-group $ResourceGroup `
    --name $AppInsights `
    --resource-type "Microsoft.Insights/components" `
    --query "name" `
    -o tsv 2>$null

if (-not $appInsightsExists) {
    Write-Host "Creating Application Insights..."
    az resource create `
    --resource-group $ResourceGroup `
    --name $AppInsights `
    --resource-type "Microsoft.Insights/components" `
    --location $Location `
    --properties '{"Application_Type":"web"}' `
    1>$null
} else {
    Write-Host "Application Insights already exists."
}

# Link Application Insights to Web App
Write-Host "Configuring Application Insights app settings..."
$aiConnectionString = az resource show `
    --resource-group $ResourceGroup `
    --name $AppInsights `
    --resource-type "Microsoft.Insights/components" `
    --query "properties.ConnectionString" `
    -o tsv

$aiInstrumentationKey = az resource show `
    --resource-group $ResourceGroup `
    --name $AppInsights `
    --resource-type "Microsoft.Insights/components" `
    --query "properties.InstrumentationKey" `
    -o tsv

az webapp config appsettings set `
    --name $WebApp `
    --resource-group $ResourceGroup `
    --settings `
        APPLICATIONINSIGHTS_CONNECTION_STRING="$aiConnectionString" `
        APPINSIGHTS_INSTRUMENTATIONKEY="$aiInstrumentationKey" `
        ApplicationInsightsAgent_EXTENSION_VERSION="~3" `
        SPRING_PROFILES_ACTIVE="prod" `
    1>$null

Write-Host ""
Write-Host "Provisioning completed successfully." -ForegroundColor Green
Write-Host "Remember: secrets are handled separately through configure-secrets.ps1"