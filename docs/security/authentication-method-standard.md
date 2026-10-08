# Authentication Method Standard

## Objective

Authentication methods must be introduced through controlled rollout and
validated before they are used as an enforcement dependency.

## Preferred methods

### Microsoft Authenticator

Microsoft Authenticator is the primary general-purpose MFA registration target
for workforce identities.

It is introduced through a pilot before broader workforce rollout.

### FIDO2 and passkeys

FIDO2/passkey authentication is the preferred phishing-resistant direction.

Feature 4 establishes readiness and rollout boundaries but does not require
physical security-key ownership for every laboratory identity.

### Temporary Access Pass

Temporary Access Pass is reserved for controlled onboarding and recovery.

The preferred design uses:

- restricted targeting;
- short lifetime;
- one-time use;
- no publication of pass values;
- no persistent storage in Git.

## Transitional methods

### Software OATH

Software OATH is evaluated as a fallback rather than assumed as the primary
method.

### SMS

SMS is not the desired long-term primary MFA method.

It must not be removed until stronger-method registration and recovery paths
have been validated.

### Voice

Voice authentication is not part of the desired steady-state design.

## Enforcement boundary

Authentication-method availability and MFA sign-in enforcement are separate
controls.

Feature 4 establishes method readiness.

Feature 6 owns Conditional Access enforcement.

## Safety requirements

Feature 4A must remain read-only.

It must not:

- disable Security Defaults;
- delete user authentication methods;
- modify Conditional Access;
- modify privileged roles;
- activate emergency identities;
- publish authentication secrets.
