# Email sign-in address-page parent cancellation

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Extensive pre-existing uncommitted changes
  remain, including related authentication work. This verification includes local modifications to
  the Email input props/component, their existing Vitest files, the existing fixture-free HTTP
  journey file and the authentication-flow checklist.
- Root cause: `EmailsController#email_new_props` supplied a Back link but no cancellation action,
  and `EmailSignInForm` rendered no Cancel component. The admitted parent cancellation endpoint
  already existed.
- Change: supply `auth_parent_cancellation_form` as nullable `cancel` props and render the existing
  `CeremonyCancellation` component outside the Email submit form. Cancel uses the existing
  CSRF-protected POST, does not require address/Turnstile validation and follows the authoritative
  parent cancellation via Visa to the Base RP `/sign/interruption` page. The existing
  method-selection Back link remains separate. No new state writer, route or transition was added.
- TDD Red: targeted Email form interaction test failed because the cancellation form was absent (1
  failed, 34 passed). Green after adding the props and existing component:
  `bun run test gait/features/auth/signin/signin_interaction.test.tsx gait/features/auth/signin/signin_screens.test.tsx`
  passed, 2 files and 53 tests. The new interaction case verifies the independent native POST,
  absence of Email/Turnstile fields in it, current-document CSRF and submit disabling; existing
  null-cancellation fixtures continue to pass.
- HTTP test: starts at real Base `/sign`, follows admission into Auth, opens `/sign/in/email/new`,
  reads the server's cancellation props, submits with CSRF protection enabled and follows Visa's
  signed continuation to Base `/sign/interruption` (200). An initial attempt was blocked by the
  shared test-process lock. The next attempt exposed a test parsing error (Inertia's JSON is in
  script text, not a data attribute); that test code was corrected to the repository's existing
  script-text format.
- Final HTTP regression:
  `bin/rails test test/integration/email_signup_http_delivery_commit_test.rb test/integration/sign_entry_exit_flow_test.rb`:
  14 runs, 294 assertions, 0 failures, 0 errors, 0 skips.
- Scoped RuboCop: 2 files, no offenses. Scoped Oxlint and Oxfmt checks on the three changed TSX
  files: exit 0. Scoped `git diff --check`: passed.
- Checklist update documents address-page parent cancellation and corrects the older OTP
  description: current OTP UI can use a parent action, with a separate local DELETE fallback. That
  OTP behavior was already present and is not changed in this slice.
- Limits: no live browser or mobile replay, full repository test run or deployment was performed.
  Vitest covers rendered interaction in its configured environment; the Ruby HTTP test verifies the
  server-side continuation journey. No credentials, tokens, addresses or raw requests are retained
  here.
