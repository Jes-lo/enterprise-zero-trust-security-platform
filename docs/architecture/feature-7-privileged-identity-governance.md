# Feature 7 — Privileged Identity Governance

## Purpose

Feature 7 evaluates privileged identity governance and identity-risk controls
for the Enterprise Zero Trust Security Platform.

The project intentionally does not acquire Microsoft Entra ID P2 or any
additional Microsoft license for this feature.

Microsoft Entra ID P1 remains the licensed identity baseline.

## Established tenant baseline

The established baseline inherited from prior completed features remains:

- Security Defaults enabled.
- Four Conditional Access policies in Report-only.
- `PLAB-CA-Pilot` with zero members.
- `PLAB-CA-004` targeting Microsoft Admin Portals.
- `BOOTSTRAP_ADMIN` as the expected Global Administrator.
- `PRIVILEGED_ADMIN_01` as the expected Privileged Role Administrator.
- Emergency identities disabled and outside normal operations.
- Microsoft Entra ID P1 available.
- Microsoft Entra ID P2 not acquired.
- Microsoft Entra ID Governance not acquired.

## PIM design

A least-privilege PIM design was produced for a potential future environment:

- Identity: `PRIVILEGED_ADMIN_01`
- Role: Privileged Role Administrator
- Assignment type: Eligible
- Eligibility duration: 7 days
- Maximum activation: 1 hour
- MFA on activation: required
- Justification: required
- Ticket information: not required
- Approval: not required for the isolated single-operator lab

This design was not deployed because the project does not acquire the
additional entitlement required for PIM.

No eligible PIM assignment was created and the existing P1-compatible
privileged administration baseline remains the operational state.

## Identity Protection design

A risk-aware Conditional Access design was also produced:

`PLAB-CA-005 - Require MFA for risky sign-ins`

Desired design:

- `EMPLOYEE_01` as pilot identity.
- Emergency identities excluded.
- Medium and high sign-in risk.
- MFA grant control.
- Report-only state.

The policy was not created because risk-based Conditional Access depends on
capabilities outside the licensed P1 baseline selected for this project.

## Portfolio interpretation

Feature 7 demonstrates:

- capability and license assessment;
- privileged-access architecture;
- just-in-time administration design;
- risk-aware Conditional Access design;
- safe license-gating;
- avoidance of unsupported or falsely claimed implementation;
- explicit fallback to the licensed P1 control plane.

PIM and Identity Protection are documented as future architecture rather than
implemented controls.

## Explicit non-goals

Feature 7 does not:

- acquire Microsoft Entra ID P2;
- acquire Microsoft Entra ID Governance;
- deploy PIM;
- create a PIM eligible assignment;
- create `PLAB-CA-005`;
- enable risk-based Conditional Access;
- disable Security Defaults;
- enable CA-001 through CA-004;
- weaken emergency access;
- create authentication secrets or certificates;
- retain temporary audit-helper access.

## Closure state

Feature 7 is closed as:

`validated-license-deferred-p1-baseline-preserved`

This is an intentional architecture and licensing decision, not a failed
implementation.
