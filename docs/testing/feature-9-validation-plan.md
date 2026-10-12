# Feature 9 — Validation Plan

## Feature 9A objective

Validate the application-permission governance foundation before any live
Microsoft Graph discovery or tenant mutation.

## Positive validation

The repository validator must confirm:

- Feature 9 lifecycle is `feature9a-foundation`;
- implementation state is read-only discovery pending;
- tenant writes are not authorized;
- application registration creation is not authorized;
- service-principal mutation is not authorized;
- credential creation is not authorized;
- permission-grant creation and removal are not authorized;
- administrative consent is not authorized;
- Stage 1 uses `Application.Read.All`;
- Stage 1 is GET-only and not yet execution-authorized;
- Stage 2 uses `Directory.Read.All`;
- Stage 2 is GET-only and not yet execution-authorized;
- application and delegated permissions are distinguished;
- application permissions default to deny unless justified;
- delegated permissions default to deny unless justified;
- administrative consent defaults to deny;
- no tenant IDs, object IDs, UPNs, secrets or tokens are committed;
- device-compliance ownership points to Feature 8.

## Static collector validation

Both PowerShell collectors must:

- contain Microsoft Graph GET operations;
- contain no POST;
- contain no PATCH;
- contain no PUT;
- contain no DELETE;
- contain no Microsoft Graph mutation cmdlets;
- avoid printing authentication identity, tenant ID or object IDs;
- produce aggregate sanitized output.

## Adversarial validation

Tests must reject at least:

- tenant writes enabled;
- administrative consent enabled;
- application creation enabled;
- a write-capable Stage 1 Graph scope;
- premature Stage 1 execution authorization;
- premature Stage 2 execution authorization;
- application permissions changed to allow-by-default;
- a collector changed from GET to POST;
- device-compliance ownership regressed back to Feature 9.

## Live discovery gates

Phase 9A performs no live Graph request.

Phase 9B requires separate approval before the Stage 1 collector runs.

Phase 9C requires another separate approval before the broader delegated-grant
collector runs.

## Completion

Feature 9A is complete when:

- architecture and ADR are present;
- guardrails are present;
- desired-state configuration and policy are present;
- both GET-only collectors pass static validation;
- positive validation passes;
- adversarial validation passes;
- prior Feature 8 validation still passes;
- repository security regression passes;
- the branch is clean and synchronized.

Feature 9A completion does not equal live tenant discovery or tenant
implementation.
