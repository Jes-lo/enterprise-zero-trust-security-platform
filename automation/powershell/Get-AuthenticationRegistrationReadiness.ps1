#Requires -Version 7.2

[CmdletBinding()]
param(
    [string]$IdentityPath = (
        "configs/identity-foundation.json"
    ),

    [string]$RawOutputPath = (
        "local-evidence/" +
        "authentication-registration-readiness-raw.json"
    ),

    [string]$SanitizedOutputPath = (
        "docs/evidence/" +
        "authentication-registration-readiness.json"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RequiredScopes = @(
    "AuditLog.Read.All",
    "Policy.Read.AuthenticationMethod"
)

$GraphGetCount = 0

function Get-OptionalPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if (
        $Object -is
        [System.Collections.IDictionary]
    ) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }

        return $null
    }

    $Property = (
        $Object.PSObject.Properties[$Name]
    )

    if ($null -eq $Property) {
        return $null
    }

    return $Property.Value
}

function Get-OptionalString {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $Value = Get-OptionalPropertyValue `
        -Object $Object `
        -Name $Name

    if ($null -eq $Value) {
        return $null
    }

    return [string]$Value
}

function Get-OptionalBoolean {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $Value = Get-OptionalPropertyValue `
        -Object $Object `
        -Name $Name

    if ($null -eq $Value) {
        return $null
    }

    return [bool]$Value
}

function Invoke-ReadOnlyGraphGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $script:GraphGetCount++

    return (
        Microsoft.Graph.Authentication\Invoke-MgGraphRequest `
            -Method GET `
            -Uri $Uri
    )
}

function Invoke-PagedReadOnlyGraphGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $Items = @()
    $NextUri = $Uri

    while (
        -not [string]::IsNullOrWhiteSpace(
            $NextUri
        )
    ) {
        $Response = (
            Invoke-ReadOnlyGraphGet `
                -Uri $NextUri
        )

        $Value = (
            Get-OptionalPropertyValue `
                -Object $Response `
                -Name "value"
        )

        if ($null -ne $Value) {
            $Items += @(
                $Value
            )
        }

        $Next = (
            Get-OptionalString `
                -Object $Response `
                -Name "@odata.nextLink"
        )

        if (
            [string]::IsNullOrWhiteSpace(
                $Next
            )
        ) {
            $NextUri = $null
        }
        else {
            $NextUri = $Next
        }
    }

    return $Items
}

function Get-PolicyTargetClass {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$TargetId
    )

    if (
        [string]::IsNullOrWhiteSpace(
            $TargetId
        )
    ) {
        return "missing"
    }

    if (
        $TargetId.Equals(
            "all_users",
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return "all_users"
    }

    if (
        $TargetId -match (
            "^[0-9a-fA-F]{8}-" +
            "[0-9a-fA-F]{4}-" +
            "[0-9a-fA-F]{4}-" +
            "[0-9a-fA-F]{4}-" +
            "[0-9a-fA-F]{12}$"
        )
    ) {
        return "object_reference"
    }

    return "named_reference"
}

Import-Module `
    Microsoft.Graph.Authentication `
    -ErrorAction Stop

if (
    -not (
        Test-Path `
            -LiteralPath $IdentityPath
    )
) {
    throw (
        "Identity contract missing."
    )
}

$Identity = Get-Content `
    -Raw `
    -LiteralPath $IdentityPath |
    ConvertFrom-Json

