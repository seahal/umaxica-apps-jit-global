# DBSC Hands-On Check on a Windows VM (APP, development)

Date: 2026-11-05

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree had extensive uncommitted changes
(step-up units 6 and 6b in progress); the DBSC registration path and its CSRF handling were
unchanged by them as far as source reading shows.

## Setup

- Windows guest on Proxmox VE with a TPM available to the guest (confirmed by the owner).
- Chrome (version not recorded).
- Development hosts `www.umaxica.app`, `auth.umaxica.app` and `visa.umaxica.app`, runtime role
  `shared`.

## Actions

Three APP email sign-ins around 09:01 to 09:10 UTC, one including a sign-out before it and one
including a wrong code followed by an OTP resend.

## Observations (`log/development.log`)

- Every sign-in completed (`LOGGED_IN`) through Visa `POST /oauth/authorize`.
- In that response Visa logged `dbsc.registration.advertised` (`request_path: /edge/v0/token/dbsc`),
  set by `AuthenticationBase#issue_dbsc_registration_header_for` from `apply_committed_login!`.
- Right after each sign-in the browser sent `POST /edge/v0/token/dbsc` itself
  (`Visa::App::Edge::V0::Token::DbscController#create`), with `sec_fetch_site: same-origin`.
- Each such request returned **422**: `security.csrf.request_blocked`,
  `ActionController::InvalidCrossOriginRequest` (no Rails CSRF token on a browser-initiated
  request).
- `log/development.access.jsonl` holds 19 requests to this endpoint in total, all 422.

## Conclusion

The browser side starts DBSC registration; the server refuses it at the CSRF check, so no session is
DBSC-bound. Sign-in works without DBSC.

## Not verified

- That these requests came from the Windows guest: the log does not identify the client; attribution
  is by time.
- Server-side registration, key verification, binding and refresh: never reached.
- ORG: not exercised.
- Where Chrome DevTools shows the browser-initiated request: the owner could not identify it in the
  Network panel.

Follow-up: `plans/backlog/visa-dbsc-registration-csrf.md`.
