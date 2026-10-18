# OP/RP Separation — Miscellaneous

> Archived snapshot, generation 0001 (originally `five.md`). Non-normative and not evidence; see
> [README](./README.md).

Status: **non-normative notes structure; no implementation direction or acceptance criteria**.

## Purpose and Promotion

Use this file for research notes, references, unclassified observations, future-cycle candidates and
out-of-scope discoveries that do not belong to [one.md](./implementation-plan.md),
[two.md](./acceptance-definitions.md), [three.md](./implementation-reports.md) or
[four.md](./addenda.md).

A note does not authorize code, data, configuration, external writes or a change of security
guarantee. A requirement is promoted only after the relevant user decision and registration in the
proper approved supplement, with Work Unit/Gate traceability. Implementation-stopping findings go to
the user and `three.md` during implementation, not only here.

## Note Register

Historical discussion remains in unchanged [nine.md](./planning-discussion.md); it is not copied
here as current instructions.

```text
Note ID: MISC-20261016-0001
Date: 2026-10-16
Subject: Independent audit of one.md and two.md (sub-investigator, read-only)
Category: research
Observation or idea:
  Baseline HEAD 17903f7d121aa33efe29f2db9235c9aa5db4b001. Read-only; no test, boot, DB or network check run.
  Verdict: R1 can be handed to Luna Max as written. R2 onward needs the items below resolved first.
  Sound: single-layer structure, R1-R5 split, P-8 Waiting contract, retired Restricted design removed,
  MFA-reset closure, escalation rule (1.3), com/org limitation controllers correctly recorded as existing,
  early resolve!/later log_in gap identified (base_sign_in_limitations.rb:63 vs :272), acyclic DAG,
  four.md anchors #one-addenda / #two-addenda resolve, ID formats consistent across two/three/four.
  one.md findings:
  - H-1 P-9 (first actor-serialized commit wins, no Waiting reservation) existed only in one.md.
    User confirmed it on 2026-10-16 (see MISC-20261016-0002). Resolved.
  - H-2 Section 5.1 gives every regional cell its own physical DB in each environment
    (19 dev + 19 test + 19 test replica + workers). Not a user decision. See MISC-20261016-0002.
  - H-3 Section 5.1 binds one region per process, but no Work Unit owns the development topology
    (region-bound processes, regional hostnames) that AT-R4-REL needs.
  - H-4 AR-20/4.1 require role-specific credential bundles and separate OP/RP processes;
    no Work Unit owns this (R5-WU04 mentions role-isolated key loading only). Likely the largest hidden task.
  - M-1 R5-WU19 activates all cells at once while R5-WU17 defines a pilot order; reconcile.
  - M-2 Section 7.2 allows a read-only GET page to auto-submit the promotion POST; prefer an explicit
    user-initiated button.
  - M-3 R1 refuses OIDC Access tokens without authn_ctx, signing out every current RP session at release;
    state it as a consequence.
  - M-4 131 KB of dense prose with I/S/D/E shorthand; R1/R2 are executable, R5 units are abstract.
  - L-1 Section 3 calls the root-login ADR "dirty"; it is committed in 17903f7.
  two.md findings:
  - High: Gates map 1:1 to Work Units, so user-decided invariants (MFA-reset closure, N+2 refusal,
    103 never authenticates, Org context continuity) are not re-verified by R3-R5 release Gates.
    Add an invariant register (for example INV-01..) that every later release Gate re-runs.
  - Low: R3 and R4 have no docs/diagram reconciliation Gate (R2-WU05 and R5-WU18 do).
Basis / references: one.md sections 2, 3, 4.1, 5.1, 7.1, 7.2, 8.2, 12; two.md sections 3, 5.
Related documents / Work Units / Gates: R2-WU03, R4-WU01..04, R5-WU04, R5-WU17, R5-WU19; AT-R*-REL.
Unverified assumptions: dev topology and credential layout were inferred from source/config, not run.
Possible follow-up / owner: Codex revises one.md/two.md or registers addenda after user decisions.
Promotion status: note only
Actual decision / Report / Addendum reference: none
```

