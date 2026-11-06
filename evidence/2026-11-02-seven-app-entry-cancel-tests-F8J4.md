# Seven APP Sign In / Sign Up entry cancellation paths

- Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Extensive pre-existing uncommitted changes
  remain. The existing fixture-free HTTP test file was already untracked and contained prior
  delivery/cancellation work; those cases were preserved. This slice changes tests and their
  checklist/evidence, not application behavior.
- Coverage audit found existing first-Sign-In-page cancellation protocol tests, an Email Sign In
  input-to-interruption HTTP case, and signup Email/Telephone entry controller tests ending at a
  Jump redirect. These did not form an explicit seven-path end-to-end matrix. Signup OTP checkpoint
  tests are later phases and do not substitute for the requested entry screens.
- Expanded the existing Email Sign In input case in
  `test/integration/email_signup_http_delivery_commit_test.rb` into seven separately named HTTP
  tests:

| Screen                   | Path                     | Cancel property read from rendered Inertia response |
| ------------------------ | ------------------------ | --------------------------------------------------- |
| Sign In method selection | `/sign/in`               | `cancel_form`                                       |
| Sign In Email input      | `/sign/in/email/new`     | `cancel`                                            |
| Sign In Passkey          | `/sign/in/passkey/new`   | `cancel`                                            |
| Sign In Secret           | `/sign/in/secret/new`    | `parent_cancel`                                     |
| Sign Up method selection | `/sign/up`               | `cancel_form`                                       |
| Sign Up Email input      | `/sign/up/email/new`     | `cancel`                                            |
| Sign Up Telephone input  | `/sign/up/telephone/new` | `cancel`                                            |

Each case starts at the real Base neutral entry, follows Visa/Auth admission, switches to signup
where applicable, loads the named page with `ri=jp`, and submits the page-provided cancellation
action with forgery protection enabled and the current CSRF token. It asserts the Auth ceremony and
authorization parent are cancelled, follows Visa's continuation form, checks the RP callback carries
`access_denied` and no authorization code, and finally verifies the Base host and
`/sign/interruption` response with HTTP 200. The tests use real controllers/services, without
mocking cancellation behavior. They operate through HTTP; they do not render/click React in a live
browser.

- Strengthened the existing shared cancellation assertion to validate the callback's error/code
  contract, so reaching the generic interruption page for an unrelated error cannot satisfy that
  part of the test.
- Preserved the three existing signup delivery/OTP cases. Updated
  `docs/checklists/authentication-flow-integrity.md` with the seven-path mapping.
- Final `bin/rails test test/integration/email_signup_http_delivery_commit_test.rb`: **10 runs, 295
  assertions, 0 failures, 0 errors, 0 skips**. This includes the seven entry paths plus the three
  existing cases. Earlier matrix run passed 10/250 before callback assertions were added; the final
  run includes the stronger assertions and helper refactoring.
- Final `bin/rubocop test/integration/email_signup_http_delivery_commit_test.rb`: 1 file, no
  offenses. An intermediate helper exceeded ABC size and was split into continuation and callback
  assertions before final verification. Scoped `git diff --check`: passed.
- Social-provider paths and later OTP/credential checkpoints are outside this seven-path matrix;
  their pre-existing tests remain. No full-suite run or new live-browser session was performed in
  this test-only slice.
