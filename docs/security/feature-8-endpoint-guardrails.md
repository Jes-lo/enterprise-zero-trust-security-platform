# Feature 8 — Endpoint Security Guardrails

## Licensing

Feature 8 uses only capabilities already available in the current Microsoft 365
Business Premium subscription.

No additional Microsoft license or trial is authorized.

## Tenant isolation

Initial implementation must use:

`PLAB-Device-Pilot`

The group starts with zero members.

Do not initially assign endpoint or compliance policies to:

- all users;
- all devices;
- emergency identities;
- unrelated administrative identities.

## Device safety

The project does not authorize:

- device wipe;
- retire;
- Autopilot reset;
- Fresh Start;
- remote lock;
- destructive remediation;
- BitLocker recovery-key deletion;
- removal of existing local recovery access.

A dedicated test endpoint is preferred over the user's primary workstation.

## Conditional Access safety

`PLAB-CA-006 - Require compliant device` must initially remain Report-only.

Do not enable CA-006 until:

- a pilot endpoint is enrolled;
- its compliance state is understood;
- Defender posture is validated;
- impact is reviewed;
- emergency access remains unaffected.

## Existing tenant controls

Feature 8 does not intentionally modify:

- Security Defaults;
- CA-001;
- CA-002;
- CA-003;
- CA-004;
- `BOOTSTRAP_ADMIN`;
- emergency identities.

## Evidence safety

Do not commit:

- UPNs;
- device serial numbers;
- hardware hashes;
- tenant identifiers;
- device identifiers;
- recovery keys;
- tokens;
- credentials;
- raw diagnostic bundles;
- unredacted screenshots.

Use aliases and sanitized state summaries only.
