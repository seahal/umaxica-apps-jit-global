# Routing Policy and Exception Ledger — Step 7

Status: **COMPLETE for Step 7 / REQ-074** after the standard test-database follow-up below. Route
annotation work for REQ-075 remains in Step 16 of the fixed order.

## Revision and worktree

- Branch: `feature`
- Full HEAD: `45ed455caa35c0efc2139c1969f541b5b3fc2242`
- The worktree had uncommitted changes, including the deferred Step 5 work; those changes were
  preserved. Step 7 did not change route files or route behavior.
- Frozen file checksums still match: `one.md`
  `663bb1a858f537edde4da80e53631a73e08a8022c59123fb2df391601d4cbe4c`; `two.md`
  `7297a6e0eb52fc4df2768c926e084297e654f827c0acd83f0d462c6c8ae4086d`.
- Acting agent: Codex. Exact backend model and reasoning-effort settings are not exposed in this
  session.

## Changes made

- Updated `.agents/harnesses/rules/generic/routing.mdc` and
  `adr/rails-routing-resourceful-policy.md` with A/B/C route classification, route-specific approval
  and ledger requirements, the `param:` debt rule, one-root-definition-per-FQDN counting, duplicate
  priority reporting and the authorized FIXME format.
- Added only the neutral RP `/sign` exception specified by REQ-074: Core app/com/org, Warp
  app/com/org, Edit org and Palm app. The ledger records the observed host aliases and route helper
  names. The GET remains display-only and the POST remains CSRF-protected.
- No route code, URL, parameter, helper, controller lookup, authentication/access constraint or
  route comment changed. Route FIXME comments remain in Step 16's sequence.
- `git diff --check` on the two changed policy files produced no errors.

## Route inventory and before/after comparison

Commands used the same development settings before and after the documentation edit:

```sh
UMAXICA_ENV_FILE=/home/global/workspace/.env.devcontainer.example RUBY_DEBUG_ENABLE=0 bin/rails routes
```

Both commands exited 0. Raw captured files differ in startup logs and one Rack object address. After
normalizing process-specific `0x...` addresses, both route sections contain 1,655 lines and have the
same SHA-256: `0a2211049521c05cd55d2c77e9353a87186d1fb1b10c3c322d023e3813afa8d0`.

Route-object inspection used the same environment with `bin/rails runner` and counted exact `/`
paths across the loaded route set:

- 39 exact `/` route definitions: 31 product roots, six host-constrained engine mounts and two
  unconstrained routes.
- The 37 host-constrained definitions cover 72 distinct explicit FQDNs. No concrete FQDN is shared
  by multiple host-constrained definitions. Duplicate host strings inside a single host array were
  counted once per route definition.
- The unconstrained `GET /` to `unknown_hosts#show` follows the host-specific roots and mounts. It
  therefore acts as a fallback on otherwise unmatched hosts while its pattern overlaps the explicit
  host definitions.
- The later unconstrained development `GET /` to `rails/welcome#index` follows that fallback and is
  shadowed in this environment. These definitions and their route priority were recorded, not
  changed.
- The six constrained mounts are Mission Control Jobs, Flipper, Blazer, PgHero, Rswag UI and Rails
  Performance.

The Step 7 ledger adds the Core/Warp/Edit/Palm neutral RP `/sign` scope. Separate Base app/com/org
`GET/POST /sign` routes were also observed. They are outside the surfaces named for this ledger
entry and were not added or changed; they remain debt for separate route-specific approval or
reconciliation.

## `param:` inventory

`rg -n 'param:' config/routes -g '*.rb'` returned 20 textual matches, including comments. Inspection
of active route DSL lines found 13 declarations: twelve `param: :public_id` routes (three each in
Docs, Help, Info and News) and one `param: :guid` route in Guid. No individual ADR approval of the
`param:` DSL option was found. All 13 remain existing C debt; no use was changed or added. The
frozen plan's textual count was not edited.

## Tests not run at the original observation

The acceptance tests listed by AT-074 had not been executed at this observation:

- `test/config/acme_public_resource_routes_test.rb`
- `test/config/routes_public_id_param_test.rb`
- `test/config/routing_entrypoints_test.rb`
- `test/controllers/auth/route_naming_test.rb`
- `test/integration/routes/`

The repository's preferred command prefix for future Rails test commands is:

```sh
POSTGRESQL_TEST_PREPARE_DATABASES="$(grep -E '^POSTGRESQL_TEST_PREPARE_DATABASES=' .env.devcontainer.example | cut -d= -f2)" \
  bin/rails test <accepted test paths>
```

That declaration is a database preparation allowlist and does not establish ownership or isolation.
At this observation there was no `POSTGRESQL_ISOLATED_TEST_RUN_ID`, no
`POSTGRESQL_ISOLATED_TEST_MANIFEST`, no PostgreSQL isolated-test manifest under the workspace `tmp/`
or `/tmp`, and `primary` did not resolve through DNS. The single manifest-shaped file found under
`/tmp` belongs to an unrelated Edge audit. `test/test_helper.rb` loads all fixtures and installs
`ParallelTestDatabaseCloner`; the selected tests therefore were not run against ordinary shared
`test_*` databases. No database preparation, migration, test or cleanup command ran.

This status was superseded by the follow-up below after the user changed the permitted database
target to the standard Rails test configuration.

## Follow-up environment check at the original observation

Checked again on 2026-10-13 against full HEAD `45ed455caa35c0efc2139c1969f541b5b3fc2242` with the
same dirty worktree. The `cloud_environment.environment_status` tool is not available in this
session, and `/etc/codex/network-policy.json` is unreadable or absent. Neither Docker nor Podman is
installed; `/var/run/docker.sock` and the PostgreSQL Unix socket are absent.
`pg_isready -h 127.0.0.1 -p 5432` returned `no response`. The read-only `ss` listener query could
not inspect netlink (`Operation not permitted`). No PostgreSQL connection, query, preparation,
migration or test was attempted. No safe local isolated test path was found at that observation.

## Completion follow-up on the standard Rails test database

The user directed the implementation to use the standard Rails `development` and `test`
configurations, not an isolated test fleet. This direction is recorded as CHG-003 in the local
`three.md`.

The route-test command ran against full HEAD `45ed455caa35c0efc2139c1969f541b5b3fc2242` with the
test expectation correction uncommitted. Post-run status and schema checks and the Rails notes
command ran at full HEAD `65b786f9ed5270da3007b457fff33b946008c394`. The worktree remained dirty;
the Step 7 policy files and Step 8 changes were not part of the route-test commit.

After the retired Device route test expectation was corrected, the AT-074 test group passed with
`PARALLEL_WORKERS=1`: 154 runs, 2,766 assertions, no failures, errors or skips. The correction only
changed the test expectation to require `GET /sign/in/device` to be unrecognized, as the completed
Step 3 contract requires. The RuboCop check for the changed test passed. Detailed output and the
standard test-database findings are in `evidence/2026-10-13-route-tests-standard-db-L6P2.md`.

The standard Rails test preparation performed a read-only catalog check through the configured admin
database `db` before using the 20 `test_*` databases. It invoked the normal migration task for those
test databases; all 1,429 migrations were already applied, and post-run status plus schema drift
checks remained clean. No test database was reset and no migration had pending work.

`RAILS_ENV=test bin/rails notes --annotations FIXME` exited 0 and listed the repository's existing
FIXME annotations. Step 7 introduced no route comments; the route annotations remain scheduled for
Step 16. The required route inventory and code/document checks above remain unchanged, so Step 7 is
complete for its REQ-074 scope.
