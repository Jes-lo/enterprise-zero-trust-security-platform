#Requires -Version 7.2

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern("^[A-Za-z]{2}$")]
    [string]$UsageLocation,

    [Parameter(Mandatory)]
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

$PlanPath = (
    "local-evidence/" +
    "identity-full-provisioning-plan.json"
)

$OperationPath = (
    "local-evidence/" +
    "identity-full-provisioning-operation.json"
)

$PilotOperationPath = (
    "local-evidence/" +
    "pilot-EMPLOYEE_01-operation.json"
)

$CredentialDirectory = (
    "local-evidence/full-credentials"
)

$UsageLocation = $UsageLocation.ToUpperInvariant()

foreach ($Path in @(
    $IdentityPath,
    $ProvisioningPath,
    $PlanPath,
    $PilotOperationPath
)) {
    if (-not (Test-Path $Path)) {
        throw "Required input missing: $Path"
    }
}

$Identity = Get-Content `
    -Raw `
    $IdentityPath |
    ConvertFrom-Json

$Provisioning = Get-Content `
    -Raw `
    $ProvisioningPath |
    ConvertFrom-Json

$AuthoritativePlan = Get-Content `
    -Raw `
    $PlanPath |
    ConvertFrom-Json

$PilotOperation = Get-Content `
    -Raw `
    $PilotOperationPath |
    ConvertFrom-Json

$ExpectedConfirmation = (
    [string]$Provisioning.apply.full_confirmation
)

if ($Confirmation -ne $ExpectedConfirmation) {
    throw "Full Apply confirmation is invalid."
}

if (
    $AuthoritativePlan.write_operations_performed -ne
    $false
) {
    throw "Authoritative plan is not read-only evidence."
}

if (
    @($AuthoritativePlan.safety.conflicts).Count -ne 0
) {
    throw "Authoritative plan contains conflicts."
}

if (
    $AuthoritativePlan.safety.license_capacity_sufficient -ne
    $true
) {
    throw "Authoritative plan reports insufficient license capacity."
}

if (
    @($AuthoritativePlan.delta.users_to_create).Count -ne 9 -or
    @($AuthoritativePlan.delta.licenses_to_assign).Count -ne 7 -or
    @($AuthoritativePlan.delta.groups_to_create).Count -ne 11 -or
    @($AuthoritativePlan.delta.memberships_to_add).Count -ne 16
) {
    throw "Authoritative plan delta differs from approved Feature 3C."
}

$ApprovedUsersToCreate = @(
    $AuthoritativePlan.delta.users_to_create |
    ForEach-Object {
        [string]$_
    } |
    Sort-Object -Unique
)

$ApprovedLicensesToAssign = @(
    $AuthoritativePlan.delta.licenses_to_assign |
    ForEach-Object {
        [string]$_
    } |
    Sort-Object -Unique
)

$ApprovedGroupsToCreate = @(
    $AuthoritativePlan.delta.groups_to_create |
    ForEach-Object {
        [string]$_
    } |
    Sort-Object -Unique
)

$ApprovedMembershipsToAdd = @(
    $AuthoritativePlan.delta.memberships_to_add |
    ForEach-Object {
        (
            [string]$_.group_id +
            "|" +
            [string]$_.account_id
        )
    } |
    Sort-Object -Unique
)

if ($ApprovedUsersToCreate.Count -ne 9) {
    throw "Authoritative plan user set is invalid."
}

if ($ApprovedLicensesToAssign.Count -ne 7) {
    throw "Authoritative plan license set is invalid."
}

if ($ApprovedGroupsToCreate.Count -ne 11) {
    throw "Authoritative plan group set is invalid."
}

if ($ApprovedMembershipsToAdd.Count -ne 16) {
    throw "Authoritative plan membership set is invalid."
}

$RequiredScopes = @(
    $Provisioning.apply.full_apply_graph_scopes
)

$ExpectedScopes = @(
    "User.Create",
    "User.Read.All",
    "Group.ReadWrite.All",
    "GroupMember.ReadWrite.All",
    "LicenseAssignment.Read.All",
    "LicenseAssignment.ReadWrite.All"
)

if (
    @(
        Compare-Object `
            ($RequiredScopes | Sort-Object) `
            ($ExpectedScopes | Sort-Object)
    ).Count -ne 0
) {
    throw "Full Apply Graph permission contract differs from expected."
}

foreach ($Forbidden in @(
    "Directory.ReadWrite.All",
    "Directory.Read.All",
    "User.ReadWrite.All"
)) {
    if ($Forbidden -in $RequiredScopes) {
        throw "Forbidden Graph permission configured: $Forbidden"
    }
}

$AccountById = @{}

foreach ($Account in $Identity.accounts) {
    $AccountId = [string]$Account.id

    if ($AccountById.ContainsKey($AccountId)) {
        throw "Duplicate account ID in identity contract."
    }

    $AccountById[$AccountId] = $Account
}

$LiveAccounts = @(
    $Identity.accounts |
    Where-Object {
        $_.live_creation -eq $true
    }
)

$LicensedAccounts = @(
    $LiveAccounts |
    Where-Object {
        $_.license_policy -eq "business-premium"
    }
)

$EmergencyAccounts = @(
    $LiveAccounts |
    Where-Object {
        $_.persona -eq "EMERGENCY_ADMIN"
    }
)

$PlannedGroups = @(
    $Identity.groups
)

$Feature3MembershipGroups = @(
    $PlannedGroups |
    Where-Object {
        [int]$_.membership_managed_in_feature -eq 3
    }
)

if ($LiveAccounts.Count -ne 10) {
    throw "Expected 10 live-creation identities."
}

if ($LicensedAccounts.Count -ne 8) {
    throw "Expected 8 Business Premium identities."
}

if ($EmergencyAccounts.Count -ne 2) {
    throw "Expected 2 emergency identities."
}

if ($PlannedGroups.Count -ne 11) {
    throw "Expected 11 security groups."
}

$MembershipEdgeCount = 0

foreach ($Group in $Feature3MembershipGroups) {
    $MembershipEdgeCount += @($Group.members).Count
}

if ($MembershipEdgeCount -ne 16) {
    throw "Expected 16 Feature 3 membership edges."
}

foreach ($Emergency in $EmergencyAccounts) {
    if ($Emergency.license_policy -ne "unlicensed") {
        throw "Emergency identity must remain unlicensed."
    }

    if ($Emergency.cloud_only -ne $true) {
        throw "Emergency identity must remain cloud-only."
    }
}

