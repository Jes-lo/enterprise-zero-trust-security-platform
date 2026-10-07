# ADR-0001: Laboratory Boundary and Synthetic Data

## Status

Accepted

## Context

The project demonstrates enterprise security controls and will eventually
publish selected implementation evidence as part of a professional
portfolio.

Using real organizational information would introduce unnecessary privacy,
security, confidentiality, and ownership risks.

## Decision

The project will operate exclusively with synthetic organizational data and
systems owned or explicitly authorized by the project owner.

The laboratory identifier is `ZT-LAB`.

No real employer, customer, or production data will be used as part of the
published project.

## Consequences

Benefits:

- Reduced privacy risk.
- Reduced confidentiality risk.
- Clear separation from employer intellectual property.
- Safer public documentation.
- Reproducible test scenarios.

Tradeoff:

The environment models enterprise behavior but does not represent every
constraint of a production organization.
