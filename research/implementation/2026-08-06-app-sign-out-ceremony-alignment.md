# App Sign-Out Ceremony Alignment Implementation Notes

## Context

- Original plan/spec: none. Work started from a production report that
  `https://www.umaxica.app/sign/out/new?ri=jp` fails, and from log inspection
  (`log/development.log`, the `Redirected to https://auth.umaxica.app/sign/out?logout_token=…` line
  immediately followed by `ActionController::RoutingError (No route matches [GET] "/sign/out")`).
- Related decisions/docs/plans:
  - `adr/logout-ceremony-boundary.md` (Accepted 2026-06-21) — the current contract
  - `adr/logout-completion-boundary.md` (superseded by the above)
  - `adr/sign-residual-idp-surface-retirement.md` item 4 — retire auth-side session mutation
  - `docs/security/logout-sequence.md`, `docs/security/logout-session-management.md`
  - `docs/security/redirect-vs-ceremony-result.md`
  - `docs/mermaid/sign-app-sign-out.mmd` (deprecated; notes `/sign/out` is redirect-only if
    retained)
- Implementation date: 2026-08-06

Naming: the decision documents predate the surface rename. `acme/www` is today's `base` (www host),
`sign/id` is today's `auth`, and the old `base` surface is today's `side`.

## Decisions Made During Implementation

- Decision: rebuild `Base::App::SignOutsController` as a direct authority logout that completes on
  its own surface, matching `Base::Com::SignOutsController` and `Base::Org::SignOutsController`.
  - Why: `adr/logout-ceremony-boundary.md` makes the ceremony surface-local, makes the completion
    marker session-bound and explicitly not URL-borne, and makes Base the only surface that mutates
    session authority. The `app` surface was the only one carrying a `LogoutTransaction` one-shot
    token in the redirect query string, which is the retired `/sign/out/edit?sot=` pattern under a
    new name.
  - Alternatives considered: adding a `GET /sign/out` entry on the auth surface so the existing
    redirect resolves. Rejected: it would make an undocumented cross-host handoff permanent and
    would contradict both the ceremony ADR and `docs/security/redirect-vs-ceremony-result.md`.
  - Follow-up needed: none for this surface.

- Decision: rebuild the user-initiated branch of `Auth::App::Sign::OutsController#create` on
  `OidcRpLogoutLauncher`, matching `Auth::Com` and `Auth::Org`.
  - Why: auth is an RP. The previous implementation consumed a `LogoutTransaction` with
    `issuer: "acme"` while Base issued `issuer: "base"`, so the token could never validate — and the
    return value of `LogoutTransaction.consume_one_time_url_token!` was discarded, so an invalid
    token still advanced the flow (a silent fallback).
  - Alternatives considered: fixing only the issuer string. Rejected: it preserves an off-contract
    mechanism and the discarded result.
  - Follow-up needed: none.

- Decision: keep a `logout_challenge` continuation branch on
  `Auth::App::Sign::OutsController#create`, preserving the previous redirect target
  (`auth_app_sign_out_completion_url` on the Base host).
  - Why: `AcmeLogoutTransaction.step_sequence_for` gives `core`, `side`, and `palm` origins a
    three-step ceremony whose `sign_cleared` hop is posted to this endpoint by
    `SignOidcLogout#handle_oidc_logout_completion_redirect!`. The previous controller served that
    hop incidentally (the absent `logout_token` produced an ignored `:invalid` result and the flow
    continued). Routing that hop into the RP launcher instead starts a second ceremony and raises in
    `OidcSubject.for`.
  - Alternatives considered: advancing the transaction to `sign_cleared`, finalizing it, and
    redirecting to `transaction.completion_url` through the jump gateway, which is what the state
    machine implies. Rejected here as out of scope:
    `test/controllers/palm/app/sign/outs_controller_test.rb` pins the Base completion page as the
    destination and asserts the finalize URL carries no `logout_challenge` or `state`, which the
    state-machine-correct behavior would contradict.
  - Follow-up needed: yes — the coordinated transaction is left with `expected_step: sign_cleared`
    and is never finalized on the auth hop. Reconciling the auth-side continuation with
    `AcmeLogoutTransaction` (and with `adr/sign-residual-idp-surface-retirement.md` item 4, which
    wants this hop to be redirect-only) needs its own task.

