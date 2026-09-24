# Auth ceremony and full-suite runtime revalidation

- Date: 2026-09-22 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Worktree: pre-existing staged, unstaged, and untracked changes were preserved.
- External writes: none. No GitHub, AWS, Cloudflare, provider, production, shared database,
  email, or SMS service was contacted.

## Focused verification

The Auth ceremony admission rotation tests passed in the Compose-backed test environment:

```text
PARALLEL_WORKERS=1 bin/rails test test/models/auth_ceremony_session_test.rb test/models/auth_ceremony_session_concurrency_test.rb
36 runs, 219 assertions, 0 failures, 0 errors, 0 skips
```

The OIDC registry and local keyset tests also passed together with one worker:

```text
PARALLEL_WORKERS=1 bin/rails test test/values/oidc_seven_first_party_rp_clients_test.rb test/unit/jit/security/jwt/local_keyset_installer_test.rb
13 runs, 220 assertions, 0 failures, 0 errors, 0 skips
```

## Full-suite verification

The first parallel full-suite run produced one failure at
`test/values/oidc_seven_first_party_rp_clients_test.rb:22`:

```text
core-app missing private key for CORE_APP.
Expected nil to be present?.
```

It completed with `11536 runs, 73371 assertions, 1 failure, 0 errors, 8 skips`.

The failing file passed in isolation, and the related registry/local-keyset group passed with one
worker. With no code or configuration changes between runs, the same full-suite command was run
again and completed with:

```text
11536 runs, 73426 assertions, 0 failures, 0 errors, 8 skips
```

The first failure was therefore not reproduced. A parallel-test shared-state interaction involving
JWT registry/local-keyset state is a plausible explanation, but its causal mechanism is not proven
by this run. No test was deleted, weakened, skipped, mocked, or changed to obtain the passing
result. The eight skips are existing suite skips.

## Boundary

This evidence establishes the current local runtime result only. It does not validate production
worker topology, external RP key deployment, provider delivery, Cloudflare Tunnel, or external
OIDC acceptance.
