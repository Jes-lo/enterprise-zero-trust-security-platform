# Controlled Microsoft Authenticator Pilot Registration

## Scope

This runbook applies only to `EMPLOYEE_01`.

The pilot is a standard `PC3` workforce identity.

## Preconditions

Feature 4B established that:

- the pilot exists in the authentication registration report;
- the pilot is not MFA registered;
- the pilot is not MFA capable;
- the pilot is not passwordless capable;
- Microsoft Authenticator is enabled by the existing Authentication Methods
  Policy;
- Security Defaults is enabled.

## Registration procedure

The user signs in to Microsoft Security Info as `EMPLOYEE_01`.

If the initial temporary password has not previously been consumed, Microsoft
Entra requires the user to replace it.

The replacement password is user-managed and must not be committed to Git or
printed by project automation.

The user then adds Microsoft Authenticator and completes the challenge shown
during registration.

## Verification

After registration, the pilot authenticates separately to Microsoft Graph.

The verifier requests only:

`UserAuthenticationMethod.Read`

It reads only:

`GET /me/authentication/methods`

The signed-in Graph account must exactly match the expected pilot UPN held in
ignored local evidence.

The verifier fails closed if:

- a different account authenticates;
- the requested delegated scope is unavailable;
- Microsoft Authenticator is not present;
- a Graph resource write is attempted.

## Explicit exclusions

Feature 4C does not:

- change Security Defaults;
- change Authentication Methods Policy;
- change Conditional Access;
- add or remove methods as an administrator;
- use emergency identities;
- publish UPNs, tenant identifiers, method object IDs, QR payloads, passwords,
  device-login codes, or tokens.
