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
- EDR remains connector-deferred while its prerequisite connector is absent;
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
- EDR policy count: zero;
- prerequisite connector count: zero.

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
- EDR falsely represented as created;
- nonzero pilot membership in the repository state.

## Completion

Feature 8 Phase A is complete when:

- tenant-side controls are accurately represented;
- exact Defender and Tamper values are validated;
- CA-006 remains Report-only;
- pilot membership remains zero;
- EDR and endpoint limitations are explicitly deferred;
- repository/adversarial/security validation passes.

Phase A completion does not equal endpoint-enforcement completion.
