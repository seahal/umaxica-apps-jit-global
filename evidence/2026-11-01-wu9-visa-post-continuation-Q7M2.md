# WU-9 Visa continuation update

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contains uncommitted changes affecting this work. No commit was created.
- Local destructive Preference cutover approval and execution are recorded in
  `2026-10-31-wu9-approved-local-cutover-J8P3.md`.

## Changes

- Visa result, cancellation, switch and sufficient-session silent SSO use the same-origin POST
  continuation implemented in `OidcAuthorizationContinuation` and `OidcAuthorizationResultPost`. The
  protected authorization POST revalidates the signed, purpose-bound continuation and parent state
  before finalizing the Visa result. Its expiry is capped at 60 seconds and the parent/session
  deadline.
- APP/ORG Preference sign-in writers are statically authorized at the Visa OAuth authorization
  `create` action. Social APP integration journeys now follow the GET display and POST commit path.
  Architecture, ADR, checklist, Mermaid diagrams and transition inventory describe it.
- Added coverage for the 59/60/61-second expiry boundary, tampered continuation refusal, CSRF and
  cross-origin POST refusal, and read-only result GET behavior.

## Verification performed

Commands used explicit local COM Preference JWT settings:

- `test/controllers/concerns/preference_write_boundary_test.rb` and
  `test/integration/sign_entry_exit_flow_test.rb`: 20 runs, 208 assertions, 0 failures, 0 errors, 0
  skips.
- `test/integration/social_login_admission_test.rb`: 11 runs, 239 assertions, 0 failures, 0 errors,
  0 skips.
- `test/integration/org_oidc_auth_handoff_root_completion_test.rb` filtered to the complete Entra
  and Passkey journey: 1 run, 111 assertions, 0 failures, 0 errors, 0 skips.
- `test/integration/oidc_initiated_sign_in_completion_test.rb` filtered to the Preference-writer
  failure journey: 1 run, 16 assertions, 0 failures, 0 errors, 0 skips.
- `test/integration/social_auth_app_flow_contract_test.rb` filtered to Google/Apple sign-up and
  sign-in result journeys: 4 runs, 109 assertions, 0 failures, 0 errors, 0 skips.
- `test/integration/sign_entry_exit_flow_test.rb` and
  `test/integration/visa_authorization_continuations_test.rb`: 13 runs, 251 assertions, 0 failures,
  0 errors, 0 skips.
- `test/integration/visa_authorization_continuations_test.rb` after adding missing/unsupported
  authorization POST purpose cases: 6 runs, 146 assertions, 0 failures, 0 errors, 0 skips.
- `git diff --check`: passed.

An initial boundary assertion expected expiry at exactly 60 seconds; the observed verifier behavior
accepts exactly 60 and refuses at 61 seconds. The test now records that observed boundary. One test
invocation without required COM JWT environment values stopped during Rails initialization; the
listed runs supplied the explicit local values.

## Remaining verification

- The prior closure full suite in `2026-11-01-wu9-closure-result-R6T2.md` ran before these changes
  and reported 16,665 runs, 60,366 assertions, 90 failures, and 9,566 errors. It has not been rerun;
  this update does not establish the final full-suite comparison.
- The complete WU-9 AC set across APP, ORG and COM, all reset/sign-out failure cases, and the final
  baseline comparison have not been reverified by this update. WU-9 remains incomplete until the
  required closure verification is completed.
- App Secret receipt/parallel/root-concurrency integration flows still have stale earlier
  authorization-start assumptions. Targeted runs stopped before reaching the Visa continuation
  submission (`AppSecretParallelLoginTest` and `AppSecretRootLoginConcurrencyTest` fail while
  finding their earlier start form; `AppSecretReceiptCollectionJourneyTest` redirects to the
  existing Auth sign-in sentry instead of its expected Base start form). The parallel and
  root-concurrency tests were updated to submit the new Visa continuation, but that code remains
  unverified because setup stops earlier. The App Secret login journey's result submissions were
  also updated but not run. The receipt-collection test still has its old result form expectation.
  These flows need reconciliation with the current sign-in entry contract.

