# Azure Provisioning - ShelfScan AI

Questa cartella contiene gli script per automatizzare la configurazione dell'ambiente Azure del progetto ShelfScan AI.

## Script disponibili

### `provision.ps1`

Crea e configura automaticamente le principali risorse Azure del progetto:

- Resource Group
- Storage Account
- Blob container `covers`
- Key Vault
- SQL Server
- SQL Database
- App Service Plan
- App Service
- Managed Identity
- Application Insights
- Permessi dell'App Service verso Key Vault

Lo script è pensato per essere non distruttivo: se una risorsa esiste già, non viene ricreata.

### `configure-secrets.ps1`

Configura i segreti nel Key Vault.

I valori sensibili non sono salvati nel repository. Lo script li richiede in input oppure li genera a partire dalle risorse già presenti, come nel caso della connection string dello Storage Account.

Secret gestiti:

- `spring-datasource-url`
- `spring-datasource-username`
- `spring-datasource-password`
- `app-blob-connection-string`
- `app-blob-container`
- `app-gemini-api-key`

## Validazione read-only

Prima di eseguire il provisioning sull'ambiente reale è disponibile lo script:

### `validate-provisioning.ps1`

Lo script verifica la presenza delle risorse Azure principali, della Managed Identity, dei collegamenti ad Application Insights e dei secret attesi nel Key Vault.

La validazione è read-only.

## Uso

Eseguire da PowerShell:

```powershell
cd scripts/azure/provisioning
.\provision.ps1
.\configure-secrets.ps1