# Relay boundary checks

HEAD: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree contained uncommitted changes affecting these checks.

- `PARALLEL_WORKERS=1 bin/rails test test/integration/visa_authorization_continuations_test.rb`: 5 runs, 224 assertions, passed. HEAD and iframe requests were tested on Visa result, cancel and switch routes with malformed references.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/acceptance_wu12_relay_repeat_test.rb`: 4 runs, 67 assertions, passed. With a live Visa confirmation binding, a foreign browser and HEAD were refused without changing the binding or ceremony. An iframe request returned 200 with the confirmation form without changing either record. A preceding run expecting refusal failed at that assertion (4 runs, 44 assertions, one failure); the implementation renders the form when automatic confirmation is not allowed. This differs from A12-5's stated refusal and remains open.
- `bundle exec rubocop test/integration/visa_authorization_continuations_test.rb --format simple` and `bundle exec rubocop test/integration/acceptance_wu12_relay_repeat_test.rb --format simple`: no offenses.

Per-hop tests with live bindings and the remaining stage 2 Partial cases were not completed in these checks.
