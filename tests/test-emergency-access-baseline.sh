#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

IDENTITY="$ROOT/configs/identity-foundation.json"
RBAC="$ROOT/configs/rbac-privileged-administration.json"
EVIDENCE="$ROOT/docs/evidence/rbac-emergency-access-baseline-validation.json"

VALIDATOR="$ROOT/scripts/validate-emergency-access-baseline.py"
BASE_VALIDATOR="$ROOT/scripts/validate-rbac-privileged-administration.py"

TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT

python3 \
  "$VALIDATOR" \
  "$IDENTITY" \
  "$RBAC" \
  "$EVIDENCE"

make_fixture() {
  local identity_out="$1"
  local rbac_out="$2"
  local evidence_out="$3"
  local mutation="$4"

  python3 - \
    "$IDENTITY" \
    "$RBAC" \
    "$EVIDENCE" \
    "$identity_out" \
    "$rbac_out" \
    "$evidence_out" \
    "$mutation" <<'PY'
import json
import sys
from pathlib import Path

identity = json.loads(Path(sys.argv[1]).read_text())
rbac = json.loads(Path(sys.argv[2]).read_text())
evidence = json.loads(Path(sys.argv[3]).read_text())

identity_out = Path(sys.argv[4])
rbac_out = Path(sys.argv[5])
evidence_out = Path(sys.argv[6])
mutation = sys.argv[7]

emergency = rbac["principals"]["emergency_access"]

if mutation == "wrong-logical-ids":
    emergency["logical_ids"] = [
        "EMERGENCY_ACCESS_01",
        "EMERGENCY_ACCESS_02",
    ]

elif mutation == "identity-not-cloud-only":
    for item in identity["accounts"]:
        if item["id"] == "EMERGENCY_ADMIN_01":
            item["cloud_only"] = False

elif mutation == "enabled-too-early":
    evidence[
        "emergency_access"
    ][
        "current_state"
    ][
        "enabled_identity_count"
    ] = 1

elif mutation == "premature-role":
    evidence[
        "emergency_access"
    ][
        "current_state"
    ][
        "directory_role_assignment_count"
    ] = 1

elif mutation == "unexpected-group":
    evidence[
        "emergency_access"
    ][
        "current_state"
    ][
        "group_membership_count"
    ] = 1

elif mutation == "unexpected-license":
    evidence[
        "emergency_access"
    ][
        "current_state"
    ][
        "license_count"
    ] = 1

elif mutation == "premature-auth":
    evidence[
        "emergency_access"
    ][
        "current_state"
    ][
        "registered_strong_authentication_identity_count"
    ] = 1

elif mutation == "wrong-target-role":
    emergency["target_role"] = "Privileged Role Administrator"

elif mutation == "eligible-pim":
    emergency["pim_target_state"] = "eligible"

elif mutation == "routine-use":
    emergency["routine_use"] = True

elif mutation == "bootstrap-reduction":
    evidence[
        "authorization"
    ][
        "bootstrap_reduction_authorized"
    ] = True

else:
    raise SystemExit("unknown mutation")

identity_out.write_text(
    json.dumps(identity, indent=2) + "\n"
)

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

  local i="$TMP/${mutation}-identity.json"
  local r="$TMP/${mutation}-rbac.json"
  local e="$TMP/${mutation}-evidence.json"

  make_fixture "$i" "$r" "$e" "$mutation"

  echo
  echo "TEST: $description"

  if python3 \
       "$VALIDATOR" \
       "$i" \
       "$r" \
       "$e" \
       >/dev/null 2>&1
  then
    echo "FAIL: emergency validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: emergency validator rejected forbidden fixture."
}

expect_reject \
  "wrong-logical-ids" \
  "RBAC emergency logical IDs drift from identity foundation"

echo
echo "TEST: base RBAC validator rejects legacy emergency IDs"

TMP_I="$TMP/base-identity.json"
TMP_R="$TMP/base-rbac.json"
TMP_E="$TMP/base-evidence.json"

make_fixture \
  "$TMP_I" \
  "$TMP_R" \
  "$TMP_E" \
  "wrong-logical-ids"

if python3 \
     "$BASE_VALIDATOR" \
     "$TMP_R" \
     >/dev/null 2>&1
then
  echo "FAIL: base RBAC validator accepted legacy emergency IDs."
  exit 1
fi

echo "PASS: base RBAC validator rejects legacy emergency IDs."

expect_reject \
  "identity-not-cloud-only" \
  "Emergency identity loses cloud-only property"

expect_reject \
  "enabled-too-early" \
  "Emergency identity enabled before controlled onboarding"

expect_reject \
  "premature-role" \
  "Emergency identity has premature directory role"

expect_reject \
  "unexpected-group" \
  "Emergency identity joins an ordinary group"

expect_reject \
  "unexpected-license" \
  "Emergency identity receives a license"

expect_reject \
  "premature-auth" \
  "Emergency strong authentication marked before onboarding"

expect_reject \
  "wrong-target-role" \
  "Emergency target role changed from Global Administrator"

expect_reject \
  "eligible-pim" \
  "Emergency recovery path depends on eligible PIM activation"

expect_reject \
  "routine-use" \
  "Emergency identity becomes routine-use account"

expect_reject \
  "bootstrap-reduction" \
  "Bootstrap reduction authorized before emergency path exists"

echo
echo "=================================================="
echo "ALL FEATURE 5D1 EMERGENCY-ACCESS TESTS PASSED"
echo "=================================================="
