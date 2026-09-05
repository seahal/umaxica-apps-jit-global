# Dependency update, audit, and the red suite behind them

## What was being verified

Whether the `feature` branch passes on the tree pulled at 2026-09-04 02:00 JST, what a full package
update moves, whether the scanners find a performance or security defect, and how far test coverage
can be raised. Work resumed from a session interrupted by a usage limit.

## Context

- Repository `umaxica-apps-global`, branch `feature`, base revision `79d45d095`
- Ruby 4.0.6, Rails 8.2.0.alpha, node v24.19.0, pnpm 12.0.0
- PostgreSQL over the podman network; Valkey at `valkey:6379`
- Date: 2026-09-04

## The state the interrupted session left

`coverage/coverage.json` from 2026-09-03 12:33 UTC was written at `79d45d095`, the same revision
HEAD was on, and reported line 99.15% (54052 / 54515), branch 82.35%, method 95.23% — every
`.simplecov` gate cleared. `coverage/.last_run.json` was **not** updated by that run, and SimpleCov
writes it only when the run succeeds, so the failure was in the tests, not the gates.

Two prior sessions had also left `stash@{1}` (coverage WIP from 2026-09-01) untouched; it was not
disturbed here.

A second Claude session was found editing the same worktree concurrently. It was asked to stop, and
its in-flight edits were reviewed and adopted rather than discarded (its own records are
`evidence/2026-09-03-health-revision-api-contract.md` and
`evidence/2026-09-03-publishing-entries-public-id-contract.md`).

## The suite was red: nine tests, all branch fallout

Confirmed by running the named files, not inferred:

| Test                                                        | Cause                                                                                                                                                             |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `routes_public_id_param_test`                               | `79d45d095` introduced `param: :public_id` on the four content route drawers; the invariant forbade it everywhere                                                 |
| `help_docs_news_surface_smoke_test`                         | still addressed the entries show action by `slug`                                                                                                                 |
| `openapi_content_entries_contract_test`                     | set `archived_at` alone, which `chk_publishing_entries_archive` (`db/migration_support/publishing_schema.rb:353-359`) rejects with `ActiveRecord::CheckViolation` |
| `bare_controller_test`                                      | `REQUIRED_DESCENDANTS` predates the two new `Api::V0` bare controllers                                                                                            |
| `html_title_contract_test`                                  | asserted an HTML `<title>` for `/health`, which is `text/plain` now                                                                                               |
| `public_entrypoint_inventory_test`                          | classified only the text health/revision paths                                                                                                                    |
| `controller_inheritance_invariant_test`                     | `KNOWN_VIOLATIONS` named two controllers `0fc42d09c` deleted                                                                                                      |
| `forbidden_rails_patterns_test`, `ri_routing_contract_test` | both allowlists named the three `base/*/edge/v0/dbsc` controllers `0fc42d09c` deleted                                                                             |
| `base/org/edge/v0/dbsc_controller_test`                     | asserted on a class `0fc42d09c` deleted                                                                                                                           |

The last four are worth naming precisely: they are **not** pre-existing unrelated failures, they are
the unfinished half of the dead-code removal committed earlier on this same branch.

The earlier session also reported `AcmeRootsTest` and `BasePalmSurfaceSmokeTest` as failing only in
a full run. Both were left alone rather than pre-emptively "fixed", since neither was reproduced in
isolation; the full run below is what settles whether they fail.

## What was changed, and why

- The three deleted-controller allowlists lost their stale entries. Only removals, so no skip
  becomes newly permitted.
- `base/org/edge/v0/dbsc_controller_test` was re-pointed at `core/*/edge/v0/dbsc`, the routed
  preference DBSC endpoint the deleted file was a rename leftover of. Measured first: that
  controller's callback chain satisfies the same three assertions. The test now covers all three
  core surfaces and additionally asserts the router mounts what it asserts on — the earlier version
  guarded a class no request could reach.
- `compose.override.yaml.example` and `compose.remote-access.yaml` were restored from `7a7a94bdd^`.
  `7a7a94bdd` is a lockfile bump that deleted them as collateral, while `compose.yaml`,
  `.gitignore`, `README.md`, three `docs/operations` guides, both `.devcontainer` remote-access
  scripts and two tooling tests still reference them. Neither publishes a host port.
- `MachineJsonNegotiation::ACCEPTABLE` lost `"application/*"`. See below.

## The one implementation defect the audit found

`ACCEPTABLE` was matched against `request.accepts`, and it listed `"application/*"`. That entry can
never match. Measured directly rather than assumed:

