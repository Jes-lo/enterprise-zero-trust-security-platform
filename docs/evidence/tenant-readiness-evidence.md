# Tenant Readiness Evidence Contract

## Purpose

This document defines what tenant-readiness information may enter the
repository.

It does not contain live tenant evidence itself.

## Raw evidence

Raw discovery output must be stored under:

`local-evidence/`

That path is intentionally excluded from Git.

## Prohibited repository fields

Published evidence must not contain:

- Tenant GUID
- Verified tenant domain
- Administrative user principal name
- User email address
- User object ID
- Authentication token
- Refresh token
- Device identifier tied to a real person
- Billing account identifier
- Payment information

## Permitted sanitized evidence

The repository may contain:

- Logical capability name
- Subscription SKU part number
- Service-plan name
- Provisioning status
- Purchased license count
- Consumed license count
- Number of discovered subscription SKUs
- Validation result
- Collection timestamp rounded or normalized when appropriate

## Publication rule

Raw command output is never promoted directly into `docs/evidence`.

A sanitized artifact must be reviewed before publication.

## Screenshot rule

A screenshot must be inspected before commit.

At minimum, review:

- browser address bar;
- account avatar;
- tenant switcher;
- tenant domain;
- user principal name;
- tenant ID;
- subscription identifiers;
- billing data;
- notification panels.

When in doubt, do not commit the screenshot.
