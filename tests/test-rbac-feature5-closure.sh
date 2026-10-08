#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.." &&
  pwd
)"

VALIDATOR="$ROOT/scripts/validate-rbac-feature5-closure.py"

RBAC="$ROOT/configs/rbac-privileged-administration.json"

ROLE="$ROOT/docs/evidence/rbac-privileged-admin-role-assignment-validation.json"

EMERGENCY="$ROOT/docs/evidence/rbac-emergency-access-deferred-validation.json"

CLOSURE="$ROOT/docs/evidence/rbac-feature5-closure-validation.json"

TMP="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP"
}

trap cleanup EXIT

python3 \
  "$VALIDATOR" \
  "$RBAC" \
  "$ROLE" \
  "$EMERGENCY" \
  "$CLOSURE"

make_fixture() {
  local rbac_out="$1"
  local role_out="$2"
  local emergency_out="$3"
  local closure_out="$4"
  local mutation="$5"

  python3 - \
    "$RBAC" \
    "$ROLE" \
    "$EMERGENCY" \
    "$CLOSURE" \
    "$rbac_out" \
    "$role_out" \
    "$emergency_out" \
    "$closure_out" \
    "$mutation" <<'PY'
import json
import sys
from pathlib import Path

rbac = json.loads(Path(sys.argv[1]).read_text())
role = json.loads(Path(sys.argv[2]).read_text())
emergency = json.loads(Path(sys.argv[3]).read_text())
closure = json.loads(Path(sys.argv[4]).read_text())

rbac_out = Path(sys.argv[5])
role_out = Path(sys.argv[6])
emergency_out = Path(sys.argv[7])
closure_out = Path(sys.argv[8])
mutation = sys.argv[9]

principal = rbac["principals"]["privileged_admin_01"]

if mutation == "global-admin":
    principal["current_directory_role"] = "Global Administrator"

elif mutation == "pim":
    principal["pim_configured"] = True

elif mutation == "security-defaults":
    role[
        "post_assignment_state"
    ][
        "security_defaults_enabled"
    ] = False

elif mutation == "ga-baseline":
    closure[
        "tenant_protected_baseline"
    ][
        "global_administrator_assignment_count"
    ] = 2

elif mutation == "emergency-enabled":
    closure[
        "emergency_access"
    ][
        "enabled_identity_count"
    ] = 1

elif mutation == "emergency-role":
    closure[
        "emergency_access"
    ][
        "directory_role_assignment_count"
    ] = 1

elif mutation == "future-implemented":
    emergency[
        "decision"
    ][
        "implemented_in_current_project"
    ] = True

elif mutation == "claims-breakglass":
    closure[
        "emergency_access"
    ][
        "live_recovery_path_operational"
    ] = True

elif mutation == "bootstrap-reduction":
    closure[
        "bootstrap_administrator"
    ][
        "privilege_reduction_permitted"
    ] = True

elif mutation == "ca-feature":
    closure[
        "feature_boundaries"
    ][
        "conditional_access_owner_feature"
    ] = 5

elif mutation == "privacy":
    closure[
        "privacy"
    ][
        "password_present"
    ] = True

else:
    raise SystemExit("unknown mutation")


rbac_out.write_text(
    json.dumps(rbac, indent=2) + "\n"
)

role_out.write_text(
    json.dumps(role, indent=2) + "\n"
)

emergency_out.write_text(
    json.dumps(emergency, indent=2) + "\n"
)

closure_out.write_text(
    json.dumps(closure, indent=2) + "\n"
)
PY
}

expect_reject() {
  local mutation="$1"
  local description="$2"

  local r="$TMP/${mutation}-rbac.json"
  local p="$TMP/${mutation}-role.json"
  local e="$TMP/${mutation}-emergency.json"
  local c="$TMP/${mutation}-closure.json"

  make_fixture \
    "$r" \
    "$p" \
    "$e" \
    "$c" \
    "$mutation"

  echo
  echo "TEST: $description"

  if python3 \
       "$VALIDATOR" \
       "$r" \
       "$p" \
       "$e" \
       "$c" \
       >/dev/null 2>&1
  then
    echo "FAIL: closure validator accepted forbidden fixture."
    exit 1
  fi

  echo "PASS: closure validator rejected forbidden fixture."
}

expect_reject \
  "global-admin" \
  "Dedicated privileged administrator becomes Global Administrator"

expect_reject \
  "pim" \
  "PIM incorrectly configured during Feature 5"

expect_reject \
  "security-defaults" \
  "Security Defaults disabled"

expect_reject \
  "ga-baseline" \
  "Global Administrator baseline changed"

expect_reject \
  "emergency-enabled" \
  "Deferred emergency identity becomes enabled"

expect_reject \
  "emergency-role" \
  "Deferred emergency identity receives a role"

expect_reject \
  "future-implemented" \
  "Future FIDO2/passkey option marked implemented"

expect_reject \
  "claims-breakglass" \
  "Project falsely claims operational break-glass recovery"

expect_reject \
  "bootstrap-reduction" \
  "Bootstrap reduction allowed without emergency recovery path"

expect_reject \
  "ca-feature" \
  "Conditional Access incorrectly moved into Feature 5"

expect_reject \
  "privacy" \
  "Closure evidence claims password material is present"

echo
echo "=================================================="
echo "ALL FEATURE 5 CLOSURE ADVERSARIAL TESTS PASSED"
echo "=================================================="
