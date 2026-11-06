# OP Step-Up independent work recheck

HEAD: `b30345216886c98af1f04cbd434f067f12decf01`. The worktree was extensively uncommitted; this
evidence applies to the current working files and does not attribute the other changes to this run.

## Checks performed

- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/controllers/base/org/support/enforcement_approval_failures_test.rb test/controllers/base/org/support/enforcement_cases_controller_test.rb test/controllers/base/org/support/session_revocations_test.rb test/controllers/base/org/support/standby_enforcement_cases_controller_test.rb test/integration/base_org_iam_owner_api_test.rb test/operations/enforcement_case_apply_failure_test.rb test/operations/enforcement_case_apply_authority_test.rb test/operations/enforcement_case_apply_concurrency_test.rb test/operations/enforcement_case_end_missing_principal_test.rb`
  — **69 runs / 374 assertions / 0 failures / 0 errors / 0 skips**, seed `44306`. This run did not
  reproduce the earlier random-order 204 response.
- `RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/operations/enforcement_case_apply_concurrency_test.rb`
  — **1 run / 5 assertions / 0 failures / 0 errors / 0 skips** after removing the attempted
  lock-order test described below.
- Ruby syntax checks passed for `browser_rp_authentication.rb`, `rp_cell_local_session.rb`,
  `session_revocations_test.rb`, `base_shared_rp_cell_selection_test.rb`,
  `avatar_ownership_transfers_controller_test.rb`, `step_up_authentication_test.rb`,
  `base_rp_contact_registration_refusal_test.rb`, and `enforcement_case_apply_concurrency_test.rb`.
- Scoped `bundle exec rubocop` on those eight files passed with no offenses. Scoped
  `git diff --check` passed.
- The latest post-switch run recorded in the working `zero.md` and preceding evidence is **52 runs /
  265 assertions / 3 failures / 0 errors / 0 skips**. The failures remain Q-1's valid Security Mode
  downgrade (422) and two APP contact-registration expectations blocked by the fail-closed 503.

## Uncompleted lock-order probe

An additional independent-connection test was attempted for the actor-first Case apply path. Its
operation worker hit the configured PostgreSQL lock timeout while the test held the Operator row;
the run ended **2 runs / 5 assertions / 0 failures / 1 error** and did not establish the intended
lock-winner observation. The attempted test was removed, and the existing concurrency test was rerun
successfully. No independent-connection proof for every changed Case path is claimed.

## Scope and limits

`five.md` was re-read at SHA-256 `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`.
Its C9-listed closed slices are already implemented; the remaining C5 choices and the accepted
invalid-browser-credential recovery conflict leave no further safe feature slice under C0. Existing
five.md implementation dilemmas are recorded in `six.md`; no new five-specific dilemma was found.

O-9 endpoints and routes remain disconnected pending review of
`specs/op-mediated-step-up/contracts/o9-visa-roundtrip-design.md`. Q-1, contact-registration
API/receipt, and Support session-revocation source-result shapes remain proposals without required
approval. The lock inventory names 88 lexical candidates but is not a complete interprocedural
graph. Only configured test databases were accessed; no manual test DB cleanup, development DB
access, or production DB access was performed.
