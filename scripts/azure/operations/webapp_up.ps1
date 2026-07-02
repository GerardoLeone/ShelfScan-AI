$rg = "rg-shelfscan-dev"
$app = "shelfscanai-dev"
$plan = "ASP-rgshelfscandev-bdeb"

Write-Host "Scaling App Service Plan up to Basic B1..."
az appservice plan update --resource-group $rg --name $plan --sku B1

Write-Host "Enabling Always On..."
az webapp config set --resource-group $rg --name $app --always-on true

Write-Host "Done."