function Protect-LocalDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    New-Item `
        -ItemType Directory `
        -Path $Path `
        -Force |
        Out-Null

    if ($IsLinux) {
        & chmod 700 -- $Path

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to protect local directory."
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

    $Parent = Split-Path `
        -Parent `
        $Path

    Protect-LocalDirectory `
        -Path $Parent

    $TemporaryPath = (
        $Path +
        ".tmp." +
        [System.Guid]::NewGuid().ToString("N")
    )

    try {
        $Value |
            ConvertTo-Json -Depth 30 |
            Set-Content `
                -LiteralPath $TemporaryPath `
                -Encoding utf8

        if ($IsLinux) {
            & chmod 600 -- $TemporaryPath

            if ($LASTEXITCODE -ne 0) {
                throw (
                    "Unable to protect temporary " +
                    "local evidence file."
                )
            }
        }

        Move-Item `
            -LiteralPath $TemporaryPath `
            -Destination $Path `
            -Force

        if ($IsLinux) {
            & chmod 600 -- $Path

            if ($LASTEXITCODE -ne 0) {
                throw (
                    "Unable to protect local evidence file."
                )
            }
        }
    }
    finally {
        if (
            Test-Path `
                -LiteralPath $TemporaryPath
        ) {
            Remove-Item `
                -LiteralPath $TemporaryPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

function Get-RandomIndex {
    param(
        [Parameter(Mandatory)]
        [int]$Maximum
    )

    if ($Maximum -le 0) {
        throw "Maximum must be positive."
    }

    return [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(
        $Maximum
    )
}

function New-StrongPassword {
    param(
        [int]$Length = 28
    )

    if ($Length -lt 20) {
        throw "Password length is below policy."
    }

    $Upper = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    $Lower = "abcdefghijkmnopqrstuvwxyz"
    $Digits = "23456789"
    $Special = "!@#$%*-_=+?"

    $All = (
        $Upper +
        $Lower +
        $Digits +
        $Special
    )

    $Chars = [System.Collections.Generic.List[char]]::new()

    foreach ($Set in @(
        $Upper,
        $Lower,
        $Digits,
        $Special
    )) {
        $Chars.Add(
            $Set[
                (Get-RandomIndex -Maximum $Set.Length)
            ]
        )
    }

    while ($Chars.Count -lt $Length) {
        $Chars.Add(
            $All[
                (Get-RandomIndex -Maximum $All.Length)
            ]
        )
    }

    for (
        $Index = $Chars.Count - 1;
        $Index -gt 0;
        $Index--
    ) {
        $Swap = Get-RandomIndex `
            -Maximum ($Index + 1)

        $Temporary = $Chars[$Index]
        $Chars[$Index] = $Chars[$Swap]
        $Chars[$Swap] = $Temporary
    }

    return -join $Chars
}

function Read-ValidatedCredentialRecord {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$AccountId,

        [Parameter(Mandatory)]
        [string]$TargetUpn,

        [Parameter(Mandatory)]
        [string]$ExpectedUsageLocation,

        [Parameter(Mandatory)]
        [bool]$ExpectedInitiallyEnabled,

        [Parameter(Mandatory)]
        [int]$ExpectedPasswordLength
    )

    if (-not (
        Test-Path `
            -LiteralPath $Path
    )) {
        throw (
            "Required credential evidence missing for " +
            $AccountId
        )
    }

    $Record = Get-Content `
        -Raw `
        -LiteralPath $Path |
        ConvertFrom-Json -AsHashtable

    if (
        [string]$Record["account_id"] -ne
        $AccountId
    ) {
        throw "Credential evidence account mismatch."
    }

    if (
        (
            [string]$Record["user_principal_name"]
        ).ToLowerInvariant() -ne
        $TargetUpn.ToLowerInvariant()
    ) {
        throw "Credential evidence UPN mismatch."
    }

    if (
        (
            [string]$Record["usage_location"]
        ).ToUpperInvariant() -ne
        $ExpectedUsageLocation.ToUpperInvariant()
    ) {
        throw "Credential evidence usage location mismatch."
    }

    if (
        [bool]$Record["initially_enabled"] -ne
        $ExpectedInitiallyEnabled
    ) {
        throw "Credential evidence enabled-state mismatch."
    }

    if (
        [bool]$Record[
            "force_change_password_next_sign_in"
        ] -ne $true
    ) {
        throw "Credential evidence force-change policy mismatch."
    }

    $PasswordValue = (
        [string]$Record["temporary_password"]
    )

    if (
        [string]::IsNullOrWhiteSpace(
            $PasswordValue
        )
    ) {
        throw "Credential evidence contains no password."
    }

    if (
        $PasswordValue.Length -ne
        $ExpectedPasswordLength
    ) {
        throw "Credential evidence password length mismatch."
    }

    return $Record
}

function Get-GraphCollection {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $Items = @()
    $NextUri = $Uri

    while ($NextUri) {
        $Response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $NextUri

        if ($null -ne $Response.value) {
            $Items += @($Response.value)
        }

        $NextUri = $null

        if (
            $Response.PSObject.Properties.Name -contains
            "@odata.nextLink"
        ) {
            $NextUri = (
                [string]$Response.'@odata.nextLink'
            )

            if (
                [string]::IsNullOrWhiteSpace(
                    $NextUri
                )
            ) {
                $NextUri = $null
            }
        }
    }

    return @($Items)
}

function Get-UserSkuIds {
    param(
        [Parameter(Mandatory)]
        [string]$UserId
    )

    $Values = Get-GraphCollection `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "users/" +
            $UserId +
            "/licenseDetails?`$select=skuId"
        )

    return @(
        $Values |
        ForEach-Object {
            [string]$_.skuId
        }
    )
}

function Assert-ExactStringSet {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [object[]]$Actual,

        [Parameter(Mandatory)]
        [object[]]$Expected
    )

    $ActualNormalized = @(
        $Actual |
        ForEach-Object {
            [string]$_
        } |
        Sort-Object -Unique
    )

    $ExpectedNormalized = @(
        $Expected |
        ForEach-Object {
            [string]$_
        } |
        Sort-Object -Unique
    )

    $Differences = @(
        Compare-Object `
            -ReferenceObject $ExpectedNormalized `
            -DifferenceObject $ActualNormalized
    )

    if (
        $ActualNormalized.Count -ne
        $ExpectedNormalized.Count -or
        $Differences.Count -ne 0
    ) {
        throw (
            "Exact authoritative-plan mismatch: " +
            $Name
        )
    }
}

function Save-Operation {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Operation
    )

    $Operation["updated_utc"] = (
        [DateTime]::UtcNow.ToString("o")
    )

    Write-PrivateJson `
        -Path $OperationPath `
        -Value $Operation
}

$IdentityHash = (
    Get-FileHash `
        -Algorithm SHA256 `
        -Path $IdentityPath
).Hash

