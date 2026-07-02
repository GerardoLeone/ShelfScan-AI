$ErrorActionPreference = "Stop"

$ResourceGroup = "rg-shelfscan-dev"
$Location = "francecentral"

$StorageAccount = "shelfscanaccountstorage"
$BlobContainer = "covers"

$KeyVault = "shelfscan-kv-dev"

$SqlServer = "shelfscan-sql-dev"
$SqlDatabase = "shelfscan-dev-db"

$AppServicePlan = "ASP-rgshelfscandev-bdeb"
$WebApp = "shelfscanai-dev"

$AppInsights = "shelfscan-insights-dev"

Write-Host "== ShelfScan AI - Read-only provisioning validation ==" -ForegroundColor Cyan

function Check($Label, $Command) {
    Write-Host "`nChecking $Label..."
    try {
        Invoke-Expression $Command | Out-Null
        Write-Host "[OK] $Label" -ForegroundColor Green
    }
    catch {
        Write-Host "[MISSING/ERROR] $Label" -ForegroundColor Red
    }
}

Check "Resource Group" "az group show --name $ResourceGroup"
Check "Storage Account" "az storage account show --name $StorageAccount --resource-group $ResourceGroup"
Check "Blob Container" "az storage container show --name $BlobContainer --account-name $StorageAccount --auth-mode login"
Check "Key Vault" "az keyvault show --name $KeyVault --resource-group $ResourceGroup"
Check "SQL Server" "az sql server show --name $SqlServer --resource-group $ResourceGroup"
Check "SQL Database" "az sql db show --name $SqlDatabase --server $SqlServer --resource-group $ResourceGroup"
Check "App Service Plan" "az appservice plan show --name $AppServicePlan --resource-group $ResourceGroup"
Check "Web App" "az webapp show --name $WebApp --resource-group $ResourceGroup"
Check "Application Insights" "az resource show --resource-group $ResourceGroup --name $AppInsights --resource-type 'Microsoft.Insights/components'"

Write-Host "`nChecking Web App Managed Identity..."
$principalId = az webapp identity show `
    --name $WebApp `
    --resource-group $ResourceGroup `
    --query "principalId" `
    -o tsv

if ($principalId) {
    Write-Host "[OK] Managed Identity enabled: $principalId" -ForegroundColor Green
} else {
    Write-Host "[MISSING] Managed Identity not enabled" -ForegroundColor Red
}

Write-Host "`nChecking Application Insights settings..."
$appSettings = az webapp config appsettings list `
    --name $WebApp `
    --resource-group $ResourceGroup `
    --query "[].name" `
    -o tsv

$requiredSettings = @(
    "APPLICATIONINSIGHTS_CONNECTION_STRING",
    "APPINSIGHTS_INSTRUMENTATIONKEY",
    "ApplicationInsightsAgent_EXTENSION_VERSION"
)

foreach ($setting in $requiredSettings) {
    if ($appSettings -contains $setting) {
        Write-Host "[OK] $setting" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $setting" -ForegroundColor Yellow
    }
}

Write-Host "`nChecking Key Vault secrets..."
$secrets = az keyvault secret list `
    --vault-name $KeyVault `
    --query "[].name" `
    -o tsv

$requiredSecrets = @(
    "app-blob-connection-string",
    "app-blob-container",
    "app-gemini-api-key",
    "spring-datasource-password",
    "spring-datasource-url",
    "spring-datasource-username"
)

foreach ($secret in $requiredSecrets) {
    if ($secrets -contains $secret) {
        Write-Host "[OK] $secret" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $secret" -ForegroundColor Yellow
    }
}

Write-Host "`nValidation completed. No resources were created, modified, or deleted." -ForegroundColor Cyan