## Verification continuation

- HEAD remains `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree remains uncommitted.
- The Visa continuation expiry test now freezes the clock at integer-second issuance time. This
  verifies the §4.9 strict boundary: 59 seconds is accepted; expiry equality at 60 seconds and 61
  seconds are refused. `sign_entry_exit_flow_test.rb:35` passed: 1 run, 17 assertions.
- `sign_entry_exit_flow_test.rb`, `sign_entry_exit_org_flow_test.rb`, and
  `visa_authorization_continuations_test.rb` passed together: 19 runs, 304 assertions.
- The Preference writer and read/write contract group passed:
  `anonymous_com_preference_write_journey_test.rb`, `preference_browser_api_contract_test.rb`,
  `preference_signed_in_dual_write_test.rb`, `base_preference_zenith_identity_test.rb`,
  `sign_entry_exit_org_flow_test.rb`, and `app_org_preference_write_serialization_test.rb`; 74 runs,
  2,018 assertions.
- `oidc_current_device_logout_test.rb` passed: 65 runs, 787 assertions. Its two coordinator-failure
  cases now follow the read-only authorization GET with the same-origin continuation POST before
  asserting the generic 400 response.
- APP explicit-field sign-in and Preference-writer-failure cases passed: 2 runs, 30 assertions. ORG
  Entra/Passkey completion with explicit Preference reflection passed: 1 run, 111 assertions.
- `preference_write_boundary_test.rb` passed: 10 runs, 78 assertions.
- A targeted lifecycle run first exposed strict-loading errors when COM Preference destruction did
  not preload the dormant adult gate child association. COM Preference now preloads all of its
  dependent children at its own destroy boundary; the purger has no adult-gate reference. The
  lifecycle job plus commit-failure, consent-concurrency, and purge tests passed after this change:
  20 runs, 181 assertions. A lifecycle test verifies the dormant child is removed with an expired
  parent while its model/table remain available.
- `preference_lifecycle_job_test.rb`, `database_consistency_test.rb`,
  `refresh_token_shared_test.rb`, and both dormant adult gate guards passed together: 29 runs, 121
  assertions. The old generic refresh helper test now exercises the still-active ClientToken caller
  instead of the retired AppPreference refresh contract; the Preference uniqueness fixture supplies
  the required issuance interval.
- `git diff --check` passed. Runtime searches found no `PreferenceAdoption`, Preference refresh,
  DBSC, assurance, or item-cookie references under `app`, `config/routes`, or `lib`; no
  `adult_content_gate` references were found outside `app/models`.
- A further `AppSecretLoginJourneyTest` HTTP journey was attempted and failed with HTTP 401
  (`Step-up authentication required; Your changes have not been saved`) before reaching its Visa
  result submission. That flow remains unverified; no cause has been established here.
- The earlier full-suite result in `2026-11-01-wu9-closure-result-R6T2.md` predates this
  continuation and is not a final comparison. Per the one-run closure instruction, the full suite
  was not run again in this continuation. WU-9 remains incomplete pending the final baseline
  comparison and remaining acceptance evidence.

## Further acceptance checks

- Added a Base APP/ORG/COM contract asserting that preference JWT issuance, persisted issuance
  timestamps, and the three shared cookies (JWT, language, experience) all expire at issuance plus
  400 days. The targeted test passed: 1 run, 33 assertions, 0 failures, 0 errors, 0 skips.
- The first run of that test incorrectly expected the browser-binding cookie on a theme write. It
  failed at that assertion; the contract issues the binding cookie on consent, not theme. The test
  was corrected to cover the three shared cookies named by §4, then passed.
- APP and ORG reset retirement/cookie replacement tests passed: 2 runs, 36 assertions. COM reset
  retirement and consent-generation retirement tests passed: 2 runs, 40 assertions.
- The complete `preference_browser_api_contract_test.rb` passed after the new expiry contract: 19
  runs, 1,210 assertions, 0 failures, 0 errors, 0 skips.
- Re-ran the App Secret manual-delivery/login journey in isolation. It fails at the
  storage-confirmation POST (`app_secret_login_journey_test.rb:777`) with HTTP 401, “Step-up
  authentication required”; it stops before the Visa result submission. The failure is in the Base
  secret-issuance step-up path, so no WU-9 change was made for it.
- `git diff --check` passed. Runtime search under `app`, `config/routes`, and `lib` found no
  PreferenceAdoption, Preference refresh/DBSC/assurance, or adult-content-gate references outside
  `app/models`; model, option, and child-table declarations remain.
- HEAD is `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree has 90 paths with uncommitted
  changes. No commit was created.
