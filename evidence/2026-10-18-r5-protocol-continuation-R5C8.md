# R5 protocol continuation and remaining acceptance boundaries

- Date: 2026-10-18 UTC.
- Execution HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`.
- Worktree: substantial pre-existing staged, unstaged and untracked R1-R5 work was present. This
  continuation changes the public OP verifier/UserInfo client, local Refresh committer and its two
  browser callers, domain response validation, their tests and current documentation. It preserves
  the existing worktree and makes no Edge/Jump, credential, deployment or CI change.
- Scope: the user requested implementation through the remaining authorized work, deferred R5-WU03A
  and excluded Edge/Jump modification. `two.md` remains unchanged. No activation occurred.

## Observed defects and fixes

1. A signed Access JWT with another subject was installed by `RpRefreshCommitter`; the local
   subject/issuer/client/realm/epoch binding was not fully checked. Ended OP bindings and disabled
   local principals also did not prevent dispatch. New public-operation tests reproduced both
   defects before the guards were implemented. The locked local identity and session now constrain
   installation; ended local authority prevents dispatch. No external exploit is claimed.
2. Browser callers supplied an opaque session cookie to a primary-key lookup. The committer and both
   callers now use `local_session_id` and a public-ID lookup; missing, unknown and primary-key
   locators refuse without dispatch. The committer selects the cell writer and uses the shared
   binding-before-session lock order; no row transaction spans HTTPS.
3. An uncertain Refresh was forgotten on the next request, permitting another predecessor dispatch.
   Prior input-HMAC attempts are now retained across requests; concurrent in-flight callers do not
   rotate again. Subsequent recovery queries the same receipt. Original deadline expiry refuses
   query, redispatch and late installation. A lost browser response can recover the unchanged
   already-installed generation inside that deadline, without another generation write.
4. `umx_contract_epoch: 1.0` passed the integer-epoch verifier through numeric equality. A signed
   regression reproduced it; verification now requires an Integer and the exact expected value.
   Added public JWKS cache/stale-boundary and successful-key-removal cases.
5. UserInfo 429/malformed success could be treated as credential refusal. The existing public
   interface moved coherently to `OidcOpUserInfoClient` in adapters; all current callers/tests
   migrated without an old-name alias. Known OAuth refusals remain distinct from dependency or
   invalid remote responses, and successful subjects must be nonblank strings.
6. Tech and the Publishing/Avatar/Membership/administration clients raised on non-object JSON. New
   transport-boundary cases reproduced the errors. Tech now requires an object with boolean
   `allowed: true`; other clients classify non-object JSON as dependency failure rather than
   treating it as owner data. Existing owner policies/Operations and wire endpoints are retained.

## Verification performed

Environment for Rails commands:

```text
RAILS_ENV=test
PARALLEL_WORKERS=1 (focused) or 8 (full suite)
UMAXICA_ENV_FILE=.env.devcontainer.example
POSTGRESQL_ISOLATED_TEST_RUN_ID=20261017c1a2
POSTGRESQL_ISOLATED_TEST_MANIFEST=/home/global/workspace/tmp/acceptance-isolated-20261017c1a2.json
POSTGRESQL_TEST_PREPARE_DATABASES=<comma-joined database names from that verified manifest>
```

The existing DatabaseSafety checks accepted the 32-database isolated fleet, owner `root`, local
server `10.89.0.3/32:5432`, PostgreSQL 18.6. The first invocation omitted the manifest-derived
preparation list: DatabaseSafety refused the old default targets before assertions. Supplying the
manifest's exact names corrected the invocation; the safety check was not weakened.

- Initial three-file protocol/Refresh baseline: 26 tests, 98 assertions, no failures/errors/skips.
- Regression reproduction: Refresh subject/local-authority tests failed against the prior
  implementation; floating-point epoch and non-object domain responses also reproduced their
  respective acceptance failures before correction.
- Final focused command:
  `bin/rails test test/operations/rp_refresh_committer_test.rb test/operations/rp_refresh_logout_concurrency_test.rb test/adapters/oidc_op_protocol_verifiers_test.rb test/adapters/oidc_op_token_client_test.rb test/adapters/oidc_op_user_info_client_test.rb test/adapters/domain_authority_protocol_test.rb`.
  Result: **44 tests, 321 assertions, 0 failures, 0 errors, 0 skips**.
- The committed-row concurrency test uses two distinct PostgreSQL backends and a Queue barrier:
  Refresh pauses at the transport boundary; logout commits on the other connection; delayed response
  installation refuses. A standalone run passed with 1 test and 8 assertions. This is local DB
  concurrency proof, not an actual remote OP commit-response-loss experiment.
- Deadline cases cover one microsecond below/at/above the local attempt deadline using the public
  cell database clock seam. Cache trust cases cover below/at/above fresh/stale boundaries.
- First full-suite checkpoint, before the later attempt-reuse/deadline refinements:
  `bin/rails test --seed 42061`, 8 workers: **15,495 tests, 132,202 assertions, no
  failures/errors/skips**. This earlier checkpoint is not a full-suite result for the final refined
  source.
- Final refined-source full suite: `bin/rails test --seed 42061`, 8 workers, same verified fleet:
  **15,502 tests, 132,243 assertions, 0 failures, 0 errors, 0 skips**, exit 0. Reported test time
  was 372.568746 seconds; that is local test execution time, not a regional latency/capacity SLO.
  The 20 affected source/test files were hashed before execution and matched afterward; the sorted
  JSON path/hash snapshot SHA-256 was
  `4234d4089216d0f7c42429df6209b873552d16efec563eeca6b0c18ed1d2f043`.
- RuboCop on the 20 affected Ruby files: **20 files inspected, no offenses**.
- `bin/rails zeitwerk:check` under the isolated test configuration: **All is good!**
- Scoped `git diff --check`: PASS. Read-only search found no old UserInfo constant/path references
  in `app`, `lib`, `test` or `config`. Historical evidence was retained.

## Acceptance limits

These observations support protocol and local-concurrency portions of TC-R5-04-001, TC-R5-05-001,
TC-R5-08-001, the local logout/installation scenarios and domain-client failure handling for
WU11-WU15. They are not full Gate or deployment PASS results.

- WU03A/INV-007 effective secret/process/worker isolation is deferred by the user, not passed.
- WU05 independent OP receiving capacity and actual same-FQDN HTTPS load proof are NOT_RUN; the
  current shared development process does not establish them.
- WU08's actual admitted 2-second initial / 1-second receipt / 4-second total recovery targets
  remain unproven. Existing 2/5-second adapter open/read constants do not establish that budget; the
  local expiry guards prevent late authority installation but are not performance evidence.
- Real Edge/Jump-dependent acceptance, real stopped-Queue worker recovery, full pre/post-cutover
  credential rehearsal and postactivation per-cell acceptance were not executed here. This
  continuation does not weaken their requirements or infer success from in-process tests.
- WU18's shared-role OP-chain removal remains tied to the blocked cutover; WU18A/WU19/WU20 and full
  R5 release acceptance remain open. No old-profile authenticator was activated or restored.
- US runtime remains NOT_RUN. Preserved-data restore is NOT_APPLICABLE under section 1.2A.
- Mermaid parser execution remains deferred under the existing repository instruction; the derived
  local-attempt diagram/inventory/checklist were updated, without claiming parser PASS.

Implementation report: `three.md` REP-20261018-0001. This evidence changes no acceptance status.
