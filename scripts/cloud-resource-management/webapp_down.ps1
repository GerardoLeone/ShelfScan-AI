$rg = "rg-shelfscan-dev"
$app = "shelfscanai-dev"
$plan = "ASP-rgshelfscandev-bdeb"

Write-Host "Disabling Always On..."
az webapp config set --resource-group $rg --name $app --always-on false

Write-Host "Scaling App Service Plan down to Free F1..."
az appservice plan update --resource-group $rg --name $plan --sku F1

Write-Host "Done."