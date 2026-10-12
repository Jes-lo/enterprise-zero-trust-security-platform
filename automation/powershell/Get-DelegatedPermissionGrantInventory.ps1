[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [System.Security.SecureString]$BootstrapAdmin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RequiredScope = "Directory.Read.All"
$Connected = $false

function Get-CollectionValue {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    if ($Response -is [System.Collections.IDictionary]) {
        if ($Response.Contains("value")) {
            return @($Response["value"])
        }

        return @($Response)
    }

    if ($null -ne $Response.PSObject.Properties["value"]) {
        return @($Response.value)
    }

    return @($Response)
}

function Get-NextLink {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    if ($Response -is [System.Collections.IDictionary]) {
        if ($Response.Contains("@odata.nextLink")) {
            return [string]$Response["@odata.nextLink"]
        }

        return $null
    }

    $Property = $Response.PSObject.Properties["@odata.nextLink"]

    if ($null -ne $Property) {
        return [string]$Property.Value
    }

    return $null
}

function Invoke-GraphCollectionGet {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $Items = @()
    $Next = $Uri

    while (-not [string]::IsNullOrWhiteSpace($Next)) {
        $Response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $Next

        $Items += @(Get-CollectionValue -Response $Response)
        $Next = Get-NextLink -Response $Response
    }

    return @($Items)
}

$ExpectedAccount = [System.Net.NetworkCredential]::new(
    "",
    $BootstrapAdmin
).Password

try {
    Connect-MgGraph `
        -Scopes @($RequiredScope) `
        -ContextScope Process `
        -NoWelcome

    $Connected = $true
    $Context = Get-MgContext

    if ($null -eq $Context) {
        throw "Microsoft Graph context was not created."
    }

    if (
        [string]::IsNullOrWhiteSpace($Context.Account) -or
        $Context.Account -ine $ExpectedAccount
    ) {
        throw "Authenticated account does not match the locally supplied operator."
    }

    if ($RequiredScope -notin @($Context.Scopes)) {
        throw "Required read-only scope is absent from the Graph context."
    }

    $ServicePrincipals = Invoke-GraphCollectionGet `
        -Uri (
            "https://graph.microsoft.com/v1.0/servicePrincipals" +
            "?`$select=id,appOwnerOrganizationId"
        )

    $TenantOwnedIds = @{}

    foreach ($ServicePrincipal in $ServicePrincipals) {
        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$ServicePrincipal.appOwnerOrganizationId
            ) -and
            [string]$ServicePrincipal.appOwnerOrganizationId -eq
                [string]$Context.TenantId
        ) {
            $TenantOwnedIds[[string]$ServicePrincipal.id] = $true
        }
    }

    $Grants = Invoke-GraphCollectionGet `
        -Uri (
            "https://graph.microsoft.com/v1.0/oauth2PermissionGrants" +
            "?`$select=id,clientId,consentType,principalId,resourceId,scope"
        )

    $TenantOwnedGrants = @(
        $Grants |
        Where-Object {
            $TenantOwnedIds.ContainsKey([string]$_.clientId)
        }
    )

    $AllPrincipalsCount = @(
        $TenantOwnedGrants |
        Where-Object {
            [string]$_.consentType -eq "AllPrincipals"
        }
    ).Count

    $PrincipalCount = @(
        $TenantOwnedGrants |
        Where-Object {
            [string]$_.consentType -eq "Principal"
        }
    ).Count

    $ScopeTokens = @(
        $TenantOwnedGrants |
        ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace([string]$_.scope)) {
                [string]$_.scope -split "\s+"
            }
        } |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object -Unique
    )

    $Summary = [ordered]@{
        feature = "feature9"
        phase = "feature9c-read-only-delegated-grant-inventory"
        graph_surface = "v1.0"
        graph_scope = $RequiredScope
        graph_method = "GET_ONLY"
        authenticated_identity_validated = $true
        tenant_owned_service_principals = $TenantOwnedIds.Count
        tenant_owned_delegated_permission_grants =
            @($TenantOwnedGrants).Count
        tenant_owned_all_principals_grants = $AllPrincipalsCount
        tenant_owned_principal_specific_grants = $PrincipalCount
        unique_delegated_scope_tokens = @($ScopeTokens).Count
        tenant_writes = 0
        identifiers_emitted = $false
    }

    $Summary |
        ConvertTo-Json -Depth 5
}
finally {
    $ExpectedAccount = $null

    if ($Connected) {
        Disconnect-MgGraph | Out-Null
    }
}
