# RP callback scalar fallback retirement

Date: 2026-09-21

## Scope

The RP callback concern now accepts pending state, PKCE verifier, nonce, max-age, and local return
path only from the state-indexed `oidc_pending_flows` entry. Legacy scalar Rails-session values are
still cleared as stale data on callback failure, but they are no longer used for state validation,
token exchange, ID-token validation, or redirect selection.

The callback test fixture was changed to create state-indexed pending flows. A public integration
test also seeds only the legacy scalar values and verifies that the callback rejects the request
before token exchange.

## Verification

Static checks passed:

- `ruby -c app/controllers/concerns/oidc_callback.rb`
- `ruby -c test/controllers/concerns/oidc/callback_test.rb`
- `bundle exec rubocop app/controllers/concerns/oidc_callback.rb test/controllers/concerns/oidc/callback_test.rb`
- `git diff --check`

The focused Rails test could not boot in the current agent environment:

```text
PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/oidc/callback_test.rb
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

No test result is claimed for this slice. The required PostgreSQL/Valkey preflight is recorded in
`evidence/2026-09-21-phase-00-preflight-R3S4.md`; the previously passing suite results there are
historical and do not verify this change.

## Remaining risk

Unreachable historical Base/Auth callback controllers and old documentation/tests still mention
the retired shared RP paths. Their route/caller inventory and retirement require a separate,
explicit migration slice; this change does not delete those files or alter Palm/native behavior.
