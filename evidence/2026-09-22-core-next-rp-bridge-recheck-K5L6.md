# Core legacy RP bridge recheck

- Date: 2026-09-22 UTC
- HEAD: `91d71c6f61d60c13be350bff3b723e05d09adf37`
- Branch: `feature`
- Worktree: existing changes preserved; no registry deletion, migration, external configuration,
  or provider operation was performed.

## Repository evidence

The current production model layer still includes `CoreRpBridge` in the concrete app/com/org Core
bridge models. Its defaulting and legacy-host logic explicitly recognizes `core-next-rp`, and the
static registry still builds that compatibility client with Core redirect, post-logout, and
back-channel logout URIs. The test tree also exercises that bridge and its OIDC client binding.

This is an active local compatibility dependency, not merely a historical comment or an obsolete
test expectation. Removing the registry entry or changing its client binding requires the bridge
callers, deployed registrations/keys, and cutover order to be reconciled first.

## Verification

```text
PARALLEL_WORKERS=1 bin/rails test \
  test/values/oidc_seven_first_party_rp_clients_test.rb \
  test/values/oidc_client_registry_test.rb \
  test/models/core_rp_bridge_test.rb \
  test/services/oidc/client_registry_test.rb
```

Result: `47 runs, 358 assertions, 0 failures, 0 errors, 0 skips`.

## Disposition

`CF-007: OPEN / external migration gate`. The local first-party registry and bridge contracts are
green, but the regional RP identity requirement cannot be completed by inventing client IDs or
sharing credentials. External RP registration, independent keys, issuer cutover, and bridge data
migration remain required before the compatibility client can be retired.
