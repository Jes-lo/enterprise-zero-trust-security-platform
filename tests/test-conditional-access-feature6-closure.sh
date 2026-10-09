#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

CONFIG="$ROOT/configs/conditional-access-baseline.json"

EVIDENCE="$ROOT/docs/evidence/conditional-access-feature6-closure-validation.json"

VALIDATOR="$ROOT/scripts/validate-conditional-access-feature6-closure.py"

TMP="$(mktemp -d)"

trap 'rm -rf "$TMP"' EXIT

python3 \
  "$VALIDATOR" \
  "$CONFIG" \
  "$EVIDENCE"

make_fixture() {
  local mutation="$1"
  local c="$TMP/config-$mutation.json"
  local e="$TMP/evidence-$mutation.json"

  python3 - \
    "$CONFIG" \
    "$EVIDENCE" \
    "$c" \
    "$e" \
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
    evidence["tenant_state"]["security_defaults_enabled"] = False

elif mutation == "enforcement-ready":
    config["feature6_closure"]["enforcement_ready"] = True

elif mutation == "enforcement-performed":
    evidence["enforcement_decision"]["performed"] = True

elif mutation == "authorize-enforcement":
    evidence["enforcement_decision"]["authorized"] = True

elif mutation == "authorize-cutover":
    config[
        "feature6_closure"
    ][
        "security_defaults_cutover_authorized"
    ] = True

elif mutation == "emergency-operational":
    evidence["emergency_access"]["operational"] = True

elif mutation == "fake-phishing-resistant-recovery":
    evidence[
        "emergency_access"
    ][
        "independent_phishing_resistant_recovery_path"
    ] = True

elif mutation == "permit-weak-fallback":
    evidence[
        "emergency_access"
    ][
        "weak_auth_fallback_permitted"
    ] = True

elif mutation == "bootstrap-reduction":
    evidence[
        "bootstrap"
    ][
        "privilege_reduction_authorized"
    ] = True

elif mutation == "pilot-member":
    evidence[
        "tenant_state"
    ][
        "ca_pilot_group_member_count"
    ] = 1

elif mutation == "tenant-write":
    evidence[
        "closure"
    ][
        "tenant_configuration_writes"
    ] = 1

elif mutation == "write-accounting":
    evidence[
        "write_accounting"
    ][
        "cumulative_feature6_tenant_writes"
    ] = 6

elif mutation == "wrong-closure-state":
    evidence[
        "closure"
    ][
        "state"
    ] = "enforced"

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

  make_fixture "$mutation"

  if python3 \
       "$VALIDATOR" \
       "$TMP/config-$mutation.json" \
       "$TMP/evidence-$mutation.json" \
       >/dev/null 2>&1
  then
    echo "FAIL: accepted forbidden fixture: $mutation"
    exit 1
  fi

  echo "PASS: rejected forbidden fixture: $mutation"
}

expect_reject "policy-on"
expect_reject "mode-on"
expect_reject "security-defaults-off"
expect_reject "enforcement-ready"
expect_reject "enforcement-performed"
expect_reject "authorize-enforcement"
expect_reject "authorize-cutover"
expect_reject "emergency-operational"
expect_reject "fake-phishing-resistant-recovery"
expect_reject "permit-weak-fallback"
expect_reject "bootstrap-reduction"
expect_reject "pilot-member"
expect_reject "tenant-write"
expect_reject "write-accounting"
expect_reject "wrong-closure-state"

echo "PASS: all Feature 6D adversarial tests passed."
