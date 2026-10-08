#Requires -Version 7.2

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (
    git rev-parse --show-toplevel
).Trim()

Set-Location $Root

$IdentityPath = "configs/identity-foundation.json"
$ProvisioningPath = "configs/identity-provisioning.json"

$PilotOperationPath = (
    "local-evidence/" +
    "pilot-EMPLOYEE_01-operation.json"
)

$OutputPath = (
    "local-evidence/" +
    "identity-full-provisioning-plan.json"
)

foreach ($Path in @(
    $IdentityPath,
    $ProvisioningPath
)) {
    if (-not (Test-Path $Path)) {
        throw "Required configuration missing: $Path"
    }
}

if (-not (
    Get-Module -ListAvailable `
        -Name Microsoft.Graph.Authentication
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

$RequiredScopes = @(
    $Provisioning.apply.full_plan_graph_scopes
)

$ForbiddenRequestedScopePatterns = @(
    "ReadWrite",
    "User.Create",
    "Directory."
)

# Validate what this script explicitly REQUESTS.
# The effective delegated token can contain previously consented
# Microsoft Graph scopes for the same client/resource.
foreach ($Scope in $RequiredScopes) {
    foreach ($Pattern in $ForbiddenRequestedScopePatterns) {
        if ($Scope -like "*$Pattern*") {
            throw (
                "Configured Full Plan scope is not read-only: " +
                $Scope
            )
        }
    }
}

$AccountById = @{}

foreach ($Account in $Identity.accounts) {
    if ($AccountById.ContainsKey(
        [string]$Account.id
    )) {
        throw (
            "Duplicate account ID in contract: " +
            $Account.id
        )
    }

    $AccountById[
        [string]$Account.id
    ] = $Account
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
    throw "Contract must contain exactly 10 live-creation identities."
}

if ($LicensedAccounts.Count -ne 8) {
    throw "Contract must contain exactly 8 licensed live identities."
}

if ($EmergencyAccounts.Count -ne 2) {
    throw "Contract must contain exactly 2 emergency identities."
}

if ($PlannedGroups.Count -ne 11) {
    throw "Contract must contain exactly 11 security groups."
}

foreach ($Emergency in $EmergencyAccounts) {
    if ($Emergency.license_policy -ne "unlicensed") {
        throw (
            "Emergency account must be unlicensed: " +
            $Emergency.id
        )
    }

    if ($Emergency.cloud_only -ne $true) {
        throw (
            "Emergency account must be cloud-only: " +
            $Emergency.id
        )
    }
}

foreach ($Group in $PlannedGroups) {
    if ($Group.group_type -ne "security") {
        throw (
            "Only security groups are allowed: " +
            $Group.id
        )
    }

    if ($Group.membership_type -ne "assigned") {
        throw (
            "Only assigned membership is allowed: " +
            $Group.id
        )
    }

    if (
        [int]$Group.membership_managed_in_feature -ne 3 -and
        @($Group.members).Count -ne 0
    ) {
        throw (
            "Later-feature group contains premature members: " +
            $Group.id
        )
    }
}

function Protect-LocalEvidenceDirectory {
    New-Item `
        -ItemType Directory `
        -Path "local-evidence" `
        -Force |
        Out-Null

    if ($IsLinux) {
        & chmod 700 -- "local-evidence"

        if ($LASTEXITCODE -ne 0) {
            throw (
                "Unable to protect local-evidence directory."
            )
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
        ConvertTo-Json -Depth 20 |
        Set-Content `
            -Path $Path `
            -Encoding utf8

    if ($IsLinux) {
        & chmod 600 -- $Path

        if ($LASTEXITCODE -ne 0) {
            throw (
                "Unable to protect local evidence file: " +
                $Path
            )
        }
    }
}

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
            throw (
                "Required read-only Graph scope missing: " +
                $Scope
            )
        }
    }

    # Microsoft identity tokens can contain delegated scopes that were
    # consented previously for the same client/resource. Those scopes
    # are effective capabilities of the token, but they were not
    # requested by this Full Plan execution.
    #
    # This script therefore records the presence of such a superset
    # while relying on an independently validated GET-only HTTP surface.
    $EffectiveBroadScopes = @(
        foreach ($GrantedScope in @($Context.Scopes)) {
            foreach ($Pattern in $ForbiddenRequestedScopePatterns) {
                if ($GrantedScope -like "*$Pattern*") {
                    $GrantedScope
                    break
                }
            }
        }
    ) |
        Sort-Object -Unique

    if ($EffectiveBroadScopes.Count -gt 0) {
        Write-Warning (
            "Effective token contains previously consented broader " +
            "Microsoft Graph scopes. Full Plan remains GET-only. " +
            "Inherited broad scope count=" +
            $EffectiveBroadScopes.Count
        )
    }

    $UsersResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "users?" +
            "`$select=id,displayName,userPrincipalName" +
            "&`$top=999"
        )

    $GroupsResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "groups?" +
            "`$select=id,displayName,mailNickname," +
            "securityEnabled,mailEnabled,groupTypes" +
            "&`$top=999"
        )

    $SkuResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri (
            "https://graph.microsoft.com/v1.0/" +
            "subscribedSkus"
        )

    $ExistingUsers = @(
        $UsersResponse.value
    )

    $ExistingGroups = @(
        $GroupsResponse.value
    )

    $BootstrapDefinition = @(
        $Identity.accounts |
        Where-Object {
            $_.id -eq "BOOTSTRAP_ADMIN"
        }
    )

    if ($BootstrapDefinition.Count -ne 1) {
        throw (
            "Expected exactly one bootstrap definition."
        )
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
        throw (
            "Expected exactly one live bootstrap identity; " +
            "found " +
            $LiveBootstrap.Count
        )
    }

    $BootstrapUpn = (
        [string]$LiveBootstrap[0].userPrincipalName
    ).ToLowerInvariant()

    $UpnParts = $BootstrapUpn.Split("@")

    if ($UpnParts.Count -ne 2) {
        throw "Bootstrap UPN format invalid."
    }

    $TenantDomain = $UpnParts[1]

    $UsersByUpn = @{}

    foreach ($User in $ExistingUsers) {
        if (-not $User.userPrincipalName) {
            continue
        }

        $Key = (
            [string]$User.userPrincipalName
        ).ToLowerInvariant()

        if ($UsersByUpn.ContainsKey($Key)) {
            throw (
                "Duplicate live UPN detected."
            )
        }

        $UsersByUpn[$Key] = $User
    }

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

    $SpbSkuId = [string]$Spb.skuId

    $ExistingPlannedAccounts = @()
    $UsersToCreate = @()
    $LicensesAlreadyAssigned = @()
    $LicensesToAssign = @()
    $Conflicts = @()

    $LiveUserIdByAccountId = @{}

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
                    "user-display-name-collision:" +
                    $AccountId
                )
            }

            $UsersToCreate += $AccountId
        }
        else {
            $ExistingPlannedAccounts += $AccountId

            $LiveUserIdByAccountId[
                $AccountId
            ] = [string]$ExactUser.id

            if (
                [string]$ExactUser.displayName -ne
                [string]$Account.display_name
            ) {
                $Conflicts += (
                    "user-display-name-drift:" +
                    $AccountId
                )
            }

            if ($AliasMatches.Count -ne 1) {
                $Conflicts += (
                    "user-alias-not-unique:" +
                    $AccountId
                )
            }

            if (
                $AccountId -eq "EMPLOYEE_01"
            ) {
                if (-not (
                    Test-Path $PilotOperationPath
                )) {
                    $Conflicts += (
                        "pilot-local-evidence-missing:" +
                        $AccountId
                    )
                }
                else {
                    $PilotOperation = Get-Content `
                        -Raw `
                        $PilotOperationPath |
                        ConvertFrom-Json

                    if (
                        [string]$PilotOperation.object_id -ne
                        [string]$ExactUser.id
                    ) {
                        $Conflicts += (
                            "pilot-object-id-mismatch:" +
                            $AccountId
                        )
                    }
                }
            }
        }

        if (
            $Account.license_policy -eq
            "business-premium"
        ) {
            if ($null -eq $ExactUser) {
                $LicensesToAssign += $AccountId
            }
            else {
                $LicenseDetails = Invoke-MgGraphRequest `
                    -Method GET `
                    -Uri (
                        "https://graph.microsoft.com/v1.0/" +
                        "users/" +
                        $ExactUser.id +
                        "/licenseDetails?`$select=skuId"
                    )

                $AssignedSkuIds = @(
                    $LicenseDetails.value |
                    ForEach-Object {
                        [string]$_.skuId
                    }
                )

                if ($SpbSkuId -in $AssignedSkuIds) {
                    $LicensesAlreadyAssigned += $AccountId
                }
                else {
                    $LicensesToAssign += $AccountId
                }
            }
        }
        elseif (
            $Account.license_policy -eq
            "unlicensed"
        ) {
            if ($null -ne $ExactUser) {
                $LicenseDetails = Invoke-MgGraphRequest `
                    -Method GET `
                    -Uri (
                        "https://graph.microsoft.com/v1.0/" +
                        "users/" +
                        $ExactUser.id +
                        "/licenseDetails?`$select=skuId"
                    )

                if (
                    @($LicenseDetails.value).Count -gt 0
                ) {
                    $Conflicts += (
                        "unlicensed-account-has-license:" +
                        $AccountId
                    )
                }
            }
        }
        else {
            $Conflicts += (
                "unexpected-license-policy:" +
                $AccountId
            )
        }
    }

    $ExistingPlannedGroups = @()
    $GroupsToCreate = @()
    $MembershipsToAdd = @()

    $LiveGroupIdByContractId = @{}

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
            $GroupsToCreate += $GroupId
            continue
        }

        if (
            $Related.Count -ne 1 -or
            $Exact.Count -ne 1
        ) {
            $Conflicts += (
                "group-name-or-nickname-collision:" +
                $GroupId
            )

            continue
        }

        $LiveGroup = $Exact[0]

        if ($LiveGroup.securityEnabled -ne $true) {
            $Conflicts += (
                "group-security-enabled-drift:" +
                $GroupId
            )
        }

        if ($LiveGroup.mailEnabled -ne $false) {
            $Conflicts += (
                "group-mail-enabled-drift:" +
                $GroupId
            )
        }

        if (@($LiveGroup.groupTypes).Count -ne 0) {
            $Conflicts += (
                "group-type-drift:" +
                $GroupId
            )
        }

        $ExistingPlannedGroups += $GroupId

        $LiveGroupIdByContractId[
            $GroupId
        ] = [string]$LiveGroup.id
    }

    foreach ($Group in $Feature3MembershipGroups) {
        $GroupId = [string]$Group.id

        $CurrentMemberIds = @()

        if (
            $LiveGroupIdByContractId.ContainsKey(
                $GroupId
            )
        ) {
            $MembersResponse = Invoke-MgGraphRequest `
                -Method GET `
                -Uri (
                    "https://graph.microsoft.com/v1.0/" +
                    "groups/" +
                    $LiveGroupIdByContractId[$GroupId] +
                    "/members?`$select=id&`$top=999"
                )

            $CurrentMemberIds = @(
                $MembersResponse.value |
                ForEach-Object {
                    [string]$_.id
                }
            )
        }

        foreach ($MemberAccountId in @(
            $Group.members
        )) {
            $MemberAccountId = [string]$MemberAccountId

            if (-not $AccountById.ContainsKey(
                $MemberAccountId
            )) {
                $Conflicts += (
                    "unknown-membership-account:" +
                    $GroupId +
                    ":" +
                    $MemberAccountId
                )

                continue
            }

            $MembershipMissing = $true

            if (
                $LiveGroupIdByContractId.ContainsKey(
                    $GroupId
                ) -and
                $LiveUserIdByAccountId.ContainsKey(
                    $MemberAccountId
                )
            ) {
                $LiveMemberId = (
                    $LiveUserIdByAccountId[
                        $MemberAccountId
                    ]
                )

                if ($LiveMemberId -in $CurrentMemberIds) {
                    $MembershipMissing = $false
                }
            }

            if ($MembershipMissing) {
                $MembershipsToAdd += [ordered]@{
                    group_id = $GroupId
                    account_id = $MemberAccountId
                }
            }
        }
    }

    $CapacitySufficient = (
        $Available -ge $LicensesToAssign.Count
    )

    $EmergencyToCreate = @(
        $EmergencyAccounts |
        Where-Object {
            $_.id -in $UsersToCreate
        } |
        ForEach-Object {
            [string]$_.id
        }
    )

    $StandardUsersToCreate = @(
        $UsersToCreate |
        Where-Object {
            $_ -notin @(
                $EmergencyAccounts |
                ForEach-Object {
                    [string]$_.id
                }
            )
        }
    )

    $PlanResult = [ordered]@{
        schema_version = "1.0"
        evidence_type = "identity-full-provisioning-plan"

        write_operations_performed = $false

        current_state = [ordered]@{
            existing_planned_accounts = @(
                $ExistingPlannedAccounts |
                Sort-Object
            )

            existing_planned_groups = @(
                $ExistingPlannedGroups |
                Sort-Object
            )

            business_premium = [ordered]@{
                enabled_units = $Enabled
                warning_units = $Warning
                consumed_units = $Consumed
                safely_available_units = $Available
            }
        }

        delta = [ordered]@{
            users_to_create = @(
                $UsersToCreate |
                Sort-Object
            )

            standard_users_to_create = @(
                $StandardUsersToCreate |
                Sort-Object
            )

            emergency_users_to_create = @(
                $EmergencyToCreate |
                Sort-Object
            )

            licenses_already_assigned = @(
                $LicensesAlreadyAssigned |
                Sort-Object
            )

            licenses_to_assign = @(
                $LicensesToAssign |
                Sort-Object
            )

            groups_to_create = @(
                $GroupsToCreate |
                Sort-Object
            )

            memberships_to_add = @(
                $MembershipsToAdd |
                Sort-Object group_id, account_id
            )
        }

        safety = [ordered]@{
            requested_scopes_read_only = $true
            http_methods_get_only = $true

            effective_token_scope_superset_detected = (
                $EffectiveBroadScopes.Count -gt 0
            )

            effective_token_broad_scope_count = (
                $EffectiveBroadScopes.Count
            )

            conflicts = @(
                $Conflicts |
                Sort-Object -Unique
            )

            license_capacity_sufficient = (
                $CapacitySufficient
            )

            standard_accounts_initially_enabled = (
                [bool]$Provisioning.apply.standard_accounts_initially_enabled
            )

            emergency_accounts_initially_enabled = (
                [bool]$Provisioning.apply.emergency_accounts_initially_enabled
            )

            feature3_memberships_only = $true

            later_feature_memberships_modified = $false
        }
    }

    Write-PrivateJson `
        -Path $OutputPath `
        -Value $PlanResult

    Write-Host ""
    Write-Host "FULL IDENTITY FOUNDATION PLAN"
    Write-Host "-----------------------------"

    Write-Host (
        "existing_planned_accounts=" +
        $ExistingPlannedAccounts.Count
    )

    Write-Host (
        "users_to_create=" +
        $UsersToCreate.Count
    )

    Write-Host (
        "standard_users_to_create=" +
        $StandardUsersToCreate.Count
    )

    Write-Host (
        "emergency_users_to_create=" +
        $EmergencyToCreate.Count
    )

    Write-Host (
        "licenses_already_assigned=" +
        $LicensesAlreadyAssigned.Count
    )

    Write-Host (
        "licenses_to_assign=" +
        $LicensesToAssign.Count
    )

    Write-Host (
        "business_premium_available=" +
        $Available
    )

    Write-Host (
        "license_capacity_sufficient=" +
        $CapacitySufficient
    )

    Write-Host (
        "existing_planned_groups=" +
        $ExistingPlannedGroups.Count
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
        "conflicts=" +
        @(
            $Conflicts |
            Sort-Object -Unique
        ).Count
    )

    Write-Host (
        "requested_scopes_read_only=True"
    )

    Write-Host (
        "http_methods_get_only=True"
    )

    Write-Host (
        "effective_token_scope_superset_detected=" +
        ($EffectiveBroadScopes.Count -gt 0)
    )

    Write-Host (
        "effective_token_broad_scope_count=" +
        $EffectiveBroadScopes.Count
    )

    Write-Host (
        "emergency_accounts_initially_enabled=" +
        [bool]$Provisioning.apply.emergency_accounts_initially_enabled
    )

    Write-Host "write_operations_performed=False"

    Write-Host ""

    Write-Host (
        "PASS: sanitized plan written to " +
        $OutputPath
    )

    if ($Conflicts.Count -gt 0) {
        throw (
            "Full plan contains conflicts. " +
            "No Apply is allowed."
        )
    }

    if (-not $CapacitySufficient) {
        throw (
            "Insufficient Business Premium capacity. " +
            "No Apply is allowed."
        )
    }
}
finally {
    Disconnect-MgGraph `
        -ErrorAction SilentlyContinue |
        Out-Null
}
