$rg = "rg-shelfscan-dev"
$app = "shelfscanai-dev"
$jarName = "ShelfScan-AI-0.0.1-SNAPSHOT.jar"
$root = Join-Path $PSScriptRoot "..\.."

Set-Location $root

Write-Host "Building backend..."
.\gradlew clean bootJar
if ($LASTEXITCODE -ne 0) {
  throw "Build fallita"
}

Write-Host "Copying JAR to app.jar..."
Copy-Item ".\build\libs\$jarName" ".\app.jar" -Force

Write-Host "Checking app.jar..."
Get-Item ".\app.jar" | Select-Object Name, Length, LastWriteTime

Write-Host "Deploying app.jar to Azure App Service..."
az webapp deploy `
  --resource-group $rg `
  --name $app `
  --src-path ".\app.jar" `
  --type jar `
  --restart true

if ($LASTEXITCODE -ne 0) {
  throw "Deploy fallito"
}

Write-Host "Deploy completed."