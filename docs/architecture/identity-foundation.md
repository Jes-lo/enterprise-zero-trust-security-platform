# Identity Foundation

## Purpose

Feature 3 establishes the synthetic identity model used by the Microsoft
365 portfolio laboratory.

The tenant is shared by multiple independent portfolio projects. Live
tenant identities therefore use neutral Portfolio Lab naming instead of
names tied to a single project.

`ZT-LAB` remains the internal architecture identifier for this repository.
Shared tenant resources use the neutral `PLAB` prefix.

## Identity layers

The model separates:

1. Standard workforce identities.
2. Operational identities.
3. Security identities.
4. Privileged identities.
5. Emergency-access identities.
6. External identities.
7. Workload identities.

A standard productivity identity must not become the default privileged
administration identity.

## Bootstrap administrator

`Portfolio Lab Bootstrap Administrator` is the existing bootstrap identity.

Its intended use is tenant establishment and controlled bootstrap work.

It is not intended to become a normal productivity account or the
permanent administrative identity.

A separate permanent privileged-administrator persona is modeled but its
live creation and role design are deferred to Feature 5.

## Synthetic workforce

The laboratory defines synthetic workforce identities representing:

- Human Resources;
- Finance;
- Sales;
- Engineering;
- IT Operations;
- Security;
- Executive leadership;
- Contractor access.

The model provides coverage for every department currently defined in the
organization model.

No identity represents a real employee, customer, contractor, or employer.

## Workforce groups

`PLAB-Workforce` contains the standard synthetic workforce identities.

Department and functional groups provide narrower targeting for security
testing.

The engineering contractor is intentionally kept out of
`PLAB-Engineering` and remains in `PLAB-Contractors`. This allows later
features to demonstrate restricted contractor access independently from
employee engineering access.

The bootstrap administrator, permanent privileged administrator,
emergency-access identities, guest identity, and workload identity are not
members of `PLAB-Workforce`.

## Pilot groups

`PLAB-CA-Pilot` is created as a security group but its membership belongs
to Feature 6.

`PLAB-Device-Pilot` is created as a security group but its membership
belongs to Feature 8.

Keeping pilot membership empty during Feature 3 prevents this feature from
preconfiguring later security-control behavior.

## Emergency access

Two independent cloud-only emergency identities are defined.

They are not routine administrative identities and remain unlicensed unless
a later control provides a justified reason to change that state.

Emergency identities are excluded from general workforce and pilot groups.

Authentication, privileged roles, and Conditional Access treatment for
emergency identities are completed in later features.

## Guest identity

A guest persona is modeled but live creation is deferred until an external
collaboration scenario actually requires it.

## Workload identity

A workload persona is modeled but live creation is deferred to the
enterprise-application and application-permission work.

## Shared tenant naming

Human display names use `Portfolio Lab`.

Security groups use the `PLAB-` prefix.

The actual tenant domain is never stored in the repository.

Complete live user principal names are assembled only during controlled
local execution.

## Licensing boundary

Eight planned standard workforce identities require Microsoft 365 Business
Premium licensing.

The emergency identities remain unlicensed.

The bootstrap account preserves its current license state until later role
review.

The permanent privileged administrator has no Feature 3 licensing action
because its live creation is deferred to Feature 5.

## Feature boundaries

Feature 3 defines identities, security groups, and foundational group
membership.

Feature 3 does not implement:

- MFA policy — Feature 4.
- permanent privileged roles — Feature 5.
- Conditional Access — Feature 6.
- PIM — Feature 7.
- endpoint enrollment.
- enterprise application permissions.

## Secret handling

Passwords, temporary passwords, recovery codes, authentication secrets,
tokens, tenant IDs, Graph object IDs, and complete live user principal
names must not be written to tracked repository files.

Operational evidence containing private tenant information belongs only in
ignored local evidence paths.
