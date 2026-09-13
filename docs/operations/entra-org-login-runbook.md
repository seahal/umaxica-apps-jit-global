# Entra ID Org login runbook

This runbook covers the human configuration required before enabling the Org Entra login ceremony.
It does not contain credentials or tenant identifiers.

1. Create a Microsoft Entra application registration in the company tenant, for organizational
   accounts only. Do not select an account type that includes personal Microsoft accounts. The org
   surface federates this single tenant (`adr/org-entra-single-tenant-credential-configuration.md`).
2. Register the callback URI `https://<org-auth-host>/social/entra/callback`. This must match
   `ExternalAuthenticationEntraRedirectUri::CALLBACK_PATH` exactly; a mismatch produces AADSTS50011
   at Microsoft. Confirm the host is the Org authentication host, not a request-derived or preview
   host. `entra` is the provider segment used throughout this application and matches the wider
   ecosystem (the `omniauth-entra-id` gem's strategy name, Auth.js's `microsoft-entra-id`); a
   `microsoft` segment is not used anywhere in this codebase. Then remove any other redirect URI on
   the registration — a stale entry the application never serves is an unused, permanently
   registered redirect target.
3. Create a client secret and store it in Rails credentials as `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET`.
   Store the directory (tenant) id as `OMNI_AUTH_ENTRA_ORG_TENANT_ID` and the application (client)
   id as `OMNI_AUTH_ENTRA_ORG_CLIENT_ID`. All three are required at boot outside development and
   test; a missing one fails the boot naming the key, and the tenant and client ids must be UUIDs
   (so `common`, `organizations` and `consumers` are rejected). Boot checks presence and shape only
   and makes no call to Microsoft; the preflight below does the semantic checks. No credential value
   is printed, and no Entra secret is stored in the database.
4. Add the optional `acct` claim to ID tokens. The Rails verifier requires `acct = 0` and rejects
   guests or tokens without this claim.
5. Review API permissions. The login flow requests `openid profile` only and does not require
   Microsoft Graph permissions. Remove any unnecessary Graph permission added during registration.
6. Pre-provision an `OperatorEntraIdentity` for each operator. See "Provisioning an operator" below.
   There is **no JIT provisioning**: an operator without one cannot sign in. There is no UI; the
   rake tasks below are the supported path.
7. Perform E2E validation for a pre-provisioned active operator, an unknown identity, a suspended
   identity, cancelled authorization, invalid state, invalid nonce, and kill-switch drain behavior.
   See "Live sign-in smoke test" below.
8. Test the `social_ceremony_org_entra` kill switch: new ceremonies must stop while a callback for
   an already-issued ceremony is allowed to drain.

The release gate remains incomplete until the production E2E evidence and tenant-specific
administrator-consent evidence are recorded.

## Provisioning an operator

`tid + oid` is the only thing that identifies a person to this ceremony. Do not derive an operator
from an email address, UPN, domain, or display name: all of them are mutable in Entra, and none of
them are read by the sign-in path.

1. Read the operator's Entra **Object ID** in the Entra admin center under Users → the user → Object
   ID. It is a UUID and is stable for the lifetime of that user object in the tenant. The tenant is
   not an input: it comes from `OMNI_AUTH_ENTRA_ORG_TENANT_ID` so that no administrator can bind an
   operator to a tenant this deployment does not federate.
2. Read the UMAXICA operator's `public_id` from the operator record. Hyphenated and lower-case forms
   are accepted.
3. Create the mapping. It is created **inactive**, and creating it does not permit sign-in:

   ```bash
   bin/rails entra_identity:provision OPERATOR=<operator_public_id> OID=<entra_object_id>
   ```

4. Permit sign-in as a separate, deliberate act:

   ```bash
   bin/rails entra_identity:activate OPERATOR=<operator_public_id>
   ```

5. Confirm the result:

   ```bash
   bin/rails entra_identity:status
   ```

To stop an operator's Entra sign-in without losing the mapping or its audit evidence, use
`entra_identity:suspend`; use `entra_identity:revoke` to withdraw it permanently. Both take effect
on the next sign-in attempt. Neither task deletes a record, and no task prints a credential.

