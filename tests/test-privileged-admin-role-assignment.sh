#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

VALIDATOR="$ROOT/scripts/validate-privileged-admin-role-assignment.py"
CONFIG="$ROOT/configs/rbac-privileged-administration.json"
EVIDENCE="$ROOT/docs/evidence/rbac-privileged-admin-role-assignment-validation.json"

TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT

python3 \
  "$VALIDATOR" \
  "$CONFIG" \
  "$EVIDENCE"

make_fixture() {
  local config_out="$1"
  local evidence_out="$2"
  local mutation="$3"

  python3 - \
    "$CONFIG" \
    "$EVIDENCE" \
    "$config_out" \
    "$evidence_out" \
    "$mutation" <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text())
evidence = json.loads(Path(sys.argv[2]).read_text())

config_out = Path(sys.argv[3])
evidence_out = Path(sys.argv[4])
mutation = sys.argv[5]

principal = config["principals"]["privileged_admin_01"]

if mutation == "global-admin":
    principal["current_directory_role"] = "Global Administrator"

elif mutation == "planned-role":
    principal["initial_feature5_role"] = "Global Administrator"

elif mutation == "two-roles":
    evidence[
        "post_assignment_state"
    ][
        "directory_role_assignment_count"
    ] = 2

elif mutation == "group-membership":
    evidence[
        "post_assignment_state"
    ][
        "group_membership_count"
    ] = 1

elif mutation == "license":
    evidence[
        "post_assignment_state"
    ][
        "license_count"
    ] = 1

elif mutation == "pim":
    evidence[
        "assignment"
    ][
        "pim"
    ] = True

elif mutation == "eligible":
    evidence[
        "assignment"
    ][
        "assignment_state"
    ] = "eligible"

elif mutation == "wrong-scope":
    evidence[
        "assignment"
    ][
        "scope"
    ] = "administrative-unit"

elif mutation == "ga-baseline":
    evidence[
        "post_assignment_state"
    ][
        "global_administrator_assignment_count"
    ] = 2

elif mutation == "functional-write":
    evidence[
        "functional_validation"
    ][
        "administrative_writes_performed_during_functional_test"
    ] = 1

elif mutation == "no-passkey-test":
    evidence[
        "functional_validation"
    ][
        "fresh_passkey_sign_in_successful"
    ] = False

elif mutation == "bootstrap-reduction":
    evidence[
        "authorization_state_after"
    ][
        "bootstrap_reduction_authorized"
    ] = True

else:
    raise SystemExit("unknown mutation")

config_out.write_text(
    json.dumps(config, indent=2) + "\n"
)

evidence_out.write_text(
    json.dumps(evidence, indent=2) + "\n"
)
PY
}

expect_reject() {
  local mutation="$1"
  local description="$2"

  local c="$TMP/${mutation}-config.json"
  local e="$TMP/${mutation}-evidence.json"

  make_fixture "$c" "$e" "$mutation"

  echo
  echo "TEST: $description"

  if python3 \
       "$VALIDATOR" \
       "$c" \
       "$e" \
       >/dev/null 2>&1
  then
    echo "FAIL: validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: validator rejected forbidden fixture."
}

expect_reject \
  "global-admin" \
  "Current privileged role changed to Global Administrator"

expect_reject \
  "planned-role" \
  "Planned Feature 5 role unexpectedly changed"

expect_reject \
  "two-roles" \
  "Privileged identity receives more than one role"

expect_reject \
  "group-membership" \
  "Privileged identity regains a group membership"

expect_reject \
  "license" \
  "Privileged identity unexpectedly receives a license"

expect_reject \
  "pim" \
  "PIM configured prematurely in Feature 5"

expect_reject \
  "eligible" \
  "Eligible assignment used instead of active-static-interim"

expect_reject \
  "wrong-scope" \
  "Role assigned to unexpected scope"

expect_reject \
  "ga-baseline" \
  "Global Administrator baseline changed"

expect_reject \
  "functional-write" \
  "Functional PRA test performs an administrative write"

expect_reject \
  "no-passkey-test" \
  "Fresh passkey sign-in was not validated"

expect_reject \
  "bootstrap-reduction" \
  "Bootstrap reduction prematurely authorized"

echo
echo "=================================================="
echo "ALL FEATURE 5C5/5C6 ROLE TESTS PASSED"
echo "=================================================="
