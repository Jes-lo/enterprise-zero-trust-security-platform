# Security Policy

## Scope

This repository is a controlled security-engineering portfolio project.

Testing must be restricted to systems, tenants, accounts, devices, and
data that the project owner is explicitly authorized to use.

## Prohibited repository content

Never commit:

- Passwords
- Client secrets
- Refresh tokens
- Access tokens
- Session cookies
- Private keys
- PFX or P12 files
- Authentication caches
- Recovery codes
- Real personally identifiable information
- Employer-confidential data
- Customer data
- Unsanitized tenant exports
- Sensitive tenant identifiers when disclosure is unnecessary

## Evidence handling

Evidence intended for the public repository must be sanitized before
commit.

Screenshots and exported configuration must be reviewed for:

- Tenant names
- Tenant IDs
- Subscription IDs
- User principal names
- Email addresses
- Device identifiers
- IP addresses
- Object IDs
- Application IDs
- Internal domains
- Tokens or secrets
- Personal information

Only information required to demonstrate a control or test should be
published.

## Authentication material

Secrets must be supplied at runtime through approved local or CI secret
storage.

Secrets must never be hard-coded in source files or configuration
committed to Git.

## Security testing boundary

Security tests must not target:

- Third-party tenants
- Public services without authorization
- Production environments
- Employer infrastructure
- Customer infrastructure
- Accounts not owned or explicitly authorized for testing

## Responsible handling

A vulnerability discovered in a third-party product should be reported
through that vendor's appropriate security-response process rather than
published as an exploit in this repository.

## Incident response

If a secret is accidentally committed:

1. Revoke or rotate the affected credential immediately.
2. Remove the exposed material from the repository.
3. Review Git history for exposure.
4. Assess whether history rewriting is required.
5. Document the incident without preserving the secret itself.
