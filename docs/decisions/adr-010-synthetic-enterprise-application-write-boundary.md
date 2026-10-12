# ADR-010 — Synthetic Enterprise Application Write Boundary

## Status

Accepted for Feature 9 closure.

## Context

Feature 9B completed a sanitized read-only inventory and observed:

- 193 total service principals;
- zero tenant-owned service principals;
- zero tenant-owned application-permission assignments;
- zero tenant-owned applications with application permissions.

The project therefore has no existing tenant-owned enterprise application that
needs a controlled permission-governance remediation.

A synthetic application could be introduced only to manufacture an additional
portfolio scenario.

Creating a complete enterprise-application pair through Microsoft Graph would
expand the current authorization boundary. Creating an application object and
creating its corresponding service principal are separate operations with
different permission requirements.

The service-principal creation path requires a write-capable application
management permission in delegated scenarios and an appropriate Microsoft
Entra role.

## Decision

Feature 9 will not create a synthetic tenant application or service principal.

The project chooses privilege minimization over introducing a broad
application-management permission solely for demonstration purposes.

Feature 9 also will not:

- request `Application.ReadWrite.All`;
- request `Directory.ReadWrite.All`;
- assign a new Microsoft Entra administrative role;
- create a client secret;
- create a certificate credential;
- grant application permissions;
- grant delegated permissions;
- perform additional administrative consent;
- delete or modify existing first-party service principals.

## Portfolio rationale

The portfolio value of Feature 9 is demonstrated by:

- an explicit enterprise-application governance model;
- distinction between delegated and application permissions;
- least-privilege inventory design;
- successful sanitized live enterprise-application inventory;
- detection and documentation of the OAuth consent boundary;
- adversarial tests preventing permission expansion;
- explicit refusal to request broader permissions without a justified need.

Creating an artificial application would not materially improve those controls
enough to justify additional tenant privilege.

## Future trigger

A synthetic or real tenant-owned application may be introduced only if a
future requirement independently justifies it.

That future phase requires a new design and write authorization and must not be
treated as an implicit continuation of Feature 9.

## Closure

`FEATURE9_SYNTHETIC_APPLICATION=DEFERRED_PRIVILEGE_MINIMIZATION`

`FEATURE9_APPLICATION_READWRITE_ALL_AUTHORIZED=NO`

`FEATURE9_DIRECTORY_READWRITE_ALL_AUTHORIZED=NO`

`FEATURE9_NEW_ADMIN_ROLE_AUTHORIZED=NO`

`FEATURE9_NEW_CREDENTIAL_AUTHORIZED=NO`

`FEATURE9_ADDITIONAL_CONSENT_AUTHORIZED=NO`