- Decision: delete `app/controllers/base/app/outs_controller.rb`.
  - Why: it was an unrouted byte-for-byte duplicate of the broken handoff in
    `Base::App::SignOutsController`. `bin/rails routes` resolves nothing to `base/app/outs#*`.
  - Follow-up needed: none.

- Decision: leave the `LogoutTransaction` model and the `logout_transactions` table in place.
  - Why: after this change the model has no application callers, but removing it means either
    leaving an orphan table or running a destructive migration, which needs explicit approval.
  - Follow-up needed: yes — decide whether to drop `LogoutTransaction` and its table.
    `PalmLogoutCoordinator` and `Palm::App::Sign::OutsController` use `AcmeLogoutTransaction`, a
    different model, and are unaffected.

## Deviations From Plan

- Change: `Auth::App::Sign::Outs::CompletionsController#show` now delegates to `complete` instead of
  rendering `auth/shared/sign_outs/complete` directly.
  - Why: the direct render skipped `complete_oidc_rp_logout!`, so the session-bound completion
    marker was never state-validated or consumed. `Auth::Com` and `Auth::Org` already delegate.
  - Risk: low; covered by the RP handoff test.
  - Follow-up: none.

- Change: `DELETE /sign/out` was left in `config/routes/auth.rb` for all three surfaces even though
  `adr/logout-ceremony-boundary.md` says it is not part of the public contract.
  - Why: it is not a stray route — it is `SignOutCancellation#destroy`, the cancel control rendered
    by `auth/shared/sign_outs/edit`. Removing it would delete a working feature.
  - Risk: the ADR and the code disagree.
  - Follow-up: either record the cancellation endpoint as an accepted amendment to the ceremony ADR
    or retire the cancel control. Not decided here.

## Review Notes

- Tests run: full `bin/rails test` — 9723 runs, 46952 assertions, 0 failures, 0 errors, 0 skips.
  `bin/rubocop` on every touched file — no offenses.
- Tests updated:
  - `test/controllers/base/app/sign_outs_controller_test.rb` — rewritten to the com/org shape
    (redirect-only `new`, non-mutating `edit`, surface-local completion, no-session completion).
  - `test/controllers/auth/app/sign_outs_controller_test.rb` — replaced the four `logout_token`
    cases with an RP handoff case and a coordinated-continuation case; cancellation cases kept.
  - `test/controllers/base/app/identity_authority_slice_1a_test.rb` — the pinned expectation was the
    cross-host handoff; retargeted to surface-local completion.
  - `test/security/invariants/forbidden_patterns_invariant_test.rb` and
    `test/unit/security/redirect_target_usage_test.rb` — allowlist entries follow the code.
- Contradiction found and left unresolved: `test/integration/preference_logout_downgrade_test.rb`
  asserts that guest-safe display preferences survive logout, but it posts `/sign/out` with only
  `X-TEST-CURRENT-USER`, which the harness does not treat as authentication, so it never exercised
  an authenticated logout. Making it authenticate (`as_user_headers`) reproduces the completion page
  with `PreferenceBase::THEME_COOKIE_KEY` reset from `dr` to `sy`, i.e. the documented keep-values
  contract does not hold for a real logout. This predates this change — `logout_current_session!`
  was already on the authenticated branch. The test was left at its original coverage level with
  only the status expectation corrected.
- Documentation promotion needed: none. The ADRs already describe the target behavior; this change
  moves the `app` surface onto it.
