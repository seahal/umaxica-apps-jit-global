# WU-A6 ORG Standby enforcement-case application refusal

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was dirty (576 staged, unstaged, or
  untracked status entries at verification); no commit was created.
- A fixture-free integration test seeds an ORG Standby Operator session, two active Passkeys, a Base
  selection, an App principal, and valid enforcement read/apply capability grants. It seeds fresh
  Step-Up evidence matching `enforcement_case_apply` and issues matching Base and Browser RP access
  tokens.
- Both the enforcement-case confirmation GET and create POST return HTTP 403. The App case count and
  Operator Step-Up ceremony count remain unchanged; the token retains its seeded Step-Up timestamp
  and Standby context.
- The focused file passed: 1 run, 10 assertions, 0 failures, 0 errors, 0 skips. Scoped RuboCop
  inspected three affected test files with no offenses; Ruby syntax checks were `Syntax OK` for all
  three; `git diff --check` passed.
- The first attempt placed the test in a fixture-heavy class and failed during unrelated
  `bureau_ownerships` fixture loading before any assertion. The check was moved to a self-seeding
  class with global fixture loading disabled. A later request attempt initially returned 422 because
  the test supplied an invalid Origin; using the actual request base URL allowed the protected
  request to reach the Standby refusal.
- This is partial AC-41 evidence. It does not verify enforcement approval, release or appeal-review
  actions, the policy-derived Normal/Standby matrix, or real Standby Root issuance. The full suite
  was not run. No application behavior, schema, or production/Neon data changed.