```text
Note ID: MISC-20261016-0002
Date: 2026-10-16
Subject: User answers to the audit questions
Category: unclassified
Observation or idea:
  1. P-9 is the user's decision. Rationale given by the user: the case is realistic. A third browser is
     Waiting and the user signs out on another browser, which frees capacity. Reviewer view: keep P-9.
     It never exceeds N full-access units plus one Waiting unit, and it avoids a priority reservation that
     an attacker could hold while Waiting. The Waiting page should offer an explicit "continue" POST when
     capacity is free, not an auto-submission (M-2). The current-code gap to fix in R2 is the early
     resolve!/later log_in split and the per-flow (not per-actor) resolution lookup.
  2. Region layout (user decision): each development environment hosts one region; JP and US are
     implemented in separate development environments. JP has priority now. Consequence for one.md 5.1:
     a development or test environment holds only its own region's cells, so JP needs 5 WW + 7 JP stores,
     not 19. Open point for the user: which environment hosts the five WW cells (proposal: the JP
     environment). Cross-region refusal tests can use a non-matching deployment binding without a second
     physical store.
  3. Audit notes are recorded in five.md (this file).
Basis / references: user conversation 2026-10-16.
Related documents / Work Units / Gates: one.md 2 (P-9), 5.1, 7.2; R2-WU03; R4-WU01..04; R5-WU03.
Unverified assumptions: number and identity of existing development environments.
Possible follow-up / owner: answer 2 changes one.md 5.1 and must be registered as an approved
  ADD-ONE addendum in four.md before it is normative.
Promotion status: proposed (answer 2); answer 1 already integrated in one.md
Actual decision / Report / Addendum reference: none yet
```

## Note Template

```text
Note ID: <MISC-YYYYMMDD-nnnn>
Date: <UTC>
Subject: <short description>
Category: <research / reference / future / out-of-scope / unclassified>
Observation or idea: <fact versus proposal distinguished>
Basis / references: <source paths, actual observations or links>
Related documents / Work Units / Gates: <IDs or none>
Unverified assumptions: <explicit>
Possible follow-up / owner: <non-authorizing suggestion>
Promotion status: <note only / proposed / approved elsewhere>
Actual decision / Report / Addendum reference: <reference or none>
```

Keep secrets, tokens, cookies, personal data, raw dumps and large logs out of notes. Actual
completed verification that warrants retention follows the repository evidence rules; this file is
not a substitute for a PASS record.

## MISC-20261016-0003 — Final Sol Baseline Revision and Static Review

