# Receiving Handoff Status (2026-11-06)

## Purpose and repository state

This note supports receiving-side work on the dirty `feature` branch for the identity and browser-flow changes. The objective is to resume on a VM that runs Rails directly, while keeping the current Dev Container/Compose setup intact.

- Branch: `feature`
- `git rev-parse HEAD`: `f56c805bc3dfbf5d22fb6eb27d0b4490eedf05ec`
- Worktree at 2026-11-07 00:29 UTC: 120 modified tracked paths and 56 untracked file paths (176 candidates); nothing is staged. `git status --short` collapses nested untracked directories and shows 51 untracked entries. Results below are not a clean-commit baseline. Owner commits and pushes.
- No changes were made to `.devcontainer/`, `compose.yaml`, `config/database.yml`, or `lib/local_environment.rb`.

## Conflicting files

The receiving-side worktree also has uncommitted edits in `README.md`, `compose.yaml`,
`config/database.yml`, `lib/umaxica/test_environment/database_safety.rb`,
`.github/workflows/ci.yml`, and `adr/pgmem-test-database-backend.md`. In our work, only `README.md`
overlaps: the change is already committed in `f56c805` and is `+10/-11` relative to `b30345216`.
It reformats two existing README passages and updates the WebAuthn RP ID/origin configuration
guidance, replacing the old trusted-origin example with per-surface APP/ORG RP ID and exact-origin
variables and encrypted-credentials fallback. The other five files in the receiving-side list were
not changed by our work. The receiving-side changes remain separate and must be reviewed together before
the owner commits them.

## Development DB

There is no hand-carried development data that must be preserved. The receiving environment may
rebuild its development database from `bin/setup` and `db:seed`.

## Work areas and next steps

| Work area | Current progress | Next step |
| --- | --- | --- |
| `specs/op-mediated-step-up/` | H-3 model repairs and Avatar RP test setup passed. Unit 6b and 7 remain open; O-9 is not connected. ORG contact registration remains fail-closed pending the accepted RP migration work. | Resume unit 6b after handoff; the current O-9 owner contract and unresolved failure families are recorded in the H-2 report. |
| `specs/browser-flow-state-cookies/` | Accepted inventory and I-1 server-record design updated; Work order 2 test-first work has begun. | Keep implementation frozen until handoff; then continue from Work order 2 and its intentionally failing tests. |
| H-2 suite classification | `evidence/2026-11-06-handoff-h2-1714-6K2Q.md` contains the 17:14 full-run per-file table for 323 incidents across 122 test files. It separates six intentional Work order 2 failures, two post-run-fixed regressions, 77 unchanged exact October-baseline IDs, 41 additional failures reproduced at clean incoming HEAD, and the remaining known cause families. | The no-unknown classification criterion is complete; the suite remains red at the 17:14 snapshot. The two exact-baseline ORG verification incidents remain category (b). No full rerun was made after 17:14. |
| H-4/H-5 | The 29 `two.md` WU rows, 51 AC IDs, `five.md` C0–C15 sections, and each active spec's handoff state are recorded below. Open items are not represented as completed; retired/superseded items and next owners are named. | Continue only the open WUs/ACs after handoff, from their owning spec or backlog. The four ignored work logs are snapshotted under the tracked archive. |
| H-6 frontend | `bun run check` passed; `bun run test` passed (details below). The Avatar status `NOT NULL` migration was applied locally and its dump regenerated from development. | Owner reviews and commits the prepared worktree; VM performs H-1 setup and records its own evidence. |
| ORG MFA reset entry link | Implemented with ORG-specific English/Japanese copy and RP-session request coverage; the request test passed. | No implementation work remains for this item. |
| Selector | ORG now has an RP-local selection screen; APP/ORG selector and two-connection HTTP concurrency tests pass. Single-candidate auto-selection follows the accepted ADR. | Include the latest full-suite selector failures in H-2; preserve `/switcher` as the only post-login switch route. |

Owner decisions already reflected in current documents include the saved O-9 browser-confirmation round trip, Auth as passkey/social write owner, RP session as selector source of truth, fail-closed O-12 contact registration, and the accepted browser-flow I-1 design. There is no unresolved owner decision required for the H-6 frontend edits. Future decisions raised by active specs must be presented by the owning work before implementation.

## H-4 closure matrix

The source work units and AC definitions are preserved in the archived `two.md` snapshot. The
tracked continuation ledger is [`2026-11-07-two-work-unit-handoff-residuals.md`](backlog/2026-11-07-two-work-unit-handoff-residuals.md).
“Done” below refers to the specific design or evidence artifact named; it does not imply that an
entire feature or the full suite passed.

### two.md Work Units

| Item | Status at handoff | Evidence / next step |
|---|---|---|
| WU-0 | Done and verified | Baseline inventory: `plans/2026-10-28-baseline-failing-tests.md`; current comparison: H-2 evidence below. |
| WU-0R | Open | Fresh VM reference-data construction remains unverified; use `bin/setup` and `db:seed`, then record the fixture/reference source. |
| WU-P0 | Done as owner-approved design; implementation unverified | Owner decision in `zero.md`; remaining Experience decisions are in `plans/backlog/2026-11-07-experience-consent-affinity-redesign.md`. |
| WU-1 | Open | Realm and audience boundary still needs current public-entry verification; see the residual ledger. |
| WU-2 | Retired by D-51 | No temporary old API repair; AC-20 is retired. |
| WU-3 | Open | Atomic COM removal has not been closed with current route/HTTP evidence. |
| WU-4 | Open | Shared COM consumers, health and eager-load closure remain. |
| WU-5 | Open; destructive work not authorized here | Database removal still needs the separate B-5 approval and recovery plan. |
| WU-6 | Open | Boot, HTTP, important-test and failure-ID closure remains. |
| WU-7 | Superseded | Replaced by the three-unit Experience/Consent/Affinity redesign backlog. |
| WU-8 | Retired | Key-separation-only unit was withdrawn. |
| WU-A1 | Open | Current sign-in classification/stop checks need reconciliation with accepted specs. |
| WU-A2 | Open | Sign-up transition, refusal and cancellation acceptance remains. |
| WU-A3 | Open | D-53 replacement remains separate from the Base selector; selector continuation is tracked in its backlog. |
| WU-A4 | Open | Cross-database writer/receipt and consume order remain incomplete. |
| WU-A5 | Open | Passkey slot, ORG external ID, audit, delivery and display acceptance remains. |
| WU-A6 | Open | ORG Normal/Standby scope and refusal coverage remain. |
| WU-A7 | Open | Withdrawal/recovery acceptance remains in `plans/backlog/2026-11-06-withdrawal-and-recovery-entry-gaps.md`. |
| WU-A8 | Open | Base canonical identity resolution remains an explicit boundary question in the existing RP backlog. |
| WU-A9 | Open | Visa/result and social restart behavior remains; O-9 is not connected. |
| WU-A10 | Open | Credential-version writers and root revalidation need a complete lock-ordered inventory. |
| WU-A11 | Open | Non-Base RP Jump work remains deferred in `plans/backlog/2026-10-16-jump-rp-routes-and-continuation-redesign.md`. |
| WU-A12 | Open | Continuation simplification and cross-RP rollout remain deferred. |
| WU-A13 | Open | Age-check and release-condition inventory remains. |
| WU-A14 | Open | Remaining boundaries, translations and attributes require per-file review. |
| WU-9 | Superseded | The old `two.md` Preference cutover is replaced by `five.md`'s Experience/Consent/Affinity redesign. Continue from `plans/backlog/2026-11-07-experience-consent-affinity-redesign.md`; O-9's separate Visa connection remains open under the step-up spec. |
| WU-X1 | Open | Route/settings/translation cleanup remains after applicable units. |
| WU-X2 | Open | BL-14/BL-20 and not-run acceptance inventory remains. |
| WU-E | Open; deferred | Edge/Jump/Away/xt environment and acceptance were not established here. |

