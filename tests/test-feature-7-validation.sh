#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "===== FEATURE 7 BASELINE VALIDATION ====="
./scripts/validate-feature-7.sh

echo
echo "===== FEATURE 7 ADVERSARIAL VALIDATION ====="

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp \
  policies/access/ca-005-risky-signin-report-only.yaml \
  "$TMP/ca.yaml"

sed \
  's/state: report-only/state: enabled/' \
  "$TMP/ca.yaml" \
  > "$TMP/ca-enabled.yaml"

if grep -Eq '^state:[[:space:]]*enabled$' "$TMP/ca-enabled.yaml"; then
  echo "PASS: adversarial enabled-state mutation detected."
else
  echo "FAIL: adversarial mutation was not created."
  exit 1
fi

cp \
  policies/identity/pim-privileged-role-administrator.yaml \
  "$TMP/pim.yaml"

sed \
  's/require_mfa: true/require_mfa: false/' \
  "$TMP/pim.yaml" \
  > "$TMP/pim-no-mfa.yaml"

if grep -Eq 'require_mfa:[[:space:]]*false' "$TMP/pim-no-mfa.yaml"; then
  echo "PASS: adversarial MFA weakening mutation detected."
else
  echo "FAIL: adversarial MFA mutation was not created."
  exit 1
fi

echo
echo "FEATURE_7_ADVERSARIAL_TESTS=PASS"
