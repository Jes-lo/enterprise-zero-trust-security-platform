#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

architecture="docs/architecture/feature-7-privileged-identity-governance.md"
adr="docs/decisions/adr-007-pim-governance-strategy.md"
cleanup="docs/security/feature-7-license-trial-cleanup.md"
plan="docs/testing/feature-7-validation-plan.md"
evidence="docs/evidence/feature-7-license-deferred-closure.md"
pim="policies/identity/pim-privileged-role-administrator.yaml"
risk="policies/access/ca-005-risky-signin-report-only.yaml"

required=(
  "$architecture"
  "$adr"
  "$cleanup"
  "$plan"
  "$evidence"
  "$pim"
  "$risk"
)

for path in "${required[@]}"; do
  [[ -s "$path" ]] || {
    echo "FAIL: missing or empty $path"
    exit 1
  }
done

grep -Fq \
  "implementation_state: license_deferred_not_implemented" \
  "$pim"

grep -Fq \
  "additional_license_acquisition: false" \
  "$pim"

grep -Fq \
  "microsoft_entra_id_p2_acquired: false" \
  "$pim"

grep -Fq \
  "eligible_assignment_created: false" \
  "$pim"

grep -Fq \
  "activation_performed: false" \
  "$pim"

grep -Fq \
  "require_mfa: true" \
  "$pim"

grep -Fq \
  "require_justification: true" \
  "$pim"

grep -Fq \
  "implementation_state: license_deferred_not_implemented" \
  "$risk"

grep -Fq \
  "additional_license_acquisition: false" \
  "$risk"

grep -Fq \
  "microsoft_entra_id_p2_acquired: false" \
  "$risk"

grep -Fq \
  "policy_created: false" \
  "$risk"

grep -Fq \
  "enforcement_enabled: false" \
  "$risk"

grep -Fq \
  "state: report-only" \
  "$risk"

grep -Fq \
  -- "- EMPLOYEE_01" \
  "$risk"

grep -Fq \
  -- "- EMERGENCY_ADMIN_01" \
  "$risk"

grep -Fq \
  -- "- EMERGENCY_ADMIN_02" \
  "$risk"

grep -Fq \
  "validated-license-deferred-p1-baseline-preserved" \
  "$evidence"

if grep -RniE \
  'implementation_state:[[:space:]]*(implemented|enabled|active)|microsoft_entra_id_p2_acquired:[[:space:]]*true|additional_license_acquisition:[[:space:]]*true|eligible_assignment_created:[[:space:]]*true|activation_performed:[[:space:]]*true|policy_created:[[:space:]]*true|enforcement_enabled:[[:space:]]*true' \
  "$pim" \
  "$risk"
then
  echo "FAIL: unsupported P2 implementation claim detected."
  exit 1
fi

if grep -RniE \
  '-----BEGIN ((OPENSSH|RSA|EC|DSA) )?PRIVATE[[:space:]]+KEY-----|Bearer[[:space:]]+[A-Za-z0-9._-]{20,}' \
  "${required[@]}"
then
  echo "FAIL: credential material detected."
  exit 1
fi

echo "FEATURE_7_VALIDATION=PASS"
echo "FEATURE_7_IMPLEMENTATION_MODE=LICENSE_DEFERRED"
echo "P2_ACQUIRED=NO"
echo "PIM_IMPLEMENTED=NO"
echo "IDENTITY_RISK_POLICY_IMPLEMENTED=NO"
echo "P1_BASELINE_PRESERVED=YES"
echo "CREDENTIAL_MATERIAL_SCAN=PASS"
