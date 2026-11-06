# Review 5: contract revision 3 and ADR amendment drafts

Date: 2026-11-03. Disposition: changes required before unit 1. HEAD:
`efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, extensive existing uncommitted changes. Scope includes
the final board request, contract/inventory revision 3, ADR drafts and recorded Q-1. Source and
specification inspection only. No tests, migrations or live flows were run.

## Findings

### RV-87 — High — Hint verification conflates grant sid with OP session identity

Evidence: `contracts/contract-draft.md:68,104-113` requires the hint sid to match the active OP
session. Current token issuance sets `sid` to `usage.public_id`, the RP grant identifier, at
`app/services/oidc_token_exchange_coordinator.rb:1023,1078`. It is not the OP root/device-session
identifier. A direct comparison can reject legitimate step-up or bind the wrong concept.

Disposition: validate the hint's signature, issuer, requesting-client audience and subject; resolve
its sid to that client's exact live grant, then compare the grant's parent device/root ownership
with the active OP session. Keep both comparisons explicit. A valid hint is not a replacement for
the active OP session, client authentication or browser correlation.

The hint lifetime rule is also missing. ID Tokens expire after minutes while sessions live longer.
OIDC Core 3.1.2.2 permits accepting expired hints for a current/recent OP session; use a dedicated
hint-validation policy instead of the ordinary fresh-ID-Token verifier. Define key
retention/rotation handling and rejection of foreign-client, stale/revoked-grant and unknown-key
hints. Do not turn ID Token expiry into sign-in every five minutes. This is distinct from O-8's
one-time absence of stored hints before activation.

### RV-88 — High — DISPATCHING has no crash recovery or complete refusal precedence

Evidence: contract:69-76,116-123,156-162. A worker can commit DISPATCHING and die before sending, or
receive a response and die before installation/INDETERMINATE. All later callbacks return 409; the
proposed edges have no expiration/reconciliation rule for a stranded DISPATCHING row. The
correlated-error rows also precede the DISPATCHING/terminal row, potentially allowing an
error-bearing duplicate to attempt a forbidden transition.

Disposition: specify a database-clock dispatch deadline and a named recovery transition to
INDETERMINATE, without retrying the old code or guessing that OP commit failed. Record the uncertain
outcome durably. Check legal source state before either code or error processing; late results
cannot revive the row. Test crash-before-send, response-received-before-crash, error-bearing
duplicate and late-success-after-recovery, plus restart into a new transaction.

### RV-89 — High — Existing security revocation cannot be deferred as ordinary window closure

Evidence: contract:100,216-219,266-267. Attribution moves to grant `amr` while the same draft says
no authorization decision reads it and leaves TOTP-removal window closure open.
`AuthenticationSessionRevoker.tokens_for_method` at
`app/controllers/concerns/authentication_session_revoker.rb:28-42` implements the current
TOTP-specific root revocation union. `adr/unified-enforcement.md:626-641` owns that security effect;
it is not merely an optional new sudo-window-closing feature.

Disposition: distinguish routine credential edits, the separately deferred extra window closure, and
existing compromise/enforcement revocation. Preserve the last category across root/grant attribution
migration, including multiple RP grants and changed/latest method snapshots. Specify the
authoritative attribution that the revocation owner reads; `amr` may remain non-authoritative for
the ordinary RP freshness decision while serving the existing revocation policy. Do not silently
narrow that policy or defer it under O-7. Add policy-specific regression tests.

### RV-90 — Medium — Audit schema still leaves identity and result semantics ambiguous

Evidence: contract:185-202. The rejected-attempt dedup unique key is stated without an explicit
partial predicate. Applied to every event it can collide across requested/committed/installed events
sharing context and reason. RP audit `context_ref` refers to an RP state public reference, but
`rp_step_up_states` has no public_id. Successful and failed outcomes must not inherit the Passkey
delivery job's hardcoded `result: succeeded` (`app/jobs/passkey_audit_delivery_job.rb:93,115`).

Disposition: specify the partial unique index for rejected attempts only, a stable non-secret RP
context reference, and each event's Chronicle action/result/reason/identity mapping. Define failed
delivery-attempt durability and uniqueness under concurrent workers. The outbox design now addresses
the logging-only defect in principle; these concrete shapes remain migration blockers. Do not
substitute a state/browser secret as an audit identifier.

### RV-91 — Medium — Token preparation must use one locked issuance snapshot

Evidence: contract:125-133 separates token preparation from the subsequent consume/update/rotate
transaction. The draft does not state that grant/session locks, database clock and snapshot
validation cover preparation too, nor how the prepared refresh credential matches the persisted
rotation. A concurrent refresh/revocation between preparation and commit can stale that response.

Disposition: prepare/sign while holding the authoritative issuance locks in the transaction, or
specify equivalent optimistic validation of every prepared input before commit. Persist the exact
prepared refresh credential digest and event; roll back on signing failure. Send HTTP only after
commit. Test concurrent refresh/logout during preparation and issuer failure; prepared but
uncommitted tokens must never escape. This refines the accepted pre-commit preparation requirement.

### RV-92 — Medium — ADR amendments retain incompatible parts of old path C

Evidence: `contracts/adr-amendment-drafts.md` section 1 says the other path-C rules stay, while the
old path C binds evidence to operation and original transaction. The new ordinary evidence
deliberately removes operation/target single-use binding. Section 2 correctly changes the
consolidation ADR, but section 1 needs the same explicit scope of supersession.

Disposition: enumerate retained Identity, client, live RP-session, request-correlation and
authorization protections, and explicitly supersede old ordinary operation/target consumption. Keep
ceremony/code single-use distinct from reusable authentication evidence. Update the drafts' source
revision references and make the new ordinary credential-activity policy an explicit disposition,
rather than hiding it in a claimed unchanged managed-credential check. The old
`ClientPasskeyPolicy#management_credential` checks the authenticating credential, not automatically
the credential being managed (`app/policies/client_passkey_policy.rb:64-83`).