```
Accept: application/*  ->  request.accepts expands to 12 concrete types
                           includes "application/json"? true
                           includes literal "application/*"? false
```

`Mime::Type.parse` expands a trailing-star range into the registered concrete types, so the literal
never reaches the comparison; `application/*` was being accepted by the `application/json` entry all
along. The dead entry is removed and the behaviour it appeared to provide is now pinned by a test.
No response changed.

A second finding was pinned rather than fixed: `Accept: application/json;q=0` is an explicit refusal
under RFC 9110 12.5.1, but Rails discards the weight when parsing, so the endpoint answers 200.
Honouring q values means hand-rolling a parser for a header no orchestrator sends this way, so the
deviation is recorded in a comment and fixed in place by a test.

## Package update

`bundle update` (exit 0):

| Package                  | From                                       | To                                                |
| ------------------------ | ------------------------------------------ | ------------------------------------------------- |
| `rails` (git, `main`)    | `2164c6c6f7fb91cc1caff5ee4b05931445de42ea` | `24baf7ab874edeae25b147fa25943738c514c0ce`        |
| `et-orbi`                | 1.4.1                                      | 1.4.2                                             |
| `google-protobuf`        | 4.36.0                                     | 4.36.1                                            |
| `omniauth-google-oauth2` | 1.2.2                                      | 1.2.3 (also widens its `jwt` constraint to `< 4`) |
| `svix`                   | 2.1.0                                      | 2.2.0                                             |

`propshaft` and `flipper`, also git-sourced, were already at their branch heads.

`pnpm update` (exit 0): `knip` 6.33.0 -> 6.34.0 plus two transitive packages. No major version was
crossed on either side, so no compatibility change was needed. `bin/rails runner` booted on the new
Rails revision and reported 8.2.0.alpha before the suite was run.

## Audit results

| Check                                       | Result                                                                                                     |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `bundle exec brakeman`                      | 0 security warnings, 0 errors, over 811 controllers / 557 models / 88 templates                            |
| `bundle exec bundler-audit check --update`  | No vulnerabilities found (advisory db `0a02e5f`, 1237 advisories)                                          |
| `bundle exec rubocop`                       | 4396 files inspected, 0 offences                                                                           |
| `pnpm lint` (oxlint)                        | exit 0                                                                                                     |
| `pnpm format:check` (oxfmt)                 | exit 0, 571 files                                                                                          |
| `pnpm typecheck` / `typecheck:verify` (tsc) | exit 0                                                                                                     |
| `pnpm deadcode` (knip)                      | exit 0, one configuration hint, no unused code                                                             |
| `pnpm openapi:lint` (redocly)               | app/com/org valid                                                                                          |
| `pnpm test:coverage` (vitest)               | exit 0; statements 99.54%, branches 99.03%, functions 98.80%, lines 99.81%, against a flat threshold of 98 |

Performance was not re-derived from scratch: N+1 is structurally prevented by
`config/environments/test.rb:82-84` (`strict_loading_by_default` with
`action_on_strict_loading_violation = :raise`) plus Prosopite, and the one query changed on this
branch, `PublishingPublishedEntriesQuery#find_published`, moved from a join through the slug table
to a direct `edition.entries` lookup with a flattened `includes`, which is strictly fewer joins.

## The check that could not be completed

`pnpm audit` did not run. Four attempts, two distinct failures from the same endpoint:

```
× The audit endpoint (at https://registry.npmjs.org/-/npm/v1/security/advisories/bulk)
  responded with 503: {"error":"Service Unavailable"}

× Failed to request the audit endpoint (at https://registry.npmjs.org/-/npm/v1/security/
  advisories/bulk): error sending request  ╰─▶ operation timed out
```

The JavaScript dependency tree is therefore **unscanned in this record**. This is a registry-side
outage, not a repository problem, and CI's `scan-npm` job makes the same call and hard-fails when
the response will not parse, so it would be failing on this too. Two other npm advisory paths remain
active and are unaffected: the daily Dependabot npm schedule and the `dependency-review-action` that
runs on every pull request. `bundler-audit` covers the Ruby side and did run, clean.

`bundle exec database_consistency` was not attempted. Version 3.0.11 calls the deprecated
`ActiveRecord::Base.connection`, which raises under Rails 8.2.0.alpha; reproduced here incidentally
when a `bin/rails runner` using that API aborted with the same error.

## Coverage and the full suite

`COVERAGE=true bin/rails test`, first run on the updated tree:

```
12273 runs, 69393 assertions, 1 failures, 0 errors, 1 skips   (1091.2s)
Line coverage:   54054 / 54515 (99.15%)
Branch coverage:  7703 /  9344 (82.43%)
Method coverage:  9650 / 10132 (95.24%)
```

