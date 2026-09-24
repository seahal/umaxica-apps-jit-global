# OIDC result documentation boundary and runtime recheck

- Date: 2026-09-22 UTC
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Worktree: pre-existing modified and untracked files were preserved. No reset, clean, commit,
  push, GitHub write, AWS access, Cloudflare access, provider call, or production/shared-database
  operation was performed.

## Scope

The current Base/Auth OIDC result contract was rechecked after labeling remaining Sign/Acme
signed one-shot result descriptions as historical in the security documentation. The follow-up
does not add a signed-result API, change the Auth ceremony/session boundary, weaken Rails CSRF
protection, or introduce a dry-run/preview path.

The documentation-only boundary was applied to:

- `docs/security/ceremony-grant-result.md`
- `docs/security/redirect-vs-ceremony-result.md`
- `docs/security/credential-gateway.md`
- `docs/security/webauthn-rp-id-origin-boundary.md`
- `docs/security/social-callback-boundary.md`
- `docs/security/step-up-ceremony-delegation.md`

## Verification

Focused command:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/services/base_auth_admission_coordinator_test.rb \
  test/services/oidc_authorization_transaction_service_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/controllers/base/oauth_oidc_authority_test.rb \
  test/integration/oidc_initiated_sign_in_completion_test.rb \
  test/security/opaque_result_transport_test.rb
```

Result: `162 runs, 774 assertions, 0 failures, 0 errors, 6 skips`.

Full command:

```text
bin/rails test
```

Result: `11536 runs, 73429 assertions, 0 failures, 0 errors, 8 skips`.

The suite emitted existing OmniAuth diagnostic output and warnings but completed without failures
or errors. The skips were not added by this follow-up. No tests, assertions, CSRF checks, security
checks, or coverage gates were weakened.

Static `git diff --check` also passed. The result remains repository-side evidence only; it does
not prove external RP registration/key deployment, provider delivery, production worker topology,
or live Tunnel acceptance.
