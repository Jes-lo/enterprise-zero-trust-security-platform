#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=================================================="
echo "TENANT BOOTSTRAP VALIDATION"
echo "=================================================="

REQUIRED_FILES=(
  "configs/tenant-bootstrap.json"
  "configs/business-premium-capabilities.json"
  "docs/architecture/tenant-bootstrap.md"
  "docs/security/trial-activation-checklist.md"
  "docs/evidence/tenant-readiness-evidence.md"
  "docs/evidence/tenant-capability-validation.json"
  "docs/decisions/0003-staged-laboratory-licensing.md"
  "automation/powershell/Get-TenantReadiness.ps1"
  "scripts/build-tenant-capability-evidence.py"
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

python3 -m json.tool \
  configs/business-premium-capabilities.json \
  >/dev/null

python3 -m json.tool \
  docs/evidence/tenant-capability-validation.json \
  >/dev/null

echo "PASS: Feature 2 JSON artifacts valid."

echo
echo "===== TENANT BOOTSTRAP CONTRACT ====="

python3 - <<'PY_CONTRACT'
import json
from pathlib import Path

data = json.loads(
    Path("configs/tenant-bootstrap.json").read_text()
)

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

billing = subscription["billing_protection"]

assert billing["required"] is True
assert billing["preferred_strategy"] == "recurring_billing_off"
assert billing["fallback_strategy"] == "manual_cancel_before_expiration"
assert billing["cancel_before_expiration_days"] >= 1

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

print("PASS: tenant bootstrap contract validated.")
PY_CONTRACT

echo
echo "===== BUSINESS PREMIUM CAPABILITY CONTRACT ====="

python3 - <<'PY_CAPABILITIES'
import json
from pathlib import Path

data = json.loads(
    Path("configs/business-premium-capabilities.json").read_text()
)

assert data["schema_version"] == "1.0"
assert data["product"]["sku_part_number"] == "SPB"

expected = {
    "ENTRA_ID_P1": "AAD_PREMIUM",
    "INTUNE_PLAN_1": "INTUNE_A",
    "DEFENDER_FOR_BUSINESS": "MDE_SMB",
    "DEFENDER_FOR_OFFICE_365_P1": "ATP_ENTERPRISE",
}

actual = {
    item["id"]: item["service_plan_name"]
    for item in data["required_capabilities"]
}

assert actual == expected

for item in data["required_capabilities"]:
    assert item["required_status"] == "Success"

print("PASS: Business Premium capability contract validated.")
PY_CAPABILITIES

echo
echo "===== RAW EVIDENCE PROTECTION ====="

if ! grep -Fxq "local-evidence/" .gitignore; then
  echo "FAIL: local-evidence/ is not protected by .gitignore."
  exit 1
fi

if git ls-files local-evidence | grep -q .; then
  echo "FAIL: local-evidence contains tracked files."
  exit 1
fi

echo "PASS: raw evidence remains outside Git."

echo
echo "===== GRAPH LEAST-PRIVILEGE BOUNDARY ====="

SCRIPT="automation/powershell/Get-TenantReadiness.ps1"

if ! grep -Fq '"LicenseAssignment.Read.All"' "$SCRIPT"; then
  echo "FAIL: LicenseAssignment.Read.All scope missing."
  exit 1
fi

if grep -Fq '"Directory.Read.All"' "$SCRIPT"; then
  echo "FAIL: Directory.Read.All must not be requested."
  exit 1
fi

if grep -Fq '"Organization.Read.All"' "$SCRIPT"; then
  echo "FAIL: Organization.Read.All must not be requested."
  exit 1
fi

if ! grep -Fq -- '-ContextScope Process' "$SCRIPT"; then
  echo "FAIL: process-scoped Graph authentication missing."
  exit 1
fi

if grep -Eq \
  'New-Mg|Update-Mg|Remove-Mg|Set-Mg' \
  "$SCRIPT"; then

  echo "FAIL: write-capable Microsoft Graph cmdlet detected."
  exit 1
fi

if grep -Eq \
  'TenantId|UserPrincipalName|VerifiedDomains' \
  "$SCRIPT"; then

  echo "FAIL: prohibited tenant identity field detected."
  exit 1
fi

echo "PASS: Graph collector follows least privilege."

echo
echo "===== POWERSHELL SYNTAX ====="

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
  echo "INFO: pwsh not installed; parser check skipped."
fi

echo
echo "===== ACTIVATION SAFEGUARDS ====="

for phrase in \
  "Attempt to disable recurring billing" \
  "manual cancellation plan" \
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
echo "===== LIVE CAPABILITY EVIDENCE ====="

python3 - <<'PY_EVIDENCE'
import json
import re
from pathlib import Path

contract = json.loads(
    Path(
        "configs/business-premium-capabilities.json"
    ).read_text()
)

path = Path(
    "docs/evidence/tenant-capability-validation.json"
)

text = path.read_text()

for pattern in (
    r"onmicrosoft\.com",
    r"TenantId",
    r"UserPrincipalName",
    r"@[A-Za-z0-9._+-]+\.[A-Za-z]{2,}",
):
    assert not re.search(
        pattern,
        text,
        flags=re.IGNORECASE,
    )

evidence = json.loads(text)

assert evidence["schema_version"] == "1.0"
assert evidence["sensitive_identifiers_included"] is False
assert evidence["subscription"]["sku_part_number"] == "SPB"
assert evidence["subscription"]["validated"] is True

expected = {
    item["id"]
    for item in contract["required_capabilities"]
}

observed = {
    item["id"]
    for item in evidence["capabilities"]
    if item["validated"] is True
}

assert observed == expected

for item in evidence["capabilities"]:
    assert item["observed_status"] == item["required_status"]

assert (
    evidence["billing_protection"]["strategy"]
    == "manual_cancel_before_expiration"
)

assert (
    evidence["billing_protection"]["cancel_before_expiration_days"]
    >= 1
)

print("PASS: sanitized live capability evidence validated.")
PY_EVIDENCE

echo
echo "===== PYTHON BUILDER SYNTAX ====="

python3 - <<'PY_BUILDER'
import ast
from pathlib import Path

path = Path(
    "scripts/build-tenant-capability-evidence.py"
)

ast.parse(path.read_text())

print("PASS: evidence-builder Python syntax valid.")
PY_BUILDER

echo
echo "=================================================="
echo "TENANT BOOTSTRAP VALIDATION PASSED"
echo "=================================================="
