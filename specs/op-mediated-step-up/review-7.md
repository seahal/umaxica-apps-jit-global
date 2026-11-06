# Review 7: contract revision 5

Date: 2026-11-03. Disposition: targeted contract corrections required before unit 1. HEAD
`efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, with extensive existing uncommitted work. Reviewed the
latest board request, contract revision 5, ADR amendment drafts, review 6 and the relevant source
boundaries. This is a document/source review, not evidence of runtime behavior. No implementation,
migrations, Rails/Vitest tests or live browser/provider flows were performed.

## Findings

### RV-97 — High — Name the DPoP check on the new code-exchange path, not only on refresh

Evidence: `contracts/contract-draft.md:154-170,327-334` says the new completion rotates the existing
grant and keeps the OP refresh path's DPoP check. These are different entry paths today:
`app/services/oidc_token_exchange_coordinator.rb:59-62,129-151` dispatches an authorization code
through `validate_dpop_proof`, which accepts absent proof and otherwise returns the presented key's
thumbprint without comparing an existing grant (`:1200-1212`). Refresh instead calls
`validate_refresh_dpop_proof` (`:220-221,352-367`), requiring proof for a bound grant and comparing
it to `usage.dpop_jkt`. The RP token adapter currently provides neither a proof argument nor a DPoP
header (`app/adapters/oidc_op_token_client.rb:37-47,60-85`). The low-level refresh issuer does not
perform that proof check itself (`app/operations/oidc_refresh_token_issuer.rb:89-107`).

Trigger/impact: a purpose-bound step-up code targets a grant that already has a DPoP key binding.
Reusing ordinary code validation or only the low-level rotation operation can accept no proof or a
different key. Leaving the stored binding unchanged does not establish possession for this issuance.
The draft's reference to the refresh check does not specify how the new path invokes it, despite
AC-22's requirement that DPoP checks remain effective. This is a missing contract; the new path has
not been implemented, and no exploitable runtime bypass is claimed.

Disposition: explicitly require the step-up completion's proof to match the bound grant's existing
key before event/rotation/commit, and preserve that key in issued credentials. Name the validation
owner and RP transport/proof-generation contract; check the authoritative binding under the issuance
locks. If Base's in-scope grants cannot be DPoP-bound, establish that invariant and explicitly
refuse a bound grant before mutation until supported. Ordinary sign-in remains under its own
contract; this does not request new binding for every unbound grant. Cover absent proof, foreign
key, invalid/replayed proof and correct proof through the actual step-up token endpoint, including
unchanged event, refresh digest and binding on refusal.

DBSC is separate. The revision correctly identifies the device-session refresh proof gate at
`AuthenticationBase#device_session_refresh_allowed?` (`:1841-1879`), with the realm-specific Visa
endpoint selected by `token_dbsc_url` (`:3284-3292`). Keeping the device/root DBSC fields untouched
and testing the next device-session refresh is a coherent preservation contract. That portion of C-5
is addressed; it does not establish the DPoP behavior of a new grant exchange.

### RV-98 — Medium — New event names select a different retention class from existing step-up actions

Evidence: `contracts/contract-draft.md:236-249` intentionally maps all new `step_up.*` actions to
the default `security` retention policy. `app/policies/chronicle_record_policy.rb:28-29` explicitly
assigns `auth.step_up.succeeded` and `auth.step_up.failed` to `compliance`; the fallback to
`security` is at `:88-94`. Revision 5's fallback claim is technically correct, but it is not
equivalent to the existing step-up classification. The ADR draft does not identify this as an
intentional retention-policy change.

Trigger/impact: replacing step-up accounting with the new action names changes the policy used to
calculate erasability. Whether this shortens or lengthens retention depends on actual policy rows,
which were not queried in this review; no duration or data-loss claim is made. It is still a policy
discrepancy to settle before making the new names authoritative. The repository's logging boundary
requires explicit event ownership and retention expectations
(`adr/application-logging-boundary.md:34-38`).

Disposition: explicitly map the replacement authentication success/failure facts to the existing
`compliance` policy, while separately classifying new request/attempt/installation observations as
appropriate, or document and justify an intentional classification change for acceptance. Do not
depend on the action-name fallback to make that decision. Include per-event retention alongside the
result/payload mapping, and test policy selection and resulting erasability through the public
delivery boundary. No historical record rewrite is requested.

## Disposition of review 6

| Finding | Revision-5 assessment                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RV-93   | Addressed at contract level: typed expectation on the RP builder/client, one authenticated result carrying both client and expectation, purpose-bound validation and negative tests. During implementation, replace the token coordinator's initial authentication call with that single result-producing operation and carry its result to code classification; do not call the old boolean verifier first (`oidc_token_exchange_coordinator.rb:57,93-126`). Retaining the boolean interface for other callers is reasonable if both use the same verification implementation. |
| RV-94   | Result-vocabulary incompatibility addressed: all proposed results now belong to `Chronicle::RESULTS` (`app/models/chronicle.rb:48,64`). Detailed uncertainty remains in action/reason rather than an invented success. RV-98 covers the newly specified retention choice, not the enum fix.                                                                                                                                                                                                                                                                                     |
| RV-95   | Addressed at policy-contract level: latest attribution is root-scoped across retained facts, independent of source-grant liveness, retained for the root lifetime; ADR wording agrees. Implementation still needs deterministic ordering for simultaneous facts and tests of sibling grants and retained-purpose writes. No new enforcement-policy decision is requested.                                                                                                                                                                                                       |
| RV-96   | Addressed at contract level: installation checks both deadlines under its lock independently of the sweeper, with a shared writer and boundary/race tests. Preserve the absorbing-terminal invariant when implementing the ordered prose at lines 166-169: check DISPATCHING before attempting any timeout transition. A late result for INSTALLED/REFUSED/INDETERMINATE must never create another terminal fact.                                                                                                                                                               |

The signed-assertion expectation is correctly described as a local extension rather than a
standardized grant-binding field.
[RFC 7523 section 3](https://www.rfc-editor.org/rfc/rfc7523.html#section-3) permits additional
claims; their purpose and validation remain this application's contract. The owner's choice, the
300-second reusable event, Q-1 and the withdrawal of ID Token storage are not reopened.

## Readiness and remaining document work

The previous four findings are substantially resolved at design level. Unit 0 still needs RV-97 and
RV-98 settled, the explicitly open per-event audit payload/reason schemas (C-3), and a finalized
pending lifetime/dispatch duration (C-8). C-3's question about the result vocabulary is now answered
and can be closed separately from its payload work. ORG parity remains an implementation/test
obligation; proposed tables and named tests do not demonstrate it.

Reconcile the final accepted documents before handoff: `spec.md:140-152` still says shapes and the
class are undecided and repeats the old consumption count, while the contract supplies those
decisions. This is document synchronization, not a reason to reopen them. The proposed removal of
the authenticating credential's continued-activity check remains an explicit policy change for
formal acceptance as already recorded. No implementation is authorized by this review.

Only this review and the append-only `zero.md` response were authored. Source inspection confirmed
the distinctions above; no future-path DBSC/DPoP, delivery, race or enforcement test was executed.
