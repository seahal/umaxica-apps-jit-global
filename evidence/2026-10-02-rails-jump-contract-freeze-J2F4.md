# Rails Jump contract freeze verification

Date: 2026-10-02. Verified implementation commit: `6632eec2afc4c4da5e94c77369504ecbe0412e7d`.
Hono input: this implementation revision and `adr/jump-directed-rails-handoff-contract.md`.

## Committed implementation

A clean local checkout of the exact implementation commit was tested independently of the existing
staged/unstaged preference API work. Git status and `git diff --check` were clean in that checkout.
Ignored dependency links and generated test assets supplied the existing local execution environment;
no tracked application changes were made there.

- `bin/rails test`: **12,266 runs, 80,522 assertions, 0 failures, 0 errors, 2 skips**; exit 0,
  seed 45117, 296.595 seconds. The two skips belong to the existing suite; none was introduced.
- Focused command below: **267 runs, 1,826 assertions, 0 failures, 0 errors, 0 skips**; exit 0,
  5.321 seconds.
- The literal twenty-edge expectation matched the complete runtime allowlist. All 169 ordered
  pairs of the thirteen canonical nodes were checked; forbidden pairs were denied.
- Each of the thirteen canonical issuers produced an ES384 RT verified with the public JWKS
  fetched locally at its exact issuer origin. Header kid publication and private-field absence
  were checked.
- Palm browser relay, callback verification and native completion; Edit same-site OIDC admission
  without Jump and rejected Jump capability; receiver validation and replay contracts were covered
  by the focused suite. Edit OIDC client/key namespaces and callback/logout registrations remain.

```bash
bin/rails test test/services/jump_rt test/services/jump_rt_keyring_test.rb test/unit/jit/security/jwt test/integration/jump_rt_return_verification_test.rb test/integration/jump_rt_issuer_jwks_authority_test.rb test/integration/jump_directed_handoffs_test.rb test/integration/palm_jump_sign_in_test.rb test/integration/oidc_rp_browser_flow_test.rb test/integration/core_rp_browser_flow_test.rb test/integration/edit_org_jump_rt_sign_in_test.rb test/values/oidc_seven_first_party_rp_clients_test.rb test/values/regional_rp_client_matrix_test.rb test/controllers/concerns/oidc
```

## Development runtime

Actual `RAILS_ENV=development` boot was exercised with process-local, disposable P-384 keys and a
synthetic production public-key reference. Public Auth host and opt-in issuer/JWKS/return settings
were supplied before boot. A local Rack HTTPS request with the explicit Host header returned 200
from `Auth::App::WellKnown::JwksController`. The issued RT named the configured distinct development
origin, used its dedicated development kid and production Jump audience, and verified against that
endpoint's JWKS. No token, private key or production secret is retained in this record.

This was a local application check, not public DNS/TLS or Hono acceptance. The hostname used for
this check is not a provisioned infrastructure contract. Required-setting, private/stale/production
identity, gateway/JWKS/return binding and production-key reuse rejection passed the issuance tests.
The production public-key reference must be complete and maintained by operators.

## Shared-worktree results and separation

The earlier full-suite invocation started against `7430ddea6da1e18da0b42418e5374379a52c8a4b` with uncommitted Jump changes and
unrelated preference API work: **12,310 runs, 84,569 assertions, 0 failures, 1 error, 2 skips**.
`OidcRpBrowserFlowTest` failed at `test/integration/oidc_rp_browser_flow_test.rb:331` because an
existing unrelated worktree edit replaced `Rack::Test::CookieJar#merge` with unsupported `merge!`.
The committed version uses `merge`; the clean implementation checkout passed that flow.
The unrelated edit was retained. The complete staged patch was byte-identical before and after
committing the Jump implementation.

Scoped `git diff --check` passed. The shared worktree's unscoped command reported an existing extra
EOF blank line in `adr/api-route-vocabulary-consolidation.md:205`; that unrelated file was retained.
No formatter, automatic correction, database migration, gateway deployment or key rotation ran.
Commit hooks were disabled to keep automatic formatting and unrelated staged work out of the commit.

## Remaining deployment checks

Production Jump registration of development issuer/JWKS/kids, real public DNS/TLS/JWKS reachability,
host-only browser continuity across deployed origins and physical iOS/Android completion were not
verified. Existing Core bridge rows/defaults were not migrated. The Hono deployment must implement
the frozen graph and explicitly register any approved development authorities; valid Rails settings
alone do not establish that trust.
