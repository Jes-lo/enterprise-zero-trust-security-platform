# Feature 7 — License and Trial Cleanup Guardrails

## Purpose

Feature 7 can temporarily depend on Microsoft Entra ID P2. This document
defines the mandatory safety conditions for activation and cleanup.

## Before activating P2

Confirm that:

- Feature 7 repository design is already validated.
- Security Defaults remains enabled.
- Existing Conditional Access policies remain Report-only.
- `BOOTSTRAP_ADMIN` remains the recovery administrator.
- Emergency identities remain unchanged.
- The exact trial expiration date is recorded locally.
- Cleanup is scheduled before the trial expiration date.

## During the P2 pilot

Allowed P2-dependent scope is limited to:

- PIM for the Privileged Role Administrator pilot.
- Identity Protection assessment.
- One Report-only risky-sign-in Conditional Access pilot.

No production-style enforcement is authorized.

## Mandatory pre-expiration cleanup

Complete cleanup before P2 entitlement expires.

Required sequence:

1. Confirm no PIM activation is currently active.
2. Restore the intended P1-compatible permanent PRA assignment if the pilot
   removed the standing assignment.
3. Verify `PRIVILEGED_ADMIN_01` has the expected fallback role.
4. Remove the eligible PIM PRA assignment.
5. Remove `PLAB-CA-005` while P2-dependent Conditional Access configuration is
   still editable.
6. Verify the original four Conditional Access policies remain Report-only.
7. Leave Security Defaults enabled.
8. Remove the temporary `Global Reader` role from `AUDIT_READER_01`.
9. Revoke sessions for `AUDIT_READER_01`.
10. Reset the exposed temporary password before any further account use.
11. Disable and then remove `AUDIT_READER_01` when no longer needed.
12. Remove temporary local collector files.
13. Do not revoke unrelated historical permissions from the shared Microsoft
    Graph Command Line Tools enterprise application unless their provenance is
    independently established.

## Failure prevention

Do not allow the P2 trial to expire while a time-bound privileged assignment is
active.

Do not rely on eligible PIM assignments as the only path to required
administrative access when the P2 entitlement is about to end.

Do not leave P2-only Conditional Access configuration as an unmanaged
post-trial dependency.

## Evidence

Portfolio evidence should contain sanitized state summaries only.

Do not commit:

- UPNs;
- tenant identifiers;
- object identifiers;
- authentication tokens;
- passwords;
- MFA values;
- temporary client identifiers;
- raw device/login codes;
- unredacted portal screenshots.
