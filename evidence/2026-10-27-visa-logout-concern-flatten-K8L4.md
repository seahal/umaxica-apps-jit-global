# Visa logout controllers: flat concern (full-suite repair item 3)

- Commit: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`; dirty worktree (cycle changes and Codex's partial
  full-suite repair, evidence P3R8).
- Second full run after Codex's partial batch 1: `bin/rails test` 18,445 runs, 176 failures,
  240 errors in 105 files (baseline F7Q1: 179 / 244 / 110). New failures: the flat-layout invariant
  (2) and the architecture baseline (1), caused by the concern location in Claude's instruction
  (`app/controllers/concerns/visa/<realm>/oidc/logout_endpoint.rb` with `included do layout`), and
  `acceptance_wu02_jwks_separation_test` (passed alone: 1 run, 0 failures; order-dependent).
- Change: the three concerns are now flat `VisaAppOidcLogoutEndpoint`, `VisaComOidcLogoutEndpoint`,
  `VisaOrgOidcLogoutEndpoint` (`app/controllers/concerns/visa_<realm>_oidc_logout_endpoint.rb`) with no
  `included` hook; each Visa `Oidc::LogoutsController`, `Logouts::ConfirmationsController` and
  `Logouts::CompletionsController` declares its own `layout`. `bin/rails architecture:baseline`
  removed only the three deleted `acme_logout_transaction*` entries.
- Verification: flat-layout invariant, architecture baseline, controller inheritance, BareController,
  Visa/Base logout controller tests, `oidc_current_device_logout_test.rb`,
  `oidc_logout_enqueue_failure_test.rb`: 162 runs, 3,919 assertions, 0 failures, 0 errors. RuboCop:
  no offenses on the 12 files.
