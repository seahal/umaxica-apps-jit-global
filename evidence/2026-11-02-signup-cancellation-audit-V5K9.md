# APP signup cancellation audit and routing correction

Commit: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The shared worktree had extensive pre-existing
uncommitted changes, including authentication fixes by another agent and the earlier Email HTTP
test. This record includes local changes from the interrupted Email/Telephone cancellation work and
the subsequent four-method audit. No production, Neon, schema, deployment or manual account cleanup
was performed.

## Contract and scope

The owner's request covers Email, Telephone, Google and Apple signup Cancel controls, first-page
versus progressed behavior, and refusal after registration completion. `one.md` D-49 says Cancel
ends the attempt, not Back; pre-completion steps may cancel, while completed registration is not
undone. Switch alone is first-page-only. `two.md` section 12.8 also distinguishes cancellation of an
unfinished parent login after durable account completion from deleting the completed registration.
The latter remains forbidden; this audit does not change that separate parent-login contract.

## Source audit matrix

| Point                                                       | Entry/control and authoritative checks                                                                                                   | Outcome and evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Initial signup method choice                                | `AppSignUpEntryPage`, `SignEntryExit#sign_entry_exit_forms`, POST `Auth::App::Sign::CancellationsController#create`                      | No signup Flow required. The admitted parent is checked, Auth continuity ends and the Visa cancellation continuation returns `access_denied` to the RP. Switch availability is narrower than Cancel. Existing first-page integration coverage mainly starts at Sign In; signup-specific first-page browser replay was not performed.                                                                                                                                       |
| Email/Telephone contact entry, before successful submission | `ContactSignUpForm` renders the `auth_parent_cancellation_form` supplied by the respective entry controller                              | Cancels the parent authorization, not a local navigation back. These entry controls include other-agent work already present in the shared tree; not attributed as new implementation here.                                                                                                                                                                                                                                                                                |
| Email OTP and birthdate                                     | DELETE checkpoint through `SignUpExplicitStepControllerSupport#cancel_from_explicit_step`                                                | Signed checkpoint gate and CSRF precede mutation. Signup cancellation/owned-artifact cleanup precede parent cancellation. Previously redirected to `/sign/up`, which refused with `not_on_first_page`; now uses Visa and the RP interruption page. Email OTP public HTTP journey reaches `/sign/interruption`, including a tampered flow-binding refusal preserving the Flow. Birthdate uses the same handler; no independent birthdate Cancel HTTP replay was added.      |
| Telephone OTP, Passkey and Secret                           | Each checkpoint DELETE calls the same explicit-step cancellation handler                                                                 | Same correction. OTP HTTP journey reaches `/sign/interruption`. Passkey and Secret call sites were inspected; their post-OTP Cancel HTTP journeys were not separately replayed.                                                                                                                                                                                                                                                                                            |
| Google/Apple provider navigation, before verified callback  | Provider POST dispatches signed callback state; no signup Flow is created until a valid callback                                         | No application-owned button can be rendered while the user is on the provider's external site. The parent authorization cancellation remains distinct from provider account/access revocation. External-provider browser behavior was not exercised.                                                                                                                                                                                                                       |
| Google/Apple confirmation and birthdate                     | Confirmation forms use DELETE and the signed flow binding; birthdate also uses `cancel_from_explicit_step`                               | Audit found the same stale-entry redirect still present after the earlier contact-only correction. Added public callback-to-confirmation cancellation assertions for both providers; both failed with `/sign/up` before the fix. Shared cancellation now includes `SignEntryExit` explicitly, keeps social-specific artifact cleanup, and sends the parent through Visa. Both confirmation tests pass. Birthdate uses the same handler but was not independently replayed. |
| FINALIZING                                                  | `FlowSignUp.sign_up_cancelable_status_ids` excludes FINALIZING; `SignUpStateMachine` rejects the normal cancel event                     | `docs/mermaid/idp-client-sign-up.mmd` and inventory row T037 explicitly also show the lower-level `cancel_sign_up!` model-map edge. That is not permission for the normal HTTP cancel event. The graph and inventory already distinguish these layers; do not interpret every model edge as a reachable button action. No new cancellation state edge was added.                                                                                                           |
| COMPLETED, all four methods                                 | Completed is terminal; step gate treats terminal signup tickets as unusable; the cancellation state machine rejects terminal transitions | Added four public-service regression tests, each with a completed Flow and active registered actor. Cancellation fails and all Flow/actor attributes remain identical. This verifies stored COMPLETED boundaries, not the separate Source-commit/Ticket-completion gap or a concurrent finalizer race.                                                                                                                                                                     |

