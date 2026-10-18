# Admission transport and state-indexed OIDC revalidation

- Date: 2026-09-21 UTC
- HEAD: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Working directory: `/home/global/workspace`
- Worktree: uncommitted changes were present and preserved.
- External writes: none; no application provider, AWS, Cloudflare, production, or shared database was contacted.
- Secrets: no admission code, cookie, credential, or environment value was recorded.

## Contract checked

The current Auth admission boundary accepts only the non-secret opaque `entry_ref` or
`transaction_ref` reference in the initial GET. The GET renders a same-origin continuation form;
the reference is consumed only by the CSRF-protected POST. Raw legacy `admission` query input is
rejected. OIDC initiation stores state, nonce, PKCE verifier, and return target in the bounded
state-indexed pending-flow map rather than writing new scalar session keys.

## Verification

The first attempted focused command contained a nonexistent test path and stopped before loading a
test file. No test result was attributed to that command. The corrected command was:

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/auth/app/sign_in_admission_test.rb \
  test/controllers/auth/ceremony_admission_boundary_test.rb \
  test/services/valkey/auth_state/opaque_admission_store_test.rb \
  test/integration/routes/neutral_rp_entry_contract_test.rb \
  test/controllers/concerns/oidc/sso_initiator_test.rb
```

Result: `39 runs, 377 assertions, 0 failures, 0 errors, 0 skips`.

The test environment used the repository's Compose-backed PostgreSQL and Valkey services selected
through `.env.devcontainer.example`. No application, test, configuration, or security control was
changed to obtain the result.

## Remaining boundary

This evidence confirms the repository-side transport and pending-flow behavior. It does not claim
external RP registration, live cross-host deployment, or provider delivery completion.
