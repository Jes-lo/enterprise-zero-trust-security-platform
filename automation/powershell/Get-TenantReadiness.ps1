#Requires -Version 7.2

[CmdletBinding()]
param(
    [string]$OutputPath = "local-evidence/tenant-readiness.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Identity.DirectoryManagement"
)

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        throw "Required PowerShell module is not installed: $module"
    }
}

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Identity.DirectoryManagement

$requiredScopes = @(
    "Organization.Read.All",
    "Directory.Read.All"
)

try {
    Connect-MgGraph `
        -Scopes $requiredScopes `
        -NoWelcome

    $context = Get-MgContext

    if ($null -eq $context) {
        throw "Microsoft Graph authentication context is unavailable."
    }

    $organization = Get-MgOrganization | Select-Object -First 1

    if ($null -eq $organization) {
        throw "Microsoft Graph did not return an organization."
    }

    $skus = @(
        Get-MgSubscribedSku -All |
            Sort-Object SkuPartNumber
    )

    $sanitizedSkus = foreach ($sku in $skus) {
        $servicePlans = foreach (
            $plan in @($sku.ServicePlans | Sort-Object ServicePlanName)
        ) {
            [ordered]@{
                service_plan_name = $plan.ServicePlanName
                provisioning_status = [string]$plan.ProvisioningStatus
            }
        }

        [ordered]@{
            sku_part_number = $sku.SkuPartNumber
            consumed_units = $sku.ConsumedUnits
            prepaid_units = [ordered]@{
                enabled = $sku.PrepaidUnits.Enabled
                suspended = $sku.PrepaidUnits.Suspended
                warning = $sku.PrepaidUnits.Warning
            }
            service_plans = @($servicePlans)
        }
    }

    $result = [ordered]@{
        schema_version = "1.0"
        evidence_type = "sanitized-tenant-readiness"
        collected_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        collector = "Get-TenantReadiness.ps1"
        tenant_summary = [ordered]@{
            subscribed_sku_count = $skus.Count
            verified_domain_count = @($organization.VerifiedDomains).Count
        }
        graph_context = [ordered]@{
            authentication_type = [string]$context.AuthType
            granted_scopes = @($context.Scopes | Sort-Object)
        }
        subscribed_skus = @($sanitizedSkus)
    }

    $directory = Split-Path -Parent $OutputPath

    if ($directory) {
        New-Item `
            -ItemType Directory `
            -Path $directory `
            -Force |
            Out-Null
    }

    $result |
        ConvertTo-Json -Depth 10 |
        Set-Content `
            -Path $OutputPath `
            -Encoding utf8

    Write-Host "PASS: sanitized tenant readiness written to $OutputPath"
}
finally {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}
