# Microsoft 365 Business Premium Trial Activation Checklist

## Status

This checklist must be completed when Feature 2 moves from offline
preparation to the live laboratory tenant.

## Before activation

- [ ] Repository working tree is clean.
- [ ] Feature 2 branch is active.
- [ ] Repository security validation passes.
- [ ] Tenant bootstrap validation passes.
- [ ] A payment method will not be documented or captured in repository evidence.
- [ ] No employer or customer domain will be used.
- [ ] No production account will be used as a laboratory persona.
- [ ] A synthetic tenant naming choice has been prepared.

## Immediately after activation

- [ ] Record the trial start date locally.
- [ ] Record the trial expiration date locally.
- [ ] Disable recurring billing.
- [ ] Confirm that future automatic billing is disabled.
- [ ] Confirm the administrative account can sign in.
- [ ] Preserve emergency access planning before restrictive controls are introduced.
- [ ] Do not publish the initial tenant domain.
- [ ] Do not publish the tenant ID.

## Base capability verification

Verify that the tenant exposes the capabilities required for the base lab:

- [ ] Microsoft Entra ID P1
- [ ] Microsoft Intune Plan 1
- [ ] Microsoft Defender for Business
- [ ] Microsoft Defender for Office 365 Plan 1

The verification must be based on the live subscription and service-plan
inventory, not only on product marketing names.

## Deferred licensing

Do not activate Microsoft Entra ID P2 during initial bootstrap unless the
current feature explicitly requires it.

P2 is reserved for the later PIM and Identity Protection feature.

Do not activate Defender for Office 365 Plan 2 solely for Feature 2.

## Evidence handling

Allowed repository evidence:

- Sanitized capability names
- Sanitized license-state summaries
- Counts that do not identify real users
- PASS/FAIL validation results
- Redacted screenshots when necessary

Keep only outside Git:

- Tenant ID
- Initial tenant domain
- User principal names
- Authentication information
- Billing information
- Raw Graph exports
- Raw portal screenshots

## Completion criteria

Feature 2 can be considered complete only when:

1. The tenant is active.
2. Recurring billing has been disabled.
3. The base subscription is discoverable through read-only automation.
4. Required base capabilities have been verified.
5. Raw evidence remains outside Git.
6. Sanitized evidence has been generated.
7. Local and CI validation pass.
