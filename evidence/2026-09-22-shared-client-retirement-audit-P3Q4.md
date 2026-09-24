# Shared browser-client retirement audit

Date: 2026-09-22 UTC

Repository: `seahal/umaxica-apps-jit-global`

HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`

Worktree: dirty before and after this audit. The attempted `sign-rp` / `base-rails-rp` registry
removal was rolled back within this slice after the adversarial test evidence below. The previously
completed `side-rails-rp` local retirement was preserved. No external registration, key, GitHub,
AWS, Cloudflare, production, or shared database operation was performed.

## Evidence

The production-source literal audit found no direct runtime references to `sign-rp` or
`base-rails-rp` outside the static registry and the deprecated-client map. However, the first TDD
test for their absence failed because the registry still returned `sign-rp`.

During the temporary implementation, the registry-focused suite exposed 5 failures and 10 errors.
The remaining references are not only registry characterization tests: the repository contains
OIDC browser-flow, logout, callback, connection, token, policy, and controller test helpers that
still exercise these identifiers. Replacing their defaults requires a surface-by-surface mapping;
blind substitution would conflate Core, Base, Sign, and legacy flow ownership.

The attempted removal was therefore reverted without preserving any partial production change.
The restored focused contract set passed:

```text
PARALLEL_WORKERS=1 bin/rails test test/services/oidc/client_registry_test.rb test/services/oidc/authorize_service_test.rb test/values/oidc_seven_first_party_rp_clients_test.rb
67 runs, 430 assertions, 0 failures, 0 errors, 0 skips
```

The accepted `side-rails-rp` retirement remains covered by its negative registry test and the
surface-boundary replacements.

## Disposition

`sign-rp` and `base-rails-rp` remain a separate migration gate. Their retirement requires an
approved surface-by-surface test/call-path migration and confirmation of external registration/key
ownership. `core-next-rp` remains additionally protected by the live `CoreRpBridge` legacy-client
normalization path. No compatibility contract was weakened merely to make the registry test pass.

## Additional read-only bridge check

The current Compose-backed test database was queried without mutation:

```text
RAILS_ENV=test bin/rails runner 'puts({core_app: CoreAppClientBridge.where(rp_client_id: "core-next-rp").count, core_com: CoreComVisitorBridge.where(rp_client_id: "core-next-rp").count, core_org: CoreOrgOperatorBridge.where(rp_client_id: "core-next-rp").count}.inspect)'
{core_app: 0, core_com: 0, core_org: 0}
```

The empty test database does not establish production absence or authorize removing the legacy
normalization path. The bridge remains gated on a real data inventory and approved migration.
