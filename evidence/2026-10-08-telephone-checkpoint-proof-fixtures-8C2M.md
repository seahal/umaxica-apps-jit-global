# Telephone checkpoint proof fixtures

Commit: `6405c465c82dd45625d294ad8f8c2fe7827a4390`; uncommitted worktree changes affect results.

The existing seventeen APP Telephone passkey/checkpoint cases retain their original security and
age/finalization assertions. Their existing fixture body now uses explicit signup admission and
public Base confirmation, actual encrypted SMS code, typed ceremony reference/generation and the
original signed flow binding on subsequent URLs. No new helper or production behavior was added.
Required references use semantic defaults, and the host has no environment default.

The first selected case errored before OTP because the old admission/number fixture created no
Contact (seed 40447). After current fixture preparation, it failed because the original redirect
expectation omitted the signed binding (one test/11 assertions, seed 29217). The fixture now
requires the exact original bound guard redirect using a boolean comparison rather than printing the
binding. It continues through the real guard and passkey endpoints.

The full normal file passed 17 tests/281 assertions, zero failures/errors/skips, seed 13842. Scoped
RuboCop and git diff --check passed after formatting. This covers proof-fixture migration, not
whole-suite completion; identifier HOTP schema retirement remains pending.
