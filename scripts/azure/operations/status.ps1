$rg = "rg-shelfscan-dev"
$app = "shelfscanai-dev"
$plan = "ASP-rgshelfscandev-bdeb"

az webapp show --resource-group $rg --name $app --query "{name:name,state:state,defaultHostName:defaultHostName}" -o table
az appservice plan show --resource-group $rg --name $plan --query "{name:name,sku:sku.name,tier:sku.tier,capacity:sku.capacity}" -o table