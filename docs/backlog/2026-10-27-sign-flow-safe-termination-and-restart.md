# Sign flow refusal: safe termination and restart

Status: Open, deferred by the owner on 2026-10-27. Analysis only; implementation and the policy
for selecting termination cases have not been approved.

## Problem

The owner reported being unable to continue at `https://auth.umaxica.app/sign/in?ri=jp` after
receiving the stale-screen refusal. The reported customer copy was
“この画面は古くなっています。最初からやり直してください。” (quoted Japanese UI text).
The browser-specific cause has not been reproduced or established. A refusal that instructs a
restart needs a usable, safe route for doing so.

## Proposal to evaluate

Introduce a shared Concern explicitly called by selected terminal refusal paths in sign-up,
sign-in and sign-out. Reuse the existing authentication-cookie deletion operation for access,
refresh and DBSC cookies, reset the Rails session, and provide a server-selected restart route.
Do not select termination solely because a response uses `render plain:`.

Relevant existing implementation:

- `app/controllers/concerns/authentication_cookie_store.rb`: `clear_auth_cookies!` deletes the
  three authentication cookies and clears request-local authentication state.
- `app/controllers/concerns/auth_ceremony_context.rb`: `clear_auth_ceremony_context!` also revokes
  the current Auth ceremony and deletes its separate SID cookie before resetting the session.
- `app/controllers/concerns/authentication_logoutable.rb`: existing logout and Inertia-history
  clearing operations distinguish browser cleanup from authoritative session revocation.
- `app/controllers/concerns/sign_in_phase_binding_controller_support.rb`: phase refusals currently
  request `clear_continuity: false`.

## Decisions still required

- Classify eligible terminal refusals separately from retryable input errors, OTP resend cooldowns,
  dependency failures and stale or foreign requests. Shared responders have multiple callers;
  enumerate their public request paths before changing them.
- Decide whether each operation ends browser continuity, an owned Auth ceremony, or an
  authoritative authentication session. Cookie deletion and `reset_session` alone do not revoke
  database credentials, remove the separate Auth SID cookie, or end sessions on other hosts.
- Preserve surface ownership and protect a newer flow from an old tab's request. Decide how a
  termination request proves ownership, and whether an explicit CSRF-protected restart action is
  needed instead of cleanup during a refused GET/HEAD.
- Decide how to retain required cooldown protections, handle cleanup failures, clear Inertia
  history, and present a fixed safe restart destination. Resetting local state alone does not make
  a context-free Auth URL a valid entry point.
- Resolve proposed changes against `docs/checklists/authentication-flow-integrity.md` FLOW-2/4
  (safe-request state preservation and replacement-flow isolation) and
  `docs/checklists/sign-out.md` SIGNOUT-8 (retaining state for failed or unknown stops).

Before implementation, cover selected terminal cleanup, retryable-state preservation, stale-tab
isolation, cookie deletion scope, failure handling and successful re-entry at public HTTP boundaries
for each affected surface. The earlier analysis attempted related tests, but another process held
the test-database lock; no new passing test result was obtained for this proposal.
