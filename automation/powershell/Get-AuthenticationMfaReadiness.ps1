#Requires -Version 7.2

[CmdletBinding()]
param(
    [string]$RawOutputPath = (
        "local-evidence/" +
        "authentication-mfa-readiness-raw.json"
    ),

    [string]$SanitizedOutputPath = (
        "docs/evidence/" +
        "authentication-mfa-readiness.json"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RequiredScopes = @(
    "Policy.Read.All"
)

$GraphGetCount = 0

function Invoke-ReadOnlyGraphRequest {
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

Import-Module `
    Microsoft.Graph.Authentication `
    -ErrorAction Stop

$RawDirectory = Split-Path `
    -Parent `
    $RawOutputPath

$SanitizedDirectory = Split-Path `
    -Parent `
    $SanitizedOutputPath

if (
    (
        -not [string]::IsNullOrWhiteSpace(
            $RawDirectory
        )
    ) -and (
        -not (
            Test-Path `
                -LiteralPath $RawDirectory
        )
    )
) {
    New-Item `
        -ItemType Directory `
        -Path $RawDirectory `
        -Force |
        Out-Null
}

if (
    (
        -not [string]::IsNullOrWhiteSpace(
            $SanitizedDirectory
        )
    ) -and (
        -not (
            Test-Path `
                -LiteralPath $SanitizedDirectory
        )
    )
) {
    New-Item `
        -ItemType Directory `
        -Path $SanitizedDirectory `
        -Force |
        Out-Null
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
        throw "Microsoft Graph context unavailable."
    }

    $MissingScopes = @(
        $RequiredScopes |
        Where-Object {
            $_ -notin $Context.Scopes
        }
    )

    if ($MissingScopes.Count -ne 0) {
        throw (
            "Required read-only Graph scope missing."
        )
    }

    $AuthenticationPolicy = (
        Invoke-ReadOnlyGraphRequest `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "policies/authenticationMethodsPolicy"
            )
    )

    $SecurityDefaults = (
        Invoke-ReadOnlyGraphRequest `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "policies/" +
                "identitySecurityDefaultsEnforcementPolicy"
            )
    )

    if ($GraphGetCount -ne 2) {
        throw (
            "Unexpected Graph resource GET count: " +
            $GraphGetCount
        )
    }

    $ConfigurationValue = (
        Get-OptionalPropertyValue `
            -Object $AuthenticationPolicy `
            -Name "authenticationMethodConfigurations"
    )

    if ($null -eq $ConfigurationValue) {
        throw (
            "Authentication method configurations " +
            "were not returned."
        )
    }

    $Configurations = @(
        $ConfigurationValue
    )

    if ($Configurations.Count -eq 0) {
        throw (
            "Authentication method configuration " +
            "collection is empty."
        )
    }

    $MethodSummaries = @(
        foreach ($Configuration in $Configurations) {
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

            $State = (
                Get-OptionalString `
                    -Object $Configuration `
                    -Name "state"
            )

            $IncludeTargets = (
                Get-OptionalPropertyValue `
                    -Object $Configuration `
                    -Name "includeTargets"
            )

            $ExcludeTargets = (
                Get-OptionalPropertyValue `
                    -Object $Configuration `
                    -Name "excludeTargets"
            )

            $IncludeTargetCount = 0
            $ExcludeTargetCount = 0

            if ($null -ne $IncludeTargets) {
                $IncludeTargetCount = @(
                    $IncludeTargets
                ).Count
            }

            if ($null -ne $ExcludeTargets) {
                $ExcludeTargetCount = @(
                    $ExcludeTargets
                ).Count
            }

            [ordered]@{
                configuration_type = $Type
                state = $State
                include_target_count = (
                    [int]$IncludeTargetCount
                )
                exclude_target_count = (
                    [int]$ExcludeTargetCount
                )
            }
        }
    )

    $MethodSummaries = @(
        $MethodSummaries |
        Sort-Object `
            configuration_type,
            state
    )

    $RegistrationEnforcement = (
        Get-OptionalPropertyValue `
            -Object $AuthenticationPolicy `
            -Name "registrationEnforcement"
    )

    $RegistrationCampaign = (
        Get-OptionalPropertyValue `
            -Object $RegistrationEnforcement `
            -Name (
                "authenticationMethods" +
                "RegistrationCampaign"
            )
    )

    $RegistrationCampaignState = (
        Get-OptionalString `
            -Object $RegistrationCampaign `
            -Name "state"
    )

    $SystemCredentialPreferences = (
        Get-OptionalPropertyValue `
            -Object $AuthenticationPolicy `
            -Name "systemCredentialPreferences"
    )

    $SystemCredentialPreferencesState = (
        Get-OptionalString `
            -Object $SystemCredentialPreferences `
            -Name "state"
    )

    $PolicyMigrationState = (
        Get-OptionalString `
            -Object $AuthenticationPolicy `
            -Name "policyMigrationState"
    )

    $SecurityDefaultsEnabledValue = (
        Get-OptionalPropertyValue `
            -Object $SecurityDefaults `
            -Name "isEnabled"
    )

    if ($null -eq $SecurityDefaultsEnabledValue) {
        throw (
            "Security Defaults enabled state " +
            "was not returned."
        )
    }

    $SecurityDefaultsEnabled = (
        [bool]$SecurityDefaultsEnabledValue
    )

    $RawEvidence = [ordered]@{
        schema_version = "1.0"

        evidence_type = (
            "authentication-mfa-readiness-raw"
        )

        authentication_methods_policy = (
            $AuthenticationPolicy
        )

        security_defaults_policy = (
            $SecurityDefaults
        )

        graph_resource_get_count = (
            [int]$GraphGetCount
        )

        graph_resource_write_count = 0
    }

    $RawEvidence |
        ConvertTo-Json -Depth 50 |
        Set-Content `
            -LiteralPath $RawOutputPath `
            -Encoding utf8

    $SanitizedEvidence = [ordered]@{
        schema_version = "1.0"

        evidence_type = (
            "authentication-mfa-readiness"
        )

        validation_date = "2026-10-08"

        feature = (
            "authentication-mfa-foundation"
        )

        collection_mode = "read_only"

        graph = [ordered]@{
            requested_scopes = @(
                "Policy.Read.All"
            )

            resource_get_count = (
                [int]$GraphGetCount
            )

            resource_write_count = 0
        }

        security_defaults = [ordered]@{
            enabled = (
                [bool]$SecurityDefaultsEnabled
            )

            modified = $false
        }

        authentication_methods_policy = [ordered]@{
            policy_migration_state = (
                $PolicyMigrationState
            )

            registration_campaign_state = (
                $RegistrationCampaignState
            )

            system_credential_preferences_state = (
                $SystemCredentialPreferencesState
            )

            method_configuration_count = (
                [int]$Configurations.Count
            )

            methods = $MethodSummaries
        }

        feature4a_assertions = [ordered]@{
            authentication_policy_modified = $false
            security_defaults_modified = $false
            conditional_access_modified = $false
            privileged_roles_modified = $false
            user_authentication_methods_modified = $false
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
        ConvertTo-Json -Depth 30 |
        Set-Content `
            -LiteralPath $SanitizedOutputPath `
            -Encoding utf8

    Write-Host ""
    Write-Host "AUTHENTICATION / MFA READINESS COMPLETE"
    Write-Host "---------------------------------------"

    Write-Host (
        "graph_resource_get_count=" +
        $GraphGetCount
    )

    Write-Host "graph_resource_write_count=0"

    Write-Host (
        "authentication_method_configuration_count=" +
        $Configurations.Count
    )

    Write-Host (
        "security_defaults_enabled=" +
        $SecurityDefaultsEnabled
    )

    Write-Host (
        "authentication_policy_modified=False"
    )

    Write-Host (
        "security_defaults_modified=False"
    )

    Write-Host (
        "conditional_access_modified=False"
    )
}
finally {
    if ($Connected) {
        Microsoft.Graph.Authentication\Disconnect-MgGraph `
            -ErrorAction SilentlyContinue |
            Out-Null
    }
}