- These checks do not close the full WU-9 AC matrix, the previously observed full-suite comparison,
  or App Secret entry flows. Those remain unverified; WU-9 is incomplete.

## Consent screen read-path correction

- Code inspection found that APP/ORG HTML cookie screens still loaded the old cookie child directly
  for display. Their API consent reader already required a recorded receipt and matching browser
  binding. The screen now uses that same read path; controller dependency failures return 503.
- Removed the obsolete `consented_at` request field and the old consent timestamp preparation path
  from `PreferenceCore`. The APP/ORG screen writer uses `PreferenceWriteBoundary`; unsupported
  consent models fail explicitly.
- APP and ORG screen tests grant consent, verify that a matching binding displays it, replace the
  binding with an invalid value and verify that consent is hidden, and confirm GET leaves jti,
  issuance time, receipt version, audit count, and active status unchanged.
- The first static guard run reported two failures because its setup still used the retired HTML
  region write to obtain a Preference JWT. It now obtains the JWT through the current Base APP theme
  API write and asserts the same protected route rejects it in both access-token positions.
- Targeted verification with explicit COM JWT settings:
  - Preference token, APP/ORG consent screens, localization, and browser API contract: 39 runs,
    2,369 assertions, 0 failures, 0 errors, 0 skips.
  - Preference issuance, token/access-token separation, read-only-route, cookie security, no-store,
    and writer-boundary guards: 26 runs, 215 assertions, 0 failures, 0 errors, 0 skips.
  - `git diff --check`: passed.
- HEAD is still `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; 87 tracked paths and 16 untracked paths
  are changed (103 paths total). The worktree is uncommitted; no commit was created.
- The earlier full suite is still only the pre-correction result recorded in
  `2026-11-01-wu9-closure-result-R6T2.md`; this continuation did not rerun it. The 90 failures and
  9,566 errors have not been compared against baseline after this correction. App Secret Visa entry
  remains unverified because its targeted journey stops at the earlier Base step-up POST with HTTP
  401 before reaching the Visa result submission. WU-9 remains incomplete.

## Remaining scoped stale expectations found in the earlier full-suite log

- Reproduced
  `PreferenceSecurityTest#test_timezone_update_rejects_unknown_raw_strings_even_with_a_slash`:
  invalid input redirected without issuing a Preference JWT or creating a row, but the old test then
  dereferenced the absent token. Updated the assertion to require no new row and no token.
- Reproduced `CorePreferenceApiSurfaceSmokeTest` expecting Core hosts to accept consent/theme
  writes. The current §4.6 contract makes Core read-only. Updated the contract test to expect 403
  for both malformed and valid writes while preserving successful GET checks.
- The two files passed together: 4 runs, 38 assertions, 0 failures, 0 errors, 0 skips.
- The previously recorded 39-run scoped group passed before these two test-only contract updates. No
  full suite was run in this continuation; all whole-suite failures remain unclassified against
  baseline after the latest edits.

## Preference model and shape-documentation continuation

- The broad APP/ORG/COM/Client/Operator Preference model test run initially reported 4 errors. One
  test still passed `staff:` to `OperatorPreference` after the owner association changed to
  `operator`; two option tests tried to remove fixed reference options while child rows still
  referenced them; and the dependent-restriction test reached missing Japanese association-name
  translations.
- Updated the operator association test to use `operator:`. The theme/timezone setup now clears
  their child rows before deleting reference options. Added matching EN/JA attribute names for
  client/operator preference child associations that use `restrict_with_error`.
