# Sign Neutral Entry and Logout Target Authorization

## Status

Accepted (2026-10-02)

Amends `adr/logout-ceremony-boundary.md` for RP-initiated logout target selection. Supersedes the
logged-in direct-entry redirect described in `app/controllers/auth/app/sign/ups_controller.rb` and
the context-free Auth-to-Base bridge (`app/controllers/concerns/auth_ceremony_admission.rb`) once the
P3 migration in `plans/active/sign-fqdn-integrated-plan.md` lands; until then the current code is
the state being migrated from, not a competing contract.

## Context

RP entry, Auth, and Base each decided differently what an already-authenticated browser gets when
it starts a new Sign: a dashboard redirect, 403 with fixed text, 409, or a silently issued
authorization code. Separately, Base RP-initiated logout took the `sid` from a verified
`id_token_hint` as the session to revoke even when the browser presenting it had no session; a test
confirmed that this ended another subject's session (D1, `evidence/2026-10-02-sign-p0-baseline-d1-T5N3.md`).

## Decision

1. The normal entry is the neutral `GET /sign` (display only) and `POST /sign` (start). RPs offer
   no Sign in / Sign up choice and send no `intent=sign_up`, `screen_hint=signup`, or
   `prompt=create` on a normal start. Auth opens on `/sign/in`; registration is reached inside Auth
   where offered. Base owns eligibility, result receipt, and session issuance.
2. A new Sign from a browser that the RP or Base can verify as authenticated is refused with shared
   i18n `403 text/plain` and `Cache-Control: no-store`, without `Location`, links, logout guidance,
   retry, or any change to the existing session. This applies at Base as well as at RPs: a browser
   signed in at Base but not at an RP cannot start a login at that RP. This product constraint is
   intended.
3. Continuation of the same live transaction is not a new Sign. It is recognized only from
   server-held stage, subject, browser binding, and expiry.
4. An `id_token_hint` identifies the session the RP wants ended; it is not authority to end it. Its
   `sub` and `sid` become the logout target only when they match the verified current session.
   Without a current session, the request may still clear this browser's state and redirect to a
   registered `post_logout_redirect_uri`, but revokes nothing and sends no back-channel logout.
   Coordinated logout stays bound to its stored logout transaction.
5. Base end-session controllers do not redeclare `protect_from_forgery`. Rails keeps one
   `verify_authenticity_token` callback per controller, so a conditional redeclaration replaces the
   inherited check; that let plain POSTs run with no CSRF check (D2). Coordinated-logout POSTs are
   gated by `verify_coordinated_sign_out_post!` and the live logout challenge instead.

## Consequences

- Cross-RP single sign-on is given up for new logins; users authenticate at each RP's start.
- Logout from a browser whose Base cookies were already cleared no longer revokes the server-side
  session named in the hint; that session ends through its own expiry or an authenticated logout.
- Base's root `POST /` with its Sign in / Sign up choice, Auth's context-free bridge to Base, the
  Base SSO code-issuing branch, and the automatic OIDC start from protected pages and failed RP
  callbacks were removed on 2026-10-02. RP callbacks moved from `/sign/callback` to
  `/oidc/callback`.
- The decision table, migration table, and P3 gate are in `plans/active/sign-fqdn-integrated-plan.md`.
