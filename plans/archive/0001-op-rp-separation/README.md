# OP/RP Separation — Cycle Archive

- Generation: 0001
- Period: 2026-10-16 to 2026-10-18 (approximate; the generation number is the ordering key)
- Outcome: partially delivered, then closed by the user. R1-R4 and R5-WU01 to WU17 are implemented
  in source; R5-WU03A (runtime secret isolation) was stopped, and R5-WU18A, WU19, WU18 and WU20 are
  frozen until it is recovered. No `acceptance-definitions.md` Gate was closed.

## What this archive is

A frozen snapshot of the working documents of one implementation cycle, kept as a clue to why the
implementation took its current shape. It is not normative, not evidence and not maintained. Code,
ADRs, `docs/` and `docs/checklists/` always take precedence. It may be deleted at any time; git
history is then the only copy, so nothing that must keep holding depends on it.

What must keep holding from this cycle was moved before closure:

- Recovery of WU03A and the frozen R5 work:
  [production runtime secret isolation backlog](../../backlog/2026-10-18-production-runtime-secret-isolation.md)
- Scope decision:
  [runtime secret isolation deferral ADR](../../../adr/runtime-secret-isolation-deferred.md)
- Lasting behavior: [authentication checklist](../../../docs/checklists/authentication.md) (AUTH-10
  to AUTH-17)
- Observations: `evidence/2026-10-16-*` to `evidence/2026-10-18-*`, closing with
  [the coarse acceptance record](../../../evidence/2026-10-18-one-md-cycle-coarse-acceptance-C9A1.md)

## Original file names

Other repository files, evidence in particular, refer to these documents by their working names.
Those references are not rewritten; use this table.

| Working name | Archived file                                            | Role                                                     |
| ------------ | -------------------------------------------------------- | -------------------------------------------------------- |
| `zero.md`    | [investigation-history.md](./investigation-history.md)   | Authentication architecture investigation history        |
| `one.md`     | [implementation-plan.md](./implementation-plan.md)       | Implementation specification: Work Units, DAG, approvals |
| `two.md`     | [acceptance-definitions.md](./acceptance-definitions.md) | Acceptance tests: Gate register, invariants, test cases  |
| `three.md`   | [implementation-reports.md](./implementation-reports.md) | Implementation reports (REP-*)                           |
| `four.md`    | [addenda.md](./addenda.md)                               | Formal supplements to the plan and acceptance documents  |
| `five.md`    | [notes.md](./notes.md)                                   | Non-normative notes and reviewer corrections (MISC-*)    |
| `six.md`     | [escalations.md](./escalations.md)                       | Escalation requests and responses                        |
| `seven.md`   | [issue-log.md](./issue-log.md)                           | Implementation issue log                                 |
| `eight.md`   | [watchdog-log.md](./watchdog-log.md)                     | Implementation watchdog log                              |
| `nine.md`    | [planning-discussion.md](./planning-discussion.md)       | Historical planning discussion                           |

The snapshots are unchanged except for a one-line archive note under each title and relative links
rewritten to the archived names and locations.
