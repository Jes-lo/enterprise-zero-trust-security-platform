#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

architecture="docs/architecture/feature-8-endpoint-security-compliance.md"
adr="docs/decisions/adr-008-endpoint-pilot-isolation.md"
guardrails="docs/security/feature-8-endpoint-guardrails.md"
plan="docs/testing/feature-8-validation-plan.md"
compliance="policies/endpoint/windows-compliance-baseline.yaml"
defender="policies/endpoint/windows-defender-baseline.yaml"
ca="policies/access/ca-006-require-compliant-device-report-only.yaml"

required=(
  "$architecture"
  "$adr"
  "$guardrails"
  "$plan"
  "$compliance"
  "$defender"
  "$ca"
)

for path in "${required[@]}"; do
  [[ -s "$path" ]] || {
    echo "FAIL: missing or empty $path"
    exit 1
  }
done

grep -Fq \
  "implementation_state: tenant_pending" \
  "$compliance"

grep -Fq \
  "group_alias: PLAB-Device-Pilot" \
  "$compliance"

grep -Fq \
  "initial_membership_count: 0" \
  "$compliance"

grep -Fq \
  "broad_assignment_allowed: false" \
  "$compliance"

grep -Fq \
  "require_bitlocker: true" \
  "$compliance"

grep -Fq \
  "require_secure_boot: true" \
  "$compliance"

grep -Fq \
  "require_code_integrity: true" \
  "$compliance"

grep -Fq \
  "require_tpm: true" \
  "$compliance"

grep -Fq \
  "require_firewall: true" \
  "$compliance"

grep -Fq \
  "require_antivirus: true" \
  "$compliance"

grep -Fq \
  "require_antispyware: true" \
  "$compliance"

grep -Fq \
  "require_microsoft_defender_antimalware: true" \
  "$compliance"

grep -Fq \
  "require_security_intelligence_up_to_date: true" \
  "$compliance"

grep -Fq \
  "require_real_time_protection: true" \
  "$compliance"

grep -Fq \
  "mark_noncompliant_after_days: 1" \
  "$compliance"

grep -Fq \
  "destructive_action_authorized: false" \
  "$compliance"

grep -Fq \
  "implementation_state: tenant_pending" \
  "$defender"

grep -Fq \
  "real_time_protection: enabled" \
  "$defender"

grep -Fq \
  "cloud_delivered_protection: enabled" \
  "$defender"

grep -Fq \
  "behavior_monitoring: enabled" \
  "$defender"

grep -Fq \
  "potentially_unwanted_applications: block" \
  "$defender"

grep -Fq \
  "broad_assignment_authorized: false" \
  "$defender"

grep -Fq \
  "name: PLAB-CA-006 - Require compliant device" \
  "$ca"

grep -Fq \
  "state: report-only" \
  "$ca"

grep -Fq \
  -- "- PLAB-Device-Pilot" \
  "$ca"

grep -Fq \
  -- "- require_compliant_device" \
  "$ca"

grep -Fq \
  "enforcement_authorized: false" \
  "$ca"

if grep -RniE \
  'additional_license_acquisition:[[:space:]]*true|assign_to_all_users:[[:space:]]*true|assign_to_all_devices:[[:space:]]*true|broad_assignment_authorized:[[:space:]]*true|destructive_action_authorized:[[:space:]]*true|device_wipe_authorized:[[:space:]]*true|device_retire_authorized:[[:space:]]*true|autopilot_reset_authorized:[[:space:]]*true|enforcement_authorized:[[:space:]]*true|state:[[:space:]]*enabled' \
  "$compliance" \
  "$defender" \
  "$ca"
then
  echo "FAIL: prohibited Feature 8 state detected."
  exit 1
fi

set +e

grep -RniE \
  -- \
  '-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----|Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' \
  "${required[@]}"

scan_rc=$?

set -e

case "$scan_rc" in
  0)
    echo "FAIL: credential material detected."
    exit 1
    ;;
  1)
    echo "PASS: no credential/private-key material detected."
    ;;
  *)
    echo "FAIL: credential scan failed unexpectedly."
    exit 1
    ;;
esac

echo "FEATURE_8_VALIDATION=PASS"
echo "FEATURE_8_IMPLEMENTATION_STATE=TENANT_PENDING"
echo "PILOT_ISOLATION=PASS"
echo "WINDOWS_COMPLIANCE_BASELINE=PASS"
echo "DEFENDER_BASELINE=PASS"
echo "CA006_REPORT_ONLY=PASS"
echo "ADDITIONAL_LICENSES_REQUIRED=NO"
