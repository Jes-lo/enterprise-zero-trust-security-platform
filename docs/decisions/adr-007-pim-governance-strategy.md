# ADR-007 — Privileged Identity Governance Strategy

## Status

Accepted — license-deferred implementation.

## Context

The lab uses Microsoft Entra ID P1 through its existing Microsoft 365
subscription.

The project evaluated Privileged Identity Management and Identity Protection,
but completing those controls would require additional licensing outside the
selected project baseline.

## Decision

No Microsoft Entra ID P2 or Microsoft Entra ID Governance license will be
acquired for this project.

The PIM and identity-risk configurations remain independently designed
portfolio artifacts but are not represented as tenant implementations.

The operational tenant remains on its existing P1-compatible privileged access
model.

## Deferred PIM design

A future implementation would use:

- `PRIVILEGED_ADMIN_01`;
- Privileged Role Administrator;
- seven-day eligible assignment;
- one-hour maximum activation;
- MFA;
- justification;
- no artificial self-approval dependency.

No eligible assignment is created in this project.

## Deferred identity-risk design

A future P2-capable environment could deploy
`PLAB-CA-005 - Require MFA for risky sign-ins` in Report-only.

The policy is not created in the current tenant.

## Rationale

The project prioritizes an accurate, reproducible and cost-controlled
implementation over claiming controls that are unavailable under the selected
license.

License-aware architecture is itself part of the Zero Trust design: controls
must reflect the capabilities that actually exist.

## Consequences

Feature 7 demonstrates PIM and risk-governance architecture while clearly
separating desired state from implemented state.

The remaining project work uses capabilities already available in the current
Microsoft 365 Business Premium baseline.
