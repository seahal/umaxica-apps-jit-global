# Nine acceptance decision after scoped exclusions

Date: 2026-10-13. Repository: `/home/global/workspace`. Full HEAD:
`4828aeedd141b54163236672890799b9b01128c2`. The worktree includes the OTel correction, acceptance
documentation and behavioral tests from the preceding follow-up. This assessment additionally
changes the ORG passkey controller test and adds
`test/models/setting_preference_public_id_immutability_test.rb`. No application behavior, migration,
dependency or global test helper was changed in this final assessment. No commit, production access,
external mail or telemetry export was performed.

## Decision and scope

**REJECTED.** The current implementation fails the permanent-identity database requirement and the
durable authentication-halt audit requirement. Successful previous suite counts did not cover these
missing negative cases. The new assertions intentionally preserve the approved expectations; they
are not skipped or weakened to turn the acceptance green.

The user excluded actual Alloy execution/effective host mounts, unresolved personal-data policy
decisions and their dependent work, and production cutover/recovery assurance. The owning scope
decision is in `specs/integrated-stack-delivery/acceptance.md`; deferred work is in `seven.md`,
Section 13. The previously observed JavaScript coverage shortfall also has a delivery-specific
exception. None of those exclusions covers either failure found here.

This is a rejection decision with bounded observations, not a claim that every possible route,
provider, actor or database writer has been exhaustively certified. Criterion dispositions below
keep remaining evidence gaps explicit. Historical chronology cannot be reconstructed by a new test.

## Reproduced failures

### ID-4: three setting preference identities accept replacement

The new Minitest covers `AppPreference`, `ComPreference` and `OrgPreference`, each through
`update_columns`, `update_all`, `upsert_all` and direct SQL: twelve public/database boundary cases.
Each creates a synthetic preference and attempts to replace its generated ID with a different valid
21-character value in a savepoint. The expected database rejection does not occur in any case. The
earlier rollback-only reload probe in `N6A2` also confirmed persistence of the replacement. Ordinary
model validation and length/uniqueness constraints do not provide this immutability.

The tests require both database refusal and preservation of the original value. They run on the
verified disposable test fleet with transactional fixture cleanup. A production database mechanism
was not introduced as part of acceptance; its scoped authority still follows PROC-2.

### FLOW-6: ORG normal sign-in halts without a durable audit

The existing ORG passkey integration test now continues from its actual locally simulated Entra
callback and successful normal passkey page. It tests missing, empty, malformed and signed stale
generation bindings on GET/HEAD: each refuses safely without changing the transaction. A public
codec creates the synthetic signed generation mismatch; the test does not claim a browser can forge
that signature.

The attributable POST returns the required 409/plain refusal and marks the session transaction
halted with `phase_violation`. Neither it nor replay creates a passkey challenge or token. However,
the `OperatorChronicleEvent::SIGN_FLOW_HALTED` record count increases by zero, not one.
`OrgNormalSignInTransaction#halt_org_normal_sign_in_transaction!` writes only session state; its
refusal logger is not the durable audit required by nine Section 7.3 / FLOW-6.

The initial exploratory assertion also observed replay returning 422 and clearing the session
transaction. Those observations alone are not treated as an additional defect: cleanup and non-phase
error contracts are distinct from terminal resurrection. The final regression asserts no new
artifacts and the definite missing audit, without requiring indefinite session retention or an
unproven replay response contract. An earlier test-authoring error used `assert_equal` with nil; it
was corrected to `assert_nil` and is not counted as an application defect.

## Actual local mail delivery capture

`RAILS_ENV=development OPEN_TELEMETRY=true OTEL_TRACES_EXPORTER=none OTEL_METRICS_EXPORTER=none OTEL_LOGS_EXPORTER=none bin/rails runner /tmp/nine-actual-mail-capture.rb`
succeeded against the actual initializer and installed instrumentation. All three concrete OTP
mailers used the local test delivery adapter; the OTP delivery job used the inline adapter. Only the
suspension lookup and deliberately failing local delivery adapter were controlled collaborators. No
SMTP, external collector or production data was used.

