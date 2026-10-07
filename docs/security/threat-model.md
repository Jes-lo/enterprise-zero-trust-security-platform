# Threat Model

## Scope

This threat model covers the synthetic Microsoft 365 security laboratory.

It is not a threat model for any real organization.

## Protected assets

The architecture treats the following as high-value assets:

- Tenant administrative control
- Workforce identities
- Privileged identities
- Emergency identities
- Authentication methods
- Managed devices
- Enterprise applications
- Workload identities
- Application permissions
- Security configuration
- Audit evidence
- Collaboration data

## Primary threat categories

### Credential compromise

An attacker obtains or guesses credentials associated with a laboratory
identity.

Security objectives:

- Require stronger authentication where appropriate.
- Reduce usefulness of a password alone.
- Detect or restrict abnormal authentication context.

### Session compromise

A valid authenticated session is misused.

Security objectives:

- Maintain meaningful session controls.
- Preserve visibility into session and sign-in activity.
- Provide a response path for session revocation.

### Privilege abuse

An identity receives or misuses excessive administrative privilege.

Security objectives:

- Separate administrative identities.
- Apply least privilege.
- Limit standing privileged access.
- Maintain auditability of privilege use.

### Device compromise

An identity attempts access through an unmanaged, unhealthy, or
non-compliant endpoint.

Security objectives:

- Establish device state.
- Define compliance requirements.
- Integrate device state into access decisions.

### Application permission abuse

An application or workload receives permissions beyond its documented
business need.

Security objectives:

- Document application permissions.
- Separate delegated and application permissions.
- Restrict administrative consent.
- Review high-impact permissions.

### External identity abuse

A contractor or guest retains unnecessary access or receives excessive
scope.

Security objectives:

- Constrain access.
- Define lifecycle expectations.
- Avoid administrative privilege for external identities unless explicitly
  justified by a documented laboratory scenario.

### Control bypass

A user or administrator attempts to access a protected resource through a
path not covered by the intended controls.

Security objectives:

- Test access policies against multiple personas and device states.
- Preserve emergency access without turning it into a routine bypass.
- Detect configuration drift.

### Configuration error

A security control is weakened accidentally.

Security objectives:

- Maintain reproducible configuration.
- Validate security-critical settings.
- Detect divergence between expected and observed state.

## Trust assumptions

The project does not assume that:

- A password proves sufficient trust.
- An authenticated user is automatically safe.
- An administrator is automatically trustworthy.
- A managed device is permanently trustworthy.
- An application permission remains appropriate forever.
- A successful previous access decision guarantees future access.

## Out of scope

The project does not perform:

- Exploitation of third-party tenants
- Malware deployment
- Credential theft
- Unauthorized phishing
- Password attacks against external systems
- Security testing against production infrastructure
