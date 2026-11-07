# Visa RP logout revocation dead end

## Status

Open. F-1 is resolved by the narrow APP and ORG revocation API boundary change recorded below.
The separate OP-confirmation-first redesign remains open. The observation below was made on
2026-11-07 in the development environment (HEAD `271673747d`).

## Symptom

After a Base APP sign-out, a later sign-in from Base ends at `https://www.umaxica.app/sign/interruption`
and keeps doing so on every retry. Clearing the `visa.umaxica.app` cookies, or completing the Visa
logout confirmation, is expected to recover the browser (not yet verified).

## Observed sequence (development log)

1. Sign-in succeeds and Visa creates an RP Session (`OpAppGrant`, client `base-app-ww`).
2. `Base::App::SignOutsController#create` calls `Visa::App::Oauth::RevocationsController#create`
   server to server. Visa refuses it before client authentication:
   `security.csrf.request_blocked ... sec_fetch_site: missing`, `422`, then
   `auth.sign_out.rp_refresh_revocation_unavailable client_id=base-app-ww outcome=rejected`.
   Every revocation call in the 2026-11-07 log returned 422.
3. Base hands off to Visa `/oidc/logout`, which renders the confirmation page (200). No confirmation
   POST followed; the next request was Base `/sign/out/edit` (consistent with browser Back; inferred).
   The Visa Browser Session therefore stays active.
4. The next Base sign-in reaches `Visa::App::Oauth::AuthorizationsController#show`;
   `authorization_session_sufficient?` is true, so Visa answers with `silent_sso` and issues a code
   without visiting Auth.
5. Base exchanges the code at `/oauth/token`: `400`, because
   `OidcTokenExchangeCoordinator#create_or_resolve_active_usage!` finds the unretired RP Session for
   the same Browser Session and client and raises `RpSessionAlreadyExists`
   (`app/services/oidc_token_exchange_coordinator.rb` around line 1203). Base records
   `oidc.rp.callback.failed reason=token_exchange_failed` and redirects to `/sign/interruption`.

Development database evidence: the latest `OpAppGrant` rows for `base-app-ww` were `revoked_at = nil`
and `retirement_pending? = true` (ids 13 and 17 on the two occurrences). A row with `revoked_at = nil`
never stops being retirement-pending, so the dead end does not expire by itself.

## Findings

- **F-1 (resolved 2026-11-07).** At observation time the APP and ORG revocation leaves inherited
  browser forgery protection, which rejected the RP's server-to-server RFC 7009 request before
  client authentication. The owner resolved this by moving only those two leaves to
  `ActionController::API` under D-59. They authenticate the registered client credentials and do not
  use browser cookies or session state as authority. The ORG `/oauth/token` leaf remains on its
  forgery-protected browser base and is a separate residual.
- **F-2 (internal inconsistency).** Visa authorize decides silent SSO without checking the
  one-RP-Session-per-Browser-Session-and-client rule that the token endpoint enforces, so it issues a
  code it will refuse to exchange (inferred from the issued code; the authorize code path has not
  been read for that check). This rule is repository-specific, not an OIDC requirement.
- **F-3 (by design).** The Visa logout confirmation follows OIDC RP-Initiated Logout 1.0, which says
  the OP SHOULD ask the End-User. Leaving the page leaves the OP session active.
- **F-4 (by design).** The Visa Browser Session is the Root authority for all first-party RPs
  (`docs/security/session-token-authority.md`, `adr/visa-op-host.md`); lifetimes are in
  `app/values/security_token_lifetimes.rb` (access 5 minutes, APP refresh 30 days, idle 8 hours).
  OIDC does not prescribe OP session length.

## Options discussed before the F-1 decision

1. Rely on users completing the Visa logout confirmation (current behavior; owner's interim choice
   on 2026-11-07).
2. Make the dead end recoverable: when the token exchange fails with `RpSessionAlreadyExists`, offer
   a Visa logout path from `/sign/interruption`.
3. Retire the old RP Session at token exchange instead of refusing (changes the one-RP-Session rule;
   needs a replay/takeover review).
4. Send `Sec-Fetch-Site` from Base to satisfy the CSRF check (not recommended: imitates a browser).
5. Move the APP and ORG revocation controllers off the browser forgery-protected base class, keeping
   client authentication as the control. Implemented for F-1 under D-59 by the 2026-11-07 owner
   decision below.
6. Shorten the Visa Browser Session (an ADR-level change; removes cross-RP SSO and RP refresh, and
   does not fix F-1/F-2).
7. Fix F-2 so authorize falls back to an interactive Auth ceremony when an unretired RP Session
   exists for the same Browser Session and client.

## Separate OP-confirmation-first direction (open)

A prior owner discussion proposed the following direction:

- The RP starts sign-out by sending the browser to the Visa end-session endpoint; a plain link is
  enough. It does not end its own session or call RFC 7009 revocation at that point, so the start
  changes no state and needs no CSRF protection of its own: a forced start only shows Visa's
  confirmation. The state-changing step is the confirmation POST at Visa, which keeps its existing
  CSRF protection.
- Visa asks for the single confirmation (OpenID Connect RP-Initiated Logout 1.0: the OP SHOULD ask,
  and MUST ask when no valid `id_token_hint` is sent; the RP still sends none). On confirmation Visa
  stops the browser's root and its grants and notifies every RP through Back-Channel Logout; each RP
  ends its own session on receipt. Declining or leaving changes nothing.
- Visa then returns to the RP's registered `post_logout_redirect_uri` (the one-use completion page).
- There is no separate RP confirmation page (`/sign/out/edit`).

This direction remains open and outside the API boundary change. It would reverse the D-59 amendment of
`adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` (RP-local
sign-out first, then revocation, then an independent OP-wide confirmation) back toward its
2026-10-16 "commit at the OP" decision, so that ADR must be amended before code changes. Both shapes
conform to the specifications; this one is the canonical RP-Initiated plus Back-Channel Logout model
and removes F-1 from the sign-out path and the dead end of F-3.

Open questions for the plan:

- Back-Channel Logout delivery is an after-commit job today; the bounded first attempt is deferred to
  WU-18. Decide how long an RP session may outlive the confirmation and how delivery failure is
  surfaced.
- Whether the RP completion page must wait for, or only follow, Back-Channel Logout delivery.
- Route and test disposition of the RP confirmation pages and the RP-side revocation call.
- Acceptance: confirm, decline, leave, delivery failure and repeat submission, each with RP and OP
  state asserted through public requests, for APP and ORG.

## Owner decision and next step

### Owner decision (2026-11-07): resolve F-1 under D-59

F-1 is resolved by implementing the APP and ORG revocation leaves as protocol endpoints authenticated
by client credentials. D-59 remains in force: each RP commits its local sign-out, attempts RFC 7009
revocation of only its grant, and then starts the independent Visa confirmation flow. The
OP-confirmation-first direction above remains open and is not part of this decision. The ORG
`/oauth/token` endpoint remains on its existing forgery-protected base as a known residual; this
decision does not change it.

The current protocol boundary and its limits are described in
[`logout-session-management.md`](../../docs/security/logout-session-management.md).
