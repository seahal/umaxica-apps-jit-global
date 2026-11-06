# ORG Emergency Passkey entry cancellation

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Extensive pre-existing uncommitted changes
  remain. This slice adds only the emergency Passkey page's parent cancellation prop/control and
  focused assertions in existing ORG HTTP/UI files. Other working-tree changes, including invitation
  test removal in the ORG UI test file, were preserved.
- Scope: `/sign/in/emergency/passkey/new` on Auth ORG. The controller now supplies
  `auth_parent_cancellation_form`; the page renders the existing `CeremonyCancellation` component
  after the Passkey panel. It uses the existing ORG cancellation POST, not a direct navigation or
  new cancellation writer. Passkey, Entra, standby eligibility and issuance policies are unchanged.
  A missing eligible parent yields no control.
- TDD Red: the new HTTP assertion failed with missing `parent_cancel` (1 run, 5 assertions, 1
  error). The targeted UI test failed because the cancellation form was absent (1 failed, 21
  passed).
- Green: `bin/rails test test/integration/sign_entry_exit_org_flow_test.rb`: 6 runs, 98 assertions,
  0 failures, 0 errors, 0 skips. The new case loads the Emergency entry, reads the supplied
  cancellation action, submits it, follows the existing Visa continuation, and verifies
  `access_denied`, absence of a code and canceled authorization parent. This existing test fixture
  uses the Core ORG RP and verifies its callback contract, not a live Base ORG interruption page.
- `bun run test gait/pages/auth/org/org_auth_screens.test.tsx`: 22 tests passed. Emergency page
  assertions verify the separate cancellation POST form and CSRF field alongside the retained
  Passkey panel and restricted-mode notice.
- Scoped RuboCop: 2 files, no offenses. Oxfmt on the two changed TSX files: passed. Oxlint on the
  emergency page alone: passed. Oxlint including the ORG UI test file reports existing unused
  `turnstile` at line 342 (eslint/no-unused-vars and TS6133); this variable and the prior removal of
  its invitation consumers were not changed here. That scoped combined lint check is not clean.
- Scoped `git diff --check`: passed. No live browser/mobile replay, full-suite run, configuration
  change or deployment was performed.
