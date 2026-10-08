#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

VALIDATOR="$ROOT/scripts/validate-privileged-admin-group-remediation.py"
CONFIG="$ROOT/configs/rbac-privileged-administration.json"
AUTH="$ROOT/docs/evidence/rbac-privileged-admin-authentication-validation.json"
EVIDENCE="$ROOT/docs/evidence/rbac-privileged-admin-group-remediation-validation.json"

TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT

python3 \
  "$VALIDATOR" \
  "$CONFIG" \
  "$AUTH" \
  "$EVIDENCE"

make_fixture() {
  local config_out="$1"
  local auth_out="$2"
  local evidence_out="$3"
  local mutation="$4"

  python3 - \
    "$CONFIG" \
    "$AUTH" \
    "$EVIDENCE" \
    "$config_out" \
    "$auth_out" \
    "$evidence_out" \
    "$mutation" <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text())
auth = json.loads(Path(sys.argv[2]).read_text())
evidence = json.loads(Path(sys.argv[3]).read_text())

config_out = Path(sys.argv[4])
auth_out = Path(sys.argv[5])
evidence_out = Path(sys.argv[6])
mutation = sys.argv[7]

principal = config["principals"]["privileged_admin_01"]

if mutation == "wrong-current-role":
    principal["current_directory_role"] = "Global Administrator"

elif mutation == "membership-remains":
    evidence[
        "post_remediation_state"
    ][
        "principal_group_membership_count"
    ] = 1

elif mutation == "unexpected-role":
    evidence[
        "post_remediation_state"
    ][
        "directory_role_assignment_count"
    ] = 1

elif mutation == "second-write":
    evidence[
        "remediation"
    ][
        "authorized_write_count"
    ] = 2

elif mutation == "wrong-member-count":
    evidence[
        "post_remediation_state"
    ][
        "group_member_count_after"
    ] = 8

elif mutation == "ga-baseline":
    evidence[
        "post_remediation_state"
    ][
        "global_administrator_assignment_count"
    ] = 2

elif mutation == "premature-5c5":
    evidence[
        "authorization_state_after"
    ][
        "feature5c5_role_assignment_authorized"
    ] = True

elif mutation == "historical-correction-lost":
    auth[
        "tenant_state_after"
    ][
        "group_membership_count"
    ] = 0

else:
    raise SystemExit("unknown mutation")

config_out.write_text(
    json.dumps(config, indent=2) + "\n"
)

auth_out.write_text(
    json.dumps(auth, indent=2) + "\n"
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
  local a="$TMP/${mutation}-auth.json"
  local e="$TMP/${mutation}-evidence.json"

  make_fixture "$c" "$a" "$e" "$mutation"

  echo
  echo "TEST: $description"

  if python3 \
       "$VALIDATOR" \
       "$c" \
       "$a" \
       "$e" \
       >/dev/null 2>&1
  then
    echo "FAIL: validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: validator rejected forbidden fixture."
}

expect_reject \
  "wrong-current-role" \
  "Unexpected current privileged role"

expect_reject \
  "membership-remains" \
  "Privileged admin still belongs to collaboration group"

expect_reject \
  "unexpected-role" \
  "Directory role assigned during remediation"

expect_reject \
  "second-write" \
  "More than one tenant write recorded"

expect_reject \
  "wrong-member-count" \
  "Unexpected group member count after removal"

expect_reject \
  "ga-baseline" \
  "Global Administrator baseline changed"

expect_reject \
  "premature-5c5" \
  "Feature 5C5 prematurely authorized"

expect_reject \
  "historical-correction-lost" \
  "Historical group discrepancy was rewritten away"

echo
echo "=================================================="
echo "ALL FEATURE 5C4-R1 REMEDIATION TESTS PASSED"
echo "=================================================="
