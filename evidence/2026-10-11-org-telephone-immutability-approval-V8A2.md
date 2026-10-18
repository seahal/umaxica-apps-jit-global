# Scoped permanent-identity mechanism approval

HEAD: `65e2f0f750b6262da38eb9022f9bf71e47a3f3a2`, branch `feature`. The worktree contains
uncommitted application/tests/tasks and unrelated source-policy work, plus the locally restored
untracked skill adapters. This document does not snapshot those changes.

The user's current response explicitly grants permission and requests completion. It resolves the
specific pending proposal in `2026-10-11-org-telephone-db-enforcement-map-M5Q8.md`: a reversible,
named rejection trigger for existing non-NULL `operator_telephones.public_id` only. The trigger ADR
now records this exception, the allowed NULL-only backfill, unchanged-value/unrelated updates,
SQLSTATE 23514, row-local lock behavior, and required direct-SQL/bulk and inventory verification.
This does not extend approval to other identifier tables, production/shared application, automatic
role changes, or schema commits.

`bun x oxfmt adr/database-trigger-usage-boundary.md` exited 0.
`ruby -rpathname scripts/check-repository-knowledge adr/database-trigger-usage-boundary.md` exited 0
(8 Skills/adapters, 68 documents, 0 evidence records). `git diff --check` exited 0. The staged set
was empty before this documentation change was staged.

The shared-generation full Rails gate is still running; no subsequent feature code, migration,
database mutation or trigger test was started. Approval and document checks are not proof of DB
enforcement. The existing Vitest result belongs to that pending combined gate. No push occurred.
