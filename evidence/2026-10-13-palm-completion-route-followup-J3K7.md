# Palm completion route follow-up

Recorded 2026-10-13 against full HEAD
`aa92265b7e63bf874fddd0aa8f278d5ed19de6b5`, branch `feature`. The worktree had extensive
uncommitted changes; unrelated changes were preserved.

Document reconciliation found that Palm's challenge page still generated its POST action with the
sign-out start route, and its unsafe-request refresh callback could attempt a refresh after the
authority phase had revoked the parent. Palm's completion controller now posts to the dedicated
`/sign/out/completion` resource and uses the durable logout challenge for continuation without
attempting that refresh. The common confirmation view omits DELETE cancellation while a challenge is
present.

The Palm completion integration test follows the initial region-normalization redirect, reads the
rendered authenticity token and form action, then posts the form. It verifies the transaction is
finalized, the captured Palm RP session is revoked, and the parent token remains unchanged. The
final focused Tech/Palm, shared logout, Base authority-first and capability selection passed: 156
runs, 865 assertions, 0 failures, 0 errors and 0 skips. The test command used
`RAILS_ENV=test`, `PARALLEL_WORKERS=1` and an unset `POSTGRESQL_ISOLATED_TEST_RUN_ID`; only the
ordinary Rails test databases were used, with no reset or migration. RuboCop passed for 19 touched
Ruby files, and `git diff --check` passed.

This closes the local Palm/Tech completion-route form defect. It does not complete the global
parent-and-RP transaction, BCL removal, full registered-RP matrix or real browser/manual acceptance.
