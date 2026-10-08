# Conditional Access Baseline Architecture

## Purpose

Feature 6 introduces a controlled migration from Microsoft Entra Security Defaults to explicit Conditional Access policies.

The project does not disable Security Defaults during design or baseline discovery.

## Current state

At the beginning of Feature 6:

- Security Defaults is enabled.
- No Conditional Access policies exist.
- Microsoft Entra Conditional Access capability is available through the existing Microsoft 365 Business Premium licensing.
- `PLAB-CA-Pilot` exists and has no members.
- the dedicated privileged administrator remains `Privileged Role Administrator`;
- the bootstrap Global Administrator remains retained;
- emergency-access identities remain disabled and non-operational.

## Migration strategy

The migration follows five safety stages:

1. record the current tenant state;
2. define the replacement policy set;
3. create policies in report-only mode under a separate write gate;
4. validate policy evaluation before enforcement;
5. perform a separately authorized Security Defaults cutover only after the replacement baseline is ready.

Security Defaults must not be disabled merely to experiment with Conditional Access.

## Planned baseline policies

### CA-001 — Require MFA for all users

Broad MFA coverage intended to replace the general MFA protection currently supplied by Security Defaults.

The two emergency identities remain modeled as exclusions for their future recovery role. They are disabled and non-operational in the current project.

### CA-002 — Require MFA for privileged administration

Explicit MFA coverage for the currently relevant privileged roles:

- Global Administrator;
- Privileged Role Administrator.

This intentionally overlaps with the broad MFA policy. The overlap provides an independently reviewable administrative control rather than relying only on the general user policy.

### CA-003 — Block legacy authentication

Blocks legacy client authentication paths that cannot satisfy modern authentication controls.

### CA-004 — Require MFA for Azure management

Provides an explicit administrative-management protection layer for Azure management access.

## Report-only requirement

Every planned Conditional Access policy begins in report-only mode.

Before enforcement, the project requires:

- policy configuration review;
- Conditional Access What If analysis;
- sign-in log evaluation;
- pilot validation;
- administrator lockout analysis;
- a separate explicit authorization.

## Pilot group

`PLAB-CA-Pilot` is the controlled pilot scope.

It remains empty in Feature 6A.

`EMPLOYEE_01` is the planned first pilot identity, but no pilot membership is added until a separately authorized stage.

## Bootstrap administrator

The bootstrap Global Administrator remains retained.

Feature 6 does not reduce bootstrap privilege.

Because the emergency-access recovery path is not operational, any future Conditional Access enforcement requires explicit lockout-protection review before activation.

## Emergency access

Emergency-access identities remain:

- disabled;
- unlicensed;
- unprivileged;
- outside normal groups;
- non-operational.

Physical FIDO2/WebAuthn credentials and device-bound passkeys remain documented future options only and are not implemented by Feature 6.

## Feature boundaries

Feature 6 does not implement:

- PIM;
- Identity Protection;
- risk-based Conditional Access;
- device compliance enforcement;
- endpoint Defender controls.

Those controls remain assigned to later features.
