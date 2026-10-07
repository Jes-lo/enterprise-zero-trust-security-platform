# Zero Trust Control Objectives

The control objectives define what the project must prove rather than how
a specific product setting must be configured.

## Identity

### ZT-ID-001

Every human identity must have a defined persona and lifecycle purpose.

### ZT-ID-002

Routine administrative activity must use an identity separate from normal
productivity activity.

### ZT-ID-003

Emergency administrative access must use dedicated identities.

## Authentication

### ZT-AUTH-001

Privileged access must require authentication stronger than a password
alone.

### ZT-AUTH-002

Authentication requirements must be enforceable through centrally managed
policy.

## Authorization

### ZT-AZ-001

Administrative access must follow least privilege.

### ZT-AZ-002

Standing high-impact administrative privilege should be minimized where
supported by the platform and licensing.

### ZT-AZ-003

Privilege changes must remain auditable.

## Access

### ZT-ACCESS-001

Protected-resource access decisions must be capable of considering identity
and authentication context.

### ZT-ACCESS-002

Device state must be usable as an access signal for selected resources.

### ZT-ACCESS-003

A defined emergency-access path must remain available without becoming a
routine control bypass.

## Endpoint

### ZT-ENDPOINT-001

Managed endpoints must have documented compliance requirements.

### ZT-ENDPOINT-002

Non-compliant endpoints must produce a measurably different security
outcome for selected access scenarios.

## Applications

### ZT-APP-001

Every laboratory application registration must have a documented purpose.

### ZT-APP-002

Application permissions must be restricted to the minimum documented
scope.

### ZT-APP-003

High-impact consent must require explicit administrative governance.

## Monitoring

### ZT-MON-001

Security-relevant identity and administrative activity must produce
reviewable telemetry where the platform exposes it.

### ZT-MON-002

Configuration changes affecting security controls must be detectable or
reviewable.

## Testing

### ZT-TEST-001

Security controls must be validated using positive and negative tests.

### ZT-TEST-002

Published evidence must be sanitized before entering the repository.

### ZT-TEST-003

Failure of a security requirement must be visible rather than silently
treated as success.
