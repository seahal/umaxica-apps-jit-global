# Phase 11 verification

Commit under test: `bfe569a162078df62e8e3b3011367840780e3078`.

The worktree was already dirty and contained unrelated user changes; the recorded status count was 382 entries. No commit was created. Verification used the owned isolated PostgreSQL manifest `tmp/auth-boundary-isolated-20261003auth6f3.json`, `POSTGRESQL_TEST_HOST=primary`, and `PARALLEL_WORKERS=1`.

Implemented and checked:

- RP cookie names, flags, response-derived access expiry, persistent refresh expiry, server-authority cap, and reversed/missing expiry refusal.
- Per-realm refresh receipt columns and validated all-or-none constraints.
- Encrypted fixed five-second delivery receipts, DB recovery after publication failure, Valkey lease coordination, generation binding, replay detection, parent/RP activity checks, and fail-closed corruption handling.
- Shared Browser RP authentication, safe/unsafe refresh orchestration, same-request credential installation, dependency-preserving 503 behavior, and CSRF/Origin/Fetch-Metadata rejection before refresh.

Commands and results:

- `bin/rails test test/controllers/base/oauth_oidc_authority_test.rb test/controllers/concerns/oidc/callback_test.rb test/services/oidc/discovery_document_test.rb test/unit/oidc_rp_browser_credential_contract_test.rb test/unit/oidc_refresh_delivery_receipt_test.rb test/services/oidc_refresh_token_coalescing_test.rb test/controllers/concerns/browser_rp_authentication_test.rb` — 100 runs, 668 assertions, 0 failures, 0 errors, 0 skips.
- The isolated coalescing/orchestrator subset — 22 runs, 126 assertions, 0 failures, 0 errors, 0 skips; the concurrency case used two independent Ticket connections and a barrier.
- `ruby -c` on the three Browser RP concerns, the refresh issuer, the receipt value, and the coalescing test — all `Syntax OK`.

The Phase 11 checkboxes in `two.md` were marked complete only after these checks passed.
