# ADR-008 — Endpoint Pilot Isolation Strategy

## Status

Accepted for Feature 8.

## Context

Endpoint management can change device configuration and can affect access to
Microsoft 365 resources.

The project therefore requires a controlled deployment model that demonstrates
Intune and Defender without unintentionally managing or blocking unrelated
devices.

## Decision

Feature 8 uses a dedicated security group:

`PLAB-Device-Pilot`

The group starts empty.

Windows compliance, Defender configuration and device-based Conditional Access
are scoped only to this pilot population during validation.

CA-006 remains Report-only.

No policy is initially assigned to all users or all devices.

## Pilot endpoint

A dedicated lab endpoint is preferred.

A primary personal workstation is not automatically enrolled for portfolio
purposes.

If no suitable endpoint is available, the project can still validate the
tenant-side policy architecture and record device enrollment as
environment-deferred rather than misrepresenting it as completed.

## Rationale

This approach limits blast radius while preserving a realistic Zero Trust
design:

- identity establishes who is requesting access;
- Intune establishes device compliance;
- Defender establishes endpoint protection posture;
- Conditional Access consumes the compliance signal.

## Consequences

Enforcement is deliberately separated from policy creation.

A successful Feature 8 implementation does not require broad production-style
rollout.
