# Feature 5 — RBAC & Privileged Administration Foundation Closure

Feature 5 establishes the Microsoft Entra privileged-administration foundation for the Enterprise Zero Trust Security Platform.

## Implemented state

The implemented privileged-administration path includes:

- an authoritative RBAC baseline;
- a dedicated cloud-only privileged administrator;
- separation from workforce and collaboration groups;
- Microsoft Authenticator registration;
- a validated device-bound passkey;
- successful fresh passwordless sign-in validation;
- one tenant-scoped `Privileged Role Administrator` assignment;
- an active-static-interim assignment model;
- zero productivity licenses on the dedicated privileged identity;
- zero ordinary group memberships on the dedicated privileged identity;
- preservation of Security Defaults;
- preservation of the existing Global Administrator baseline.

`PRIVILEGED_ADMIN_01` is not a Global Administrator.

PIM conversion remains deliberately deferred to Feature 7.

## Historical correction

During Feature 5C3/5C4, an operator read-back incorrectly recorded zero group memberships for the privileged identity.

A later validation identified one assigned Microsoft 365 collaboration-group membership. Feature 5C4-R1:

- preserved the original inaccurate assertion in correction metadata;
- recorded the correct historical state;
- removed only the unnecessary collaboration membership;
- validated a final group-membership count of zero.

The correction remains auditable in Git history and sanitized evidence.

## Emergency-access governance

Two cloud-only emergency identities exist:

- `EMERGENCY_ADMIN_01`
- `EMERGENCY_ADMIN_02`

Their current project state is intentionally non-operational:

- disabled;
- unlicensed;
- outside ordinary groups;
- no directory roles;
- no validated emergency authentication method.

The project does not claim that a live break-glass recovery path is operational.

## Possible future implementation

The following phishing-resistant mechanisms are documented as possible future emergency-access implementations:

- physical FIDO2/WebAuthn security credentials;
- device-bound passkeys.

Neither option is selected, registered, enabled, or implemented in the current project.

A future implementation would require a separate security review, fresh tenant validation, controlled enrollment, recovery-path testing, and explicit authorization.

## Bootstrap administrator

The existing bootstrap Global Administrator remains retained.

Bootstrap privilege reduction is intentionally blocked because the emergency recovery path is not operational in the current project.

This is an explicit security limitation rather than an implemented control being represented as complete.

## Feature boundaries

Feature 5 does not implement:

- Conditional Access — owned by Feature 6;
- PIM — owned by Feature 7;
- Identity Protection — owned by Feature 7;
- live emergency-access FIDO2/passkey onboarding;
- bootstrap Global Administrator reduction.

## Final Feature 5 status

Feature 5 is complete with one explicitly documented implementation limitation:

> Emergency-access governance is defined, but the live break-glass recovery path is deferred.

The privileged-administration foundation itself is implemented, tested, sanitized, and ready for the Conditional Access work in Feature 6.
