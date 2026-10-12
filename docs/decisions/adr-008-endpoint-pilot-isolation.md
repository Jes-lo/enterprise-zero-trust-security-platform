# ADR-008 — Endpoint Pilot Isolation Strategy

## Status

Accepted and validated for Feature 8 Phase A.

## Context

Endpoint-management controls can change device configuration and can influence
access to Microsoft 365 resources.

The project therefore needs a deployment boundary that demonstrates realistic
Intune, Defender and Conditional Access integration without broadly managing
unrelated devices or users.

## Decision

Feature 8 uses the dedicated security group:

`PLAB-Device-Pilot`

Tenant-side controls are scoped only to that pilot population.

The final Phase A audit validated that the group exists and contains zero
members.

CA-006 remains Report-only.

No Feature 8 policy is intentionally assigned to all users or all devices.

## Tenant-side implementation

The validated Phase A tenant state includes:

- one Windows compliance policy assigned to the pilot;
- one Defender Antivirus policy assigned to the pilot;
- one Tamper Protection policy assigned to the pilot;
- one CA-006 policy in Report-only;
- zero EDR onboarding policies at the original Phase A closure because the
  required connector was unavailable.

A later EDR follow-up preserved the same isolation decision: after the
connector became available, the EDR policy was created and its direct
assignment relationship was limited to `PLAB-Device-Pilot`, which remained
empty.

## Pilot endpoint

A dedicated lab endpoint remains the preferred validation target.

The primary personal workstation is not required for portfolio evidence.

Because no suitable dedicated endpoint has been introduced into the pilot,
device enrollment and endpoint telemetry remain `environment-deferred`.

## Rationale

This structure limits blast radius while preserving the intended Zero Trust
relationship:

- identity establishes who is requesting access;
- Intune defines device-compliance requirements;
- Defender defines endpoint-protection posture;
- Conditional Access consumes the compliance signal.

Configuration and enforcement are intentionally separated.

## Consequences

The empty pilot group means the tenant-side configuration can be validated
without applying the controls to a production or personal endpoint.

CA-006 must not be enabled merely to make the portfolio appear more complete.

EDR onboarding was initially `connector-deferred` rather than simulated or
misrepresented. The later tenant-side EDR configuration does not change the
endpoint-execution boundary: no device enrollment, endpoint telemetry or
enforcement result is claimed without a dedicated test endpoint.

The observed beta `isAssigned` inconsistency does not change the isolation
decision and does not authorize assignment retries.

A future dedicated pilot endpoint can be introduced without redesigning the
Feature 8 isolation model.
