#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

CONFIG="$ROOT/configs/conditional-access-baseline.json"
EVIDENCE="$ROOT/docs/evidence/conditional-access-baseline-validation.json"
VALIDATOR="$ROOT/scripts/validate-conditional-access-baseline.py"

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

if mutation == "security-defaults-off":
    config[
        "current_state"
    ][
        "security_defaults_enabled"
    ] = False

elif mutation == "existing-policy":
    evidence[
        "tenant_state"
    ][
        "conditional_access_policy_count"
    ] = 1

elif mutation == "pilot-member":
    config[
        "pilot_strategy"
    ][
        "current_member_count"
    ] = 1

elif mutation == "policy-created":
    config[
        "planned_policies"
    ][0][
        "created"
    ] = True

elif mutation == "policy-enabled":
    config[
        "planned_policies"
    ][0][
        "enabled"
    ] = True

elif mutation == "not-report-only":
    config[
        "planned_policies"
    ][0][
        "planned_initial_mode"
    ] = "on"

elif mutation == "authorize-policy-create":
    config[
        "authorization"
    ][
        "conditional_access_policy_creation_authorized"
    ] = True

elif mutation == "authorize-sd-disable":
    config[
        "authorization"
    ][
        "security_defaults_disable_authorized"
    ] = True

elif mutation == "bootstrap-reduction":
    config[
        "migration_principles"
    ][
        "bootstrap_reduction_allowed"
    ] = True

elif mutation == "emergency-operational":
    evidence[
        "emergency_access_state"
    ][
        "live_recovery_path_operational"
    ] = True

elif mutation == "pim-feature":
    config[
        "feature_boundaries"
    ][
        "pim_owner_feature"
    ] = 6

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
    echo "FAIL: CA baseline validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: CA baseline validator rejected forbidden fixture."
}

expect_reject \
  "security-defaults-off" \
  "Security Defaults disabled during Feature 6A"

expect_reject \
  "existing-policy" \
  "Unexpected preexisting Conditional Access policy"

expect_reject \
  "pilot-member" \
  "CA pilot group modified before authorization"

expect_reject \
  "policy-created" \
  "Conditional Access policy marked created during baseline"

expect_reject \
  "policy-enabled" \
  "Conditional Access policy marked enabled during baseline"

expect_reject \
  "not-report-only" \
  "Planned baseline policy skips report-only"

expect_reject \
  "authorize-policy-create" \
  "Conditional Access creation prematurely authorized"

expect_reject \
  "authorize-sd-disable" \
  "Security Defaults cutover prematurely authorized"

expect_reject \
  "bootstrap-reduction" \
  "Bootstrap reduction allowed without emergency recovery"

expect_reject \
  "emergency-operational" \
  "Repository falsely claims emergency recovery exists"

expect_reject \
  "pim-feature" \
  "PIM incorrectly moved into Feature 6"

echo
echo "=================================================="
echo "ALL FEATURE 6A CONDITIONAL ACCESS TESTS PASSED"
echo "=================================================="
