# Browser History Residue on Devices Whose Sessions Were Revoked Remotely

Status: backlog (not scheduled). Recorded 2026-09-19 as a candidate GitHub issue; kept here instead
of filing one.

## Problem

When a user or an operator revokes sessions belonging to other devices ("sign out other devices",
administrative revocation, account security operations), the server-side sessions become invalid
immediately. The server cannot, however, clear those other devices' browser state:

- Inertia history encryption keys live in each tab's `sessionStorage`.
- `session[:inertia_clear_history]`, set by
  `AuthenticationLogoutable#reset_session_and_clear_inertia_history!`, reaches only the browser that
  made the terminating request.

## Current mitigations

- Authenticated HTML and Inertia responses are `Cache-Control: no-store`
  (`AuthenticationBase#apply_authenticated_page_cache_policy!`), so the HTTP cache and the
  back/forward cache do not retain them.
- Every re-fetch is authenticated server-side, so a revoked device that navigates is redirected
  rather than served.

The remaining exposure is a same-document Back on the revoked device, which Inertia restores from
encrypted history without contacting the server.

## Options to evaluate

1. Clear on the revoked device's next request: when a request presents credentials for a revoked
   session, respond with the history-clear instruction (the stale-credential detach path already
   does this for `:open` pages; extend the same behavior to every response that rejects revoked
   credentials).
2. Clear on the client when a tab becomes visible again, after a lightweight session-status check.

## Out of scope

The 2026-09-19 change that introduced the no-store policy and the history-clear flag.
