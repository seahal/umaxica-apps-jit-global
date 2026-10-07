# Step-Up fixture API and ID isolation

Commit: `6fa6867d44b5499632079775cb0fb22cbfddd339`; dirty worktree, including inherited changes. All Rails runs were serial and used the owned `20261006fresh1` disposable PostgreSQL manifest.

Command:

```bash
bin/rails test test/controllers/base/step_up_intent_authority_test.rb test/operations/step_up_finalization_restart_race_test.rb test/operations/identity_step_up_ceremony_freshness_committer_test.rb
```

- Initial result: 52 runs, 176 assertions, 0 failures, 27 errors, 0 skips; seed 22823. The errors called nonexistent `Rack::Test::CookieJar#merge!` in the existing RP cookie installer before reaching the intended HTTP boundary.
- Installed Rack::Test source defines mutating `merge`, accepting an array of raw cookies. Both browser credentials now use one final merge call; no lint suppression or new helper was added.
- A repeat after the cookie fix reached 52 runs, 413 assertions, 0 failures, 1 error, 0 skips; seed 40117. The nontransactional race's cleanup hit a restrictive admission-binding FK on reused token ID 980191006.
- Read-only model inspection found binding 6160 / parent 3961 pointing to that token ID but a different parent session and actor. The race assigns independent high actor/token IDs; no unrelated binding or token was removed.
- The same three-file command with `--seed 40117` then passed: 52 runs, 413 assertions, no failures, errors or skips.
- After a line-wrap-only lint repair, the race alone with seed 40117 passed: 1 run, 7 assertions, no failures, errors or skips. Scoped RuboCop on the two changed fixture/test files and scoped `git diff --check` both passed.

This establishes the selected authority/freshness/race behavior, not the complete Phase 16/17 acceptance matrix. Production authorization, FK constraints and deferred scope were unchanged.
