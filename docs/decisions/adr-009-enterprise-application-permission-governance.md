# ADR-009 — Enterprise Application Permission Governance

## Status

Accepted for Feature 9A foundation.

## Context

Enterprise applications and service principals can receive delegated
permissions, application permissions, user or group assignments, ownership and
credentials that materially affect the Zero Trust security boundary.

Application permissions are especially significant because they can operate
without a signed-in user.

Administrative consent is also a separate governance decision and must not be
treated as a routine side effect of application configuration.

## Decision

Feature 9 adopts the following model:

1. inventory before mutation;
2. distinguish delegated permissions from application permissions;
3. deny permission expansion by default;
4. require documented business justification;
5. review tenant-owned application ownership;
6. treat administrative consent as a separately authorized operation;
7. prohibit application credentials in the repository;
8. separate lower-privilege application inventory from broader delegated-grant
   inventory;
9. prohibit mutation of Microsoft first-party service principals as a Feature
   9 default;
10. use sanitized aggregate evidence rather than tenant identifiers.

## Discovery stages

Stage 1 uses the read-only application inventory collector and the
`Application.Read.All` scope.

Stage 2 uses the separately gated delegated-permission collector and the
`Directory.Read.All` scope.

Both stages are GET-only.

Neither stage is authorized for execution by merely merging the Feature 9A
foundation.

## Write boundary

Feature 9A authorizes zero tenant writes.

The following actions require a separate decision:

- application registration creation;
- service-principal mutation;
- client-secret creation;
- certificate credential creation;
- delegated permission grant creation or removal;
- application permission assignment or removal;
- administrative consent;
- user or group assignment changes;
- service-principal deletion.

## Consequences

The project gains an auditable application-permission governance model without
using a high-impact live change to make the portfolio appear more complete.

A later implementation can build on this foundation without weakening the
default-deny posture.
