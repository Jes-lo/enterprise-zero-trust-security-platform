#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

VALIDATOR="$ROOT/scripts/validate-privileged-admin-provisioning.py"
CONFIG="$ROOT/configs/rbac-privileged-administration.json"
EVIDENCE="$ROOT/docs/evidence/rbac-privileged-admin-provisioning-validation.json"

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

if mutation == "wrong-current-role":
    principal["current_directory_role"] = "Global Administrator"

elif mutation == "planned-role-changed":
    principal["initial_feature5_role"] = "Global Administrator"

elif mutation == "evidence-role":
    evidence[
        "provisioning"
    ][
        "directory_role_assignment_count"
    ] = 1

elif mutation == "license":
    evidence["provisioning"]["license_count"] = 1

elif mutation == "ga-baseline":
    evidence[
        "baseline_after"
    ][
        "global_administrator_assignment_count"
    ] = 2

elif mutation == "state-mismatch":
    principal["provisioning_state"] = (
        "created-unprivileged-auth-ready"
    )
    principal["strong_authentication_state"] = (
        "pending-first-sign-in-registration"
    )
    principal["initial_sign_in_complete"] = False

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

  if python3 "$VALIDATOR" "$c" "$e" >/dev/null 2>&1; then
    echo "FAIL: validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: validator rejected forbidden fixture."
}

expect_reject \
  "wrong-current-role" \
  "Unexpected current privileged role"

expect_reject \
  "planned-role-changed" \
  "Planned Feature 5 role changed unexpectedly"

expect_reject \
  "evidence-role" \
  "Historical Feature 5C2 evidence contains a role"

expect_reject \
  "license" \
  "Historical Feature 5C2 evidence contains a license"

expect_reject \
  "ga-baseline" \
  "Historical Global Administrator baseline changed"

expect_reject \
  "state-mismatch" \
  "Current authentication/provisioning state is inconsistent"

echo
echo "=================================================="
echo "ALL FEATURE 5C2 PROGRESSION TESTS PASSED"
echo "=================================================="
