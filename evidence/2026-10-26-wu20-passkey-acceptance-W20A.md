# WU-20 passkey acceptance follow-up

Date: 2026-10-26

Commit under test: `bde2346c17e2aa911acc95de1f6035f80498f2da`

The worktree was broadly dirty before this run, with staged, unstaged and untracked changes from
other work. WU-20 changes were also uncommitted. No unrelated changes were staged, reset or removed.

## Acceptance results

| Case | Verification | Result |
|---|---|---|
| A20-5 | `test/controllers/auth/app/in/passkeys_controller_test.rb`, `test/controllers/auth/com/in/passkeys_controller_test.rb`, `test/queries/passkey_sign_in_identity_resolver_query_test.rb` | Missing, empty, malformed, unknown, unverified, released and expired identifiers refuse without authenticating. Ambiguous email/telephone resolution is unreachable for one input under the current disjoint normalizers and unique effective digest indexes. The resolver returns no Identity unless exactly one owner remains. |
| A20-6 | APP/COM passkey request tests above | Disabled, revoked, deleted, unknown and foreign-surface credentials refuse; valid credentials for the selected Identity succeed. |
| A20-7 | APP/COM passkey request tests above; temporary timing probe | Response status/shape/size, redirects, cookie behavior and descriptor privacy are checked. Timing sample recorded below. |
| A20-8 | APP/COM request tests; `test/unit/webauthn/challenge_store_test.rb`, `test/unit/webauthn/verifiers_test.rb`, `test/services/webauthn/verifier_uv_policy_test.rb`, `test/concurrency/passkey_authentication_resubmission_http_test.rb` | Reuse, expiry boundaries, purpose, RP ID, Origin, `userHandle`, signature, UP/UV and concurrent resubmission are covered. The two-connection HTTP race admitted at most one request and preserved the winning Auth session. |
| A20-9 | `test/controllers/auth/org/in/passkeys_controller_test.rb`, `test/controllers/auth/org/in/emergency/passkeys_controller_test.rb`, `test/controllers/auth/org/verification/emergency_step_up_prohibition_test.rb` | ORG Normal remains Entra-bound; Standby remains restricted and cannot Step-Up or gain Normal freshness. Employee Number selection is **not accepted**: current code selects by generated `Operator.public_id`, while the accepted ADR requires an audited authoritative Employee Number. See open issue below. |
| A20-10 | APP/COM passkey request tests above | Reassigning the contact owner between selection and verification refuses; the challenge remains bound to the selected Identity. |
| A20-11 | APP/COM sign-up checkpoint tests, APP/COM/ORG verification registration tests, `test/integration/base_passkey_mutation_step_up_test.rb` | Fixed non-identifying account labels and `residentKey: required` are verified for sign-up telephone, signed-in Identity registration and Base management on all surfaces. |
| A20-12 | `test/controllers/auth/org/verification/passkeys_controller_test.rb` | Missing/false discoverability and UV=false refuse without storing a candidate; `rk: true` and UV=true is the positive control. |

### Focused test groups

- APP/COM request, resolver and WebAuthn tests: **95 runs, 670 assertions, 0 failures, 0 errors**.
- Registration, setup and ORG Step-Up tests: **52 runs, 645 assertions, 0 failures, 0 errors**.
- ORG Normal, Emergency and Step-Up tests: **34 runs, 308 assertions, 0 failures, 0 errors**.
- Passkey integration files: **7 runs, 224 assertions, 0 failures, 0 errors** across
  `base_dashboard_passkey_login_journey_test.rb`, `base_passkey_mutation_step_up_test.rb`,
  `app_passkey_secret_session_step_up_test.rb` and
  `passkey_authentication_resubmission_http_test.rb`.
- `test/unit/security/webauthn_invariants_test.rb`: **9 runs, 20 assertions, 0 failures, 0 errors**.
- RuboCop on 23 changed Ruby files: **no offenses**.

### Identifier timing sample (A20-7)

The temporary test `test/integration/wu20_passkey_options_timing_probe_test.rb` was run once and then
removed. It warmed the known and unknown APP paths once each, alternated 200 known and 200 unknown
requests, cloned the same post-admission cookies for each request, and used a unique test `REMOTE_ADDR`
per request so the production rate limits remained active. Monotonic elapsed time covered each HTTP
request and the existing minimum-response budget; no artificial delay was added. All 400 responses
were HTTP 200.

| Path | Median | p95 |
|---|---:|---:|
| Known identifier | 155.955 ms | 162.193 ms |
| Unknown identifier | 156.009 ms | 163.094 ms |
| Unknown minus known | +0.054 ms | +0.901 ms |

This is a local Rails test-process sample, not a production load measurement.

## Implementation findings

- The APP/COM resolver now requires a finalized, unreleased, non-expired contact in a verified
  status. Unverified and expired bindings no longer select an Identity.
- If WebAuthn returns `userHandle`, assertion verification now compares its decoded bytes with the
  selected actor's immutable handle and refuses a mismatch. The handle remains unused for actor
  selection.
- Invalid or wrong-purpose Auth admission continuation errors now render the established invalid
  admission response instead of escaping the request. The concern was split into a focused helper;
  its behavior is covered by the setup and admission tests above.
- Existing ORG Normal/Emergency and dashboard tests expected a retired HTML continuation form. Their
  request setup now follows the current confirmed-admission GET redirect. No route, database schema,
  or public request shape was changed by this test adjustment.

## Open contract conflict: A20-9 Employee Number

`adr/passkey-identifier-first-sign-in.md` requires Standby selection by the existing authoritative
Employee Number and explicitly says not to guess a model field. It also records that the authority
audit has not been done. Current code instead calls `Operator.normalize_public_id` and looks up
`Operator.public_id`; that value is a generated 16-character Base32 public reference, not an audited
Employee Number. Current tests exercise that public reference, and
`docs/security/passkeys.md` describes the flow as Employee Number, so code, tests and accepted
contract disagree.

No Employee Number column, existing contract or authoritative external source was identified in
`app/`, `db/`, `docs/`, `research/` or `adr/`. No schema or public-identifier guess was introduced.
The user was asked to identify the authoritative source and its contract. A20-9 remains open until
that source is established or the contract is explicitly revised.

## Broad Auth controller run

`bin/rails test test/controllers/auth` completed with **1,210 runs, 9,915 assertions, 52 failures,
95 errors and 0 skips**. Failures include unrelated in-flight Auth entry and OTP tests that still
expect continuation forms or response shapes from an earlier flow, as well as a route-naming test
for a route absent from the current router. The focused WU-20 groups listed above passed. The broad
run remains red and is not represented as a clean suite.

A20-13's documentation result predates this follow-up and was not re-audited in this run.
