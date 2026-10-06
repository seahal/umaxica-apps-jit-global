# Phase 20 evidence: social binding

- Commit: `bfe569a162078df62e8e3b3011367840780e3078`.
- Worktree: dirty before and during the run; unrelated existing changes were preserved.
- Database: disposable manifest `tmp/auth-boundary-isolated-20261006fresh1.json`, all application test databases at `10.89.2.3`, with `PARALLEL_WORKERS=1`.
- Targeted verification: `39 runs, 225 assertions, 0 failures, 0 errors, 0 skips` for the social binding contract, unlink, link handler, and repository adapter tests.
- Broad Phase 20 social suite: `216 runs, 1258 assertions, 0 failures, 0 errors, 0 skips`.
- Observed guarantees: effective social uniqueness is client-wide; release retains rows and `released_at`; link grants bind to the device-session public ID; revoked-but-unreleased identities can be reactivated only through a new authorized link ceremony; released rows are not reactivated by old callbacks or grants; Base social completion follows receiver GET plus same-origin POST; org/customer boundary tests passed.
- The OmniAuth CSRF-protection deprecation messages were emitted by negative callback tests; they did not produce test failures.
