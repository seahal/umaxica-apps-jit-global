# Request-body limit current audit

- Date: 2026-09-22 UTC
- HEAD: `277673d13547d722fc88f830711eee69b923a7e8`
- Branch: `feature`
- Working tree: pre-existing implementation, test, documentation, and evidence changes were
  preserved; this audit added no application or test behavior.
- External writes: none. No AWS, Cloudflare, provider, production/shared database, or GitHub
  service was contacted.

## Disposition

`CF-009` is closed for the Rails-owned JSON origin boundary. The existing implementation is
accepted as-is; no new request-size API, upload policy, compressed-input decoder, or middleware
abstraction was added during this audit.

## Evidence reviewed

- `lib/request_body_size_limit.rb` bounds `application/json` and structured `+json` bodies at the
  explicit `MAX_JSON_BODY_BYTES` value of 1 MiB before the downstream application is called.
- The middleware checks declared length before reading, reads at most one byte beyond the limit
  when the length is absent or unusable, rejects malformed/negative lengths, and rejects unsupported
  content encodings rather than attempting unbounded decompression.
- `config/application.rb` inserts the middleware after `ActionDispatch::RequestId`, before routes
  and controller parameter parsing.
- `test/middleware/request_body_size_limit_test.rb` covers the exact boundary, oversize declared
  length, chunked oversize, compressed input, malformed length, and negative length.
- `test/integration/core_browser_api_boundary_test.rb` covers an oversized JSON request at the
  public API boundary and its RFC 9457 `413 content-too-large` response.
- `docs/security/request-size-limits.md` explicitly separates the Rails origin defense from
  Cloudflare/proxy/server-ingress limits and non-JSON upload limits.

## Current static verification

```text
ruby -c lib/request_body_size_limit.rb
ruby -c test/middleware/request_body_size_limit_test.rb
ruby -c test/integration/core_browser_api_boundary_test.rb
```

Result: all three files reported `Syntax OK`.

```text
bundle exec rubocop lib/request_body_size_limit.rb test/middleware/request_body_size_limit_test.rb test/integration/core_browser_api_boundary_test.rb --format simple
```

Result: 3 files inspected, no offenses detected.

```text
git diff --check -- lib/request_body_size_limit.rb test/middleware/request_body_size_limit_test.rb test/integration/core_browser_api_boundary_test.rb config/application.rb docs/security/request-size-limits.md plans/backlog/2026-09-17-integrated-hardening-plan.md
```

Result: passed.

```text
bundle exec ruby -r active_support/core_ext/numeric/bytes -r active_support/core_ext/object/blank \
  -r rack -r json -r securerandom -r stringio -r ./app/values/problem_type \
  -r ./lib/request_body_size_limit -e '<boundary smoke>'
```

Result: `request-body-limit smoke: PASS (200,413,413,415)` for exact-size, declared oversize,
undeclared-length oversize, and unsupported compressed JSON respectively.

The latest repository evidence for the database-backed focused and full Rails runs is
`evidence/2026-09-22-request-body-limit-revalidation-B3C4.md`. A new Rails run was not claimed by
this audit; the current non-Compose shell cannot resolve `primary`/`valkey-kvs` before schema boot.

## Remaining boundary

Cloudflare/proxy/server-ingress enforcement, compressed requests outside the explicitly rejected
origin contract, and non-JSON multipart/upload limits remain separate operational or endpoint
contracts. No implementation may infer those contracts from this Rails-side result.