## Changes and safety boundaries

- Extracted the APP parent-cancellation redirect sequence into
  `SignEntryExit#redirect_to_sign_entry_parent_cancellation!` and reused it from the existing APP
  parent-cancel controller and signup checkpoints. Existing parent issuance/commit, Auth SID
  deletion, session reset, Jump transport and Visa continuation are retained.
- All four signup families now preserve their existing signup cleanup and then follow the same
  parent cancellation route instead of restarting `/sign/up`. Successful checkpoint cancellation now
  returns the continuation redirect for JSON requests too; the former 204 response did not complete
  the parent cancellation. This is an intentional response-contract change at those cancellation
  endpoints.
- Added explicit `SignEntryExit` inclusion to the checkpoint concern because the standalone social
  confirmation controllers did not inherit it. The first social Green run exposed that missing
  dependency as two NameErrors; the explicit inclusion corrected it.
- No registered actor is deleted to make Cancel succeed. Signed bindings, nonce/ownership, phase
  gates, CSRF and current-parent checks remain in place. Completed-account cancellation already
  refused; tests were added rather than weakening terminal rules.
- Updated the signup Mermaid note/inventory and authentication-flow checklist. The checklist's
  Email-only challenge Cancel wording is now explicitly scoped to Sign In; signup Cancel ends the
  parent authorization. No account completion or expiry transition was changed.

## TDD and verification performed

1. Initial checkpoint controller test attempt: 2 errors before cancellation because the old tests
   received no registration redirect; not a Red proof of the intended defect. Those tentative
   assertion edits were removed.
2. Email Red:
   `bin/rails test test/integration/email_signup_http_delivery_commit_test.rb --name '/initial_Email_signup_commits/'`:
   1 run, 24 assertions, 1 failure, 0 errors. Expected `/oidc/cancellation`, actual `/sign/up`.
3. Email Green after minimal routing change: 1 run, 27 assertions, no failures/errors/skips.
4. Contact/parent regression run:
   `bin/rails test test/integration/email_signup_http_delivery_commit_test.rb test/integration/sign_entry_exit_flow_test.rb test/integration/sign_entry_exit_org_flow_test.rb test/policies/sign_up_step_gate_refusals_test.rb`:
   21 runs, 371 assertions, no failures/errors/skips. Includes Email and Telephone OTP cancellation
   through Visa to the actual Base interruption page, and the tampered Email flow binding. This
   preceded the later all-method extension; contact behavior is unchanged by that extension.
5. Completed registration boundary tests alone: 4 runs, 24 assertions, no failures/errors/skips.
6. Social Red: `bin/rails test test/integration/social_signup_missing_flow_test.rb`: 2 runs, 38
   assertions, 2 failures, 0 errors. Both providers expected `/oidc/cancellation`, actual
   `/sign/up`.
7. Social/terminal Green after fixing the explicit dependency:
   `bin/rails test test/integration/social_signup_missing_flow_test.rb test/services/sign_up/completed_cancellation_boundary_test.rb`:
   6 runs, 66 assertions, no failures/errors/skips. The earlier Green attempt had two missing-method
   errors, described above.
8. Final combined rerun including existing social cleanup tests: initialization failed with
   `ActiveRecord::NoDatabaseError` for `test_rp_base_org_db`. Earlier attempts also encountered the
   shared test-process lock. No lock was bypassed or foreign process stopped, and no database was
   created/reset. A subsequent rerun of the same seven-file command succeeded: **31 runs, 460
   assertions, 0 failures, 0 errors, 0 skips**. This is the final focused regression result; it does
   not represent the repository-wide suite.
9. Scoped RuboCop on `sign_entry_exit.rb`, `sign_up_explicit_step_controller_support.rb`, APP sign
   cancellations controller, Email HTTP test, social callback HTTP test and completed-boundary test:
   6 files, no offenses. Scoped `git diff --check` passed.

## Remaining audit limits

Real browser button visibility, installed Service Workers, provider-site cancellation, each later
checkpoint independently, deadline/finalizer competition, failed parent-delivery recovery after
signup cleanup, and the durable Source completion versus Ticket status gap were not newly verified.
Existing D-49/D-40 serialization and two.md completion-receipt requirements still apply. A pending
parent-login cancellation after completed registration must not be described as undoing that
registration. Full-suite acceptance is not claimed.
