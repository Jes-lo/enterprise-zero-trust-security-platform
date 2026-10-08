#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

VALIDATOR="$ROOT/scripts/validate-privileged-admin-authentication.py"
CONFIG="$ROOT/configs/rbac-privileged-administration.json"
EVIDENCE="$ROOT/docs/evidence/rbac-privileged-admin-authentication-validation.json"

TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT

python3 "$VALIDATOR" "$CONFIG" "$EVIDENCE"

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

if mutation == "premature-role":
    principal["current_directory_role"] = (
        "Privileged Role Administrator"
    )

elif mutation == "no-authenticator":
    evidence[
        "authentication"
    ][
        "microsoft_authenticator_registered"
    ] = False

elif mutation == "no-passkey":
    evidence[
        "authentication"
    ][
        "device_bound_passkey_registered"
    ] = False

elif mutation == "passkey-not-tested":
    evidence[
        "authentication"
    ][
        "passwordless_passkey_test_successful"
    ] = False

elif mutation == "historical-group-count":
    evidence[
        "tenant_state_after"
    ][
        "group_membership_count"
    ] = 0

elif mutation == "missing-correction":
    evidence.pop("correction_notice", None)

elif mutation == "ga-baseline":
    evidence[
        "tenant_state_after"
    ][
        "global_administrator_assignment_count"
    ] = 2

elif mutation == "security-defaults-off":
    evidence[
        "tenant_state_after"
    ][
        "security_defaults_enabled"
    ] = False

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
  "premature-role" \
  "PRA assigned before Feature 5C5"

expect_reject \
  "no-authenticator" \
  "Microsoft Authenticator missing"

expect_reject \
  "no-passkey" \
  "Device-bound passkey missing"

expect_reject \
  "passkey-not-tested" \
  "Passkey registered but passwordless sign-in not proven"

expect_reject \
  "historical-group-count" \
  "Corrected historical group count reverted to zero"

expect_reject \
  "missing-correction" \
  "Feature 5C4-R1 correction metadata removed"

expect_reject \
  "ga-baseline" \
  "Global Administrator baseline unexpectedly changed"

expect_reject \
  "security-defaults-off" \
  "Security Defaults unexpectedly disabled"

echo
echo "=================================================="
echo "ALL FEATURE 5C3/5C4 AUTH TESTS PASSED"
echo "=================================================="
