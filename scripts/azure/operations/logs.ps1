$rg = "rg-shelfscan-dev"
$app = "shelfscanai-dev"

az webapp log tail --resource-group $rg --name $app