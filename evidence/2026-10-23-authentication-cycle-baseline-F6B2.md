# Authentication cycle initial full-suite baseline

- Date: 2026-10-23.
- Commit: `6e4d70d0b0799a4ef9bd9fc4cea2c21d4b3eca72`.
- Worktree: pre-existing staged, unstaged and untracked cycle and unrelated changes; no production
  edits during the baseline. New spec files and cleanup regression tests were created while the
  already-loaded baseline test list ran; they were not part of this baseline.
- Command: `bin/rails test` (16 processes).
- Result: 18422 runs, 158064 assertions, 146 failures, 24 errors, 0 skips; exit status 1; 330.470209 seconds.
- Log SHA-256: `1a933e0685225b0ee692ba03ae7ca0a61896a6fd78ee114a620e8bd5ba8d3e4c`.
- All 170 failure/error identities are retained, without raw diagnostic payloads, in
  `specs/authentication-cycle-completion/baseline.md`. They remain untriaged and unwaived.
- This is G-1 intake evidence, not acceptance of any Work Unit. Subsequent runs must fix or
  explicitly disposition failures in their affected area and detect new regressions.
