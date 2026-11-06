# SOC test resumption and plain response localization

Performed on 2026-11-02 against HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had
extensive pre-existing uncommitted changes affecting execution. This record describes the working
tree, not the committed tree.

## Scope

The owner requested resumption of the approved SOC-1..SOC-13 test-only instruction in `zero.md`,
then separately requested localization of literal `render plain:` messages. Existing tests were left
unchanged. No authentication or workflow correction was made for SOC failures.

Added `test/integration/social_login_soc_test.rb` (24 parameterized HTTP tests) and
`test/integration/plain_response_localization_test.rb` (4 provider/locale HTTP tests). Requests
enter through Base `/sign`, use separate Base/Auth/Visa cookie jars and real admission/continuation
endpoints. Provider results are fixtures, not live-provider verification. SOC-13 replaces HTTP
transport with in-process requests to real token, JWKS, UserInfo and dashboard-identity endpoints,
including the Base client JWKS lookup. No external HTTP or database rebuild/cleanup was performed.

## SOC results

Here `admission` means `test/integration/social_login_admission_test.rb`; `soc` means
`test/integration/social_login_soc_test.rb`; `apple` means
`test/integration/apple_social_flows_test.rb`; `login` means
`test/integration/social_auth_login_test.rb`.

| ID     | Coverage reused or added                                                                                                        | Google                            | Apple                             |
| ------ | ------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | --------------------------------- |
| SOC-1  | Existing `admission:609`, A29-6; existing `apple:41`, sign up waits for confirmation                                            | Pass                              | Pass                              |
| SOC-2  | Existing `admission:414,845,855`; Apple verified registered crossing at `admission:1145`                                        | Pass                              | Pass                              |
| SOC-3  | Existing `admission:27,312`; existing Dashboard completion at `login:534,3566`                                                  | Pass                              | Pass                              |
| SOC-4  | Existing `admission:836,855`; Apple verified unregistered crossing at `admission:1145`                                          | Pass                              | Pass                              |
| SOC-5  | Existing Google reserved actor at `admission:756`; added Apple `soc:30`                                                         | Pass                              | Pass                              |
| SOC-6  | Added both entry intents at `soc:136`                                                                                           | Pass, both                        | Pass, both                        |
| SOC-7  | Existing two-provider abandoned-start return at `admission:1251`                                                                | Pass                              | Pass                              |
| SOC-8  | Added both entry intents, initial dispatch plus two fresh admissions in the same browser, at `soc:286`; owner's 200 expectation | Pass, both                        | Pass, both                        |
| SOC-9  | Added provider refusal at `soc:419`                                                                                             | Pass                              | Pass                              |
| SOC-10 | Added Google confirmation and both birthdate cancellations at `soc:548`; reused Apple confirmation at `apple:399`               | Confirmation pass; birthdate fail | Confirmation pass; birthdate fail |
| SOC-11 | Added first-page and earlier-confirmation GET at `soc:759`                                                                      | First pass; confirmation fail     | First pass; confirmation fail     |
| SOC-12 | Added consumed callback replay for both entry intents at `soc:932`                                                              | Pass, both                        | Pass, both                        |
| SOC-13 | Added registered-signup guidance → fresh `/sign` → sign-in → Base Dashboard at `soc:1088`                                       | Pass                              | Pass                              |

Failing assertions retained:

- SOC-10, both providers, `soc:709`: expected cancellation redirect status **303**, actual **403**.
  The return-to-RP, terminal-parent and replay assertions after this point were not reached for
  these birthdate cases.
- SOC-11, both providers, `soc:916`: expected earlier-confirmation GET status **409**, actual
  **302**. Assertions about response cookies and unchanged records after this point were not reached
  for these cases. First-page cases passed those assertions.

These observations disagree with the approved SOC expectations. They do not independently identify
the cause of refusal or redirection. No fixture foreign-key errors occurred in the final runs. No
tests were skipped or weakened to match current behavior.

## Localization

The search `rg -n -U 'render\s*\(?\s*\n?\s*plain:\s*\n?\s*["\x27]' app --glob '*.rb'` found ten
executable literal sites and one comment. Six user-facing sites now call explicit translation keys:

- Google and Apple confirmation controllers: `sign.app.registration.confirmation_required`.
- Two plain stale-checkpoint branches in `sign_up_sequence_controller_support.rb`:
  `errors.messages.stale_checkpoint`. The JSON machine error remains `stale_checkpoint`.
- `browser_rp_unsafe_request_refresh.rb`: `errors.messages.invalid_browser_request`.
- `oidc_rp_logout_launcher.rb`: existing `errors.messages.login_required`.

Three keys were added to both existing bundles, `config/locales/en.yml` and `ja.yml`. Health check
`ok\n`/`unavailable\n` and the Base/Core NET service identifiers remain technical response values.
No HTTP status, CSRF check, admission or authentication decision was changed.

The new localization tests assert literal English/Japanese customer-copy fixtures,
missing/empty/false confirmation, and missing/empty/malformed/below/above checkpoint versions, with
no account/identity/token creation or flow advance. Existing SOC success coverage exercises the
current checkpoint version.

## Verification

- `bin/rails test test/integration/social_login_soc_test.rb test/integration/plain_response_localization_test.rb test/initializers/locale_bundle_integrity_test.rb`:
  **31 runs, 839 assertions, 4 failures, 0 errors, 0 skips**. The four failures are SOC-10/SOC-11
  above. Twenty SOC tests, four localization tests and three locale-integrity tests passed. Repeated
  after final test formatting with the same result.
- Existing coverage command:
  `bin/rails test test/integration/social_login_admission_test.rb test/integration/apple_social_flows_test.rb test/integration/social_auth_login_test.rb -i '/A29-6|admitted .* callback records|existing Google subject started at signup|verified unregistered Google subject|D-48 L[12]|R-AU-23|Apple verified|SOC-7|reserved existing social actor|sign up waits for confirmation|cancel after unknown Apple callback|login with existing identity completes|Google sign up refuses a birthdate submitted against a stale/'`:
  **19 runs, 418 assertions, 1 failure, 0 errors, 0 skips**. All 18 reused SOC cases passed. The
  unchanged `login:2697` assertion expects the old literal `stale_checkpoint`; actual body is the
  new Japanese translation. This existing-test/translation-contract discrepancy remains for the
  owner because the instruction forbids editing existing tests.
- `bin/rails test test/controllers/core/app/sign/outs_controller_test.rb -i '/sibling RP local session|root Browser Session/'`:
  **2 runs, 12 assertions, 0 failures/errors/skips**.
- RuboCop on both new tests and the five modified controller/concern files: **7 files, no
  offenses**.
- Both YAML bundles parsed successfully. Scoped `git diff --check` passed.

The complete test suite, real Google/Apple behavior and a live browser journey were not verified.
