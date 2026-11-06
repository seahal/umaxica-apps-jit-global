# WU-A6 support-session revocation after Test Org rebuild

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`.
- The worktree contained extensive uncommitted changes. This check did not edit application or test
  source and created no commit.
- After the approved migration rebuild of only `test_org_zenith_db`, the original
  `test/controllers/base/org/support/session_revocations_test.rb` passed: 21 runs, 98 assertions, 0
  failures, 0 errors, 0 skips. The earlier fixture-free refactor was reverted and is not part of
  this result.
- This resolves the fixture-load failure for this test file only. Other WU-A6 acceptance, including
  the complete Normal/Standby operation matrix and reviewed Standby Root issuance, remains open.