For each surface: `deliver_now` succeeded with usable synthetic OTP content; `deliver_later`
executed successfully; a local delivery failure propagated; an explicit retry succeeded; suspension
prevented delivery. Nine messages were delivered locally in total. This is not a claim about
automatic retry policy or live queue scheduling.

The in-memory exporter captured 30 mail spans. Their combined attribute keys were exactly `action`,
`mailer`, `email.x_mailer`. Synthetic OTP and verification-token/address markers were absent from
all captured span attributes/events and the DEBUG application/job logger. Each concrete mailer
logger remained nil; SDK force_flush returned numeric success. Together with the earlier unknown-key
notification capture and flush/shutdown checks in `F7K2`, this supplies current local MAIL-2/3
evidence. It does not claim all downstream sinks or automatic exporter installation.

## Criterion dispositions

Execution results:

| Command/check                                                           | Result                                                                                   |
| ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Full `bin/rails test`, verified p8b fleet, four workers                 | 15,238 runs, 128,887 assertions, 13 failures, zero errors/skips; 334.65 seconds, exit 1. |
| Final two-file `bin/rails test`, same fleet, one worker                 | 29 runs, 160 assertions, 13 failures, zero errors/skips; 7.12 seconds, exit 1.           |
| Targeted RuboCop for the two changed Ruby tests                         | Two files, no offenses.                                                                  |
| Repository knowledge checker with changed checklist/plan/evidence paths | Passed; selected 68 documents and one evidence record.                                   |
| `git diff --check`                                                      | Passed.                                                                                  |

The full run had already loaded the exploratory ORG assertion before its final narrowing to the
definite durable-audit requirement. The final two-file rerun verifies the final test source and
reproduces exactly the same twelve identifier failures plus one audit failure. The full suite was
not redundantly rerun after that assertion-only refinement; no application behavior changed. The
final audit failure explicitly reports expected 1, actual 0. No unrelated test failed in the full
run. JavaScript and prior static/schema results remain the executions recorded in N6A2/F7K2; they
were not rerun or relabeled as new executions here.

Rails invocations used the N6A2 command wrapper with `RAILS_ENV=test`,
`POSTGRESQL_ISOLATED_TEST_RUN_ID=20261010p8b`,
`POSTGRESQL_ISOLATED_TEST_MANIFEST=tmp/acceptance-isolated-20261010p8b-primary.json`,
`POSTGRESQL_TEST_HOST=primary`, `POSTGRESQL_DATABASE=postgres` and all 20 manifest names supplied to
`POSTGRESQL_TEST_PREPARE_DATABASES`. The final focused paths were
`test/models/setting_preference_public_id_immutability_test.rb` and
`test/controllers/auth/org/in/passkeys_controller_test.rb`. After both test processes exited, the
read-only postflight verified all 20 parent database identities and zero remaining worker databases.
No manual cleanup or parent reset was needed.

References `N6A2` and `F7K2` denote the same-date evidence files with those filename suffixes. Their
executions occurred in this conversation at the same HEAD; dirty scope is stated separately. PASS
below is limited to the described local scope. PARTIAL means acceptance remains unclosed; it is not
converted to PASS because the global decision is already a rejection.

