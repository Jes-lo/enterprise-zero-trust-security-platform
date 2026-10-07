# ADR-0003: Stage Laboratory Licensing by Feature

## Status

Accepted

## Context

The laboratory needs capabilities from multiple Microsoft security products.

Activating every optional trial at the beginning would consume limited trial
time before those capabilities are exercised and could make tests depend on
licenses that are not part of the documented base environment.

## Decision

Microsoft 365 Business Premium is the base laboratory subscription.

The project validates the capabilities actually exposed by the live tenant
before using them.

Additional licensing is activated only when required by a defined feature.

Microsoft Entra ID P2 is deferred until the feature covering Privileged
Identity Management and Identity Protection.

Advanced Defender for Office 365 Plan 2 functionality is not considered part
of the base Business Premium environment.

## Consequences

Benefits:

- More efficient use of trial periods.
- Clear capability boundaries.
- Better reproducibility.
- Reduced licensing ambiguity.
- Tests can identify when an add-on is required.

Tradeoffs:

- Some later features require an additional activation step.
- Capability validation must distinguish base and optional licensing.
