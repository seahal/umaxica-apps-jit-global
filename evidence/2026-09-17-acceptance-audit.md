# 2026-09-17 cycle acceptance audit

Baseline HEAD: `cac794f88e473666832c78f043b87b15bb6bc38d`. Worktree carried additional uncommitted
acceptance tests/evidence (see `git status` at audit start); nothing discarded, no GitHub write, no
production change made.

Independent audit found the existing acceptance tests (three committed in `cac794f88`/`2628f17f4`:
`ceremony_admission_boundary_test.rb`, `oauth_token_exchange_e1_test.rb`,
`oauth_freshness_e3_test.rb`; plus the uncommitted additions in `oauth_freshness_e3_test.rb`,
`identity_session_revocation_test.rb`, `session_absolute_expiry_value_test.rb`,
`cycle_close_authenticated_roots_test.rb`, `base_identity_session_presenter_test.rb`,
`sms_not_phishing_resistant_inventory_test.rb`, `oidc_seven_first_party_rp_isolation_test.rb`)
already exercise A/B/C/D/E/F/G at observable boundaries. No production defect was found; no
production file was changed.

Focused run (new/modified acceptance files, 1 worker): 29 runs, 173 assertions, 0 failures, 0
errors.

Ordinary isolated Rails: 13,098 runs, 79,375 assertions, 0 failures, 0 errors, 3 skips (415.2s, 16
workers).

JS: `bun run test` — 85 files, 1,057 tests passed. `bun run test:coverage` (Node/Vitest V8 launcher)
— statements 100% (2184/2184), branches 99.63% (1354/1359), functions 100% (739/739), lines 100%
(2143/2143); all above configured thresholds.

`bundle exec rubocop --parallel`: 4,818 files inspected, no offenses.

`bundle exec erb_lint --lint-all`: 1,857 files, no errors.

`bundle exec brakeman -q --no-progress`: 0 security warnings, 0 errors.

`bundle exec bundler-audit check --update`: ruby-advisory-db updated, 0 vulnerabilities.

`git diff --check`: exit 0.

Ruby `COVERAGE=true` isolated Rails (once): 13,098 runs, 79,383 assertions, 0 failures, 0 errors, 3
skips (474.7s). SimpleCov: line 98.33% (58,003/58,985, meets 97% floor); branch 87.84% (8,673/9,873,
below 90% floor); method 93.82% (10,068/10,731, below 95% floor). Lowest-branch files unchanged from
prior measurement (`lib/architecture_baseline.rb`, `lib/coverband_process_gate.rb`,
`lib/diagnostic_surface_credentials.rb`, `app/controllers/auth/app/social/sessions_controller.rb`,
`app/controllers/concerns/regional_root_redirect.rb`). Thresholds, exclusions, and skip markers were
not changed. This matches the explicit cycle waiver recorded in `MISC-0017`.

Canonical `bin/ci`: exit 0, 13m27.72s. Stages: Setup test DB, Style (JS/Ruby/ERB), Security (gem
audit/JS audit/Brakeman), Report (outdated deps), Smoke (Rails server boot), Tests (JavaScript with
coverage, Rails: 13,098 runs / 79,371 assertions / 0 failures / 0 errors / 3 skips, 377.7s) — all
green.

`test/tooling/evidence_layout_test.rb`: 3 runs, 6 assertions, 0 failures.

OpenAPI verification is exercised inside the ordinary Rails suite via
`test/contracts/openapi_*_test.rb` and `openapi_route_coverage_test.rb`; all green in the runs
above. No dedicated `bin/*openapi*` step exists in this repository.

No live IdP, mail, SMS, Turnstile, or production/shared database was contacted. No database was
reset/dropped/flushed. No production or test file was modified during this audit; only this evidence
file was added.

Verdict inputs: no A-G invariant failed at observable boundaries; the only red gate is the
pre-existing, explicitly waived Ruby branch/method SimpleCov floor (`MISC-0017`). See the
conversation's final report for the full acceptance matrix and both verdicts.
