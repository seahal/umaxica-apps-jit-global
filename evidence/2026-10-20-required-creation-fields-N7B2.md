# Required creation fields and explicit Avatar booleans

Application revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`; branch `feature`; date 2026-10-20
UTC. The worktree already contained extensive uncommitted
model/test/locale/configuration/migration/dump changes, including the earlier digest slice. Those
changes were retained and affect these results. The starting tracked patch/status were saved as
validation-start.patch/status in the ignored local artifact directory. No migration, dump
generation, production data operation or external write ran.

## Scope and behavior

- User delegated validation decisions and requested NOT NULL findings and mistakes be corrected.
- C11: 48 required locale fields on all twelve Entry/Slug/Revision/Version families reject only nil
  on create. Characterization preserves ja/en, empty/whitespace and false/zero string casting.
  Twelve Publication effective_from fields get creation-time presence; nullable end times, immutable
  versions and projected existing-publication updates remain valid. Existing DB NOT NULL enforcement
  remains unchanged; independent SQL NULL writes fail.
- C12: nine AvatarLifecycleState flags accept explicit true/false on creation. Missing/empty inputs
  fail model validation; false remains valid, raw NULL still fails. All canonical catalog state
  values, transitions, authorization, event writers and surface boundaries are unchanged.
- Root cause groups: three (locale, publication start, boolean catalog). Affected model consumers:
  61; new tests: 54 (36 Publishing, 18 added Avatar); migrations: zero. Model implementation changes
  are four existing Concerns and one concrete model; explicit labels added to the four locale
  bundles.
- Existing DB constraints are authoritative. No uniqueness SELECT, trigger, callback, data default,
  format whitelist, destructive DDL or authentication/withdrawal redesign was introduced.

## TDD and checks

Commands use the existing `tmp/database-consistency-20261019/run_tests.py` runner with the exact
current `.env.container.devcontainer` preparation list and PARALLEL_WORKERS=1; no global setup
changed.

| Receipt prefix in tmp/database-consistency-20261019 | Result                                                                  |
| --------------------------------------------------- | ----------------------------------------------------------------------- |
| required-red                                        | 36 runs / 1392 assertions; 24 expected failures, 0 errors/skips; exit 1 |
| required-green                                      | 407 runs / 11836 assertions; 0 failures/errors/skips; exit 0            |
| avatar-required-red                                 | 23 runs / 70 assertions; 9 expected failures, 0 errors/skips; exit 1    |
| avatar-required-green                               | 49 runs / 253 assertions; 0 failures, 5 errors, 0 skips; exit 1         |
| avatar-required-focused                             | 53 runs / 253 assertions; 0 failures/errors/skips; exit 0               |
| required-final                                      | 59 runs / 1945 assertions; 0 failures/errors/skips; exit 0              |

The Publishing broad run covers models, operations and locale integrity. Final combined run also
covers all projected-publication updates. The focused Avatar run covers catalog, agent/individual
bindings, lifecycle transitions, authority lifecycle invariant and locale bundle integrity.

The five errors in the first broad Avatar run are explicit
`committed tests require run-owned worker receipts` refusals from AvatarConcreteOwnershipPeriodTest.
Those committed/concurrency tests did not execute their contracts in the one-worker runner. They
were not changed, skipped or made passing; the later successful focused run is a narrower scope, not
full ownership verification.

## Checker results

- Full default checker after C11: exit 1; raw failures 1,886 -> 1,838. Exactly 60 old NullConstraint
  identities removed, twelve new ColumnPresence/Publication.effective_from identities added.
- Full default checker after C12: exit 1; **1,829 individual failures, 1,814 displayed groups, one
  warning**, 18,619 OK reports. No internal error report. C12 removes exactly the nine boolean
  NullConstraint identities; no new report from C12. Total net reduction this turn: 57.
- ColumnPresenceChecker marks every presence validator with :on as weak even when the DB is NOT
  NULL. Keep these twelve new reports visible: create-only validation preserves actual projected
  saves. Owning Concern has a FIXME. No validator/context/configuration was altered to conceal the
  reports.
- Current stable-ID ledger now retains 2,194 identities, including absent historical reports and all
  twelve new reports; checker/domain summaries updated in current-findings.md. Remaining
  NullConstraint: 215; ColumnPresence: 45. No checker config, exclusion, fork or enabled state
  changed.

Final scoped RuboCop: seven files inspected, no offenses, exit 0. `git diff --check` passed. The
final target capture confirms the same 873 project models and no disabled checker. The staged diff
remains empty.

## Limits

Full Rails suite and production preflights were not run. The earlier schema-drift comparison failure
from the HMAC definer-role/database-name mismatch was not rerun or repaired by this validation
slice. Committed ownership tests remain unverified as above. Schema reconstruction and production
migration acceptance are not established. Overall zero-finding objective remains unmet.

## Retained artifacts

Full, untruncated logs/JSON and exit receipts remain in ignored tmp paths, not in evidence.

| Artifact                                                   | SHA-256                                                            |
| ---------------------------------------------------------- | ------------------------------------------------------------------ |
| `tmp/database-consistency-20261020/required-after.stdout`  | `904f955c3d59b20157e988effed00eed603bdad34cff35ddefb00fd25ec096d2` |
| `tmp/database-consistency-20261020/required-after.stderr`  | `cef06f5ab66d5c25b45550f78e9045cdbf9f7cea0a40d12fc11314e40fd1c46e` |
| `tmp/database-consistency-20261020/required-raw.json`      | `e0d7863d093546b07eb612355e09801ce675b89fd42b44b2ae33c6e521a77bf6` |
| `tmp/database-consistency-20261020/boolean-after.stdout`   | `6a2e3cde9e550117f50bef077957e26c1e25c621633bf419cc6203090273021c` |
| `tmp/database-consistency-20261020/boolean-after.stderr`   | `bae981cec4873135b5baae7be570aadd142e361c4b08a10ebb8a6bf42aadb228` |
| `tmp/database-consistency-20261020/boolean-raw.json`       | `5e6dc1af69c32c8b973f119cf402dddf039e8451eea8030b8c6c8562f25d63cd` |
| `tmp/database-consistency-20261020/validation-start.patch` | `910b7d1af0a207e7f7f7767f44eb0d61e99c100c788811a74e16cf51df5079b8` |
