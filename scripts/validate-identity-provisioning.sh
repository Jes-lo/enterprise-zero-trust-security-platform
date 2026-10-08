#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "=================================================="
echo "IDENTITY PROVISIONING VALIDATION"
echo "=================================================="

REQUIRED=(
  "configs/identity-provisioning.json"
  "automation/powershell/Test-IdentityProvisioningReadiness.ps1"
  "automation/powershell/Invoke-IdentityProvisioning.ps1"
  "automation/powershell/Test-IdentityPilotState.ps1"
  "docs/evidence/identity-pilot-validation.json"
)

for file in "${REQUIRED[@]}"; do
  [[ -s "$file" ]] || {
    echo "FAIL: missing or empty $file"
    exit 1
  }

  echo "PASS: $file"
done

echo
echo "===== JSON CONTRACT ====="

python3 - <<'PY_CONTRACT'
import json
from pathlib import Path

config = json.loads(
    Path("configs/identity-provisioning.json").read_text()
)

evidence = json.loads(
    Path(
        "docs/evidence/identity-pilot-validation.json"
    ).read_text()
)

assert config["schema_version"] == "1.0"
assert config["feature"] == "identity-live-provisioning"
assert config["mode"] == "staged"

expected = config["expected_live_objects"]

assert expected["users_to_create"] == 10
assert expected["business_premium_users"] == 8
assert expected["unlicensed_emergency_users"] == 2
assert expected["security_groups"] == 11

runtime = config["runtime_inputs"]

assert (
    runtime["tenant_domain"]["source"]
    == "auto-detected-from-bootstrap-upn"
)
assert runtime["tenant_domain"]["store_in_repository"] is False
assert runtime["usage_location"]["store_in_repository"] is False

apply = config["apply"]

assert apply["strategy"] == "staged"
assert apply["pilot_account_id"] == "EMPLOYEE_01"
assert apply["pilot_confirmation"] == "CREATE-EMPLOYEE_01"
assert apply["pilot_creates_groups"] is False
assert apply["pilot_creates_memberships"] is False
assert apply["pilot_creates_exactly_one_user"] is True
assert apply["pilot_assigns_at_most_one_license"] is True
assert apply["directory_wide_permission_allowed"] is False
assert apply["context_scope"] == "Process"
assert apply["idempotent"] is True

assert set(apply["pilot_graph_scopes"]) == {
    "User.Create",
    "User.ReadBasic.All",
    "LicenseAssignment.Read.All",
    "LicenseAssignment.ReadWrite.All",
}

credentials = config["credentials"]

assert credentials["repository_storage_allowed"] is False
assert credentials["plaintext_console_output_allowed"] is False
assert credentials["force_change_password_next_sign_in"] is True
assert credentials["local_directory_mode"] == "0700"
assert credentials["local_file_mode"] == "0600"
assert credentials["password_length"] == 28

assert evidence["schema_version"] == "1.0"
assert evidence["account_id"] == "EMPLOYEE_01"

initial = evidence["initial_apply"]

assert initial["user_created"] is True
assert initial["business_premium_assigned"] is True
assert initial["groups_created"] == 0
assert initial["memberships_created"] == 0
assert initial["credential_output_to_console"] is False

live = evidence["live_validation"]

assert live["user_found"] is True
assert live["display_name_matches"] is True
assert live["alias_matches"] is True
assert live["usage_location_matches"] is True
assert live["business_premium_assigned"] is True
assert live["write_operations_performed"] is False

idem = evidence["idempotency"]

assert idem["plan_target_exists"] is True
assert idem["plan_business_premium_assigned"] is True
assert idem["plan_users_to_create"] == 0
assert idem["plan_licenses_to_assign"] == 0
assert idem["repeated_pilot_user_created_this_run"] is False
assert idem["repeated_pilot_license_assigned_this_run"] is False
assert idem["repeated_pilot_groups_created"] == 0
assert idem["repeated_pilot_memberships_created"] == 0

assert (
    evidence["license_snapshot"]
    ["business_premium_available_after_pilot"]
    == 23
)

privacy = evidence["privacy"]

assert all(value is False for value in privacy.values())

print("PASS: provisioning contract validated.")
print("PASS: sanitized pilot evidence validated.")
print("PASS: idempotent pilot evidence validated.")
PY_CONTRACT

