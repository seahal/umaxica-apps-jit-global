# WU-9 browser read boundary and writer regression slice

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree had 206 modified/staged tracked paths and 61 untracked paths before this evidence
  file was added. Existing changes were preserved; no commit was created.
- Scope: Base APP/ORG Preference display-cookie repair on GET/HEAD, response theme short codes,
  explicit locale overlay precedence, and removal of an unreferenced legacy consent dual-write
  helper. The helper search under `app` and `test` returned no callers before deletion.

## Verification

- The seven-file Base API/read group passed: 37 runs, 1,323 assertions, 0 failures, 0 errors, 0
  skips. It covered Base APP/ORG cookie and theme endpoints, Preference sign-in conflict, browser
  API contract, and GET/edit behavior.
- After the `PreferenceCore` change, the 24-file WU-9 regression group passed: 220 runs, 3,533
  assertions, 0 failures, 0 errors, 0 skips. It covered the shared write boundary, APP/ORG/COM
  browser API and binding behavior, consent, sign-in/out, reset, lifecycle purge, concurrency, and
  Visa continuation/logout.
- After formatting corrections, the five directly changed controller/integration test files passed:
  16 runs, 106 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop passed for the 12 changed controller/test files and separately for
  `app/controllers/concerns/preference_core.rb`; no offenses were reported.
- `git diff --check` passed.

The WU-9 closing full suite was not repeated in this slice. The earlier closure run and its
unclassified failures are recorded in `2026-11-01-wu9-closure-result-R6T2.md`; this focused pass
does not close the complete AC matrix or establish the final baseline comparison.

## Follow-up after concern cleanup

- `update_preference_cookie_dual_write!` had no callers under `app` or `test`; the remaining
  definition was removed from `PreferenceCore`. The anonymous option resolver now names every
  supported option type before returning an option name and raises for an unsupported type.
- Re-ran the 24-file WU-9 regression group after those code changes: 220 runs, 3,533 assertions, 0
  failures, 0 errors, 0 skips.
- RuboCop passed for `PreferenceCore` with no offenses. The runtime reference search returned no
  Preference adoption/refresh/DBSC/assurance or consent dual-write helper references under `app`,
  `config/routes`, or `lib`.
- Final `git diff --check` passed. HEAD remains `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`; the
  worktree has uncommitted changes (206 modified tracked paths and 62 untracked paths). No commit
  was created.

## Visa sign-in verification

- APP OIDC email sign-in with explicit Preference reflection and Preference signing failure passed:
  2 runs, 30 assertions, 0 failures, 0 errors, 0 skips. The success case asserts that only the
  explicit theme is reflected, account region is not copied, and explicit metadata remains intact.
- ORG Entra/Passkey completion with Preference reflection passed: 1 run, 111 assertions, 0 failures,
  0 errors, 0 skips. The test also checks root authority and account Preference immutability.
- APP Google/Apple sign-up and sign-in result journeys passed: 4 runs, 109 assertions, 0 failures, 0
  errors, 0 skips.
- These results cover APP and ORG Visa sign-in paths in addition to the 24-file Preference writer,
  logout, reset, consent, binding, and lifecycle regression group. The App Secret receipt-collection
  journey and its source-transaction boundary remain unverified as described in
  `2026-11-01-wu9-visa-post-continuation-Q7M2.md`.
