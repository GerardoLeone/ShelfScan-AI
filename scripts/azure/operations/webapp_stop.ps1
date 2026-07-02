$rg = "rg-shelfscan-dev"
$app = "shelfscanai-dev"

Write-Host "Stopping Web App '$app'..."

az webapp stop -g $rg -n $app

Write-Host "Waiting for Web App to reach Stopped state..."

do {
    $state = az webapp show `
        -g $rg `
        -n $app `
        --query "state" `
        -o tsv

    Write-Host "Current state: $state"

    if ($state -ne "Stopped") {
        Start-Sleep -Seconds 5
    }

} while ($state -ne "Stopped")

Write-Host "Web App is Stopped."