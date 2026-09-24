# OIDC result one-shot API retirement

- Date: 2026-09-22 UTC
- Repository HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Worktree: pre-existing modified and untracked files were preserved; no reset, clean, commit,
  push, GitHub write, AWS access, Cloudflare access, provider call, or production/shared-database
  operation was performed.

## Change

The unreferenced `BaseAuthAdmissionCoordinator.consume_result!` method was removed. It was the
obsolete one-shot OIDC result path that could make Valkey consumption look like the result
authority. The live Base result POST uses `read_result!`, validates the PostgreSQL transaction
binding and result generation, and lets the surface-local PostgreSQL finalization transaction
own the durable state transition.

The separate ceremony transaction `consume_result!` methods were not changed. A repository-wide
call-site search found no production caller of the removed Base/Auth coordinator method; the only
remaining reference was a transport test stub, which was retargeted to `read_result!`.

The current Rails result contract was also made explicit in `docs/security/sign-in-sequence.md`
and `docs/identity/authority-boundary.md`. Their earlier `sign/id`–`acme/www` sections remain
clearly labeled as historical migration vocabulary rather than being silently deleted.

The remaining active security documents that used the retired Sign/Acme signed one-shot result
vocabulary were likewise labeled as historical and cross-referenced to the current Base/Auth
contract: `ceremony-grant-result.md`, `redirect-vs-ceremony-result.md`, `credential-gateway.md`,
`webauthn-rp-id-origin-boundary.md`, `social-callback-boundary.md`, and
`step-up-ceremony-delegation.md`. This follow-up is documentation-only; it does not introduce a
signed-result API or alter CSRF, session, or ceremony behavior.

## Verification

Environment was selected explicitly with `.env.devcontainer.example`; PostgreSQL and Valkey were
reachable through the Compose service network.

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

Static checks:

- Ruby syntax checks for the changed Ruby files: passed.
- targeted RuboCop for the two changed files: passed with no offenses.
- `git diff --check`: passed.
- Production call-site search for the removed method: no matches.

Full command:

```text
bin/rails test
```

Result: `11536 runs, 73426 assertions, 0 failures, 0 errors, 8 skips`.

The eight skips were not added by this change. No assertion, CSRF check, security check, or
coverage gate was weakened.

## Boundary

This verifies removal of the obsolete local one-shot coordinator API and the existing
PostgreSQL-authoritative, generation-bound result flow. It does not prove live external RP
registration, provider delivery, production worker topology, or external Tunnel acceptance.
