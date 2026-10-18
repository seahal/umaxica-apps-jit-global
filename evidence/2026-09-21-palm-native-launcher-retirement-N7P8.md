# Palm native authorization launcher retirement

- Date: 2026-09-21 UTC
- Repository: `seahal/umaxica-apps-jit-global`
- Branch: `feature`
- HEAD observed before this slice: `ab4746f9d403021b3ea5fff53a0a6ae4b4e68ec9`
- Worktree: pre-existing changes were preserved; no reset, clean, commit, GitHub write, external
  service access, or provider configuration change was performed.
- Frozen Plan requirement: `FREQ-0017`

## Finding

The accepted Palm architecture says that Palm is an app-only native Resource Server, that the
concrete iOS/Android native flow is not yet approved, and that the inert callback compatibility
stub must not exchange tokens or create durable state. The current repository nevertheless exposed
an unfinished Palm-specific authorization launcher:

- `config/routes/palm.rb` routed `GET /oidc/authorization` to Palm.
- `app/controllers/palm/app/oidc/authorizations_controller.rb` accepted `app-ios-rp` and
  `app-android-rp`, selected `screen_hint`, and redirected to Base `/oauth/authorize`.
- `app/controllers/palm/app/roots_controller.rb` published iOS and Android sign-up links to that
  launcher.
- Integration tests treated that redirect and the two public links as the active contract.

This was inconsistent with the Frozen Plan requirement not to expose an unfinished native
authentication surface before an actual native client and external registration exist. It also
conflicted with `adr/acme-sign-core-base-port-boundary.md`, which leaves the concrete native flow
open and limits the compatibility callback to an inert stub.

## Change made

The smallest repository-local correction was applied:

- removed Palm's `/oidc/authorization` route;
- removed the unused Palm authorization controller;
- left only the inert `/oidc/callback` compatibility stub;
- removed the iOS/Android authorization links from the Palm landing props while preserving the
  existing response shape with an empty `links` collection;
- updated route, boundary, redirect-allowlist, and integration tests to assert the launcher is not
  routable and the root publishes no native authentication links;
- updated the Palm architecture and endpoint inventory to distinguish the inert callback from a
  future, separately approved native authorization flow.

The `app-ios-rp` and `app-android-rp` public-client registry entries and the `palm-api` resource
server verifier were not changed. Palm remains app-only, bearer-only at its API boundary, and
rejects DPoP-bound tokens when presented as Bearer. No native client, private secret, route family,
or external registration was invented.

## Adversarial review

- A hostile caller can no longer select a registered native client through a Palm URL and cause
  Palm to proxy an authorization request.
- The callback remains inert and is still separately route-tested; it does not gain token exchange
  or session mutation.
- The Palm API remains reachable only through its existing bearer-token resource boundary; this
  slice did not add browser cookies, localStorage credentials, or a second issuer.
- Unknown or known `client_id` values have the same result for the removed launcher: no route.
- The future native client flow remains an explicit external-registration decision rather than an
  assumption encoded in Rails.

## Verification

Static checks completed after the edit:

- Ruby syntax checks passed for the changed Ruby/config/test files.
- Targeted RuboCop passed for the seven changed Ruby/config/test files (`7 files inspected, no
  offenses detected`).
- `git diff --check` passed for the changed files.
- Repository search found no remaining production reference to
  `palm_app_oidc_authorization_path`, the removed Palm authorization controller, or the removed
  Palm authorization route.

The focused Rails test command was attempted with the repository-supported devcontainer environment
variables:

```text
env UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example \
  POSTGRESQL_TEST_PREPARE_DATABASES=test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db \
  PARALLEL_WORKERS=1 bin/rails test \
  test/controllers/palm/app/oidc_boundary_test.rb \
  test/integration/base_palm_auth_entrypoints_test.rb
```

It did not reach test execution because this shell is outside the Compose network:

```text
ActiveRecord::DatabaseConnectionError: There is an issue connecting with your hostname: primary.
PG::ConnectionBad: could not translate host name "primary" to address: Temporary failure in name resolution
```

`getent hosts primary` and `getent hosts valkey-kvs` returned no records, and neither `podman` nor
`docker` is installed in this execution context. No localhost substitution or application/config
workaround was used. Therefore the Rails test result is `UNVERIFIED` in this shell; the changed-area
tests must be rerun inside the core service before this slice is considered verified.

## Disposition

`FREQ-0017`: implementation slice completed locally, runtime verification pending core-service
test access. The external native-client registration decision remains a separate dependency for
re-enabling any authorization launcher. This slice does not close the regional RP registration
blocker or the provider notification delivery/receipt/retry blocker.