echo
echo "===== POWERSHELL SYNTAX ====="

pwsh -NoProfile -NonInteractive -Command '
$files = @(
    "automation/powershell/Test-IdentityProvisioningReadiness.ps1",
    "automation/powershell/Invoke-IdentityProvisioning.ps1",
    "automation/powershell/Test-IdentityPilotState.ps1"
)

foreach ($file in $files) {
    $tokens = $null
    $errors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $file,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null

    if ($errors.Count -gt 0) {
        throw "PowerShell syntax failure: $file"
    }

    Write-Host "PASS: $file"
}
'

echo
echo "===== PROVISIONER FAIL-SAFE DEFAULT ====="

grep -Fq \
  '[string]$Mode = "Plan"' \
  automation/powershell/Invoke-IdentityProvisioning.ps1

grep -Fq \
  '$Confirmation -ne $ExpectedConfirmation' \
  automation/powershell/Invoke-IdentityProvisioning.ps1

echo "PASS: Plan default and explicit Pilot confirmation."

echo
echo "===== WRITE SURFACE ====="

POST_COUNT="$(
  grep -Ec \
    '\-Method[[:space:]]+POST' \
    automation/powershell/Invoke-IdentityProvisioning.ps1
)"

[[ "$POST_COUNT" -eq 2 ]] || {
  echo "FAIL: expected exactly two POST call sites."
  exit 1
}

if grep -Ein \
  '\-Method[[:space:]]+(PATCH|PUT|DELETE)' \
  automation/powershell/Invoke-IdentityProvisioning.ps1
then
  echo "FAIL: unexpected provisioning write method."
  exit 1
fi

echo "PASS: writes limited to user creation and license assignment."

echo
echo "===== LIVE VERIFIER READ-ONLY ====="

if grep -Ein \
  '\-Method[[:space:]]+(POST|PATCH|PUT|DELETE)' \
  automation/powershell/Test-IdentityPilotState.ps1
then
  echo "FAIL: live verifier contains write operation."
  exit 1
fi

if grep -Fq \
  'pilot-EMPLOYEE_01-credentials.json' \
  automation/powershell/Test-IdentityPilotState.ps1
then
  echo "FAIL: live verifier reads credential file."
  exit 1
fi

echo "PASS: live verifier is read-only and credential-independent."

echo
echo "===== PERMISSION BOUNDARY ====="

if grep -Ein \
  'Directory\.ReadWrite|Directory\.Read\.All|User\.ReadWrite\.All' \
  automation/powershell/Invoke-IdentityProvisioning.ps1
then
  echo "FAIL: broad directory permission detected."
  exit 1
fi

echo "PASS: no broad directory permissions."

echo
echo "===== CREDENTIAL PROTECTION ====="

grep -Fq \
  'chmod 700' \
  automation/powershell/Invoke-IdentityProvisioning.ps1

grep -Fq \
  'chmod 600' \
  automation/powershell/Invoke-IdentityProvisioning.ps1

grep -Fq \
  'forceChangePasswordNextSignIn = $true' \
  automation/powershell/Invoke-IdentityProvisioning.ps1

if grep -Ein \
  'Write-Host.*\$Password|Write-Output.*\$Password' \
  automation/powershell/Invoke-IdentityProvisioning.ps1
then
  echo "FAIL: password may reach console."
  exit 1
fi

git check-ignore -q local-evidence/validator-probe

echo "PASS: credential protections validated."

echo
echo "===== PRIVACY BOUNDARY ====="

FILES=(
  "configs/identity-provisioning.json"
  "automation/powershell/Test-IdentityProvisioningReadiness.ps1"
  "automation/powershell/Invoke-IdentityProvisioning.ps1"
  "automation/powershell/Test-IdentityPilotState.ps1"
  "docs/evidence/identity-pilot-validation.json"
)

if grep -Ein \
  'onmicrosoft\.com|portfolioprojectlab|bootstrapadmin@' \
  "${FILES[@]}"
then
  echo "FAIL: private tenant value detected."
  exit 1
fi

echo "PASS: no private tenant values published."

echo
echo "=================================================="
echo "IDENTITY PROVISIONING VALIDATION PASSED"
echo "=================================================="
