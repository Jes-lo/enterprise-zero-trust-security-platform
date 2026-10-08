#Requires -Version 7.2

[CmdletBinding()]
param(
    [string]$CredentialPath = (
        "local-evidence/" +
        "pilot-EMPLOYEE_01-credentials.json"
    ),

    [string]$ReadinessPath = (
        "docs/evidence/" +
        "authentication-registration-readiness.json"
    ),

    [string]$RawOutputPath = (
        "local-evidence/" +
        "authentication-pilot-registration-raw.json"
    ),

    [string]$SanitizedOutputPath = (
        "docs/evidence/" +
        "authentication-pilot-registration-validation.json"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RequiredScopes = @(
    "UserAuthenticationMethod.Read"
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

foreach (
    $Path in @(
        $CredentialPath,
        $ReadinessPath
    )
) {
    if (
        -not (
            Test-Path `
                -LiteralPath $Path
        )
    ) {
        throw (
            "Required Feature 4C input missing."
        )
    }
}

$Credential = Get-Content `
    -Raw `
    -LiteralPath $CredentialPath |
    ConvertFrom-Json

$Readiness = Get-Content `
    -Raw `
    -LiteralPath $ReadinessPath |
    ConvertFrom-Json

if (
    [string]$Credential.account_id -ne
    "EMPLOYEE_01"
) {
    throw (
        "Pilot credential account mismatch."
    )
}

if (
    [string]$Readiness.pilot.account_id -ne
    "EMPLOYEE_01"
) {
    throw (
        "Feature 4B pilot evidence mismatch."
    )
}

if (
    [string]$Readiness.pilot.readiness_status -ne
    "ready-for-controlled-strong-method-registration"
) {
    throw (
        "Feature 4B did not authorize the registration path."
    )
}

$ExpectedUpn = (
    [string]$Credential.user_principal_name
).ToLowerInvariant()

if (
    [string]::IsNullOrWhiteSpace(
        $ExpectedUpn
    )
) {
    throw (
        "Expected pilot UPN unavailable."
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

Import-Module `
    Microsoft.Graph.Authentication `
    -ErrorAction Stop

$Connected = $false

try {
    Microsoft.Graph.Authentication\Disconnect-MgGraph `
        -ErrorAction SilentlyContinue |
        Out-Null

    Write-Host ""
    Write-Host "FEATURE 4C — PILOT SELF-VERIFICATION"
    Write-Host "------------------------------------"
    Write-Host (
        "Sign in as the EMPLOYEE_01 pilot account."
    )
    Write-Host (
        "Do not authenticate using the bootstrap administrator."
    )
    Write-Host (
        "Do not paste the device-login code into chat."
    )
    Write-Host ""

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
            "Pilot Graph context lacks required self-read scope."
        )
    }

    $AuthenticatedAccount = (
        [string]$Context.Account
    ).ToLowerInvariant()

    if (
        $AuthenticatedAccount -ne
        $ExpectedUpn
    ) {
        throw (
            "Wrong account authenticated. " +
            "Expected the controlled pilot."
        )
    }

    $Response = (
        Invoke-ReadOnlyGraphGet `
            -Uri (
                "https://graph.microsoft.com/v1.0/" +
                "me/authentication/methods"
            )
    )

    if ($GraphGetCount -ne 1) {
        throw (
            "Unexpected Graph GET count."
        )
    }

    $Value = (
        Get-OptionalPropertyValue `
            -Object $Response `
            -Name "value"
    )

    $Methods = @()

    if ($null -ne $Value) {
        $Methods = @(
            $Value
        )
    }

    $MethodTypes = @(
        foreach ($Method in $Methods) {
            $Type = (
                [string](
                    Get-OptionalPropertyValue `
                        -Object $Method `
                        -Name "@odata.type"
                )
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

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $Type
                )
            ) {
                $Type
            }
        }
    )

    $MethodTypes = @(
        $MethodTypes |
        Sort-Object -Unique
    )

    $AuthenticatorMethods = @(
        $MethodTypes |
        Where-Object {
            $_ -eq (
                "microsoftAuthenticator" +
                "AuthenticationMethod"
            )
        }
    )

    if ($AuthenticatorMethods.Count -lt 1) {
        throw (
            "Microsoft Authenticator registration " +
            "was not found for the pilot."
        )
    }

    $RawEvidence = [ordered]@{
        schema_version = "1.0"

        evidence_type = (
            "authentication-pilot-registration-raw"
        )

        account_id = "EMPLOYEE_01"

        authenticated_account_matches_expected = $true

        authentication_methods_response = (
            $Response
        )

        graph_resource_get_count = (
            [int]$GraphGetCount
        )

        graph_resource_write_count = 0
    }

    $RawEvidence |
        ConvertTo-Json -Depth 40 |
        Set-Content `
            -LiteralPath $RawOutputPath `
            -Encoding utf8

    $SanitizedEvidence = [ordered]@{
        schema_version = "1.0"

        evidence_type = (
            "authentication-pilot-registration-validation"
        )

        validation_date = "2026-10-08"

        feature = (
            "authentication-mfa-foundation"
        )

        phase = "feature4c"

        pilot = [ordered]@{
            account_id = "EMPLOYEE_01"
            privilege_class = "PC3"
            authenticated_account_matches_expected = $true
            microsoft_authenticator_registered = $true
            authentication_method_count = (
                [int]$Methods.Count
            )
            method_types = (
                $MethodTypes
            )
        }

        graph = [ordered]@{
            requested_scopes = @(
                "UserAuthenticationMethod.Read"
            )
            resource = (
                "/me/authentication/methods"
            )
            resource_get_count = (
                [int]$GraphGetCount
            )
            resource_write_count = 0
        }

        tenant_controls = [ordered]@{
            security_defaults_modified = $false
            authentication_methods_policy_modified = $false
            conditional_access_modified = $false
            privileged_roles_modified = $false
            emergency_identity_state_modified = $false
        }

        privacy = [ordered]@{
            tenant_domain_present = $false
            tenant_id_present = $false
            complete_upn_present = $false
            graph_object_id_present = $false
            credential_secret_present = $false
            registration_secret_present = $false
            qr_payload_present = $false
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
    Write-Host (
        "PASS: pilot account authenticated."
    )

    Write-Host (
        "PASS: Microsoft Authenticator registration found."
    )

    Write-Host (
        "authentication_method_count=" +
        $Methods.Count
    )

    Write-Host "graph_resource_get_count=1"
    Write-Host "graph_resource_write_count=0"
}
finally {
    if ($Connected) {
        Microsoft.Graph.Authentication\Disconnect-MgGraph `
            -ErrorAction SilentlyContinue |
            Out-Null
    }
}
