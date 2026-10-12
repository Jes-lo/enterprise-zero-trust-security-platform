# Feature 8 — EDR Assignment Follow-up Sanitized Evidence

## Evidence classification

This document records the sanitized post-Phase-A Defender for Endpoint
tenant-side follow-up.

It intentionally excludes:

- tenant IDs;
- object IDs;
- assignment IDs;
- real UPNs;
- tenant domains;
- device IDs;
- tokens;
- credentials;
- onboarding blobs;
- raw Graph responses;
- unredacted screenshots.

## Historical boundary

The original Feature 8 Phase A evidence correctly recorded EDR as
`connector-deferred` because the required Defender/Intune integration was not
available at that closure point.

That historical evidence is preserved unchanged.

## Connector follow-up

A later controlled follow-up validated:

- mobile threat-defense connector count: 1;
- connector partner state: enabled;
- Windows connector state: enabled.

No additional Microsoft license or trial was introduced by this follow-up.

## EDR policy

The tenant-side policy is:

`PLAB-WIN-EDR-001 - Defender for Endpoint onboarding`

Validated sanitized observations:

- policy count: 1;
- setting count: 2;
- onboarding package source: connector-managed;
- sample sharing: all samples;
- deprecated telemetry-frequency setting: absent.

No onboarding package, tenant identifier or policy object identifier is stored
in the repository.

## Pilot assignment relationship

Before the controlled assignment action, reconciliation validated:

- policy assignment count: 0;
- policy `isAssigned`: false;
- pilot direct membership: 0;
- pilot transitive membership: 0;
- All Devices target: absent.

The controlled assignment action completed without a POST exception.

Direct relationship readback subsequently and repeatedly returned:

- policy assignment relationship count: 1;
- target type: group;
- target: `PLAB-Device-Pilot`;
- assignment source: direct;
- assignment filter: none;
- All Devices target: absent;
- pilot direct membership: 0;
- pilot transitive membership: 0;
- policy setting count: 2.

## Beta API readback inconsistency

During the same post-assignment observations:

- the direct configuration-policy `assignments` relationship repeatedly
  returned the pilot assignment;
- the policy `isAssigned` property remained false;
- an expanded `assignments` readback did not consistently reproduce the direct
  relationship;
- the returned assignment key was treated as an opaque string rather than
  assumed to be a GUID;
- an attempted narrow rollback did not complete successfully.

Because the direct relationship continued to show exactly one safe pilot
assignment, subsequent reconciliation was restricted to read-only operations.

The project does not conceal this difference and does not treat the beta status
field as authorization to repeat `/assign` or retry rollback.

## Safety outcome

Validated safety properties after the follow-up:

- `PLAB-Device-Pilot` remains empty;
- no All Devices EDR assignment is present in the observed direct relationship;
- no assignment filter is present;
- the EDR policy retains exactly two settings;
- no destructive device action was performed;
- no group membership change was performed;
- no CA-006 enforcement change was performed;
- no further assignment or rollback retry is authorized.

## Endpoint execution boundary

No dedicated Windows lab endpoint has been introduced for runtime validation.

Endpoint execution therefore remains:

`environment-deferred`

This evidence does not claim:

- device enrollment;
- successful real-device Defender onboarding;
- device compliance telemetry;
- Defender endpoint telemetry;
- endpoint policy application;
- CA-006 enforcement testing.

## Closure classification

`FEATURE8_EDR_FOLLOWUP=TENANT_CONFIGURED_PILOT_RELATIONSHIP_VALIDATED_WITH_BETA_READBACK_INCONSISTENCY`

`FEATURE8_ENDPOINT_EXECUTION=ENVIRONMENT_DEFERRED`

`FEATURE8_EDR_ASSIGNMENT_RETRY_AUTHORIZED=NO`

`FEATURE8_EDR_ROLLBACK_RETRY_AUTHORIZED=NO`