- Updated the `ClientPreference` and `OperatorPreference` schema comments to match the applied
  structure: owner foreign key, public ID, explicit fields, lifecycle status and active-owner
  partial unique index; removed stale display and consent fields from those comments.
- The focused operator option and locale-bundle checks passed: 34 runs, 51 assertions, 0 failures, 0
  errors, 0 skips.
- Re-ran all matching Preference model tests: 491 runs, 741 assertions, 0 failures, 0 errors, 0
  skips.
- Locale parity and bundle-integrity checks passed: 18 runs, 187 assertions, 0 failures, 0 errors, 0
  skips.
- `git diff --check` passed. Searches across `app`, `config/routes`, and `lib` returned no
  `PreferenceAdoption`, `preference_refresh`, `preference_dbsc`, `preference_assurance`, or
  `adult_content_gate` runtime references outside `app/models`.
- HEAD remains `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree has 115 changed tracked
  paths and 16 untracked paths (131 total); no commit was created.
- The one recorded closure full-suite run still predates these edits and has not been repeated. The
  full final baseline comparison, complete AC matrix, and App Secret journey remain unverified; the
  previously attempted App Secret journey stopped at HTTP 401 during Base step-up before Visa result
  submission. WU-9 remains incomplete.

## Saved closure-log classification

- Read `/tmp/wu9-full-suite-closure.log` without rerunning the suite. Among its 9,656 distinct
  failing/error identifiers, repeated error blocks include 8,414 `enterprise_units` foreign-key
  failures (`enterprise_id=519260501` absent), 689 `KeyError` failures for missing
  `VALKEY_NAMESPACE_RUN_ID`, 191 COM Preference web-push foreign-key failures, and 16 COM browser
  binding foreign-key failures. These are counts of logged failure blocks by error text, not unique
  test identifiers.
- The log also contains unrelated navigation/response assertion failures and the previously recorded
  COM strict-loading errors. This session did not establish the owning WU for each group, and the
  log predates the strict-loading correction and subsequent targeted fixes. The 9,218 identifiers
  absent from the baseline therefore remain unclassified; no full-suite comparison after the current
  edits is available.
- As a focused probe of the COM Preference FK group, ran
  `test/values/external_authentication/credential_revocation_result_test.rb` alone with the required
  local COM JWT settings: 3 runs, 16 assertions, 0 failures, 0 errors, 0 skips. Its full-suite FK
  error was not reproduced in isolation. This supports a suite-level fixture/database interaction
  hypothesis but does not identify the cause or establish a passing full suite.
- Rechecked the sign-in Preference failure contract against `two.md` §4.8/XDB-26,
  `docs/checklists/preference-lifecycle.md` PREF-7b and `adr/preference-visa-writer-boundary.md`.
  They require the Root login to remain committed while the authorization code is withheld and the
  signed continuation can be retried. The current Visa controller behavior and its targeted tests
  implement that boundary; no code change was retained from an attempted broader interpretation.
- Final focused checks for this continuation remain as recorded above. HEAD is
  `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree is uncommitted and no commit was created.

## App Secret receipt-collection continuation

- Updated `AppSecretReceiptCollectionJourneyTest` to follow the current Base `/sign` → signed Jump →
  Visa `/oauth/authorize` route, and to submit the Visa result through
  `form#visa-authorization-continuation-form` with its hidden continuation and same-origin headers.
  The old test expected a Base ceremony form and directly posted unsigned result references.
- The targeted test initially exposed the stale Base-host expectation. After updating that
  expectation and following the Visa authorization GET to establish its browser nonce, the test
  reached the Auth handoff POST but received HTTP 400 (`errors.messages.invalid_request`). One
  attempted same-origin Origin header correction did not change the result. The cause was not
  established; the journey is not verified and remains a WU-9 closure failure candidate.
- Command:
  `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/integration/app_secret_receipt_collection_journey_test.rb`.
  The final run reported 1 test, 6 assertions, 1 failure, no errors or skips. Do not infer an
  implementation defect or a passing journey from the partial progress.
