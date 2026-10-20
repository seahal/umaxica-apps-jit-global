# Database consistency resumption and content-digest validation

Date: 2026-10-20 UTC. Revision: `87c15e1e5d89344db7dcaaa85ebb1f6972c0c829`, branch `feature`. The
worktree was already extensively dirty: retained model/test/locale remediation, untracked
migrations/specification/evidence, configuration changes, structure dumps, and deleted old outputs.
No commit, migration execution, dump regeneration, production access or external write was performed
by this session. Those preexisting changes affect the results below. Tracked binary diffs and staged
state were captured before work; a later per-file comparison found no changes outside the four
locale bundles and the newly modified encrypted-content Concern. The staged diff remains identical.
Existing untracked artifacts were retained; the plan/cycles/historical ledger were extended in
place.

## Phase 0

- Runtime/catalog: Ruby 4.0.7, Bundler 4.0.23, Rails/ActiveRecord 8.2.0.alpha, database_consistency
  3.0.16. Rails source `72ffadb2073a6f81696f4f6559eb6a7ce70496c7`; local checker fork
  `d5d1781f3d642b428d6a9654099b0cd96ce52fd8`.
- Read-only inventory: 893 concrete existing-table models, 30 model-owned development connections,
  32 test writers. Every queried server reports PostgreSQL `18.6 (Debian 18.6-1.pgdg12+2)`. No
  pending migration versions on any inventoried development/test connection. This does not prove
  reconstruction, schema-dump equality or production applicability.
- `bundle exec database_consistency`: exit **1**, completed with **1,895 displayed failures**.
  Unsuppressed report capture: **1,910 individual failures**, 18,526 OK reports and one warning. No
  error-status reports/internal checker failure. CLI grouping explains the 15-line difference.
- Relative to the previous 2,177-individual-failure baseline, 271 identities are absent and four
  newly visible OperatorLifecycleRequest deletion-policy failures are present. These differences
  include preexisting migrations/model edits; they are not this session's implementation count.
- All configured checkers enabled, and exactly the same 873 project-model targets as the prior
  target receipt. The broader 893-model catalog includes twenty third-party classes filtered by the
  checker's unchanged upstream project-class selection, not by a new task exclusion.
- Preserve existing contract conflicts per the user's explicit 2026-10-20 reply. PublicId remains
  generation 21 / storage validation capacity 25; no CHECK/column is narrowed or widened.
- Stable-ID current ledger covers all 2,178 historical non-OK identities plus four new ones,
  including absent records. See `specs/database-consistency-remediation/current-findings.md` for
  checker/domain totals and current status, and `findings.md` for historical cause/index/FK/test
  mappings.
- Resumption test command, through the existing runner (exact current prepare list, one worker):
  PublicId generation/capacity, three token reference catalogs, snapshot reference capacity,
  projected-record validation, nullable step-up evidence: **185 runs, 3,180 assertions, zero
  failures/errors/skips**, exit 0. Full logs/exit:
  `tmp/database-consistency-20261019/resume-20261020.*`.

## C10

One root cause, 24 concrete revision/version models: missing creation-time content_digest format and
length validation against the existing canonical SHA-256 contract and physical constraints. Added
exact length 64 and lowercase hex alphabet only on create in PublishingEncryptedContent, plus the
content_digest label in all four canonical locale bundles. Valid digest producers, encryption,
restore/promotion, duplicate contracts and immutable updates are retained. Malformed model create!
now raises RecordInvalid before SQL; direct SQL still rejects NULL, invalid format and oversized
values. No uniqueness SELECT, callback, trigger, schema or migration is added.

- Red: `run_tests.py digest-red-20261020 test/models/publishing/content_digest_contract_test.rb`:
  **24 runs, 612 assertions, 12 expected failures, zero errors/skips**, exit 1. The twelve normal
  persistence/direct-SQL/version-immutability characterization cases passed before implementation.
- Green: digest, version snapshot, revision/version sequence and digest-producer tests: **133 runs,
  4,860 assertions, zero failures/errors/skips**, exit 0.
