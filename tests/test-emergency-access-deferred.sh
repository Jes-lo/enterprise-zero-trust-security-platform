#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

RBAC="$ROOT/configs/rbac-privileged-administration.json"

EVIDENCE="$ROOT/docs/evidence/rbac-emergency-access-deferred-validation.json"

VALIDATOR="$ROOT/scripts/validate-emergency-access-deferred.py"

TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT

python3 \
  "$VALIDATOR" \
  "$RBAC" \
  "$EVIDENCE"

make_fixture() {
  local rbac_out="$1"
  local evidence_out="$2"
  local mutation="$3"

  python3 - \
    "$RBAC" \
    "$EVIDENCE" \
    "$rbac_out" \
    "$evidence_out" \
    "$mutation" <<'PY'
import json
import sys
from pathlib import Path

rbac = json.loads(Path(sys.argv[1]).read_text())
evidence = json.loads(Path(sys.argv[2]).read_text())

rbac_out = Path(sys.argv[3])
evidence_out = Path(sys.argv[4])
mutation = sys.argv[5]

emergency = rbac["principals"]["emergency_access"]

if mutation == "enabled":
    emergency["current_account_enabled_count"] = 1

elif mutation == "role":
    emergency["current_directory_role_assignment_count"] = 1

elif mutation == "weak-auth":
    emergency["weaker_authentication_substitution_allowed"] = True

elif mutation == "totp":
    evidence[
        "security_rationale"
    ][
        "totp_as_final_emergency_method_allowed"
    ] = True

elif mutation == "password":
    evidence[
        "security_rationale"
    ][
        "password_only_allowed"
    ] = True

elif mutation == "claims-operational":
    evidence[
        "feature5_end_state"
    ][
        "emergency_access_live_recovery_path_operational"
    ] = True

elif mutation == "bootstrap-reduction":
    evidence[
        "feature5_end_state"
    ][
        "bootstrap_reduction_permitted"
    ] = True

elif mutation == "ga-baseline":
    evidence[
        "current_tenant_state"
    ][
        "global_administrator_assignment_count"
    ] = 3

elif mutation == "future-option-selected":
    emergency[
        "future_authentication_selected_for_current_project"
    ] = "device-bound-passkey"

elif mutation == "future-option-implemented":
    evidence[
        "decision"
    ][
        "implemented_in_current_project"
    ] = True

elif mutation == "future-options-removed":
    evidence[
        "decision"
    ][
        "possible_future_implementations"
    ] = []

elif mutation == "future-gate-removed":
    evidence[
        "future_resume_gate"
    ][
        "independent_phishing_resistant_credential_required"
    ] = False

else:
    raise SystemExit("unknown mutation")

rbac_out.write_text(
    json.dumps(rbac, indent=2) + "\n"
)

evidence_out.write_text(
    json.dumps(evidence, indent=2) + "\n"
)
PY
}

expect_reject() {
  local mutation="$1"
  local description="$2"

  local r="$TMP/${mutation}-rbac.json"
  local e="$TMP/${mutation}-evidence.json"

  make_fixture "$r" "$e" "$mutation"

  echo
  echo "TEST: $description"

  if python3 \
       "$VALIDATOR" \
       "$r" \
       "$e" \
       >/dev/null 2>&1
  then
    echo "FAIL: validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: validator rejected forbidden fixture."
}

expect_reject \
  "enabled" \
  "Deferred emergency account becomes enabled"

expect_reject \
  "role" \
  "Deferred emergency account receives a role"

expect_reject \
  "weak-auth" \
  "Weak authentication substitution becomes allowed"

expect_reject \
  "totp" \
  "TOTP accepted as final emergency authentication"

expect_reject \
  "password" \
  "Password-only emergency authentication accepted"

expect_reject \
  "claims-operational" \
  "Repository falsely claims emergency recovery is operational"

expect_reject \
  "bootstrap-reduction" \
  "Bootstrap reduction allowed without emergency recovery path"

expect_reject \
  "ga-baseline" \
  "Repository falsely claims three live Global Administrators"

expect_reject \
  "future-option-selected" \
  "Future passkey/FIDO2 option selected in current project"

expect_reject \
  "future-option-implemented" \
  "Future passkey/FIDO2 option marked as implemented"

expect_reject \
  "future-options-removed" \
  "Documented future authentication options removed"

expect_reject \
  "future-gate-removed" \
  "Future phishing-resistant credential requirement removed"

echo
echo "=================================================="
echo "ALL FEATURE 5D2-D DEFERRED-ACCESS TESTS PASSED"
echo "=================================================="
