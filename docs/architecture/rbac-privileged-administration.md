# RBAC & Privileged Administration Architecture

## Status

Feature 5B defines the privileged-administration architecture only.

It does not authorize live tenant changes.

## Current authoritative baseline

Feature 5A established the current active Microsoft Entra role-assignment baseline from the **All roles** export.

The sanitized baseline contains:

- 1 active role assignment.
- 1 represented role type.
- `Global Administrator` = 1.
- 0 unknown or custom role assignments.

The raw export remains local-only and is not tracked by Git.

The current Global Administrator identity is the bootstrap administrative identity.

## Architectural objective

Feature 5 separates routine identities from privileged identities and establishes explicit boundaries for future role administration.

The target architecture is:

1. `BOOTSTRAP_ADMIN`
   - Existing transitional administrative identity.
   - Currently holds `Global Administrator`.
   - Remains unchanged while the replacement privileged path is built and validated.
   - Must not become the normal long-term administrative identity.

2. `PRIVILEGED_ADMIN_01`
   - Dedicated cloud-only administrative identity.
   - Not a routine workforce account.
   - Planned initial Feature 5 role: `Privileged Role Administrator`.
   - Intended for role-governance operations, not email or ordinary productivity activity.
   - Requires strong authentication before privileged use.
   - Live creation and role assignment require the explicit Feature 5C write gate.

3. Emergency access identities
   - Two logical emergency identities are part of the target design.
   - They are not considered operational recovery controls until configuration, authentication, access and recovery procedures are validated.
   - Target role is `Global Administrator`.
   - They are never intended for routine administration.
   - Their live activation or privileged assignment requires a separate explicit gate.

## Why PRIVILEGED_ADMIN_01 does not start as Global Administrator

Feature 5 follows least privilege.

The dedicated privileged identity only needs a role capable of administering Entra role assignments during this phase. It therefore starts with `Privileged Role Administrator`, rather than automatically receiving unrestricted `Global Administrator`.

`Privileged Role Administrator` is itself highly sensitive because it can manage privileged role assignments. It is treated as a high-impact administrative identity and requires the same separation and authentication discipline expected for other critical administrative identities.

Additional service-specific roles must be justified by an actual task and introduced by the feature that owns that task.

Examples:

- Conditional Access belongs to Feature 6.
- PIM belongs to Feature 7.
- Identity Protection belongs to Feature 7.
- Intune administration belongs to the device-management phases.

## Bootstrap reduction safety gate

The bootstrap Global Administrator role must not be removed or reduced until all of the following are true:

- `PRIVILEGED_ADMIN_01` exists.
- Its strong authentication is registered and validated.
- Its intended role assignment is validated.
- An operational emergency-access recovery path exists.
- Recovery and rollback procedures are documented and tested.
- A bootstrap reduction cannot strand the tenant without privileged access.

This is a fail-closed gate.

## Feature boundaries

Feature 5B does not change:

- Security Defaults.
- Conditional Access.
- PIM.
- Identity Protection.
- Authentication-method policy.
- Existing role assignments.
- Existing users.
- Existing emergency accounts.

Feature 5C is the first phase that may perform a controlled tenant write, and only after an explicit approval gate.

## Evidence model

Raw tenant exports remain under ignored local-evidence storage.

Tracked evidence must contain only sanitized aggregate state and must exclude:

- Complete UPNs.
- Tenant domains.
- Tenant IDs.
- Principal IDs.
- Role-assignment IDs.
- Authentication secrets or tokens.
- Device-login codes.

## Recovery principle

No privileged identity is removed merely because a replacement has been created.

Replacement access must first be proven usable, strongly authenticated and recoverable.

## Feature 5C2 implementation status

`PRIVILEGED_ADMIN_01` has been provisioned as a dedicated cloud-only administrative identity.

Its current implementation state is deliberately unprivileged:

- Account enabled.
- User type `Member`.
- No license.
- No group memberships.
- No Microsoft Entra directory-role assignments.
- No PIM configuration.
- Initial privileged role assignment has not occurred.
- Strong-authentication registration remains pending.
- Initial sign-in remains pending.

The existing bootstrap `Global Administrator` assignment remains unchanged.

The identity must not receive `Privileged Role Administrator` until its first-sign-in flow and strong-authentication readiness are completed and independently validated.

Feature 5C2 does not authorize Feature 5C3, 5C4 or 5C5.

## Feature 5C3/5C4 authentication status

`PRIVILEGED_ADMIN_01` completed its initial sign-in and the temporary credential was transitioned to a unique operational password stored outside the repository.

Strong-authentication readiness was established before any directory role assignment:

- Microsoft Authenticator registered and validated.
- One device-bound passkey registered.
- Passwordless sign-in with the passkey successfully tested.
- Initial sign-in complete.
- No Microsoft Entra directory roles assigned.
- No group memberships.
- No license assigned.
- Existing `Global Administrator` assignment baseline remains one.
- Security Defaults remains enabled.
- Conditional Access remains owned by Feature 6.
- PIM and Identity Protection remain owned by Feature 7.

The identity is now authentication-ready but remains intentionally unprivileged.

`Privileged Role Administrator` must not be assigned until the separate Feature 5C5 authorization gate is approved.

## Feature 5C4-R1 group-membership correction

A post-validation review identified that `PRIVILEGED_ADMIN_01` had one direct membership in the cloud `Portfolio Project Lab` Microsoft 365 group.

The original Feature 5C3/5C4 sanitized evidence incorrectly recorded zero group memberships. The historical evidence was corrected rather than silently rewritten:

- Correct historical membership count before remediation: one.
- Group type: Microsoft 365.
- Membership type: Assigned.
- Source: Cloud.
- Group member count before remediation: ten.
- The membership was not required for the dedicated privileged-administration identity.

Feature 5C4-R1 removed only `PRIVILEGED_ADMIN_01` from that collaboration group.

Post-remediation validation confirmed:

- Privileged-admin group memberships: zero.
- Group member count: nine.
- Directory-role assignments: zero.
- Licenses: zero.
- Microsoft Authenticator remains registered.
- Device-bound passkey remains registered.
- Global Administrator assignment baseline remains one.
- Security Defaults remains enabled.

No role assignment was performed as part of this remediation. Feature 5C5 remains a separate authorization gate.
