# Controlled Microsoft Authenticator Passkey Pilot

## Scope

Feature 4D validates a phishing-resistant passkey for the existing
`EMPLOYEE_01` standard-user pilot.

The target is a device-bound passkey stored by Microsoft Authenticator.

This checkpoint does not broaden the rollout to other workforce identities.

## Preconditions

The controlled pilot requires:

- Feature 4C to be complete;
- Microsoft Authenticator MFA to remain registered;
- the Software OATH fallback to remain available;
- FIDO2/passkey policy to permit registration;
- self-service passkey registration to be available;
- no Conditional Access dependency for the registration workflow;
- no use of emergency identities.

The pilot account remains a non-privileged `PC3` identity.

## Registration procedure

Registration is user-interactive.

The user creates one passkey from the existing Microsoft Authenticator
work/school account and completes local device verification with the
operating-system-supported biometric, PIN, or screen-lock mechanism.

The intended credential is device-bound.

The workflow must not intentionally create a synced passkey through another
password manager or platform provider.

No Graph write operation is used to create the credential.

## Tenant policy assessment

Tenant policy is assessed separately with read-only delegated permission:

`Policy.Read.AuthenticationMethod`

The resource is:

`GET /policies/authenticationMethodsPolicy/authenticationMethodConfigurations/fido2`

The assessment records only sanitized policy characteristics needed to
demonstrate that the pilot was permitted.

No target object identifiers or tenant identifiers are published.

## Pilot verification

Pilot verification is performed as the signed-in `EMPLOYEE_01` identity.

Delegated permissions are restricted to self-read scopes:

- `UserAuthMethod-Passkey.Read`
- `UserAuthenticationMethod.Read`

The verifier reads:

- `GET /me/authentication/fido2Methods`
- `GET /me/authentication/methods`

The verifier must prove that:

- the authenticated account matches the controlled pilot;
- at least one passkey exists;
- at least one passkey is device-bound;
- Microsoft Authenticator is identified as the passkey provider;
- Microsoft Authenticator MFA remains registered;
- Software OATH remains registered as a fallback;
- Graph verification performs no write operation.

## Evidence handling

Raw Graph responses remain under `local-evidence/` and are ignored by Git.

Tracked evidence is sanitized and must not contain:

- complete user principal names;
- tenant domains;
- tenant identifiers;
- Graph object identifiers;
- passkey credential identifiers;
- AAGUID values;
- OAuth tokens;
- passwords;
- registration secrets;
- QR payloads;
- device-login codes.

## Recovery

If the verifier authenticates the wrong identity, it fails closed before
accepting pilot evidence.

A failed verification must not trigger another passkey registration.

If the passkey is already present, verification should be retried only as a
read operation.

## Explicit exclusions

Feature 4D does not:

- disable Security Defaults;
- modify Authentication Methods Policy;
- change FIDO2/passkey targeting;
- create or modify Conditional Access;
- assign privileged roles;
- activate emergency identities;
- delete Microsoft Authenticator MFA;
- delete Software OATH;
- expand passkey registration to the workforce;
- publish authentication secrets.
