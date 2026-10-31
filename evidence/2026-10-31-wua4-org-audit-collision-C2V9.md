# ORG Passkey audit collision

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree had extensive uncommitted changes, including the exercised code.
- An ORG Chronicle row with the Source UUID and a conflicting actor is refused; the Source event remains pending while a later event is delivered with a batch size of one.
- `PARALLEL_WORKERS=1 bin/rails test test/jobs/passkey_audit_delivery_job_test.rb test/concurrency/passkey_audit_delivery_commit_order_test.rb`: 9 runs, 84 assertions, 0 failures, 0 errors, 0 skips.
- The collision case uses transactional fixtures. Other independent failure modes and the full suite were not checked.
