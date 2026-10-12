# Feature 8 — Validation Plan

## Repository validation

The repository validator must confirm:

- no additional Microsoft license is required;
- Phase A is represented as tenant implemented and validated;
- the pilot group is `PLAB-Device-Pilot`;
- the validated pilot membership count is zero;
- broad assignment remains prohibited;
- Windows compliance security requirements remain enabled;
- noncompliance uses one block action with a 24-hour grace period;
- Defender Antivirus contains exactly six validated settings;
- network protection is block;
- the security intelligence update interval is 4 hours;
- Tamper Protection is On;
- Controlled Configuration is not selected;
- CA-006 remains Report-only;
- CA-006 requires a compliant device;
- destructive device operations remain prohibited;
- historical Phase A evidence preserves the original connector-deferred EDR
  state;
- current EDR state records one enabled connector, one policy, two settings and
  one pilot-only assignment relationship;
- EDR broad assignment remains prohibited;
- EDR assignment and rollback retries remain prohibited;
- the observed beta `isAssigned` inconsistency is documented without being
  treated as a reason to rewrite tenant state;
- endpoint execution remains environment-deferred;
- evidence contains no tenant-specific identifiers or credentials.

## Completed tenant validation

The final Phase A reconciliation used Microsoft Graph GET operations only.

Validated results:

- `PLAB-Device-Pilot`: exactly one group;
- pilot membership: zero;
- Windows compliance policy count: one;
- compliance assignment: pilot only;
- compliance required settings: pass;
- noncompliance rule count: one;
- noncompliance action count: one;
- action: block;
- grace period: 24 hours;
- Defender Antivirus policy count: one;
- Defender Antivirus setting count: six;
- Defender Antivirus assignment: pilot only;
- behavior monitoring: enabled;
- cloud protection: enabled;
- real-time protection: enabled;
- network protection: block;
- PUA protection: block;
- security intelligence update interval: 4 hours;
- Tamper Protection policy count: one;
- Tamper setting count: one;
- Tamper Protection: On;
- Controlled Configuration: not selected;
- CA-006 policy count: one;
- CA-006 state: Report-only;
- CA-006 target: pilot only;
- CA-006 resources: all resources;
- CA-006 grant: compliant device;
- original Phase A EDR policy count: zero;
- original Phase A prerequisite connector count: zero.

The later EDR follow-up additionally validated:

- prerequisite connector count: one;
- connector partner state: enabled;
- Windows connector state: enabled;
- EDR policy count: one;
- EDR setting count: two;
- direct policy assignment relationship count: one;
- assignment target: `PLAB-Device-Pilot`;
- assignment filter: none;
- All Devices assignment: absent;
- direct pilot membership: zero;
- transitive pilot membership: zero;
- policy `isAssigned` beta readback: false despite the populated direct
  assignments relationship;
- no authorization to repeat `/assign` or rollback.

## Endpoint validation

Endpoint execution remains `environment-deferred`.

When a dedicated test endpoint becomes available:

1. enroll exactly one authorized Windows lab endpoint;
2. add only the intended pilot identity/device;
3. confirm Intune inventory;
4. confirm compliance-policy evaluation;
5. confirm BitLocker, Secure Boot and code-integrity evaluation;
6. confirm Firewall and Defender health evaluation;
7. confirm Defender endpoint visibility where licensed and available;
8. confirm CA-006 remains Report-only;
9. record sanitized evidence only.

The current Feature 8 closure must not claim those endpoint observations as
completed.

## Adversarial validation

Tests must reject at least:

- CA-006 changed from Report-only to enabled;
- broad user assignment;
- weakened BitLocker compliance;
- destructive device action authorization;
- Defender network protection changed away from block;
- security intelligence interval changed away from 4 hours;
- Controlled Configuration selected;
- Phase A implementation regressed to tenant pending;
- EDR regressed to `connector_deferred` in the current policy model;
- EDR policy represented as absent;
- EDR assignment broadened beyond `PLAB-Device-Pilot`;
- EDR All Devices assignment enabled;
- EDR assignment retry authorized;
- EDR rollback retry authorized;
- nonzero pilot membership in the repository state;
- endpoint execution falsely represented as completed.

## Completion

Feature 8 Phase A is complete when:

- tenant-side controls are accurately represented;
- exact Defender and Tamper values are validated;
- CA-006 remains Report-only;
- pilot membership remains zero;
- historical Phase A EDR deferral remains accurately preserved;
- current EDR connector, policy and pilot relationship are accurately
  represented;
- beta assignment-status inconsistency is documented;
- endpoint execution remains explicitly `environment-deferred`;
- repository/adversarial/security validation passes.

Tenant-side EDR configuration completion does not equal endpoint-enforcement or
endpoint-telemetry completion.