Every `.simplecov` minimum was cleared, but the one failure stopped SimpleCov from writing
`coverage/.last_run.json`, so the `maximum_drop` comparison did not run on that pass. The failure
was caused by this update: `google_provider_adapter_test` asserted
`verification_authority == "omniauth-google-oauth2/1.2.2"` while the adapter derives that version
from the loaded gemspec, which had moved to 1.2.3. Both that assertion and the identical latent one
in `apple_provider_adapter_test` now derive the version the same way the adapter does and also match
its shape; dropping the version from the adapter still makes the test fail.

After that fix, the suite was re-run in full:

```
12273 runs, 69444 assertions, 0 failures, 0 errors, 1 skips
Line coverage:   54054 / 54515 (99.15%)
Branch coverage:  7704 /  9344 (82.44%)
Method coverage:  9649 / 10132 (95.23%)
```

This run wrote `coverage/.last_run.json` (99.15 / 82.44 / 95.23), which is the evidence that the
`maximum_drop` guards on line and branch were evaluated against the retained 2026-09-03 baseline and
passed, not merely that the minimums did.

The two tests the previous session reported as full-run-only failures, `AcmeRootsTest` and
`BasePalmSurfaceSmokeTest`, did **not** fail in either run; no change was made on their account. The
single remaining skip is the pre-existing one at `test/integration/oidc_rp_browser_flow_test.rb`,
blocked on issue #846.

### Movement

| Metric | 2026-09-03 baseline (`.last_run.json`) | 12:33 run at `79d45d095` | This session            |
| ------ | -------------------------------------- | ------------------------ | ----------------------- |
| Line   | 99.11                                  | 99.15                    | 99.15 (54054 / 54515)   |
| Branch | 82.38                                  | 82.35                    | **82.44** (7704 / 9344) |
| Method | 94.73                                  | 95.23                    | 95.23                   |

Line coverage did not move: the 18 tests added here mostly cover branches through lines that other
tests already executed. Branch coverage moved 82.35 -> 82.44, a gain of 31 branches.

### Why line coverage was not pushed further

The 461 uncovered lines sit one or two per file across 255 files, and the 1641 uncovered branches
sit roughly one per line across 515 files -- `app/controllers/concerns/authentication_base.rb` alone
holds 84 of them on 84 distinct lines. There is no dense target left. Reaching a materially higher
number is on the order of 150-200 further tests, most of them controller tests needing an
authenticated session per surface, which is the same conclusion
`evidence/2026-09-03-rails-line-coverage-raise.md` and
`evidence/2026-09-03-dead-code-removal-coverage.md` reached independently. No line here was covered
by deleting code, by asserting on a mock instead of behaviour, or by calling a method purely to
reach it.

## Tests added

18, in two groups. Each was checked against a deliberately broken implementation rather than assumed
to bite; the mutation and the resulting failure count are given.

| Group                                                                                                                                                                                                                                   | Tests | Mutation check                                                                                                                                  |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `health_revision_contract_test` -- absent/wildcard/browser/unknown `Accept`, q=0, HEAD parity, `X-Robots-Tag` on JSON and its absence on 406, `warn` on the wire, warn+fail precedence, the 503 text aggregate, the missing-probe guard | 10    | removing the empty-`Accept` branch: 1 failure; removing the probe guard and the aggregate's `http_status`: 2; inverting fail/warn precedence: 1 |
| `AuthenticationBaseActorCurrentResourceTest` -- the actor-snapshot guard chain (actor_type, `Unauthenticated` singleton, blank subject, `resource_class`, actor_id agreement, plus both accepting paths)                                | 8     | removing the four guards: 5 of 8 fail                                                                                                           |

## Assessment

PASS, with one check unrun. The branch is green, both coverage gates hold, and the scanners that
could run are clean. The substantive work was not the update -- four gems and one JS package moved,
none across a major -- but the nine red tests, which were the unfinished half of three changes
already committed to this branch, and the one dead constant the new negotiation concern carried.

The JavaScript dependency tree is unscanned, and this record says so rather than implying coverage
it does not have.

## Limitations

- `pnpm audit` did not run (registry outage, above). `bundler-audit` covers only the Ruby side.
- `database_consistency` remains unrunnable under Rails 8.2.0.alpha, so its model-versus-column
  checks are still unavailable; no substitute was run this session.
- The audit is scanners plus targeted reading, not an exhaustive review.
- `origin/feature` has diverged (8 remote commits against 4 local) and was deliberately not merged;
  only `origin/develop`, which had nothing new, was pulled.
