# Feature 7 — License and Temporary Access Cleanup

## Final licensing decision

The project does not activate or acquire:

- Microsoft Entra ID P2;
- Microsoft Entra ID Governance;
- any additional Microsoft license specifically for Feature 7.

No P2 trial-expiration dependency therefore exists.

## Controls not deployed

The following P2-dependent designs remain documentation-only:

- PIM eligible assignment for `PRIVILEGED_ADMIN_01`;
- PIM activation workflow;
- Identity Protection operational assessment;
- `PLAB-CA-005 - Require MFA for risky sign-ins`.

## Temporary audit-helper cleanup

The temporary Feature 7 audit mechanism is not part of the portfolio
implementation.

Final cleanup requires:

1. Remove the temporary Global Reader assignment from `AUDIT_READER_01`.
2. Revoke its active sessions.
3. Disable the temporary identity.
4. Remove the temporary identity after it is no longer required.
5. Remove any temporary isolated Graph application if it was created.
6. Remove temporary local collector files.

The shared Microsoft Graph Command Line Tools enterprise application is not
modified because its historical permissions are outside the provenance of this
feature.

## Preserved tenant state

Feature 7 does not intentionally change:

- Security Defaults;
- CA-001 through CA-004;
- emergency identities;
- `BOOTSTRAP_ADMIN`;
- the established P1-compatible privileged administration baseline.

## Evidence rules

Only sanitized state summaries belong in the repository.

Do not commit tenant identifiers, object identifiers, UPNs, credentials,
authentication tokens, MFA values, client identifiers or unredacted portal
screenshots.
