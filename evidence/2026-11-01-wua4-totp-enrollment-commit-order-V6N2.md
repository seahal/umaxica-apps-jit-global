# WU-A4 XDB-10 TOTP enrollment commit boundary

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree was already extensively dirty. This slice is uncommitted; no staged changes or commit
  were created.
- The finalizer now rejects a caller-owned OP transaction before reading the admission result. Its
  test class runs without transactional fixtures and explicitly removes the actor-owned rows. The
  state diagram and transition inventory now describe the independent OP commit boundary.
- The targeted finalizer file passed: 6 runs, 84 assertions, no failures, errors or skips. It
  exercises outer-OP refusal, notification-observed OP-before-Zenith commit order, OP commit failure
  before consumption, Zenith commit failure after OP consumption, and fail-closed retry when the
  consumed OP record has no Zenith credential. The pre-edit file passed 6 runs / 67 assertions.
- Scoped RuboCop passed for the operation and test files. Ruby syntax and scoped `git diff --check`
  passed.
- The first nontransactional run exposed a teardown foreign-key omission for Auth Ceremony rows (1
  failure, 5 errors). Teardown was corrected and the test-owned actors from that run
  (`980190969`–`980190974`, created 2026-11-01 20:06:51–20:06:52 UTC) and their linked rows were
  removed from the local test databases. One cleanup command initially stopped at an unsupported
  `delete!` call; it was corrected to `delete` and the exact six actors were then removed.
- A read-only check found two other bare local test App Clients (`980190984` and `980190988`) with
  no Step-Up parents, tokens or TOTP credentials. Their origin was not established; they were
  preserved. This does not affect the focused test result.
- The same-Zenith authoritative TOTP enrollment audit is still absent. Its event shape remains
  unapproved and no audit data shape was invented. No full suite or external database was used.
