# Retained three.md cycle: first acceptance pass over implemented scope

Date: 2026-10-19. HEAD: `ff58ff28125fafe405dc76809f6498b64d69e627`, dirty worktree containing the
uncommitted cycle changes under test (Cancel/Switch, Passkey limit and audit outbox, withdrawal
timing, Activity Log, credentials/DB configuration) plus unrelated user work. User request: start
acceptance on what is implemented only; deferred rows (AC-C*, AC-V*, deferred parts of AC-W09-W12
and AC-R01) are excluded per four.md's scope amendment.

## Run

Isolated receipt-verified fleet `POSTGRESQL_ISOLATED_TEST_RUN_ID=20261017c1a2`, manifest
`tmp/acceptance-isolated-20261017c1a2.json`, `POSTGRESQL_TEST_PREPARE_DATABASES` derived from the
manifest, `PARALLEL_WORKERS=2`.

- 47-file acceptance group (Cancel/Switch, Passkey operation/models/duplicates/removal/step-up,
  audit delivery, Activity Log, OIDC authority/resolver/transactions/surfaces, same-origin handoff,
  signup-to-signin completion, cross-surface isolation, admission coordinator, Org Standby policies
  and Emergency Step-Up prohibition, withdrawal lifecycle/ceremony/gate/timing, retention purge and
  cross-database child purge, signup cleanup, anonymizer, staff lifecycle): **453 runs, 4060
  assertions, 0 failures, 0 errors, 0 skips**.
- RP browser flow files (`oidc_rp_browser_flow`, `core_rp_browser_flow`, `base_rp_browser_flow`):
  **18 runs, 314 assertions, 0 failures, 0 errors, 0 skips**.

## Disposition (automated evidence only)

PASS means the row's listed examples are found in passing public-boundary tests. PARTIAL means some
examples pass and the named ones have no test found.

| AC                          | Disposition | Basis / gap                                                                                                                                                                                                                                       |
| --------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P01, P02 (replacement), P04 | PASS        | 9/10/11 per surface, per-owner limit, owner-lock concurrency test                                                                                                                                                                                 |
| P03                         | PASS        | `passkey_registration_writer_invariant_test` static guard                                                                                                                                                                                         |
| P05                         | PASS        | constraint-name classification per surface; DB unique index                                                                                                                                                                                       |
| P07                         | PASS        | removal committer and Base step-up tests (last-method, foreign actor, step-up)                                                                                                                                                                    |
| P08                         | PASS        | added `test/operations/identity_passkey_name_committer_test.rb` (3 tests, all surfaces)                                                                                                                                                           |
| P06, P09-P12                | PARTIAL     | related cleanup/anonymizer/removal tests pass; row-specific examples not mapped                                                                                                                                                                   |
| A02, A04, A05               | PASS        | rollback on invalid metadata and outer rollback; retry before ack converges; nil actor and occurrence time after deletion                                                                                                                         |
| A03                         | PASS        | failed event remains retryable while others deliver                                                                                                                                                                                               |
| A09, A10                    | PASS        | existing merge/limit 1-2-3/dedup/owner tests plus added empty owner, invalid limits (0, -1, nil, "1", 1.0), equal-time order and out-of-insertion-order history                                                                                   |
| A01, A06-A08, A11           | PARTIAL     | sanitizer and presenter tests pass; full event catalog and observability not mapped                                                                                                                                                               |
| H05-H07, H11, H13           | PASS        | 11 end-to-end Cancel/Switch tests and prompt tests; added RP callback tests: access_denied consumes only its matching flow and logs nobody in; unknown/blank state consumes nothing                                                               |
| H12                         | PASS        | prompt none success and login_required                                                                                                                                                                                                            |
| H01, H02                    | PARTIAL     | Standby policy and Emergency Step-Up prohibition pass; mode switch/Entra outage example not mapped                                                                                                                                                |
| H03, H04                    | PARTIAL     | existing `oidc/callback_test` and `oidc/sso_initiator_test` cover matching-flow consumption, expiry, mismatch, two-flow bound; added exact 10-minute TTL (accepted) and +1s (refused); concurrent lost-update across parallel requests not tested |
| H09, H17                    | PARTIAL     | canceled parent refuses late result; OTP/Passkey-in-progress supersession not mapped                                                                                                                                                              |
| H14-H16                     | PARTIAL     | signup-to-signin completion tests pass; per-method matrix not mapped                                                                                                                                                                              |
| W05                         | PASS        | timing policy value tests (order, non-positive, non-integer, production override refusal)                                                                                                                                                         |
| W01-W04, W08, W13           | PARTIAL     | lifecycle/ceremony/gate tests pass; exact threshold triplets not mapped                                                                                                                                                                           |
| W06                         | PARTIAL     | invalid development config refuses `bin/jobs check` (R8M2); valid-config startup not run                                                                                                                                                          |
| W07, R04-R07                | NOT RUN     | require actual production/worker execution                                                                                                                                                                                                        |
| R02, R03                    | PARTIAL     | retention purge continuation and child purge tests pass                                                                                                                                                                                           |
| G01-G04, H18, R08           | NOT RUN     | documentation review not performed in this pass                                                                                                                                                                                                   |

Manual browser acceptance (four.md final section): NOT RUN.

## Added acceptance tests (same session)

Isolated fleet as above. `identity_passkey_name_committer_test.rb` (new), additions to
`base_identity_activity_log_presenter_test.rb` and `oidc/callback_test.rb`: the three files run
together give **43 runs, 239 assertions, 0 failures, 0 errors, 0 skips**. All additions passed on
first run against unchanged application code; no defect was found. RuboCop clean on the three files.
The user accepted the known pre-existing full-suite failures (Avatar worker receipts,
`inertia_rails`) for this cycle.
