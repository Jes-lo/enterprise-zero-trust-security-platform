[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [System.Security.SecureString]$BootstrapAdmin
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RequiredScope = "Application.Read.All"
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
            "?`$select=id,appOwnerOrganizationId,accountEnabled,servicePrincipalType"
        )

    $TenantOwned = @(
        $ServicePrincipals |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace(
                [string]$_.appOwnerOrganizationId
            ) -and
            [string]$_.appOwnerOrganizationId -eq
                [string]$Context.TenantId
        }
    )

    $OwnerlessCount = 0
    $DisabledCount = 0
    $ApplicationPermissionAssignmentCount = 0
    $AppsWithApplicationPermissions = 0

    foreach ($ServicePrincipal in $TenantOwned) {
        if ($ServicePrincipal.accountEnabled -eq $false) {
            $DisabledCount++
        }

        $Owners = Invoke-GraphCollectionGet `
            -Uri (
                "https://graph.microsoft.com/v1.0/servicePrincipals/" +
                "$($ServicePrincipal.id)/owners?`$select=id"
            )

        if (@($Owners).Count -eq 0) {
            $OwnerlessCount++
        }

        $Assignments = Invoke-GraphCollectionGet `
            -Uri (
                "https://graph.microsoft.com/v1.0/servicePrincipals/" +
                "$($ServicePrincipal.id)/appRoleAssignments" +
                "?`$select=id,resourceId,appRoleId"
            )

        $AssignmentCount = @($Assignments).Count
        $ApplicationPermissionAssignmentCount += $AssignmentCount

        if ($AssignmentCount -gt 0) {
            $AppsWithApplicationPermissions++
        }
    }

    $Summary = [ordered]@{
        feature = "feature9"
        phase = "feature9b-read-only-inventory"
        graph_surface = "v1.0"
        graph_scope = $RequiredScope
        graph_method = "GET_ONLY"
        authenticated_identity_validated = $true
        total_service_principals = @($ServicePrincipals).Count
        tenant_owned_service_principals = @($TenantOwned).Count
        tenant_owned_disabled_service_principals = $DisabledCount
        tenant_owned_ownerless_service_principals = $OwnerlessCount
        tenant_owned_application_permission_assignments =
            $ApplicationPermissionAssignmentCount
        tenant_owned_apps_with_application_permissions =
            $AppsWithApplicationPermissions
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
