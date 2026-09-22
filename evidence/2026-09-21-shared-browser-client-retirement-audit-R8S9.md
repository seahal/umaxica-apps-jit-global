# Shared browser client retirement audit

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Frozen Plan requirement: `FREQ-0020`
- Worktree: pre-existing changes were preserved; no reset, clean, commit, GitHub write, external
  registration change, or key-management access was performed.

## Current registry and authority map

`app/values/oidc_client_stores_static_client_store.rb:78-85` still registers the deprecated
shared browser client IDs:

- `sign-rp`
- `base-rails-rp`
- `side-rails-rp`
- `core-next-rp`

`app/values/auth_boundary_authority_map.rb:20-23` still classifies those IDs as deprecated shared
browser clients. Their presence is therefore explicit migration state, not an accidental test-only
fixture.

## Production call-site evidence

The repository still contains active application references:

- Auth app/com/org callback and sign-out paths use `sign-rp`.
- Base app/com/org application and callback paths use `base-rails-rp`.
- `app/models/concerns/core_rp_bridge.rb` still recognizes `core-next-rp` as a compatibility
  binding.
- The static registry still defines redirect, logout, audience, and key namespace behavior for
  all four IDs.

These references are under `app/` and are not test-only uses. Removing the registry entries now
would create missing-client failures or silently change callback/logout authority. The existing
test suite also encodes the current migration behavior across token exchange, logout, registry,
refresh, and connection records; those tests cannot be deleted merely to permit removal.

## Adversarial assessment

- A client identifier can be retired only after its application call sites, callback registrations,
  logout/backchannel registrations, persisted session records, and external registration state have
  a verified replacement and retirement order.
- Replacing an ID by string substitution would be unsafe because the client IDs also bind audience,
  redirect URI, credentials, RP-session client binding, and backchannel behavior.
- Keeping a compatibility client solely for old tests would violate the Frozen Plan, but the current
  evidence shows real production callers, so the present registrations are not retained solely for
  tests.
- No external registration, private-key inventory, active-session inventory, or migration window
  was available in this repository-only execution context. No external system was contacted.

## Disposition

`FREQ-0020`: `BLOCKED_BY_DEPENDENCY` / `NEXT_CYCLE` for retirement implementation.

No shared client was deleted or renamed. The safe next step is a separately approved migration
matrix that maps each old caller to an exact replacement client, proves redirect/logout/backchannel
and key independence, handles existing sessions and codes, and provides an external retirement
window. Only after that matrix is verified should application callers, registry entries, and tests
be migrated together.

This finding is separate from the regional RP registration blocker (`FREQ-0014`) and the content
RP retirement dependency (`FREQ-0016`). It does not close or widen either one.

## Verification record

Commands used:

- `rg -n --glob 'app/**' --glob 'config/**' --glob 'lib/**' '(sign-rp|base-rails-rp|side-rails-rp|core-next-rp)'`
- `rg -n --glob 'test/**' '(sign-rp|base-rails-rp|side-rails-rp|core-next-rp)'`
- `nl -ba app/values/oidc_client_stores_static_client_store.rb | sed -n '75,220p'`
- `rg -n 'sign_rp|base_rails_rp|side_rails_rp|core_next_rp|client_id' app/controllers app/services`

No Rails test was run for this read-only audit. Current test execution in this shell remains
blocked by unresolved Compose hostnames (`primary` and `valkey-kvs`); no localhost substitution or
application workaround was used.

## Current local revalidation

The repository now has a limited Auth/Base boundary slice after the original audit. Auth app/com/org
no longer expose OIDC authorization, callback, or backchannel controller routes, and their sign-out
controllers no longer include `OidcRpLogoutLauncher` or issue `sign-rp` logout requests. They clear
Auth ceremony continuity and redirect to the configured Base sign-out route; coordinated logout still
advances the existing `sign_cleared` transaction step. The shared client registrations themselves
remain unchanged because Base, Core bridge, persisted-session, key, and external-registration
retirement evidence is still incomplete.

Focused verification after that slice:

- `PARALLEL_WORKERS=1 bin/rails test test/security/invariants/auth_base_authority_boundary_test.rb test/controllers/auth/app/sign_outs_controller_test.rb test/controllers/auth/com/sign_outs_controller_test.rb test/controllers/auth/org/sign_outs_controller_test.rb`
- Result: `13 runs, 129 assertions, 0 failures, 0 errors, 0 skips`.

This does not change the disposition: `FREQ-0020` remains `BLOCKED_BY_DEPENDENCY` / `NEXT_CYCLE`.
