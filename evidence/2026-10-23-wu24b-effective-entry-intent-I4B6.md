# WU-24b effective admission intent

- Date: 2026-10-23.
- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree: existing staged, unstaged and untracked changes plus uncommitted WU-24e/b work.
- Authority: `two.md` WU-24b, D-72; acceptance A24-1. Whole-unit gates remain open.

## Delivered behavior

- `AuthEntryIntentResolver` selects the persisted Switch intent when present; otherwise only
  the persisted OP `oidc_prompt=create` selects Sign Up. Ordinary authentication selects Sign In.
  Invalid intent values are explicit errors. Re-verification retains its purpose-specific checks.
- Base continuation validation, Auth redemption, admitted Auth context checks and Base confirmation
  return targeting use that resolver. Wrong-intent GET/POST refuse before consumption; an admitted
  ceremony cannot be reinterpreted by changing a route or request parameter.
- Storage remains unchanged in this sub-unit. WU-24c/d still need immutable curfew storage and
  NOT NULL, purpose-constrained intent. This is not completion of E1 or curfew enforcement.

## Executed checks

- Red: `bin/rails test test/controllers/auth/effective_entry_intent_test.rb`:
  8 runs, 16 assertions, 8 failures. APP/COM ordinary and create admissions each accepted the
  wrong entry at GET continuation and POST redemption (200/303 instead of 400).
- The first Green attempt exposed an incorrect new reader name (`prompt` instead of the existing
  `oidc_prompt`): 12 runs, 21 assertions, 8 errors. Corrected to the actual stored attribute.
- Green: the HTTP file plus `test/resolvers/auth_entry_intent_resolver_test.rb`:
  12 runs, 101 assertions, no failures/errors/skips. It covers unchanged valid redemption after
  rejection, Binding non-consumption, post-admission route tampering, Switch precedence and
  invalid input partitions.
- First broad run over 143 files selected by the coordinator/concern references plus the new
  tests and translation guard: 1556 runs, 17750 assertions, 96 failures, 1 error. New failures
  exposed registration fixtures that named a sign-up intent or `screen_hint` but omitted create.
- Updated rendering/transport inputs in APP/COM/ORG SignUps controller tests, OIDC entrances,
  sign-up suspension and regional link tests. The existing synthetic ORG rendering fixtures do
  not establish production support for ORG prompt=create. The wrong-purpose boundary test now
  asserts refusal on GET before a continuation is offered and preserves Binding/session counts;
  wrong-purpose POST is directly covered by the new HTTP matrix.
- The APP Secret and APP/COM email registration journeys now explicitly send prompt=create to
  the public OP endpoint instead of using a neutral login admission for later registration.
  Their existing assertions are retained.
- Focused fixture regression (10 files including new HTTP/resolver files):
  130 runs, 2812 assertions, no failures/errors/skips.
- Final combined run: `rg -l -0 --glob '*_test.rb'
  'BaseAuthAdmissionCoordinator|AuthCeremonyAdmission|AuthCeremonyContext' test | xargs -0
  bin/rails test` with the new HTTP/resolver files, cleanup/lock/issuer files and six selected
  invariant guards explicitly appended:
  1602 runs, 19796 assertions, 47 failures, 1 error, 0 skips; 53.337016 seconds.
  All 48 failing identities also occur in the initial full baseline; zero new failing identities.
  The two email signup journeys again reach their original later root-completion refusal after
  correcting their entry input, rather than being stopped early by the new intent check.
- Final RuboCop on all 23 changed/new WU-24b/e Ruby files: no offenses after scoped formatting
  corrections. Scoped `git diff --check`: passed.

## Limits

The remaining 48 broad-run failures/errors are retained without waiver in the cycle spec; no
passing G-1 or whole-cycle claim is made. Narrow success and unchanged failure identities do not
prove all flow behavior. WU-24c/d/g/h, sign-up unification, Visa, authority-stop and the other
remaining work/acceptance stay open in `specs/authentication-cycle-completion/tasks.md`.
