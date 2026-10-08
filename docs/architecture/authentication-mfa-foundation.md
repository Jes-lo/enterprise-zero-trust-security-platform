# Authentication & MFA Foundation

## Purpose

Feature 4 establishes the authentication-method foundation for the portfolio
tenant without prematurely enforcing Conditional Access or modifying privileged
role assignments.

The implementation is intentionally staged:

1. observe the current tenant authentication state;
2. preserve existing tenant protections during discovery;
3. establish an explicit authentication-method strategy;
4. introduce controlled pilot changes only after the baseline is understood;
5. expand authentication registration before sign-in enforcement;
6. leave Conditional Access enforcement to Feature 6.

## Feature boundary

Feature 4 owns:

- authentication-method policy design;
- MFA registration strategy;
- Microsoft Authenticator readiness;
- phishing-resistant authentication readiness;
- Temporary Access Pass onboarding/recovery design;
- weak-factor migration planning;
- read-only authentication-policy evidence.

Feature 4 does not own:

- privileged role assignment;
- PIM;
- Conditional Access enforcement;
- device compliance;
- endpoint security enforcement.

## Rollout model

The rollout model is:

`observe -> pilot -> validate -> expand`

Feature 4A is the observation stage and performs no tenant policy writes.

## Security Defaults

Security Defaults are treated as an existing tenant protection boundary.

Feature 4A records their current state but does not disable or modify them.

A later change may only replace Security Defaults when the replacement controls
are prepared, validated, and protected against administrative lockout.

## Authentication methods

The target strategy prioritizes:

- Microsoft Authenticator for MFA and passwordless readiness;
- FIDO2/passkeys for phishing-resistant authentication;
- Temporary Access Pass for controlled onboarding and recovery.

SMS is not treated as the desired long-term primary MFA mechanism.

Voice authentication is not part of the desired steady-state model.

No weak method is disabled during Feature 4A because registration readiness has
not yet been validated.

## Emergency identities

The two emergency identities created in Feature 3 remain disabled and
unlicensed.

Feature 4 does not automatically activate them and does not treat them as
ordinary workforce identities.

## Evidence model

Raw Microsoft Graph responses remain local-only.

Tracked evidence contains only non-identifying state information such as:

- policy migration state;
- authentication-method state;
- target counts;
- registration-campaign state;
- Security Defaults enabled/disabled state.

Tenant identifiers, user principal names, object IDs and credentials are not
published.
