# Conditional Access Security Standard

## Default-deny change discipline

Conditional Access is a lockout-sensitive security control.

No policy may move from design to enforcement without an explicit write authorization and a successful pre-enforcement validation.

## Security Defaults transition

Security Defaults remains enabled until the replacement Conditional Access baseline is ready for a controlled cutover.

The project must not intentionally leave a gap in which:

- Security Defaults is disabled; and
- the replacement Conditional Access baseline is not enforcing the intended protection.

## Report-only first

New Conditional Access policies must begin in report-only mode unless a documented emergency change process explicitly overrides this requirement.

Report-only evaluation must be reviewed before policy enforcement.

## Administrative access

Administrative identities require explicit consideration before enabling a policy.

The current privileged identities are:

- bootstrap Global Administrator;
- dedicated Privileged Role Administrator.

The project must verify that at least one viable administrative authentication path remains available throughout every Conditional Access transition.

## Emergency-access limitation

The two modeled emergency identities are not operational in this project.

Their existence must not be used as evidence that a tested break-glass path exists.

Bootstrap Global Administrator reduction remains prohibited while this limitation exists.

## Scope boundaries

Feature 6 baseline policies must not silently introduce:

- PIM;
- risk-based Identity Protection;
- compliant-device requirements;
- Defender dependencies;
- geographic restrictions;
- authentication-strength requirements not explicitly approved.

These controls require their own design and authorization.

## Feature 6B report-only deployment state

The baseline Conditional Access controls may exist in the tenant before enforcement only when all are configured in `Report-only`.

During this state:

- Security Defaults remains enabled;
- no Conditional Access policy is `On`;
- the pilot group remains unchanged;
- no administrator role is changed;
- no authentication method is changed;
- no emergency identity is enabled;
- no bootstrap privilege is reduced.

The report-only deployment must be validated with policy inspection, What If analysis, and appropriate sign-in evidence before any enforcement decision.

A report-only policy must never be represented as an enforced security control.


## CA-004 administrative target correction

CA-004 was initially created with
`Windows Azure Active Directory`.

The current target is `Microsoft Admin Portals`.

The policy remains `Report-only`.

This correction does not constitute policy enforcement or a
Security Defaults cutover.
