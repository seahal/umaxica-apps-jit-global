# OIDC Access JWT stateless RP-session validation

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing uncommitted changes were present and preserved. No reset, clean,
  commit, push, GitHub write, provider access, deployment, or production/shared-data operation was
  performed.

## Change

Normal OIDC Access JWT authentication no longer resolves an RP Session row on each request. The
JWT retains `sid` as the RP Session protocol identifier and now carries the private
`umx_base_sid` claim for the Base Browser Session that issued the RP credentials. The authenticator
verifies the JWT and DPoP proof, resolves the parent Base Browser Session, requires that parent to
remain usable, resolves the surface-local actor from the verified subject, checks client/audience
binding and actor ownership, and returns the parent token as the authenticated session context.

The RP Session remains the authority for refresh rotation, revoke, logout, and new credential
issuance. A child RP-session revoke therefore stops future refresh/issuance but does not
retroactively invalidate an already-issued Access JWT; the existing RFC 9068 expiry and configured
leeway remain the validity bound. No per-request blacklist or Valkey revocation list was added.
Palm/native authentication was not changed because it is a separate boundary.

## TDD and verification

The new public regression first failed because `OidcAccessTokenAuthenticator` queried
`ClientRpSession` during ordinary authentication. After the implementation change, the focused
test proves that a valid JWT succeeds while the RP-session lookup is made to raise. Tests also
cover the required Base-session claim, parent/actor mismatch, token client binding, child revoke
independence, and claim extraction.

Commands executed with the repository-supported Compose environment (`UMAXICA_ENV_FILE` selected
`.env.devcontainer.example`; no secret values were printed):

- `PARALLEL_WORKERS=1 bin/rails test` on the focused OIDC/token files: 145 runs, 557 assertions,
  0 failures, 0 errors, 0 skips.
- broader OIDC/Core/cross-surface regression set: 82 runs, 469 assertions, 0 failures, 0 errors,
  0 skips.
- `bin/rails test`: 11,500 runs, 73,295 assertions, 0 failures, 0 errors, 5 skips.
- targeted `bin/rubocop` for the changed Ruby files: no offenses.
- `RAILS_ENV=test bin/rails zeitwerk:check`: `All is good!`.
- `git diff --check`: passed.

The repository-wide worktree was already dirty; the results above include the current uncommitted
working tree and are not a clean-branch baseline. Coverage was not run, per the current task
instruction. Live external RP registration, key management, and production revocation behavior
remain unverified.