### two.md acceptance IDs

AC-20 is retired by D-51. The other 50 acceptance IDs remain open because their whole owning unit
has not been verified; named focused tests prove only their individual behavior. For each ID below,
the accepted definition is in archived `two-design-work-log.md` §7.2, the owning residual and next
step are in the linked backlog, and the latest failing-test evidence is in the H-2 evidence file.

| AC | Owner WU | Status | Evidence / next step |
|---|---|---|---|
| AC-1 | WU-3 | Open | Residual ledger; verify every COM host through its public route. |
| AC-2 | WU-3 | Open | Residual ledger; verify retired Base COM routes. |
| AC-3 | WU-1, WU-3 | Open | Residual ledger; compare APP/ORG route inventories around the atomic removal. |
| AC-4 | WU-1, WU-3 | Open | Residual ledger; verify accepted/rejected realm and audience boundaries. |
| AC-5 | WU-3 | Open | Residual ledger; verify anonymous Base COM behavior. |
| AC-6 | WU-3 | Open | Residual ledger; verify database isolation at the public boundary. |
| AC-7 | WU-3, WU-4 | Open | Residual ledger; verify COM publishing/document surfaces. |
| AC-8 | WU-4 | Open | Residual ledger; verify health dependencies after consumer removal. |
| AC-9 | WU-4 | Open | Residual ledger; verify eager load and shared service entry points. |
| AC-10 | WU-5 | Open | Residual ledger; await destructive-change approval and then verify all registries. |
| AC-11 | WU-0, WU-3–6 | Open | The 17:14 H-2 table is complete with no unknown classifications, but the full suite remains red and has not been rerun after the later fixes; finish the critical-set and owner-side full-run comparison. |
| AC-12 | WU-3–6 | Open | Residual ledger; complete COM runtime/credential cleanup and boot verification. |
| AC-35 | WU-3 | Open | Residual ledger; verify public browser and HTTP state behavior. |
| AC-20 | — | Retired by D-51 | No work; replaced by AC-20b. |
| AC-20b | WU-7, WU-9 | Open | Experience redesign backlog; implement only from its future accepted shape. |
| AC-21 | WU-7, WU-9 | Open | Experience redesign backlog; verify realm-specific credential handling. |
| AC-22 | WU-7, WU-9 | Open | Experience redesign backlog; verify display and consent ownership. |
| AC-23 | WU-7, WU-9, WU-E | Open | Experience redesign backlog; verify public behavior after implementation. |
| AC-24 | WU-7, WU-9 | Open | Experience redesign backlog; verify the sole writer and failure behavior. |
| AC-25 | WU-7, WU-9 | Open | Experience redesign backlog; verify lifetime boundaries. |
| AC-26 | WU-7, WU-9 | Open | Experience redesign backlog; verify reset/retention behavior. |
| AC-27 | WU-9 | Open | Experience redesign backlog; verify Visa integration after its prerequisites. |
| AC-28 | WU-7, WU-9 | Open | Experience redesign backlog; verify public state transitions. |
| AC-29 | WU-P0, WU-9 | Open | Experience redesign backlog; shape decision exists but runtime acceptance remains open. |
| AC-49 | WU-7, WU-9 | Open | Experience redesign backlog; verify account/browser boundary. |
| AC-30 | WU-7, WU-9 | Open | Experience redesign backlog; verify reset and stale credential handling. |
| AC-31 | WU-7, WU-9, WU-X2 | Open | Experience redesign backlog; complete route and not-run classification. |
| AC-32 | WU-7, WU-9 | Open | Experience redesign backlog; verify sign-out and independent state. |
| AC-33 | WU-9 | Open | Experience redesign backlog; verify all realm pairs. |
| AC-34 | WU-7, WU-9 | Open | Experience redesign backlog; verify failure isolation. |
| AC-36 | WU-7, WU-9 | Open | Experience redesign backlog; verify cookie output and attributes. |
| AC-37 | WU-7, WU-9 | Open | Experience redesign backlog; verify browser binding and consent. |
| AC-52 | WU-7, WU-9 | Open | Experience redesign backlog; implement and verify only after accepted shape review. |
| AC-38 | WU-A1 | Open | Residual ledger; reconcile sign-in classification and disabled-entry behavior. |
| AC-39 | WU-A1 | Open | Residual ledger; verify stop checks at each public entry. |
| AC-40 | WU-A2, WU-A3 | Open | Residual ledger; verify transitions, cancellation and replacement. |
| AC-41 | WU-A6 | Open | Residual ledger; verify ORG mode and operation scope. |
| AC-42 | WU-A5 | Open | Residual ledger; verify credential slot and ownership rules. |
| AC-43 | WU-A5 | Open | Residual ledger; verify audit and delivery outcomes. |
| AC-44 | WU-A4, WU-A5, WU-A2 | Open | Residual ledger; verify every commit boundary and injected failure. |
| AC-45 | WU-A8 | Open | Residual ledger; resolve and verify canonical actor binding. |
| AC-46 | WU-0, WU-A8 | Open | Residual ledger; verify the documented change boundary. |
| AC-47 | WU-A14, WU-A10, WU-X1, WU-X2 | Open | Residual ledger; identify each remaining not-run case and owner. |
| AC-48 | WU-A7 | Open | Withdrawal/recovery backlog; verify terminal state and access refusal. |
| AC-50 | WU-A2 | Open | Residual ledger; verify the sign-up public boundary. |
| AC-51 | WU-A2 | Open | Residual ledger; verify replay/cancellation behavior. |
| AC-53 | WU-A3, WU-A2 | Open | Selector-state backlog; verify first attach, replacement and rejected replay. |
| AC-54 | WU-A8, WU-9 | Open | Existing RP identity backlog; verify actor and operation authorization. |
| AC-55 | WU-A10 | Open | Residual ledger; verify captured credential version and root revalidation. |
| AC-56 | WU-A9 | Open | Residual ledger; verify social/OTP refusal and restart guidance. |
| AC-57 | WU-A3, WU-A4, WU-A7, WU-A8, WU-A13 | Open | Residual ledger; verify logout/revocation boundaries and release conditions. |

### five.md sections C0–C15

The C numbers are sections, not executable acceptance IDs. Their documentary disposition is:

