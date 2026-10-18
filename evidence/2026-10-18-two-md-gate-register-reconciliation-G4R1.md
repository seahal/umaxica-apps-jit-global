# `two.md` Gate register reconciled against recorded evidence

- Date: 2026-10-18 UTC. Commit `17903f7d121aa33efe29f2db9235c9aa5db4b001`; uncommitted R1-R5
  worktree.
- Method: read-only comparison of the `two.md` section 3 acceptance unit register (every row
  `NOT_RUN`) with each `evidence/2026-10-16-*`, `2026-10-17-*` and `2026-10-18-*` record. No test
  was run for this record and no register status was changed.

## Finding

No evidence record claims a Gate-level PASS under the `two.md` section 2 definition; several records
say explicitly that they do not close their Gate (R1C1, R1C2, 7P4M, R5C8, W18B). The `NOT_RUN`
column is therefore consistent with the evidence at Gate level. It does not show that partial
execution exists for most rows. The table below records that partial evidence.

| Gate                 | Partial evidence (focused/full-suite runs, migrations, probes) | Open at Gate level                                                                                         |
| -------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| AT-R1-01, AT-R1-02   | R1C1, R1C2                                                     | full R1 procedure, R1-WU02 release closure                                                                 |
| AT-R2-01 .. AT-R2-05 | 7KQ2, 3D7M, 7P4M, 6H2Q, 4J7N                                   | Gate procedures, AT-R2-REL                                                                                 |
| AT-R3-01 .. AT-R3-06 | covered only through R3-WU07/08 runs                           | per-unit procedures                                                                                        |
| AT-R3-07, AT-R3-08   | A6Q4 (full suite), K8P3                                        | restore NOT_APPLICABLE (one.md 1.2A); Gate procedure                                                       |
| AT-R4-01 .. AT-R4-04 | R4T1                                                           | JP host binding (AT-R4-02A), cutoff (AT-R4-03), US out of scope                                            |
| AT-R5-01             | none found                                                     | ownership manifest                                                                                         |
| AT-R5-02             | H7M2                                                           | Gate procedure                                                                                             |
| AT-R5-03             | W17A (cell stores)                                             | Gate procedure                                                                                             |
| AT-R5-03A            | R3A1, R3P7 (DB denial PASS, secret isolation FAIL)             | stopped 2026-10-18 by user decision; see `plans/backlog/2026-10-18-production-runtime-secret-isolation.md` |
| AT-R5-04, 05, 07     | R5P1, R5C8, W18B                                               | WU03A isolation; WU05 capacity NOT_RUN                                                                     |
| AT-R5-06             | W6S1                                                           | Gate procedure                                                                                             |
| AT-R5-08             | W8R1, R5C8, G4X2                                               | admitted 2/1/4-second budget NOT_RUN                                                                       |
| AT-R5-09, AT-R5-10   | L9B1, R5C8, W18B, G4X2 (real worker restart)                   | ACK under real HTTPS NOT_RUN                                                                               |
| AT-R5-11 .. AT-R5-15 | T11A, I12A, P13A, A14A, M15A, R5C8                             | Gate procedures                                                                                            |
| AT-R5-16             | B16A                                                           | Gate procedure                                                                                             |
| AT-R5-17             | W17A, R3P7                                                     | per-cell runtime with isolated roles                                                                       |
| AT-R5-18             | S18T                                                           | old OP-chain removal waits for WU19                                                                        |
| AT-R5-18A            | A18R (NO-GO), W18B, G4X2                                       | WU03A, cross-process cases                                                                                 |
| AT-R5-19, AT-R5-20   | W19S (source only)                                             | activation not performed                                                                                   |

Short IDs are the 4-character suffixes of the evidence file names.
