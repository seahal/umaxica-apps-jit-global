# Phase 14 logout evidence

Commit: `bfe569a162078df62e8e3b3011367840780e3078`.

The worktree had uncommitted user and implementation changes during this verification; no unrelated changes were reverted.

Implemented and verified the authority-first Browser RP logout graph:

- `browser_rp` transactions use `authority_revoked`, `authority_cleanup_issued`, `origin_cleanup_issued`, `origin_rp_session_revoked`, and `finalized`, while legacy sign/acme transactions keep their historical graph.
- The workflow migration was applied to the owned isolated `app_ticket` test database and expired open legacy Base/Core/Warp/Edit rows without relabeling completed steps.
- Core, Warp, Base self-RP, and Edit journeys were exercised through Base authority and back to the initiating origin. Parent refresh failed before origin cleanup, sibling RP rows were not synchronously revoked, and a separately revoked initiating RP row still finalized idempotently.
- Trusted and untrusted Origin handling, no Auth response hop, RP realm-derived authority routing, and D67 direct `LOGICALLY_REVOKED` → `COMPLETED` behavior were covered.
- Existing back-channel and Palm logout tests passed.

Targeted command result:

```text
83 runs, 542 assertions, 0 failures, 0 errors, 0 skips
```

Command scope included `test/controllers/oidc/rp_logout_receivers_test.rb`, Palm logout, all three Base OIDC logout controller tests, logout service tests, and `test/integration/oidc_rp_authority_first_logout_test.rb`. The focused Core/Warp/model/coordinator run also passed after the final validation fix.
