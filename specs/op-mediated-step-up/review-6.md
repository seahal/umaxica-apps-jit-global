# Review 6: contract revision 4

Date: 2026-11-03. Disposition: changes required before unit 1; the owner-selected binding approach
is not reopened. HEAD `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`, with extensive uncommitted work.
Reviewed contract revision 4, the latest board response and amended ADR drafts. Source and primary
specification inspection only; no tests, migrations, provider or browser flows were run.

## Findings

### RV-93 — High — Signed expectation needs a verified-claims API, not the existing boolean result

Evidence: `contracts/contract-draft.md:114-118,135-141` relies on two custom assertion claims.
`app/values/oidc_client_assertion_jwt.rb` currently issues only standard client identity/endpoint/
time/JTI claims (`issue_with_configured_key`) and `valid?` returns a boolean after verification and
JTI consumption. `OidcClientRegistry.authenticate_assertion` and
`OidcTokenExchangeCoordinator#authenticated_client_assertion?` use that boolean API. The RP token
client creates its assertion internally at `app/adapters/oidc_op_token_client.rb:65-66` and has no
typed step-up expectation argument today.

Disposition: specify the RP builder and OP verifier contract for the signed expectation, returning
the authenticated client and validated expectation from the same verification/JTI-consumption
operation. Do not decode the JWT again without authentication, read unsigned request equivalents, or
invoke the single-use verifier twice. Require non-empty correctly typed exact grant/subject values
for the purpose-bound step-up code; missing claims must not fall back to ordinary sign-in issuance
or OP-current selection. Ordinary sign-in/refresh assertions remain valid under their own contracts
and cannot use these fields to grant step-up. Test missing/partial/wrong-type claims, tampering,
foreign client, mismatched code purpose and replay. Add these concrete integration changes to the
plan and accepted shape proposal.

RFC 7523 permits additional claims, but does not standardize these two fields or their application
meaning. Describe them as the owner-approved extension while preserving existing signature, endpoint
audience, client identity, expiry and replay requirements.

### RV-94 — High — Proposed Chronicle result values cannot be persisted by the current model

Evidence: contract section 8 maps results to `recorded`, `cancelled`, `indeterminate` and
`rejected`, leaving compatibility unverified. `app/models/chronicle.rb:48,64` explicitly allows only
`intent`, `succeeded`, `failed`, `audit_incomplete`, `invalidated` and `manual_recovery_required`.
Delivery of four proposed event categories would fail validation and remain pending; outbox
durability alone does not complete Accounting.

Disposition: provide an explicit per-event mapping into the current approved result vocabulary,
retaining detailed cancellation/uncertainty/rejection distinctions in the authoritative action,
reason and constrained metadata, or specify an intentional result-vocabulary change with all its
consumers and constraints. Do not broaden the enum merely to get delivery green. Verify retention
policies and delivery identity comparisons for every mapped event, including repeated delivery. This
source discrepancy is now confirmed and should no longer be listed only as unverified.

### RV-95 — Medium — Filtering attribution to live grants may narrow existing TOTP root revocation

Evidence: contract section 9 changes set 3 to roots owning a _live_ grant whose latest step-up
commit used TOTP. Current `AuthenticationSessionRevoker.tokens_for_method` at
`app/controllers/concerns/authentication_session_revoker.rb:28-42` checks root attribution without a
grant-liveness condition. `adr/unified-enforcement.md:626-638` requires the compromised-method union
to revoke roots in full, not just their current grants.

Trigger: a root has an attributed TOTP step-up, its corresponding RP grant expires or is revoked,
but the root and another RP grant remain active. A live-grant-only filter may exclude that root even
though the old root-attribution rule would include it. Multiple grants also require a defined
meaning of latest: latest per grant is not the old single latest event on the root.