## Joiners and leavers

Offboarding through `OperatorLifecycleRequest` already carries the Entra mapping with it, so these
tasks are for one-off changes, not for routine staff movement:

- `withdraw` (leaving, with a 31-day window to change their mind) and `suspend` (a leave of absence
  or a disciplinary suspension, with no deletion at all) both set the mapping to suspended;
  `terminate` sets it to revoked. All three are logical deletes: the row keeps its `(tid, oid)`,
  protocol evidence, and `last_authenticated_at` so the mapping stays auditable.
- `restore` deliberately does **not** re-grant Entra sign-in. Restoring an operator returns their
  own credentials; a federated sign-in is a separate decision and needs an explicit
  `entra_identity:activate`.
- The row is deleted for real when the operator's retention window expires and the purge removes
  them (`RetentionCrossDatabaseChildPurge`).
- A rehire is a new operator and is provisioned from scratch. Until the purge has removed the
  withdrawn mapping, its `(tid, oid)` is still claimed and `entra_identity:provision` refuses with a
  message saying so — wait for the purge rather than editing rows by hand.

The tasks refuse rather than overwrite: an operator may hold at most one Entra identity, and an
Entra object may be mapped to at most one operator. Repointing an existing mapping is an identity
change, not a provisioning step, so a mistyped `OPERATOR` fails instead of silently moving an
account.

## Live sign-in smoke test

The ordinary test suite never contacts Microsoft. This procedure does, and is run by hand.

1. Run the preflight. It checks credential presence and shape (never values), the redirect URI, the
   kill switch, the issuer the tenant actually advertises, and whether anyone is provisioned:

   ```bash
   bin/rails entra_identity:preflight
   ```

   Every check must pass before continuing; each failure names its own cause. The preflight fetches
   the tenant's OpenID configuration purely to compare issuers — the ceremony itself keeps Discovery
   disabled and derives its endpoints from the pinned tenant. The output is safe to paste into a
   note: it reports the secret by length only and never echoes an issuer, matching or not, because
   every issuer embeds the tenant id. The redirect URI is printed in full, which is the point — it
   is a public URL and must be compared character for character with the registration.

2. Confirm the org auth host reaches this deployment. `auth/org` is deliberately **not** behind
   Cloudflare Access (`docs/security/cloudflare-access-org-authentication.md`), so Microsoft's
   redirect must land on Rails and not on an Access login page.

3. In a browser, open `/settings/entra/edit` on the org auth host and press **Connect**, or go to
   `/social/entra/session/new` directly. Complete the Microsoft sign-in with the account whose
   Object ID was provisioned above.

4. A successful sign-in lands in the org sign-in sequence. Confirm the record moved:

   ```bash
   bin/rails entra_identity:status
   ```

   `last_authenticated_at` for that identity must no longer be `never`.

5. Run the negative cases, each of which must fail closed and reach `/social/entra/failure`: an
   account that is not provisioned; a suspended identity (`entra_identity:suspend`, retry, then
   `entra_identity:activate`); cancelling at the Microsoft consent screen; and re-issuing an already
   used callback URL, which must be rejected as `csrf_detected` because state is single use.

6. Test the kill switch: `bin/rails social_ceremony:disable[entra]` must stop new ceremonies at the
   entry point while a callback for an already-issued ceremony drains, then
   `bin/rails social_ceremony:enable[entra]`.

Record the outcome as release-gate evidence. Do not paste a token, code, state, nonce, secret, or
Entra profile field into that record; the identity `public_id` and the check names are enough.

## Client secret rotation

1. Create a second client secret on the same Entra application registration. Do not delete the
   existing one yet — Entra allows more than one to be valid at a time.
2. Update `OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET` in Rails credentials to the new value and deploy.
   Never place the secret in the database, source control, fixtures, logs, or this runbook.
3. Keep the old secret valid in Entra during a short overlap window to absorb in-flight
   authorization ceremonies issued before the rotation. Confirm no callback failures reference a
   token-exchange error before proceeding.
4. Delete the old secret in Entra once the overlap window has passed.
5. Record the rotation date and the operator who performed it in the approved secret-management
   boundary, not in this runbook.
