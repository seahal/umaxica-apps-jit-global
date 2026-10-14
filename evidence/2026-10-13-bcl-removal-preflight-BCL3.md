# First-party BCL removal preflight

## Revision and worktree

The preflight was performed against full commit
`45ed455caa35c0efc2139c1969f541b5b3fc2242` on branch `feature`. The worktree contains uncommitted
Step 5 Xper retirement changes. The local, Git-ignored `three.md` contains the user-authorized
sequencing change CHG-001; `one.md` and `two.md` are unchanged. No Step 6 application or test files
were changed.

## Source inventory

- The repository source search found one sender call: `SignOidcLogout#perform_oidc_end_session_logout`
  calls `notify_oidc_rps_of_logout`, which calls `OidcBackchannelLogoutNotifier`. The notifier
  constructs and enqueues `OidcBackchannelLogoutDeliveryJob` instances.
- `OidcRpLogoutReceiver` is included by four current receiver controllers: Core app, Core com, Core
  org and Edit org. No other receiver was found in the current application source.
- `OidcClientRegistry` builds from `OidcClientStoresStaticClientStore`. That store defines ten
  first-party browser RP specifications with BCL URI/session-required fields. Its native Palm client
  entries do not set BCL fields. This is the repository registry source map; it does not establish
  what an external deployment or party is currently using.
- `OidcBackchannelLogoutDeliveryJob#perform` accepts the current one-argument encrypted payload and
  the legacy form with four trailing fields, for five total serialized arguments.
- Development and production configure Solid Queue using the `queue` database. The development
  database configuration names `development_queue_db` and reads its host from
  `POSTGRESQL_QUEUE_PUB`. The Solid Queue job schema stores `class_name`, `arguments` and
  `finished_at`, so the required current queue inventory must be read from the live queue database.

## Blocker and disposition

The executor has no readable `/etc/codex/network-policy.json`, and
`cloud_environment.environment_status` is not exposed by the active tools. No supported path to
inspect the live queue database was established. The number and argument shape of unfinished BCL
jobs, including legacy five-argument jobs, and their disposition therefore remain unknown. No
PostgreSQL connection or queue query was attempted; no job was drained or purged; no Rails test was
run; and no BCL source, route or test was removed.

AT-007 / REQ-007 is **BLOCKED before implementation**. Resume only after the live queue can be
inspected through an approved, read-only path. Record pending job counts by payload shape without
printing payload contents, and drain or classify each job as required by the accepted plan. A
legitimate external consumer blocks removal pending the planned repair and migration. Static source
inspection alone does not certify either condition.

## Follow-up test impact classification

This read-only classification was performed against the same full commit
`45ed455caa35c0efc2139c1969f541b5b3fc2242`; the Step 5 Xper changes remain uncommitted. No tests
were run and no Step 6 source or test files were edited.

- The five tests whose subject is a removed BCL component are the logout token codec,
  `OidcRpSessionLogout`, RP receiver, notifier and delivery job tests named in `two.md`. Delete them
  with their subjects only after the queue and consumer gates pass.
- Keep shared sign-out tests, but remove stale delivery-job assertions from the Base app/com/org
  logout controller tests. Their remaining session-scope and authority checks still cover live
  behavior.
- Keep registry and token exchange coverage while removing BCL fields and assertions from
  `test/services/oidc/client_registry_test.rb`,
  `test/services/oidc/discovery_document_test.rb`,
  `test/values/regional_rp_client_matrix_test.rb`, and
  `test/services/oidc/token_exchange_service_test.rb`. Discovery tests should assert the BCL
  metadata keys are absent; token issuance's `sid` control remains.
- Update Core and Edit route contracts and the Core smoke/auth-boundary checks to assert that former
  receiver paths are absent and do not mutate sessions. Retain existing negative absence controls
  on Auth sign surfaces. The route references occur in
  `test/controllers/core/route_naming_test.rb`,
  `test/controllers/core/auth_boundary_test.rb`,
  `test/controllers/core/bff_surface_smoke_test.rb`,
  `test/integration/routes/core_route_contract_test.rb`,
  `test/integration/routes/edit_org_publishing_management_route_contract_test.rb`, and
  `test/integration/routes/app_rails_edge_ownership_contract_test.rb`.
- Remove the BCL-only standalone no-store case and preference-CSRF request. Remove deleted receiver
  classes from `test/security/invariants/default_no_store_policy_invariant_test.rb`,
  `test/controllers/protocol_controller_csrf_boundary_test.rb`, and the BCL exemption from
  `test/controllers/security/csrf_route_coverage_test.rb`. Remove only the three stale Sign receiver
  null-session allowlist entries from `test/security/invariants/forbidden_patterns_invariant_test.rb`.
- Retain generic consumed-JTI replay and purge behavior using surviving purposes; remove only the
  `oidc_logout_token` purpose cases from `test/models/security_consumed_jti_test.rb` and
  `test/jobs/security_consumed_jti_purge_job_test.rb`. Remove the BCL-only early-return cases from
  the two branch-coverage batch tests.
- `test/lib/outbound_http/connection_test.rb` has a generic plain-HTTP connection fixture whose
  sample path says `/backchannel`; inspect the remaining outbound call sites before deciding whether
  to rename that fixture or retain a generic connection contract. Do not remove shared redirect or
  transport behavior that still serves other callers.

This is a static classification only. In particular, the repository cannot establish from this
search whether an external party currently consumes BCL, and no runtime queue inventory has been
performed.
