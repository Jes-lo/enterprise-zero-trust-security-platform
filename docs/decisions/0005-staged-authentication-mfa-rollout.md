# ADR-0005: Staged Authentication and MFA Rollout

- Status: Accepted
- Decision scope: Feature 4
- Control family: ZT-AUTH

## Context

Authentication policy changes can affect every interactive identity in a
tenant. Applying method restrictions or MFA enforcement before registration and
recovery paths are understood can create administrative lockout risk.

The tenant also contains existing protections whose current state must be
observed before replacement or modification.

## Decision

Authentication and MFA controls will use a staged rollout:

1. read-only baseline;
2. controlled pilot;
3. validation;
4. workforce expansion;
5. enforcement in the dedicated access-control feature.

Feature 4A performs only read operations.

Security Defaults will not be disabled during Feature 4A.

Conditional Access enforcement remains outside Feature 4.

## Consequences

Benefits:

- current tenant behavior is captured before modification;
- authentication policy changes remain reviewable;
- lockout risk is reduced;
- authentication-method configuration is separated from access enforcement;
- evidence can demonstrate before/after state.

Trade-offs:

- MFA enforcement is not completed in the first Feature 4 checkpoint;
- transitional authentication methods may temporarily remain available;
- additional validation stages are required.
