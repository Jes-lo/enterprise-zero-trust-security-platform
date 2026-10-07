# ADR-0002: Separate Productivity and Privileged Identities

## Status

Accepted

## Context

Using the same identity for normal productivity activity and high-impact
administration increases the consequences of compromise and makes the
security boundary less explicit.

## Decision

Laboratory personas requiring high-impact administration will use separate
privileged identities.

A normal workforce identity does not automatically inherit the privileges
of the corresponding administrative identity.

Emergency access identities will also remain separate from routine
privileged identities.

## Consequences

Benefits:

- Reduced exposure of administrative credentials.
- Clearer privilege boundaries.
- Easier policy testing.
- Better audit interpretation.

Tradeoffs:

- Additional identities must be managed.
- Administrative workflows require deliberate account switching.
