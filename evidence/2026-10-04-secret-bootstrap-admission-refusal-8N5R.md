# Secret-root bootstrap admission refusal

Performed 2026-10-04, recorded at 04:15 UTC (Etc/UTC).
Rails `feature`, HEAD f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5.
The preceding status capture had 376 dirty paths, including concurrent work.
These results include uncommitted changes and are not CI results.

BaseStepUpAdmissionIssuer rejects a bootstrap requirement for a normal
Secret-derived Client Token after token reload/lock and usability validation.
Both Passkey and TOTP registration are refused without creating a Ticket
ceremony or Step-Up session. Ordinary Step-Up using another permitted method
remains available. The HTTP test uses a valid signed return path and prepared
normal root session; it does not claim to perform Secret Sign in.

VerificationBase's no-method refusal is scoped to Secret-derived Client root
sessions. The previous broader Client-root refusal also blocked the existing
non-Secret first-registration journey, so it was narrowed. That correction
preserves the separate initial-registration contract rather than granting
Secret bootstrap authority. Signup without a Client root Token remains separate.

## Commands and results

All Rails executions used the existing guarded task-only database wrapper:
`bundle exec ruby /tmp/umaxica-secret-db-task.rb test <paths>`.

- Red: `test/operations/app_secret_step_up_binding_test.rb`, 7 tests/28 assertions,
  one failure: Secret-root Passkey bootstrap was accepted. No setup error counted
  as product Red.
- Expanded regression: app Secret binding, admission issuer, Passkey Secret-session
  HTTP and TOTP registration boundary files initially ran 22 tests/251 assertions,
  one failure and one error. The failure exposed the broader no-method refusal;
  the error was the persisted constraint mismatch below.
- After scoping refusal to Secret sessions, the same selection ran 22 tests/257
  assertions, zero failures and two errors. Both errors are TOTP registration
  evidence rejected by the persisted check constraint; they remain unresolved.
- Focused regression including app binding/admission, the new HTTP test, actual
  Base freshness committer and com/org Passkey controller suites:
  **80 tests/496 assertions, zero failures/errors/skips**. HTTP verifies both
  Secret-root bootstrap POSTs return 400 with no ceremony and preserves the
  separately bound Passkey Step-Up authorization test.
- RuboCop on the issuer, VerificationBase and two changed test files: four files,
  no offenses after formatting corrections. No suppression or threshold change.
- `git diff --check`: PASS.

## Observed database mismatch

Read-only runner `/tmp/umaxica-registration-db-shape.rb` inspected
`codex_integrity_20261003secret_app_ticket`. schema_migrations contains both
20261003185506 and 20261003221628, but the actual
`client_step_up_verified_credential_present` constraint still requires a nonempty
verified_credential_ref for every verified transaction. The current migration
and app_ticket_structure.sql instead distinguish bootstrap/credential_registration
evidence, which legitimately has no existing verified credential reference.

The first diagnostic runner used deprecated `.connection` and failed before
inspection; correcting it to `.with_connection` completed the read-only diagnosis.
No constraint was relaxed, migration history rewritten or database reset here.
FAIL: this disposable fleet does not match the checked-in registration constraint
shape. The TOTP registration regression is not green.

NOT_RUN: full suite, complete Secret login, real browser/cryptographic Step-Up,
new Secret delivery and Chronicle/purge integration. Other bootstrap paths and
already-issued legacy registration continuations still need lifecycle review.
