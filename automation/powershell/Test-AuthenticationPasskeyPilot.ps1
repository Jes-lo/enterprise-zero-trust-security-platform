#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        "TenantPolicy",
        "PilotSelfRead"
    )]
    [string]$Mode,

    [string]$CredentialPath = (
        "local-evidence/" +
        "pilot-EMPLOYEE_01-credentials.json"
    ),

    [Parameter(Mandatory)]
    [string]$RawOutputPath,

    [Parameter(Mandatory)]
    [string]$SanitizedOutputPath
)

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"

$GraphGetCount = 0

$AuthenticatorAaguids = @(
    "de1e552d-db1d-4423-a619-566b625cdc84",
    "90a3ccdf-635c-4729-a248-9b709135078f"
)

function Get-ObjectValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if (
        $InputObject -is
        [System.Collections.IDictionary]
    ) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
    }

    $Property = (
        $InputObject.PSObject.Properties[$Name]
    )

    if ($null -ne $Property) {
        return $Property.Value
    }

    return $null
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
            -Uri $Uri `
            -ErrorAction Stop
    )
}

function Write-AtomicJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $Directory = Split-Path `
        -Parent `
        -Path $Path

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Directory
        )
    ) {
        New-Item `
            -ItemType Directory `
            -Force `
            -Path $Directory |
            Out-Null
    }

    $TempPath = (
        $Path +
        ".tmp"
    )

    $Value |
        ConvertTo-Json -Depth 50 |
        Set-Content `
            -LiteralPath $TempPath `
            -Encoding utf8

    Move-Item `
        -Force `
        -LiteralPath $TempPath `
        -Destination $Path
}

if ($Mode -eq "TenantPolicy") {
    $RequiredScopes = @(
        "Policy.Read.AuthenticationMethod"
    )
}
else {
    $RequiredScopes = @(
        "UserAuthMethod-Passkey.Read",
        "UserAuthenticationMethod.Read"
    )
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
    Write-Host "FEATURE 4D — PASSKEY VERIFICATION"
    Write-Host "---------------------------------"
    Write-Host (
        "mode=" +
        $Mode
    )

    if ($Mode -eq "TenantPolicy") {
        Write-Host (
            "Sign in using the bootstrap administrator."
        )
    }
    else {
        Write-Host (
            "Sign in as the EMPLOYEE_01 pilot account."
        )
        Write-Host (
            "Do not use the bootstrap administrator."
        )
    }

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
            "Microsoft Graph context lacks required " +
            "read-only scope."
        )
    }

    if ($Mode -eq "TenantPolicy") {
        $PolicyUri = (
            "https://graph.microsoft.com/v1.0/" +
            "policies/authenticationMethodsPolicy/" +
            "authenticationMethodConfigurations/fido2"
        )

        $Policy = (
            Invoke-ReadOnlyGraphGet `
                -Uri $PolicyUri
        )

        if ($GraphGetCount -ne 1) {
            throw "Unexpected Graph GET count."
        }

        $IncludeTargets = @(
            Get-ObjectValue `
                -InputObject $Policy `
                -Name "includeTargets"
        )

        $ExcludeTargets = @(
            Get-ObjectValue `
                -InputObject $Policy `
                -Name "excludeTargets"
        )

        $Profiles = @(
            Get-ObjectValue `
                -InputObject $Policy `
                -Name "passkeyProfiles"
        )

        $AllUsersTargeted = $false
        $ExplicitGroupTargetCount = 0

        foreach ($Target in $IncludeTargets) {
            if ($null -eq $Target) {
                continue
            }

            $TargetId = (
                [string](
                    Get-ObjectValue `
                        -InputObject $Target `
                        -Name "id"
                )
            )

            $TargetType = (
                [string](
                    Get-ObjectValue `
                        -InputObject $Target `
                        -Name "targetType"
                )
            )

            if ($TargetId -eq "all_users") {
                $AllUsersTargeted = $true
            }
            elseif ($TargetType -eq "group") {
                $ExplicitGroupTargetCount++
            }
        }

        $SupportedPasskeyTypes = @()
        $AttestationValues = @()
        $KeyRestrictionsEnforced = $false

        foreach ($Profile in $Profiles) {
            if ($null -eq $Profile) {
                continue
            }

            $RawTypes = (
                Get-ObjectValue `
                    -InputObject $Profile `
                    -Name "passkeyTypes"
            )

            if ($null -ne $RawTypes) {
                foreach (
                    $Type in (
                        (
                            [string]$RawTypes
                        ) -split ","
                    )
                ) {
                    $Trimmed = $Type.Trim()

                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            $Trimmed
                        )
                    ) {
                        $SupportedPasskeyTypes += (
                            $Trimmed
                        )
                    }
                }
            }

            $Attestation = (
                [string](
                    Get-ObjectValue `
                        -InputObject $Profile `
                        -Name "attestationEnforcement"
                )
            )

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $Attestation
                )
            ) {
                $AttestationValues += $Attestation
            }

            $KeyRestrictions = (
                Get-ObjectValue `
                    -InputObject $Profile `
                    -Name "keyRestrictions"
            )

            if ($null -ne $KeyRestrictions) {
                $Enforced = (
                    Get-ObjectValue `
                        -InputObject $KeyRestrictions `
                        -Name "isEnforced"
                )

                if ([bool]$Enforced) {
                    $KeyRestrictionsEnforced = $true
                }
            }
        }

        $SupportedPasskeyTypes = @(
            $SupportedPasskeyTypes |
            Sort-Object -Unique
        )

        $AttestationValues = @(
            $AttestationValues |
            Sort-Object -Unique
        )

        $DefaultProfile = (
            [string](
                Get-ObjectValue `
                    -InputObject $Policy `
                    -Name "defaultPasskeyProfile"
            )
        )

        $RawEvidence = [ordered]@{
            schema_version = "1.0"
            evidence_type = (
                "authentication-passkey-policy-raw"
            )
            authenticated_account = (
                [string]$Context.Account
            )
            response = $Policy
            graph_resource_get_count = (
                [int]$GraphGetCount
            )
            graph_resource_write_count = 0
        }

        $SanitizedEvidence = [ordered]@{
            schema_version = "1.0"
            evidence_type = (
                "authentication-passkey-policy-sanitized"
            )
            mode = "tenant-policy-read"
            state = (
                [string](
                    Get-ObjectValue `
                        -InputObject $Policy `
                        -Name "state"
                )
            )
            self_service_registration_allowed = (
                [bool](
                    Get-ObjectValue `
                        -InputObject $Policy `
                        -Name "isSelfServiceRegistrationAllowed"
                )
            )
            all_users_targeted = (
                [bool]$AllUsersTargeted
            )
            explicit_group_target_count = (
                [int]$ExplicitGroupTargetCount
            )
            exclude_target_count = (
                [int]$ExcludeTargets.Count
            )
            passkey_profile_count = (
                [int]$Profiles.Count
            )
            default_passkey_profile_present = (
                -not [string]::IsNullOrWhiteSpace(
                    $DefaultProfile
                )
            )
            supported_passkey_types = (
                $SupportedPasskeyTypes
            )
            attestation_enforcement = (
                $AttestationValues
            )
            key_restrictions_enforced = (
                [bool]$KeyRestrictionsEnforced
            )
            graph_get_count = (
                [int]$GraphGetCount
            )
            graph_write_count = 0
        }

        Write-AtomicJson `
            -Value $RawEvidence `
            -Path $RawOutputPath

        Write-AtomicJson `
            -Value $SanitizedEvidence `
            -Path $SanitizedOutputPath

        Write-Host ""
        Write-Host (
            "PASS: FIDO2/passkey tenant policy read."
        )
        Write-Host (
            "fido2_state=" +
            $SanitizedEvidence.state
        )
        Write-Host (
            "all_users_targeted=" +
            $SanitizedEvidence.all_users_targeted
        )
        Write-Host (
            "graph_resource_get_count=1"
        )
        Write-Host (
            "graph_resource_write_count=0"
        )
    }
    else {
        $Credential = Get-Content `
            -Raw `
            -LiteralPath $CredentialPath |
            ConvertFrom-Json

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

        $ActualUpn = (
            [string]$Context.Account
        ).ToLowerInvariant()

        if ($ActualUpn -ne $ExpectedUpn) {
            throw (
                "Wrong account authenticated. " +
                "Expected the controlled pilot."
            )
        }

        $FidoResponse = (
            Invoke-ReadOnlyGraphGet `
                -Uri (
                    "https://graph.microsoft.com/v1.0/" +
                    "me/authentication/fido2Methods"
                )
        )

        $MethodsResponse = (
            Invoke-ReadOnlyGraphGet `
                -Uri (
                    "https://graph.microsoft.com/v1.0/" +
                    "me/authentication/methods"
                )
        )

        if ($GraphGetCount -ne 2) {
            throw "Unexpected Graph GET count."
        }

        $FidoMethods = @(
            Get-ObjectValue `
                -InputObject $FidoResponse `
                -Name "value"
        )

        $AuthenticationMethods = @(
            Get-ObjectValue `
                -InputObject $MethodsResponse `
                -Name "value"
        )

        $TotalPasskeyCount = 0
        $DeviceBoundCount = 0
        $SyncedCount = 0
        $AuthenticatorPasskeyCount = 0

        foreach ($Method in $FidoMethods) {
            if ($null -eq $Method) {
                continue
            }

            $TotalPasskeyCount++

            $PasskeyType = (
                [string](
                    Get-ObjectValue `
                        -InputObject $Method `
                        -Name "passkeyType"
                )
            )

            if ($PasskeyType -eq "deviceBound") {
                $DeviceBoundCount++
            }

            if ($PasskeyType -eq "synced") {
                $SyncedCount++
            }

            $Aaguid = (
                [string](
                    Get-ObjectValue `
                        -InputObject $Method `
                        -Name "aaGuid"
                )
            ).ToLowerInvariant()

            if (
                $AuthenticatorAaguids -contains
                $Aaguid
            ) {
                $AuthenticatorPasskeyCount++
            }
        }

        $MethodTypes = @()

        foreach ($Method in $AuthenticationMethods) {
            if ($null -eq $Method) {
                continue
            }

            $MethodType = (
                [string](
                    Get-ObjectValue `
                        -InputObject $Method `
                        -Name "@odata.type"
                )
            )

            $MethodType = (
                $MethodType -replace
                '^#microsoft\.graph\.',
                ''
            )

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $MethodType
                )
            ) {
                $MethodTypes += $MethodType
            }
        }

        $MethodTypes = @(
            $MethodTypes |
            Sort-Object -Unique
        )

        $AuthenticatorMfaPresent = (
            "microsoftAuthenticatorAuthenticationMethod" `
                -in $MethodTypes
        )

        $SoftwareOathPresent = (
            "softwareOathAuthenticationMethod" `
                -in $MethodTypes
        )

        if ($TotalPasskeyCount -lt 1) {
            throw (
                "No FIDO2/passkey method found."
            )
        }

        if ($DeviceBoundCount -lt 1) {
            throw (
                "No device-bound passkey found."
            )
        }

        if ($AuthenticatorPasskeyCount -lt 1) {
            throw (
                "Microsoft Authenticator passkey " +
                "was not found."
            )
        }

        if (-not $AuthenticatorMfaPresent) {
            throw (
                "Microsoft Authenticator MFA " +
                "was not preserved."
            )
        }

        if (-not $SoftwareOathPresent) {
            throw (
                "Software OATH fallback " +
                "was not preserved."
            )
        }

        $RawEvidence = [ordered]@{
            schema_version = "1.0"
            evidence_type = (
                "authentication-passkey-pilot-raw"
            )
            account_id = "EMPLOYEE_01"
            authenticated_account = (
                [string]$Context.Account
            )
            fido2_methods_response = (
                $FidoResponse
            )
            authentication_methods_response = (
                $MethodsResponse
            )
            graph_resource_get_count = (
                [int]$GraphGetCount
            )
            graph_resource_write_count = 0
        }

        $SanitizedEvidence = [ordered]@{
            schema_version = "1.0"
            evidence_type = (
                "authentication-passkey-pilot-sanitized"
            )
            mode = "pilot-self-read"
            account_id = "EMPLOYEE_01"
            privilege_class = "PC3"
            authenticated_account_matches_expected = $true
            total_passkey_count = (
                [int]$TotalPasskeyCount
            )
            device_bound_count = (
                [int]$DeviceBoundCount
            )
            synced_count = (
                [int]$SyncedCount
            )
            microsoft_authenticator_passkey_count = (
                [int]$AuthenticatorPasskeyCount
            )
            authentication_method_count = (
                [int]$AuthenticationMethods.Count
            )
            method_types = (
                $MethodTypes
            )
            microsoft_authenticator_mfa_present = (
                [bool]$AuthenticatorMfaPresent
            )
            software_oath_present = (
                [bool]$SoftwareOathPresent
            )
            graph_get_count = (
                [int]$GraphGetCount
            )
            graph_write_count = 0
        }

        Write-AtomicJson `
            -Value $RawEvidence `
            -Path $RawOutputPath

        Write-AtomicJson `
            -Value $SanitizedEvidence `
            -Path $SanitizedOutputPath

        Write-Host ""
        Write-Host (
            "PASS: correct EMPLOYEE_01 account authenticated."
        )
        Write-Host (
            "PASS: Microsoft Authenticator device-bound " +
            "passkey found."
        )
        Write-Host (
            "PASS: Microsoft Authenticator MFA preserved."
        )
        Write-Host (
            "PASS: Software OATH fallback preserved."
        )
        Write-Host (
            "total_passkey_count=" +
            $TotalPasskeyCount
        )
        Write-Host (
            "device_bound_count=" +
            $DeviceBoundCount
        )
        Write-Host (
            "microsoft_authenticator_passkey_count=" +
            $AuthenticatorPasskeyCount
        )
        Write-Host (
            "graph_resource_get_count=2"
        )
        Write-Host (
            "graph_resource_write_count=0"
        )
    }
}
finally {
    if ($Connected) {
        Microsoft.Graph.Authentication\Disconnect-MgGraph `
            -ErrorAction SilentlyContinue |
            Out-Null
    }
}
