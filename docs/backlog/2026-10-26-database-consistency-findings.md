# database_consistency findings

Status: Open (owner, 2026-10-26). Not resolved in the 2026-10 authentication cycle.

The development scan reports 690 findings, 104 from this cycle and 586 pre-existing; full
classification in `evidence/2026-10-26-database-consistency-cycle-findings-X7P4.md`. The sign-out
tables' share is listed in `docs/backlog/2026-10-25-logout-suite-withdrawn-from-cycle.md`; findings
on the dropped `*_authority_stop_browser_logouts` tables no longer apply. Each finding needs an
owner decision (model validation vs database constraint order, dependent-delete policy, redundant
indexes) before any change.
