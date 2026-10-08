# ADR-0004: Shared Portfolio Laboratory Identity Model

- Status: Accepted
- Decision scope: Identity foundation
- Applies to: Synthetic Microsoft 365 laboratory identities

## Context

The Microsoft 365 tenant supports more than one independent portfolio
project.

Project-specific tenant identity names would unnecessarily couple the
shared laboratory to one repository.

The organization model also defines multiple departments and privilege
classes that require stable identities for later access-control and
security-operations testing.

## Decision

Tenant-visible human identities use neutral `Portfolio Lab` display names.

Tenant-visible security groups use the neutral `PLAB-` prefix.

This Zero Trust repository continues to use `ZT-LAB` as its internal
architecture identifier.

The identity foundation provides synthetic workforce coverage for all
departments represented in the organization model.

The bootstrap administrator is separate from the future permanent
privileged administrator.

Emergency identities are separate cloud-only identities and are excluded
from general workforce targeting.

Guest, workload, and permanent privileged-administrator live creation are
deferred until the feature responsible for their concrete use.

Pilot security groups are defined in Feature 3 but their memberships remain
owned by the later features that use them.

The actual tenant domain, complete live user principal names, Graph object
IDs, and credentials remain outside the tracked repository.

## Consequences

The same synthetic identities can support both the Zero Trust project and
the future Security Operations and Incident Response project.

Later features can target stable departments and personas without renaming
the underlying tenant identities.

Conditional Access and device pilot membership cannot be accidentally
preconfigured by Feature 3.
