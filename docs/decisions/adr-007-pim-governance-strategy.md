# ADR-007 — Privileged Identity Governance Strategy

## Status

Accepted for Feature 7 implementation.

## Context

The lab currently has a dedicated Privileged Role Administrator with a
standing active assignment. The portfolio objective is to demonstrate
just-in-time privileged access without making a temporary P2 entitlement a
long-term operational dependency.

Microsoft Entra PIM requires Microsoft Entra ID P2 or Microsoft Entra ID
Governance licensing. The current verified tenant baseline is P1.

## Decision

When P2 is explicitly activated and verified:

- only `PRIVILEGED_ADMIN_01` enters the initial PIM pilot;
- only Privileged Role Administrator is placed under the pilot;
- eligibility is time-bound to seven days;
- role activation is limited to one hour;
- MFA and justification are required;
- approval is not enabled in the single-operator lab;
- the existing active PRA assignment is removed only after successful eligible
  assignment and activation validation;
- `BOOTSTRAP_ADMIN` remains outside this PIM pilot;
- emergency identities remain outside this PIM pilot.

Identity Protection is demonstrated independently through a Report-only
risk-based Conditional Access policy targeting the non-administrative pilot
identity.

## Rationale

This design demonstrates reduced standing privilege and activation governance
while preserving a recovery path.

Requiring approval in a lab with no independent approver would produce an
artificial dependency and could cause administrative lockout. MFA,
justification, one-hour activation, time-bound eligibility, audit evidence,
and a limited pilot scope provide appropriate compensating controls.

## License-expiry decision

PIM must not remain an operational dependency when the temporary P2 entitlement
ends.

Before P2 expiration:

- no PIM activation may remain active;
- the required permanent P1-compatible administrative baseline must be
  restored;
- eligible PIM assignments must be removed or allowed to be removed only after
  the fallback role posture is verified;
- P2-dependent risk policies must be removed before they become uneditable;
- temporary Feature 7 access must be removed.

## Consequences

The repository documents a stronger P2 desired state while the lab remains
safe to return to its P1 baseline after the temporary evaluation period.
