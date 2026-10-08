#!/usr/bin/env bash

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

APPLY="automation/powershell/Invoke-IdentityFullProvisioning.ps1"
CONFIG="configs/identity-provisioning.json"
IDENTITY="configs/identity-foundation.json"
PLAN="local-evidence/identity-full-provisioning-plan.json"

echo "=================================================="
echo "IDENTITY FULL APPLY SEMANTIC TESTS"
echo "LOCAL ONLY"
echo "=================================================="

python3 - <<'PY_CONTRACT'
import json
from pathlib import Path

identity = json.loads(
    Path("configs/identity-foundation.json").read_text()
)

config = json.loads(
    Path("configs/identity-provisioning.json").read_text()
)

plan = json.loads(
    Path(
        "local-evidence/identity-full-provisioning-plan.json"
    ).read_text()
)

live = [
    a
    for a in identity["accounts"]
    if a["live_creation"] is True
]

expected_users = sorted(
    a["id"]
    for a in live
    if a["id"] != "EMPLOYEE_01"
)

expected_licenses = sorted(
    a["id"]
    for a in live
    if (
        a["license_policy"] == "business-premium"
        and a["id"] != "EMPLOYEE_01"
    )
)

expected_groups = sorted(
    g["id"]
    for g in identity["groups"]
)

expected_memberships = sorted(
    (
        g["id"],
        account_id,
    )
    for g in identity["groups"]
    if g["membership_managed_in_feature"] == 3
    for account_id in g["members"]
)

actual_users = sorted(
    plan["delta"]["users_to_create"]
)

actual_licenses = sorted(
    plan["delta"]["licenses_to_assign"]
)

actual_groups = sorted(
    plan["delta"]["groups_to_create"]
)

actual_memberships = sorted(
    (
        edge["group_id"],
        edge["account_id"],
    )
    for edge in plan["delta"]["memberships_to_add"]
)

assert expected_users == actual_users
assert expected_licenses == actual_licenses
assert expected_groups == actual_groups
assert expected_memberships == actual_memberships

apply = config["apply"]

for key in (
    "full_apply_requires_exact_plan_delta",
    "full_apply_pins_authoritative_plan_hash",
    "full_apply_atomic_local_evidence",
    "full_apply_single_process_lock",
    "full_apply_reconciles_uncertain_posts",
    "full_apply_rejects_pending_state_on_completion",
    "full_apply_exact_final_membership_verification",
    "full_apply_exact_final_object_verification",
    "full_apply_verifies_enabled_state",
    "full_apply_verifies_usage_location",
    "full_apply_verifies_user_type",
):
    assert apply[key] is True, key

print("PASS: authoritative plan exact sets verified.")
print("PASS: semantic hardening contract verified.")
PY_CONTRACT

for marker in \
  'authoritative_plan_sha256' \
  'Assert-ExactStringSet' \
  'Read-ValidatedCredentialRecord' \
  'recovered_after_uncertain_post' \
  'recovered_created' \
  'recovered_assigned' \
  'recovered_present' \
  'PendingLedgerEntries' \
  '[System.IO.FileShare]::None' \
  'Move-Item'   'user-enabled-state-drift'   'Final account-enabled state mismatch'   'Final usage-location mismatch'   'Final user-type mismatch'
do
  grep -Fq "$marker" "$APPLY"
  echo "PASS: $marker"
done

if grep -Ein \
  '\-Method[[:space:]]+(PATCH|PUT|DELETE)' \
  "$APPLY"
then
  echo "FAIL: forbidden write method."
  exit 1
fi

POST_COUNT="$(
  grep -Ec \
    '\-Method[[:space:]]+POST' \
    "$APPLY"
)"

[[ "$POST_COUNT" -eq 4 ]]

echo "PASS: exactly four POST call sites."
echo "PASS: no PATCH/PUT/DELETE."

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

print("PASS: SKU-ID zero/one/many result shape guarded.")
PY_SKU_ARRAY

RECOVERY_MODE="${ALLOW_FULL_APPLY_RECOVERY_STATE:-0}"

if [[ "$RECOVERY_MODE" == "1" ]]; then
  OPERATION="$ROOT/local-evidence/identity-full-provisioning-operation.json"
  CREDENTIAL_DIR="$ROOT/local-evidence/full-credentials"

  if [[ ! -s "$OPERATION" ]]; then
    echo "FAIL: recovery mode requires an operation ledger."
    exit 1
  fi

  if [[ ! -d "$CREDENTIAL_DIR" ]]; then
    echo "FAIL: recovery mode requires credential evidence."
    exit 1
  fi

  python3 - <<'PY_RECOVERY'
import json
from pathlib import Path

data = json.loads(
    Path(
        "local-evidence/"
        "identity-full-provisioning-operation.json"
    ).read_text()
)

assert data["status"] == "failed"
assert data["failed_stage"] == "verification"

assert len(data["accounts"]) == 9
assert len(data["groups"]) == 11
assert len(data["licenses"]) == 8
assert len(data["memberships"]) == 16

pending = []

for category in (
    "accounts",
    "groups",
    "licenses",
    "memberships",
):
    for key, value in data[category].items():
        status = str(value.get("status", ""))

        if "pending" in status:
            pending.append(
                f"{category}:{key}:{status}"
            )

if pending:
    raise SystemExit(
        "FAIL: recovery ledger contains pending write state."
    )

print("PASS: explicit failed-verification recovery state validated.")
PY_RECOVERY

  CREDENTIAL_COUNT="$(
    find "$CREDENTIAL_DIR" \
      -maxdepth 1 \
      -type f \
      -name '*.json' |
    wc -l
  )"

  if [[ "$CREDENTIAL_COUNT" -ne 9 ]]; then
    echo "FAIL: recovery mode expected 9 credential records."
    exit 1
  fi

  git check-ignore -q "$OPERATION"

  echo "PASS: recovery ledger is ignored by Git."
  echo "PASS: recovery credential records=9."
  echo "PASS: recovery-mode execution artifacts accepted explicitly."

else
  if [[ -e \
    local-evidence/identity-full-provisioning-operation.json
  ]]; then
    echo "FAIL: Full Apply has already started."
    exit 1
  fi

  if [[ -d local-evidence/full-credentials ]] &&
     find \
       local-evidence/full-credentials \
       -type f \
       -print -quit |
     grep -q .
  then
    echo "FAIL: Full Apply credentials already exist."
    exit 1
  fi

  echo "PASS: no Full Apply execution artifacts exist."
fi

echo "=================================================="
echo "IDENTITY FULL APPLY SEMANTIC TESTS PASSED"
echo "=================================================="
