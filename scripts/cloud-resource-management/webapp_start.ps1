$rg = "rg-shelfscan-dev"
$app = "shelfscanai-dev"

Write-Host "Starting Web App '$app'..."

az webapp start -g $rg -n $app

Write-Host "Waiting for Web App to reach Running state..."

do {
    $state = az webapp show `
        -g $rg `
        -n $app `
        --query "state" `
        -o tsv

    Write-Host "Current state: $state"

    if ($state -ne "Running") {
        Start-Sleep -Seconds 5
    }

} while ($state -ne "Running")

Write-Host "Web App is Running."