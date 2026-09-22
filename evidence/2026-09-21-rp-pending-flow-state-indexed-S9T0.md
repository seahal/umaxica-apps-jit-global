# RP pending-flow state-indexing slice

## Scope

This slice removes the RP initiator's legacy scalar session write path. Every newly initiated
OIDC flow now stores its PKCE verifier, nonce, state-associated return path, and optional `max_age`
inside the bounded `oidc_pending_flows` map, including callers that still pass a legacy
`screen_hint`. The existing `screen_hint` query behavior was not broadened or removed in this
slice; canonical first-party `/sign` routes already omit it.

## Change

- Added a public integration assertion that a hinted initiation does not write scalar
  `oidc_code_verifier`, `oidc_state`, `oidc_nonce`, or `oidc_pt` session keys.
- Changed `OidcSsoInitiator#initiate_oidc_session!` to always use the state-indexed pending-flow
  store.

## Verification

Executed on 2026-09-21 at HEAD `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9` with existing worktree
changes preserved.

- `PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/oidc/sso_initiator_test.rb`
  **UNVERIFIED**: Rails boot reached test-schema maintenance but PostgreSQL host `primary` could
  not be resolved (`PG::ConnectionBad: could not translate host name "primary" to address:
  Temporary failure in name resolution`). No test ran.
- `ruby -c app/controllers/concerns/oidc_sso_initiator.rb`: passed.
- `ruby -c test/controllers/concerns/oidc/sso_initiator_test.rb`: passed.
- `bundle exec rubocop app/controllers/concerns/oidc_sso_initiator.rb
  test/controllers/concerns/oidc/sso_initiator_test.rb`: passed; 2 files, no offenses.
- `git diff --check`: passed.

The prior full-suite result (`11,450 runs, 73,177 assertions, 0 failures, 0 errors, 5 skips`)
predates this slice and is not used as verification of it. The focused test must be rerun in the
reachable PostgreSQL/Valkey test environment before this slice is considered complete.

## Remaining risk

The callback concern still contains legacy scalar-key reads for compatibility with older flows.
Their removal requires a separate call-path inventory and regression run; this slice only removes
new scalar writes and therefore does not claim complete legacy-path retirement.