```text
Note ID: MISC-20261016-0003
Date: 2026-10-16
Subject: Final design correction, invariant traceability and R1 acceptance definitions
Category: research
Baseline: feature, 17903f7d121aa33efe29f2db9235c9aa5db4b001; tracked/untracked status clean at start.
Reviewer/coordinator: Codex Sol (the user's replacement name for Astra).
Scope: one.md and two.md draft-baseline corrections, plus this append only.
Facts / source:
  - Existing MISC-20261016-0001/0002 are retained without rewriting or duplicating them.
  - Root-login ADR and earlier Avatar changes are committed at this HEAD, not currently dirty work.
  - OidcTokenExchangeCoordinator refreshed/exchanged Access encodes omit authentication_context.
    AuthorizationTokenClaims.build defaults omitted context to Normal and always writes the claim:
    the source defect can therefore produce an explicit WRONG Normal value, not necessarily a
    missing claim. No runtime exploit/test was executed to make this observation.
  - Existing Org continuity tests and chk_operator_tokens_authentication_context allow NULL as
    legitimate canonical Normal root storage. The previous plan's nonblank-root requirement would
    reject those real Normal roots. That requirement was corrected; a missing/unknown TOKEN claim
    is still rejected at the strict OIDC boundary and cannot infer Normal.
  - Current Puma/configuration supports one multi-host development process; current credential
    provisioning describes environment-wide encrypted credentials/master-key files. Effective
    future role/secret isolation cannot be claimed from a code-only signing dependency removal.
User decision sources:
  - Current final integration instruction H-1 formally confirms P-9: no Waiting reservation,
    first valid actor-serialized final commit wins; explicit bound browser continuation.
  - H-2 confirms WW5 + JP7 in JP development; WW stays WW. US is target metadata/static validation,
    no assumed permanent US runtime/DB/host/private secrets. Production fleet is absent.
  - H-3/H-4 assign R4 environment and R5 effective secret/process isolation.
  - M-2 removes auto-submit; user explicitly presses Continue at the existing safe POST.
  - The former note-0002 suggestion to defer these draft corrections to an initial addendum is
    superseded by the current instruction: integrate them directly before baseline acceptance.
Design corrections integrated:
  - R4-WU02A owns fixed JP multi-host binding/readiness without requiring R5 roles.
  - R5-WU03A owns bundles/master-key visibility, per-role Puma/jobs, DB/key/queue/ingress denial.
    A queue-name string or shared readable master key is insufficient. Use existing mechanisms,
    with exact S/D review and real capability probes before activation.
  - R5-WU18A makes isolated attack/restore evidence a hard prerequisite to WU19, not a post-cutover
    discovery. WU20 repeats verification in the actual activated environment.
  - WU19 has a closed coordinated common schema/protocol/cutoff batch with separate database
    commits/checkpoints, then exact-cell admission/acceptance. No legacy authenticator fallback.
  - A signed required R5 contract epoch prevents pre-R5 JWT reuse even with forged RP local rows;
    actor authentication epoch remains a distinct identity-stop axis. Exact shape S is pending.
  - Specific R5 review sub-packets retain stable parent IDs/consumer ownership and domain writers.
  - two.md defines 24 Invariants, all AR-01..AR-20 validation links, release regression and 46
    defined cases/scenarios, including 19 full R1 cases. Runtime results all remain NOT_RUN.
Static validation actually performed:
  - Parsed 42 stable executable Work Unit IDs, 74 edges; graph is acyclic, and Mermaid exactly
    matches the authoritative dependency table. Existing IDs are retained.
  - Matched all 42 Work Unit/Gate entries; checked every defined case reference, unique case ID,
    24 Invariant IDs and all 20 AR verification destinations.
  - Confirmed secret-role prerequisites and isolated preactivation precede WU19, and JP development
    binding precedes R4 credential cutoff.
  - Final relative-link/whitespace/protected-file checks are recorded in the final follow-up below.
Not performed:
  No Rails boot/test, DB/catalog/migration/rename/reset/restore, credential/session cutoff,
  secret decryption/distribution, environment/CI change, deployment, or Jump/Edge write/probe.
Severity and remaining risk:
  Current R1 source defects/gaps remain unimplemented and unverified; independent R1 is ready
  for I, not runtime PASS. R2 shapes/data reconciliation, R3 actual target/restore/D, R4 environment
  and cutoff, R5 secret/role/epoch/queue/isolation and attack evidence remain scoped prerequisites.
  No unresolved Critical/High DESIGN contradiction is claimed solved by runtime evidence.
Disposition:
  Design GO for the candidate; R1 Implementation Ready pending explicit I. R2 conditional,
  R3 Data Approval Pending, R4 Environment Preparation Pending, R5 Secret Isolation/Preactivation
  Proof Pending; current R5 Activation is NO-GO until those actual tests pass.
Related documents / Work Units / Gates:
  one.md sections 2, 5.1, 6.3, 7.1/7.2, 8 and 13; two.md sections 8..13; new WU02A/03A/18A.
Actual decision / Report / Addendum:
  User's current H/M/L instruction; no implementation Report, no initial Addendum, no I/S/D/E
  blanket approval. three.md/four.md and historical nine.md remain unchanged.
```

Follow-up to MISC-20261016-0003 (same planning revision, 2026-10-16):

- Source route correction: the three current `resource :limitation` declarations provide update via
  PATCH/PUT, not an explicit POST. R2 now owns adding POST at the same existing URL/update Action
  with identical CSRF/Origin/browser/actor checks; existing methods cannot bypass it. GET and
  generic OAuth/social auto-resume stay Waiting even after capacity frees until explicit
  continuation. No code/route was changed now.
- Actual document checks passed: 42 Units / 74 edges, acyclic DAG, exact Mermaid/Gate
  correspondence; 46 defined cases/scenarios including 19 R1 procedures; 24 Invariants; all
  AR-01..AR-20 linked to existing case definitions. Twenty relative file/anchor links resolved,
  including the required opening One/Two Addenda links.
- `git diff --check` and explicit `git diff --no-index --check /dev/null <document>` plus
  whitespace/fence/language checks reported no document errors. These files are ignored, so the
  explicit file checks are necessary; an empty tracked diff alone would not verify them.
- HEAD and tracked/index/untracked status stayed unchanged. `three.md`, `four.md`, `nine.md` and the
  original 6,467-byte five.md history prefix retained their original SHA256 values. Only
  one.md/two.md and this five.md append changed.
