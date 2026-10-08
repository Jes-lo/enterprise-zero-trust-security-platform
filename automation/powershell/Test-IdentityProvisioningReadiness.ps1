#Requires -Version 7.2

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (
    git rev-parse --show-toplevel
).Trim()

Set-Location $Root

$IdentityConfigPath = "configs/identity-foundation.json"
$ProvisioningConfigPath = "configs/identity-provisioning.json"
$OutputPath = "local-evidence/identity-provisioning-readiness.json"

foreach ($Path in @(
    $IdentityConfigPath,
    $ProvisioningConfigPath
)) {
    if (-not (Test-Path $Path)) {
        throw "Required configuration missing: $Path"
    }
}

if (-not (
    Get-Module -ListAvailable -Name Microsoft.Graph.Authentication
)) {
    throw "Microsoft.Graph.Authentication is not installed."
}

Import-Module Microsoft.Graph.Authentication

$Identity = Get-Content `
    -Raw `
    $IdentityConfigPath |
    ConvertFrom-Json

$Provisioning = Get-Content `
    -Raw `
    $ProvisioningConfigPath |
    ConvertFrom-Json

$UsageLocation = ""

while ($UsageLocation -notmatch '^[A-Z]{2}$') {
    $UsageLocation = (
        Read-Host "Usage location (ISO two-letter code, for example MX)"
    ).Trim().ToUpperInvariant()

    if ($UsageLocation -notmatch '^[A-Z]{2}$') {
        Write-Warning (
            "Enter exactly two letters, for example MX."
        )
    }
}

$RequiredScopes = @(
    "User.ReadBasic.All",
    "GroupMember.Read.All",
    "LicenseAssignment.Read.All"
)

