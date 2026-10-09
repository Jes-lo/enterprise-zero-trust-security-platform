# Feature 7 — Validation Plan

## Repository validation

The repository must verify:

- PIM pilot targets only `PRIVILEGED_ADMIN_01`.
- The PIM target role is Privileged Role Administrator.
- Activation maximum duration is one hour.
- MFA and justification are required.
- Approval is disabled for the isolated lab pilot.
- Eligible assignment duration is seven days.
- Identity Protection policy remains Report-only.
- Emergency identities are excluded from the risk pilot.
- No P2-dependent enforcement is declared.
- No credential material is introduced.

## Tenant validation when P2 is activated

### PIM

Validate in this order:

1. P2 entitlement is active.
2. PRA role settings match the declared configuration.
3. `PRIVILEGED_ADMIN_01` becomes eligible.
4. Eligible assignment has the intended expiration.
5. Activation requires MFA.
6. Activation requires justification.
7. Activation is limited to one hour.
8. Activated PRA functionality is confirmed.
9. The previous standing active PRA assignment is removed only after the prior
   steps succeed.
10. The activation expires.
11. The identity is no longer active after expiration.

### Identity Protection

Validate:

1. Identity Protection becomes available only after P2 is established.
2. CA-005 exists only if the P2 pilot is authorized.
3. CA-005 state is Report-only.
4. `EMPLOYEE_01` is the pilot target.
5. Both emergency identities are excluded.
6. Medium and high sign-in risk are selected.
7. MFA is the grant control.
8. No enforcement cutover occurs.

## Regression validation

Feature 7 completion requires:

- repository validation PASS;
- Feature 7 validation PASS;
- adversarial repository tests PASS;
- clean working tree before merge;
- clean main after merge.
