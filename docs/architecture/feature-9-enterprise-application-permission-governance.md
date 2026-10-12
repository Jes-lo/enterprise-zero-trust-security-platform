# Feature 9 — Enterprise Application and Permission Governance

## Purpose

Feature 9 extends the Zero Trust laboratory from identity, privileged access,
Conditional Access, and endpoint controls into application identities and
permission governance.

The feature covers:

- Microsoft Entra enterprise applications;
- service principals;
- tenant-owned application identities;
- delegated permission grants;
- application permissions represented through app-role assignments;
- application ownership;
- administrative-consent governance;
- credential and secret-handling boundaries.

Feature 9 does not assume that an existing application or consent grant is safe
merely because it already exists.

## Feature boundary

Feature 9 owns application-identity and permission governance.

It does not take ownership of:

- authentication-method policy — Feature 4;
- privileged role administration — Feature 5;
- Conditional Access — Feature 6;
- PIM and Identity Protection — Feature 7;
- device compliance and endpoint security — Feature 8.

A stale historical configuration reference that assigned device compliance to
Feature 9 is corrected by this feature foundation to reflect the implemented
Feature 8 ownership.

## Phase 9A — Foundation

Phase 9A is repository and design work only.

It performs no Microsoft Graph authentication, no live inventory request and
no tenant mutation.

It establishes:

- the permission-governance model;
- least-privilege discovery stages;
- read-only inventory tooling;
- privacy rules;
- mutation prohibitions;
- positive and adversarial repository validation.

## Phase 9B — Enterprise application inventory

The first live phase is read-only.

Its intended Microsoft Graph scope is:

`Application.Read.All`

The collector is limited to GET requests and produces only sanitized aggregate
output suitable for sharing.

The phase is intended to establish:

- total service-principal population;
- tenant-owned service-principal population;
- disabled tenant-owned service principals;
- tenant-owned applications without service-principal owners;
- tenant-owned application-permission assignment counts.

Phase 9B is not authorized by Phase 9A merely because the collector exists.

Authentication requires a fresh explicit execution gate.

## Phase 9C — Delegated permission grant inventory

Delegated permission grants use a separately gated read-only collector.

Its intended Microsoft Graph scope is:

`Directory.Read.All`

This broader read permission is not silently combined with Phase 9B.

The collector is limited to GET requests and produces aggregate counts for
tenant-owned client service principals, including organization-wide consent
counts.

Phase 9C requires a separate explicit execution decision after Phase 9B has
been reviewed.

## Potential controlled implementation phase

Feature 9 may later determine that a synthetic single-tenant application adds
meaningful portfolio value.

Phase 9A does not authorize that implementation.

Any future application registration, service-principal mutation, credential,
permission grant, consent grant, assignment, or deletion requires:

1. a fresh tenant read-back;
2. a documented exact desired state;
3. least-privilege review;
4. a separate explicit write gate;
5. post-write authoritative read-back;
6. sanitized evidence;
7. rollback planning that does not broaden access.

No client secret, private key, token, tenant identifier, object identifier or
real user principal name is committed to the repository.

## Permission model

Delegated permissions and application permissions are treated as distinct
security decisions.

For each permission, the project must be able to explain:

- the protected resource;
- whether access is delegated or app-only;
- the minimum required scope or app role;
- why the permission is necessary;
- whether administrative consent is required;
- what principal receives the grant;
- what removal or rollback would mean.

Existing consent does not replace justification.

## Administrative consent

Administrative consent is denied by default in the Feature 9 policy model.

The foundation does not grant or revoke consent.

Any future administrative-consent operation requires an explicit controlled
write phase and must not be bundled into unrelated application changes.

## Credential boundary

Feature 9A creates no application credential.

Repository evidence must never contain:

- client secrets;
- certificate private keys;
- access tokens;
- refresh tokens;
- onboarding credentials.

## Current state

`FEATURE9_PHASE=FOUNDATION`

`FEATURE9_TENANT_DISCOVERY=PENDING`

`FEATURE9_TENANT_WRITES_AUTHORIZED=NO`

`FEATURE9_ADMIN_CONSENT_AUTHORIZED=NO`

`FEATURE9_CREDENTIAL_CREATION_AUTHORIZED=NO`
