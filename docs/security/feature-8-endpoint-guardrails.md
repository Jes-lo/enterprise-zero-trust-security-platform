# Feature 8 — Endpoint Security Guardrails

## Licensing

Feature 8 uses only capabilities already available in the current Microsoft 365
Business Premium subscription.

No additional Microsoft license, add-on or trial is authorized.

## Tenant isolation

Feature 8 uses:

`PLAB-Device-Pilot`

Validated Phase A membership count:

`0`

Compliance, Defender Antivirus, Tamper Protection and CA-006 are scoped to the
pilot boundary.

Broad Feature 8 assignment is prohibited.

## Conditional Access

`PLAB-CA-006 - Require compliant device` must remain Report-only during the
current Feature 8 state.

Enforcement is not authorized until:

- a dedicated pilot endpoint exists;
- enrollment succeeds;
- device compliance is understood;
- Defender posture is evaluated;
- access impact is reviewed;
- emergency access remains unaffected.

## Endpoint security

Validated tenant-side security posture includes:

- behavior monitoring enabled;
- cloud-delivered protection enabled;
- real-time protection enabled;
- network protection in block mode;
- PUA protection in block mode;
- security intelligence update interval of 4 hours;
- Tamper Protection On;
- Controlled Configuration not selected.

## EDR

Defender for Endpoint onboarding is `connector-deferred`.

Current validated state:

- prerequisite connector count: zero;
- EDR policy count: zero.

The project must not manufacture an EDR-complete claim while that prerequisite
is absent.

## Device safety

Feature 8 does not authorize:

- device wipe;
- retire;
- Autopilot reset;
- Fresh Start;
- remote lock;
- destructive remediation;
- BitLocker recovery-key deletion;
- removal of existing local recovery access.

A dedicated lab endpoint is preferred over the primary personal workstation.

## Existing tenant controls

Feature 8 is not authorized to intentionally modify:

- Security Defaults;
- CA-001;
- CA-002;
- CA-003;
- CA-004;
- `BOOTSTRAP_ADMIN`;
- emergency identities.

## Evidence safety

Do not commit:

- real UPNs;
- tenant domains;
- tenant identifiers;
- object identifiers;
- device identifiers;
- device serial numbers;
- hardware hashes;
- BitLocker recovery keys;
- access or refresh tokens;
- credentials;
- raw diagnostic bundles;
- unredacted screenshots.

Use aliases and sanitized state summaries only.

## Final Phase A rule

The controlled Feature 8 writer must not be rerun after the validated Phase A
state.

Further tenant changes require a new explicitly scoped implementation phase.
