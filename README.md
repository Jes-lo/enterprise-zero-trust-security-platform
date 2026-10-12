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

**Status: Portfolio implementation complete.**

The repository contains the completed and validated implementation track from
Feature 1 through Feature 9.

Validated project progression:

- **Feature 1 — Organization and Zero Trust Architecture:** completed.
- **Feature 2 — Tenant Bootstrap and Licensing Validation:** completed.
- **Feature 3 — Identity Foundation:** completed with sanitized live validation
  and idempotent provisioning evidence.
- **Feature 4 — Authentication and MFA Foundation:** completed with staged
  readiness and controlled authentication-method pilot validation.
- **Feature 5 — RBAC and Privileged Administration:** completed with documented
  operational boundaries.
- **Feature 6 — Conditional Access Baseline:** completed in validated
  report-only mode; enforcement remains deliberately deferred.
- **Feature 7 — Privileged Identity Governance:** closed as
  `VALIDATED-LICENSE-DEFERRED` because the current laboratory does not justify
  acquiring additional P2/Governance licensing solely for portfolio evidence.
- **Feature 8 — Endpoint Security and Device Compliance:** tenant configuration
  validated; real endpoint runtime/device telemetry remains
  `ENVIRONMENT_DEFERRED`.
- **Feature 9 — Enterprise Application and Permission Governance:** completed
  with validated read-only inventory, consent-boundary evidence, adversarial
  permission-expansion controls, and privilege-minimization closure.

The Feature 9 `Application.Read.All` delegated administrator consent used for
the controlled inventory was selectively revoked through the Microsoft Entra
admin center after Feature 9 completion. The cleanup is operator-confirmed from
the portal. It was intentionally not revalidated by requesting additional
Microsoft Graph directory permissions solely for cleanup verification.

Intentional deferred boundaries are documented rather than represented as
implemented controls. They do not prevent the repository from being complete
for its portfolio scope.

This project is a controlled laboratory implementation and portfolio artifact.
It is not a production deployment, production certification, or substitute for
organization-specific security assessment.

No production Microsoft 365 environment, production data, or production
credentials are used by this project.

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
