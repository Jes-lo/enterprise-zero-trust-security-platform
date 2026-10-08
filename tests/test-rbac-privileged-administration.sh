#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

VALIDATOR="$ROOT/scripts/validate-rbac-privileged-administration.py"
CONFIG="$ROOT/configs/rbac-privileged-administration.json"

TMP="$(
  mktemp -d
)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT

echo "=================================================="
echo "RBAC PRIVILEGED ADMINISTRATION ADVERSARIAL TESTS"
echo "=================================================="

python3 "$VALIDATOR" "$CONFIG"

make_fixture() {
  local output="$1"
  local mutation="$2"

  python3 - \
    "$CONFIG" \
    "$output" \
    "$mutation" <<'PY'
import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
mutation = sys.argv[3]

data = json.loads(
    source.read_text()
)

if mutation == "security-defaults-off":
    data[
        "feature_boundaries"
    ][
        "security_defaults_preserved"
    ] = False

elif mutation == "privileged-admin-ga":
    data[
        "principals"
    ][
        "privileged_admin_01"
    ][
        "initial_feature5_role"
    ] = "Global Administrator"

elif mutation == "pim-enabled":
    data[
        "feature_boundaries"
    ][
        "pim_changes_allowed"
    ] = True

elif mutation == "tenant-write-enabled":
    data[
        "feature_boundaries"
    ][
        "tenant_writes_allowed_in_phase_5B"
    ] = True

else:
    raise SystemExit(
        "unknown mutation"
    )

target.write_text(
    json.dumps(
        data,
        indent=2,
    )
    + "\n"
)
PY
}

expect_reject() {
  local fixture="$1"
  local description="$2"

  echo
  echo "TEST: $description"

  if python3 \
    "$VALIDATOR" \
    "$fixture" \
    >/dev/null 2>&1
  then
    echo "FAIL: validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: validator rejected forbidden fixture."
}

make_fixture \
  "$TMP/security-defaults-off.json" \
  "security-defaults-off"

expect_reject \
  "$TMP/security-defaults-off.json" \
  "Security Defaults disabled"

make_fixture \
  "$TMP/privileged-admin-ga.json" \
  "privileged-admin-ga"

expect_reject \
  "$TMP/privileged-admin-ga.json" \
  "PRIVILEGED_ADMIN_01 defaults to Global Administrator"

make_fixture \
  "$TMP/pim-enabled.json" \
  "pim-enabled"

expect_reject \
  "$TMP/pim-enabled.json" \
  "PIM changed during Feature 5"

make_fixture \
  "$TMP/tenant-write-enabled.json" \
  "tenant-write-enabled"

expect_reject \
  "$TMP/tenant-write-enabled.json" \
  "Feature 5B tenant write authorization"

echo
echo "=================================================="
echo "ALL RBAC PRIVILEGED ADMINISTRATION TESTS PASSED"
echo "=================================================="
