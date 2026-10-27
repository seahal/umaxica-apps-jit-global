# RuboCop autocorrect review

Performed against commit `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree was already
dirty with the queued acceptance-test implementation and unrelated dependency/configuration edits;
those changes were preserved. This review changed only
`test/controllers/auth/admission_redemption_input_boundary_test.rb` and added this evidence file.

The task's original `bin/rubocop -A` output was not present in the repository or `tmp/`. The current
commit also contains broad implementation and test changes, so their individual authorship cannot
be inferred from the commit diff. I reviewed the corrections named by the task and left other
unattributable changes untouched.

## Correction review

| File:line | Cop | Behavior changed? | Action |
| --- | --- | --- | --- |
| `test/controllers/auth/admission_redemption_input_boundary_test.rb:60` | `Lint/Void` | The reported `merge!` correction would fail because `Rack::Test::CookieJar` provides mutating `merge`, not `merge!`. The file already used `merge`; its inline disable was itself prohibited by this repository's RuboCop configuration. | Kept `merge` and assigned its ignored result to `_merged_cookie_jar`; removed the directives. The file's 84 tests pass. |
| `test/controllers/auth/ceremony_admission_boundary_test.rb:134` (former `headers` assignment) | `Lint/UselessAssignment`, `Lint/Void` | No request-shape loss is evident: the revoked-device case attaches through `attach_auth_ceremony_entry!` and then uses GET requests. No later POST in that case consumes the removed Origin/Fetch headers. | Left the assignment removed. The ceremony file passed in the combined four-file run. |
| `test/controllers/auth/ceremony_admission_boundary_test.rb:176` | `Lint/UselessAssignment` | Unclear. The current contact-POST test drops the `OidcTestEntry.issue!` result and does not use its reference, while the surrounding test flow differs substantially from the parent revision. The current assertions still check a refused direct POST and no contact/actor writes, but do not establish that the browser holds an unconfirmed binding for that issuance. | Left unchanged because the diff does not establish whether this came from autocorrect or the in-progress test rewrite. Flagged as an unresolved coverage/provenance concern. |
| `app/operations/client_secret_passkey_reservation_issuer.rb:355` | `Style/ReturnNilInPredicateMethodDefinition` | The predicate now returns `false` instead of `nil` on refusal. Its only caller uses the result in boolean conditions and a truthiness check; it does not distinguish `nil` from `false`. | Left unchanged; caller behavior is equivalent. |
| `app/controllers/concerns/authentication_logout_current_session.rb:52` | `Lint/UnusedMethodArgument` | Renaming the unused argument to `_token_record` does not affect behavior. | Left unchanged under the sign-out hold. |
| `app/operations/avatar_ownership_transfers/operation.rb:13-17` | `Style/GuardClause` | The early returns accept the same two cases (both optional values absent, or a valid Step-Up context); all other cases raise `InvalidTransfer`. | Left unchanged. |
| `app/services/oidc_end_session_request.rb:118-124` | `Style/GuardClause`, `Style/RedundantReturn` | The `id_token_hint` subject mismatch still returns `invalid_request`; a match or missing expected subject continues. | Left the logout-area code unchanged. Separately, the current branch no longer checks an `id_token_hint` SID mismatch that the parent revision checked. That broader behavior change is not attributable to autocorrect from the available diff, so it remains untouched and needs owner review. |
| `app/operations/client_secret_storage_confirmation_committer.rb:94` | `Style/SafeNavigation` | `nil` still skips Step-Up consumption. `false` would differ, but supported callers provide a persisted `ClientToken` or `nil`; `call!` rejects other values before this path, and the sign-up path uses the `nil` default. | Left unchanged; no supported public call reaches the `false` case. |
| `config/initializers/i18n_missing_translation_logging.rb:9-22` | Layout correction | The handler still logs only for production missing-translation exceptions and always delegates to the captured previous handler. | Confirmed behavior-neutral. |
| `test/controllers/auth/app/sign/up/check/email/birthdates_controller_test.rb:267-271` | Lambda reindent; `Lint/RedundantCopDisableDirective` | No behavior change was found in the reindent or removal of the redundant directive pair. | Confirmed the test body and file structure through execution. |
| `test/controllers/auth/com/sign/up/check/email/birthdates_controller_test.rb:185-197` | Lambda reindent | The callback and SQL notification subscription remain intact. | Confirmed the test body and file structure through execution. |
| `test/controllers/auth/effective_entry_intent_test.rb:54-57` | Argument layout | The call still passes `valid_path`, `issuance.reference`, the `ri` parameter, and `browser`. | Confirmed; no argument change. |
| Other `[Corrected]` offenses | Not available | The original autocorrect output and an isolated autocorrect-only diff are unavailable, so attribution for other changed lines cannot be established from the broad current commit. | No additional changes made. Unattributable changes remain for the owner to map to the original RuboCop output. |

## Verification

- `bin/rails test test/controllers/auth/admission_redemption_input_boundary_test.rb`: 84 runs,
  672 assertions, all passed.
- `bin/rails test test/controllers/auth/ceremony_admission_boundary_test.rb
  test/controllers/auth/app/sign/up/check/email/birthdates_controller_test.rb
  test/controllers/auth/com/sign/up/check/email/birthdates_controller_test.rb
  test/controllers/auth/effective_entry_intent_test.rb`: 68 runs, 1,586 assertions, all passed.
- An earlier isolated run of `ceremony_admission_boundary_test.rb:158` stopped during fixture setup
  with `client_chronicles.event_id=36` missing from `client_chronicle_events`; the later combined
  run passed all four files.
- `bin/rails test test/operations/*client_secret* test/operations/avatar_ownership_transfers_test.rb
  test/operations/avatar_ownership_transfers_concurrency_test.rb
  test/operations/avatar_ownership_cutover_operation_test.rb test/initializers`: 172 runs,
  2,253 assertions, all passed.
- No `test/services/oidc_end_session_request*` file exists.
- `bundle exec rubocop` on the 11 files named in the review inspected all 11 and reported one
  uncorrected `Lint/EmptyWhen` offense at
  `test/controllers/auth/admission_redemption_input_boundary_test.rb:122`. No other offense was
  reported in that targeted set after the directive removal.
- The task's remaining `Metrics/*`, `Layout/LineLength`, `Lint/DuplicateBranch`, `Lint/EmptyWhen`,
  and `Rails/SkipsModelValidations` offenses were not changed. Only the targeted set was scanned;
  a repository-wide offense listing was not produced.
- `git diff --check` passed. No full test suite or repository-wide RuboCop run was performed.

The worktree had uncommitted changes throughout; this evidence records work against the full commit
hash above.
