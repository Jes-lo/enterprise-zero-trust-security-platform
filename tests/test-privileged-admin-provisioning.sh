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

config_source = Path(sys.argv[1])
evidence_source = Path(sys.argv[2])

config_target = Path(sys.argv[3])
evidence_target = Path(sys.argv[4])

mutation = sys.argv[5]

config = json.loads(
    config_source.read_text()
)

evidence = json.loads(
    evidence_source.read_text()
)

if mutation == "premature-role":
    config[
        "principals"
    ][
        "privileged_admin_01"
    ][
        "current_directory_role"
    ] = "Privileged Role Administrator"

elif mutation == "evidence-role":
    evidence[
        "provisioning"
    ][
        "directory_role_assignment_count"
    ] = 1

elif mutation == "license":
    evidence[
        "provisioning"
    ][
        "license_count"
    ] = 1

elif mutation == "ga-baseline":
    evidence[
        "baseline_after"
    ][
        "global_administrator_assignment_count"
    ] = 2

elif mutation == "premature-auth":
    config[
        "principals"
    ][
        "privileged_admin_01"
    ][
        "strong_authentication_state"
    ] = "validated"

else:
    raise SystemExit("unknown mutation")

config_target.write_text(
    json.dumps(
        config,
        indent=2,
    )
    + "\n"
)

evidence_target.write_text(
    json.dumps(
        evidence,
        indent=2,
    )
    + "\n"
)
PY
}

expect_reject() {
  local mutation="$1"
  local description="$2"

  local config_fixture="$TMP/${mutation}-config.json"
  local evidence_fixture="$TMP/${mutation}-evidence.json"

  make_fixture \
    "$config_fixture" \
    "$evidence_fixture" \
    "$mutation"

  echo
  echo "TEST: $description"

  if python3 \
    "$VALIDATOR" \
    "$config_fixture" \
    "$evidence_fixture" \
    >/dev/null 2>&1
  then
    echo "FAIL: validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: validator rejected forbidden fixture."
}

expect_reject \
  "premature-role" \
  "Directory role assigned before strong-authentication validation"

expect_reject \
  "evidence-role" \
  "Provisioning evidence reports a premature role"

expect_reject \
  "license" \
  "Unexpected license assigned to privileged identity"

expect_reject \
  "ga-baseline" \
  "Global Administrator baseline unexpectedly increased"

expect_reject \
  "premature-auth" \
  "Strong authentication marked validated before 5C3/5C4"

echo
echo "=================================================="
echo "ALL FEATURE 5C2 ADVERSARIAL TESTS PASSED"
echo "=================================================="
