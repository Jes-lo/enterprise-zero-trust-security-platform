# Feature 8 — Endpoint Security and Device Compliance

## Purpose

Feature 8 extends the Zero Trust lab from identity controls into managed-device
security using capabilities already available in Microsoft 365 Business
Premium.

No additional Microsoft license or trial is required or authorized.

## Licensed capability baseline

The tenant-side design uses the capabilities already available to the lab:

- Microsoft Entra ID P1;
- Microsoft Intune;
- Microsoft Defender for Business.

Microsoft Entra ID P2, Microsoft Entra ID Governance, PIM and additional
Microsoft licensing are outside Feature 8.

## Isolation model

Feature 8 uses the dedicated security group:

`PLAB-Device-Pilot`

The final Phase A tenant audit validated:

- exactly one pilot group;
- zero pilot-group members;
- no broad Feature 8 assignment;
- no requirement to enroll the primary personal workstation.

The empty pilot group provides a controlled boundary between configuration and
endpoint rollout.

## Phase A tenant implementation

Tenant-side Phase A is implemented and independently validated through
read-only Microsoft Graph reconciliation.

Validated state:

- Windows compliance policy: implemented and assigned to the pilot group;
- Defender Antivirus policy: implemented and assigned to the pilot group;
- Tamper Protection policy: implemented and assigned to the pilot group;
- CA-006: implemented in Report-only and scoped to the pilot group;
- Defender for Endpoint onboarding policy: deferred during the original
  Phase A because the Defender/Intune connector was not yet present;
- pilot group membership: zero.

Phase A completed without fabricating the missing EDR prerequisite. A later,
separately gated EDR follow-up enabled the existing Defender/Intune integration,
created the EDR onboarding configuration and established an assignment
relationship only to the still-empty pilot group.

## Windows compliance baseline

The implemented Windows compliance policy requires:

- BitLocker;
- Secure Boot;
- code integrity;
- Trusted Platform Module;
- Windows Firewall;
- antivirus;
- antispyware;
- Microsoft Defender Antimalware health;
- current Defender security intelligence;
- real-time protection.

The final audit also validated:

- exactly one target compliance policy;
- exactly one pilot assignment;
- default scope tag;
- exactly one scheduled noncompliance rule;
- exactly one scheduled action;
- action type `block`;
- grace period of 24 hours.

Microsoft Graph omitted `ruleName` from the expanded readback. The schedule was
therefore validated from its actual rule/action cardinality, block action and
24-hour grace period rather than falsely treating the omitted field as an
implementation failure.

No minimum Windows build is hard-coded in the repository.

## Defender Antivirus baseline

The implemented Defender Antivirus policy contains exactly six validated
settings:

1. behavior monitoring: enabled;
2. cloud-delivered protection: enabled;
3. real-time protection: enabled;
4. network protection: block;
5. potentially unwanted application protection: block;
6. security intelligence update interval: 4 hours.

The final audit compared the actual tenant values with the same
tenant-discovered setting definitions used by the controlled implementation.

## Tamper Protection

Tamper Protection is implemented through the Windows Security Experience
policy.

The final audit validated:

- exactly one Tamper Protection policy;
- exactly one setting;
- only the pilot-group assignment;
- `Tamper Protection (On)` selected;
- `Configuration Protection (On)` not selected.

The underlying tenant definition is represented by
`ControlledConfiguration`; the repository records the security outcome instead
of exposing tenant-specific definition identifiers.

## Conditional Access integration

The implemented policy is:

`PLAB-CA-006 - Require compliant device`

Validated state:

- Report-only;
- included group: `PLAB-Device-Pilot`;
- target resources: all resources;
- grant requirement: compliant device;
- enforcement not authorized by Feature 8.

CA-006 must remain Report-only until a dedicated pilot endpoint is enrolled,
evaluated and its access impact is reviewed.

## Defender for Endpoint onboarding

The policy is:

`PLAB-WIN-EDR-001 - Defender for Endpoint onboarding`

The original Phase A state was `connector-deferred`. The subsequent controlled
EDR follow-up validated the prerequisite integration and then created the
tenant-side policy.

Current sanitized tenant observations:

- Defender/Intune mobile threat-defense connector count: one;
- connector partner state: enabled;
- Windows connector state: enabled;
- EDR policy count: one;
- EDR setting count: two;
- onboarding package source: connector-managed;
- sample sharing: all samples;
- assignment relationship count: one;
- assignment target: `PLAB-Device-Pilot` only;
- assignment filter: none;
- pilot direct membership: zero;
- pilot transitive membership: zero;
- All Devices target: absent.

The beta configuration-policy `assignments` relationship repeatedly returned
the exact pilot assignment. During the same observations, the policy
`isAssigned` property remained `false`, and an expanded assignments readback
did not consistently reproduce the relationship. These beta-API status
differences are recorded as an observed readback inconsistency rather than
being hidden or treated as permission to repeat the assignment operation.

The assignment writer must not be rerun. No further EDR tenant write is
required by the current Feature 8 closure.

## Endpoint validation

A dedicated Windows lab endpoint was not available for the completed Phase A
tenant validation.

Endpoint execution is therefore:

`environment-deferred`

The project does not claim:

- device enrollment;
- device compliance telemetry;
- Defender endpoint telemetry;
- CA-006 enforcement testing.

Those activities require a suitable dedicated pilot endpoint and are separate
from the validated tenant-side Phase A configuration.

## Safety boundaries

Feature 8 does not authorize:

- device wipe;
- retire;
- Autopilot reset;
- Fresh Start;
- remote lock;
- destructive remediation;
- BitLocker recovery-key deletion;
- broad user or device assignment;
- CA-006 enforcement;
- changes to Security Defaults;
- changes to CA-001 through CA-004;
- additional Microsoft licensing.

## Closure classification

Feature 8 Phase A status:

`tenant-implemented-and-validated`

Current closure state:

- tenant-side EDR configuration: implemented;
- EDR pilot assignment relationship: observed and validated against the direct
  assignments relationship;
- broad EDR assignment: absent;
- dedicated endpoint validation: `environment-deferred`;
- real endpoint onboarding/telemetry claim: not made.

The original Phase A final audit was read-only. The later EDR follow-up used
controlled tenant writes followed by read-only reconciliation. The final
repository closure performs no tenant mutation.