try {
    Connect-MgGraph `
        -Scopes $RequiredScopes `
        -ContextScope Process `
        -NoWelcome

    $Context = Get-MgContext

    if ($null -eq $Context) {
        throw "Microsoft Graph context unavailable."
    }

    foreach ($Scope in $RequiredScopes) {
        if ($Scope -notin $Context.Scopes) {
            throw "Required Graph scope missing: $Scope"
        }
    }

    $UsersResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "users?`$select=id,displayName,userPrincipalName&`$top=999"
        )

    $GroupsResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "groups?`$select=id,displayName,mailNickname&`$top=999"
        )

    $SkuResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"

    $ExistingUsers = @($UsersResponse.value)
    $ExistingGroups = @($GroupsResponse.value)

    $BootstrapMatches = @(
        $ExistingUsers |
        Where-Object {
            $_.userPrincipalName -and
            $_.userPrincipalName.Split("@")[0].ToLowerInvariant() -eq
            "bootstrapadmin"
        }
    )

    if ($BootstrapMatches.Count -ne 1) {
        throw (
            "Expected exactly one bootstrapadmin identity; found " +
            $BootstrapMatches.Count
        )
    }

    $BootstrapUpn = (
        [string]$BootstrapMatches[0].userPrincipalName
    ).ToLowerInvariant()

    $UpnParts = $BootstrapUpn.Split("@")

    if (
        $UpnParts.Count -ne 2 -or
        [string]::IsNullOrWhiteSpace($UpnParts[1])
    ) {
        throw "Bootstrap account UPN has an invalid format."
    }

    $TenantDomain = $UpnParts[1]

    $SpbMatches = @(
        $SkuResponse.value |
        Where-Object {
            $_.skuPartNumber -eq "SPB"
        }
    )

    if ($SpbMatches.Count -ne 1) {
        throw (
            "Expected exactly one Business Premium SPB SKU; found " +
            $SpbMatches.Count
        )
    }

    $Spb = $SpbMatches[0]

    $Enabled = [int]$Spb.prepaidUnits.enabled
    $Warning = [int]$Spb.prepaidUnits.warning
    $Consumed = [int]$Spb.consumedUnits

    $Available = [Math]::Max(
        0,
        $Enabled - $Warning - $Consumed
    )

    $PlannedUsers = @(
        $Identity.accounts |
        Where-Object {
            $_.live_creation -eq $true
        }
    )

    $LicensedUsers = @(
        $PlannedUsers |
        Where-Object {
            $_.license_policy -eq "business-premium"
        }
    )

    $PlannedGroups = @($Identity.groups)

    $ExistingPlannedUsers = @()

    foreach ($Account in $PlannedUsers) {
        $DesiredUpn = (
            $Account.alias +
            "@" +
            $TenantDomain
        ).ToLowerInvariant()

        $Match = @(
            $ExistingUsers |
            Where-Object {
                $_.userPrincipalName.ToLowerInvariant() -eq
                $DesiredUpn
            }
        )

        if ($Match.Count -gt 0) {
            $ExistingPlannedUsers += $Account.id
        }
    }

    $ExistingPlannedGroups = @()

    foreach ($Group in $PlannedGroups) {
        $Match = @(
            $ExistingGroups |
            Where-Object {
                $_.displayName -eq $Group.display_name -or
                $_.mailNickname -eq $Group.mail_nickname
            }
        )

        if ($Match.Count -gt 0) {
            $ExistingPlannedGroups += $Group.id
        }
    }

    $BootstrapExists = $false

    foreach ($User in $ExistingUsers) {
        if (-not $User.userPrincipalName) {
            continue
        }

        $Alias = (
            $User.userPrincipalName.Split("@")[0]
        ).ToLowerInvariant()

        if ($Alias -eq "bootstrapadmin") {
            $BootstrapExists = $true
            break
        }
    }

    if ($Available -lt $LicensedUsers.Count) {
        throw (
            "Insufficient Business Premium capacity. Required=" +
            $LicensedUsers.Count +
            " Available=" +
            $Available
        )
    }

    $Result = [ordered]@{
        schema_version = "1.0"
        evidence_type = "identity-provisioning-readiness"
        write_operations_performed = $false

        tenant_input = [ordered]@{
            tenant_domain_auto_detected = $true
            tenant_domain_persisted = $false
            usage_location_supplied = $true
            usage_location_persisted = $false
        }

        graph = [ordered]@{
            authentication_type = [string]$Context.AuthType
            required_read_only_scopes = @(
                $RequiredScopes |
                Sort-Object
            )
        }

        identity_plan = [ordered]@{
            users_to_create = $PlannedUsers.Count
            licensed_users = $LicensedUsers.Count
            groups_to_create = $PlannedGroups.Count
        }

        current_state = [ordered]@{
            bootstrap_account_detected = $BootstrapExists
            planned_users_already_present = @(
                $ExistingPlannedUsers |
                Sort-Object
            )
            planned_groups_already_present = @(
                $ExistingPlannedGroups |
                Sort-Object
            )
        }

        business_premium = [ordered]@{
            enabled_units = $Enabled
            warning_units = $Warning
            consumed_units = $Consumed
            safely_available_units = $Available
            required_units = $LicensedUsers.Count
            capacity_sufficient = (
                $Available -ge $LicensedUsers.Count
            )
        }
    }

    New-Item `
        -ItemType Directory `
        -Path "local-evidence" `
        -Force |
        Out-Null

    $Result |
        ConvertTo-Json -Depth 10 |
        Set-Content `
            -Path $OutputPath `
            -Encoding utf8

    if ($IsLinux) {
        & chmod 600 -- $OutputPath
    }

    Write-Host ""
    Write-Host "READ-ONLY PREFLIGHT"
    Write-Host "-------------------"
    Write-Host "bootstrap_detected=$BootstrapExists"
    Write-Host "planned_users=$($PlannedUsers.Count)"
    Write-Host "licensed_users=$($LicensedUsers.Count)"
    Write-Host "planned_groups=$($PlannedGroups.Count)"
    Write-Host "spb_available=$Available"
    Write-Host (
        "existing_planned_users=" +
        $ExistingPlannedUsers.Count
    )
    Write-Host (
        "existing_planned_groups=" +
        $ExistingPlannedGroups.Count
    )
    Write-Host ""
    Write-Host (
        "PASS: sanitized readiness written to " +
        $OutputPath
    )
}
finally {
    Disconnect-MgGraph `
        -ErrorAction SilentlyContinue |
        Out-Null
}
