# Tenant Bootstrap and Licensing Validation

## Purpose

Feature 2 establishes the Microsoft 365 laboratory tenant in a controlled,
reproducible, and privacy-preserving manner.

The tenant exists exclusively for the `ZT-LAB` portfolio environment.

It must not contain production, customer, employer, or otherwise
confidential organizational data.

## Bootstrap phases

The tenant bootstrap process is divided into four phases.

### Phase A — Offline preparation

Before activating any trial:

- Define the expected subscription capabilities.
- Define evidence handling rules.
- Prepare read-only discovery automation.
- Validate repository safeguards.
- Confirm that no real organizational information is required.

### Phase B — Subscription activation

Activate Microsoft 365 Business Premium only after the offline foundation
has passed repository validation.

Immediately after activation:

1. Confirm access to the Microsoft 365 admin center.
2. Confirm the trial expiration date.
3. Attempt to disable recurring billing without terminating the active trial.
4. If the tenant offers only immediate cancellation, preserve the active
   laboratory period and document manual cancellation before expiration.
5. Maintain at least a one-day cancellation safety margin.
6. Record subscription state only in local evidence.
7. Do not publish billing or payment information.

### Phase C — Capability discovery

The project must discover actual tenant licensing rather than assuming that
display names or internal service identifiers will remain constant.

The discovery process records:

- Subscription SKU identifiers
- Enabled service-plan names
- Service-plan provisioning status
- License quantities
- High-level tenant readiness counts

Raw identifiers tied directly to the tenant are excluded from repository
evidence.

### Phase D — Validation

Observed capabilities are compared with the logical capabilities required by
the project.

The base environment is expected to support:

- Microsoft Entra ID P1
- Microsoft Intune Plan 1
- Microsoft Defender for Business
- Microsoft Defender for Office 365 Plan 1

Capabilities requiring additional licensing are activated only when their
feature is reached.

## Licensing strategy

The project intentionally avoids activating every available trial at the
beginning.

Microsoft Entra ID P2 is deferred until the feature that exercises
Privileged Identity Management and Identity Protection.

Advanced Defender for Office 365 Plan 2 capabilities are outside the base
Business Premium scope and are reserved for later security-operations work.

This staged approach:

- reduces unnecessary trial consumption;
- makes licensing assumptions explicit;
- improves reproducibility; and
- prevents a successful test from accidentally depending on an undocumented
  add-on.

## Tenant identity handling

The repository must not contain:

- tenant IDs;
- verified tenant domain names;
- administrator user principal names;
- authentication tokens;
- recovery codes;
- billing identifiers;
- payment information;
- raw screenshots containing those values.

Synthetic display labels may be used in published documentation.

## Automation boundary

Discovery automation is read-only.

Feature 2 does not use automation to modify:

- users;
- groups;
- licenses;
- Conditional Access;
- authentication methods;
- devices;
- enterprise applications;
- security policies.

Configuration changes belong to later features with their own tests and
approval boundaries.

## Microsoft Graph authentication boundary

The tenant-readiness collector uses delegated Microsoft Graph
authentication with `LicenseAssignment.Read.All`.

This permission is limited to the licensing information required by the
tenant-readiness workflow.

`Directory.Read.All` and `Organization.Read.All` are intentionally not
requested by the collector.

The collector uses `ContextScope Process`, limiting the Microsoft Graph
authentication context to the current PowerShell process rather than
persisting that context for future PowerShell sessions.

This process scope does not restrict Microsoft Entra identities, roles, or
future laboratory personas. Other users can authenticate independently with
permissions appropriate to their own test scenario.

The collector explicitly disconnects from Microsoft Graph when execution
finishes.
