#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

CONFIG="$ROOT/configs/conditional-access-baseline.json"

EVIDENCE="$ROOT/docs/evidence/conditional-access-report-only-evaluation-validation.json"

VALIDATOR="$ROOT/scripts/validate-conditional-access-report-only-evaluation.py"

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

elif mutation == "tenant-write":
    evidence["tenant_state"]["tenant_configuration_writes"] = 1

elif mutation == "scenario-failed":
    evidence["what_if"]["scenarios"][0]["validated"] = False

elif mutation == "legacy-not-blocked":
    evidence[
        "what_if"
    ][
        "scenarios"
    ][3][
        "expected_ca003_control"
    ] = "mfa"

elif mutation == "admin-portals-missing":
    evidence[
        "what_if"
    ][
        "scenarios"
    ][4][
        "expected_plab_applicable"
    ] = ["CA-001"]

elif mutation == "emergency-not-excluded":
    evidence[
        "emergency_exclusion_validation"
    ][
        "both_emergency_identities_excluded"
    ] = False

elif mutation == "signin-ca004-missing":
    evidence[
        "real_sign_in_validation"
    ][
        "ca004_applied"
    ] = False

elif mutation == "claim-enforcement":
    evidence[
        "decision"
    ][
        "safe_to_claim_enforcement"
    ] = True

elif mutation == "ready-for-enforcement":
    config[
        "report_only_evaluation"
    ][
        "enforcement_ready"
    ] = True

elif mutation == "authorize-cutover":
    evidence[
        "decision"
    ][
        "security_defaults_cutover_authorized"
    ] = True

elif mutation == "pilot-member":
    evidence[
        "tenant_state"
    ][
        "ca_pilot_group_member_count"
    ] = 1

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
expect_reject "tenant-write"
expect_reject "scenario-failed"
expect_reject "legacy-not-blocked"
expect_reject "admin-portals-missing"
expect_reject "emergency-not-excluded"
expect_reject "signin-ca004-missing"
expect_reject "claim-enforcement"
expect_reject "ready-for-enforcement"
expect_reject "authorize-cutover"
expect_reject "pilot-member"

echo "PASS: all Feature 6C adversarial tests passed."