| Section | Status | Evidence / next step |
|---|---|---|
| C0 | Done and verified as scope/authority statement | Archived `five-experience-consent-affinity-log.md` §C0. The design remains open. |
| C1 | Done and verified as current summary | Archived §C1; implementation is not implied. |
| C2 | Done and verified as terminology | Archived §C2. |
| C3 | Done and verified as constraints | Archived §C3; C5 conflicts remain explicit. |
| C4 | Done and verified as owner decisions | Archived §C4; decisions do not approve unresolved shapes. |
| C5 | Open | Continue from `plans/backlog/2026-11-07-experience-consent-affinity-redesign.md`; resolve each listed decision before shape or persistence changes. |
| C6 | Open | Naming map is a target only; implement after an accepted specification. |
| C7 | Open | Cookie names/counts/attributes are candidates, not an accepted storage contract. |
| C8 | Done and verified as disposition of Appendix T | Archived §C8; superseded text remains historical. |
| C9 | Partly done but not reverified; remaining work open | Archived §C9.1 records bounded UI/test slices as completed with historical results, not re-run for this handoff. §C9.2's persistence and ADR changes remain open; resume from the redesign backlog. |
| C10 | Done and verified as review disposition record | Archived §C10; underlying open design questions stay open. |
| C11 | Done and verified as review 3 disposition | Archived §C11. |
| C12 | Done and verified as review 4 disposition | Archived §C12. |
| C13 | Done and verified as review 5 disposition | Archived §C13. |
| C14 | Done and verified as review 6 disposition | Archived §C14. |
| C15 | Done and verified as final review disposition | Archived §C15; C5 decisions and implementation remain open. |

## H-5 specification handoff

| Owner document | Handoff status | Next step / owner decision status |
|---|---|---|
| `specs/op-mediated-step-up/` | Accepted; unit 6b and unit 7 remain open; O-9 is not connected. | Resume at unit 6b after the O-9 Visa round-trip contract in `contracts/o9-visa-roundtrip-design.md` and its accepted review. No pending decision is inferred beyond decisions explicitly listed by the spec. |
| `specs/browser-flow-state-cookies/` | Accepted; Work order 1 inventory and I-1 server-record design are complete. Work order 2 has test-first work in progress; its failure cases are intentional until implementation. D-12/AC-13 are included. | Continue Work order 2 after the handoff. Keep rejected GETs read-only and retain the fixed Base `/sign` restart guidance. |
| `plans/backlog/2026-11-07-experience-consent-affinity-redesign.md` | Open design backlog. | Resolve five.md C5 and obtain an accepted spec/data-shape review before implementation. |
| `plans/backlog/2026-11-06-selector-state-machine-connection.md` | Open; current Base one-selection-per-RP-session behavior remains outside the sign-in state machine. | Resume only if the owner schedules the connection; `/switcher` remains the post-selection route. |

No new owner decision was requested for the four receiving-side memo additions in this pass. Pending
decisions remain with their owning specs/backlogs rather than being inferred from this handoff.

## VM bootstrap commands

Run from a clean clone on the receiving VM after provisioning the repository's development/test credentials and local services:

```bash
git clone <owner-pushed-feature-branch-url> umaxica-apps-jit-global
cd umaxica-apps-jit-global
bundle install
bun install --frozen-lockfile
bin/setup --skip-server
PARALLEL_WORKERS=1 bin/rails test
bun run test
```

`bin/setup --skip-server` installs/prepares the app and calls the documented `db:prepare` setup path without starting `bin/dev`. Before running it, the VM must satisfy the `primary` hostname/database requirements above and have the non-container cache/storage endpoints configured. The URL placeholder must be replaced with the owner-pushed `feature` branch clone URL; no push has been performed from this workspace. These commands have not been verified on the receiving VM. The app's credentials and `.env` file are intentionally not listed or copied into this memo.

## Verification and known failures

| Command | Result | Classification / limitation |
| --- | --- | --- |
| `PARALLEL_WORKERS=1 bin/rails test test/models/required_attribute_not_null_contract_test.rb` | 596 runs / 2,538 assertions / 0 failures / 0 errors / 0 skips | Verified after adding `avatar_ownership_periods.avatar_ownership_status_id NOT NULL`. |
| `PARALLEL_WORKERS=1 bin/rails test test/models` | 5,752 runs / 40,011 assertions / 0 failures / 0 errors / 0 skips | Passed after the Avatar status migration; result is recorded in `zero.md`'s 2026-11-06 13:06 entry. |
| `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/selector_controller_test.rb test/controllers/base/org/selector_controller_test.rb test/concurrency/base_selector_single_write_http_test.rb` | 18 runs / 99 assertions / 0 failures / 0 errors / 0 skips | APP and ORG single-candidate behavior, multi-candidate selection, selected-session rejection, and two-connection race coverage. |
| `PARALLEL_WORKERS=1 bin/rails test test/controllers/base/app/avatar_ownership_transfers_controller_test.rb test/controllers/base/org/avatar_ownership_transfers_controller_test.rb` | 37 runs / 264 assertions / 0 failures / 0 errors / 0 skips | H-3 RP test setup repair, dirty worktree. |
| `PARALLEL_WORKERS=1 bin/rails test test/controllers/concerns/browser_rp_authentication_test.rb test/services/rp_request_authenticator_test.rb test/controllers/concerns/authenticated_response_cache_policy_test.rb test/security/invariants/actor_context_invariant_test.rb test/security/invariants/org_withdrawal_gate_invariant_test.rb test/security/invariants/withdrawal_gate_invariant_test.rb test/controllers/base/org/api/v0/avatar` | 90 runs / 261 assertions / 5 failures / 0 errors / 0 skips | After the 17:14 full run. The direct Browser RP/authenticator checks passed. Remaining focused failures are the pre-existing Actor context guard, RP/OP withdrawal-state propagation and stale-root-credential expectations; details are in `zero.md`. |
| `bin/rubocop app/controllers/concerns/avatar_authority_api_endpoint.rb app/controllers/concerns/browser_rp_authentication.rb app/services/rp_request_authenticator.rb test/security/invariants/actor_context_invariant_test.rb test/controllers/concerns/authenticated_response_cache_policy_test.rb test/controllers/concerns/browser_rp_authentication_test.rb test/security/invariants/org_withdrawal_gate_invariant_test.rb` | 7 files inspected; no offenses | Scoped to the post-17:14 authentication-boundary changes. |
| `bun run check` | Passed: format, oxlint, TypeScript checks, Knip, OpenAPI lint and bundle verification | One OpenAPI warning remains: unused `bearerToken` security scheme in `openapi/app.yml:97`; command exits successfully. |
| `bun run test` | 98 files / 1,077 tests / 0 failures | H-6 frontend change, dirty worktree. |
| `bin/rubocop` | 5,572 files inspected; 118 offenses reported | Not clean. Repo-wide RuboCop cleanup is deferred until after handoff. |
| Coverage (`COVERAGE=true PARALLEL_WORKERS=1 bin/rails test`) | Interrupted after 9,831 runs / 81,129 assertions / 165 failures / 37 errors / 0 skips; line 86.12%, branch 51.96%, method 78.34% | A separate public-method coverage run, stopped at the handoff freeze. It is incomplete, does not replace the 17:14 H-2 baseline, and must not be treated as the full-suite result. Resume coverage after handoff. |
| Focused ORG Avatar/selector batch | 45 runs / 325 assertions / 0 failures / 0 errors / 0 skips | Covers the RP avatar-selection model, ORG selector/switcher, Avatar ownership and presentation, Avatar API, and two-connection selector race. |
| Owner full run, `PARALLEL_WORKERS=1 bin/rails test` (17:14 UTC) | 16,922 runs / 146,848 assertions / 270 failures / 53 errors / 0 skips | Dirty-worktree snapshot used for H-2. Compared with the previous full run (16,922 / 146,729 / 282 / 60), 322 incidents repeat, 20 resolve, and one cache-header assertion is new; that assertion was corrected afterward and passed the focused batch. Compared with the owner morning run (16,898 / 146,156 / 313 / 104), 307 repeat, 110 resolve and 16 are new. The per-file table records 6 intentional cookie Work order 2 tests, 77 unchanged October-baseline matches, 41 additional incidents reproduced at clean incoming HEAD, and two post-run fixes. See `evidence/2026-11-06-handoff-h2-1714-6K2Q.md`; the suite remains red. |

