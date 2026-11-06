# Review 8: contract revision 6

Date: 2026-11-03. Disposition: **unit 0 is ready for the owner's formal acceptance**. No new
blocking finding was identified in this review. This is design-review readiness, not acceptance by
the owner, implementation authorization or runtime verification.

HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, with extensive existing uncommitted changes.
Reviewed the latest board request, contract revision 6, synchronized spec risks, ADR amendment
drafts and the relevant source/test boundaries. Earlier reviews remain historical records.

## Disposition of review 7

| Finding                                       | Revision-6 disposition and evidence                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RV-97 — DPoP on the step-up code exchange     | Addressed at contract level. `contracts/contract-draft.md:156-166` explicitly applies the existing-grant proof/key rule under issuance locks, preserves the key in issued credentials and refuses bound Base grants until the adapter supports proofs. The source distinction remains confirmed: `app/services/oidc_token_exchange_coordinator.rb:352-367` checks the existing refresh binding, while `:1200-1212` only validates a presented code-exchange proof. The adapter at `app/adapters/oidc_op_token_client.rb:37-47,60-85` currently sends no DPoP header. Explicit refusal closes the gap without expanding this change into a new proof-producing adapter. |
| RV-98 — Retention class selected by new names | Addressed at contract level. Contract `:259-268` explicitly assigns authentication outcomes to `compliance` and request/rejected-attempt observations to `security`, with entries in the owning policy instead of relying on fallback. This matches the existing success/failure classification at `app/policies/chronicle_record_policy.rb:28-29`; its default is separately `security` at `:88-94`. Proposed result values fit `Chronicle::RESULTS` at `app/models/chronicle.rb:48,64`.                                                                                                                                                                              |

The statement that Base grants are expected to be unbound is a proposed guarded invariant, not a
demonstrated inventory of every existing grant. No grant data was queried. Its safety depends on
refusing a bound grant before issuance, not on assuming such a grant can never arrive. That refusal
and the absence of event/refresh/binding mutations need a public endpoint regression test.

## Remaining points checked

- C-3: contract `:243-284` now supplies result, retention and per-event payload-key mappings. This
  is sufficient to close the earlier unit-0 omission. Implement closed payload validation with
  explicit types and allowed categorical values; test sanitization, identity comparison, repeated
  delivery and erasability. These are implementation obligations, not completed tests.
- C-8: contract `:370-372` proposes a 15-minute RP pending lifetime and a 60-second dispatch/
  installation deadline. The cited OP default is confirmed at
  `app/services/oidc_authorization_transaction_coordinator.rb:20-40`. Equal lifetime durations do
  not require identical absolute expiry timestamps: the RP starts earlier and must enforce its own
  stored expiry. Installation checks both limits independently of sweep scheduling.
- RV-93 integration note: contract `:123-134` now explicitly replaces the coordinator's initial
  boolean authentication call with one result-producing verification and carries that result to code
  classification. Keep one underlying verification implementation and one JTI consumption.
- RV-96 ordering note: contract `:177-183` checks DISPATCHING before any timeout transition.
  Terminal-state absorption is now explicit; the named writer and lock decide the winning outcome.
  The transition uniqueness index alone cannot serialize two different target states.
- Spec synchronization: `spec.md:138-156` points to revision 6 and removes the stale undecided
  class/shapes and consumption-count claims. The retained purposes and single-cutover scope remain
  explicit. ORG parity remains required rather than inferred from APP coverage.
- ADR drafts retain the recorded Q-1 decision, distinguish reusable evidence from single-use
  ceremony correlation, and explicitly identify removal of the authenticating credential's
  continued-activity check as a policy change for acceptance
  (`contracts/adr-amendment-drafts.md:31-40,69-77`). No new owner policy choice is proposed here.

## Acceptance and implementation handoff

The unit-0 proposal can be presented for formal acceptance with its existing explicit tradeoffs: the
reusable 300-second event, refresh rotation and possible sign-in recovery after a lost response, the
authenticating-credential activity policy change, and the pending/dispatch durations. This review
does not reopen recorded owner decisions or apply the ADR amendments.

After authorization, the implementation must demonstrate the proposed properties through the public
boundaries already identified in the plan: APP/ORG request and issuance parity, proof and
signed-expectation refusals, atomic event/token/outbox commit, generation and terminal-state races,
deadline boundaries, retained-purpose behavior, TOTP enforcement attribution, and durable Chronicle
delivery with the required retention reference rows. DBSC preservation and the next device-session
refresh proof remain required. Failures and missing evidence must remain explicit.

Relevant existing coverage was inspected, including DPoP cases in
`test/services/oidc/token_exchange_service_test.rb:2457`, policy selection in
`test/policies/chronicle_record_policy_test.rb:67-78`, and indeterminate refresh dispatch in
`test/operations/rp_refresh_committer_test.rb:183-209`. These tests were not run and do not yet
verify the proposed step-up path. No new blocker is inferred merely because implementation and its
future acceptance tests have not started.

Only this review and the append-only `zero.md` response were authored. No application, test, spec,
plan, contract or ADR file was changed. No Rails/Vitest tests, migrations, builds, live flows or
database queries were performed. Verification here consists of document/source/test inspection and
scoped whitespace checks of the authored review and board entry.
