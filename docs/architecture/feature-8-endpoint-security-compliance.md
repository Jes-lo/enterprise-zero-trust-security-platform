# Feature 8 — Endpoint Security and Device Compliance

## Purpose

Feature 8 extends the Zero Trust lab from identity controls into managed-device
security using capabilities already available in Microsoft 365 Business
Premium.

No additional Microsoft license is acquired.

## Licensed capability baseline

The implementation is designed for the existing tenant capabilities:

- Microsoft Entra ID P1
- Microsoft Intune
- Microsoft Defender for Business

## Security model

Feature 8 introduces three connected controls:

1. Windows device compliance.
2. Microsoft Defender endpoint security posture.
3. Conditional Access consumption of device compliance state.

The tenant implementation is isolated through a dedicated pilot group:

`PLAB-Device-Pilot`

The pilot group starts with zero members.

No broad assignment to all users or all devices is allowed during initial
validation.

## Windows compliance baseline

The desired Windows compliance state requires:

- BitLocker;
- Secure Boot;
- code integrity;
- Trusted Platform Module;
- Windows Firewall;
- antivirus;
- antispyware;
- Microsoft Defender Antimalware;
- current Defender security intelligence;
- real-time protection.

A device becomes noncompliant after a one-day grace period.

No minimum Windows build is hard-coded in the repository because operating
system lifecycle requirements change over time and should be evaluated against
the current supported Windows release before enforcement.

## Defender baseline

The desired Defender for Business posture enables:

- real-time protection;
- cloud-delivered protection;
- behavior monitoring;
- potentially unwanted application protection in block mode;
- automatic security intelligence updates;
- network protection;
- tamper protection where supported by the licensed service and managed
  endpoint.

Exact portal setting names can evolve. This repository records the intended
security outcome rather than coupling the architecture to transient UI labels.

## Conditional Access integration

The desired policy is:

`PLAB-CA-006 - Require compliant device`

Initial state:

- Report-only
- included group: `PLAB-Device-Pilot`
- target resources: all resources
- grant requirement: compliant device
- no emergency identity is intentionally brought into the device pilot

The policy is never enabled before a managed pilot device has successfully
reported compliant.

## Device enrollment strategy

A dedicated Windows test endpoint is preferred.

The user's primary workstation is not required to participate in the pilot.
Enrollment of a personal production workstation must not be used merely to
satisfy portfolio evidence.

A pilot device, when available, is enrolled under an authorized lab identity
and evaluated against compliance and Defender controls before any broader
assignment.

## Implementation sequence

1. Validate repository design.
2. Create `PLAB-Device-Pilot` with zero members.
3. Create the Windows compliance policy.
4. Create the Defender endpoint baseline.
5. Assign both only to the empty pilot group.
6. Create CA-006 in Report-only.
7. Verify no broad assignments exist.
8. Enroll one dedicated Windows test endpoint when available.
9. Add only the intended pilot identity/device.
10. Validate compliance and Defender state.
11. Review CA-006 Report-only results.
12. Do not enable CA-006 as part of the initial Feature 8 pilot.

## Non-goals

Feature 8 does not:

- purchase additional licenses;
- deploy Microsoft Entra ID P2;
- enable PIM;
- wipe, retire or reset any device;
- require enrollment of the primary workstation;
- assign endpoint policies to all users or all devices;
- enable CA-006 during the initial pilot;
- modify CA-001 through CA-004;
- disable Security Defaults;
- weaken emergency access.

## Initial closure target

Feature 8 should demonstrate a validated endpoint-management architecture,
actual tenant-side policy configuration, pilot isolation and, when a dedicated
test endpoint is available, real compliance and Defender telemetry.
