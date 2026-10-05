# Step-Up observability, characterization, and status-write consolidation

Date: 2026-10-05

Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. The worktree held several hundred uncommitted
changes before this work started, and every result below was measured on that worktree, not on the
commit alone.

## Scope of the work verified

- Phase 1: keyed correlation references, internal refusal codes, and ceremony log events on the
  Base and Auth Step-Up paths; an `auth.session.authentication_required` diagnostic.
- Phase 2A: characterization tests for the transaction model's transitions as they behave today.
- Phase 2B: every Step-Up transaction status write routed through one model method, with no change
  to observable behavior.
- Step-Up tests that entered Auth through the retired signed-grant contract were rewritten against
  Base admission.

## Results

Baseline before any change, 17 Step-Up test paths:

```text
283 runs, 1644 assertions, 75 failures, 12 errors, 0 skips
```

After Phase 2B, before the legacy tests were rewritten, the same paths failed with the identical set
of test locations (compared by `bin/rails test <file>:<line>` lines); one failure became an error
because that test built a controller without a request.

After the rewrite, the same paths plus the new test files:

```text
365 runs, 2349 assertions, 0 failures, 0 errors, 0 skips
```

Final run over the changed tests, `test/controllers/auth/step_up_admission_test.rb`,
`test/operations`, `test/consumers`, and the transaction, coordinator and credential-transition
tests:

```text
790 runs, 5446 assertions, 0 failures, 0 errors, 0 skips
```

`bundle exec rubocop` over the 43 changed application and test files reported no offenses.

## Not green, and not caused by this work

`bin/rails test test/controllers/auth test/controllers/base` finished with:

```text
2012 runs, 11012 assertions, 133 failures, 37 errors, 0 skips
```

The failing classes are sign-in and sign-up controller tests and three tests that reference a
missing `client_secret_credential_kinds` fixture. None of the failure output references a file or
method added or changed here. The worktree could not be reset to prove these failed beforehand, so
this is an inference from the failure output, not a measured before/after comparison.

`bin/rails test test/unit/security test/security` reported four failures in files this work did not
touch (`auth/*/sign/in/challenge/passkeys_controller.rb`,
`client_secret_manual_issuance_invalidator.rb`, and the Base dashboard read-only route invariant).

## Observations from the development environment

Read-only queries against the development database and logs; no row was written.

- The most recent client session was created at 02:13:03 UTC, last used at 02:17:19, and was still
  active with its 30-day expiry and refresh generation 1 at 03:35 UTC. No Step-Up transaction
  referenced it.
- `log/development.log` contained no `auth.credential_rejected` event.
- After the diagnostic was added, the running server logged one live
  `auth.session.authentication_required` event at 03:44:30 UTC for
  `Base::App::Identity::ActivitiesController#index` with `failure_reason: blank_access_token`,
  `access_credential_presented: false`, and `refresh_credential_presented: false`.

Whether that request came from the browser that owned the 02:13 session is not established. A
controlled reproduction with an authenticated browser was not performed.

## Status of the suites

```text
targeted suites: green
broader suites: pre-existing/unclassified failures remain
```

The broader `test/controllers/auth` and `test/controllers/base` run, the four security guard
failures, and five failures in `test/services/identity/step_up_ceremony_contract_test.rb` (calls to
a committer signature the worktree had already replaced) are not evidence for or against this work.
They are recorded here as separate, unclassified problems.

## Removed tests and their replacements

| Removed file | Reason | Replacement |
| --- | --- | --- |
| `test/controllers/auth/app/verification/passkeys_controller_coverage_test.rb` | Subclassed the controller and drove private methods through `send` and instance variables; the branches it named no longer exist. | `test/controllers/auth/step_up_admission_test.rb` ("Passkey GET creates no challenge and options POST binds the admitted transaction") and `test/operations/identity_step_up_passkey_verification_committer_test.rb`. |
| `test/controllers/auth/org/verification/setups_page_props_test.rb` | Same harness pattern; tested a redirect for "nothing left to configure" that the admission-only setup page no longer performs. | `test/controllers/auth/org/verification/setups_controller_test.rb` (admitted bootstrap page; refusal without admission). |
| `test/controllers/auth/com/verification/emails_resend_guard_test.rb` | Entered Auth through the retired signed grant. | `test/controllers/auth/com/verification/emails_controller_test.rb` ("a second code is not issued inside the resend interval and the first code stays valid"). |
| `test/integration/verification_sessions_test.rb` | Tested an Auth-side "skip verification while fresh" shortcut that Auth no longer owns. | `test/controllers/base/step_up_intent_authority_test.rb` ("app base verification returns to the protected page without a new ceremony while freshness is valid"). |
| `app/consumers/identity_step_up_ceremony_result_consumer.rb` and its three tests in `test/services/identity/step_up_ceremony_acme_transaction_test.rb` | The signed-result consumer had no caller in `app/` and consumed a pending transaction directly, which the transition contract now forbids. | `test/models/step_up_ceremony_transaction_transition_test.rb` (consumption requires verified evidence) and `test/operations/identity_step_up_ceremony_freshness_committer_test.rb`. |

## Phase 2C addendum (same day)

After the transition contract, return-target ordering, expiry handling and bootstrap freshness
window were implemented, the targeted run reported:

```text
769 runs, 5630 assertions, 0 failures, 0 errors, 0 skips
```

The Base method choice, the email bootstrap committer and their tests were written while another
session held `tmp/parallel-test-databases.lock` with a full-suite run that had been silent for more
than ten minutes. That process (pid 162930) was stopped on the user's instruction and the tests were
then executed. Nine tests ran in `test/controllers/base/app/verification/setups_controller_test.rb`;
seven failed and one errored on the first run because the test signed its return target with the
token's public id instead of the stable session identifier, and because an invalid method raised
instead of rendering the plain refusal. After those two corrections:

```text
917 runs, 6582 assertions, 0 failures, 0 errors, 0 skips   (targeted Rails suite)
9 files, 127 tests passed                                    (Vitest, spec/features/base)
49 files inspected, no offenses detected                     (rubocop)
```

Five existing tests changed with the behavior: an actor without an authenticator is now sent to the
Base method choice instead of receiving a multi-method bootstrap for the Auth setup page, and email
is a bootstrap method on surfaces that support it.
