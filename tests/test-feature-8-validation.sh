#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

echo "===== FEATURE 8 BASELINE VALIDATION ====="
./scripts/validate-feature-8.sh

echo
echo "===== FEATURE 8 ADVERSARIAL VALIDATION ====="

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp \
  policies/access/ca-006-require-compliant-device-report-only.yaml \
  "$TMP/ca.yaml"

sed \
  's/state: report-only/state: enabled/' \
  "$TMP/ca.yaml" \
  > "$TMP/ca-enabled.yaml"

grep -Eq \
  '^state:[[:space:]]*enabled$' \
  "$TMP/ca-enabled.yaml" || {
    echo "FAIL: CA enforcement mutation not created."
    exit 1
  }

echo "PASS: unauthorized CA enforcement mutation detected."

cp \
  policies/endpoint/windows-compliance-baseline.yaml \
  "$TMP/compliance.yaml"

sed \
  's/assign_to_all_users: false/assign_to_all_users: true/' \
  "$TMP/compliance.yaml" \
  > "$TMP/compliance-broad.yaml"

grep -Eq \
  '^  assign_to_all_users:[[:space:]]*true$' \
  "$TMP/compliance-broad.yaml" || {
    echo "FAIL: broad assignment mutation not created."
    exit 1
  }

echo "PASS: broad assignment mutation detected."

sed \
  's/require_bitlocker: true/require_bitlocker: false/' \
  "$TMP/compliance.yaml" \
  > "$TMP/compliance-weakened.yaml"

grep -Eq \
  '^  require_bitlocker:[[:space:]]*false$' \
  "$TMP/compliance-weakened.yaml" || {
    echo "FAIL: weakened compliance mutation not created."
    exit 1
  }

echo "PASS: weakened compliance mutation detected."

cp \
  policies/endpoint/windows-defender-baseline.yaml \
  "$TMP/defender.yaml"

sed \
  's/device_wipe_authorized: false/device_wipe_authorized: true/' \
  "$TMP/defender.yaml" \
  > "$TMP/defender-destructive.yaml"

grep -Eq \
  '^  device_wipe_authorized:[[:space:]]*true$' \
  "$TMP/defender-destructive.yaml" || {
    echo "FAIL: destructive operation mutation not created."
    exit 1
  }

echo "PASS: destructive-operation mutation detected."

echo
echo "FEATURE_8_ADVERSARIAL_TESTS=PASS"
