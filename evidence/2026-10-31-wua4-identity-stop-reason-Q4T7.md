# Identity-stop reason validation

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. Substantial uncommitted worktree changes affected the implementation and tests.
- The focused test called the recorder with an unsupported reason while holding the actor lock. Before the change it returned normally rather than rejecting the reason: 1 run, 1 assertion, 1 failure. The OP invalidator already rejected that reason, so such a source event could not be applied.
- The recorder and invalidator now use one mapping containing the reason/cause combinations previously accepted by the invalidator. The recorder checks it before changing the actor epoch or inserting an event. Tests exercise unknown, missing, empty and wrong-type reasons while keeping the surrounding transaction open; no event or epoch change is allowed.
- `PARALLEL_WORKERS=1 bin/rails test test/operations/op_identity_event_invalidator_test.rb test/jobs/op_identity_event_sweep_job_test.rb test/concurrency/op_authority_stop_concurrency_test.rb test/services/administrative_access_lock_test.rb test/services/oidc_access_token_authenticator_test.rb`: 60 runs, 352 assertions, no failures, errors or skips. Scoped RuboCop passed.
- Historical malformed events, actual queue or OP outages, production data and the full suite were not inspected or tested.
