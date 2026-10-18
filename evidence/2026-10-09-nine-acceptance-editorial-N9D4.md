# Integrated instruction and acceptance document validation

Date: 2026-10-09. Code HEAD during checks: `13f27059c874e607bbe246cdf532b832691012fa`, branch
`feature`. The worktree contains extensive pre-existing uncommitted application, test, migration,
configuration and documentation changes. Other work continued during editing. This is document
validation only; no application implementation, DB operation, application test, dynamic acceptance
or independent application investigation was performed. A later document-only commit does not
snapshot that dirty code.

## Owned document scope

- `nine.md` (previously ignored; explicitly authorized for local Git persistence).
- `docs/checklists/integrated-stack.md` (independent reader entry and source crosswalk).
- `docs/checklists/identifier-contracts.md`.
- `docs/checklists/contact-identifiers.md`.
- `docs/checklists/authentication-flow-integrity.md`.
- `docs/checklists/avatar-ownership.md`.
- `docs/checklists/email-observability.md`.
- `specs/integrated-stack-delivery/acceptance.md`.
- This evidence record.

Existing dirty indexes/rules and other authors' untracked checklists were read, not edited or
included. The new integration index is discoverable from nine.md and the existing checklist glob; it
links tracked authority where another author's checklist is not yet committed.

## Observed checks

- `python3 /tmp/check-nine-documents.py`: passed the one-off editorial checks over eight
  instruction/ criteria files: 48 unique Acceptance IDs; all 87 M/I/A/F/O/E source IDs covered; 75
  existing local file/anchor links with committed or owned destinations. Protected business Sections
  5–9 and C01–C15 matched the pre-edit document after ignoring whitespace/table-separator
  formatting. The temporary script is an editing aid, not a new committed harness. The check expands
  source ranges, resolves local links and anchors, checks duplicate IDs/fences/whitespace and
  compares protected text.
- `node_modules/.bin/oxfmt --check` with the eight explicit instruction/criteria paths: initially
  reported formatting differences; the same formatter was applied only to owned paths and the check
  then passed. No application formatter/test script was run.
- `git diff --check`: exit 0. New/ignored document whitespace was additionally checked by the
  one-off audit; this unstaged Git check alone did not cover those new files.
- `scripts/check-repository-knowledge nine.md specs/integrated-stack-delivery/acceptance.md`: exit 1
  before document validation due to eight missing/broken `.claude/skills` adapter preconditions:
  browser-testing-with-devtools, code-review-and-quality, deprecation-and-migration,
  frontend-ui-engineering, observability-and-instrumentation, security-and-hardening,
  shipping-and-launch, spec-driven-development. Those unrelated adapters were not repaired or
  bypassed. The focused link/ID/content check above is a separate limited result, not a successful
  repository checker.
- Reviewed the revised dependency graph/table/crosswalk, gate holds/cadence, document commit
  authority and independent-reader procedure against the requested editorial constraints. Existing
  design holds (Group semantics and Avatar personal-data policy) remain holds; planned test coverage
  is labeled.

## Persistence and remaining limits

Initial index had no staged changes. The local commit is restricted to the nine paths above, using
explicit paths and normal hooks/signing/permissions. Actual commit hash/path/blob inspection is
reported after the commit, not predicted here. No push, PR, remote edit or configuration override is
part of this work. Restoration of the eight repository knowledge adapters by their owner is the
minimum prerequisite to obtain a successful full repository knowledge-check result.

These checks validate documentation structure and protected contract content, not implementation
coverage or behavior. Rails/Vitest, real COMMIT/concurrency, effective mount and emitted-export
acceptance remain unexecuted by this editor. The independent investigator must establish their own
revision-scoped results from the permanent criteria; no criterion receives permanent PASS here.
