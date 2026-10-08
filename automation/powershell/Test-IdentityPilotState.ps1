#Requires -Version 7.2

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (git rev-parse --show-toplevel).Trim()
Set-Location $Root

$IdentityPath = "configs/identity-foundation.json"
$OperationPath = "local-evidence/pilot-EMPLOYEE_01-operation.json"

foreach ($Path in @(
    $IdentityPath,
    $OperationPath
)) {
    if (-not (Test-Path $Path)) {
        throw "Required file missing: $Path"
    }
}

Import-Module Microsoft.Graph.Authentication

$Identity = Get-Content -Raw $IdentityPath | ConvertFrom-Json
$Operation = Get-Content -Raw $OperationPath | ConvertFrom-Json

$Pilot = @(
    $Identity.accounts |
    Where-Object {
        $_.id -eq "EMPLOYEE_01"
    }
)

if ($Pilot.Count -ne 1) {
    throw "Pilot identity definition invalid."
}

$Pilot = $Pilot[0]

$Scopes = @(
    "User.ReadBasic.All",
    "LicenseAssignment.Read.All"
)

try {
    Connect-MgGraph `
        -Scopes $Scopes `
        -ContextScope Process `
        -NoWelcome

    $User = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/users/" +
            $Operation.object_id +
            "?`$select=id,displayName,userPrincipalName,usageLocation,userType"
        )

    if ($User.id -ne $Operation.object_id) {
        throw "Graph user ID does not match local operation evidence."
    }

    $Alias = (
        [string]$User.userPrincipalName
    ).Split("@")[0].ToLowerInvariant()

    $DisplayMatches = (
        [string]$User.displayName -eq
        [string]$Pilot.display_name
    )

    $AliasMatches = (
        $Alias -eq
        ([string]$Pilot.alias).ToLowerInvariant()
    )

    $UsageMatches = (
        [string]$User.usageLocation -eq
        [string]$Operation.usage_location
    )

    if (-not $DisplayMatches) {
        throw "Live display name does not match contract."
    }

    if (-not $AliasMatches) {
        throw "Live alias does not match contract."
    }

    if (-not $UsageMatches) {
        throw "Live usageLocation does not match local pilot evidence."
    }

    $LicenseDetails = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/users/" +
            $Operation.object_id +
            "/licenseDetails?`$select=skuId"
        )

    $Skus = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"

    $Spb = @(
        $Skus.value |
        Where-Object {
            $_.skuPartNumber -eq "SPB"
        }
    )

    if ($Spb.Count -ne 1) {
        throw "Expected exactly one SPB SKU."
    }

    $Assigned = @(
        $LicenseDetails.value |
        ForEach-Object {
            [string]$_.skuId
        }
    )

    $SpbAssigned = (
        [string]$Spb[0].skuId -in $Assigned
    )

    if (-not $SpbAssigned) {
        throw "Business Premium is not assigned to pilot."
    }

    Write-Host ""
    Write-Host "LIVE PILOT VERIFICATION"
    Write-Host "-----------------------"
    Write-Host "account_id=EMPLOYEE_01"
    Write-Host "user_found=True"
    Write-Host "display_name_matches=$DisplayMatches"
    Write-Host "alias_matches=$AliasMatches"
    Write-Host "usage_location_matches=$UsageMatches"
    Write-Host "business_premium_assigned=$SpbAssigned"
    Write-Host "write_operations_performed=False"
    Write-Host ""
    Write-Host "PASS: live pilot state verified."
}
finally {
    Disconnect-MgGraph `
        -ErrorAction SilentlyContinue |
        Out-Null
}
