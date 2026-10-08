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
