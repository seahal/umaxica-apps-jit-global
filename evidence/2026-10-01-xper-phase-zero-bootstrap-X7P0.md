# Xper Phase 0 bootstrap verification

- Date: 2026-10-01 (UTC).
- Commit: `91974b8b05ccda80afcb1beb3174ab48f4155889`.
- Worktree: uncommitted Xper changes affected these results. Pre-existing untracked ADRs,
  initializer and tests were preserved. Concurrent user changes to AGENTS, SurfaceChrome,
  Warp callbacks and locale content were also preserved. No commit or external write was made.

## Completed checks

| Check | Command / subject | Observed result |
| --- | --- | --- |
| Related contracts | `bundle exec rails test` with the sixteen files listed below | 177 tests, 6,401 assertions; 0 failures, 0 errors, 0 skips |
| Host Authorization | `bundle exec ruby test/config/host_authorization_contract_test.rb` | 3 tests, 53 assertions; 0 failures, 0 errors, 0 skips |
| Standard Rails suite, final serial run | `bundle exec rails test` | 12,126 tests, 78,701 assertions; 28 failures, 4 errors, 2 skips; exit 1 |
| Scoped Ruby lint | `bundle exec rubocop` on Xper controllers/routes and all affected Ruby configuration/contracts | 57 files; no offenses |
| Repository Ruby lint | `bundle exec rubocop --format simple` | 4,911 files; 62 offenses in files outside the Xper change; exit 1 |
| Repository ERB lint | `bundle exec erb_lint --lint-all` | 1,586 files; no errors |
| Final Xper ERB lint | `bundle exec erb_lint app/views/layouts/xper app/views/xper` | 6 files; no errors |
| Security static analysis | `bundle exec brakeman --no-pager --quiet` | 0 analysis errors; 1 existing warning in unchanged `app/operations/client_emergency_secret_credential_sign_in_operation.rb:22` (`SECRET_KIND`); exit 3 |
| Patch whitespace | `git diff --check` | passed |
| Rails route table | `bundle exec rails runner -e test` inspecting Xper routes | 33 routes, eleven per edition, each in its own controller namespace |
| Compose structure | Ruby YAML parsing of `.devcontainer/compose.yaml` and comparison with HEAD | all six Xper/Warp aliases present; existing Core VPC alias retained; Core host publications unchanged |

The related contract files were:

- `test/integration/xper_bootstrap_test.rb`
- `test/security/invariants/xper_phase_zero_invariant_test.rb`
- `test/integration/health_endpoints_test.rb`
- `test/integration/revision_endpoint_test.rb`
- `test/controllers/csp_violation_reports_controller_test.rb`
- `test/security/invariants/fqdn_availability_registry_invariant_test.rb`
- `test/unit/security/public_entrypoint_inventory_test.rb`
- `test/contracts/openapi_route_coverage_test.rb`
- `test/lib/config_values/host_family_values_test.rb`
- `test/controllers/controller_base_inheritance_test.rb`
- `test/controllers/concerns/application_controller_common_patterns_test.rb`
- `test/controllers/concerns/default_web_rate_limit_test.rb`
- `test/unit/security/ri_routing_contract_test.rb`
- `test/integration/layout_title_contract_test.rb`
- `test/security/invariants/controller_lifecycle_order_invariant_test.rb`
- `test/security/invariants/csrf_verification_strategy_invariant_test.rb`

These checks covered public/private host routing, FQDN slot and fail-closed polarity, absence of
Experience/PWA/offline/manifest routes, independent controller bases, no Preference/Experience
credential issuance, public canonical SEO URLs on both ingress families, valid XML, shared
health/revision contracts and machine JSON negotiation, CSP null Origin and malformed/empty
input, body bytes 65,535/65,536/65,537, CSP request counts 119/120/121, and homepage request
counts 299/300/301. The homepage cookie test explicitly enabled forgery protection.

