# WU-A3 admission CAS and purge recheck

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this record was added, the worktree had
  372 unstaged tracked paths and 84 untracked paths, with no staged changes. Existing work was
  preserved; no commit was created.
- After the local FK normalization, ran
  `bin/rails test --seed 30491 test/services/auth_admission_binding_concurrency_test.rb test/models/auth_ceremony_session_concurrency_test.rb test/models/auth_admission_binding_test.rb test/operations/auth_admission_binding_purger_test.rb`
  with `.env.container.devcontainer` loaded.
- Result: 22 runs, 307 assertions, 0 failures, 0 errors, 0 skips. Covered concurrent exact
  confirmation, confirmed redemption, competing attachment, SID replacement CAS, immutable/terminal
  binding facts, strict deadlines, parent-scoped uniqueness, and binding/continuity retention
  boundaries in the listed suites.
- Existing NanoID frozen-string warnings appeared. No full suite was run. This does not verify the
  remaining public Cancel/replacement and registered-account/OTP cases in §3.6/§10.6, or close WU-A3
  or `two.md`.