$Workforce = @(
    $Identity.accounts |
    Where-Object {
        $_.live_creation -eq $true `
        -and
        $_.license_policy -eq "business-premium"
    }
)

$Emergency = @(
    $Identity.accounts |
    Where-Object {
        $_.persona -eq "EMERGENCY_ADMIN"
    }
)

if ($Workforce.Count -ne 8) {
    throw (
        "Expected exactly eight managed workforce identities."
    )
}

if ($Emergency.Count -ne 2) {
    throw (
        "Expected exactly two emergency identities."
    )
}

$Pilot = @(
    $Workforce |
    Where-Object {
        $_.id -eq "EMPLOYEE_01"
    }
)

if ($Pilot.Count -ne 1) {
    throw (
        "Controlled pilot definition invalid."
    )
}

$RawDirectory = Split-Path `
    -Parent `
    $RawOutputPath

$SanitizedDirectory = Split-Path `
    -Parent `
    $SanitizedOutputPath

foreach (
    $Directory in @(
        $RawDirectory,
        $SanitizedDirectory
    )
) {
    if (
        (
            -not [string]::IsNullOrWhiteSpace(
                $Directory
            )
        ) -and (
            -not (
                Test-Path `
                    -LiteralPath $Directory
            )
        )
    ) {
        New-Item `
            -ItemType Directory `
            -Path $Directory `
            -Force |
            Out-Null
    }
}

$Connected = $false

try {
    Microsoft.Graph.Authentication\Connect-MgGraph `
        -Scopes $RequiredScopes `
        -TenantId "organizations" `
        -UseDeviceAuthentication `
        -ContextScope Process `
        -NoWelcome `
        -ErrorAction Stop

    $Connected = $true

    $Context = Get-MgContext

    if ($null -eq $Context) {
        throw (
            "Microsoft Graph context unavailable."
        )
    }

    $MissingScopes = @(
        $RequiredScopes |
        Where-Object {
            $_ -notin $Context.Scopes
        }
    )

    if ($MissingScopes.Count -ne 0) {
        throw (
            "Authenticated session is missing required scopes."
        )
    }

    $AuthenticationPolicy = (
        Invoke-ReadOnlyGraphGet `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "policies/authenticationMethodsPolicy"
            )
    )

    $RegistrationRows = @(
        Invoke-PagedReadOnlyGraphGet `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "reports/authenticationMethods/" +
                "userRegistrationDetails"
            )
    )

    $ManagedRawRows = @()
    $ManagedResults = @()

    foreach (
        $Account in
        (
            $Workforce |
            Sort-Object id
        )
    ) {
        $ExpectedAlias = (
            [string]$Account.alias
        ).ToLowerInvariant()

        $Matches = @(
            $RegistrationRows |
            Where-Object {
                $Upn = (
                    Get-OptionalString `
                        -Object $_ `
                        -Name "userPrincipalName"
                )

                if (
                    [string]::IsNullOrWhiteSpace(
                        $Upn
                    )
                ) {
                    return $false
                }

                $LocalPart = (
                    $Upn.Split(
                        "@",
                        2
                    )[0]
                ).ToLowerInvariant()

                return (
                    $LocalPart -eq
                    $ExpectedAlias
                )
            }
        )

        if ($Matches.Count -gt 1) {
            throw (
                "Registration report returned duplicate " +
                "managed identity match for " +
                [string]$Account.id
            )
        }

        if ($Matches.Count -eq 0) {
            $ManagedResults += [ordered]@{
                account_id = [string]$Account.id
                privilege_class = (
                    [string]$Account.privilege_class
                )
                report_present = $false
                is_mfa_registered = $null
                is_mfa_capable = $null
                is_passwordless_capable = $null
                is_sspr_registered = $null
                is_sspr_capable = $null
                system_preferred_enabled = $null
                methods_registered = @()
                system_preferred_methods = @()
                preferred_secondary_method = $null
            }

            continue
        }

        $Row = $Matches[0]

        $ManagedRawRows += $Row

        $MethodsRegisteredValue = (
            Get-OptionalPropertyValue `
                -Object $Row `
                -Name "methodsRegistered"
        )

        $MethodsRegistered = @()

        if ($null -ne $MethodsRegisteredValue) {
            $MethodsRegistered = @(
                $MethodsRegisteredValue |
                ForEach-Object {
                    [string]$_
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_
                    )
                } |
                Sort-Object -Unique
            )
        }

        $SystemPreferredValue = (
            Get-OptionalPropertyValue `
                -Object $Row `
                -Name (
                    "systemPreferred" +
                    "AuthenticationMethods"
                )
        )

        $SystemPreferredMethods = @()

        if ($null -ne $SystemPreferredValue) {
            $SystemPreferredMethods = @(
                $SystemPreferredValue |
                ForEach-Object {
                    [string]$_
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        $_
                    )
                } |
                Sort-Object -Unique
            )
        }

        $ManagedResults += [ordered]@{
            account_id = [string]$Account.id

            privilege_class = (
                [string]$Account.privilege_class
            )

            report_present = $true

            is_mfa_registered = (
                Get-OptionalBoolean `
                    -Object $Row `
                    -Name "isMfaRegistered"
            )

            is_mfa_capable = (
                Get-OptionalBoolean `
                    -Object $Row `
                    -Name "isMfaCapable"
            )

            is_passwordless_capable = (
                Get-OptionalBoolean `
                    -Object $Row `
                    -Name "isPasswordlessCapable"
            )

            is_sspr_registered = (
                Get-OptionalBoolean `
                    -Object $Row `
                    -Name "isSsprRegistered"
            )

            is_sspr_capable = (
                Get-OptionalBoolean `
                    -Object $Row `
                    -Name "isSsprCapable"
            )

            system_preferred_enabled = (
                Get-OptionalBoolean `
                    -Object $Row `
                    -Name (
                        "isSystemPreferred" +
                        "AuthenticationMethodEnabled"
                    )
            )

            methods_registered = (
                $MethodsRegistered
            )

            system_preferred_methods = (
                $SystemPreferredMethods
            )

            preferred_secondary_method = (
                Get-OptionalString `
                    -Object $Row `
                    -Name (
                        "userPreferredMethodFor" +
                        "SecondaryAuthentication"
                    )
            )
        }
    }

    $ConfigurationValue = (
        Get-OptionalPropertyValue `
            -Object $AuthenticationPolicy `
            -Name (
                "authenticationMethodConfigurations"
            )
    )

    if ($null -eq $ConfigurationValue) {
        throw (
            "Authentication method configurations missing."
        )
    }

    $Configurations = @(
        $ConfigurationValue
    )

    $PolicySummaries = @(
        foreach (
            $Configuration in
            $Configurations
        ) {
            $Type = (
                Get-OptionalString `
                    -Object $Configuration `
                    -Name "@odata.type"
            )

            if (
                (
                    -not [string]::IsNullOrWhiteSpace(
                        $Type
                    )
                ) -and (
                    $Type.StartsWith(
                        "#microsoft.graph."
                    )
                )
            ) {
                $Type = $Type.Substring(
                    "#microsoft.graph.".Length
                )
            }

            $IncludeValue = (
                Get-OptionalPropertyValue `
                    -Object $Configuration `
                    -Name "includeTargets"
            )

            $ExcludeValue = (
                Get-OptionalPropertyValue `
                    -Object $Configuration `
                    -Name "excludeTargets"
            )

            $IncludeTargets = @()

            if ($null -ne $IncludeValue) {
                $IncludeTargets = @(
                    $IncludeValue
                )
            }

            $ExcludeTargets = @()

            if ($null -ne $ExcludeValue) {
                $ExcludeTargets = @(
                    $ExcludeValue
                )
            }

            $ScopeClasses = @(
                $IncludeTargets |
                ForEach-Object {
                    $TargetId = (
                        Get-OptionalString `
                            -Object $_ `
                            -Name "id"
                    )

                    Get-PolicyTargetClass `
                        -TargetId $TargetId
                } |
                Sort-Object -Unique
            )

            [ordered]@{
                configuration_type = $Type

                state = (
                    Get-OptionalString `
                        -Object $Configuration `
                        -Name "state"
                )

                include_target_count = (
                    [int]$IncludeTargets.Count
                )

                exclude_target_count = (
                    [int]$ExcludeTargets.Count
                )

                include_target_scope_classes = (
                    $ScopeClasses
                )
            }
        }
    )

    $PolicySummaries = @(
        $PolicySummaries |
        Sort-Object configuration_type
    )

    $PresentCount = @(
        $ManagedResults |
        Where-Object {
            $_.report_present -eq $true
        }
    ).Count

    $MfaRegisteredCount = @(
        $ManagedResults |
        Where-Object {
            $_.is_mfa_registered -eq $true
        }
    ).Count

    $MfaCapableCount = @(
        $ManagedResults |
        Where-Object {
            $_.is_mfa_capable -eq $true
        }
    ).Count

    $PasswordlessCapableCount = @(
        $ManagedResults |
        Where-Object {
            $_.is_passwordless_capable -eq $true
        }
    ).Count

    $PilotResult = @(
        $ManagedResults |
        Where-Object {
            $_.account_id -eq "EMPLOYEE_01"
        }
    )

    if ($PilotResult.Count -ne 1) {
        throw (
            "Pilot readiness result missing."
        )
    }

    $PilotStatus = $null

    if (
        $PilotResult[0].report_present -ne
        $true
    ) {
        $PilotStatus = (
            "blocked-registration-report-missing"
        )
    }
    elseif (
        $PilotResult[0].is_mfa_registered -eq
        $true
    ) {
        $PilotStatus = (
            "ready-for-existing-registration-validation"
        )
    }
    else {
        $PilotStatus = (
            "ready-for-controlled-strong-method-registration"
        )
    }

    $RawEvidence = [ordered]@{
        schema_version = "1.0"

        evidence_type = (
            "authentication-registration-readiness-raw"
        )

        authentication_methods_policy = (
            $AuthenticationPolicy
        )

        managed_registration_rows = (
            $ManagedRawRows
        )

        managed_workforce_count = (
            [int]$Workforce.Count
        )

        disabled_emergency_count = (
            [int]$Emergency.Count
        )

        graph_resource_get_count = (
            [int]$GraphGetCount
        )

        graph_resource_write_count = 0
    }

    $RawEvidence |
        ConvertTo-Json -Depth 60 |
        Set-Content `
            -LiteralPath $RawOutputPath `
            -Encoding utf8

    $SanitizedEvidence = [ordered]@{
        schema_version = "1.0"

        evidence_type = (
            "authentication-registration-readiness"
        )

        validation_date = "2026-10-08"

        feature = (
            "authentication-mfa-foundation"
        )

        phase = "feature4b"

        collection_mode = "read_only"

        graph = [ordered]@{
            requested_scopes = @(
                "AuditLog.Read.All",
                "Policy.Read.AuthenticationMethod"
            )

            resource_get_count = (
                [int]$GraphGetCount
            )

            resource_write_count = 0
        }

        population = [ordered]@{
            managed_workforce_expected = 8

            managed_workforce_report_present = (
                [int]$PresentCount
            )

            disabled_emergency_excluded = 2
        }

        readiness_summary = [ordered]@{
            mfa_registered = (
                [int]$MfaRegisteredCount
            )

            mfa_capable = (
                [int]$MfaCapableCount
            )

            passwordless_capable = (
                [int]$PasswordlessCapableCount
            )
        }

        managed_workforce = (
            $ManagedResults
        )

        authentication_method_targeting = (
            $PolicySummaries
        )

        pilot = [ordered]@{
            account_id = "EMPLOYEE_01"

            privilege_class = "PC3"

            readiness_status = (
                $PilotStatus
            )

            report_present = (
                [bool]$PilotResult[0].report_present
            )

            is_mfa_registered = (
                $PilotResult[0].is_mfa_registered
            )

            is_mfa_capable = (
                $PilotResult[0].is_mfa_capable
            )

            is_passwordless_capable = (
                $PilotResult[0].is_passwordless_capable
            )

            methods_registered = @(
                $PilotResult[0].methods_registered
            )
        }

        feature4b_assertions = [ordered]@{
            authentication_policy_modified = $false
            security_defaults_modified = $false
            conditional_access_modified = $false
            user_authentication_methods_modified = $false
            emergency_identity_state_modified = $false
        }

        privacy = [ordered]@{
            tenant_domain_present = $false
            tenant_id_present = $false
            complete_upn_present = $false
            graph_object_id_present = $false
            credential_secret_present = $false
            oauth_token_present = $false
            device_login_code_present = $false
        }
    }

    $SanitizedEvidence |
        ConvertTo-Json -Depth 40 |
        Set-Content `
            -LiteralPath $SanitizedOutputPath `
            -Encoding utf8

    Write-Host ""
    Write-Host "FEATURE 4B REGISTRATION READINESS COMPLETE"
    Write-Host "------------------------------------------"

    Write-Host (
        "graph_resource_get_count=" +
        $GraphGetCount
    )

    Write-Host "graph_resource_write_count=0"

    Write-Host (
        "managed_workforce_expected=" +
        $Workforce.Count
    )

    Write-Host (
        "managed_workforce_report_present=" +
        $PresentCount
    )

    Write-Host (
        "mfa_registered=" +
        $MfaRegisteredCount
    )

    Write-Host (
        "mfa_capable=" +
        $MfaCapableCount
    )

    Write-Host (
        "passwordless_capable=" +
        $PasswordlessCapableCount
    )

    Write-Host (
        "pilot_readiness_status=" +
        $PilotStatus
    )

    Write-Host "authentication_policy_modified=False"
    Write-Host "security_defaults_modified=False"
    Write-Host "conditional_access_modified=False"
    Write-Host "user_authentication_methods_modified=False"
}
finally {
    if ($Connected) {
        Microsoft.Graph.Authentication\Disconnect-MgGraph `
            -ErrorAction SilentlyContinue |
            Out-Null
    }
}