The H-2 evidence table records all 122 failing test files, failure/error counts, exact baseline ID
counts and cause families. Of the 42 non-baseline incidents that were initially unattributed, a
detached clean worktree at incoming HEAD reproduced 41 with the same test IDs and result kinds;
these are classified as pre-existing at handoff. The remaining ORG verification return-target
incident was traced to RP-cell requests having no OP root session ID; the code now binds the target
to its authenticated local Base RP session, with same-session acceptance and cross-session refusal
coverage. H-2 classification has no unknown entries. The intentional Work order 2 tests remain
open until that accepted implementation work resumes.

## VM setup and container dependencies

The VM setup runs Rails natively and currently has a working PostgreSQL/Redis-style setup, but it does not have the Dev Container network aliases. The tracked configuration must remain unchanged.

| Container hostname / component | Current role | VM requirement / limitation |
| --- | --- | --- |
| `primary` | PostgreSQL writer and all test DBs. `lib/umaxica/test_environment/database_safety.rb` deliberately fixes `TEST_HOST = "primary"`; `config/database.yml` uses the same host. | Provide a local, disposable PostgreSQL endpoint resolvable as `primary` on port 5432, with the expected local `root` role/password and admin DB `db`. Keep test databases prefixed `test_`. A hosts/DNS alias to the VM's isolated local PostgreSQL is the expected approach; it has not yet been verified on the receiving VM. Never point it at shared or retained data. |
| `replica` | Development read replica on port 5432 inside Compose; host-published port 5433. | VM needs a compatible replica only for checks that exercise read routing. Test runs should use the documented primary-only selector behavior where appropriate; the replica databases in the current test setup are static copies. |
| `valkey` | Compatibility/diagnostic Valkey endpoint; canonical app traffic also uses `valkey-cache` and `valkey-kvs`. | Provide the configured cache/KVS services and required local URLs; there are no Compose DNS aliases on the VM. |
| `fakecloud` | S3-compatible development object-storage service on port 4566. | Only needed by object-storage flows; receiving VM must configure an equivalent local endpoint or skip no behavior test that depends on it. |
| `core-workers-vpc.internal` | Compose network alias pointing to the `core` app container for internal worker/service callbacks. | No VM equivalent is configured. Any check depending on that callback hostname needs an explicit VM-local hostname/route setup; not yet verified. |

`.env.container.devcontainer` variable names absent from `.env` (names only; no values): `DEVCONTAINER`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `PREFERENCE_COM_JWT_AUDIENCE`, `PREFERENCE_COM_JWT_ISSUER`, `PREFERENCE_COM_JWT_REVOKED_KIDS`, `PRIVATE_GUID_SERVICE_URL`, `PRIVATE_VISA_CORPORATE_URL`, `PRIVATE_VISA_SERVICE_URL`, `PRIVATE_VISA_STAFF_URL`, `RUBY_DEBUG_OPEN`, `WEB_CONCURRENCY`.

Container-bound tools and checks identified from the Dev Container definition and operations docs:

- `podman`/`podman-compose` for the local service stack and nested rootless Podman workspace target; the current shell has no `docker` or `podman` executable.
- The image/Dev Container CLI provisions GitHub CLI, `herdr`, Claude Code, Codex and Terraform features; the current host inspection found no `cloudflared` CLI. The container image also owns the pinned Ruby/Bundler/runtime toolchain and browser desktop setup, while Node/Bun are available in this workspace.
- `core-desktop` supplies Xvfb, x11vnc and noVNC at loopback port 6080; RFB 5900 is not published. Browser UI checks that require observing that desktop are container-bound.
- Optional remote access runs userspace Tailscale and an unprivileged `sshd` inside `core`; the `remote-access` Compose overlay and tailnet are not part of the receiving VM setup. The current host has a Tailscale client binary, but that does not provide the container's tailnet route or sshd arrangement.
- Public development URLs and external-origin/browser checks rely on the Cloudflare Tunnel connectors and Cloudflare Access. The receiving environment explicitly has no tunnel yet, so those checks are not established by local Rails page requests alone.
- The Tunnel ingress rules and Cloudflare Access application/policy list are available only in the
  Cloudflare administration UI. The owner will export and document those separately; this memo does
  not claim to inventory them.

## Measurements

The owner (Claude Code) will fill this section in the commit immediately before push, using the
owner-side full-suite run:

| Measurement | Owner entry |
| --- | --- |
| `git rev-parse HEAD` |  |
| Uncommitted changes present during the run |  |
| Exact test command |  |
| Full test result row (`runs / assertions / failures / errors / skips`) |  |
| Failing test IDs/names/files |  |
| CPU | AMD Ryzen 9 7950X (32 threads) |
| PostgreSQL | 18.6 |
| `PARALLEL_WORKERS` |  |

## Migration and structure-dump handoff

Range checked: `b30345216886c98af1f04cbd434f067f12decf01..f56c805bc3dfbf5d22fb6eb27d0b4490eedf05ec`.

- The `b303452..f56c805` range added 107 migration files and modified 3 existing files. Six more
  owner-approved, uncommitted RP Base Org migrations are listed below, for 113 added migrations in
  the current worktree relative to `b303452`.
- All 26 `db/*_structure.sql` files were rebuilt/compared against fresh migrations in uniquely named disposable databases. Result: `checked=26`, `failed=0`. Comparison normalized only generated role-name suffixes derived from the scratch database name. The scratch databases were dropped after each check.
- This process exposed and repaired the APP Zenith dump's `client_apple_notification_events` table and sequence persistence mismatch; current dump now matches the fresh migration result under the same normalization.

The handoff-added Avatar migrations are `20261106130500_add_avatar_ownership_status_not_null_check.rb` and `20261106130501_make_avatar_ownership_status_not_null.rb`. Before either local migration ran, read-only queries found zero NULL `avatar_ownership_status_id` rows in both `development_avatar_db` and `test_avatar_db`; both migrations then applied successfully in both environments without changing rows. `db/avatar_structure.sql` was regenerated from the development database and records the column as `NOT NULL`. A test-database dump differed in eight pre-existing foreign-key `NOT VALID` markers; the tracked structure file was kept from the development migration state, and that unrelated development/test constraint-state discrepancy remains to be reconciled during H-6's fresh migration check.

**Release step:** before deploying the NOT NULL migration to production, confirm that the production Avatar database has zero NULL values in `avatar_ownership_periods.avatar_ownership_status_id`. The migration also checks and raises a named, explicit error before validating the constraint if a NULL row exists. No production query or migration was run from this workspace.

