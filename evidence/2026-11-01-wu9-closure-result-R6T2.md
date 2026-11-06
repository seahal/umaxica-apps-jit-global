# WU-9 closure verification result

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree has uncommitted changes affecting this result. No commit was created.
- Local approved cutover and eight development/test migrations are recorded in
  `2026-10-31-wu9-approved-local-cutover-J8P3.md`.

## Checks performed

- The first closure-suite invocation stopped before running tests because
  `test/security/invariants/withdrawal_gate_invariant_test.rb` had a malformed allowlist hash.
  Corrected the two DBSC entries and ran that file: 5 runs, 18 assertions, 0 failures, 0 errors, 0
  skips.
- Ran the closure full suite once after that correction with the local COM JWT environment values
  and `PARALLEL_WORKERS=1`: 16,665 runs, 60,366 assertions, 90 failures, 9,566 errors, 0 skips; exit
  status 1. The log was kept outside the repository at `/tmp/wu9-full-suite-closure.log`.
- Compared unique failing/error test identifiers from that run with
  `plans/2026-10-28-baseline-failing-tests.md`: 9,656 current identifiers, 438 listed in the
  baseline and 9,218 not listed. This comparison does not establish causes for those failures.
- The full run reports repeated fixture setup foreign-key failures in `test_app_zenith_db`:
  `enterprise_units` / `persona_memberships` rows reference missing `enterprises.id = 519260501`. A
  subsequent focused `test/integration/acme_preference_test.rb` run ended with 129 errors, 0
  assertions; fixture setup raised that same foreign-key error. Preference behavior in this file
  remains unverified in this database state.
- The full run reported outdated or failing Preference expectations, including a consent write test
  expecting HTTP 204 while the current response is HTTP 200 JSON, plus reset-cookie, audit, locale,
  timezone, token, and option tests. Updated the consent write test to assert the current JSON
  response and removed its unrelated global-fixture dependency; its focused run passed with 1 run,
  21 assertions, 0 failures, 0 errors, 0 skips. The full suite was not rerun after this change.
- Earlier scoped WU-9 suites in this work cycle passed: 201 runs / 2,734 assertions; browser API,
  Inertia and Base resolver: 58 / 2,246; realm separation and binding: 15 / 72; COM receipt/write
  journey: 58 / 840; COM response/storage boundaries: 38 / 522. These do not supersede the
  closure-suite failures.
- Runtime search in `app` and `config/routes` found no `PreferenceAdoption`, `preference_refresh`,
  `preference_dbsc`, or `preference_assurance` references.
  `PreferenceCore#load_or_refresh_preference_child` remains as a generic child-association loader.
  Search for `adult_content_gate` outside `app/models` found none. Model, option and child-table
  definitions remain.
- Visa sign-in is still invoked by `AuthorizationBaseController#resume_authorization!` during
  `GET Visa::{App,Org}::Oidc::ResultsController#show`. Current `two.md` §12.5 requires GET
  result/SSO/cancel/switch to render a no-store continuation form and the existing Visa OAuth
  authorization `create` POST to be the sole commit endpoint, with a purpose-bound signed
  continuation, CSRF and Origin/Fetch Metadata checks. `OidcAuthorizationResultPost` currently
  starts only the ceremony on POST and runs result/cancel/switch jobs from GET; this contract
  discrepancy is unresolved.
- `git diff --check` passed. The static reference searches and focused checks do not establish all
  WU-9 acceptance criteria.

## Closure status

WU-9 is not complete. The Visa GET-versus-POST continuation contract remains unimplemented. The
closure suite has substantial failures, the App/Org test database fixture foreign-key failure has
not been repaired or attributed, and the remaining full Preference contract failures have not been
resolved. No causal attribution is made for the 9,218 identifiers absent from the recorded baseline.
