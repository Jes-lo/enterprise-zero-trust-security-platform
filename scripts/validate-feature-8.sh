#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

architecture="docs/architecture/feature-8-endpoint-security-compliance.md"
adr="docs/decisions/adr-008-endpoint-pilot-isolation.md"
guardrails="docs/security/feature-8-endpoint-guardrails.md"
plan="docs/testing/feature-8-validation-plan.md"
evidence="docs/evidence/feature-8-phase-a-validation.md"

compliance="${FEATURE8_COMPLIANCE_FILE:-policies/endpoint/windows-compliance-baseline.yaml}"
defender="${FEATURE8_DEFENDER_FILE:-policies/endpoint/windows-defender-baseline.yaml}"
ca="${FEATURE8_CA_FILE:-policies/access/ca-006-require-compliant-device-report-only.yaml}"

required=(
  "$architecture"
  "$adr"
  "$guardrails"
  "$plan"
  "$evidence"
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

require_literal() {
  local file="$1"
  local value="$2"

  grep -Fq -- "$value" "$file" || {
    echo "FAIL: expected state missing from $file"
    echo "EXPECTED: $value"
    exit 1
  }
}

echo "===== FEATURE 8 FINAL STATE VALIDATION ====="

require_literal "$compliance" \
  "implementation_state: tenant_implemented_validated"

require_literal "$compliance" \
  "group_alias: PLAB-Device-Pilot"

require_literal "$compliance" \
  "validated_group_count: 1"

require_literal "$compliance" \
  "validated_membership_count: 0"

require_literal "$compliance" \
  "broad_assignment_allowed: false"

require_literal "$compliance" \
  "policy_count: 1"

require_literal "$compliance" \
  "assignment_count: 1"

require_literal "$compliance" \
  "default_scope_tag_validated: true"

require_literal "$compliance" \
  "require_bitlocker: true"

require_literal "$compliance" \
  "require_secure_boot: true"

require_literal "$compliance" \
  "require_code_integrity: true"

require_literal "$compliance" \
  "require_tpm: true"

require_literal "$compliance" \
  "require_firewall: true"

require_literal "$compliance" \
  "require_antivirus: true"

require_literal "$compliance" \
  "require_antispyware: true"

require_literal "$compliance" \
  "require_microsoft_defender_antimalware: true"

require_literal "$compliance" \
  "require_security_intelligence_up_to_date: true"

require_literal "$compliance" \
  "require_real_time_protection: true"

require_literal "$compliance" \
  "scheduled_rule_count: 1"

require_literal "$compliance" \
  "scheduled_action_count: 1"

require_literal "$compliance" \
  "action: block"

require_literal "$compliance" \
  "grace_period_hours: 24"

require_literal "$compliance" \
  "state: environment_deferred"

require_literal "$compliance" \
  "assign_to_all_users: false"

require_literal "$compliance" \
  "assign_to_all_devices: false"

require_literal "$defender" \
  "implementation_state: tenant_implemented_validated"

require_literal "$defender" \
  "antivirus_policy_count: 1"

require_literal "$defender" \
  "antivirus_setting_count: 6"

require_literal "$defender" \
  "tamper_policy_count: 1"

require_literal "$defender" \
  "tamper_setting_count: 1"

require_literal "$defender" \
  "edr_policy_count: 0"

require_literal "$defender" \
  "behavior_monitoring: enabled"

require_literal "$defender" \
  "cloud_delivered_protection: enabled"

require_literal "$defender" \
  "real_time_protection: enabled"

require_literal "$defender" \
  "potentially_unwanted_applications: block"

require_literal "$defender" \
  "network_protection: block"

require_literal "$defender" \
  "security_intelligence_update_interval_hours: 4"

require_literal "$defender" \
  "tamper_protection: on"

require_literal "$defender" \
  "controlled_configuration: not_selected"

require_literal "$defender" \
  "implementation_state: connector_deferred"

require_literal "$defender" \
  "mde_connector_count: 0"

require_literal "$defender" \
  "policy_created: false"

require_literal "$defender" \
  "state: environment_deferred"

require_literal "$defender" \
  "device_wipe_authorized: false"

require_literal "$defender" \
  "device_retire_authorized: false"

require_literal "$defender" \
  "autopilot_reset_authorized: false"

require_literal "$defender" \
  "broad_assignment_authorized: false"

require_literal "$ca" \
  "implementation_state: tenant_implemented_validated"

require_literal "$ca" \
  "name: PLAB-CA-006 - Require compliant device"

require_literal "$ca" \
  "state: report-only"

require_literal "$ca" \
  "policy_count: 1"

require_literal "$ca" \
  "report_only_validated: true"

require_literal "$ca" \
  "pilot_target_only_validated: true"

require_literal "$ca" \
  "all_resources_validated: true"

require_literal "$ca" \
  "compliant_device_grant_validated: true"

require_literal "$ca" \
  "validated_pilot_membership_count: 0"

require_literal "$ca" \
  "scope: all_resources"

require_literal "$ca" \
  "require_compliant_device"

require_literal "$ca" \
  "enforcement_authorized: false"

require_literal "$evidence" \
  "FEATURE8_TENANT_RECONCILIATION=PHASE_A_PRESENT_AND_VALID"

require_literal "$evidence" \
  "setting count: 6"

require_literal "$evidence" \
  "network protection: block"

require_literal "$evidence" \
  "security intelligence update interval: 4 hours"

require_literal "$evidence" \
  "Controlled Configuration selected: no"

require_literal "$evidence" \
  "status: connector-deferred"

require_literal "$evidence" \
  "environment-deferred"

require_literal "$guardrails" \
  "The controlled Feature 8 writer must not be rerun"

require_literal "$plan" \
  "Endpoint execution remains \`environment-deferred\`"

if grep -RniE \
  'additional_license_acquisition:[[:space:]]*true|assign_to_all_users:[[:space:]]*true|assign_to_all_devices:[[:space:]]*true|broad_assignment_authorized:[[:space:]]*true|destructive_action_authorized:[[:space:]]*true|destructive_remediation_authorized:[[:space:]]*true|device_wipe_authorized:[[:space:]]*true|device_retire_authorized:[[:space:]]*true|autopilot_reset_authorized:[[:space:]]*true|enforcement_authorized:[[:space:]]*true|^state:[[:space:]]*enabled$' \
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
  '-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----|Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' \
  "${required[@]}"

scan_rc=$?

set -e

case "$scan_rc" in
  0)
    echo "FAIL: sensitive or tenant-specific material detected."
    exit 1
    ;;
  1)
    echo "PASS: no credential, UPN or GUID material detected."
    ;;
  *)
    echo "FAIL: sensitive-material scan failed unexpectedly."
    exit 1
    ;;
esac

echo "FEATURE_8_VALIDATION=PASS"
echo "FEATURE_8_IMPLEMENTATION_STATE=TENANT_IMPLEMENTED_VALIDATED"
echo "PILOT_ISOLATION=PASS"
echo "PILOT_MEMBERSHIP_COUNT=0"
echo "WINDOWS_COMPLIANCE_BASELINE=PASS"
echo "COMPLIANCE_BLOCK_GRACE_HOURS=24"
echo "DEFENDER_BASELINE=PASS"
echo "DEFENDER_SETTING_COUNT=6"
echo "NETWORK_PROTECTION=BLOCK"
echo "SIGNATURE_UPDATE_INTERVAL_HOURS=4"
echo "TAMPER_PROTECTION=TAMPER_PROTECTION_ON"
echo "CONTROLLED_CONFIGURATION=NOT_SELECTED"
echo "CA006_REPORT_ONLY=PASS"
echo "EDR_STATE=CONNECTOR_DEFERRED"
echo "ENDPOINT_VALIDATION=ENVIRONMENT_DEFERRED"
echo "ADDITIONAL_LICENSES_REQUIRED=NO"
echo "FEATURE8_WRITER_RERUN_ALLOWED=NO"
