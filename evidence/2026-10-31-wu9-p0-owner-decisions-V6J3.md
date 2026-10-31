# WU-9 P0 owner decisions

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`. The worktree had 3,442 lines of staged, unstaged, and untracked changes when recorded.
- On 2026-10-31 the owner approved the WU-P0 ADR replacement proposal and resolved its review questions: retain `items_per_page: infinity`; do not classify legacy account rows whose `explicit_fields` is NULL and treat those rows as historical read-only records; store Web Push by option-reference foreign key, not boolean; no external reader consumes the old JWT shape; no JWT compatibility or migration from old state is needed because the service has not reached alpha.
- The Web Push reference option table's current `id IN (0, 1)` CHECK remains unchanged in WU-9; future state expansion requires a migration.
- This decision does not approve destructive migrations or data deletion. The separate `two.md` §12.8 execution ticket and approval remain required. It does not resolve WU-7 final acceptance or the minimum A8/A2/A9 prerequisites.
- No ADR, application code, database or test was changed/run for recording this owner decision.
