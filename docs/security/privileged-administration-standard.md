# Privileged Administration Security Standard

## Purpose

This standard defines the minimum security requirements for privileged identities introduced by Feature 5.

## Administrative identity separation

Privileged administration must use dedicated administrative identities.

A privileged identity must not be treated as the user's normal workforce identity.

Administrative credentials must not be shared.

Routine browsing, messaging, email and ordinary productivity usage are outside the intended purpose of the dedicated privileged identity.

## Least privilege

`Global Administrator` must not be assigned merely for convenience.

The initial planned role for `PRIVILEGED_ADMIN_01` is `Privileged Role Administrator`.

Any additional role requires:

- A documented operational requirement.
- A least-privilege review.
- A pre-write plan.
- Post-write verification.
- Evidence that no broader role is necessary.

## Authentication

A privileged identity must have strong authentication configured before it is accepted as operational.

Phishing-resistant authentication is preferred.

Password-only privileged operation is not accepted as the target state.

Authentication secrets, recovery material and passwords must never be committed to the repository.

## Privileged Role Administrator handling

`Privileged Role Administrator` is considered a high-impact privileged role.

Although narrower than `Global Administrator`, it can control Entra role assignments and therefore can materially affect tenant privilege.

It must not be used as a routine workforce role.

## Bootstrap administrator

The bootstrap Global Administrator is transitional.

Its privilege remains intact until replacement administration and recovery paths are proven operational.

Bootstrap privilege reduction is a separate controlled operation and is not authorized by Feature 5B.

## Emergency access

The target architecture contains two cloud-only emergency-access identities.

Emergency identities:

- Are not routine administrator identities.
- Target `Global Administrator`.
- Require independent credential handling.
- Require strong authentication/recovery planning.
- Require monitoring and periodic validation.
- Must not be considered operational solely because the user objects exist.

Any enablement or privileged assignment is a separate gated operation.

## Feature boundaries

Feature 5B must not modify:

- Security Defaults.
- Conditional Access.
- PIM.
- Identity Protection.
- Existing tenant role assignments.
- Existing account enablement state.

PIM and time-bound eligible assignments remain Feature 7 responsibilities.

## Change discipline

Every privileged tenant write must follow:

1. Read-only preflight.
2. Explicit write plan.
3. Explicit approval gate.
4. Minimum required write.
5. Immediate read-back validation.
6. Sanitized evidence.
7. Rollback or recovery verification.

A failed precondition blocks the write.

## Repository privacy

Raw role-assignment exports remain local-only.

Tracked artifacts must not contain tenant-specific identifiers, full UPNs, passwords, tokens, login codes or raw principal records.

## Emergency-access operational standard

Emergency-access identities are recovery principals rather than routine administrator accounts.

The platform requires two independent cloud-only emergency identities.

Each emergency identity must:

- remain separate from productivity and routine administration;
- remain unlicensed unless a documented technical requirement changes that decision;
- remain outside ordinary workforce and application groups;
- use phishing-resistant authentication that does not depend on the routine administrator's normal authentication path;
- hold `Global Administrator` only as a permanent active emergency assignment;
- never depend on an eligible PIM activation step for recovery;
- be excluded from blocking or restrictive Conditional Access policies when Feature 6 implements those controls;
- have credentials stored independently and securely;
- be used only for recovery or scheduled validation;
- be functionally tested at least every 90 days.

Bootstrap privilege must not be reduced until both emergency identities are operational and a recovery test has succeeded.

## Deferred emergency-access implementation

A lab environment may defer operational emergency-access accounts when the required independent phishing-resistant credentials are not available.

Deferral does not authorize weakening the emergency-access standard.

While deferred:

- emergency identities remain disabled and unprivileged;
- no emergency identity receives `Global Administrator`;
- password-only authentication is not accepted as the final emergency design;
- TOTP, SMS, or routine-administrator authentication is not substituted for the production phishing-resistant requirement;
- the platform must not claim that a tested live break-glass path exists;
- the existing bootstrap Global Administrator must be retained;
- bootstrap privilege reduction remains prohibited.

Future operationalization requires independent phishing-resistant credentials, fresh tenant validation, a controlled onboarding sequence, successful recovery-path testing, and a new explicit write authorization.

### Future phishing-resistant credential options

Possible future implementations for the emergency identities include:

- physical FIDO2/WebAuthn security credentials;
- device-bound passkeys.

These mechanisms are architectural options only. They are not selected, registered, enabled, or validated in the current project.

Their presence in the design must never be interpreted as evidence that a live break-glass authentication path exists.
