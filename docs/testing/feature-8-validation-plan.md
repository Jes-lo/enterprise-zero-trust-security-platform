# Feature 8 — Validation Plan

## Repository validation

Validate that:

- no additional license is required;
- the pilot group is `PLAB-Device-Pilot`;
- broad assignment is prohibited;
- Windows compliance requires the selected security controls;
- Defender security controls are declared;
- CA-006 is Report-only;
- CA-006 requires device compliance;
- destructive device operations are prohibited;
- existing Conditional Access controls are not modified.

## Tenant policy validation

After tenant implementation, verify:

- `PLAB-Device-Pilot` exists;
- its initial membership is zero;
- one Windows compliance policy exists for the pilot;
- one Defender endpoint baseline exists for the pilot;
- assignments are limited to `PLAB-Device-Pilot`;
- CA-006 exists in Report-only;
- CA-006 targets the pilot group;
- no Feature 8 policy is broadly assigned.

## Endpoint validation

When a dedicated test endpoint is available:

1. Enroll exactly one pilot Windows endpoint.
2. Confirm Intune inventory.
3. Confirm compliance policy evaluation.
4. Confirm BitLocker/Secure Boot/code-integrity evaluation.
5. Confirm Firewall and Defender health evaluation.
6. Confirm Defender endpoint visibility where available.
7. Confirm CA-006 remains Report-only.
8. Record only sanitized evidence.

## Adversarial validation

Repository tests must detect:

- CA-006 changed from Report-only to enabled;
- broad all-user assignment;
- destructive device action authorization;
- weakened compliance requirements.

## Completion

Feature 8 is complete when its implemented state is represented accurately.

A missing physical/virtual test endpoint may be documented as
environment-deferred, but tenant-side controls must not be falsely represented
as endpoint-validated.
