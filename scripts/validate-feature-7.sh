#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

required=(
  "docs/architecture/feature-7-privileged-identity-governance.md"
  "docs/decisions/adr-007-pim-governance-strategy.md"
  "docs/security/feature-7-license-trial-cleanup.md"
  "docs/testing/feature-7-validation-plan.md"
  "policies/identity/pim-privileged-role-administrator.yaml"
  "policies/access/ca-005-risky-signin-report-only.yaml"
)

for path in "${required[@]}"; do
  [[ -s "$path" ]] || {
    echo "FAIL: missing or empty $path"
    exit 1
  }
done

pim="policies/identity/pim-privileged-role-administrator.yaml"
risk="policies/access/ca-005-risky-signin-report-only.yaml"
cleanup="docs/security/feature-7-license-trial-cleanup.md"

grep -Fq "identity_alias: PRIVILEGED_ADMIN_01" "$pim"
grep -Fq "role: Privileged Role Administrator" "$pim"
grep -Fq "duration_days: 7" "$pim"
grep -Fq "maximum_duration_hours: 1" "$pim"
grep -Fq "require_mfa: true" "$pim"
grep -Fq "require_justification: true" "$pim"
grep -Fq "require_approval: false" "$pim"
grep -Fq "restore_p1_compatible_pra_before_p2_expiration: true" "$pim"

grep -Fq "name: PLAB-CA-005 - Require MFA for risky sign-ins" "$risk"
grep -Fq "state: report-only" "$risk"
grep -Fq -- "- EMPLOYEE_01" "$risk"
grep -Fq -- "- EMERGENCY_ADMIN_01" "$risk"
grep -Fq -- "- EMERGENCY_ADMIN_02" "$risk"
grep -Fq -- "- medium" "$risk"
grep -Fq -- "- high" "$risk"
grep -Fq "enforcement_authorized: false" "$risk"

grep -Fq "Reset the exposed temporary password" "$cleanup"
grep -Fq "Revoke sessions for" "$cleanup"

if grep -RniE \
  --exclude="validate-feature-7.sh" \
  --exclude="test-feature-7-validation.sh" \
  'client[_ -]?secret|BEGIN .*PRIVATE KEY|access[_ -]?token|password[[:space:]]*:' \
  "${required[@]}" \
  policies/identity/pim-privileged-role-administrator.yaml \
  policies/access/ca-005-risky-signin-report-only.yaml
then
  echo "FAIL: possible credential material detected."
  exit 1
fi

if grep -RniE \
  'ReadWrite|state:[[:space:]]*enabled|enforcement_authorized:[[:space:]]*true' \
  "$pim" \
  "$risk"
then
  echo "FAIL: prohibited Feature 7 enforcement/write declaration detected."
  exit 1
fi

echo "FEATURE_7_VALIDATION=PASS"
echo "PIM_PILOT_SCOPE=PASS"
echo "IDENTITY_RISK_POLICY_REPORT_ONLY=PASS"
echo "TRIAL_CLEANUP_GUARDRAILS=PASS"
echo "CREDENTIAL_MATERIAL_SCAN=PASS"
