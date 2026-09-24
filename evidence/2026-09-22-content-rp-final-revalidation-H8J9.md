# Content RP retirement final revalidation

- Date: 2026-09-22
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Worktree: already contained unrelated and in-progress changes; this verification preserved them. The
  final local diff from this slice touched only three test files.
- Scope: verify that read-only `docs`, `news`, and `help` routes remain available while their obsolete
  Rails OIDC client registrations are absent.

## Repository checks

- The static OIDC registry contains the seven first-party browser RPs, native clients, and the
  remaining shared-browser migration clients; it does not register `docs_*`, `news_*`, or `help_*`
  client IDs.
- Existing content route/API names were not treated as OIDC registrations and were left intact.
- No external service, provider, Cloudflare configuration, secret, or key store was accessed or
  modified.

## Tests and checks

Commands used the repository's Compose-backed test environment with
`UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example` and the four explicitly selected
ticket databases. Secret values were not displayed.

- OIDC registry, token exchange, assertion, and surface lookup focus: **154 runs, 816 assertions,
  0 failures, 0 errors, 0 skips**.
- Read-only content route/API contracts plus OIDC registry: **55 runs, 591 assertions, 0 failures,
  0 errors, 0 skips**.
- Final test-only cleanup focus: **107 runs, 476 assertions, 0 failures, 0 errors, 0 skips**.
- RuboCop on the three changed test files: **no offenses**.
- `git diff --check`: **passed**.
- Final Rails suite: **11,529 runs, 73,419 assertions, 0 failures, 0 errors, 8 skips**.

The Rails suite emitted expected diagnostic output from negative OmniAuth/provider and CSRF tests,
plus existing environment/constant warnings; none was a test failure. Coverage was not used as a
gate, per the current task instruction.

## Result and limits

The local registry and repository-side contracts are verified. The retirement of any external edge
registration, deployed client key, or undeployed consumer dependency was not verified and remains a
separate deployment/integration check. No claim is made that the broader regional RP registration or
shared-browser-client retirement gates are closed.
