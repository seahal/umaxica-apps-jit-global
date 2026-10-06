# Phase 0.1 Baseline

Date: 2026-10-06

Commit: `bfe569a162078df62e8e3b3011367840780e3078`

The worktree was already dirty before this phase. The only tracked change observed was the user's
three-line addition to `.gitignore`; it was preserved. No application or test file was changed for
this baseline.

## Repository and environment

- Branch: `feature`
- `git status --short | wc -l`: `1`
- `scripts/test-environment-check`: blocked before execution because Bundler could not materialize
  the locked Rails revision `2f75a03b05aff2610b3799ef9ebd87cfc9cf38eb`.
- `podman ps`: blocked by the host's read-only `/run/user/1000/libpod` (`chmod ... read-only file
  system`), so the existing development container could not be inspected.
- `bundle install --jobs 4 --retry 1`: failed because `github.com` and the configured gem mirror
  could not be resolved. No tracked files changed.

## Baseline test files

Each command was run as `bin/rails test <file>` after loading the local environment file. All seven
commands exited `1` before test discovery with the same Bundler error: the locked Rails checkout was
missing and could not be fetched.

| Test file | Result | Classification |
| --- | --- | --- |
| `test/operations/base_step_up_admission_issuer_test.rb` | exit 1 | environment failure |
| `test/controllers/base/step_up_intent_authority_test.rb` | exit 1 | environment failure |
| `test/queries/client_secret_lookup_query_test.rb` | exit 1 | environment failure |
| `test/integration/app_secret_login_journey_test.rb` | exit 1 | environment failure |
| `test/integration/app_secret_parallel_login_test.rb` | exit 1 | environment failure |
| `test/integration/app_secret_root_login_concurrency_test.rb` | exit 1 | environment failure |
| `test/security/invariants/primary_authentication_account_rate_limit_invariant_test.rb` | exit 1 | environment failure |

The baseline is therefore a startup baseline only. No application assertion executed, and no
pre-existing behavioral failure can be classified until the pinned Rails checkout and disposable
database targets are available.

Commands: `git status --short`, `git branch --show-current`, `git rev-parse HEAD`,
`pgrep -af 'rails test'`, `scripts/test-environment-check`, `bundle check`, `bundle install --jobs 4
--retry 1`, and the seven `bin/rails test` commands above.