- `git diff --check` passed. HEAD is `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; 116 tracked paths
  and 16 untracked paths are changed (132 total). The worktree is uncommitted; no commit was
  created. The one full-suite run predates these latest changes and was not repeated.
- After that run, added the expected cross-site document-navigation headers to the test's Visa
  result GET. The test was not rerun after this final test-only header edit; execution had failed
  earlier at the Auth handoff POST, before reaching the Visa result GET. `git diff --check` passed
  against the final worktree.

## Receipt journey now follows the public Visa authorization path

- Replaced the receipt test's mixed legacy setup (Base ceremony form plus a separately fabricated
  authorization transaction and handoff) with a browser journey through the public Visa authorize
  endpoint, signed Jump navigation, Auth entry, and Visa result continuation. This removes the
  earlier HTTP 400 from the test's synthetic Auth entry request.
- The targeted run now reaches `Auth::App::Sign::In::SecretsController#create` and raises
  `ClientSecretClaimCommitter::TransactionConflict: Secret claim requires an independent source commit`.
  The test class uses transactional tests, while the production committer intentionally refuses an
  enclosing AppZenith transaction before consuming the credential. This is a test setup limitation,
  not evidence that the real browser journey passed; the receipt lifecycle assertions and Visa
  result continuation remain unverified in this test.
- Command:
  `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/integration/app_secret_receipt_collection_journey_test.rb`;
  1 run, 0 assertions, 1 error, no failures or skips.
- `ruby -c test/integration/app_secret_receipt_collection_journey_test.rb` and `git diff --check`
  passed. HEAD is `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; 116 tracked paths and 16 untracked
  paths are changed. The worktree remains uncommitted; no commit was created. The closure full suite
  has not been rerun.
- Re-ran the scoped Visa continuation, writer-authorization, and current-device logout group with
  explicit local COM JWT settings: `test/controllers/concerns/preference_write_boundary_test.rb`,
  `test/integration/visa_authorization_continuations_test.rb`, and
  `test/integration/oidc_current_device_logout_test.rb` passed with 81 runs, 1,011 assertions, 0
  failures, 0 errors, and 0 skips.

## Preference refusal ADR reconciliation

- Compared `adr/invalid-browser-credential-recovery.md` with the owner-approved P0 revision map,
  current `two.md` §4.4/4.6, and the realm JWT ADR. The normative Preference taxonomy and
  concurrency sections still described the removed refresh/DBSC rotation path; its cookie section
  also claimed all cookies were host-only, which conflicts with the accepted realm-domain JWT.
- Updated the current ADR to state the read/write refusal boundary, point Visa sign-in/out and Base
  reset to their distinct §4.4 rules, distinguish realm Preference cookies from host-only auth and
  binding cookies, and remove the obsolete Preference refresh/rotation observability contract.
  Updated `adr/README.md` to remove the stale claim about stale-generation reads.
- Ran
  `PREFERENCE_COM_JWT_ISSUER=https://www.umaxica.com PREFERENCE_COM_JWT_AUDIENCE=com PREFERENCE_COM_JWT_REVOKED_KIDS= bin/rails test test/integration/preference_cookie_invalid_values_test.rb test/controllers/base/com/roots_controller_test.rb test/controllers/warp/com/roots_controller_test.rb`:
  21 runs, 177 assertions, 0 failures, 0 errors, and 0 skips. This run preceded only the
  documentation edits in this section; no application or test code changed during it.
