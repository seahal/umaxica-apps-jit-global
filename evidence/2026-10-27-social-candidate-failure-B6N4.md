# Social candidate failure boundary

HEAD: `aeb09ca9fb97ef1ca24c0195b2fa1d28d21245df`. The worktree contained uncommitted changes affecting this check.

- `PARALLEL_WORKERS=1 bin/rails test test/services/identity_social_ceremony_candidate_store_failures_test.rb test/services/identity/social_ceremony_contract_test.rb`: 17 runs, 124 assertions, no failures, errors or skips. Injecting an `ActiveRecord::ConnectionNotEstablished` at the OP database clock caused candidate fetch and consumption to raise; the candidate remained unconsumed and was readable after restoring the clock.
- `bundle exec rubocop test/services/identity_social_ceremony_candidate_store_failures_test.rb --format simple`: no offenses.

This injection does not establish behavior under an actual database outage or on the candidate write path; A05-7 remains partial.