The installed Inertia Rails gem includes a global hook into `ActionController::Base`. With
forgery protection enabled, that hook emits framework CSRF/session cookies on ERB requests.
The Xper test verifies that neither Preference nor Experience access/refresh/dbsc credentials
are emitted; it does not assert absence of every framework cookie. Xper declares no Inertia
page, layout, configuration or sharing lifecycle, and excludes `SurfaceInertiaPage`,
`PreferenceGlobal`, actor hydration and the application Session/authentication lifecycle.

The registry continues driving FeatureFlags generation and development seed. Neither
`FeatureFlags::REGISTRY` nor `db/seeds.rb` was changed; production auto-enablement was not added.

## Full-suite failures and comparison

No final serial-suite failure or error named an Xper controller or test. Remaining failures
included Base root/sign-out expectations, Preference return-link/current-behavior expectations,
Auth invalid-cookie recovery, pre-existing title failures, and the architecture baseline.
The four errors came from `SignRouteHostTest` using removed `sign_*` helper vocabulary.
The two existing skipped tests were reported by the standard suite; their names were not
collected in a verbose rerun.

The Base, Auth, Core and Palm controller trees, models, database files, and Base route file
had no diff from HEAD attributable to this task. That is a source-preservation observation,
not a claim that the whole suite is green.

A `git archive HEAD` copy under `tmp/xper-baseline` used the same installed dependencies and
credential key paths without changing the live worktree. Its serial command
`bundle exec rails test test/integration/preference_logout_downgrade_test.rb` reproduced both
logout failures: 2 tests, 9 assertions, 2 failures, 0 errors, 0 skips. In both cases the old
expectation was `/sign/out` while the unchanged code returned `/`. This establishes that those
two failures predate Xper.

The additional serial HEAD comparison used
`bundle exec rails test test/integration/preference_inertia_page_contract_test.rb test/integration/com_visitor_preference_current_behavior_test.rb test/controllers/base/sign_out_and_oauth_revocation_test.rb test/security/invariants/read_only_route_write_invariant_test.rb`.
It completed with 54 tests, 1,017 assertions, 9 failures, 0 errors, 0 skips. Its nine failures
were the same six Preference guest-return/root expectations, Com adoption expectation,
Base sign-out redirect expectation and Base read-only `/dashboard` expectation observed in
the final working-tree suite. These comparisons establish that those eleven Base/Preference
failures predate Xper. They do not establish a baseline for every unrelated suite failure.

## Execution constraints and recovery

The first sandboxed targeted test could not resolve PostgreSQL `primary` during test-schema
maintenance. Executing the unchanged command with access to the existing test infrastructure
succeeded; no ad-hoc test ENV or application bypass was introduced.

The generator attempt was blocked by the development debugger's Unix socket bind in the sandbox;
controller files were therefore created from the existing surface archetypes and checked by
routing, inheritance, CSRF, lint and behavioral contracts.

An initial full run before the inventory/title/default-rate fixes completed with 12,123 tests,
37 failures, 4 errors and 2 skips. A subsequent full run overlapped an isolated HEAD comparison;
shared database clone preparation interfered and missing worker databases invalidated the run.
Those processes were stopped. The final serial suite above completed without missing-database
errors. The interrupted comparison and suite are not treated as successful checks.

`.devcontainer` was an OS-level read-only mount. Shell, elevated execution and file-editor
writes all failed. A narrow patch was prepared at `tmp/xper-compose-aliases.patch`; the user
made the alias changes from the host. An intermediate host-side diff removed
`core-workers-vpc.internal`. The user restored it after reviewing the existing Workers VPC
contract. Final static validation confirms the Core VPC alias is retained and the only Compose
diff is the requested Xper additions and Wide-to-Warp alias replacement. No external
Cloudflare configuration or runtime VPC reachability was inspected.

No Compose CLI is available in this execution environment. Compose verification used YAML
parsing and exact alias/port comparison, rather than claiming `podman compose config` ran.

## Deferred checks

No devcontainer rebuild, `getent`, private HTTP curl, public apex request, public DNS, Tunnel,
Access, or Warp public E2E check was performed. These are Phase 1 checks, not Phase 0 PASS claims.
See [the Activation Gate](../docs/operations/xper-phase-one-activation-gate.md).
