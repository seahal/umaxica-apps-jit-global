# App social release and Source audit acceptance

- Date: 2026-10-09 UTC.
- Reviewed HEAD: `c4d85867ced5fa261cc7a762d12851893038b7ca`. The full Rails run began against `13f27059c874e607bbe246cdf532b832691012fa`; the intervening commit changed documentation, an evidence record, and `nine.md`, with no application, migration, or test files. The worktree had uncommitted changes that affected every check reported here, alongside unrelated concurrent edits.
- Scope: app Apple/Google signup, login, link, unlink, and withdrawal termination; Source social audit outbox and Chronicle delivery. Org Microsoft Entra ID was not changed. The user explicitly approved app-only release proof and preserving company-owned org Entra authority.

## Observed results

| Check | Result |
| --- | --- |
| Full Rails suite, one worker, verified disposable 20-database manifest `tmp/acceptance-isolated-20261009social3.json` | `14,950 runs, 127,023 assertions, 0 failures, 0 errors, 0 skips` in 940.37 seconds. Command: `ruby /tmp/four-social3-run-tests.rb`; log: `/tmp/four-social3-suite-final5.log`. |
| Focused social login, signup, link, unlink, withdrawal, Chronicle delivery, and HTTP flow selections | Latest individual runs: 72/488, 36/260, 27/225, 15/91, 52/492, and 46/469, all with zero failures/errors/skips. These runs preceded the final full suite where later changes are covered together. |
| Social binding concurrency, org Customer refusal, and withdrawal Chronicle delivery, added after the full suite | The latest three-file selection passed 16 runs, 63 assertions, 0 failures/errors/skips. Independent PostgreSQL backend PIDs raced two Clients for one Google subject and Google/Apple for one Client; each race produced one effective binding and one Source linked intent. A valid app Client public ID was refused as an org Entra provisioning target. The deleted app identity's release outbox was delivered to Chronicle and acknowledged. The final whole-suite result above does not include these later test cases. |
| Released-subject query refinement after the full suite | Replacing an unbounded locked-row load with a bounded SQL existence predicate was followed by link, login, signup, and concurrency tests: 15 runs, 76 assertions, 0 failures/errors/skips. The whole-suite result above predates this equivalent query change. |
| Empty-catalog migration build | All 20 disposable databases were created from the migration inventory; the focused Rails run applied the new app Zenith and Chronicle migrations successfully. |
| App Zenith and Chronicle schema dumps | `SchemaDriftVerification.dump_matches?` returned true for both tracked dumps against the disposable catalogs. The top-level `db:verify_no_schema_drift` task was not claimed as passing because it intentionally rejects dirty tracked dump files. |
| Reversibility of the two app Zenith release-proof migrations | `db:migrate:down:app_zenith` on the disposable `20261009social2` catalog reverted versions `20261009211717` and `20261009211605` successfully. |
| Full Ruby style | `bundle exec rubocop --parallel`: 5,314 files inspected, no offenses. |
| JavaScript tests and gates | `bun run test`: 99 files and 1,140 tests passed. `bun run format:check`, `bun run lint`, `bun run typecheck`, and `bun run build` each exited 0. |
| Loader and whitespace | `bin/rails zeitwerk:check` and `git diff --check` exited 0. |

The first whole-suite attempt after adding the ceremony timestamp surfaced a test caller that omitted the new required keyword. Its test input was corrected without changing its unverified-principal expectation. Later whole-suite attempts were intentionally stopped when the review found additional app signup and login stale-callback paths; the final completed run above includes those repairs. No interrupted run is counted as a pass.

## Contract findings

- A committed app social signup, link, ordinary unlink, or withdrawal termination writes a Source audit intent in the same app Zenith transaction as its binding change. The job delivers to Chronicle by event UUID, verifies an existing UUID's event identity, and acknowledges Source only after Chronicle persistence. A repeated unlink returns `already_unlinked` without a second intent.
- A pre-release app social ceremony is refused at login, signup, and link use-case boundaries after unlink or withdrawal termination. The release proof survives deletion of the app external-identity row as a domain-separated HMAC and release timestamp in the Source outbox. The Auth login callback uses persisted admission creation time; Base finalization uses the Ticket transaction creation time. App link completion requires a live pending Ticket grant and expires it after candidate consumption.
- The corresponding app Source identity and social ceremony diagrams, transition inventory, spec, and durable authentication checklist were updated. The user-approved org Microsoft Entra distinction is recorded in the spec and checklist.

This is evidence for the stated app social and Source audit slice. It does not prove all 91 frozen implementation tasks, T01–T17, RP1–RP14, or the complete Phase 23 fault matrix. The eight unchecked `two.md` entries remain 16.1, 16.3, 16.5, 16.6, 19.3, 19.4, 23.1, and 23.3. T05, T07, and T16 have stronger passing slices than the earlier `2026-10-09-auth-acceptance-repair-H9K4.md` record, but their whole guarantees are not accepted by this record. Browser-enforced cookie/CSP behavior, real providers, and external deployment were not exercised.
