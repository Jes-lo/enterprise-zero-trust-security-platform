#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=================================================="
echo "TENANT BOOTSTRAP VALIDATION"
echo "=================================================="

REQUIRED_FILES=(
  "configs/tenant-bootstrap.json"
  "docs/architecture/tenant-bootstrap.md"
  "docs/security/trial-activation-checklist.md"
  "docs/evidence/tenant-readiness-evidence.md"
  "docs/decisions/0003-staged-laboratory-licensing.md"
  "automation/powershell/Get-TenantReadiness.ps1"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: required tenant-bootstrap artifact missing: $file"
    exit 1
  fi

  echo "PASS: $file"
done

echo
echo "===== JSON VALIDATION ====="

python3 -m json.tool \
  configs/tenant-bootstrap.json \
  >/dev/null

echo "PASS: tenant bootstrap JSON is valid."

echo
echo "===== TENANT BOOTSTRAP CONTRACT ====="

python3 - <<'PY'
import json
from pathlib import Path

path = Path("configs/tenant-bootstrap.json")
data = json.loads(path.read_text())

assert data["schema_version"] == "1.0"
assert data["laboratory"]["code"] == "ZT-LAB"
assert data["laboratory"]["environment_type"] == "non-production"
assert data["laboratory"]["data_classification"] == "synthetic-only"

tenant = data["tenant"]

assert tenant["production_use_allowed"] is False
assert tenant["real_customer_data_allowed"] is False
assert tenant["real_employer_data_allowed"] is False
assert tenant["raw_tenant_identifiers_allowed_in_repository"] is False

subscription = data["base_subscription"]

assert subscription["product"] == "Microsoft 365 Business Premium"
assert subscription["expected_trial_duration_days"] == 30
assert subscription["recurring_billing_must_be_disabled"] is True

base = {
    item["id"]
    for item in data["expected_base_capabilities"]
    if item["required"] is True
}

assert base == {
    "ENTRA_ID_P1",
    "INTUNE_PLAN_1",
    "DEFENDER_FOR_BUSINESS",
    "DEFENDER_FOR_OFFICE_365_P1",
}

deferred = {
    item["id"]
    for item in data["deferred_capabilities"]
}

assert "ENTRA_ID_P2" in deferred
assert "DEFENDER_FOR_OFFICE_365_P2" in deferred

evidence = data["evidence"]

assert evidence["raw_output_directory"] == "local-evidence"
assert evidence["raw_output_must_not_be_committed"] is True
assert evidence["tenant_ids_must_not_be_published"] is True
assert evidence["domains_must_not_be_published"] is True
assert evidence["user_principal_names_must_not_be_published"] is True

print("PASS: tenant bootstrap contract validated.")
PY

echo
echo "===== RAW EVIDENCE PROTECTION ====="

if ! grep -Fxq "local-evidence/" .gitignore; then
  echo "FAIL: local-evidence/ is not protected by .gitignore."
  exit 1
fi

echo "PASS: local-evidence/ is ignored."

echo
echo "===== DISCOVERY SCRIPT BOUNDARY ====="

SCRIPT="automation/powershell/Get-TenantReadiness.ps1"

if ! grep -Fq '"Organization.Read.All"' "$SCRIPT"; then
  echo "FAIL: Organization.Read.All scope missing."
  exit 1
fi

if ! grep -Fq '"Directory.Read.All"' "$SCRIPT"; then
  echo "FAIL: Directory.Read.All scope missing."
  exit 1
fi

if grep -Eq \
  'New-Mg|Update-Mg|Remove-Mg|Set-Mg' \
  "$SCRIPT"; then

  echo "FAIL: write-capable Microsoft Graph cmdlet detected."
  exit 1
fi

if grep -Eq \
  'TenantId|UserPrincipalName|VerifiedDomains\[[^]]*\]\.Name' \
  "$SCRIPT"; then

  echo "FAIL: prohibited tenant identity field detected in discovery script."
  exit 1
fi

echo "PASS: discovery script remains read-only and sanitized."

echo
echo "===== OPTIONAL POWERSHELL SYNTAX ====="

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -NonInteractive -Command '
    $tokens = $null
    $errors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
      "automation/powershell/Get-TenantReadiness.ps1",
      [ref]$tokens,
      [ref]$errors
    ) | Out-Null

    if ($errors.Count -gt 0) {
      $errors |
        ForEach-Object {
          Write-Error $_.Message
        }

      exit 1
    }

    Write-Host "PASS: PowerShell syntax valid."
  '
else
  echo "INFO: pwsh not installed locally; PowerShell parser check skipped."
fi

echo
echo "===== ACTIVATION SAFEGUARDS ====="

for phrase in \
  "Disable recurring billing" \
  "Do not publish the initial tenant domain" \
  "Do not publish the tenant ID"
do
  if ! grep -Fq \
      "$phrase" \
      docs/security/trial-activation-checklist.md; then

    echo "FAIL: activation safeguard missing: $phrase"
    exit 1
  fi

  echo "PASS: $phrase"
done

echo
echo "=================================================="
echo "TENANT BOOTSTRAP VALIDATION PASSED"
echo "=================================================="
