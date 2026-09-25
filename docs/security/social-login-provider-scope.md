# Social Login Provider Scope

> **Partially superseded by Identity Authority inversion:** The provider availability vocabulary in
> this document remains useful only where it does not assign account linking, account lifecycle,
> session, token, or freshness authority to `sign/id`. `acme/www` is the Session, Token, Account,
> Preference, Authorization, and downstream-token Authority. `sign/id` is ceremony-only. Existing
> sign-side physical tables/models do not imply sign-side authority. Do not use this document to
> reintroduce sign-side sessions, refresh, preference, dashboard, account lifecycle, token issuance,
> logout, or step-up freshness.

Social login availability is surface-specific.

## Production Target

| Surface | Google   | Apple    | Microsoft Entra ID                          | Other external social providers     |
| ------- | -------- | -------- | ------------------------------------------- | ----------------------------------- |
| `app`   | Allowed  | Allowed  | Rejected                                    | Rejected unless accepted separately |
| `org`   | Rejected | Rejected | Allowed (org-only Umaxica OmniAuth strategy) | Rejected                            |
| `com`   | Rejected | Rejected | Rejected                                    | Rejected                            |

## Rules

- `app` may offer Google and Apple social login for end users.
- `org` may offer only Microsoft Entra ID as its external identity provider. It uses the accepted
  Umaxica-specific OmniAuth strategy and the org-only `/social/entra` request, callback, and failure
  paths. `OmniAuthSocialProviderHostMatrix` permits that provider on org while keeping Google and
  Apple app-only and all external providers unavailable on com. The retired
  `OmniAuthNonAppSocialGuard` is not the current policy.
- Org Entra sign-in is a first stage, not a completed session: the callback resolves a
  pre-provisioned `(tid, oid)` identity and starts the actor-bound local completion stage. It does
  not perform JIT provisioning or establish a session. Passkey is the normal completion method;
  the existing Secret/SecretKey path supports a lost-passkey case. Org does not use TOTP. See
  `adr/org-entra-omniauth-strategy-migration.md`, `adr/org-entra-id-sign-in-boundary.md`, and
  `docs/security/org-emergency-access.md` for the strategy and ceremony boundaries.
- The org Entra entry page is `GET /social/entra/session/new`; its CSRF-protected form submits to
  `POST /social/entra/session`, which applies the surface policy and hands the same POST to the
  OmniAuth request phase at `POST /social/entra` with a 307. The callback is
  `GET /social/entra/callback`, and `GET /social/entra/failure` is the org-specific failure path.
  The Entra app registration must contain the configured staff-host callback URI before live Entra
  sign-ins can complete; that provider registration is external to local repository changes.
- `com` must not offer or accept any external provider, including Entra ID.
- Direct OmniAuth requests follow the same provider/surface matrix as the UI; a hidden button does
  not authorize a request path.
- On `app`, an unknown Google or Apple identity is a sign-up entry, not a completed login. It must
  go through the sign-up sequence and required checkpoint setup before it can enter the login
  sequence.
- On `app`, a registered Google or Apple identity enters the login sequence. It must not be treated
  as a new sign-up unless required sign-up setup is still incomplete.
- On `app`, a session-limit pending social login resumes at `/sign/in/limitation` with a
  `social_resolution` payload on the Acme surface.
- On `app`, linking Google or Apple from account configuration requires recent token-bound Step-Up
  scope `social_link`. This is separate from `social_unlink`, so a Step-Up completed for one social
  credential operation does not authorize the other.
- Do not add Google, Apple, or another external provider to `org` or `com` without a new accepted
  ADR. Org Entra is the sole current org exception, governed by
  `adr/org-entra-omniauth-strategy-migration.md` and the non-superseded decisions in
  `adr/org-entra-id-sign-in-boundary.md`.

## Withdrawn Temporary Gateway

The 2026-06-02 temporary Google gateway exception for `org` and `com` is withdrawn. The old org/com
Google provider IDs and environment flags are not production provider/configuration names. The
cleanup removes their routes, UI, provider registration, temporary provisioners, and retirement
tags. Historical schema cleanup, if needed, requires a separate migration plan.