The complete added-file list follows:
- `db/app_principals_migrate/20261101174445_add_preferences_changed_to_client_contact_audit_events.rb`
- `db/app_principals_migrate/20261101174545_validate_client_contact_audit_event_constraint.rb`
- `db/app_principals_migrate/20261101175512_add_preference_change_actor_check_to_client_contact_audit_outboxes.rb`
- `db/app_principals_migrate/20261101175522_validate_preference_change_actor_check_on_client_contact_audit_outboxes.rb`
- `db/app_principals_migrate/20261105031747_create_client_totp_registration_receipts.rb`
- `db/app_principals_migrate/20261105031751_add_registration_operation_index_to_client_passkey_audit_outboxes.rb`
- `db/app_principals_migrate/20261105035213_create_client_social_link_source_receipts.rb`
- `db/app_principals_migrate/20261105044709_validate_client_social_link_source_receipt_foreign_key.rb`
- `db/app_zenith_migrate/20261102064741_create_client_registration_completions.rb`
- `db/app_zenith_migrate/20261102064911_seed_client_registration_completion_methods.rb`
- `db/app_zenith_migrate/20261102065335_validate_client_registration_completion_constraints.rb`
- `db/chronicle_migrate/20261103183220_insert_security_chronicle_retention_policy.rb`
- `db/op_base_app_migrate/20261101031705_add_status_to_client_auth_admission_bindings.rb`
- `db/op_base_app_migrate/20261101031715_validate_client_auth_admission_binding_status_constraint.rb`
- `db/op_base_app_migrate/20261101031805_add_active_status_indexes_to_client_auth_admission_bindings.rb`
- `db/op_base_app_migrate/20261101031816_remove_timestamp_admission_indexes_from_client_auth_admission_bindings.rb`
- `db/op_base_app_migrate/20261101031900_validate_client_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_app_migrate/20261101034328_add_status_to_client_auth_ceremony_sessions.rb`
- `db/op_base_app_migrate/20261101034333_backfill_client_auth_ceremony_session_statuses.rb`
- `db/op_base_app_migrate/20261101034338_enforce_client_auth_ceremony_session_statuses.rb`
- `db/op_base_app_migrate/20261101034339_validate_client_auth_ceremony_session_statuses.rb`
- `db/op_base_app_migrate/20261101034340_switch_client_auth_ceremony_session_indexes.rb`
- `db/op_base_app_migrate/20261101041000_add_state_reference_to_client_oidc_authorization_transactions.rb`
- `db/op_base_app_migrate/20261101041001_backfill_client_oidc_authorization_transaction_statuses.rb`
- `db/op_base_app_migrate/20261101041002_enforce_client_oidc_authorization_transaction_statuses.rb`
- `db/op_base_app_migrate/20261101041003_validate_client_oidc_authorization_transaction_statuses.rb`
- `db/op_base_app_migrate/20261101041004_cut_over_client_oidc_authorization_transaction_status.rb`
- `db/op_base_app_migrate/20261101073137_normalize_client_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_app_migrate/20261101073138_validate_normalized_client_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_app_migrate/20261101073139_remove_legacy_client_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_app_migrate/20261103112921_create_client_step_up_persistence.rb`
- `db/op_base_app_migrate/20261103112925_seed_client_step_up_reference_rows.rb`
- `db/op_base_app_migrate/20261103183200_constrain_client_step_up_audit_codes.rb`
- `db/op_base_app_migrate/20261103183201_validate_client_step_up_audit_codes.rb`
- `db/op_base_app_migrate/20261104101051_create_client_sensitive_admissions.rb`
- `db/op_base_app_migrate/20261104101408_validate_client_sensitive_admission_foreign_keys.rb`
- `db/op_base_app_migrate/20261104101933_create_client_sensitive_admission_accounting.rb`
- `db/op_base_app_migrate/20261104101950_validate_client_sensitive_admission_accounting_foreign_keys.rb`
- `db/op_base_app_migrate/20261104102755_create_client_sensitive_admission_sessions.rb`
- `db/op_base_app_migrate/20261104102812_validate_client_sensitive_admission_session_foreign_key.rb`
- `db/op_base_app_migrate/20261105035150_create_client_visa_sensitive_admissions.rb`
- `db/op_base_app_migrate/20261105044804_validate_client_visa_sensitive_admission_foreign_keys.rb`
- `db/op_base_app_migrate/20261105050223_create_client_visa_social_link_admissions.rb`
- `db/op_base_app_migrate/20261105050239_add_browser_confirmed_to_client_visa_sensitive_admissions.rb`
- `db/op_base_app_migrate/20261105050417_validate_client_visa_social_link_admission_foreign_keys.rb`
- `db/op_base_app_migrate/20261105050418_validate_client_visa_sensitive_admission_checks.rb`
- `db/op_base_org_migrate/20261101031710_add_status_to_operator_auth_admission_bindings.rb`
- `db/op_base_org_migrate/20261101031720_validate_operator_auth_admission_binding_status_constraint.rb`
- `db/op_base_org_migrate/20261101031811_add_active_status_indexes_to_operator_auth_admission_bindings.rb`
- `db/op_base_org_migrate/20261101031821_remove_timestamp_admission_indexes_from_operator_auth_admission_bindings.rb`
- `db/op_base_org_migrate/20261101031900_validate_operator_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_org_migrate/20261101034343_add_status_to_operator_auth_ceremony_sessions.rb`
- `db/op_base_org_migrate/20261101034348_backfill_operator_auth_ceremony_session_statuses.rb`
- `db/op_base_org_migrate/20261101034353_enforce_operator_auth_ceremony_session_statuses.rb`
- `db/op_base_org_migrate/20261101034354_validate_operator_auth_ceremony_session_statuses.rb`
- `db/op_base_org_migrate/20261101034355_switch_operator_auth_ceremony_session_indexes.rb`
- `db/op_base_org_migrate/20261101041003_add_state_reference_to_operator_oidc_authorization_transactions.rb`
- `db/op_base_org_migrate/20261101041004_backfill_operator_oidc_authorization_transaction_statuses.rb`
- `db/op_base_org_migrate/20261101041005_enforce_operator_oidc_authorization_transaction_statuses.rb`
- `db/op_base_org_migrate/20261101041006_validate_operator_oidc_authorization_transaction_statuses.rb`
- `db/op_base_org_migrate/20261101041007_cut_over_operator_oidc_authorization_transaction_status.rb`
- `db/op_base_org_migrate/20261101073142_normalize_operator_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_org_migrate/20261101073143_validate_normalized_operator_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_org_migrate/20261101073144_remove_legacy_operator_auth_admission_binding_status_foreign_key.rb`
- `db/op_base_org_migrate/20261103112929_create_operator_step_up_persistence.rb`
- `db/op_base_org_migrate/20261103112933_seed_operator_step_up_reference_rows.rb`
- `db/op_base_org_migrate/20261103183204_constrain_operator_step_up_audit_codes.rb`
- `db/op_base_org_migrate/20261103183205_validate_operator_step_up_audit_codes.rb`
- `db/op_base_org_migrate/20261104101057_create_operator_sensitive_admissions.rb`
- `db/op_base_org_migrate/20261104101417_validate_operator_sensitive_admission_foreign_keys.rb`
- `db/op_base_org_migrate/20261104101941_create_operator_sensitive_admission_accounting.rb`
- `db/op_base_org_migrate/20261104101959_validate_operator_sensitive_admission_accounting_foreign_keys.rb`
- `db/op_base_org_migrate/20261104102804_create_operator_sensitive_admission_sessions.rb`
- `db/op_base_org_migrate/20261104102819_validate_operator_sensitive_admission_session_foreign_key.rb`
- `db/op_base_org_migrate/20261105035154_create_operator_visa_sensitive_admissions.rb`
- `db/op_base_org_migrate/20261105044800_validate_operator_visa_sensitive_admission_foreign_keys.rb`
- `db/op_base_org_migrate/20261105050239_add_browser_confirmed_to_operator_visa_sensitive_admissions.rb`
- `db/op_base_org_migrate/20261105050417_validate_operator_visa_sensitive_admission_checks.rb`
- `db/org_principals_migrate/20261105031755_add_registration_operation_index_to_operator_passkey_audit_outboxes.rb`
- `db/org_settings_migrate/20261101025006_validate_org_preference_status_foreign_key.rb`
- `db/org_zenith_migrate/20261104110000_create_org_iam_operation_outcomes.rb`
- `db/rp_base_app_migrate/20261103112937_create_rp_base_app_step_up_persistence.rb`
- `db/rp_base_app_migrate/20261103112941_seed_rp_base_app_step_up_reference_rows.rb`
- `db/rp_base_app_migrate/20261103183208_constrain_rp_base_app_step_up_audit_codes.rb`
- `db/rp_base_app_migrate/20261103183209_validate_rp_base_app_step_up_audit_codes.rb`
- `db/rp_base_app_migrate/20261105063737_create_rp_base_app_session_selections.rb`
- `db/rp_base_app_migrate/20261105064233_add_rp_base_app_session_selection_fields.rb`
- `db/rp_base_app_migrate/20261105065207_complete_rp_base_app_session_selection_shape.rb`
- `db/rp_base_app_migrate/20261105065508_add_rp_base_app_session_selection_foreign_key.rb`
- `db/rp_base_app_migrate/20261105065512_preserve_empty_rp_base_app_session_selection_migration.rb`
- `db/rp_base_app_migrate/20261105065912_add_rp_base_app_session_selection_constraints.rb`
- `db/rp_base_app_migrate/20261105065916_validate_rp_base_app_session_selection_constraints.rb`
- `db/rp_base_app_migrate/20261105065920_enforce_rp_base_app_session_selection_not_null.rb`
- `db/rp_base_app_migrate/20261106005640_add_rp_base_app_step_up_generation_check.rb`
- `db/rp_base_app_migrate/20261106005739_validate_rp_base_app_step_up_generation_check.rb`
- `db/rp_base_org_migrate/20261103112945_create_rp_base_org_step_up_persistence.rb`
- `db/rp_base_org_migrate/20261103112949_seed_rp_base_org_step_up_reference_rows.rb`
- `db/rp_base_org_migrate/20261103183212_constrain_rp_base_org_step_up_audit_codes.rb`
- `db/rp_base_org_migrate/20261103183213_validate_rp_base_org_step_up_audit_codes.rb`
- `db/rp_base_org_migrate/20261106005646_add_rp_base_org_step_up_generation_check.rb`
- `db/rp_base_org_migrate/20261106005748_validate_rp_base_org_step_up_generation_check.rb`
- `db/rp_base_org_migrate/20261106064341_create_rp_base_org_session_selections.rb`
- `db/rp_base_org_migrate/20261106064603_complete_rp_base_org_session_selection_shape.rb`
- `db/rp_base_org_migrate/20261106064607_add_rp_base_org_session_selection_constraints.rb`
- `db/rp_base_org_migrate/20261106064611_add_rp_base_org_session_selection_foreign_key.rb`
- `db/rp_base_org_migrate/20261106064615_validate_rp_base_org_session_selection_constraints.rb`
- `db/rp_base_org_migrate/20261106064619_enforce_rp_base_org_session_selection_not_null.rb`