$ProvisioningHash = (
    Get-FileHash `
        -Algorithm SHA256 `
        -Path $ProvisioningPath
).Hash

$AuthoritativePlanHash = (
    Get-FileHash `
        -Algorithm SHA256 `
        -Path $PlanPath
).Hash

$OperationExists = Test-Path $OperationPath

if ($OperationExists) {
    $Operation = Get-Content `
        -Raw `
        $OperationPath |
        ConvertFrom-Json -AsHashtable

    if (
        $Operation["identity_contract_sha256"] -ne
        $IdentityHash
    ) {
        throw "Identity contract changed after Full Apply began."
    }

    if (
        $Operation["provisioning_contract_sha256"] -ne
        $ProvisioningHash
    ) {
        throw "Provisioning contract changed after Full Apply began."
    }

    if (
        $Operation["authoritative_plan_sha256"] -ne
        $AuthoritativePlanHash
    ) {
        throw "Authoritative plan changed after Full Apply began."
    }

    if (
        $Operation["usage_location"] -ne
        $UsageLocation
    ) {
        throw "Usage location differs from existing operation evidence."
    }
}
else {
    $Operation = [ordered]@{
        schema_version = "1.0"
        operation_type = "identity-full-provisioning"
        status = "not-started"

        identity_contract_sha256 = $IdentityHash
        provisioning_contract_sha256 = $ProvisioningHash
        authoritative_plan_sha256 = $AuthoritativePlanHash

        usage_location = $UsageLocation

        created_utc = (
            [DateTime]::UtcNow.ToString("o")
        )

        updated_utc = (
            [DateTime]::UtcNow.ToString("o")
        )

        accounts = [ordered]@{}
        groups = [ordered]@{}
        licenses = [ordered]@{}
        memberships = [ordered]@{}
    }
}

$LockPath = (
    [string]$Provisioning.apply.full_apply_lock_file
)

if (
    [string]::IsNullOrWhiteSpace(
        $LockPath
    )
) {
    throw "Full Apply lock path is not configured."
}

$LockStream = $null