- Broader `test/models/publishing test/operations/publishing`, digest producer and locale bundle
  integrity: **376 runs, 9,659 assertions, zero failures/errors/skips**, exit 0.
- Final strengthened public save! and promoted-revision guard checks: **24 runs, 3,180 assertions,
  zero failures/errors/skips**, exit 0. Receipt prefix:
  `tmp/database-consistency-20261019/digest-final-guards-20261020`.
- Scoped final RuboCop: two files inspected, no offenses, exit 0. `git diff --check` passed.
- The new test file contains **24 tests**, covering every one of the **24 model consumers**. Both
  creation boundaries (63/64/65), missing/empty/boolean/zero/wrong alphabet inputs, independent DB
  writes, both-language full errors, immutable version updates and promoted-revision DB refusal are
  exercised. Existing DB checks and savepoint rollback preserve stored digests.
- Full default checker after: exit **1**, **1,871 displayed failures**; raw **1,886 individual
  failures**, 18,550 OK, one warning. Exactly 24 LengthConstraint/content_digest identities removed;
  no new non-OK identity. All checker states/targets retained. Per-checker and connection totals in
  current ledger.
- The 24 content_digest NullConstraint reports stay open because this checker recognizes neither
  length nor format as rejection of nil. Adding redundant presence just for the count was rejected.

## Unverified / failed checks

`bin/rails db:verify_no_schema_drift` exits 1 **before completing comparison**, with
`ArgumentError: HMAC definer role does not match database development_com_zenith_db`. Its
implementation dumps to temporary files and preserved worktree dumps. Do not report this as
successful schema verification or as a completed inventory of drift. No role/configuration change
was attempted to bypass it. The full Rails suite was not run this session; prior full-suite evidence
is historical and contains failures. No production data preflight, migration rehearsal, lock/EXPLAIN
measurement, rollback or production safety claim is established. This slice has zero migrations.
Zero findings and overall task completion remain **unachieved**.

## Artifact digests

Untruncated stdout/stderr, report and catalog JSON, worktree snapshots and exit receipts remain
locally under ignored tmp paths; raw logs are not placed in evidence.

| Artifact                                                  | SHA-256                                                            |
| --------------------------------------------------------- | ------------------------------------------------------------------ |
| `tmp/database-consistency-20261020/full.stdout`           | `290e0f2933c4ac5312e860cfca0b425d78634842bd3130519d611c29b74b197f` |
| `tmp/database-consistency-20261020/full.stderr`           | `29a30b3f0fbed7a4546448b5caefd02a0f83990103d198068467eeece3307de0` |
| `tmp/database-consistency-20261020/raw.json`              | `0c7f3b678eed6fafd84efdebc1fea7ae225694976aeda07d47eb3e2519bce984` |
| `tmp/database-consistency-20261020/inventory.json`        | `f87451adf64d01a1a7d9aedbd53adbe5bd4add9a7c2fce77e9f0ed2c21a4697f` |
| `tmp/database-consistency-20261020/test-inventory.json`   | `f4e423183df66858791e8fe87455e6333efde7ec3c626f25545b8869ff7402f0` |
| `tmp/database-consistency-20261020/after.stdout`          | `05251e0d08f49be42498140222c60c697456e4fe9b07ae874d6c906f52069bc0` |
| `tmp/database-consistency-20261020/after.stderr`          | `667e9c1cc2e75464c0176e341ac0974b40c85bcf53daddd715c91aa5d929b877` |
| `tmp/database-consistency-20261020/after-raw.json`        | `fe57f631fc554bd3cfbd7ae8ae46514210e344d3ceadd0acfeacdb2f2bca6b73` |
| `tmp/database-consistency-20261020/after-targets.json`    | `971661acdce3855eb23f98ce641b02b5dba0f45184ca4b2f9cba30d716ecf5ac` |
| `tmp/database-consistency-20261020/git-status.before`     | `ac6220ba9be143cf642c679cccb744a02ab9fddaf6f1eb56b61767541c1a6a99` |
| `tmp/database-consistency-20261020/worktree.before.patch` | `ccf9d4c0b11b8a42fb069354db51077772a959d791759fc06ac5f2e970a9aea8` |
