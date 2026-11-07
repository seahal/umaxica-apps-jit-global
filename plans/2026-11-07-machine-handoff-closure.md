# Machine Handoff Closure (2026-11-07)

Status: active. Owner decision on 2026-11-06: development on the current machine ends within days.
By the end of 2026-11-07 the `feature` branch is pushed and work continues on other machines (VMs
where `rails server` and `rails test` already run). The owner operates; Codex, Claude Code and the
VM agents do the work. The goal is a clean, honest handoff, not a green suite.

## Current handoff checkpoint (2026-11-06)

The owner's latest sequence governs the remaining work on this worktree: stop further test-failure
repairs after the bounded withdrawal/RP check; finish H-2 from the supplied 17:14 full run; record
the H-4/H-5 work-unit, acceptance and spec statuses; refresh the four tracked archive snapshots;
then report commit readiness. The H-2 table is complete with no unclassified incidents, but its
17:14 suite result remains red and no post-fix full-suite result is claimed. The owner makes the
commit and push. This checkpoint supersedes the earlier numbered execution order below for this
handoff pass.

## Done means

- H-1 Fresh setup: on a VM, from a clean clone of the pushed `feature`, the documented setup creates
  and migrates every database from the committed structure dumps, `bin/rails server` serves the
  Base, Auth and Visa sign-in pages, and `PARALLEL_WORKERS=1 bin/rails test` and `bun run test` run
  to completion. Record the commands and results in `evidence/`.
- H-2 Every remaining test failure is classified, none unknown. One table, per failing test file:
  (a) caused by the current changes, (b) present before (compare with
  `plans/2026-10-28-baseline-failing-tests.md`), (c) intended spec change with an outdated
  expectation, (d) intentionally failing test written ahead of implementation
  (`specs/browser-flow-state-cookies` Work order 2). Each row has a one-line cause and its owner
  document.
- H-3 Fixed before push: (a) and (c) failures in sign-in, sign-up, step-up, OTP, selector and
  session paths, including the 13 `test/models` failures reported on 2026-11-06. Other (a)/(c)
  failures are fixed if time allows; otherwise they stay listed under H-2.
- H-4 `two.md` and `five.md` are closed honestly: for each Work Unit and acceptance item, record
  done and verified, done but unverified, or open, with the evidence path. Open items move to
  `plans/backlog/` or the owning spec; nothing is silently dropped. Follow `plans/archive/README.md`
  for what is archived.
- H-5 Open specs state their status for the handoff: `specs/op-mediated-step-up` (unit 6b and 7
  open, O-9 not connected), `specs/browser-flow-state-cookies` (accepted, Work order 2 in progress,
  intentionally failing tests listed). Owner decisions made in conversation are written into the
  owning documents.
- H-6 Repository hygiene before the commit: no secrets, credentials, `.env` values or local paths in
  tracked files; structure dumps match a fresh migration; no stray files at the repository root
  (`zero.md`, `two.md`, `five.md`, `six.md` are either archived or explicitly kept with a reason);
  `bin/rubocop` and `bun run check` results recorded (fixing new offenses only in files changed for
  H-3).
- H-7 A handoff note `plans/2026-11-07-handoff-status.md` lists: branch and commit, setup commands,
  test results, the H-2 table location, open specs and their next step, owner decisions pending,
  and known risks.

## Rule for fixing test failures before the handoff (owner, 2026-11-06)

Fix a failure only when its cause is established and the fix is small. "Established" means the
failing line and the reason are shown (stack trace, the changed contract it contradicts, or a
reproduced run), not inferred from the failure message alone. A test is changed to match new
behavior only when an accepted spec, ADR or owner decision states that behavior; otherwise the
implementation is suspect and the failure is reported, not adjusted. Never weaken or delete an
assertion to make a test pass. Everything else stays in the H-2 table with what is known and what
would confirm it.

## Frozen until after the handoff

New feature work: `specs/browser-flow-state-cookies` implementation beyond the tests already
written, O-9 connection, RuboCop cleanup outside H-3 files, the coverage task, the backlog items
added on 2026-11-06.

## Order

1. H-3 fixes and the H-2 table (Codex, current machine).
2. H-6 hygiene and the commit (Codex prepares, owner commits and pushes).
3. H-1 on a VM from the pushed branch (VM agent; owner operates).
4. H-4, H-5, H-7 documents (Codex drafts, Claude Code reviews).
5. Claude Code reruns the full suite on the current machine and checks the table against the run.

## Receiving-side requests (VM agent, 2026-11-06)

