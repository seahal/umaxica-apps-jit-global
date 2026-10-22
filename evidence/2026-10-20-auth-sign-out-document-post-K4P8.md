# Auth sign-out forms submit as document POSTs

Commit: `febec3225cc9a0cfa53b9cbe817d20d366aba5a2` (worktree had uncommitted changes; the ones affecting this result are
`src/features/auth/session/SignOutConfirmation.tsx`, `SignOutUnavailable.tsx` and
`gait/features/auth/session/sign_out_{interaction,screens}.test.tsx`).

## Change
The Auth sign-out confirmation, cancellation and retry forms no longer submit through Inertia
`useForm`. They are plain `method="post"` forms carrying `authenticity_token` and, when present,
`logout_challenge` and `logout_intent_proof`, so the 303 to the cross-origin jump gateway is a
top-level navigation instead of a followed `fetch`. Controllers are unchanged.

## Results
- `node node_modules/vitest/vitest.mjs run`: 100 files, 1159 tests passed.
- `tsc --build`: exit 0. `oxlint` on the changed directories: no findings.
- Rails Minitest: the container process environment carried a stale
  `POSTGRESQL_TEST_PREPARE_DATABASES` (still listing `test_{app,com,org}_ticket_db`), so
  `db:test:prepare` aborted. Rerun with the value from `.env.container.devcontainer` overriding it:
  auth app/com/org `sign_outs_controller_test.rb`, `sign_out_inertia_history_clear_test.rb`,
  `sign_out_oneshot_contract_test.rb`, `sign_entry_and_logout_delegations_test.rb` —
  25 runs, 274 assertions, 0 failures, 0 errors, 0 skips.
- Playwright e2e: not added or run, by user decision (does not run in this environment).
