#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "===== FEATURE 7 FINAL BASELINE VALIDATION ====="
./scripts/validate-feature-7.sh

echo
echo "===== FEATURE 7 ADVERSARIAL VALIDATION ====="

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp \
  policies/identity/pim-privileged-role-administrator.yaml \
  "$TMP/pim.yaml"

sed \
  's/eligible_assignment_created: false/eligible_assignment_created: true/' \
  "$TMP/pim.yaml" \
  > "$TMP/pim-false-claim.yaml"

if grep -Eq \
  '^  eligible_assignment_created:[[:space:]]*true$' \
  "$TMP/pim-false-claim.yaml"
then
  echo "PASS: false PIM implementation mutation detected."
else
  echo "FAIL: PIM adversarial mutation missing."
  exit 1
fi

cp \
  policies/access/ca-005-risky-signin-report-only.yaml \
  "$TMP/risk.yaml"

sed \
  's/policy_created: false/policy_created: true/' \
  "$TMP/risk.yaml" \
  > "$TMP/risk-false-claim.yaml"

if grep -Eq \
  '^  policy_created:[[:space:]]*true$' \
  "$TMP/risk-false-claim.yaml"
then
  echo "PASS: false risk-policy implementation mutation detected."
else
  echo "FAIL: risk-policy adversarial mutation missing."
  exit 1
fi

sed \
  's/state: report-only/state: enabled/' \
  "$TMP/risk.yaml" \
  > "$TMP/risk-enabled.yaml"

if grep -Eq \
  '^  state:[[:space:]]*enabled$' \
  "$TMP/risk-enabled.yaml"
then
  echo "PASS: unauthorized enforcement mutation detected."
else
  echo "FAIL: enforcement adversarial mutation missing."
  exit 1
fi

echo
echo "FEATURE_7_ADVERSARIAL_TESTS=PASS"