The receiving environment runs Rails directly on a VM (no Dev Container, no compose network aliases,
no `core` service, no Cloudflare Tunnel yet). Its setup is in the uncommitted README Local Setup. It
asks for, in addition to H-1..H-7:

- Commit and push all needed work on a non-main branch (`feature`); list unneeded untracked files;
  commit no secrets.
- A handoff memo covering purpose, spec/plan paths, progress, next step, decided vs owner-pending
  items, last test commands and results with pre-existing vs change-caused failures, branch and
  `git rev-parse HEAD` (this is H-7).
- A list of container dependencies: container hostnames (`primary`, `replica`, `valkey`,
  `fakecloud`, `core-workers-vpc.internal`), variable names present only in
  `.env.container.devcontainer` (names, not values), container-only tools, noVNC/desktop, Tailscale,
  sshd, and checks that rely on the Cloudflare Tunnel.
- Migrations added by this work and whether `db/*_structure.sql` were updated; any reliance on
  hand-made development data (the new environment starts from `bin/setup` and `db:seed`).
- Do not recreate or delete `.devcontainer/`, `compose.yaml`, `config/database.yml` or
  `lib/local_environment.rb`, and make no move-only configuration changes.

Owner of the 13–14 `test/models` failures: fixed here by Codex under H-3, because they come from this
branch's changes. The VM side only re-runs `test/models` after pulling, to avoid duplicate edits.

Initial facts found by Claude Code (read-only, 2026-11-06):

- `lib/umaxica/test_environment/database_safety.rb` fixes `TEST_HOST = "primary"` (the Dev Container
  database host) as a deliberate safety rule; on a VM the test database host must satisfy it.
- Variable names present in `.env.container.devcontainer` but not in `.env` on this machine:
  `DEVCONTAINER`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `PREFERENCE_COM_JWT_AUDIENCE`,
  `PREFERENCE_COM_JWT_ISSUER`, `PREFERENCE_COM_JWT_REVOKED_KIDS`, `PRIVATE_GUID_SERVICE_URL`,
  `PRIVATE_VISA_CORPORATE_URL`, `PRIVATE_VISA_SERVICE_URL`, `PRIVATE_VISA_STAFF_URL`,
  `RUBY_DEBUG_OPEN`, `WEB_CONCURRENCY`.
- 107 migrations were added between `b30345216` and `f56c805` (op_base_app 34, op_base_org 32,
  rp_base_app 14, rp_base_org 12, app_principals 8, app_zenith 3, and one each in chronicle,
  org_principals, org_settings, org_zenith). Structure dumps were regenerated on 2026-11-05; H-6 must
  confirm they match a fresh migration.

## Added before the handoff: `belongs_to` required by default (owner, 2026-11-06)

The application default is `true` (`config.load_defaults(8.2)`, confirmed with `bin/rails runner`),
but 15 places set `self.belongs_to_required_by_default = false`: 12 models (`Avatar`,
`OperatorLifecycleRequest`, `ClientToken`, `OperatorToken`,
`{Client,Operator}SessionLimitResolutionTransaction`, `{App,Org,Com}PreferenceChronicle`,
`AvatarOwnershipPeriod`, `Department`, `ComPreference`) and 3 concerns (`CollectiveMembership`,
`CollectiveUnit`, `SignFlow`). All predate `b30345216`.

Owner decision: remove all 15 overrides. For each `belongs_to` in the affected models (including
every model that includes the three concerns), decide from the schema and the domain whether the
association is required. Mark only genuinely optional associations `optional: true`, each with a
one-line reason; everything else becomes required. Apply the fixing rule above: where a column is
nullable but the association should be required, or the decision is unclear, list it instead of
guessing. Do not change schema in this step. Run the tests of every affected model and its writers.
The existing 40 `optional: true` declarations are out of scope here.

Owner decision (2026-11-06): make `avatar_ownership_periods.avatar_ownership_status_id` NOT NULL
before the handoff. The migration only adds the constraint; it does not backfill or rewrite rows.
It must stop with an explicit error if any row has a NULL status, so a database with such rows is
never silently changed. Use the repository's safe pattern for large tables (check constraint
`NOT VALID`, validate, then `NOT NULL`, then drop the check) as `generic/migrations.mdc` and
strong_migrations require. The migration is reversible (dropping NOT NULL restores the previous
shape). Before release, confirm on production that no NULL rows exist; that check is a release step,
not part of this change.

Owner decision (2026-11-06): the new Base ORG table `rp_base_org_session_avatar_selections` (six
migrations from `20261106143155` to `20261106143215`) was approved by the owner directly with Codex
before it was added. It belongs in the handoff: the migration list in
`plans/2026-11-07-handoff-status.md` and the structure-dump comparison must include it.
