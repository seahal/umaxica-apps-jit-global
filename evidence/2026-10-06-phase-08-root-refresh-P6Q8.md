# Phase 8 root session and refresh evidence

Commit: `bfe569a162078df62e8e3b3011367840780e3078`.

The worktree was dirty with unrelated changes preserved. On the owned disposable PostgreSQL copies from `tmp/auth-boundary-isolated-20261003auth6f3.json`, with one worker and all 20 manifest databases prepared, the complete Phase 8 target command passed: 187 runs, 732 assertions, zero failures, zero errors, zero skips. The run covered refresh ordering/concurrency, usable-device capacity, token binding, RP parent binding/retirement, logout, absolute expiry, and the database constraints.
