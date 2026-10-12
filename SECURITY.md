# Security Policy

## Scope

This repository is a controlled security-engineering portfolio and
demonstration project for Zero Trust practices across Microsoft 365,
Microsoft Entra ID, Microsoft Intune, Microsoft Defender for Endpoint,
Microsoft Graph, and PowerShell automation.

Testing must be restricted to systems, tenants, accounts, applications,
devices, and data that the project owner is explicitly authorized to use.

This repository is not a production security product, production
deployment, or authorization to test third-party systems.

## Reporting a security issue

Do not publish credentials, secrets, tokens, private keys, tenant-sensitive
information, personal information, or other confidential material in a
public issue.

When GitHub Private Vulnerability Reporting is available for this
repository, use that mechanism for security-sensitive reports.

Otherwise, contact the repository owner privately before disclosing
sensitive details publicly.

## Credentials and secrets

This repository must not contain:

- passwords;
- client secrets;
- access tokens;
- refresh tokens;
- session cookies;
- recovery codes;
- private SSH or TLS keys;
- PFX or P12 files containing private keys;
- authentication caches;
- production credentials;
- real customer data;
- employer-confidential information;
- authentication or authorization headers;
- credentials introduced solely to simplify testing.

Secrets required during an authorized laboratory operation must be supplied
at runtime through appropriate local or CI secret storage and must never be
hard-coded in committed source code or configuration.

## Tenant, identity, and evidence privacy

Microsoft 365 and Microsoft Entra evidence must be treated as potentially
sensitive operational data.

Evidence intended for this repository must be sanitized before commit.

Screenshots, command output, configuration exports, JSON, logs, and other
evidence must be reviewed for unnecessary disclosure of:

- tenant names;
- tenant IDs;
- user principal names;
- email addresses;
- object IDs;
- group IDs;
- application or service-principal IDs;
- device identifiers;
- internal domains;
- IP addresses;
- authentication-method identifiers that are tenant-specific;
- tokens, secrets, or session material;
- personal information.

Only information required to demonstrate the engineering control or
validation result should be retained.

Raw or unsanitized tenant exports must not be committed.

## Authentication and authorization changes

Identity and access changes must follow least-privilege principles.

Authentication, Conditional Access, role assignment, consent, application
permission, endpoint-security, and device-compliance changes should be
limited to the explicitly defined laboratory scope.

Broader permissions or additional licenses must not be requested solely to
produce stronger-looking portfolio evidence.

Where read-only access is sufficient to validate a requirement, write
permissions should not be introduced.

## Microsoft Graph and PowerShell automation

Microsoft Graph and PowerShell automation must use the minimum permissions
required for the documented operation.

Automation that can modify tenant state should use explicit validation,
bounded target selection, and fail-closed safety checks where practical.

Scripts must not silently expand from pilot or laboratory targets to
organization-wide targets.

Tenant identifiers, authentication material, and raw responses containing
sensitive information must not be written to tracked repository paths.

## Controlled security testing

Security tests must not target:

- third-party tenants;
- public services without authorization;
- production environments;
- employer infrastructure;
- customer infrastructure;
- accounts, applications, or devices not owned or explicitly authorized
  for testing.

Destructive endpoint actions, credential attacks, privilege escalation
outside the laboratory scope, or attempts to bypass security controls on
unauthorized systems are outside this repository's scope.

## Endpoint and Conditional Access safety

Endpoint, compliance, Microsoft Defender for Endpoint, and Conditional
Access testing must preserve documented pilot boundaries.

Policies intended for staged or report-only validation must not be
represented as production enforcement.

Changes that broaden assignments, enable destructive actions, or expand
access beyond the documented laboratory targets require explicit review
before execution.

## Security findings

Security findings produced by automated validation or security tooling
should be reviewed individually.

Suppressions or exceptions should include a documented technical
justification rather than disabling security controls globally.

If a credential or secret is accidentally exposed:

1. Revoke or rotate the affected credential immediately.
2. Remove the exposed material from the maintained repository state.
3. Review Git history, GitHub Actions logs, artifacts, releases, issues,
   and pull-request content for additional exposure.
4. Rewrite history only when required to remediate the exposure.
5. Document the incident without preserving the secret itself.

If tenant-sensitive or personal information is unintentionally published,
the affected material should be removed or sanitized and the disclosure
scope assessed.

## Third-party vulnerabilities

A vulnerability discovered in a third-party product or service should be
reported through that vendor's appropriate security-response process rather
than published as an exploit in this repository.

## Supported versions

This repository represents a portfolio project rather than a versioned
production software product.

Only the current `main` branch is considered maintained.