The owner-approved ORG Avatar selection record adds six uncommitted RP Base Org migrations after
the range above. They are included in the current worktree and must be reviewed with the schema
change:

- `db/rp_base_org_migrate/20261106143155_create_rp_base_org_session_avatar_selections.rb`
- `db/rp_base_org_migrate/20261106143159_complete_rp_base_org_session_avatar_selection_shape.rb`
- `db/rp_base_org_migrate/20261106143203_add_rp_base_org_session_avatar_selection_constraints.rb`
- `db/rp_base_org_migrate/20261106143207_add_rp_base_org_session_avatar_selection_foreign_key.rb`
- `db/rp_base_org_migrate/20261106143211_validate_rp_base_org_session_avatar_selection_constraints.rb`
- `db/rp_base_org_migrate/20261106143215_enforce_rp_base_org_session_avatar_selection_not_null.rb`

`db/rp_base_org_structure.sql` was regenerated from the development database. A disposable fresh
RP Base Org migration replay created the same new table, NOT NULL columns, 21-character check,
unique session index, parent foreign key and cascade behavior. The six new migration objects match
between the development and replay dumps. The complete normalized dumps are not identical: they
differ only in PostgreSQL's rendered casts for seven pre-existing RP step-up CHECK expressions
(`chk_rp_step_up_attempt_failure_codes`, `chk_rp_step_up_audit_attempt_outcome`,
`chk_rp_step_up_audit_event`, `chk_rp_step_up_audit_payload`,
`chk_rp_step_up_audit_payload_codes`, `chk_rp_step_up_audit_reason_codes`, and
`chk_rp_step_up_transition_reason`). These constraints and their structure-file lines are unchanged
from HEAD; the disposable replay database was dropped. This is a scoped match for the new objects,
not a claim that the complete dumps are byte-identical.

Modified migrations in the same range:

- `db/app_principals_migrate/20261031220002_cut_over_client_preference_shape.rb`
- `db/app_settings_migrate/20261031220000_cut_over_app_preference_shape.rb`
- `db/org_principals_migrate/20261031220003_cut_over_operator_preference_shape.rb`

## Untracked files and root working logs

The owner will commit/push. The following untracked files are present for review; retain the implementation, migration, test, evidence, archive, plan and backlog files that belong to this handoff. No secret values were added by this handoff note:

- `app/models/rp_base_org_session_avatar_selection.rb` — retain; model for the approved ORG RP Avatar selection table.
- `db/avatars_migrate/20261106130500_add_avatar_ownership_status_not_null_check.rb` and `db/avatars_migrate/20261106130501_make_avatar_ownership_status_not_null.rb` — retain; owner-approved Avatar status constraint migrations.
- The six `db/rp_base_org_migrate/20261106143155_*` through `20261106143215_*` migrations — retain; full paths are listed in the migration section above.
- `evidence/2026-11-06-handoff-h2-org-avatar-7C2M.md` and `evidence/2026-11-06-rails-test-groups-abc-7Q4M.md` — retain as test evidence.
- `evidence/2026-11-06-handoff-h2-1714-6K2Q.md` — retain; complete 17:14 H-2 per-file classification.
- `plans/2026-11-07-handoff-status.md`, `plans/2026-11-07-handoff-acceptance-checklist.md`, and `plans/2026-11-07-machine-handoff-closure.md` — retain as handoff status, acceptance checklist, and active handoff plan.
- `plans/archive/0003-authentication-handoff-work-logs/README.md` and its four archived work-log snapshots — retain as the authorized transferable archive copies.
- `plans/backlog/2026-11-06-social-link-step-up-hands-on-review.md`, `plans/backlog/2026-11-06-withdrawal-and-recovery-entry-gaps.md`, `plans/backlog/2026-11-07-experience-consent-affinity-redesign.md`, `plans/backlog/2026-11-07-react-compiler-optimization-skips.md`, and `plans/backlog/2026-11-07-two-work-unit-handoff-residuals.md` — retain as open or explicitly deferred tasks.
- `src/pages/base/org/selectors/show.tsx` — retain; RP-local ORG selector page.
- `test/concurrency/base_selector_single_write_http_test.rb` — retain; separate-connection selector race coverage.
- `test/controllers/base/org/api/v0/avatar/dashboard_identities_controller_test.rb` and `test/controllers/base/org/identity_entry_mfa_reset_link_test.rb` — retain; ORG Avatar presentation and MFA reset entry coverage.
- `test/controllers/visa/sign_in_restart_guidance_test.rb` — retain for the active safe-termination spec.
- `test/models/rp_base_org_session_avatar_selection_test.rb` and `test/models/rp_base_session_selection_validation_test.rb` — retain; ORG Avatar persistence and APP/ORG selection length contracts.
- `test/controllers/base/org/avatar_selected_delete_authority_test.rb` and `test/operations/identity_social_ceremony_transaction_purger_behavior_test.rb` — retain as later coverage-task additions, not H-2 evidence. Focused run: 3 runs / 18 assertions / 1 failure / 0 errors. The social-purger cases pass. The Avatar deletion request reaches its no-mutation assertions, but returns HTTP 302 to `https://www.umaxica.org/` where the test and `docs/architecture/avatar-authority-contract-proposal.md` expect 403. No application or existing test was changed; the mismatch remains recorded for the coverage task. Keep these files out of the immediate handoff commit until the deferred coverage task is resolved; do not delete them as generated files.

`zero.md`, `two.md`, `five.md`, and `six.md` remain as ignored local working logs through handoff closure. They are not part of a push. The candidate scan covered changed and untracked files plus these four logs. Gitleaks reported 17 generic API-key pattern matches; manual review found only short dummy values in test authorization headers and abbreviated commit IDs, not live credentials. No private-key marker, JWT, provider credential, personal email address, or phone number was found. Transferable snapshots are included in the commit at [plans/archive/0003-authentication-handoff-work-logs/README.md](archive/0003-authentication-handoff-work-logs/README.md). The originals remain available locally until handoff closure; lasting requirements remain in their owning specs, ADRs, plans, and docs.

No untracked file has been deleted. The prohibited environment/configuration paths remain unchanged.

## Earlier commit-candidate audit (2026-11-06 20:45 UTC)

The current worktree has 120 modified tracked files and 34 untracked files (154 candidate files); no
file is staged. `git status --short` shows 30 untracked entries because it collapses nested
directories. The earlier 146-file count is stale. A fresh Gitleaks scan reported 15 generic
`generic-api-key` matches: 13 fixed test-fixture/idempotency strings and two archived abbreviated
revision identifiers. Manual review found no live credential. No private-key marker, JWT, provider
secret, non-placeholder personal contact, `.env` file, scratch log, dump or generated artifact is a
candidate. `git diff --check` passes. The two later coverage tests above are intentional but outside
this handoff scope; one failed and one remains unverified, so they are explicitly deferred rather
than silently included as handoff-complete work.

## Handoff closeout and current candidate audit (2026-11-06 22:00 UTC)

The requested closeout uses the owner's 17:14 full-suite snapshot. H-2 is complete as an inventory:
`evidence/2026-11-06-handoff-h2-1714-6K2Q.md` lists all 323 failures/errors across 122 test files,
with a cause family and next step for every incident. The suite was not rerun after the snapshot;
the 17:14 result remains 16,922 runs / 146,848 assertions / 270 failures / 53 errors / 0 skips.
The post-snapshot changes and still-failing withdrawal/RP boundary cases are summarized in the
latest `zero.md` entry. No more failure repair was started after the withdrawal work reached its
handoff stopping point.

H-4/H-5 are closed as handoff inventories, not as claims that open work is implemented. The
reconciled matrices cover all 29 `two.md` Work Units, all 51 acceptance IDs (AC-20 retired; the
other 50 remain open against their owning evidence), `five.md` sections C0-C15, and the open-spec
handoff. Step-up unit 6b/7 and O-9 connection, browser-flow cookie Work order 2, and the
Experience/Consent/Affinity redesign remain assigned to their owning specs/backlogs.

At 22:00 UTC, HEAD was `f56c805bc3dfbf5d22fb6eb27d0b4490eedf05ec` on `feature`; no files were
staged. The current candidate set is 120 changed tracked paths plus 43 untracked paths (163 total).
The security scan covered those candidates and the four ignored root work logs (167 files scanned).
Gitleaks reported 17 `generic-api-key` matches: 13 fixed idempotency test values and four
abbreviated revision/evidence identifiers (two identifiers repeated in `zero.md` and its archive
copy). Manual review found no live secret, private key, JWT, provider credential, or personal contact
data; email-like values in candidates use the reserved `example.com` test domain. No `.env` file,
temporary log, dump, or generated artifact is among the commit candidates. All paths have an
implementation, migration, test, evidence, handoff, archive, or backlog purpose.

Eleven untracked tests belong to the resumed public-method coverage task and are outside the
immediate handoff commit. Keep them in the worktree for that task; do not treat them as generated
debris or include them in this handoff set before the coverage task is completed:

- `test/adapters/mcp_tool_public_call_test.rb`
- `test/adapters/visa_sensitive_admission_client_confirmation_test.rb`
- `test/controllers/base/org/avatar_selected_delete_authority_test.rb`
- `test/jobs/op_identity_event_delivery_job_authority_test.rb`
- `test/models/client_totp_credential_slot_status_policy_test.rb`
- `test/models/operator_contact_registration_finalization_evidence_test.rb`
- `test/operations/identity_social_ceremony_transaction_purger_behavior_test.rb`
- `test/operations/visa_sensitive_admission_browser_confirmer_authority_test.rb`
- `test/services/authentication_token_service_expired_token_facade_test.rb`
- `test/services/base_auth_admission_registration_restart_browser_test.rb`
- `test/services/sign_secret_record_event_logging_boundary_test.rb`

Ten of these files have passing focused results. The Avatar deletion request file still expects 403
but receives a 302 after its no-mutation assertions; this mismatch is recorded and no implementation
was changed. The coverage full-suite run was interrupted when handoff closeout was reprioritized;
it stopped at 7,042 runs / 62,491 assertions / 94 failures / 16 errors / 0 skips and produced no
complete coverage result. Those partial counts do not replace or alter H-2's 17:14 snapshot.

The four archived work-log snapshots were refreshed from the current root logs, with local absolute
paths redacted and repository-relative links rewritten. `git diff --check` passes. No changes were
made to `.devcontainer/`, `compose.yaml`, `config/database.yml`, or `lib/local_environment.rb`.
No commit or push was made; the owner remains responsible for selecting and committing the handoff
set.

