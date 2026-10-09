#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

CONFIG="$ROOT/configs/conditional-access-baseline.json"

EVIDENCE="$ROOT/docs/evidence/conditional-access-report-only-creation-validation.json"

VALIDATOR="$ROOT/scripts/validate-conditional-access-report-only-creation.py"

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

if mutation == "policy-on":
    config["planned_policies"][0]["enabled"] = True

elif mutation == "mode-on":
    config["planned_policies"][0]["current_mode"] = "on"

elif mutation == "security-defaults-off":
    evidence["post_write_state"]["security_defaults_enabled"] = False

elif mutation == "three-policies":
    evidence["post_write_state"]["conditional_access_policy_count"] = 3

elif mutation == "pilot-member":
    evidence["post_write_state"]["ca_pilot_group_member_count"] = 1

elif mutation == "extra-write":
    evidence["write_activity"]["tenant_writes"] = 5

elif mutation == "role-change":
    evidence["write_activity"]["role_modifications"] = 1

elif mutation == "future-enforcement":
    evidence["future_authorization"]["policy_enforcement_authorized"] = True

elif mutation == "bad-azure-target":
    config[
        "planned_policies"
    ][3][
        "target_resource_display_name"
    ] = "All resources"

elif mutation == "missing-policy":
    evidence["created_policies"] = evidence["created_policies"][:3]

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
    echo "FAIL: Feature 6B validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: Feature 6B validator rejected forbidden fixture."
}

expect_reject \
  "policy-on" \
  "Conditional Access policy marked enforced"

expect_reject \
  "mode-on" \
  "Conditional Access mode changes from report-only to On"

expect_reject \
  "security-defaults-off" \
  "Security Defaults disabled during Feature 6B"

expect_reject \
  "three-policies" \
  "Report-only baseline contains fewer than four policies"

expect_reject \
  "pilot-member" \
  "Pilot membership changed during report-only creation"

expect_reject \
  "extra-write" \
  "More than four tenant writes recorded"

expect_reject \
  "role-change" \
  "Directory role changed during Feature 6B"

expect_reject \
  "future-enforcement" \
  "Policy enforcement prematurely authorized"

expect_reject \
  "bad-azure-target" \
  "Azure management policy targets wrong resource"

expect_reject \
  "missing-policy" \
  "One report-only policy missing from evidence"

echo
echo "=================================================="
echo "ALL FEATURE 6B REPORT-ONLY TESTS PASSED"
echo "=================================================="
