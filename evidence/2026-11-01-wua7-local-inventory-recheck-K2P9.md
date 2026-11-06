# WU-A7 local withdrawal inventory recheck

HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this evidence file and its `four.md`
reference were added, the worktree had 500 modified tracked files, 228 untracked files, and no
staged files. Existing changes were preserved.

With `.env.container.devcontainer` loaded, read-only Rails runner queries found:

| Environment / principal database | Actors                                | Withdrawal-related facts                                                                                                          |
| -------------------------------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Development APP                  | 0 Clients                             | 0 rows                                                                                                                            |
| Development ORG                  | 0 Operators                           | 0 rows                                                                                                                            |
| Test APP                         | 9 Clients; `status_id` groups 6, 1, 2 | 0 withdrawal-start, deactivation, termination, recovery-available or early-termination timestamps; 0 finite `withdrawn_at` values |
| Test ORG                         | 6 Operators; `status_id` groups 5, 1  | 0 withdrawal-start, deactivation or `withdrawn_at` timestamps                                                                     |

`ClientWithdrawalFlow.count` returned 0 in the test database. A subsequent read-only grouping by
`status_id` failed with PostgreSQL `UndefinedColumn`; the test flow table has no `status_id` column
in the connected schema. The query did not modify database rows. No migration was run, no records
were changed, and no production or Neon database was accessed.

This refresh supersedes the earlier test APP actor count of 7 in the draft WU-A7 shape ticket. The
missing test flow column and ORG indefinite-suspension mapping remain unresolved. No full test suite
was run. The owner has not yet approved the WU-A7 state shape or migration execution.
