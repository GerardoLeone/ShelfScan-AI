$rg = "rg-shelfscan-dev"
$server = "shelfscan-sql-dev"
$db = "shelfscan-dev-db"

Write-Host "Scaling Azure SQL Database to low-cost serverless configuration..."

az sql db update `
  --resource-group $rg `
  --server $server `
  --name $db `
  --edition GeneralPurpose `
  --compute-model Serverless `
  --family Gen5 `
  --capacity 1 `
  --min-capacity 0.5 `
  --auto-pause-delay 60

Write-Host "Done. SQL Database optimized for idle periods."