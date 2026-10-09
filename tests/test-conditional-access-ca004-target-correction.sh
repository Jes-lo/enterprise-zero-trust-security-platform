#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

CONFIG="$ROOT/configs/conditional-access-baseline.json"

HIST="$ROOT/docs/evidence/conditional-access-report-only-creation-validation.json"

CORR="$ROOT/docs/evidence/conditional-access-ca004-target-correction-validation.json"

VALIDATOR="$ROOT/scripts/validate-conditional-access-ca004-target-correction.py"

TMP="$(mktemp -d)"

trap 'rm -rf "$TMP"' EXIT

python3 \
  "$VALIDATOR" \
  "$CONFIG" \
  "$HIST" \
  "$CORR"

make_fixture() {
  local mutation="$1"
  local c="$TMP/config-$mutation.json"
  local h="$TMP/hist-$mutation.json"
  local r="$TMP/corr-$mutation.json"

  python3 - \
    "$CONFIG" \
    "$HIST" \
    "$CORR" \
    "$c" \
    "$h" \
    "$r" \
    "$mutation" <<'PY'
import json
import sys
from pathlib import Path

config = json.loads(Path(sys.argv[1]).read_text())
hist = json.loads(Path(sys.argv[2]).read_text())
corr = json.loads(Path(sys.argv[3]).read_text())

config_out = Path(sys.argv[4])
hist_out = Path(sys.argv[5])
corr_out = Path(sys.argv[6])
mutation = sys.argv[7]

ca004 = {
    item["id"]: item
    for item in config["planned_policies"]
}["CA-004"]

if mutation == "wrong-target":
    ca004["target_resource_display_name"] = (
        "Windows Azure Active Directory"
    )

elif mutation == "policy-on":
    ca004["enabled"] = True

elif mutation == "mode-on":
    ca004["current_mode"] = "on"

elif mutation == "security-defaults-off":
    corr["baseline_state"]["security_defaults_enabled"] = False

elif mutation == "extra-write":
    corr["correction"]["tenant_write_count"] = 2

elif mutation == "wrong-history":
    {
        item["id"]: item
        for item in hist["created_policies"]
    }["CA-004"]["target"] = "Microsoft Admin Portals"

elif mutation == "pilot-member":
    corr["baseline_state"]["ca_pilot_group_member_count"] = 1

elif mutation == "recovery-write":
    corr["recovery"]["additional_tenant_writes"] = 1

else:
    raise SystemExit("unknown mutation")

config_out.write_text(json.dumps(config, indent=2) + "\n")
hist_out.write_text(json.dumps(hist, indent=2) + "\n")
corr_out.write_text(json.dumps(corr, indent=2) + "\n")
PY
}

expect_reject() {
  local mutation="$1"

  make_fixture "$mutation"

  if python3 \
       "$VALIDATOR" \
       "$TMP/config-$mutation.json" \
       "$TMP/hist-$mutation.json" \
       "$TMP/corr-$mutation.json" \
       >/dev/null 2>&1
  then
    echo "FAIL: accepted forbidden fixture: $mutation"
    exit 1
  fi

  echo "PASS: rejected forbidden fixture: $mutation"
}

expect_reject "wrong-target"
expect_reject "policy-on"
expect_reject "mode-on"
expect_reject "security-defaults-off"
expect_reject "extra-write"
expect_reject "wrong-history"
expect_reject "pilot-member"
expect_reject "recovery-write"

echo "PASS: all Feature 6B-R1 adversarial tests passed."