## Previous findings and decisions

| Finding | Current disposition                                                                                                                                                                                                               |
| ------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RV-81   | Correlation before errors and unauthorized-request nonmutation are now explicit. Complete state precedence under RV-88.                                                                                                           |
| RV-82   | Atomic dispatch and no lock over network are addressed in principle. Crash recovery remains RV-88.                                                                                                                                |
| RV-83   | A standard hint is a reasonable binding carrier; fix the identifier/lifetime checks under RV-87.                                                                                                                                  |
| RV-84   | The draft explicitly proposes removing evidence-credential continued-activity checks. That is a policy disposition, not proof of unchanged behavior. Review ADR wording under RV-92 and preserve existing revocation under RV-89. |
| RV-85   | Outbox identity, polling and acknowledgement recovery are substantially specified. RV-90/91 cover remaining concrete consistency gaps.                                                                                            |
| RV-86   | Source claim corrected and browser refusal mapping separated. Route-specific CSRF behavior still requires implementation tests; it is not verified by another controller's development log.                                       |

Q-1 is treated as the recorded owner decision: ADVANCED to NORMAL may use ordinary reusable step-up,
and all-session/refresh revocation after the mode change remains. Do not ask the owner to decide it
again. At commit, verify current ADVANCED mode and current actor/session authority before changing
it; a concurrently invalidated session or stale event cannot authorize the downgrade. A single class
alone is not a reason to omit those checks. The consolidation ADR is the correct primary amendment
target; the drafts now improve that ownership mapping.

O-7 may remain deferred only for genuinely new ordinary credential-change window behavior; existing
enforcement revocation remains mandatory. O-8 introduces a user-visible activation cost (fresh
sign-in before first step-up for old sessions). Treat it as a proposed rollout requirement, not a
decided fact or a migration backfill instruction. Before seeking acceptance, specify a usable
same-session missing-hint recovery path, the effect of fresh login on the pending step-up request,
and whether existing verified hint material can safely avoid forced login. Never forge ID Tokens or
reuse an unrelated logout hint simply to populate the new table. This does not relax the
separate-step-up-after-sign-in requirement.

## Readiness and verification

Prepare revisions for RV-87 through RV-92, then finalize schemas and ADR amendment text. No
implementation or unit-1 migration is authorized yet. Formal acceptance must include any intentional
credential-activity policy change and O-8's activation behavior. Routine binding, crash recovery and
atomicity details should be resolved by the authors without reopening fixed product choices.

Primary source checked:
[OIDC Core 3.1.2.1 and 3.1.2.2](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest),
including issuer/audience semantics and expired-hint handling. No hint validation, outbox delivery,
code dispatch or downgrade race was exercised. Only this review and the board response were written.
