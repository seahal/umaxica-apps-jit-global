# WU-A7 privacy erasure refusal recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. The worktree was already dirty; no application or
test code was edited for this recheck.

Ran `PARALLEL_WORKERS=1 bin/rails test test/integration/privacy_erasure_request_test.rb` with
`.env.container.devcontainer` loaded: 3 runs, 19 assertions, 0 failures, 0 errors, 0 skips. The
withdrawal-ceremony request test covers absent, malformed, and signed Preference cookies. It
observed HTTP 403 with no direct SQL writes, no new privacy request, processor notification or
occurrence, and no queued jobs. Existing request recovery/cancellation cases passed in the same
file.

The current APP endpoint and `docs/security/withdrawal-privacy-erasure.md` already implement and
describe the provisional refusal. No implementation change was needed. This local integration check
does not establish deployed behavior, browser behavior, or an ORG procedure.
