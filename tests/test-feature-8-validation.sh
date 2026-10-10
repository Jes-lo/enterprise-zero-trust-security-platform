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

expect_rejected() {
  local label="$1"
  shift

  if "$@" >"$TMP/${label}.out" 2>&1; then
    echo "FAIL: validator accepted adversarial fixture: $label"
    cat "$TMP/${label}.out"
    exit 1
  fi

  echo "PASS: validator rejected adversarial fixture: $label"
}

cp \
  policies/access/ca-006-require-compliant-device-report-only.yaml \
  "$TMP/ca.yaml"

sed \
  's/state: report-only/state: enabled/' \
  "$TMP/ca.yaml" \
  > "$TMP/ca-enabled.yaml"

grep -Fq \
  'state: enabled' \
  "$TMP/ca-enabled.yaml"

expect_rejected \
  "ca-enforcement" \
  env FEATURE8_CA_FILE="$TMP/ca-enabled.yaml" \
  ./scripts/validate-feature-8.sh

cp \
  policies/endpoint/windows-compliance-baseline.yaml \
  "$TMP/compliance.yaml"

sed \
  's/assign_to_all_users: false/assign_to_all_users: true/' \
  "$TMP/compliance.yaml" \
  > "$TMP/compliance-broad.yaml"

grep -Fq \
  'assign_to_all_users: true' \
  "$TMP/compliance-broad.yaml"

expect_rejected \
  "broad-assignment" \
  env FEATURE8_COMPLIANCE_FILE="$TMP/compliance-broad.yaml" \
  ./scripts/validate-feature-8.sh

sed \
  's/require_bitlocker: true/require_bitlocker: false/' \
  "$TMP/compliance.yaml" \
  > "$TMP/compliance-weakened.yaml"

grep -Fq \
  'require_bitlocker: false' \
  "$TMP/compliance-weakened.yaml"

expect_rejected \
  "weakened-compliance" \
  env FEATURE8_COMPLIANCE_FILE="$TMP/compliance-weakened.yaml" \
  ./scripts/validate-feature-8.sh

sed \
  's/validated_membership_count: 0/validated_membership_count: 1/' \
  "$TMP/compliance.yaml" \
  > "$TMP/compliance-member.yaml"

grep -Fq \
  'validated_membership_count: 1' \
  "$TMP/compliance-member.yaml"

expect_rejected \
  "nonempty-pilot" \
  env FEATURE8_COMPLIANCE_FILE="$TMP/compliance-member.yaml" \
  ./scripts/validate-feature-8.sh

sed \
  's/implementation_state: tenant_implemented_validated/implementation_state: tenant_pending/' \
  "$TMP/compliance.yaml" \
  > "$TMP/compliance-pending.yaml"

grep -Fq \
  'implementation_state: tenant_pending' \
  "$TMP/compliance-pending.yaml"

expect_rejected \
  "implementation-regression" \
  env FEATURE8_COMPLIANCE_FILE="$TMP/compliance-pending.yaml" \
  ./scripts/validate-feature-8.sh

cp \
  policies/endpoint/windows-defender-baseline.yaml \
  "$TMP/defender.yaml"

sed \
  's/device_wipe_authorized: false/device_wipe_authorized: true/' \
  "$TMP/defender.yaml" \
  > "$TMP/defender-destructive.yaml"

grep -Fq \
  'device_wipe_authorized: true' \
  "$TMP/defender-destructive.yaml"

expect_rejected \
  "destructive-device-action" \
  env FEATURE8_DEFENDER_FILE="$TMP/defender-destructive.yaml" \
  ./scripts/validate-feature-8.sh

sed \
  's/network_protection: block/network_protection: enabled/' \
  "$TMP/defender.yaml" \
  > "$TMP/defender-network.yaml"

grep -Fq \
  'network_protection: enabled' \
  "$TMP/defender-network.yaml"

expect_rejected \
  "network-not-block" \
  env FEATURE8_DEFENDER_FILE="$TMP/defender-network.yaml" \
  ./scripts/validate-feature-8.sh

sed \
  's/security_intelligence_update_interval_hours: 4/security_intelligence_update_interval_hours: 24/' \
  "$TMP/defender.yaml" \
  > "$TMP/defender-signature.yaml"

grep -Fq \
  'security_intelligence_update_interval_hours: 24' \
  "$TMP/defender-signature.yaml"

expect_rejected \
  "signature-interval-drift" \
  env FEATURE8_DEFENDER_FILE="$TMP/defender-signature.yaml" \
  ./scripts/validate-feature-8.sh

sed \
  's/controlled_configuration: not_selected/controlled_configuration: on/' \
  "$TMP/defender.yaml" \
  > "$TMP/defender-controlled-config.yaml"

grep -Fq \
  'controlled_configuration: on' \
  "$TMP/defender-controlled-config.yaml"

expect_rejected \
  "controlled-configuration-selected" \
  env FEATURE8_DEFENDER_FILE="$TMP/defender-controlled-config.yaml" \
  ./scripts/validate-feature-8.sh

sed \
  's/policy_created: false/policy_created: true/' \
  "$TMP/defender.yaml" \
  > "$TMP/defender-false-edr.yaml"

grep -Fq \
  'policy_created: true' \
  "$TMP/defender-false-edr.yaml"

expect_rejected \
  "false-edr-completion" \
  env FEATURE8_DEFENDER_FILE="$TMP/defender-false-edr.yaml" \
  ./scripts/validate-feature-8.sh

echo
echo "FEATURE_8_ADVERSARIAL_TESTS=PASS"
