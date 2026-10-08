#Requires -Version 7.2

[CmdletBinding()]
param(
    [ValidateSet("Plan", "Pilot")]
    [string]$Mode = "Plan",

    [string]$UsageLocation,

    [string]$Confirmation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (
    git rev-parse --show-toplevel
).Trim()

Set-Location $Root

$IdentityPath = "configs/identity-foundation.json"
$ProvisioningPath = "configs/identity-provisioning.json"

foreach ($Path in @(
    $IdentityPath,
    $ProvisioningPath
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
    $IdentityPath |
    ConvertFrom-Json

$Provisioning = Get-Content `
    -Raw `
    $ProvisioningPath |
    ConvertFrom-Json

$PilotAccountId = [string]$Provisioning.apply.pilot_account_id

$PilotMatches = @(
    $Identity.accounts |
    Where-Object {
        $_.id -eq $PilotAccountId
    }
)

if ($PilotMatches.Count -ne 1) {
    throw (
        "Expected exactly one pilot account definition; found " +
        $PilotMatches.Count
    )
}

$PilotAccount = $PilotMatches[0]

if (
    $PilotAccount.live_creation -ne $true -or
    $PilotAccount.license_policy -ne "business-premium"
) {
    throw "Pilot account contract is not eligible for live creation."
}

$BootstrapMatches = @(
    $Identity.accounts |
    Where-Object {
        $_.id -eq "BOOTSTRAP_ADMIN"
    }
)

if ($BootstrapMatches.Count -ne 1) {
    throw "Bootstrap account definition is invalid."
}

$BootstrapAlias = [string]$BootstrapMatches[0].alias

$PlanScopes = @(
    "User.ReadBasic.All",
    "LicenseAssignment.Read.All"
)

$PilotScopes = @(
    $Provisioning.apply.pilot_graph_scopes
)

$ExpectedConfirmation = [string]$Provisioning.apply.pilot_confirmation

$CredentialPath = (
    "local-evidence/pilot-" +
    $PilotAccountId +
    "-credentials.json"
)

$OperationPath = (
    "local-evidence/pilot-" +
    $PilotAccountId +
    "-operation.json"
)

function Protect-LocalEvidenceDirectory {
    New-Item `
        -ItemType Directory `
        -Path "local-evidence" `
        -Force |
        Out-Null

    if ($IsLinux) {
        & chmod 700 -- "local-evidence"

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to protect local-evidence directory."
        }
    }
}

function Write-PrivateJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Value
    )

    Protect-LocalEvidenceDirectory

    $Value |
        ConvertTo-Json -Depth 12 |
        Set-Content `
            -Path $Path `
            -Encoding utf8

    if ($IsLinux) {
        & chmod 600 -- $Path

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to protect local evidence file: $Path"
        }
    }
}

function New-RandomPassword {
    param(
        [int]$Length = 28
    )

    if ($Length -lt 20) {
        throw "Password length must be at least 20."
    }

    $Upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $Lower = "abcdefghijkmnopqrstuvwxyz"
    $Digits = "23456789"
    $Special = "!@#$%*-_+=?"

    $All = $Upper + $Lower + $Digits + $Special

    $Chars = New-Object System.Collections.Generic.List[char]

    foreach ($Set in @(
        $Upper,
        $Lower,
        $Digits,
        $Special
    )) {
        $Index = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(
            $Set.Length
        )

        $Chars.Add($Set[$Index])
    }

    while ($Chars.Count -lt $Length) {
        $Index = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(
            $All.Length
        )

        $Chars.Add($All[$Index])
    }

    for ($i = $Chars.Count - 1; $i -gt 0; $i--) {
        $j = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(
            $i + 1
        )

        $Temp = $Chars[$i]
        $Chars[$i] = $Chars[$j]
        $Chars[$j] = $Temp
    }

    return -join $Chars
}

if ($Mode -eq "Pilot") {
    if ($Confirmation -ne $ExpectedConfirmation) {
        throw (
            "Pilot requires explicit confirmation: " +
            $ExpectedConfirmation
        )
    }

    if ([string]::IsNullOrWhiteSpace($UsageLocation)) {
        $UsageLocation = (
            Read-Host "Usage location (ISO two-letter code)"
        )
    }

    $UsageLocation = $UsageLocation.Trim().ToUpperInvariant()

    if ($UsageLocation -notmatch '^[A-Z]{2}$') {
        throw "Usage location must be a two-letter country code."
    }

    $RequiredScopes = $PilotScopes
}
else {
    $RequiredScopes = $PlanScopes
}

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

    $ExistingUsers = @($UsersResponse.value)

    $LiveBootstrap = @(
        $ExistingUsers |
        Where-Object {
            $_.userPrincipalName -and
            $_.userPrincipalName.Split("@")[0].ToLowerInvariant() -eq
            $BootstrapAlias.ToLowerInvariant()
        }
    )

    if ($LiveBootstrap.Count -ne 1) {
        throw (
            "Expected exactly one live bootstrap identity; found " +
            $LiveBootstrap.Count
        )
    }

    $BootstrapUpn = (
        [string]$LiveBootstrap[0].userPrincipalName
    ).ToLowerInvariant()

    $Parts = $BootstrapUpn.Split("@")

    if ($Parts.Count -ne 2) {
        throw "Bootstrap UPN format is invalid."
    }

    $TenantDomain = $Parts[1]

    $TargetUpn = (
        ([string]$PilotAccount.alias) +
        "@" +
        $TenantDomain
    ).ToLowerInvariant()

    $ExistingTarget = @(
        $ExistingUsers |
        Where-Object {
            $_.userPrincipalName -and
            $_.userPrincipalName.ToLowerInvariant() -eq
            $TargetUpn
        }
    )

    if ($ExistingTarget.Count -gt 1) {
        throw "Multiple users matched the pilot UPN."
    }

    $SkuResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/subscribedSkus"

    $SpbMatches = @(
        $SkuResponse.value |
        Where-Object {
            $_.skuPartNumber -eq "SPB"
        }
    )

    if ($SpbMatches.Count -ne 1) {
        throw (
            "Expected exactly one SPB SKU; found " +
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

    if ($Mode -eq "Plan") {
        $UsersToCreate = 0
        $LicensesToAssign = 0
        $LicenseAlreadyAssigned = $false

        if ($ExistingTarget.Count -eq 0) {
            $UsersToCreate = 1
            $LicensesToAssign = 1
        }
        else {
            $PlanLicenseDetails = Invoke-MgGraphRequest `
                -Method GET `
                -Uri (
                    "https://graph.microsoft.com/v1.0/users/" +
                    $ExistingTarget[0].id +
                    "/licenseDetails?`$select=skuId"
                )

            $PlanAssignedSkuIds = @(
                $PlanLicenseDetails.value |
                ForEach-Object {
                    [string]$_.skuId
                }
            )

            $PlanSpbSkuId = [string]$Spb.skuId

            $LicenseAlreadyAssigned = (
                $PlanSpbSkuId -in $PlanAssignedSkuIds
            )

            if (-not $LicenseAlreadyAssigned) {
                $LicensesToAssign = 1
            }
        }

        Write-Host ""
        Write-Host "PILOT PLAN"
        Write-Host "----------"
        Write-Host "account_id=$PilotAccountId"
        Write-Host "target_exists=$($ExistingTarget.Count -eq 1)"
        Write-Host "business_premium_available=$Available"
        Write-Host "business_premium_assigned=$LicenseAlreadyAssigned"
        Write-Host "users_to_create=$UsersToCreate"
        Write-Host "licenses_to_assign=$LicensesToAssign"
        Write-Host "groups_to_create=0"
        Write-Host "memberships_to_create=0"
        Write-Host "write_operations_performed=False"
        Write-Host ""
        Write-Host "PASS: plan completed without writes."
        return
    }

    if (
        $ExistingTarget.Count -eq 0 -and
        $Available -lt 1
    ) {
        throw "No Business Premium license is safely available."
    }

    $UserCreatedNow = $false
    $LicenseAssignedNow = $false

    if ($ExistingTarget.Count -eq 1) {
        if (-not (Test-Path $OperationPath)) {
            throw (
                "Target already exists but no trusted local pilot " +
                "operation evidence exists. Refusing to adopt it."
            )
        }

        $Previous = Get-Content `
            -Raw `
            $OperationPath |
            ConvertFrom-Json

        if (
            $Previous.account_id -ne $PilotAccountId -or
            $Previous.object_id -ne $ExistingTarget[0].id
        ) {
            throw "Existing pilot identity does not match local evidence."
        }

        $UserId = [string]$ExistingTarget[0].id
    }
    else {
        if (
            (Test-Path $CredentialPath) -and
            -not (Test-Path $OperationPath)
        ) {
            throw (
                "Stale credential file exists without operation evidence. " +
                "Refusing to overwrite it."
            )
        }

        $Password = New-RandomPassword `
            -Length ([int]$Provisioning.credentials.password_length)

        $CredentialRecord = [ordered]@{
            schema_version = "1.0"
            account_id = $PilotAccountId
            user_principal_name = $TargetUpn
            usage_location = $UsageLocation
            force_change_password_next_sign_in = $true
            generated_utc = [DateTime]::UtcNow.ToString("o")
        }

        $CredentialRecord.Add(
            "temporary_password",
            $Password
        )

        Write-PrivateJson `
            -Path $CredentialPath `
            -Value $CredentialRecord

        $PasswordProfile = @{
            forceChangePasswordNextSignIn = $true
        }

        $PasswordProfile.Add(
            "password",
            $Password
        )

        $CreateBody = @{
            accountEnabled = $true
            displayName = [string]$PilotAccount.display_name
            mailNickname = [string]$PilotAccount.alias
            userPrincipalName = $TargetUpn
            usageLocation = $UsageLocation
        }

        $CreateBody.Add(
            "passwordProfile",
            $PasswordProfile
        )

        $Created = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users" `
            -Body (
                $CreateBody |
                ConvertTo-Json -Depth 10
            ) `
            -ContentType "application/json"

        $UserId = [string]$Created.id

        if ([string]::IsNullOrWhiteSpace($UserId)) {
            throw "Graph did not return a user object ID."
        }

        $UserCreatedNow = $true

        $InitialEvidence = [ordered]@{
            schema_version = "1.0"
            account_id = $PilotAccountId
            object_id = $UserId
            usage_location = $UsageLocation
            status = "user-created-license-pending"
            user_created = $true
            license_assigned = $false
            credential_file = $CredentialPath
            updated_utc = [DateTime]::UtcNow.ToString("o")
        }

        Write-PrivateJson `
            -Path $OperationPath `
            -Value $InitialEvidence

        $Password = $null
    }

    $LicenseDetailsResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/users/" +
            $UserId +
            "/licenseDetails?`$select=skuId"
        )

    $AssignedSkuIds = @(
        $LicenseDetailsResponse.value |
        ForEach-Object {
            [string]$_.skuId
        }
    )

    $SpbSkuId = [string]$Spb.skuId

    if ($SpbSkuId -notin $AssignedSkuIds) {
        if ($Available -lt 1) {
            throw "Business Premium capacity is insufficient."
        }

        $LicenseBody = @{
            addLicenses = @(
                @{
                    skuId = $SpbSkuId
                }
            )
            removeLicenses = @()
        }

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri (
                "https://graph.microsoft.com/v1.0/users/" +
                $UserId +
                "/assignLicense"
            ) `
            -Body (
                $LicenseBody |
                ConvertTo-Json -Depth 10
            ) `
            -ContentType "application/json" |
            Out-Null

        $LicenseAssignedNow = $true
    }

    $FinalEvidence = [ordered]@{
        schema_version = "1.0"
        account_id = $PilotAccountId
        object_id = $UserId
        usage_location = $UsageLocation
        status = "completed"
        user_created = $true
        license_assigned = $true
        user_created_this_run = $UserCreatedNow
        license_assigned_this_run = $LicenseAssignedNow
        credential_file = $CredentialPath
        write_scope = "pilot-single-user"
        updated_utc = [DateTime]::UtcNow.ToString("o")
    }

    Write-PrivateJson `
        -Path $OperationPath `
        -Value $FinalEvidence

    Write-Host ""
    Write-Host "PILOT APPLY"
    Write-Host "-----------"
    Write-Host "account_id=$PilotAccountId"
    Write-Host "user_created_this_run=$UserCreatedNow"
    Write-Host "license_assigned_this_run=$LicenseAssignedNow"
    Write-Host "groups_created=0"
    Write-Host "memberships_created=0"
    Write-Host "credential_output_to_console=False"
    Write-Host ""
    Write-Host "PASS: controlled pilot completed."
}
finally {
    Disconnect-MgGraph `
        -ErrorAction SilentlyContinue |
        Out-Null
}
