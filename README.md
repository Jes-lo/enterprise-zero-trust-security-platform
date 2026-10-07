# Enterprise Zero Trust Security Platform for Microsoft 365

An independently designed portfolio project for implementing, automating,
testing, and documenting an enterprise Zero Trust security architecture in
a controlled Microsoft 365 laboratory environment.

## Project purpose

The project demonstrates security engineering capabilities across:

- Identity architecture
- Multi-factor authentication
- Conditional Access
- Role-based access control
- Privileged Identity Management
- Device management
- Device compliance
- Endpoint security
- Microsoft Defender integration
- Enterprise applications
- Application permissions
- Administrative consent
- Microsoft Graph automation
- PowerShell automation
- Security auditing
- Configuration validation
- Security testing
- Recovery and environment reconstruction

## Core technology areas

The laboratory is designed around technologies including:

- Microsoft 365
- Microsoft Entra ID
- Microsoft Intune
- Microsoft Defender
- Microsoft Graph
- PowerShell

Availability of individual capabilities depends on the licenses enabled in
the laboratory tenant.

## Engineering principles

The project follows these principles:

- Zero Trust
- Least privilege
- Explicit verification
- Assume breach
- Separation of duties
- Defense in depth
- Secure-by-default configuration
- Fail-closed validation where appropriate
- Reproducible configuration
- Evidence-based security testing
- No production data
- No production credentials
- No third-party tenant access

## Repository scope

    automation/
      graph/              Microsoft Graph automation
      powershell/         PowerShell automation

    configs/              Sanitized configuration definitions

    docs/
      architecture/       Original architecture documentation
      decisions/          Architecture Decision Records
      evidence/           Sanitized validation evidence
      security/           Threat models and security documentation
      testing/            Security and functional test documentation

    policies/
      access/             Access-control policy definitions
      apps/               Application security policies
      endpoint/           Endpoint security policies
      identity/           Identity security policies

    scripts/              Repository tooling and validation scripts
    tests/                Automated tests

## Current status

Feature 2 — Tenant bootstrap and licensing validation.

Completed foundations include:

- Repository security and governance
- Synthetic organization model
- Identity personas and privilege classes
- Zero Trust access-decision architecture
- Threat model
- Security control objectives
- Architecture Decision Records
- Automated repository and architecture validation

Feature 2 includes the tenant-bootstrap contract, licensing boundaries,
trial safeguards, least-privilege Microsoft Graph discovery automation,
live Business Premium capability validation, and sanitized repository
evidence.

The live laboratory validated Microsoft Entra ID P1, Microsoft Intune
Plan 1, Microsoft Defender for Business, and Microsoft Defender for
Office 365 Plan 1 without publishing tenant identifiers.

No production Microsoft 365 environment is used by this project.

## Intellectual property

The architecture, original source code, documentation, test scenarios,
diagrams, policy models, and other original project material are created
specifically for this repository.

No open-source license is granted for the original project material unless
a file explicitly states otherwise.

See:

- `LICENSE`
- `COPYRIGHT.md`
- `NOTICE.md`
- `THIRD_PARTY_NOTICES.md`
- `TRADEMARKS.md`

## Security

Do not commit credentials, tenant secrets, authentication tokens,
private keys, certificates containing private keys, personally
identifiable information, or unsanitized tenant evidence.

See `SECURITY.md`.

## Disclaimer

This is an independent portfolio project.

It is not an official Microsoft product and is not sponsored, endorsed,
certified, or maintained by Microsoft.

## Feature 3 — Identity Foundation

Status: in progress.

Feature 3 defines the shared synthetic identity foundation for the portfolio
laboratory.

The current offline model includes:

- neutral Portfolio Lab tenant naming;
- 14 modeled identities;
- 8 planned Business Premium workforce identities;
- separate bootstrap and permanent privileged-administrator personas;
- two cloud-only emergency-access identities;
- complete organizational department coverage;
- 11 security groups with deterministic naming and membership ownership;
- deferred guest and workload identities;
- repository privacy and evidence boundaries.

No Feature 3 identities or groups have been created in the live tenant yet.