- These PASS observations concern static documentation only. All application, race, DB,
  role-isolation, HTTP, browser, restore and acceptance execution remains NOT_RUN. R1 awaits
  explicit I; R5 actual Activation stays NO-GO pending its secret/attack/data gates. The
  draft-baseline corrections are directly integrated, not initial approved addenda or fictional
  implementation reports.

## MISC-20261016-0004 — Sol response to Luna Max's six.md escalations

Date: 2026-10-16 UTC. Source HEAD: `17903f7d121aa33efe29f2db9235c9aa5db4b001`. The user requested a
response to the current `six.md`. Original escalation facts and historical PENDING labels remain;
section 4 records the effective dispositions.

- Accepted finding: the current shared-store/no-BCL ADR conflicts with target R5. Existing user
  D-08/OP-RP decisions already choose separation, so no repeated architecture selection is needed.
  The missing sequencing condition is now explicit: R5-WU01 must obtain Accepted successor ADR
  Supersession before conflicting R5 implementation; WU18 is final documentation closure. No ADR was
  edited or presumed Accepted, and R1-R4 retain the active shared-store contract.
- Existing H-2 resolves current runtime completion as WW5+JP7. `one.md`'s opening success condition
  and closure wording now distinguish that scope from US static catalog/negative tests and deferred
  US runtime NOT_RUN. No US environment was provisioned or inferred.
- Current I for R1-WU01 and exact isolated-fixture D are recorded consistently in the opening and
  handoff sections. R1-WU02 and later units inherit no I/S/D/E; no new approval model was proposed.
- `two.md` AT-R5-01 names the ADR prerequisite. Stable Unit IDs and existing dependency edges remain
  unchanged. No new requirement was hidden in `four.md`; `nine.md` remains history.
- Actual checks: changed-document trailing whitespace and required One/Two supplement anchors
  passed; `git diff --check` passed at this point. These document checks are not R5 acceptance.

R1 code/test work continues separately under its actual I/D. Its observed runtime results belong in
the R1 evidence record and acceptance disposition, not in this design-response note. A concurrent
change to `src/features/auth/session/SignOutConfirmation.tsx` was observed and preserved.

## MISC-20261016-0005 — Reviewer corrections before R1 resumption

```text
Note ID: MISC-20261016-0005
Date: 2026-10-16
Subject: Final reviewer check of one.md/two.md and the corrections the user requested
Category: research
Baseline: feature, 17903f7d121aa33efe29f2db9235c9aa5db4b001; worktree held uncommitted R1-WU01 application/test changes,
  which were preserved and not edited.
Reviewer: Claude (sub-investigator).
User decision: the user paused R1-WU01 implementation on 2026-10-16 and asked for these corrections.
Corrections applied (documents only):
  1. one.md 7.2: the Waiting read-only rule for generic/OAuth/social completion is scoped to the flow
     that itself holds the Waiting lease. A different fresh sign-in flow of the same actor follows
     admission step 2 and may take free capacity (P-9). two.md TC-R2-03-001 adds that case.
  2. one.md section 3 and R1-WU01: a third encoder without authentication_context,
     CoreBrowserCredentialContract.encode_access_token (app/services/core_browser_credential_contract.rb),
     must be classified in R1. A static search found only test callers. two.md TC-R1-02-006 updated.
  3. Stale status text: one.md opening/section 13/13.1 and two.md baseline now state that R1-WU01
     started and is paused, and that R1 test runs exist only in the R1C1 evidence record.
  4. one.md 7.2 and R2-WU04, two.md INV-003 and TC-R2-04-001: Org Standby is Full Access for
     capacity, but an MFA-reset mutation requires Step-Up and is therefore unreachable from Standby.
Follow-up to MISC-20261016-0002: answer 2 (region layout, WW5 + JP7 in JP development) is integrated
  into one.md as H-2 before baseline acceptance; no ADD-ONE addendum is needed for it.
Observed out of scope: core_browser_credential_contract.rb reads
  ENV.fetch("CORE_BROWSER_JWT_COOKIE_ENABLED", false), which conflicts with the one-argument
  ENV.fetch rule. Not changed here.
Not performed: no application code, test, DB, configuration or ADR change; no test run.
Promotion status: corrections integrated into the baseline candidate
Actual decision / Report / Addendum reference: user request in conversation, 2026-10-16
```
