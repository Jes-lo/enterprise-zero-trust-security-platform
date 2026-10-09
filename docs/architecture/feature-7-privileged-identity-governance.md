# Feature 7 — Privileged Identity Governance

## Purpose

Feature 7 extends the lab from standing privileged access toward controlled,
time-bound privileged access and identity-risk-aware controls.

The implementation is intentionally staged. Microsoft Entra ID P1 remains the
current verified baseline. P2-dependent controls must not be enabled until a
valid Microsoft Entra ID P2 entitlement is explicitly activated and verified.

## Established baseline

The following state is inherited from completed Features 4–6 and is not
revalidated by this document:

- Security Defaults remains enabled.
- Four Conditional Access policies exist in Report-only.
- `PLAB-CA-Pilot` has zero members.
- `PLAB-CA-004` targets Microsoft Admin Portals.
- `BOOTSTRAP_ADMIN` is the expected Global Administrator.
- `PRIVILEGED_ADMIN_01` is the expected Privileged Role Administrator.
- Emergency identities remain disabled and are not operational dependencies.
- Microsoft Entra ID P1 is present.
- Microsoft Entra ID P2 and Entra ID Governance are not currently established.

## PIM pilot target

The controlled PIM pilot is limited to:

- Identity: `PRIVILEGED_ADMIN_01`
- Role: Privileged Role Administrator
- Eligible assignment duration: 7 days
- Maximum activation duration: 1 hour
- MFA on activation: required
- Justification on activation: required
- Ticket information: not required
- Approval: not required for this single-operator lab
- Permanent active role after successful PIM transition: not retained during
  the licensed pilot
- Emergency identities: excluded from the PIM pilot

Approval is intentionally not enabled because this isolated lab does not have
two independent approvers. Creating an artificial self-approval dependency
would add lockout risk without adding meaningful separation of duties.

## Safe transition sequence

The permanent Privileged Role Administrator assignment is never removed first.

The implementation sequence is:

1. Verify the P2 entitlement.
2. Configure PIM role settings.
3. Create the eligible assignment for `PRIVILEGED_ADMIN_01`.
4. Confirm the eligible assignment is visible.
5. Perform a successful controlled activation.
6. Confirm the activated role is usable.
7. Only then remove the pre-existing standing active PRA assignment.
8. Allow the activation to expire and verify the identity is no longer active.
9. Preserve `BOOTSTRAP_ADMIN` as the administrative recovery path during the
   pilot.

## Identity Protection pilot

Identity Protection implementation is also P2-gated.

The minimum portfolio pilot is one Conditional Access policy:

`PLAB-CA-005 - Require MFA for risky sign-ins`

Design:

- State: Report-only
- Included identity: `EMPLOYEE_01`
- Excluded identities:
  - `EMERGENCY_ADMIN_01`
  - `EMERGENCY_ADMIN_02`
- Sign-in risk: medium and high
- Grant control: require multifactor authentication
- No enforcement cutover in Feature 7

The purpose of CA-005 is to demonstrate risk-aware access design without
introducing production-style enforcement into the portfolio lab.

## Explicit non-goals

Feature 7 does not:

- disable Security Defaults;
- enable the existing Conditional Access baseline;
- make emergency identities dependent on PIM;
- add PIM to Global Administrator;
- add permanent new privileged administrators;
- create authentication secrets or certificates;
- rely on the temporary audit helper as a project artifact;
- enable risk-based Conditional Access without verified P2 entitlement.

## Exit criteria

Feature 7 is complete only when:

- the repository design and validation artifacts pass;
- P2-dependent implementation is either successfully validated or explicitly
  documented as license-deferred;
- the PIM activation and expiration lifecycle is tested if P2 is activated;
- risk-based CA remains Report-only;
- no emergency account is weakened;
- trial-expiry cleanup has been completed before loss of P2 entitlement;
- temporary helper access is removed;
- the repository is clean and all regression tests pass.