| Criterion | Disposition                                         | Evidence and remaining boundary                                                                                                                                                    |
| --------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ID-1      | PARTIAL                                             | N6A2 catalog: 20 writers, 892 tables, only framework PK exceptions; ordinary creation for every individual owned table is not independently mapped.                                |
| ID-2      | PARTIAL                                             | PublicId issuance/capacity and model/bulk tests exist and ran; complete semantic writer classification is not established by column names.                                         |
| ID-3      | PARTIAL                                             | Concrete protocol/ceremony subcontracts and tests exist; all producer/consumer classification remains unclosed. ID-3a–q are bounded slices, not blanket approval.                  |
| ID-4      | FAIL                                                | Twelve setting preference replacement cases; earlier reload probe confirms changed identities. ID-4a–f narrower migration/capacity guarantees do not repair this parent invariant. |
| ID-5      | PARTIAL                                             | Named collision/savepoint/budget regressions pass in the prior full suite; exhaustive classification of every retrying issuer remains unclosed.                                    |
| ID-6      | PARTIAL                                             | Catalog has no Hash/invalid/unready indexes; complete role-specific collation/ordering/partition review is not established by that scan.                                           |
| ID-7      | PARTIAL                                             | Existing protocol and legacy-reference regressions execute; complete external-consumer continuity is not independently certified.                                                  |
| ID-8      | FAIL                                                | Newly added negative assertions expose the previously uncovered ID-4 defect.                                                                                                       |
| CONTACT-1 | PARTIAL                                             | Six-model lifecycle, receipt, finite deadline and channel-specific tests execute; complete caller/policy inventory remains unclosed.                                               |
| CONTACT-2 | PARTIAL                                             | Realm HMAC rotation and maintenance-boundary tests execute; this is not permission or proof for live key maintenance.                                                              |
| CONTACT-3 | PASS, local six-model scope                         | Realm encryption and isolated rotation-drill tests, plus safe application boot; unrelated PII reassignment excluded by the criterion.                                              |
| CONTACT-4 | PARTIAL                                             | Six concrete lifecycle/receipt/terminal/concurrency suites and recovery/withdrawal-to-registration isolation exist; complete public purpose/provider mapping remains unclosed.     |
| CONTACT-5 | PARTIAL                                             | Bound delayed/Noticed/registration transport and stale-proof cases execute; complete source/fixture/constraint retirement inventory remains unclosed.                              |
| CONTACT-6 | PASS, tested six-model races                        | Actual six-model normalized creation plus purge/reuse and duplicate-purge concurrency tests; F7K2 corrected the initial unmapped status.                                           |
| CONTACT-7 | PARTIAL                                             | Public purge/rollback/owner and three-principal cross-DB retry tests execute; every raw/bulk whole-owner path is not certified.                                                    |
| CONTACT-8 | PARTIAL                                             | History-shape, keyed fingerprint and repeated-history checks execute; exhaustive maintenance/consumer misuse review remains unclosed.                                              |
| CONTACT-9 | PASS for local visibility/deferral; policy EXCLUDED | History visibility/retention tests; unresolved policy is explicitly outside this acceptance.                                                                                       |
| FLOW-1    | PARTIAL                                             | Actual APP/COM/ORG route and negative-route tests plus root establishment; complete family applicability and authority mapping remains unclosed.                                   |
| FLOW-2    | PARTIAL                                             | APP/COM sign-up and MFA plus new ORG normal-passkey safe GET/HEAD checks; not every phase endpoint is independently exercised.                                                     |
| FLOW-3    | PARTIAL                                             | Active phase violation, terminal no-new-artifact and lifecycle tests execute; every independent-connection family transition is not certified.                                     |
| FLOW-4    | PARTIAL                                             | APP/COM replacement-flow and binding negatives plus codec tests; complete cross-family callbacks remain unclosed.                                                                  |
| FLOW-5    | PARTIAL                                             | Two-tab, committed account, root issuance and existing session/concurrency tests execute; this does not certify every consumer race.                                               |
| FLOW-6    | FAIL                                                | Attributable ORG normal-sign-in halt produces no durable halt audit.                                                                                                               |
| AV-1      | PARTIAL                                             | Concrete provisioning and four-direction operations execute; every retained-data writer is not independently certified.                                                            |
| AV-2      | PASS, isolated temporal boundary                    | Real COMMIT adjacency/gap/overlap/ownerless/history cases, concrete transfer tests and local cutover rehearsal.                                                                    |
| AV-3      | PARTIAL                                             | RC/RR/Serializable period races and registry races pass; full operation-level lock/failure scheduling remains unclosed.                                                            |
| AV-4      | PASS, local registry boundary                       | Shared registry/cardinality, request tuple and concurrency tests; no cross-family key namespace substitution.                                                                      |
| AV-5      | PARTIAL                                             | APP/ORG transport authority, key validation and replay cases execute; all actor/client-transition permutations remain unclosed.                                                    |
| AV-6      | PARTIAL                                             | Four-direction transitions, expiry neighbors and persistence-failure rollback/retry are covered; complete lock-wait/serialization scheduling is not certified.                     |
| AV-7      | PARTIAL                                             | Persona/Agent capability, revocation, non-owner and historical-generation refusal tests execute; full N:M subject/capability matrix remains unclosed.                              |
| AV-8      | PARTIAL                                             | Independent account context and membership consequences are covered; synthetic Group backfill/cutover passed, not every retained-data consumer reconciliation.                     |
| AV-9      | PASS for deferral; policy EXCLUDED                  | Idempotent observable retention deferral retains Avatar/history; final personal-attribute policy is excluded.                                                                      |
| MAIL-1    | PASS, local filtering                               | Positive/negative exact-key and nested filtering tests; no all-sink claim.                                                                                                         |
| MAIL-2    | PASS, local adapter scope                           | Actual three-surface DEBUG capture, now/later/failure/explicit retry/suspension; existing delivery/Noticed regressions.                                                            |
| MAIL-3    | PASS, local pre-export boundary                     | Actual 30-span capture plus F7K2 unknown-key capture and numeric flush/shutdown; no external delivery claim.                                                                       |
| MAIL-4    | EXCLUDED                                            | User excluded actual Alloy processor execution.                                                                                                                                    |
| MAIL-5    | PASS declaration; runtime EXCLUDED                  | N6A2 static read-only/shared-label declaration; effective host mount is excluded, not assumed passing.                                                                             |
| MAIL-6    | PASS for this investigation                         | Local synthetic scope preserved; production/broader owner-review closure is not claimed.                                                                                           |
| PROC-1    | PASS for this investigation                         | Same checkout/HEAD, previous work retained, scoped test/document changes only.                                                                                                     |
| PROC-2    | PASS for this investigation                         | No new DB mechanism or broadened trigger authority introduced; required identifier guarantee remains failed.                                                                       |
| PROC-3    | PARTIAL                                             | Existing current full suites/gates recorded; JS coverage exception applies, historical TDD cadence cannot be reconstructed, new negatives fail.                                    |
| PROC-4    | NOT_RUN for historical chronology                   | No new feature implementation accumulated in this assessment; prior agents' hold chronology is not inferred.                                                                       |
| PROC-5    | PARTIAL                                             | Current failure evidence and test references recorded; implementation and all remaining behavioral criteria are not declared complete.                                             |
| PROC-6    | NOT_APPLICABLE to this assessment                   | No commit requested or made; historical document-persistence compliance is not certified.                                                                                          |
| MIG-1     | PARTIAL                                             | F7K2 fresh migrations, 20-database restore and synthetic identity/sequence preservation; complete mixed-version and per-table transition coverage remains unclosed.                |
| MIG-2     | PARTIAL                                             | Fresh migration/rebuild/restore and bounded backfill/cutover passed; complete historical six-draft provenance/reverse-object lifecycle is not re-established.                      |
| MIG-3     | PASS, isolated exercised boundaries                 | Real-COMMIT and three-isolation tests, four-direction failure injection, repeat 20-DB/12-role rebuild, foreign-dependency refusal and restore cleanup in F7K2.                     |
| MIG-4     | PARTIAL; production portion EXCLUDED                | Real committed synthetic cutover, writer-not-quiesced refusal, marker replay and legacy barrier passed; full local consumer reconciliation remains unclosed.                       |

## Coverage interpretation

The actual route-contract tests cover APP/COM/ORG and unsupported endpoints; ORG MFA absence has
explicit tests, so APP/COM MFA is not silently extrapolated to ORG. The six concrete contact models
have generated cases for lifecycle/receipts/terminal SQL behavior and independent-connection races.
Cross-database child purge tests cover Client, Visitor and Operator partial-failure retry. Avatar
tests include both concrete subject families, generation-bound Grants, four transfers, idempotency
and failure rollback. Those observations improve the earlier mapping, but do not prove all
combinations in the broader strict authentication/authority contract.

The known failures are sufficient to reject this delivery. Subsequent implementation must repair
them and close the remaining PARTIAL criteria before a positive acceptance decision; the user has
not waived those criteria. Passing the two new regressions alone would not justify global PASS.
