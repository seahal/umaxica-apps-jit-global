# WU-26 diagnosis input and correlation follow-up

Date: 2026-10-26

Commit: `bde2346c17e2aa911acc95de1f6035f80498f2da`

The worktree was already dirty and contained staged, unstaged and untracked changes. The WU-26
query/test files had staged additions before this follow-up; those index entries and all unrelated
work were preserved. Verification ran against the modified worktree. No files were staged and no
schema change was made.

## Delivered

`SignUpAttemptDiagnosisInventory.call` now accepts exactly one selector: `flow_public_id`,
`entry_reference_digest`, `principal_public_id`, or `provider` plus `subject_digest`. Public ids and
lowercase SHA-256 digests are format-checked; nil, empty, raw reference/subject values, unknown
providers, partial selectors, ambiguous selectors and unsupported surfaces are refused. Unknown
well-formed inputs return `flow_not_found`; multiple matching Flows are all returned under
`multiple_attempts_found`.

The report includes OIDC transaction/result lifecycle fields, ceremony session ids and lifecycle
timestamps, APP social Candidate ids/states, principal `access_enabled?` and External Identity state,
audit outbox event ids/names, Chronicle request/event ids, and a structured-log search key. It does
not emit contacts, provider subjects, candidate refs/digests/auth hashes, session digests, OIDC
secrets or outbox payloads. APP and COM lookups remain surface-local; social Candidate lookup is
APP-only. Reads use the reading role with writes prevented, and an existing writing scope is
refused.

The existing reference digest was exposed through
`Valkey::AuthState::OpaqueAdmissionStore.reference_digest` and reused by the query. This keeps the
`SHA256("reference:<reference>")` algorithm in one place. Entry-reference lookup computes it for
each sign-up Binding in the selected OP database. Social-subject lookup decrypts and hashes matching
APP sign-up Candidate subjects in memory. These scans are kept read-only and introduce no database
column or index; large retained tables may make diagnostics slow. Structured logs remain externally
searched using the returned surface/Flow key rather than being queried by Rails.

The stuck-registration runbook and sign-up sequence documentation now list the selectors and output
limits. The WU-26 delivery ledger records this as a follow-up, not full D-82 closure. Remaining D-82
scope includes graph-owner detail beyond Identity presence, grants/RP-session timestamps,
replica-lag/unavailable-database reporting, and full runner acceptance.

## Verification

- `bin/rails test test/queries/sign_up_attempt_diagnosis_inventory_test.rb test/services/valkey/auth_state/opaque_admission_store_test.rb` — **27 runs, 101 assertions, 0 failures, 0 errors, 0 skips**.
- `bin/rubocop app/queries/sign_up_attempt_diagnosis_inventory.rb app/services/valkey/auth_state/opaque_admission_store.rb test/queries/sign_up_attempt_diagnosis_inventory_test.rb test/services/valkey/auth_state/opaque_admission_store_test.rb` — **4 files inspected, no offenses**.
- `git diff --check` — passed.
- An initial focused query-test run had 3 test-construction errors (COM realm selection, lifecycle state setup, and Candidate return shape). The test setup was corrected; the final combined run above passes.
- The full Rails suite was not run.