- `git diff --check` passed after the documentation edits. HEAD is
  `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; 118 tracked paths are modified and 16 paths are
  untracked (134 status paths total). The worktree remains uncommitted; no commit was created.

## Current focused WU-9 regression pass

- With local COM Preference JWT settings, ran the shared writer, Preference security/browser API,
  consent lifecycle, COM journey, Base resolver, Visa continuation/logout, app/org serialization,
  and APP/ORG entry-exit test files together. Result: 175 runs, 3,338 assertions, 0 failures, 0
  errors, 0 skips.
- Rechecked runtime references under `app`, `config/routes`, and `lib`. No `PreferenceAdoption`,
  `Preference::Adoption`, `preference_refresh`, `preference_dbsc`, `preference_assurance`, or
  non-model `adult_content_gate` references were returned. No `VisitorPreference`, `UserPreference`,
  `StaffPreference`, `preference_consented`, or `consented_at` references were returned under
  controllers, values, operations, or `lib`.
- Confirmed the current Visa APP/ORG authorization and shared OIDC result POST call the common
  `write_preference!(operation: :sign_in, ...)` entry, and committed OIDC logout invokes
  `write_preference!(operation: :sign_out, ...)` through `finish_oidc_committed_logout`.
- `git diff --check` passed. HEAD is `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; 118 tracked paths
  remain modified and 16 remain untracked. The worktree is uncommitted; no commit was created.
- This targeted pass does not verify every WU-9 AC or replace the single full-suite baseline
  comparison. WU-9 closure remains incomplete.

## OIDC Secret integration transaction boundary

- Ran `test/integration/oidc_initiated_sign_in_completion_test.rb` with local COM Preference JWT
  settings: 15 runs, 115 assertions, 0 failures, 7 errors. All seven errors are
  `ClientSecretClaimCommitter::TransactionConflict` raised before Secret lookup because the
  integration test's AppZenith connection has an enclosing fixture transaction while the committer
  requires its source claim to own an independent commit.
- The same test identifiers were checked against `plans/2026-10-28-baseline-failing-tests.md`: two
  are listed in the baseline and five are not. The full-suite log contains six matching identifiers
  (two baseline, four absent); the current targeted run exposed one additional matching test error.
  These are test-harness/source-commit boundary failures, not evidence of a Preference writer
  defect. The test class reuses fixture clients and Secret credentials, so disabling its transaction
  without isolating and cleaning those rows would risk changing shared test data. No test workaround
  or production relaxation was added.
- This integration class still has stale GET-based result assertions relative to the Visa POST
  continuation. Its Secret-claim setup errors prevent reaching those assertions. The class remains
  unverified for the updated browser flow and is outside the WU-9 Preference AC matrix; its five
  baseline-absent errors remain unassigned to a WU.
- The stored full-suite log was parsed without rerunning it. The error records include 882
  Preference-named identifiers and 452 Visa/OIDC-named identifiers, but many share the same fixture
  setup or transaction-root cause. These counts are identifiers in the old suite output, not unique
  implementation defects; the previously recorded 9,218 identifiers absent from the baseline are
  still not fully attributed.
- HEAD is `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree remains uncommitted with 118
  modified tracked paths and 16 untracked paths. No commit was created.

## WU-9 schema dump reconciliation

- `bin/rails db:verify_no_schema_drift` failed and reported nine dumps: the four WU-9 targets plus
  `avatar`, `chronicle`, `occurrence`, `op_base_app`, and `op_base_org`. The latter five are outside
  this work and were not changed.
- Re-ran the four authorized development schema dump tasks (`app_setting`, `app_zenith`,
  `org_setting`, `org_zenith`). A targeted `SchemaDriftVerification.dump_matches?` comparison then
  reported `match` for all four development databases.
- The same targeted comparison against all four test databases reported `drift`. Inspection of the
  APP principal test dump showed `CREATE UNLOGGED TABLE/SEQUENCE` and PostgreSQL-rendered CHECK
  expression text differences from the development dump. No test schema dump was written and no test
  database was changed by this comparison. Test principal schema equivalence is therefore not
  established by this check; the focused APP/ORG runtime tests passed separately above.
- The global drift task was not rerun after the four development dump updates: it also rejects
  schema files changed in the current uncommitted worktree, and the five unrelated dump differences
  remain. No unrelated schema dump was regenerated.
- The four development dumps were generated by Rails schema-dump tasks, not edited by hand. HEAD is
  `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the worktree remains uncommitted with 118 modified
  tracked paths and 16 untracked paths. No commit was created.
