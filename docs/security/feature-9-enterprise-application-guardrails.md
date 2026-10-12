# Feature 9 — Enterprise Application Security Guardrails

## Default posture

Feature 9 begins read-only and deny-by-default.

Creating the repository artifacts does not authorize a Microsoft Entra tenant
change.

## Prohibited during Feature 9A

Feature 9A must not:

- create an application registration;
- create or modify a service principal;
- add or remove delegated permission grants;
- add or remove application permissions;
- grant administrative consent;
- create client secrets;
- create certificate credentials;
- change user or group assignments;
- delete a service principal;
- modify Microsoft first-party enterprise applications.

## Permission governance

Every future permission decision must distinguish:

- delegated permission;
- application permission.

Permission expansion requires a separate review.

Broad directory access is not accepted merely because it simplifies
automation.

## Consent governance

Administrative consent is denied by default.

A future consent operation must be:

- explicit;
- narrowly scoped;
- independently reviewed;
- validated after the change;
- separately evidenced.

Consent must not be silently embedded in another write.

## Application ownership

Tenant-owned applications must have accountable ownership.

Ownerless tenant-owned applications require review before any new permission
or credential is added.

The project must not publish owner object IDs or real account names.

## Credential safety

Never commit:

- client secrets;
- private keys;
- passwords;
- access tokens;
- refresh tokens;
- certificate key material;
- raw authentication caches.

A future credential requirement must receive its own security design and
rotation plan.

## Discovery guardrails

The Stage 1 collector:

- requests `Application.Read.All`;
- performs GET requests only;
- emits sanitized aggregate counts only.

The Stage 2 collector:

- requests `Directory.Read.All`;
- performs GET requests only;
- emits sanitized aggregate counts only;
- requires a separate execution gate.

Neither collector performs tenant mutation.

## Privacy

Repository evidence must use generic names and aggregate counts.

Do not commit:

- tenant IDs;
- application/client IDs;
- object IDs;
- assignment IDs;
- real UPNs;
- tenant domains;
- raw Graph responses.

## Final Feature 9A rule

`TENANT_WRITES_AUTHORIZED=NO`

`ADMIN_CONSENT_AUTHORIZED=NO`

`APPLICATION_CREATION_AUTHORIZED=NO`

`CREDENTIAL_CREATION_AUTHORIZED=NO`

## Feature 9B consent-boundary finding

Feature 9B demonstrated that an otherwise GET-only workflow can still change
tenant authorization state during interactive OAuth consent.

Future live discovery must therefore treat a newly presented consent prompt as
a tenant authorization write boundary even when every Microsoft Graph resource
request is GET-only.

The Feature 9B collector must not be rerun automatically.

The project does not authorize `Directory.Read.All` for Feature 9C at this
stage. Avoiding another broad directory permission is the preferred
least-privilege outcome.
