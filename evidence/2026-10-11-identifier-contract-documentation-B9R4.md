# Durable identifier decision recording

HEAD: `332fc55bee7a171a1a8df05f13c9a79fce267f1a`. ORG Telephone application/test/backfill changes
and unrelated source-policy edits are uncommitted. Rails Gate 2 was running during this
documentation-only work; no feature change or independent acceptance was performed.

The identifier checklist referred to a proposed, nonexistent `adr/identifier-contract.md`.
Repository ADR inventory found cross-DB and GUID-surface owners but no general identifier decision
owner. The new ADR records the already approved I contract without modifying public GUID resolver
semantics, extending trigger/role/SQL permission or claiming implementation completion. The ADR
index and existing checklist now link to the actual file. Per-table classification, exception
guidelines and comprehensive executable guards remain incomplete.

`bun x oxfmt adr/identifier-contract.md adr/README.md docs/checklists/identifier-contracts.md`
exited 0. `git diff --check` exited 0. A direct local link inspection resolved all thirteen relative
Markdown links in those three files, exit 0. This limited check is not a substitute for the
repository knowledge checker.

`ruby -rpathname scripts/check-repository-knowledge adr/identifier-contract.md adr/README.md docs/checklists/identifier-contracts.md`
exited 1 on the eight existing `.claude/skills` adapter errors before document-link validation. No
adapter, environment, hook or checker rule was changed or bypassed. The full knowledge gate remains
BLOCKED by that separately owned condition. No Rails/Vitest success is attributed to this
documentation review; the pending full Rails result remains separately recorded.