Protect-LocalDirectory `
    -Path (
        Split-Path `
            -Parent `
            $LockPath
    )

try {
    $LockStream = [System.IO.File]::Open(
        $LockPath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )

    if ($IsLinux) {
        & chmod 600 -- $LockPath

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to protect Full Apply lock file."
        }
    }
}
catch {
    throw (
        "Unable to acquire Full Apply execution lock. " +
        "Another process may already be running."
    )
}

$CurrentStage = "authentication"

try {
    Connect-MgGraph `
        -Scopes $RequiredScopes `
        -TenantId "organizations" `
        -UseDeviceAuthentication `
        -ContextScope Process `
        -NoWelcome

    $Context = Get-MgContext

    if ($null -eq $Context) {
        throw "Microsoft Graph context unavailable."
    }

    foreach ($Scope in $RequiredScopes) {
        if ($Scope -notin $Context.Scopes) {
            throw "Required Graph permission missing: $Scope"
        }
    }

    $CurrentStage = "preflight"

    $ExistingUsers = Get-GraphCollection `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "users?" +
            "`$select=id,displayName,userPrincipalName," +
            "accountEnabled,usageLocation,userType" +
            "&`$top=999"
        )

    $ExistingGroups = Get-GraphCollection `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "groups?" +
            "`$select=id,displayName,mailNickname," +
            "securityEnabled,mailEnabled,groupTypes" +
            "&`$top=999"
        )

    $SkuValues = Get-GraphCollection `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "subscribedSkus"
        )

    $BootstrapDefinition = @(
        $Identity.accounts |
        Where-Object {
            $_.id -eq "BOOTSTRAP_ADMIN"
        }
    )

    if ($BootstrapDefinition.Count -ne 1) {
        throw "Bootstrap identity definition is invalid."
    }

    $BootstrapAlias = (
        [string]$BootstrapDefinition[0].alias
    ).ToLowerInvariant()

    $LiveBootstrap = @(
        $ExistingUsers |
        Where-Object {
            $_.userPrincipalName -and
            (
                $_.userPrincipalName.Split("@")[0]
            ).ToLowerInvariant() -eq $BootstrapAlias
        }
    )

    if ($LiveBootstrap.Count -ne 1) {
        throw "Unable to resolve unique bootstrap identity."
    }

    $BootstrapUpn = (
        [string]$LiveBootstrap[0].userPrincipalName
    )

    $TenantDomain = (
        $BootstrapUpn.Split("@")[1]
    ).ToLowerInvariant()

    if (
        [string]::IsNullOrWhiteSpace(
            $TenantDomain
        )
    ) {
        throw "Unable to derive tenant domain."
    }

    $SpbMatches = @(
        $SkuValues |
        Where-Object {
            $_.skuPartNumber -eq "SPB"
        }
    )

    if ($SpbMatches.Count -ne 1) {
        throw "Expected exactly one Business Premium SKU."
    }

    $Spb = $SpbMatches[0]
    $SpbSkuId = [string]$Spb.skuId

    $Enabled = [int]$Spb.prepaidUnits.enabled
    $Warning = [int]$Spb.prepaidUnits.warning
    $Consumed = [int]$Spb.consumedUnits

    # Conservative capacity calculation:
    # warning-state units are never counted as safely assignable.
    $Available = [Math]::Max(
        0,
        $Enabled - $Warning - $Consumed
    )

    $UsersByUpn = @{}

    foreach ($User in $ExistingUsers) {
        if (-not $User.userPrincipalName) {
            continue
        }

        $Key = (
            [string]$User.userPrincipalName
        ).ToLowerInvariant()

        if ($UsersByUpn.ContainsKey($Key)) {
            throw "Duplicate live UPN detected."
        }

        $UsersByUpn[$Key] = $User
    }

    $LiveUserIdByAccount = @{}
    $UsersToCreate = @()
    $LicensesToAssign = @()
    $Conflicts = @()

    foreach ($Account in $LiveAccounts) {
        $AccountId = [string]$Account.id
        $Alias = (
            [string]$Account.alias
        ).ToLowerInvariant()

        $TargetUpn = (
            $Alias +
            "@" +
            $TenantDomain
        ).ToLowerInvariant()

        $ExactUser = $null

        if ($UsersByUpn.ContainsKey($TargetUpn)) {
            $ExactUser = $UsersByUpn[$TargetUpn]
        }

        $AliasMatches = @(
            $ExistingUsers |
            Where-Object {
                $_.userPrincipalName -and
                (
                    $_.userPrincipalName.Split("@")[0]
                ).ToLowerInvariant() -eq $Alias
            }
        )

        $DisplayMatches = @(
            $ExistingUsers |
            Where-Object {
                $_.displayName -eq $Account.display_name
            }
        )

        if ($null -eq $ExactUser) {
            if ($AliasMatches.Count -gt 0) {
                $Conflicts += (
                    "user-alias-collision:" +
                    $AccountId
                )
            }

            if ($DisplayMatches.Count -gt 0) {
                $Conflicts += (
                    "user-display-collision:" +
                    $AccountId
                )
            }

            if (
                $Operation["accounts"].Contains(
                    $AccountId
                )
            ) {
                $Known = $Operation["accounts"][$AccountId]

                if (
                    $Known["status"] -in @(
                        "created",
                        "verified"
                    )
                ) {
                    $Conflicts += (
                        "previously-created-user-missing:" +
                        $AccountId
                    )
                }
            }

            $UsersToCreate += $AccountId
        }
        else {
            if (
                [string]$ExactUser.displayName -ne
                [string]$Account.display_name
            ) {
                $Conflicts += (
                    "user-display-drift:" +
                    $AccountId
                )
            }

            $ExpectedAccountEnabled = (
                [bool]$Provisioning.apply.standard_accounts_initially_enabled
            )

            if (
                $Account.persona -eq
                "EMERGENCY_ADMIN"
            ) {
                $ExpectedAccountEnabled = (
                    [bool]$Provisioning.apply.emergency_accounts_initially_enabled
                )
            }

            if (
                [bool]$ExactUser.accountEnabled -ne
                $ExpectedAccountEnabled
            ) {
                $Conflicts += (
                    "user-enabled-state-drift:" +
                    $AccountId
                )
            }

            if (
                (
                    [string]$ExactUser.usageLocation
                ).ToUpperInvariant() -ne
                $UsageLocation
            ) {
                $Conflicts += (
                    "user-usage-location-drift:" +
                    $AccountId
                )
            }

            if (
                [string]$ExactUser.userType -ne
                "Member"
            ) {
                $Conflicts += (
                    "user-type-drift:" +
                    $AccountId
                )
            }

            if ($AliasMatches.Count -ne 1) {
                $Conflicts += (
                    "user-alias-not-unique:" +
                    $AccountId
                )
            }

            if ($AccountId -eq "EMPLOYEE_01") {
                if (
                    [string]$PilotOperation.object_id -ne
                    [string]$ExactUser.id
                ) {
                    $Conflicts += (
                        "pilot-object-id-mismatch"
                    )
                }
            }
            elseif (
                $Operation["accounts"].Contains(
                    $AccountId
                )
            ) {
                $Known = $Operation["accounts"][$AccountId]

                if (
                    $Known.Contains("object_id") -and
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$Known["object_id"]
                    ) -and
                    [string]$Known["object_id"] -ne
                    [string]$ExactUser.id
                ) {
                    $Conflicts += (
                        "operation-object-id-mismatch:" +
                        $AccountId
                    )
                }
                elseif (
                    $Known["status"] -eq "create_pending"
                ) {
                    $RecoveryInitiallyEnabled = (
                        [bool]$Provisioning.apply.standard_accounts_initially_enabled
                    )

                    if (
                        $Account.persona -eq
                        "EMERGENCY_ADMIN"
                    ) {
                        $RecoveryInitiallyEnabled = (
                            [bool]$Provisioning.apply.emergency_accounts_initially_enabled
                        )
                    }

                    $RecoveryCredentialPath = Join-Path `
                        $CredentialDirectory `
                        ($AccountId + ".json")

                    Read-ValidatedCredentialRecord `
                        -Path $RecoveryCredentialPath `
                        -AccountId $AccountId `
                        -TargetUpn $TargetUpn `
                        -ExpectedUsageLocation $UsageLocation `
                        -ExpectedInitiallyEnabled $RecoveryInitiallyEnabled `
                        -ExpectedPasswordLength (
                            [int]$Provisioning.credentials.password_length
                        ) |
                        Out-Null

                    $Known["object_id"] = (
                        [string]$ExactUser.id
                    )

                    $Known["status"] = "recovered_created"

                    $Known[
                        "recovered_after_uncertain_post"
                    ] = $true
                }
            }
            else {
                $Conflicts += (
                    "untrusted-preexisting-user:" +
                    $AccountId
                )
            }

            $LiveUserIdByAccount[$AccountId] = (
                [string]$ExactUser.id
            )
        }

        if (
            $null -eq $ExactUser -and
            $Account.license_policy -eq
            "business-premium"
        ) {
            $LicensesToAssign += $AccountId
        }
        elseif (
            $null -ne $ExactUser -and
            $Account.license_policy -eq
            "business-premium"
        ) {
            $SkuIds = @(
                Get-UserSkuIds `
                    -UserId ([string]$ExactUser.id)
            )

            if ($SpbSkuId -in $SkuIds) {
                if (
                    $Operation["licenses"].Contains(
                        $AccountId
                    )
                ) {
                    $KnownLicense = (
                        $Operation["licenses"][$AccountId]
                    )

                    if (
                        $KnownLicense["status"] -eq
                        "assignment_pending"
                    ) {
                        $KnownLicense["status"] = (
                            "recovered_assigned"
                        )

                        $KnownLicense[
                            "recovered_after_uncertain_post"
                        ] = $true
                    }
                }
            }
            else {
                $LicensesToAssign += $AccountId
            }
        }
        elseif (
            $null -ne $ExactUser -and
            $Account.license_policy -eq
            "unlicensed"
        ) {
            $SkuIds = @(
                Get-UserSkuIds `
                    -UserId ([string]$ExactUser.id)
            )

            if ($SkuIds.Count -gt 0) {
                $Conflicts += (
                    "unlicensed-user-has-license:" +
                    $AccountId
                )
            }
        }
    }

    $LiveGroupIdByContract = @{}
    $GroupsToCreate = @()

    foreach ($Group in $PlannedGroups) {
        $GroupId = [string]$Group.id

        $Related = @(
            $ExistingGroups |
            Where-Object {
                $_.displayName -eq $Group.display_name -or
                $_.mailNickname -eq $Group.mail_nickname
            }
        )

        $Exact = @(
            $Related |
            Where-Object {
                $_.displayName -eq $Group.display_name -and
                $_.mailNickname -eq $Group.mail_nickname
            }
        )

        if ($Related.Count -eq 0) {
            if (
                $Operation["groups"].Contains(
                    $GroupId
                )
            ) {
                $KnownGroup = $Operation["groups"][$GroupId]

                if (
                    $KnownGroup["status"] -in @(
                        "created",
                        "verified"
                    )
                ) {
                    $Conflicts += (
                        "previously-created-group-missing:" +
                        $GroupId
                    )
                }
            }

            $GroupsToCreate += $GroupId
            continue
        }

        if (
            $Related.Count -ne 1 -or
            $Exact.Count -ne 1
        ) {
            $Conflicts += (
                "group-name-collision:" +
                $GroupId
            )

            continue
        }

        $LiveGroup = $Exact[0]

        if (
            $LiveGroup.securityEnabled -ne $true -or
            $LiveGroup.mailEnabled -ne $false -or
            @($LiveGroup.groupTypes).Count -ne 0
        ) {
            $Conflicts += (
                "group-property-drift:" +
                $GroupId
            )
        }

        if (
            $Operation["groups"].Contains(
                $GroupId
            )
        ) {
            $KnownGroup = $Operation["groups"][$GroupId]

            if (
                $KnownGroup.Contains("object_id") -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$KnownGroup["object_id"]
                ) -and
                [string]$KnownGroup["object_id"] -ne
                [string]$LiveGroup.id
            ) {
                $Conflicts += (
                    "group-object-id-mismatch:" +
                    $GroupId
                )
            }
            elseif (
                $KnownGroup["status"] -eq
                "create_pending"
            ) {
                $KnownGroup["object_id"] = (
                    [string]$LiveGroup.id
                )

                $KnownGroup["status"] = "recovered_created"

                $KnownGroup[
                    "recovered_after_uncertain_post"
                ] = $true
            }
        }
        else {
            $Conflicts += (
                "untrusted-preexisting-group:" +
                $GroupId
            )
        }

        $LiveGroupIdByContract[$GroupId] = (
            [string]$LiveGroup.id
        )
    }

    $MembershipsToAdd = @()

    foreach ($Group in $Feature3MembershipGroups) {
        $GroupId = [string]$Group.id
        $CurrentMemberIds = @()

        if (
            $LiveGroupIdByContract.ContainsKey(
                $GroupId
            )
        ) {
            $CurrentMembers = Get-GraphCollection `
                -Uri (
                    "https://graph.microsoft.com/v1.0/" +
                    "groups/" +
                    $LiveGroupIdByContract[$GroupId] +
                    "/members?`$select=id&`$top=999"
                )

            $CurrentMemberIds = @(
                $CurrentMembers |
                ForEach-Object {
                    [string]$_.id
                }
            )

            $AllowedKnownMemberIds = @(
                @($Group.members) |
                Where-Object {
                    $LiveUserIdByAccount.ContainsKey(
                        [string]$_
                    )
                } |
                ForEach-Object {
                    $LiveUserIdByAccount[
                        [string]$_
                    ]
                }
            )

            foreach ($CurrentMemberId in $CurrentMemberIds) {
                if (
                    $CurrentMemberId -notin
                    $AllowedKnownMemberIds
                ) {
                    $Conflicts += (
                        "unexpected-group-member:" +
                        $GroupId
                    )
                }
            }
        }

        foreach ($MemberAccountId in @($Group.members)) {
            $MemberAccountId = [string]$MemberAccountId

            $AlreadyPresent = $false

            if (
                $LiveUserIdByAccount.ContainsKey(
                    $MemberAccountId
                ) -and
                $LiveGroupIdByContract.ContainsKey(
                    $GroupId
                )
            ) {
                $AlreadyPresent = (
                    $LiveUserIdByAccount[$MemberAccountId] -in
                    $CurrentMemberIds
                )
            }

            $MembershipKey = (
                $GroupId +
                "|" +
                $MemberAccountId
            )

            if (-not $AlreadyPresent) {
                $MembershipsToAdd += [ordered]@{
                    group_id = $GroupId
                    account_id = $MemberAccountId
                }
            }
            elseif (
                $Operation["memberships"].Contains(
                    $MembershipKey
                )
            ) {
                $KnownMembership = (
                    $Operation["memberships"][
                        $MembershipKey
                    ]
                )

                if (
                    $KnownMembership["status"] -eq
                    "add_pending"
                ) {
                    $KnownMembership["status"] = (
                        "recovered_present"
                    )

                    $KnownMembership[
                        "recovered_after_uncertain_post"
                    ] = $true
                }
            }
        }
    }

    $UniqueConflicts = @(
        $Conflicts |
        Sort-Object -Unique
    )

    if ($UniqueConflicts.Count -gt 0) {
        throw (
            "Full Apply preflight contains " +
            $UniqueConflicts.Count +
            " conflict(s). No writes performed."
        )
    }

    if ($Available -lt $LicensesToAssign.Count) {
        throw "Insufficient Business Premium capacity."
    }

    if (-not $OperationExists) {
        $CurrentMembershipKeys = @(
            $MembershipsToAdd |
            ForEach-Object {
                (
                    [string]$_.group_id +
                    "|" +
                    [string]$_.account_id
                )
            } |
            Sort-Object -Unique
        )

        Assert-ExactStringSet `
            -Name "users_to_create" `
            -Actual $UsersToCreate `
            -Expected $ApprovedUsersToCreate

        Assert-ExactStringSet `
            -Name "licenses_to_assign" `
            -Actual $LicensesToAssign `
            -Expected $ApprovedLicensesToAssign

        Assert-ExactStringSet `
            -Name "groups_to_create" `
            -Actual $GroupsToCreate `
            -Expected $ApprovedGroupsToCreate

        Assert-ExactStringSet `
            -Name "memberships_to_add" `
            -Actual $CurrentMembershipKeys `
            -Expected $ApprovedMembershipsToAdd

        $Operation["status"] = "prepared"

        Save-Operation `
            -Operation $Operation

        $OperationExists = $true
    }
    else {
        Save-Operation `
            -Operation $Operation
    }

    Write-Host ""
    Write-Host "FULL APPLY PREFLIGHT"
    Write-Host "--------------------"
    Write-Host (
        "users_to_create=" +
        $UsersToCreate.Count
    )
    Write-Host (
        "licenses_to_assign=" +
        $LicensesToAssign.Count
    )
    Write-Host (
        "groups_to_create=" +
        $GroupsToCreate.Count
    )
    Write-Host (
        "memberships_to_add=" +
        $MembershipsToAdd.Count
    )
    Write-Host (
        "business_premium_available=" +
        $Available
    )
    Write-Host "conflicts=0"
    Write-Host ""

    $CurrentStage = "users"
    $Operation["status"] = "users"

    Save-Operation `
        -Operation $Operation

    Protect-LocalDirectory `
        -Path $CredentialDirectory

    foreach (
        $Account in (
            $LiveAccounts |
            Sort-Object id
        )
    ) {
        $AccountId = [string]$Account.id

        if (
            $LiveUserIdByAccount.ContainsKey(
                $AccountId
            )
        ) {
            continue
        }

        $Alias = (
            [string]$Account.alias
        ).ToLowerInvariant()

        $TargetUpn = (
            $Alias +
            "@" +
            $TenantDomain
        ).ToLowerInvariant()

        $CredentialPath = Join-Path `
            $CredentialDirectory `
            ($AccountId + ".json")

        $InitiallyEnabled = (
            [bool]$Provisioning.apply.standard_accounts_initially_enabled
        )

        if (
            $Account.persona -eq
            "EMERGENCY_ADMIN"
        ) {
            $InitiallyEnabled = (
                [bool]$Provisioning.apply.emergency_accounts_initially_enabled
            )
        }

        $ExpectedPasswordLength = (
            [int]$Provisioning.credentials.password_length
        )

        $Password = $null

        if (Test-Path $CredentialPath) {
            $CredentialRecord = (
                Read-ValidatedCredentialRecord `
                    -Path $CredentialPath `
                    -AccountId $AccountId `
                    -TargetUpn $TargetUpn `
                    -ExpectedUsageLocation $UsageLocation `
                    -ExpectedInitiallyEnabled $InitiallyEnabled `
                    -ExpectedPasswordLength $ExpectedPasswordLength
            )

            $Password = (
                [string]$CredentialRecord[
                    "temporary_password"
                ]
            )
        }
        else {
            $Password = New-StrongPassword `
                -Length $ExpectedPasswordLength

            $CredentialRecord = [ordered]@{
                schema_version = "1.0"
                account_id = $AccountId
                user_principal_name = $TargetUpn
                usage_location = $UsageLocation
                initially_enabled = $InitiallyEnabled
                force_change_password_next_sign_in = $true
                generated_utc = (
                    [DateTime]::UtcNow.ToString("o")
                )
            }

            $CredentialRecord.Add(
                "temporary_password",
                $Password
            )

            Write-PrivateJson `
                -Path $CredentialPath `
                -Value $CredentialRecord
        }

        $Operation["accounts"][$AccountId] = [ordered]@{
            status = "create_pending"
            object_id = $null
            created_this_operation = $false
        }

        Save-Operation `
            -Operation $Operation

        $PasswordProfile = @{
            forceChangePasswordNextSignIn = $true
        }

        $PasswordProfile.Add(
            "password",
            $Password
        )

        $CreateBody = @{
            accountEnabled = $InitiallyEnabled
            displayName = [string]$Account.display_name
            mailNickname = [string]$Account.alias
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

        if (
            [string]::IsNullOrWhiteSpace(
                [string]$Created.id
            )
        ) {
            throw "Created user returned no object ID."
        }

        $UserId = [string]$Created.id

        $LiveUserIdByAccount[$AccountId] = $UserId

        $Operation["accounts"][$AccountId][
            "object_id"
        ] = $UserId

        $Operation["accounts"][$AccountId][
            "status"
        ] = "created"

        $Operation["accounts"][$AccountId][
            "created_this_operation"
        ] = $true

        Save-Operation `
            -Operation $Operation
    }

    $CurrentStage = "groups"
    $Operation["status"] = "groups"

    Save-Operation `
        -Operation $Operation

    foreach (
        $Group in (
            $PlannedGroups |
            Sort-Object id
        )
    ) {
        $GroupId = [string]$Group.id

        if (
            $LiveGroupIdByContract.ContainsKey(
                $GroupId
            )
        ) {
            continue
        }

        $Operation["groups"][$GroupId] = [ordered]@{
            status = "create_pending"
            object_id = $null
            created_this_operation = $false
        }

        Save-Operation `
            -Operation $Operation

        $GroupBody = @{
            displayName = [string]$Group.display_name
            mailEnabled = $false
            mailNickname = [string]$Group.mail_nickname
            securityEnabled = $true
            groupTypes = @()
        }

        $CreatedGroup = Invoke-MgGraphRequest `
            -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/groups" `
            -Body (
                $GroupBody |
                ConvertTo-Json -Depth 10
            ) `
            -ContentType "application/json"

        if (
            [string]::IsNullOrWhiteSpace(
                [string]$CreatedGroup.id
            )
        ) {
            throw "Created group returned no object ID."
        }

        $LiveGroupId = (
            [string]$CreatedGroup.id
        )

        $LiveGroupIdByContract[$GroupId] = (
            $LiveGroupId
        )

        $Operation["groups"][$GroupId][
            "object_id"
        ] = $LiveGroupId

        $Operation["groups"][$GroupId][
            "status"
        ] = "created"

        $Operation["groups"][$GroupId][
            "created_this_operation"
        ] = $true

        Save-Operation `
            -Operation $Operation
    }

    $CurrentStage = "licenses"
    $Operation["status"] = "licenses"

    Save-Operation `
        -Operation $Operation

    foreach (
        $Account in (
            $LicensedAccounts |
            Sort-Object id
        )
    ) {
        $AccountId = [string]$Account.id
        $UserId = (
            [string]$LiveUserIdByAccount[$AccountId]
        )

        if (
            [string]::IsNullOrWhiteSpace(
                $UserId
            )
        ) {
            throw "Licensed account has no resolved object ID."
        }

        $SkuIds = @(
            Get-UserSkuIds `
                -UserId $UserId
        )

        if ($SpbSkuId -in $SkuIds) {
            if (
                -not $Operation["licenses"].Contains(
                    $AccountId
                )
            ) {
                $Operation["licenses"][$AccountId] = [ordered]@{
                    status = "already_assigned"
                    assigned_this_operation = $false
                }
            }

            continue
        }

        $Operation["licenses"][$AccountId] = [ordered]@{
            status = "assignment_pending"
            assigned_this_operation = $false
        }

        Save-Operation `
            -Operation $Operation

        $LicenseBody = @{
            addLicenses = @(
                @{
                    skuId = $SpbSkuId
                    disabledPlans = @()
                }
            )
            removeLicenses = @()
        }

        Invoke-MgGraphRequest `
            -Method POST `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "users/" +
                $UserId +
                "/assignLicense"
            ) `
            -Body (
                $LicenseBody |
                ConvertTo-Json -Depth 10
            ) `
            -ContentType "application/json" |
            Out-Null

        $Operation["licenses"][$AccountId][
            "status"
        ] = "assigned"

        $Operation["licenses"][$AccountId][
            "assigned_this_operation"
        ] = $true

        Save-Operation `
            -Operation $Operation
    }

    $CurrentStage = "memberships"
    $Operation["status"] = "memberships"

    Save-Operation `
        -Operation $Operation

    foreach (
        $Group in (
            $Feature3MembershipGroups |
            Sort-Object id
        )
    ) {
        $GroupId = [string]$Group.id
        $LiveGroupId = (
            [string]$LiveGroupIdByContract[$GroupId]
        )

        if (
            [string]::IsNullOrWhiteSpace(
                $LiveGroupId
            )
        ) {
            throw "Membership group has no resolved object ID."
        }

        $CurrentMembers = Get-GraphCollection `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "groups/" +
                $LiveGroupId +
                "/members?`$select=id&`$top=999"
            )

        $CurrentMemberIds = @(
            $CurrentMembers |
            ForEach-Object {
                [string]$_.id
            }
        )

        foreach (
            $MemberAccountId in (
                @($Group.members) |
                Sort-Object
            )
        ) {
            $MemberAccountId = [string]$MemberAccountId

            $UserId = (
                [string]$LiveUserIdByAccount[$MemberAccountId]
            )

            if (
                [string]::IsNullOrWhiteSpace(
                    $UserId
                )
            ) {
                throw "Membership account has no resolved object ID."
            }

            $MembershipKey = (
                $GroupId +
                "|" +
                $MemberAccountId
            )

            if ($UserId -in $CurrentMemberIds) {
                if (
                    -not $Operation["memberships"].Contains(
                        $MembershipKey
                    )
                ) {
                    $Operation["memberships"][
                        $MembershipKey
                    ] = [ordered]@{
                        status = "already_present"
                        added_this_operation = $false
                    }
                }

                continue
            }

            $Operation["memberships"][
                $MembershipKey
            ] = [ordered]@{
                status = "add_pending"
                added_this_operation = $false
            }

            Save-Operation `
                -Operation $Operation

            $MembershipBody = @{}

            $MembershipBody.Add(
                "@odata.id",
                (
                    "https://graph.microsoft.com/v1.0/" +
                    "directoryObjects/" +
                    $UserId
                )
            )

            Invoke-MgGraphRequest `
                -Method POST `
                -Uri (
                    "https://graph.microsoft.com/v1.0/" +
                    "groups/" +
                    $LiveGroupId +
                    "/members/`$ref"
                ) `
                -Body (
                    $MembershipBody |
                    ConvertTo-Json -Depth 10
                ) `
                -ContentType "application/json" |
                Out-Null

            $Operation["memberships"][
                $MembershipKey
            ]["status"] = "added"

            $Operation["memberships"][
                $MembershipKey
            ]["added_this_operation"] = $true

            Save-Operation `
                -Operation $Operation

            $CurrentMemberIds += $UserId
        }
    }

    $CurrentStage = "verification"
    $Operation["status"] = "verification"

    Save-Operation `
        -Operation $Operation

    $VerifiedUsers = 0
    $VerifiedLicensed = 0
    $VerifiedUnlicensedEmergency = 0
    $VerifiedGroups = 0
    $VerifiedMemberships = 0

    $FinalUsers = Get-GraphCollection `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "users?" +
            "`$select=id,displayName,userPrincipalName," +
            "accountEnabled,usageLocation,userType" +
            "&`$top=999"
        )

    $FinalUsersByUpn = @{}

    foreach ($FinalUser in $FinalUsers) {
        if (-not $FinalUser.userPrincipalName) {
            continue
        }

        $FinalUpnKey = (
            [string]$FinalUser.userPrincipalName
        ).ToLowerInvariant()

        if ($FinalUsersByUpn.ContainsKey(
            $FinalUpnKey
        )) {
            throw "Final verification found duplicate UPN."
        }

        $FinalUsersByUpn[$FinalUpnKey] = (
            $FinalUser
        )
    }

    foreach ($Account in $LiveAccounts) {
        $AccountId = [string]$Account.id

        $TargetUpn = (
            (
                [string]$Account.alias
            ).ToLowerInvariant() +
            "@" +
            $TenantDomain
        )

        if (-not $FinalUsersByUpn.ContainsKey(
            $TargetUpn
        )) {
            throw (
                "Final verification missing planned user: " +
                $AccountId
            )
        }

        $FinalUser = (
            $FinalUsersByUpn[$TargetUpn]
        )

        if (
            [string]$FinalUser.displayName -ne
            [string]$Account.display_name
        ) {
            throw (
                "Final user display-name mismatch: " +
                $AccountId
            )
        }

        $ExpectedFinalEnabled = (
            [bool]$Provisioning.apply.standard_accounts_initially_enabled
        )

        if (
            $Account.persona -eq
            "EMERGENCY_ADMIN"
        ) {
            $ExpectedFinalEnabled = (
                [bool]$Provisioning.apply.emergency_accounts_initially_enabled
            )
        }

        if (
            [bool]$FinalUser.accountEnabled -ne
            $ExpectedFinalEnabled
        ) {
            throw (
                "Final account-enabled state mismatch: " +
                $AccountId
            )
        }

        if (
            (
                [string]$FinalUser.usageLocation
            ).ToUpperInvariant() -ne
            $UsageLocation
        ) {
            throw (
                "Final usage-location mismatch: " +
                $AccountId
            )
        }

        if (
            [string]$FinalUser.userType -ne
            "Member"
        ) {
            throw (
                "Final user-type mismatch: " +
                $AccountId
            )
        }

        if (
            -not $LiveUserIdByAccount.ContainsKey(
                $AccountId
            )
        ) {
            throw (
                "Final verification has no trusted object ID: " +
                $AccountId
            )
        }

        if (
            [string]$FinalUser.id -ne
            [string]$LiveUserIdByAccount[$AccountId]
        ) {
            throw (
                "Final user object-ID mismatch: " +
                $AccountId
            )
        }

        $VerifiedUsers++

        $SkuIds = @(
            Get-UserSkuIds `
                -UserId ([string]$FinalUser.id)
        )

        if (
            $Account.license_policy -eq
            "business-premium"
        ) {
            if ($SpbSkuId -notin $SkuIds) {
                throw (
                    "Final verification found missing " +
                    "Business Premium license: " +
                    $AccountId
                )
            }

            $VerifiedLicensed++
        }
        elseif (
            $Account.persona -eq
            "EMERGENCY_ADMIN"
        ) {
            if ($SkuIds.Count -ne 0) {
                throw (
                    "Emergency identity gained an " +
                    "unexpected license: " +
                    $AccountId
                )
            }

            $VerifiedUnlicensedEmergency++
        }
    }

    $FinalGroups = Get-GraphCollection `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "groups?" +
            "`$select=id,displayName,mailNickname," +
            "securityEnabled,mailEnabled,groupTypes" +
            "&`$top=999"
        )

    foreach ($Group in $PlannedGroups) {
        $GroupId = [string]$Group.id

        $FinalGroupMatches = @(
            $FinalGroups |
            Where-Object {
                $_.displayName -eq $Group.display_name -and
                $_.mailNickname -eq $Group.mail_nickname
            }
        )

        if ($FinalGroupMatches.Count -ne 1) {
            throw (
                "Final verification could not resolve " +
                "exact group: " +
                $GroupId
            )
        }

        $FinalGroup = $FinalGroupMatches[0]

        if (
            $FinalGroup.securityEnabled -ne $true -or
            $FinalGroup.mailEnabled -ne $false -or
            @($FinalGroup.groupTypes).Count -ne 0
        ) {
            throw (
                "Final group property mismatch: " +
                $GroupId
            )
        }

        if (
            -not $LiveGroupIdByContract.ContainsKey(
                $GroupId
            )
        ) {
            throw (
                "Final verification has no trusted group ID: " +
                $GroupId
            )
        }

        if (
            [string]$FinalGroup.id -ne
            [string]$LiveGroupIdByContract[$GroupId]
        ) {
            throw (
                "Final group object-ID mismatch: " +
                $GroupId
            )
        }

        $VerifiedGroups++
    }

    foreach ($Group in $Feature3MembershipGroups) {
        $GroupId = [string]$Group.id

        $LiveGroupId = (
            [string]$LiveGroupIdByContract[$GroupId]
        )

        $FinalMembers = Get-GraphCollection `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "groups/" +
                $LiveGroupId +
                "/members?`$select=id&`$top=999"
            )

        $ActualMemberIds = @(
            $FinalMembers |
            ForEach-Object {
                [string]$_.id
            } |
            Sort-Object -Unique
        )

        $ExpectedMemberIds = @(
            @($Group.members) |
            ForEach-Object {
                $MemberAccountId = [string]$_

                if (
                    -not $LiveUserIdByAccount.ContainsKey(
                        $MemberAccountId
                    )
                ) {
                    throw (
                        "Final membership verification lacks " +
                        "trusted user ID: " +
                        $MemberAccountId
                    )
                }

                [string]$LiveUserIdByAccount[
                    $MemberAccountId
                ]
            } |
            Sort-Object -Unique
        )

        $MemberDifferences = @(
            Compare-Object `
                -ReferenceObject $ExpectedMemberIds `
                -DifferenceObject $ActualMemberIds
        )

        if (
            $ExpectedMemberIds.Count -ne
            $ActualMemberIds.Count -or
            $MemberDifferences.Count -ne 0
        ) {
            throw (
                "Final group membership differs from " +
                "Feature 3 contract: " +
                $GroupId
            )
        }

        $VerifiedMemberships += (
            $ExpectedMemberIds.Count
        )
    }

    if ($VerifiedUsers -ne 10) {
        throw "Final user verification count invalid."
    }

    if ($VerifiedLicensed -ne 8) {
        throw "Final licensed-user verification count invalid."
    }

    if ($VerifiedUnlicensedEmergency -ne 2) {
        throw "Final emergency verification count invalid."
    }

    if ($VerifiedGroups -ne 11) {
        throw "Final group verification count invalid."
    }

    if ($VerifiedMemberships -ne 16) {
        throw "Final membership verification count invalid."
    }

    $PendingLedgerEntries = @()

    foreach ($Entry in $Operation["accounts"].GetEnumerator()) {
        if (
            [string]$Entry.Value["status"] -like
            "*pending"
        ) {
            $PendingLedgerEntries += (
                "account:" +
                [string]$Entry.Key
            )
        }
    }

    foreach ($Entry in $Operation["groups"].GetEnumerator()) {
        if (
            [string]$Entry.Value["status"] -like
            "*pending"
        ) {
            $PendingLedgerEntries += (
                "group:" +
                [string]$Entry.Key
            )
        }
    }

    foreach ($Entry in $Operation["licenses"].GetEnumerator()) {
        if (
            [string]$Entry.Value["status"] -like
            "*pending"
        ) {
            $PendingLedgerEntries += (
                "license:" +
                [string]$Entry.Key
            )
        }
    }

    foreach ($Entry in $Operation["memberships"].GetEnumerator()) {
        if (
            [string]$Entry.Value["status"] -like
            "*pending"
        ) {
            $PendingLedgerEntries += (
                "membership:" +
                [string]$Entry.Key
            )
        }
    }

    if ($PendingLedgerEntries.Count -ne 0) {
        throw (
            "Full Apply cannot complete with pending " +
            "operation-ledger entries."
        )
    }

    $Operation["status"] = "completed"

    $Operation["verification"] = [ordered]@{
        users = $VerifiedUsers
        business_premium_users = $VerifiedLicensed
        emergency_unlicensed_users = $VerifiedUnlicensedEmergency
        groups = $VerifiedGroups
        memberships = $VerifiedMemberships
        completed_utc = (
            [DateTime]::UtcNow.ToString("o")
        )
    }

    Save-Operation `
        -Operation $Operation

    $CreatedUsersThisRun = @(
        $Operation["accounts"].Values |
        Where-Object {
            $_["created_this_operation"] -eq $true
        }
    ).Count

    $CreatedGroupsThisRun = @(
        $Operation["groups"].Values |
        Where-Object {
            $_["created_this_operation"] -eq $true
        }
    ).Count

    $AssignedLicensesThisRun = @(
        $Operation["licenses"].Values |
        Where-Object {
            $_["assigned_this_operation"] -eq $true
        }
    ).Count

    $AddedMembershipsThisRun = @(
        $Operation["memberships"].Values |
        Where-Object {
            $_["added_this_operation"] -eq $true
        }
    ).Count

    Write-Host ""
    Write-Host "FULL APPLY COMPLETE"
    Write-Host "-------------------"
    Write-Host "planned_users_verified=10"
    Write-Host "business_premium_users_verified=8"
    Write-Host "emergency_unlicensed_users_verified=2"
    Write-Host "groups_verified=11"
    Write-Host "memberships_verified=16"

    Write-Host (
        "users_created_by_operation=" +
        $CreatedUsersThisRun
    )

    Write-Host (
        "groups_created_by_operation=" +
        $CreatedGroupsThisRun
    )

    Write-Host (
        "licenses_assigned_by_operation=" +
        $AssignedLicensesThisRun
    )

    Write-Host (
        "memberships_added_by_operation=" +
        $AddedMembershipsThisRun
    )

    Write-Host "credential_output_to_console=False"
    Write-Host "automatic_rollback_performed=False"
    Write-Host "PASS: Full identity foundation verified."
}
catch {
    if ($OperationExists) {
        $Operation["status"] = "failed"
        $Operation["failed_stage"] = $CurrentStage
        $Operation["failure_type"] = (
            $_.Exception.GetType().FullName
        )

        Save-Operation `
            -Operation $Operation
    }

    throw
}
finally {
    Disconnect-MgGraph `
        -ErrorAction SilentlyContinue |
        Out-Null

    if ($null -ne $LockStream) {
        $LockStream.Dispose()
        $LockStream = $null

        Remove-Item `
            -LiteralPath $LockPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
