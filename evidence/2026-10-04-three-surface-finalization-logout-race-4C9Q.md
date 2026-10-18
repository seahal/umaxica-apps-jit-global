# Three-surface finalization/logout race

Commit: `f313b126931cfe3c9ecf64bbb72fb1cd3a0aada5`. The worktree contains uncommitted authentication changes and unrelated parallel work.

Extended the existing APP concurrency case to COM and ORG. Each case creates its own committed actor, credential, token, exact parent ticket and Auth continuity. Two writer connections with distinct PostgreSQL backend IDs simultaneously attempt Base finalization and token revocation. Synthetic verified evidence isolates the authority transition rather than signature verification. COM setup includes a verified contact, preserving its existing credential-registration prerequisite.

Assertions accept either legitimate serialization order, then require a revoked unusable token, cleared freshness, an unsatisfied resolver, a correctly consumed or revoked parent/continuity, and refusal to finalize the same result again. Cleanup targets only the IDs created by each case.

Command: `bin/rails test test/models/auth_ceremony_revocation_concurrency_test.rb`, with run ID `20261003auth6f3`, owned manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, one worker and preparation restricted to `codex_integrity_20261003auth6f3_app_ticket`.

Result: 9 runs, 99 assertions, no failures, errors or skips (seed 61632). RuboCop passed after formatting and shortening local model-binding variable names; `git diff --check` passed. The first expanded run exposed the omitted COM verified-contact setup; the prerequisite was supplied rather than bypassed.

This covers the concurrent logout/finalization invariant on all three surfaces. It does not establish deterministic observation of both serialization orders, a browser journey, or completion of every required concurrency scenario. No production code or database schema changed in this slice.
