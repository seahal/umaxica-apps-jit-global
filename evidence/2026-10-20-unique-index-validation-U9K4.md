# Unique-index validation and compatibility — C14–C27

- Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`. The worktree had extensive retained
  uncommitted changes that affected these results, including concurrent migrations and schema
  changes. This is not clean-HEAD or production evidence.
- Scope: exact UniqueIndex preflight only; no own migration, index removal, checker configuration,
  checker exclusions, trigger, auth/state writer or destructive production operation.
- Default full command: `bundle exec database_consistency`, stdout/stderr captured without
  truncation under ignored `tmp/database-consistency-20261020/avatar-unique-final.*`; exit **1**
  because findings remain. Processor capture via
  `bin/rails runner tmp/database-consistency-20261020/raw_reports.rb avatar-unique-final-raw`
  completed successfully: 18,886 OK, 1,644 failures and one warning. CLI grouped failures: 1,629. No
  internal checker error.
- UniqueIndex: **569 -> 451**, 118 reports across thirteen bounded causes and 118 concrete models.
  Compared with the earlier 605-review baseline, C13 resolved twelve and a concurrent index
  migration separately removed 24. Do not attribute those 24 to validators.
- Remaining: 264 ordinary, 98 PK-containing, 77 partial, twelve NULLS NOT DISTINCT. All 605 original
  identities remain in unique-index-review.md; the 2,194-ID overall ledger maps every current non-OK
  report. Open rows include pending consumer review; they are not all proven unfixable.
- Four locale bundles contain explicit new error labels. Partial validators match both existing-row
  predicates and candidate eligibility. Creation-only validators preserve update exception contracts
  where required.
- Performance: C14/C15 measure one create-time probe and none for unchanged persisted keys. Other
  create-only validators add one indexed SELECT on validated creation and none on updates; RP anchor
  insert_all still bypasses validators. No throughput benchmark or production query plan was run.
- Raw validation-disabled writes continue to exercise UNIQUE/NOT NULL independently. Conditions
  cover expired unrevoked RP sessions, revoked grant/assignment history, pending-only transfer
  intents, per-entry revision sequences, receipt event/sender scope and infinite ownership periods.

## Per-slice receipts

Commands use `python3 tmp/database-consistency-20261019/run_tests.py STAGE TEST_FILES...` with the
configured test-database manifest and one worker. Detailed test files and behavior are recorded in
cycles.md and the test source. No tests were skipped or removed.

| Receipt                             | Observed result                                          |
| ----------------------------------- | -------------------------------------------------------- |
| grant-red-confirmed                 | 63 runs, 791 assertions, 21 failures, 0 errors, 0 skips  |
| grant-broad                         | 224 runs, 1657 assertions, 0 failures, 0 errors, 0 skips |
| authority-unique-red                | 36 runs, 156 assertions, 24 failures, 0 errors, 0 skips  |
| authority-unique-green              | 152 runs, 1457 assertions, 0 failures, 0 errors, 0 skips |
| rp-live-red                         | 24 runs, 120 assertions, 12 failures, 0 errors, 0 skips  |
| rp-live-green                       | 54 runs, 307 assertions, 0 failures, 0 errors, 0 skips   |
| enforcement-unique-red              | 12 runs, 42 assertions, 6 failures, 0 errors, 0 skips    |
| enforcement-unique-green            | 28 runs, 151 assertions, 0 failures, 0 errors, 0 skips   |
| assignment-unique-red               | 6 runs, 27 assertions, 3 failures, 0 errors, 0 skips     |
| assignment-unique-green             | 34 runs, 197 assertions, 0 failures, 0 errors, 0 skips   |
| pending-transfer-red                | 12 runs, 48 assertions, 6 failures, 0 errors, 0 skips    |
| pending-transfer-green              | 167 runs, 1579 assertions, 0 failures, 0 errors, 0 skips |
| taxonomy-exception-characterization | 24 runs, 132 assertions, 0 failures, 0 errors, 0 skips   |
| taxonomy-position-trial             | 24 runs, 96 assertions, 12 failures, 0 errors, 0 skips   |
| taxonomy-position-restored          | 45 runs, 175 assertions, 0 failures, 0 errors, 0 skips   |
| avatar-grant-red                    | 4 runs, 24 assertions, 2 failures, 0 errors, 0 skips     |
| avatar-grant-green-corrected        | 29 runs, 113 assertions, 0 failures, 0 errors, 0 skips   |
| member-unique-red                   | 2 runs, 6 assertions, 1 failures, 0 errors, 0 skips      |
| member-unique-green                 | 12 runs, 30 assertions, 0 failures, 0 errors, 0 skips    |
| media-key-red                       | 3 runs, 9 assertions, 1 failures, 0 errors, 0 skips      |
| media-key-green-corrected           | 27 runs, 123 assertions, 0 failures, 0 errors, 0 skips   |
| revision-unique-red                 | 24 runs, 72 assertions, 12 failures, 0 errors, 0 skips   |
| revision-unique-green               | 98 runs, 1180 assertions, 0 failures, 0 errors, 0 skips  |
| rp-sender-red                       | 72 runs, 300 assertions, 36 failures, 0 errors, 0 skips  |
| rp-sender-green                     | 114 runs, 643 assertions, 12 failures, 0 errors, 0 skips |
| rp-sender-green-corrected           | 114 runs, 643 assertions, 0 failures, 0 errors, 0 skips  |
| avatar-detail-red                   | 4 runs, 12 assertions, 4 failures, 0 errors, 0 skips     |
| avatar-detail-green                 | 32 runs, 179 assertions, 0 failures, 0 errors, 0 skips   |
| avatar-period-red-corrected         | 2 runs, 8 assertions, 2 failures, 0 errors, 0 skips      |
| avatar-period-green                 | 34 runs, 199 assertions, 0 failures, 0 errors, 0 skips   |
| unique-aggregate                    | 475 runs, 3999 assertions, 0 failures, 0 errors, 0 skips |

## Reverted or corrected attempts

- C20 position uniqueness was tried against already passing duplicate-slug characterization. It
  changed RecordNotUnique to RecordInvalid when both indexes conflicted; all twelve family cases
  failed. Removed precisely that declaration. D1 remains intact; the added
  regression/characterization and FIXME remain, with all twelve findings open.
- C14 initial new tests incorrectly assumed integer zero/false could not reference fixture principal
  id zero. Corrected those new expectations to preserve actual behavior before the confirmed
  Red/Green cycle.
- Avatar and media broad commands initially referenced nonexistent test filenames; loading stopped,
  so these are not passing checks. Corrected to existing test paths and reran. Media test
  preparation applied existing historical test-DB migrations; these are not changes authored by this
  slice or proof of production safety.
- C25 initial Green exposed twelve missing subject translations; added the missing attribute label
  in all four bundles and reran successfully.
- C27 initial setup exceeded the existing moniker length limit; corrected only the new fixture
  before confirming Red.
- Ordinary two-worker Avatar run: 71 runs/326 assertions, zero failures, **eleven errors** because
  committed tests require run-owned worker receipts. Kept that guard intact. Reran with the existing
  isolated parent manifest, explicit run ID and two owned workers: **71 runs/385 assertions, zero
  failures/errors/skips**, including actual ownership concurrency and commit checks. Worker
  cloning/cleanup is the existing verified test harness; no production migration ran.
- Final aggregate after formatting: **475 runs/3,999 assertions, zero failures/errors/skips**.
  Includes every new test, taxonomy exception preservation, numeric boundaries, media
  attachments/ownership, RP callback/revocation/cookie readiness, login cooldown and
  identity-authority guard. Exact selected paths retained locally in `unique-aggregate-files.txt`.
- RuboCop on 70 scoped model/test files: **no offenses**, exit zero. Initial formatting corrected
  only selected slice files; the enforcement test's English sentence fixture was replaced by a
  neutral label to satisfy the existing i18n cop.

## Limits and continuation

No full Rails suite or production migration/data verification was completed for these slices.
Existing DB constraints remain authoritative for concurrent duplicates. The full zero-finding
objective is **not complete**. Exception-driven retries, DB-only/generated uniqueness, redundant PK
preflight and unreviewed consumers remain tracked; do not install validators merely to force zero.
The user requires a breaking change to be reverted; C20 demonstrates that policy.
