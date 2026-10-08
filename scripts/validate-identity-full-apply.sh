#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

CONFIG="configs/identity-provisioning.json"
APPLY="automation/powershell/Invoke-IdentityFullProvisioning.ps1"

echo "=================================================="
echo "IDENTITY FULL APPLY STATIC VALIDATION"
echo "=================================================="

[[ -s "$CONFIG" ]] || {
  echo "FAIL: provisioning contract missing."
  exit 1
}

[[ -s "$APPLY" ]] || {
  echo "FAIL: Full Apply script missing."
  exit 1
}

echo
echo "===== CONTRACT ====="

python3 - <<'PY_CONTRACT'
import json
from pathlib import Path

data = json.loads(
    Path("configs/identity-provisioning.json").read_text()
)

apply = data["apply"]

expected = {
    "User.Create",
    "User.Read.All",
    "Group.ReadWrite.All",
    "GroupMember.ReadWrite.All",
    "LicenseAssignment.Read.All",
    "LicenseAssignment.ReadWrite.All",
}

assert set(
    apply["full_apply_graph_scopes"]
) == expected

for forbidden in (
    "Directory.ReadWrite.All",
    "Directory.Read.All",
    "User.ReadWrite.All",
):
    assert forbidden not in apply["full_apply_graph_scopes"]

assert (
    apply["full_confirmation"]
    == "CREATE-FEATURE3-IDENTITY-FOUNDATION"
)

assert apply["full_apply_requires_authoritative_plan"] is True
assert apply["full_apply_requires_zero_conflicts"] is True
assert apply["full_apply_requires_license_capacity"] is True
assert apply["full_apply_supports_resume"] is True
assert apply["full_apply_automatic_rollback"] is False
assert apply["full_apply_requires_exact_plan_delta"] is True
assert apply["full_apply_pins_authoritative_plan_hash"] is True
assert apply["full_apply_atomic_local_evidence"] is True
assert apply["full_apply_single_process_lock"] is True
assert apply["full_apply_reconciles_uncertain_posts"] is True
assert apply["full_apply_rejects_pending_state_on_completion"] is True
assert apply["full_apply_exact_final_membership_verification"] is True
assert apply["full_apply_exact_final_object_verification"] is True
assert apply["full_apply_verifies_enabled_state"] is True
assert apply["full_apply_verifies_usage_location"] is True
assert apply["full_apply_verifies_user_type"] is True

assert apply["full_apply_user_verification_properties"] == [
    "id",
    "displayName",
    "userPrincipalName",
    "accountEnabled",
    "usageLocation",
    "userType",
]

assert apply["standard_accounts_initially_enabled"] is True
assert apply["emergency_accounts_initially_enabled"] is False

assert apply["full_apply_order"] == [
    "users",
    "groups",
    "licenses",
    "memberships",
    "verification",
]

print("PASS: Full Apply contract validated.")
PY_CONTRACT

echo
echo "===== POWERSHELL SYNTAX ====="

pwsh -NoProfile -NonInteractive -Command '
$tokens = $null
$errors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    "automation/powershell/Invoke-IdentityFullProvisioning.ps1",
    [ref]$tokens,
    [ref]$errors
) | Out-Null

if ($errors.Count -gt 0) {
    foreach ($parseError in $errors) {
        Write-Host (
            "FAIL line=" +
            $parseError.Extent.StartLineNumber +
            " column=" +
            $parseError.Extent.StartColumnNumber +
            " message=" +
            $parseError.Message
        )
    }

    exit 1
}

Write-Host "PASS: Full Apply PowerShell syntax valid."
'

echo
echo "===== HTTP WRITE SURFACE ====="

POST_COUNT="$(
  grep -Ec \
    '\-Method[[:space:]]+POST' \
    "$APPLY"
)"

echo "POST_call_sites=$POST_COUNT"

if [[ "$POST_COUNT" -ne 4 ]]; then
  echo "FAIL: expected exactly 4 POST call sites."
  exit 1
fi

