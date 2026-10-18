# Integrated implementation plan: adversarial editorial review

Code/document HEAD: `c4d85867ced5fa261cc7a762d12851893038b7ca`, branch `feature`. Date: 2026-10-09
(review shell UTC). The shared worktree contains extensive unrelated uncommitted application,
migration, test and document work plus the user's Compose edit. This is a plan review, not
independent application acceptance or a reproducible snapshot of that dirty implementation.

## Findings and dispositions

1. **Activation ordering ambiguity — corrected.** nine P8/P9 formerly described replacing ownership
   authority/converting operations before P10 Grant/Group consequences and P12b backfill. Section
   10.1 now separates synthetic implementation proof from reader/writer activation; incomplete
   consequences cannot become an admitted new transfer. MIG-4 and the phase table/resume path agree.
   Existing domain decisions, single owner authority and the no-post-cutover-fallback rule remain.
2. **Host preparation mistaken for completion — corrected.** Section 3.1a records the actual
   user-added overlay without duplicating it, while P1c retains separate source, configuration,
   processor and effective-mount dispositions. No restart is available now. Later host-managed Alloy
   edits require a scoped patch handoff rather than bypassing read-only protection.
3. **Shared-source SELinux label risk — example corrected; host application pending.** The current
   overlay has private `Z`, whereas Alloy mounts the same config with `ro,z`. On an enforcing
   SELinux host those are different access policies. Section 9.3 uses shared `z` and MAIL-5 now
   requires both readers to work, including parent-workspace relabel/startup-order effects. This
   does not claim the current host is enforcing SELinux or that changing one label alone proves
   runtime safety. Compose was not modified by this editor. Source:
   [official Podman run documentation](https://docs.podman.io/en/v5.6.2/markdown/podman-run.1.html).
4. **Immutable-history/full-suite feasibility could be discovered too late — clarified.** P7 now
   inspects existing fixture/cloning/cleanup paths before schema work and requires uniquely owned
   disposable verification without trigger suppression or shared destructive cleanup. No new trigger
   or test-helper modification authority is granted.
5. **Unconditional readiness would be unsupported — explicitly rejected.** P0 can start, but feature
   editing requires actual Gate 0 and per-slice permissions. Group semantics, broad permanent-ID
   enforcement authorization where absent, real concurrency and host runtime checks retain bounded
   holds. Eight unrelated knowledge-adapter failures remain a final-check limit.

## Observed validation

- Python `yaml.safe_load` parsed `.devcontainer/compose.yaml`; first marker was `---` and there were
  ten mounts. A semantic comparison with the HEAD file confirmed all original mounts were retained
  and exactly one `./podman/alloy` overlay with `read_only: true` was added. Source SHA-256:
  `b537eb5250a1114b1149076676cd8cac707510d1b31b01c7feca18d37569b5f7`.
- `python3 /tmp/check-nine-final-review.py`: PASS. The one-off editing check verified 48 stable
  acceptance IDs, all 87 M/I/A/F/O/E IDs, 75 existing persistent local links/anchors, balanced
  fences and unchanged C01–C15/Sections 5–8. Section 9 changes were checked against the exact
  reviewed mount-only amendment. The implementation phase graph is acyclic; P3b primary-control
  dependencies and P10/P11/P12 independent branches remain. Runtime activation has separate
  mandatory edges in the prose/table, not a purported completed phase.
- `node_modules/.bin/oxfmt --check nine.md docs/checklists/email-observability.md docs/checklists/integrated-stack.md specs/integrated-stack-delivery/acceptance.md`:
  PASS.
- `git diff --check`: PASS.
- `scripts/check-repository-knowledge nine.md specs/integrated-stack-delivery/acceptance.md`: exit
  1, the same eight existing broken/missing `.claude/skills` adapters: browser-testing-with-
  devtools, code-review-and-quality, deprecation-and-migration, frontend-ui-engineering,
  observability-and-instrumentation, security-and-hardening, shipping-and-launch,
  spec-driven-development. No unrelated adapter work was changed or checker bypassed.

The temporary Python checker is an editorial aid, not a new repository verification framework. No
Rails/Vitest, migration, DB connection, Compose rendering, Alloy binary validation, restart, real
COMMIT/concurrency, mail send, live exporter or independent application acceptance was executed. A
separate uncommitted record reports Compose rendering in another context; that report was read but
is not adopted as this review's result. Docker/Podman executables were not found on this review
shell's PATH. Future checks must establish actual runtime availability.

## Handoff and persistence

The four owned document updates and this record are eligible for the previously authorized narrow
local document commit. The actual resulting hash/path/blob verification is reported after commit.
The user's Compose edit, eight.md and all other contributors' changes are excluded. No push,
configuration edit, application implementation or permission expansion is part of this review.

The plan is suitable for starting P0 with explicit holds, not a guarantee of uninterrupted
execution. The host owner must reconcile shared-source labeling before recreation if SELinux is
enforced; Luna must establish Gate 0 and isolated DB/permission readiness before dependent feature
work. The knowledge-adapter owner must restore the eight adapters for the full document checker to
pass.
