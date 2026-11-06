# WU-A6 ORG Standby IAM operation refusals

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 579 staged, unstaged or
  untracked paths at the final status check; no commit was created.
- The fixture-free Standby integration test seeds IAM read/grant/revoke capabilities, an existing
  target grant, and fresh matching `operator_capability` Step-Up evidence. Grant-screen GET, grant
  POST and revoke POST each returned HTTP 403. The grant count and existing grant state remained
  unchanged; Step-Up freshness, Standby context and ceremony count remained unchanged.
- The whole test file passed: 2 runs, 25 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop
  reported no offenses; Ruby syntax and `git diff --check` passed.
- A separate telephone OTP-finalization test attempt in the fixture-heavy controller test did not
  reach its test body: Rails fixture setup failed on the `bureau_ownerships.operator_id` foreign
  key. No telephone-finalization behavior was verified. This unexecutable test was removed; a
  fixture-free public-flow test remains needed.
- This is partial AC-41 evidence using seeded Standby state. It does not establish Standby Root
  issuance or the complete policy-derived Normal/Standby operation matrix. No application behavior,
  schema, production or Neon data was changed in this slice; the full suite was not run.
