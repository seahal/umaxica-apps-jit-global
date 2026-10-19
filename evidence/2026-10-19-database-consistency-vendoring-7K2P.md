# database_consistency local source setup

- Application HEAD: `ff58ff28125fafe405dc76809f6498b64d69e627`.
- The worktree contained pre-existing uncommitted changes, including Gemfile and Gemfile.lock.
  Verification used that worktree with the local source setup added.
- Imported upstream tag `v3.0.16`, commit `3d9486070db552fd5a492c7253eafb1328d6041e`, into
  `vendor/fork/database_consistency` without a nested Git repository.
- `bundle install --local` succeeded: 121 dependencies, 366 gems installed.
- `bundle info database_consistency` resolved version 3.0.16 to
  `/home/global/workspace/vendor/fork/database_consistency`.
- `bundle exec database_consistency --help` succeeded and printed CLI usage.
- `bundle check` succeeded. Loading the gem with `bundle exec ruby` confirmed its loaded source is
  in `vendor/fork/database_consistency`.
- Git ignore inspection confirmed `vendor/bundle` stays ignored and the imported source is available
  for tracking.
- The full database inspection was not run. This change only selects the local source; it does not
  fix the previously observed deprecated connection API.