Disposition: state the intended root-level attribution lifetime and ordering explicitly; preserve
the existing enforcement set without depending accidentally on grant expiry. Use retained commit
facts and their root ownership as necessary, and test expired/revoked source grant, surviving
sibling grant, and a later different-method event. If exact legacy semantics must intentionally
change, record that policy delta rather than calling it unchanged. This is existing security
enforcement, not the deferred optional window-closing mechanism.

### RV-96 — Medium — Installation must define deadline checks independently of recovery scheduling

Evidence: contract:123-132,147-150 gives a 60-second dispatch deadline but the installer explicitly
requires only DISPATCHING, live binding and generation. Recovery moves a stale row only when its
writer runs. If the worker/sweep is late, a response after 60 seconds can still find DISPATCHING.

Disposition: specify whether 60 seconds is an installation deadline or only a recovery eligibility
threshold. Recommend enforcing the chosen dispatch deadline and original pending-flow expiry on the
database clock under the installation lock, even before the sweeper runs. Preserve the fixed
authentication-event freshness rule separately. Define the recovery scheduling/entry point and
single transition/outbox result for installer versus recovery races. Test immediately before, at and
after the deadline with recovery delayed, as well as a late success after INDETERMINATE.

## Disposition of review 5

| Prior finding | Revision-4 disposition                                                                                                                                                                                                                                                                                               |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RV-87         | Hint storage/expiry approach is withdrawn by the recorded owner choice. Binding an OP-selected grant and checking the RP's signed grant/subject expectation before mutation is coherent in principle; RV-93 specifies the missing implementation contract. O-8's forced re-login requirement is correctly withdrawn. |
| RV-88         | Source-state precedence and recovery transition are specified. RV-96 settles the remaining deadline-versus-sweep semantics.                                                                                                                                                                                          |
| RV-89         | Separate authoritative `verified_method` commit facts and preservation of security enforcement are improvements. RV-95 identifies a remaining filtering/ordering policy discrepancy.                                                                                                                                 |
| RV-90         | Partial rejected-attempt uniqueness, RP public reference and delivery attempts are specified. RV-94 confirms the remaining result-mapping incompatibility.                                                                                                                                                           |
| RV-91         | Preparation/signing under issuance locks inside the OP transaction, exact prepared digest persistence and post-commit HTTP response address the earlier split. Implementation must still demonstrate rollback and race behavior.                                                                                     |
| RV-92         | ADR path-C supersession now distinguishes reusable evidence from single-use ceremony correlation. The authenticating-credential activity removal is stated as an intentional policy change for acceptance; Q-1's current-mode/session checks are included. No further product-choice reversal is requested.          |

## ADR and readiness assessment

The revised ADR drafts address the major supersession ambiguity and correctly amend the
consolidation ADR as the primary current text. Preserve the accepted Q-1 direction and all-session
revocation. The proposed removal of authenticating-credential continued-activity checks remains an
explicit policy change for the owner's formal acceptance, not an implementation shortcut. Align the
enforcement wording with RV-95 before applying an amendment that says it is unchanged.

Unit 0 still needs RV-93 through RV-96 resolved, final audit payload/retention mappings and the
explicit DBSC host/credential/proof endpoint/check contract listed as open C-5. Actual new-flow DBSC
behavior is unverified, but naming its owning checks is document work that can be completed before
implementation. Finish the pending-state lifetime and dispatch deadline under C-8 without reopening
the agreed 300-second proof window.

No owner clarification is needed to fix the technical API/result/deadline issues. Any intentional
enforcement-set change must be made explicit for acceptance. After these corrections, record the
remaining schema/test mappings and seek formal acceptance of the spec/ADR changes; this review does
not authorize unit 1 or claim the future implementation is verified.

Primary source read: [RFC 7523 section 3](https://www.rfc-editor.org/rfc/rfc7523.html#section-3).
Only this review and the append-only board response were authored. Reviewed spec, plan, contracts,
ADRs, application and tests were not edited. No runtime checks were performed.