if grep -Ein \
  '\-Method[[:space:]]+(PATCH|PUT|DELETE)' \
  "$APPLY"
then
  echo "FAIL: unexpected PATCH/PUT/DELETE operation."
  exit 1
fi

echo "PASS: write surface limited to four POST operations."

echo
echo "===== REQUIRED POST ENDPOINTS ====="

grep -Fq \
  '"https://graph.microsoft.com/v1.0/users"' \
  "$APPLY"

grep -Fq \
  '"https://graph.microsoft.com/v1.0/groups"' \
  "$APPLY"

grep -Fq \
  '"/assignLicense"' \
  "$APPLY"

grep -Fq \
  '"/members/`$ref"' \
  "$APPLY"

echo "PASS: user creation endpoint."
echo "PASS: group creation endpoint."
echo "PASS: license assignment endpoint."
echo "PASS: membership endpoint."

echo
echo "===== FORBIDDEN BROAD PERMISSIONS ====="

# The Full Apply script intentionally contains the forbidden permission
# names in its own defensive deny-list. Validate the actual configured
# permission contract rather than matching the deny-list text itself.
if grep -Ein \
  'Directory\.ReadWrite\.All|Directory\.Read\.All|User\.ReadWrite\.All' \
  "$CONFIG"
then
  echo "FAIL: broad forbidden permission configured."
  exit 1
fi

echo "PASS: no forbidden Directory/User broad permissions."

echo
echo "===== CONFIRMATION GATE ====="

grep -Fq \
  '$Confirmation -ne $ExpectedConfirmation' \
  "$APPLY"

grep -Fq \
  'CREATE-FEATURE3-IDENTITY-FOUNDATION' \
  "$CONFIG"

echo "PASS: explicit Full Apply confirmation gate."

echo
echo "===== AUTHORITATIVE PLAN GATE ====="

grep -Fq \
  '$AuthoritativePlan.delta.users_to_create' \
  "$APPLY"

grep -Fq \
  '$AuthoritativePlan.safety.conflicts' \
  "$APPLY"

grep -Fq \
  '$AuthoritativePlan.safety.license_capacity_sufficient' \
  "$APPLY"

echo "PASS: authoritative plan required."

echo
echo "===== PAGINATION ====="

grep -Fq \
  '@odata.nextLink' \
  "$APPLY"

grep -Fq \
  'function Get-GraphCollection' \
  "$APPLY"

echo "PASS: Graph pagination supported."

echo
echo "===== RESUME / FAIL-CLOSED ====="

grep -Fq \
  'create_pending' \
  "$APPLY"

grep -Fq \
  'assignment_pending' \
  "$APPLY"

grep -Fq \
  'add_pending' \
  "$APPLY"

grep -Fq \
  'failed_stage' \
  "$APPLY"

grep -Fq \
  'identity_contract_sha256' \
  "$APPLY"

grep -Fq \
  'provisioning_contract_sha256' \
  "$APPLY"

grep -Fq   'authoritative_plan_sha256'   "$APPLY"

grep -Fq   'Assert-ExactStringSet'   "$APPLY"

grep -Fq   'recovered_after_uncertain_post'   "$APPLY"

grep -Fq   'recovered_assigned'   "$APPLY"

grep -Fq   'recovered_present'   "$APPLY"

grep -Fq   'Move-Item'   "$APPLY"

grep -Fq   '[System.IO.FileShare]::None'   "$APPLY"

grep -Fq   'PendingLedgerEntries'   "$APPLY"

grep -Fq   'accountEnabled,usageLocation,userType'   "$APPLY"

grep -Fq   'user-enabled-state-drift'   "$APPLY"

grep -Fq   'Final account-enabled state mismatch'   "$APPLY"

grep -Fq   'Final usage-location mismatch'   "$APPLY"

grep -Fq   'Final user-type mismatch'   "$APPLY"

echo "PASS: resumable operation ledger present."
echo "PASS: contract hashes protect partial operations."
echo "PASS: authoritative plan hash pinned."
echo "PASS: exact authoritative-plan sets enforced."
echo "PASS: uncertain POST recovery present."
echo "PASS: atomic local evidence writes present."
echo "PASS: exclusive execution lock present."
echo "PASS: pending ledger blocks completion."

