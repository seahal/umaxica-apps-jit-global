# WU-A6 ORG Standby enforcement operation refusals

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree had 577 staged, unstaged, or
  untracked status entries at verification; no commit was created.
- A fixture-free integration test seeds an ORG Standby Operator session with matching fresh Step-Up
  evidence and valid read, apply, approve, release, and appeal-review capability grants.
- The confirmation, application, approval, release, and appeal-review screens and submissions each
  return HTTP 403. The pre-existing enforcement cases remain pending approval, active, and submitted
  as seeded; the case count does not increase. The Step-Up timestamp and Ceremony count remain
  unchanged, and the session retains Standby context.
- The focused test passed: 1 run, 19 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop
  reported no offenses; Ruby syntax and `git diff --check` passed.
- These requests use a seeded Standby session; they do not verify real Standby Root issuance or
  prove the complete policy-derived Normal/Standby operation matrix. The full suite was not run.
