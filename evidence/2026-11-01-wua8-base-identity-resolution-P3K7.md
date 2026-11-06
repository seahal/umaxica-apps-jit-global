# WU-A8 Base identity resolution through the RP cell

- `Base::App::ApplicationController#current_resource` and the ORG equivalent now resolve a verified
  local Base RP session through `BaseZenithIdentityResolver`. The shared-process path accepts only
  the exact canonical `Client` or `Operator` bound to the OP grant. Unknown session-binding shapes
  and wrong actor types raise instead of selecting another identity.
- Base Preference writes now use that canonical current actor after an exact realm-type check; they
  no longer resolve the same RP identity a second time in a `RuntimeRole` branch.
- The Base APP and ORG identity pages were added to the local-cell integration journey. The APP/ORG
  identity and Preference integration file plus the resolver test passed: 10 runs, 73 assertions, 0
  failures, 0 errors, 0 skips.
- Ruby syntax checks and `git diff --check` passed. Scoped RuboCop on both Base application
  controllers still reports four existing layout offenses (module include ordering and extra blank
  lines); it reports no offense on the added methods.
- The full suite was not run. Base routes that still require an OP root-token object for Step-Up,
  session management and credential operations remain outside this slice. The legacy shared-process
  authentication path and `RuntimeRole` remain; WU-A8 and `two.md` are not closed.
- `HEAD`: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree contained 636 staged, modified or
  untracked entries at the pre-evidence check; these changes are uncommitted.