echo
echo "===== EMERGENCY ACCOUNT POLICY ====="

grep -Fq \
  'EMERGENCY_ADMIN' \
  "$APPLY"

grep -Fq \
  'emergency_accounts_initially_enabled' \
  "$APPLY"

python3 - <<'PY_EMERGENCY'
import json
from pathlib import Path

data = json.loads(
    Path("configs/identity-provisioning.json").read_text()
)

assert (
    data["apply"]
    ["emergency_accounts_initially_enabled"]
    is False
)

print("PASS: emergency accounts configured disabled.")
PY_EMERGENCY

echo
echo "===== CREDENTIAL SAFETY ====="

grep -Fq \
  'New-StrongPassword' \
  "$APPLY"

grep -Fq \
  '"temporary_password",' \
  "$APPLY"

grep -Fq \
  '"password",' \
  "$APPLY"

grep -Fq \
  'chmod 700' \
  "$APPLY"

grep -Fq \
  'chmod 600' \
  "$APPLY"

grep -Fq \
  'forceChangePasswordNextSignIn = $true' \
  "$APPLY"

if grep -Ein \
  'Write-Host.*\$Password|Write-Output.*\$Password' \
  "$APPLY"
then
  echo "FAIL: password may reach console."
  exit 1
fi

echo "PASS: credentials local-only and protected."
echo "PASS: password not emitted to console."

echo
echo "===== NO AUTOMATIC DESTRUCTIVE ROLLBACK ====="

if grep -Ein \
  '\-Method[[:space:]]+DELETE' \
  "$APPLY"
then
  echo "FAIL: destructive rollback detected."
  exit 1
fi

echo "PASS: no automatic destructive rollback."

echo
echo "===== SKU COLLECTION SHAPE ====="

python3 - <<'PY_SKU_ARRAY'
import re
from pathlib import Path

text = Path(
    "automation/powershell/"
    "Invoke-IdentityFullProvisioning.ps1"
).read_text()

unwrapped = re.findall(
    r'(?m)^\s*\$SkuIds\s*=\s*'
    r'Get-UserSkuIds\s*`',
    text,
)

wrapped = re.findall(
    r'(?ms)^\s*\$SkuIds\s*=\s*@\(\s*'
    r'Get-UserSkuIds\s*`',
    text,
)

assert not unwrapped
assert len(wrapped) == 4

print("PASS: all SKU-ID call results are array-wrapped.")
PY_SKU_ARRAY

echo
echo "===== PRIVACY ====="

if grep -Ein \
  'onmicrosoft\.com|portfolioprojectlab|bootstrapadmin@' \
  "$APPLY" \
  "$CONFIG"
then
  echo "FAIL: private tenant identifier detected."
  exit 1
fi

echo "PASS: tenant domain remains runtime-derived."

echo
echo
echo "===== POST-LIVE SANITIZED EVIDENCE ====="

POSTLIVE_EVIDENCE="docs/evidence/identity-full-apply-live-validation.json"

if [[ -e "$POSTLIVE_EVIDENCE" ]]; then
  python3 - <<'PY_POSTLIVE'
import json
import re
from pathlib import Path

path = Path(
    "docs/evidence/"
    "identity-full-apply-live-validation.json"
)

raw = path.read_text()
lower = raw.lower()
data = json.loads(raw)

assert data["schema_version"] == "1.0"
assert data["operation_result"] == "completed"
assert data["recovery_path_used"] is True
assert data["initial_failure_stage"] == "verification"

verified = data["verified_state"]

assert verified["planned_live_identities"] == 10
assert verified["business_premium_identities"] == 8
assert verified["emergency_unlicensed_identities"] == 2
assert verified["security_groups"] == 11
assert verified["feature3_memberships"] == 16

writes = data["write_operation_summary"]