## Earlier commit-candidate audit (2026-11-06 22:25 UTC)

The worktree now has 120 modified tracked files and 44 untracked files (164 commit-candidate files);
no file is staged. The earlier owner count of 146 is stale. The secret scan covered those candidates
plus the four ignored root work logs (168 files). Gitleaks reported 17 generic API-key patterns: 13
fixed test idempotency values and four abbreviated revision/evidence identifiers duplicated between
the root and archived `zero.md`. Manual review found no live credentials, private-key markers,
JWT-shaped values, provider secrets, or personal contact data; email-like values use only
`example.com`. No `.env` file, database dump, scratch log, or generated artifact is a candidate.

The 11 coverage-only untracked test files remain out of the handoff commit. Ten have passing focused
results; the Avatar delete-authority test still receives 302 rather than the contract's expected 403
after its no-mutation checks. The interrupted coverage run is not a completed suite result. Keep the
files for later resolution rather than deleting them. All other candidate paths have an
implementation, migration, test, evidence, handoff, archive, or backlog purpose. `git diff --check`
passes. No commit or push was made.

## Previous closeout and candidate audit (2026-11-06 22:53 UTC; superseded by the 2026-11-07 audit below)

The 17:14 owner full-suite result remains the handoff baseline: 16,922 runs / 146,848 assertions /
270 failures / 53 errors / 0 skips. No full run followed it. The withdrawal/RP-boundary work had
reached the requested stopping point; no further failure repairs were made. The post-snapshot changes,
focused results and remaining failures are summarized in the latest `zero.md` entry. H-2 remains the
complete per-file classification of 323 incidents in 122 files, with no unknown rows. H-4 and H-5
remain closed as inventories: all 29 `two.md` Work Units, all 51 acceptance IDs, and `five.md` C0-C15
are accounted for. Open implementation work remains with its owning specs/backlogs.

At this check, the worktree has 120 changed tracked files and 45 untracked files (165 candidate
files), with nothing staged. `git status --short` collapses nested untracked directories; the count
of 45 is from individual paths returned by `git ls-files --others`. Gitleaks scanned those paths
plus the four ignored root work logs (169 files total) and reported 17 generic API-key matches: 13
fixed test idempotency values and four abbreviated revision/evidence identifiers repeated in
root/archive `zero.md`. Manual review found no live credentials or personal contact data; email-like
values use reserved test domains and phone-shaped values are examples or synthetic test inputs. No
generated/scratch files are among the candidates.

The current set of 12 untracked public-method coverage tests is intentionally excluded from the
handoff commit and retained for the separate coverage task; their paths are listed in the latest
`zero.md` entry. Eleven have focused passing results. The Avatar delete-authority request test has a
302-versus-403 response mismatch after no-mutation assertions; no implementation was changed for it.
The seven other untracked tests are requested handoff regression tests:

- `test/concurrency/base_selector_single_write_http_test.rb`
- `test/controllers/base/app/identity/sensitive_admission_confirmations_browser_binding_test.rb`
- `test/controllers/base/org/api/v0/avatar/dashboard_identities_controller_test.rb`
- `test/controllers/base/org/identity_entry_mfa_reset_link_test.rb`
- `test/controllers/visa/sign_in_restart_guidance_test.rb`
- `test/models/rp_base_org_session_avatar_selection_test.rb`
- `test/models/rp_base_session_selection_validation_test.rb`

All other untracked files have an identified handoff purpose. `.devcontainer/`, `compose.yaml`,
`config/database.yml`, and `lib/local_environment.rb` remain unchanged. The four archive copies were
refreshed from current root logs, local paths were redacted, and local links were checked. No test,
commit, or push was run here.

## Latest handoff stop and commit-candidate audit (2026-11-07 00:29 UTC)

The bounded withdrawal/RP-boundary work is at its requested stop point; no further failure repairs
were made. H-2 remains the complete table from the owner's 17:14 run (**16,922 runs / 146,848
assertions / 270 failures / 53 errors / 0 skips**), with 323 incidents across 122 test files and no
unknown classifications. H-4/H-5 remain closed as status inventories: all 29 `two.md` Work Units,
all 51 acceptance IDs (AC-20 retired; the other 50 open), and `five.md` C0–C15 are accounted for.
The table of post-17:14 changes and the remaining focused withdrawal/RP failures is in the latest
`zero.md` entry. No complete Rails suite has been run after 17:14.

The current worktree has 120 modified tracked paths and 56 untracked file paths (176 candidates);
there are no staged files. The four ignored root logs were included in a 180-file secret scan.
Gitleaks reported 17 generic API-key patterns, all reviewed as fixed test idempotency values or
abbreviated revision/evidence identifiers. Manual review found no live credentials, private keys,
JWTs, provider secrets, or personal contact data. Email-shaped values use `example.com`; phone-shaped
values are locale examples or synthetic test fixtures. No `.env`, database dump, scratch log, or
generated artifact is a candidate.

Exclude the following 22 public-method coverage tests from the handoff commit. Keep them in the
worktree for the deferred coverage task. The known focused findings are an Avatar delete-authority
302 where the test expects 403, and a Visa ORG admission 503 from strict loading before the action;
neither received an implementation change. The separate classification evidence file is also
deferred.

- `test/adapters/avatar_authority_client_sensitive_mutations_test.rb`
- `test/adapters/mcp_tool_public_call_test.rb`
- `test/adapters/visa_sensitive_admission_client_confirmation_test.rb`
- `test/controllers/base/org/avatar_selected_delete_authority_test.rb`
- `test/controllers/visa/org/sensitive_admission_api_coverage_test.rb`
- `test/jobs/op_identity_event_delivery_job_authority_test.rb`
- `test/models/actor/authentication_context_public_test.rb`
- `test/models/authority_resource_lifecycle_public_predicates_test.rb`
- `test/models/client_totp_credential_slot_status_policy_test.rb`
- `test/models/client_visa_social_link_admission_connection_owner_test.rb`
- `test/models/op_org_authority_stop_participant_final_state_test.rb`
- `test/models/operator_contact_registration_finalization_evidence_test.rb`
- `test/models/operator_oidc_connection_actor_test.rb`
- `test/models/public_method_contract_values_test.rb`
- `test/operations/identity_social_ceremony_transaction_purger_behavior_test.rb`
- `test/operations/visa_sensitive_admission_browser_confirmer_authority_test.rb`
- `test/services/authentication_token_service_expired_token_facade_test.rb`
- `test/services/base_auth_admission_registration_restart_browser_test.rb`
- `test/services/identity_social_ceremony_candidate_store_consumed_test.rb`
- `test/services/sign_secret_record_event_logging_boundary_test.rb`
- `test/values/actor_values_context_visitor_predicate_test.rb`
- `test/values/webauthn_public_registry_entrypoints_test.rb`

Also defer `evidence/2026-11-06-public-method-coverage-classification-R4T7.md`. The other candidate
files have a handoff implementation, migration, regression test, H-2 evidence, handoff/archive
document, or requested backlog purpose. The four ignored root work logs are not commit candidates;
their tracked snapshots are in `plans/archive/0003-authentication-handoff-work-logs/`. No file was
staged, committed, or pushed. The owner can select the handoff set while excluding the coverage
files above.
