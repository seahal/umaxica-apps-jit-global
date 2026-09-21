# Request body size limit verification

Date: 2026-09-20

## Scope

FREQ-0060 was implemented as a Rack middleware boundary for JSON request bodies. The Rails-side
limit is 1 MiB. The middleware runs before controller parameter parsing, reads at most one byte
above the limit for requests without a trustworthy declared length, and rejects unsupported
compressed JSON instead of applying a limit to an undecoded stream. Multipart and other upload
contracts remain separate.

## Focused verification

```text
export UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example
PARALLEL_WORKERS=1 bin/rails test \
  test/middleware/request_body_size_limit_test.rb \
  test/integration/core_browser_api_boundary_test.rb
```

Result: 25 runs, 110 assertions, 0 failures, 0 errors, 0 skips; exit code 0.

The focused tests cover the exact limit boundary, declared and chunked oversized bodies,
malformed and negative Content-Length values, compressed JSON rejection, downstream body
preservation, and the Core Browser API problem-details response.

## Static verification

```text
bundle exec rubocop \
  lib/request_body_size_limit.rb \
  app/values/problem_type.rb \
  test/middleware/request_body_size_limit_test.rb \
  test/integration/core_browser_api_boundary_test.rb
git diff --check
```

Result: RuboCop reported no offenses and `git diff --check` reported no whitespace errors.

## Full Rails regression

```text
bin/rails test
```

Result: 11,427 runs, 73,082 assertions, 0 failures, 0 errors, 5 skips; exit code 0.

The five skips remain skips. Expected test-path OmniAuth failure/deprecation log messages and
existing `LocalEnvironment::KEY` reinitialization warnings were observed; neither produced a
test failure or error.

## Remaining boundary

The Rails middleware limit is verified in the repository test environment. Cloudflare, ingress,
proxy, compression, and production edge limits were not changed or live-tested in this slice;
their independent limits remain an operational dependency.
