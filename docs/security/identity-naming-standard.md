# Identity Naming Standard

## Objective

Identity names must clearly indicate laboratory purpose while avoiding
personal, customer, employer, or production naming.

## Human aliases

Synthetic human aliases include:

- bootstrapadmin
- privilegedadmin01
- employee01
- finance01
- sales01
- developer01
- itoperator01
- securityengineer01
- executive01
- contractor01
- emergencyadmin01
- emergencyadmin02

The repository stores aliases only.

The complete tenant user principal name is constructed locally and is not
published.

## Display names

Human display names use the `Portfolio Lab` prefix.

For example:

Portfolio Lab Security Engineer 01

## Security groups

Security groups use the `PLAB-` prefix.

Examples include:

- PLAB-Workforce
- PLAB-Human-Resources
- PLAB-Finance
- PLAB-Sales
- PLAB-Engineering
- PLAB-ITOps
- PLAB-Security
- PLAB-Executives
- PLAB-Contractors
- PLAB-CA-Pilot
- PLAB-Device-Pilot

Security groups also use deterministic non-sensitive mail nicknames.

## Privileged identities

The bootstrap account and permanent privileged-administrator persona are
different identities.

The bootstrap account is not intended to become the permanent privileged
administration account.

Standard productivity and privileged administration identities remain
separate.

## Emergency identities

Emergency accounts use dedicated aliases and are never reused for routine
administration.

They are cloud-only and excluded from workforce and pilot targeting.

## Prohibited repository values

Tracked files must not contain:

- the actual tenant domain;
- complete live UPNs;
- passwords or temporary passwords;
- recovery credentials;
- authentication tokens;
- personal recovery addresses;
- tenant-specific Graph object IDs;
- real employee or customer identities.
