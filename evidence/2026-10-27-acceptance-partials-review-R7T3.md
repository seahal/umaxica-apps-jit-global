# Review of Codex's acceptance-partials work (V8M2) and follow-up fixes

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree with the uncommitted cycle
  changes and Codex's V8M2 test additions.
- Re-run of Codex's 16-file set plus `oidc_initiated_sign_in_completion_test.rb` and
  `visa_authorization_continuations_test.rb`: 182 runs, 2,570 assertions, 0 failures, 0 errors.
- Read-through: the A44-4 test stubs only the reading-role `Client.find_by` with the stale actor, and
  `OidcAccessTokenAuthenticator` reads the actor with `find_by` under the writing role, so a switch to
  the reading role would fail the test. The A15-5 test signs each invalid Logout Token with the real
  issuer key, so the refusals come from the claim checks. No weakened or deleted assertion found.
- A12-5 product defect (reported by Codex): Auth `/ceremony_bindings` attached a binding for a framed
  request. Red: added to `acceptance_wu12_relay_repeat_test.rb` A12-3 — an `iframe` request to the
  attach path must answer 400 and leave the binding unattached (1 run, 1 failure: 303). Fix:
  `Auth::{App,Com,Org}::CeremonyBindingsController#show` include `BrowserNavigationRequest` and refuse
  `framed_destination_request?` with HEAD. Green: relay, admission boundary, Visa continuations,
  admission input tests 138 runs, 0 failures; sign-in flows through attach (social admission,
  OIDC-initiated completion, refusal matrix, Sentry) 49 runs, 0 failures. A12-5 set to Passed.
- Stale statements reported by Codex, corrected: `browser_navigation_request.rb` comment (missing
  metadata decided, D-197); the sign-out ADR status and the 2026-10-24 / 2026-10-26 amendment headers
  ("not implemented yet" → implemented locally, with evidence); `project/browser-rp-contract.mdc`
  "Logout is authority-first" → the D-188 order (RP clears itself, OP commits, siblings via BCL).
- RuboCop: no offenses on the changed Ruby files.