assert writes["users_created"] == 9
assert writes["groups_created"] == 11
assert writes["business_premium_assignments_created"] == 7
assert writes["pilot_business_premium_assignment_preexisting"] == 1
assert writes["memberships_added"] == 16

controls = data["recovery_controls"]

assert controls["pending_write_states_before_resume"] == 0
assert controls["final_verification_completed"] is True

privacy = data["privacy"]

assert privacy == {
    "tenant_domain_present": False,
    "complete_upn_present": False,
    "graph_object_id_present": False,
    "credential_secret_value_present": False,
    "oauth_bearer_value_present": False,
}

assert all(
    value is False
    for value in privacy.values()
)

forbidden_terms = (
    "onmicrosoft.com",
    "temporary" + "_password",
    "client" + "_secret",
    "access" + "_token",
    "refresh" + "_token",
)

for term in forbidden_terms:
    assert term not in lower

email_pattern = re.compile(
    r"[A-Za-z0-9._%+-]+@"
    r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}"
)

assert email_pattern.search(raw) is None

guid_pattern = re.compile(
    r"\b"
    r"[0-9a-fA-F]{8}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{12}"
    r"\b"
)

assert guid_pattern.search(raw) is None

print("PASS: sanitized post-live evidence validated.")
PY_POSTLIVE
else
  echo "INFO: post-live evidence not present yet."
fi

echo
echo "===== ZERO-DELTA IDEMPOTENCY EVIDENCE ====="

IDEMPOTENCY_EVIDENCE="docs/evidence/identity-full-apply-idempotency-validation.json"

if [[ -e "$IDEMPOTENCY_EVIDENCE" ]]; then
  python3 - <<'PY_IDEMPOTENCY'
import json
import re
from pathlib import Path

raw = Path(
    "docs/evidence/"
    "identity-full-apply-idempotency-validation.json"
).read_text()

lower = raw.lower()
data = json.loads(raw)

assert data["schema_version"] == "1.0"
assert data["proof_result"] == "passed"

assert data["observed_zero_delta"] == {
    "users_to_create": 0,
    "licenses_to_assign": 0,
    "groups_to_create": 0,
    "memberships_to_add": 0,
    "conflicts": 0,
}

assert data["verified_state"] == {
    "planned_live_identities": 10,
    "business_premium_identities": 8,
    "emergency_unlicensed_identities": 2,
    "security_groups": 11,
    "feature3_memberships": 16,
}

method = data["execution_method"]

assert method["temporary_git_worktree"] is True
assert method["copied_runtime_evidence"] is True
assert method["full_apply_source_modified"] is False
assert method["preauthenticated_process_context"] is True
assert (
    method[
        "connect_command_intercepted_for_context_reuse"
    ]
    is True
)
assert (
    method["powershell_dotnet_cwd_synchronized"]
    is True
)
assert (
    method["canonical_operation_ledger_modified"]
    is False
)
assert (
    method["canonical_credentials_modified"]
    is False
)

guard = data["graph_guard"]

assert guard["get_requests_observed"] > 0
assert guard["non_get_attempts_observed"] == 0

for key in (
    "post_allowed",
    "patch_allowed",
    "put_allowed",
    "delete_allowed",
):
    assert guard[key] is False

assert all(
    value is False
    for value in data["privacy"].values()
)

for forbidden in (
    "onmicrosoft.com",
    "temporary" + "_password",
    "client" + "_secret",
    "access" + "_token",
    "refresh" + "_token",
):
    assert forbidden not in lower

assert re.search(
    r"[A-Za-z0-9._%+-]+@"
    r"[A-Za-z0-9.-]+\.[A-Za-z]{2,}",
    raw,
) is None

assert re.search(
    r"\b"
    r"[0-9a-fA-F]{8}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{12}"
    r"\b",
    raw,
) is None

print("PASS: zero-delta evidence validated.")
PY_IDEMPOTENCY
else
  echo "INFO: zero-delta idempotency evidence not present yet."
fi

echo "=================================================="
echo "IDENTITY FULL APPLY STATIC VALIDATION PASSED"
echo "=================================================="
