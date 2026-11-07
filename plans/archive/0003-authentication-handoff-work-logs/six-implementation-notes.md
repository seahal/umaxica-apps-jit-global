# 2026-11-04 — five.md / O-9 implementation notes
> Archived snapshot prepared for the 2026-11 handoff; the ignored root original remains in the working tree.


## O-9 Visa 経由設計

16:00 のオーナー決定に従い、`specs/op-mediated-step-up/contracts/o9-visa-roundtrip-design.md` を作成し、`zero.md` にレビュー待ちとして報告した。Visa の owner endpoint と既存 OIDC 認証 transaction に関係付け、Visa → Auth → Visa → Base で戻す案である。O-9 の browser / owner endpoints は未接続のまま。

## five.md の実装状況とブロッカー

- C4-18 の未実装メソッド名を、定義と全 production / test 呼び出し箇所で `explicit_display_snapshot` → `explicit_values`、`valid_anonymous_display_snapshot?` → `valid_display_snapshot?` に置換した。互換 alias は作っていない。関連 Ruby テスト 57 runs / 426 assertions が通過した。
- `browser-testing-with-devtools` の手順に従い利用可能な browser / DevTools tool を検索したが、この実行環境に構成済み browser tool はなかった。したがって C13 の `PreferenceSelect` props 更新時の挙動は実ブラウザで再現・確認できていない。編集途中の値を失わないことも含め、再現前にコンポーネント動作を変更していない。
- five.md C0 は「実装計画は確定しない」「実装してよい完成仕様ではない」とし、C5 に cookie / JWT shape と寿命、復旧、表示値の鮮度、Affinity、reset、Cookie Consent 所有・識別、Web Push binding、具体ルート / owner、通知希望、監査 / adult gate、ADR 改訂など未決を残す。これらを決めずに DB / API shape や route owner を実装すると設計を推測で確定することになるため、依存する schema / routing / lifecycle work は保留。承認済み・コードだけで完結する C4-18 は先行した。
- C3-17 / C9.1 の Chronicle structure dump 欠陥の修復には migration/dump workflow と復旧影響の確認が必要で、未実行。空 dump を手編集しない。

## O-9 設計で確認が必要な点

Visa の既存 OIDC step-up context が、purpose-bound passkey/social operation の認可・Auth 結果・source receipt を保持できるか、また最終 Zenith の credential owner をどの処理が O-10 lock 下で更新するかは、実装前レビューで確定する。現 proposal の result linkage/receipt はレビュー候補であり、schema 変更の承認ではない。

## 2026-11-04 — five.md C5.1 implementation continuation

### Completed: notification mock no-persistence contract

The mock PATCH now ignores every submitted field and returns 303 to its edit page. Tests cover guest APP / COM / ORG requests with populated ignored input and an empty payload, plus signed-in APP / ORG requests. Before/after state snapshots include the preference rows and JWT generation columns, child and option rows, audit rows, Cookie Consent binding/receipt, Web Push rows, account preference state and the existing identity email rows. The React test changes Web Push in the mock and confirms the client submits only an empty notification object.

The first version of the new shared concern copied dynamic `public_send` route-helper resolution from older Preference concerns. The Rails change rules prohibit adding this pattern. It was removed before final verification: the shared concern calls fixed method names, and each APP / COM / ORG controller supplies those methods using its own static route helpers. No routes or persisted/API shapes changed.

Verification on HEAD `b30345216886c98af1f04cbd434f067f12decf01` with an extensively dirty worktree: targeted Rails integration plus CSRF and forbidden-pattern guards passed **54 runs / 1,201 assertions**; the focused Vitest file passed **12 tests**; scoped `git diff --check` passed. Scoped RuboCop still exits nonzero on two `Minitest/AssertWithExpectedArgument` warnings in the pre-existing reset assertions of `test/integration/base_preference_zenith_identity_test.rb`; comparing the file at HEAD confirmed both warnings are pre-existing. The new and modified code has no other scoped offenses.

### C5.1 stale-JWT loss case: unresolved contract conflict

Source inspection confirms that a signed but stale JTI reaches `current_realm_preference_for_write`, returns no usable row, and can lead the writer to create a default row and apply the submitted field. This can make the browser receive a new snapshot that omits other non-default choices. The old COM integration test explicitly expects this stale-token/new-row behavior. C4-9 now says stale writes must be refused and retried after credential recovery, but the accepted `adr/invalid-browser-credential-recovery.md` still specifies the legacy behavior pending C5-2/C5-3 decisions, while C5-3/C5-5 do not settle recovery issuance and the response/cookie result. A patch that accepts the stale mutation, creates a replacement row, or changes the wire failure without reconciling these contracts could silently select the wrong owner behavior. No stale-JTI writer change or test that blesses either outcome was made. This C5.1 item remains open for explicit contract reconciliation.

Other five.md items remain bounded by the same C0/C5 status: the `PreferenceSelect` browser repro is unavailable in this environment; the Chronicle structure dump cannot be hand-edited; cookie/JWT lifecycle, reset, Affinity and Cookie Consent shape/ownership work remains deferred until its decisions are complete.

## 2026-11-04 — continued bounded implementation and validation

Updated the stale C10 review-1 P0-3 row in `five.md`: the `preference-visa-writer-boundary.md` amendment was completed on 2026-11-04 as recorded in C9.2. This documentation correction does not close the still-open C5 recovery and cookie/JWT lifecycle decisions.

No additional Experience schema, route ownership, cookie, JWT recovery, reset, Affinity, Cookie Consent, Web Push binding, or Chronicle dump code was implemented. C0 still says the redesign is not an implementation-ready contract, and the relevant C5 choices remain open. The browser repro remains unavailable. Guessing those owners or persistent shapes would make unresolved design decisions in code; the completed bounded slices in C4/C9 remain the safe implementation limit.

The focused security regressions exercised during this continuation are recorded in `zero.md`. A test-only `ClientPasskey` row in `test_app_zenith_db` was removed only after its exact ID, timestamp, fixture absence, missing outbox and association to the current fixture Client were checked; the Client and its older OIDC connection were retained. No Experience data, schema, or cookie state was changed during this cleanup.

## 2026-11-04 — RP-local passkey removal and five.md Chronicle dump

The RP-local APP / ORG passkey removal path cannot take a root token from the browser RP's local session. It resolves the current root from the verified Step-Up event `sid`, performs an initial locked evidence and management-policy check, and calls `CredentialSecurityTransition` before the final OP-to-Zenith commit. That transition retains the current root and does not revoke other sessions, but it invalidates Step-Up freshness and unfinished authentication admissions. Those invalidations can persist if deletion is refused, rolls back, or has an indeterminate commit. The final commit re-locks and rechecks the event and policy before writing the receipt and deleting the passkey. This is fail-closed over-invalidation chosen to preserve the existing transition semantics; it can interrupt unrelated authentication work and require Step-Up again even when deletion does not complete. It is not an atomic transition with the source delete.

The current Chronicle dump is header-only (448 bytes), while the development database reports every Chronicle migration up. The current worktree already contains a modified dump with 3,361 removed lines and an untracked migration that only inserts the previously approved `security` retention policy. I left both intact. I did not regenerate `db/chronicle_structure.sql`: Rails change rules prohibit a schema-dump diff without a corresponding intentional schema migration, and regeneration would overwrite pre-existing work. The dump cannot be repaired by hand, and the unrelated retention-row migration does not authorize schema changes. This remains a C9.1 blocker until the existing worktree change and schema authority are reconciled. No database write or schema-dump generation was performed.

## 2026-11-04 — five.md stale-generation and browser-reproduction dilemmas

### C4-9 stale `jti` write

The requested fail-closed behavior conflicts with the still-accepted `adr/invalid-browser-credential-recovery.md` Preference section and its old missing/refused-cookie recovery behavior. `five.md` C4-9 requires stale writes to be rejected and retried after credential recovery, while C5-3 leaves the recovery response, cookie issuance and exact handling of first access unresolved. In the current `PreferenceWriteBoundary`, `current_realm_preference_for_write` returns `nil` for a stale `jti`, after which the writer may create a new row and apply submitted values. APP/ORG processing also commits Account Experience before validating the Browser Experience row. A narrow rejection added only at the latter point would still permit a partial Account write and would conflate independent Guest/User ownership.

No writer change was made in this pass. The required fix must first separate Guest Browser Experience writes from authenticated Account Experience writes, define the stale-credential recovery result, and reconcile the accepted ADR. The concrete mismatch is recorded in `zero.md`; the latest post-switch result is `evidence/2026-11-04-op-step-up-lock-and-regression-rerun-J6N4.md`.

## 2026-11-04 — five.md implementation scope audit

Re-read current five.md clauses C0, C4, C5 and C9 while continuing the requested implementation. C0 restricts code changes to individually closed slices; the remaining C5 items still leave cookie/JWT recovery, persistence, route ownership, lifecycle and result semantics undecided. C4-9 also conflicts with the still-accepted invalid-browser-credential recovery behavior until C5-2/C5-3 and the ADR are reconciled. A narrow stale-JTI rejection would therefore risk partial Account Experience writes and would not define recovery. C13 expressly requires a live browser reproduction before changing PreferenceSelect synchronization; no configured browser/DevTools tool is available. No additional five.md code was safe to implement in this pass. The already closed C4-18 and C5.1 slices remain implemented and verified; this pass did not change their contracts or code.

### C13 `PreferenceSelect` browser repro

The source still initializes local selection state from `form.value` only on mount. C13 requires a same-page browser reproduction before changing synchronization behavior and requires preserving an in-progress user edit. No configured browser or DevTools tool is available in this execution environment. No component change was made and the regression remains unverified; a server-rendered or component test alone would not satisfy the requested live-browser observation.


## 2026-11-04 — five.md continuation after O-10 lock-order work

Rechecked five.md C0/C4/C5/C9 while continuing the requested implementation. No additional five.md code was safe to add in this pass: the remaining C5 items still leave cookie/JWT recovery, persistent/API shape, route ownership, lifecycle and result semantics undecided. C4-9 stale-generation rejection remains in conflict with the accepted `adr/invalid-browser-credential-recovery.md`; a narrow rejection can still commit Account Experience first and does not define recovery behavior. C13 requires a live browser reproduction before changing `PreferenceSelect` synchronization, but no configured browser/DevTools tool is available. The Chronicle dump also remains a pre-existing dirty-worktree collision and cannot be repaired by hand. These are the dilemmas behind leaving those slices unchanged; the closed C4-18 and C5.1 work remains implemented.

## 2026-11-04 — O-10 passkey registration commit-boundary dilemma

The current `IdentityPasskeyRegistrationFinalCommitter` takes the Zenith actor lock, opens an OP transaction, consumes the registration candidate and transaction, completes the Auth ceremony, and only then creates the Zenith credential and `ClientPasskeyAuditOutbox` / `OperatorPasskeyAuditOutbox` row. `PasskeyRegistrationOperation` nests its Zenith transaction inside the actor transaction, so the current order commits OP before Zenith. The APP and ORG commit-order tests explicitly assert this legacy order and assert that a failed Zenith commit leaves the OP registration consumed.

Accepted revision 13 O-10 requires the Zenith credential and durable result to commit while OP authority locks remain held; the O-10 boundary also requires the OP authorization transaction to remain read-only. Moving candidate/ticket/ceremony completion to a second OP transaction after the Zenith commit would leave a crash and expiry window. `AuthCeremonySession#complete!` permits completion only while the ceremony is active, so expiry between the confirmed Zenith commit and the second OP transaction can leave a committed credential with an uncompleted ceremony and unconsumed OP transaction. Completing the ceremony before Zenith commit would instead consume the ceremony when the source write rolls back. The existing outbox has `operation_ref = transaction.transaction_id`, but that column is not unique and the current final committer does not use it to reconcile an unknown Zenith commit.

Do not select a substitute transition or success response without resolving this boundary. A safe implementation needs an accepted recovery rule for post-source OP finalization, ceremony expiry/revocation during that interval, and the durable receipt identity/replay check. If that rule needs new persisted fields or JSON metadata, obtain the `generic/data-shape-design.mdc` shape approval first. Until then, the passkey registration path remains an O-10 blocker; passkey rename/removal and the other repaired O-10 paths are separate.

## 2026-11-04 — five.md implementation recheck

O-9 is waiting for review, so I rechecked five.md's C0/C4/C5/C9 closed-slice boundary. The completed C4-18 name changes and C5.1 notification no-persistence scaffold are already implemented. Remaining C5 choices still govern persistence, cookies/JWT, recovery, route ownership and lifecycle; C13 still requires a live browser reproduction; the Chronicle dump conflicts with existing dirty work. No additional five.md implementation was safe in this continuation. No five.md feature behavior or data shape was changed.

## 2026-11-04 — C13 PreferenceSelect browser reproduction and implementation

The earlier notes saying that no browser was configured are superseded by this run. Chromium at /usr/bin/chromium and the repository's Playwright installation were available. The Rails E2E launcher required PLAYWRIGHT_CHROMIUM_EXECUTABLE=/usr/bin/chromium; it also needed the Base surface availability flags in the already-dirty scripts/e2e/server.rb so base.com.localhost would serve the real page. Existing Turnstile and sign-in flag edits in that file were preserved.

The pre-fix reproduction used a live Rails-rendered Inertia page and intercepted only the PATCH response. The response carried a new same-page form.value, while the select retained its old value. The first follow-up case used the language screen, but Rails disables its only alternate option; Playwright correctly refused the unavailable choice. I changed the browser case to the theme screen, whose current option is disabled and whose two remaining options support both a submitted choice and a newer edit during the pending response. No application write was sent: PATCH responses were fulfilled by Playwright.

The implementation keeps a local draft only while it is dirty. A clean control derives its value directly from current server props, so an Inertia response can replace it without an effect-based reset. A monotonically increasing draft revision lets onSuccess clear the dirty flag only if no newer edit happened during that submission. The component interaction test mounts the public component and rerenders its props; an initial attempt to test a pure exported helper tripped the file's unconditional afterEach cleanup because the test had not mounted a React root, so that helper was removed and behavior is now tested through the component.

Focused Vitest passed 13 tests and the final Chromium E2E run passed 2 tests: clean props synchronization and preserving a newer edit during an in-flight update. Scoped Oxlint and formatting checks passed. Full bun run typecheck still fails on gait/pages/auth/org/org_auth_screens.test.tsx:342 (turnstile is unused); the existing worktree diff removed the invitation tests that used it. I left that unrelated change intact. The E2E initial request was a read-only GET against the configured test environment; all PATCH requests were intercepted, with no preference database write.

The previously recorded C13 blocker is therefore resolved for this slice. The remaining five.md C5 recovery, cookie/JWT, persistence, lifecycle and route-owner decisions remain blockers under C0; this browser fix does not choose any of them.

### C13 verification correction — full typecheck

The initial `bun run typecheck` failure described above came from an orphaned `turnstile` fixture declaration in `gait/pages/auth/org/org_auth_screens.test.tsx`. The existing worktree diff had already removed the invitation tests that referenced it. After confirming with `rg` that the declaration had no remaining consumer, removed that unused declaration. The subsequent `bun run typecheck` passed; scoped Oxlint and Oxfmt checks also passed. This correction supersedes the earlier statement that the typecheck remains failing. No application behavior changed in this follow-up.

## 2026-11-04 — Secret sign-in receipt caller lock trace

Traced the only production creation call for `ClientSecretSignInReceipt`. `AuthenticationBase#log_in` reaches `write_secret_sign_in_receipt!` under `with_actor_session_lock(resource)`; the issuance path then holds the OP `SignInFlow` cycle lock. `verify_successful_commit!` re-locks that same OP flow and reads the Zenith Client and claimed credential without taking `FOR UPDATE`. The receipt callback and its validations do not acquire a principal row lock, so this direct creation path does not establish an OP-to-principal reverse edge. The caller-held-lock boundary and unrelated database callbacks are not proven by this trace. The lock inventory records this limited disposition; its global review is still incomplete.

## 2026-11-04 — stale unbound signup Flow caller trace

Traced the production `with_cycle_lock` callers for `ClientSignUpFlow`, including OTP issuance, Auth social pending-Client binding, explicit-step/passkey flows, state-machine transitions, termination/cleanup, lifecycle reconciliation and finalization. The bound paths either enter through the Client-first override or hold the Client before entering it. For the unbound social-binding entry, observing a concurrent binding returns without locking or mutating the existing Client; other traced actor-mutating paths resolve the actor before they can proceed, or perform cleanup after the Flow lock and use its stale-binding retry. `SignUpStateMachine` production callers only transition Flow state under this lock; the optional `before_clear` callback appears only in a test. No additional stale-blank-to-bound reverse edge was found in these call sites. This is a bounded call-site trace, not proof against external pre-held locks or unrelated callbacks; the complete O-10 graph remains open.

## 2026-11-04 — O-10 registration receipt and five.md dump findings

The current APP/ORG passkey and APP TOTP final committers acquire the actor before OP rows, but commit OP consumption before the enclosing Zenith transaction commits the credential. Reversing the order as O-10 requires changes the failure mode: after Zenith commits, an OP finalization failure must be recoverable without inserting a second credential or relying on an Auth ceremony that may expire. The current passkey source outbox already has the operation reference, actor and credential references, but no uniqueness constraint. The TOTP source has no operation receipt. I drafted `specs/op-mediated-step-up/contracts/o10-registration-source-receipts.md`: reuse the passkey outbox with a partial unique registration-operation index, and add an APP TOTP receipt keyed by the original transaction and credential. This is a proposed data shape, not approval to migrate or implement. Review must settle whether receipt-backed finalization may proceed after Auth ceremony expiry and how the moved TOTP path records the existing `totp.enable` activity event. The current `IdentityTotpEnrollmentFinalCommitter` omits that event; the older `IdentityTotpCeremonyFinalCommitter` calls `IdentityAudit.record!` but is not its caller.

The O-10 candidate review remains incomplete. Current `db/app_zenith_structure.sql` is 448 bytes with no table definitions because an existing uncommitted diff removes 9,973 lines; `db/org_zenith_structure.sql` is 262,172 bytes. I preserved those changes and did not regenerate the dump. `ClientTotpCredential`'s generated annotation names `app_principal`, while its code inherits from `AppPrincipalRecord < AppZenithRecord` and the configured writer is `app_zenith`; use the code connection owner when planning the receipt migration, and keep this annotation/dump discrepancy visible.

The five.md C9.1 note now corrects the current-worktree app_zenith dump state. C4-18, C5.1 and C13 are already closed and verified. C0 still blocks cookie/JWT, recovery, persistence and route-owner work until C5 decisions close; no remaining five.md feature slice was safe to implement in this pass. Current five.md SHA-256: `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`.

## 2026-11-04 — O-10 authorization-initiation trace and five.md follow-through

Traced APP/ORG Visa authorization initiation through `OidcAuthorizationTransactionCoordinator.issue_with_handoff!`, `SignUpEmailPendingGuard`, and `BaseAuthAdmissionCoordinator.issue_handoff!`. The direct sequence locks the OP authorization parent and admission binding, without resolving or locking a Client / Operator principal. The observed sequence is OP-parent → OP-binding, not an OP-to-principal reverse edge. This closes only this entry method; pre-held caller locks, callbacks and exceptional paths remain unverified.

I reviewed five.md again as requested. Its closed C4-18 rename, C5.1 no-persistence scaffold, and C13 synchronization fix are already implemented. Additional feature work remains gated by its unresolved C5 decisions. The current dirty schema dumps cannot be regenerated or restored without overwriting existing changes; C3-17 also requires owner approval for dump repair and database reconstruction. I made no five feature-code or persistence changes. That is the specific blocker behind not expanding implementation further in this pass.

Reviewed five.md SHA-256: `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`. HEAD: `b30345216886c98af1f04cbd434f067f12decf01`; worktree extensively uncommitted.

## 2026-11-04 — O-10 OP-only consume candidates

The lexical scan included `OrganizationInvitation#consume!` and `LogoutTransaction#consume!`. Their methods lock OP rows but do not themselves resolve a principal. The invitation service is reachable only through `OrgRegistrationPolicy#consume!`, for which no production caller was found; the active lifecycle acceptance path returns the migration-required refusal before consume. The logout transaction consumer has no application callsite. These are bounded no-inversion findings, not proof about future call composition. The inventory now names both files; current scan totals are 88 candidates, 13 named by full path, and 75 not yet named by full path. The broader lock graph remains open.

## 2026-11-04 — post-switch failures remain behind Q-1 and O-11 decisions

The repeated post-switch test run remains 50 / 229 / 3 failures. Q-1's valid mode change still returns 422 at the RP-local current-session-token guard; the contact-registration completion and sensitive-action expectations still hit the intentional 503 boundary. The current fail-closed contact-registration test passed in its earlier run, so changing these three expectations to make the suite green would hide the unfinished behaviors. The Q-1 OP session binding and O-11 source API/receipt shapes remain unapproved; no dependent code or test contract was changed. Current-session evidence is `evidence/2026-11-04-op-step-up-post-switch-confirmation-P5D2.md`.

## 2026-11-04 — five.md implementation recheck during O-10 continuation

Re-read five.md C0, C5 and C9 while continuing the requested implementation. C9 lists the bounded theme-ordering, notification no-persistence, C4-18 rename, and C13 synchronization slices; each is already implemented and recorded as verified. C0 permits only those individually closed slices, so this pass found no additional five.md feature implementation that is ready to add. The remaining cookie/JWT, recovery, persistence, route and lifecycle decisions remain open under C5; C4-9 also conflicts with the accepted invalid-browser-credential recovery ADR, and the dirty schema dump must not be regenerated or hand-edited. This recheck adds no new product decision. five.md SHA-256: `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`.

## 2026-11-05 — requested five.md implementation recheck during O-10 work

The owner asked me to implement five.md work alongside the OP Step-Up continuation. I re-read C0, C5, C5.1 and C9 at SHA-256 `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45`. C0 still says this is a design-stage document and limits implementation to individually closed slices in C9; those slices are already recorded as implemented. The stale-generation regression in C5.1 is not safe to turn into a passing behavior change yet: C4-9 conflicts with the accepted invalid-browser-credential recovery ADR, while C5-3 leaves the response and recovery procedure unresolved. A narrow guard would still permit partial Account Experience and Browser Experience writes. The dirty Chronicle and app_zenith dump changes also remain protected from regeneration under C3-17 and the Rails change rules. I made no five.md product-code, route, cookie, persistence or dump change. This is the specific implementation boundary behind the current pause on new five.md feature work; it does not stop the independent O-10 Case work.

## 2026-11-05 — five.md follow-through during O-10 session-revocation work

Re-read C0, C5 and C9 at SHA-256 `ab191cb1d6d1099dbf38d6c4c85faa68b5850733ba3483e9e2425860d211ab45` in response to the owner's request to complete five.md work where possible. The C9 slices remain already implemented. C5 still leaves the cookie/JWT contract, stale and initial-access recovery, Affinity record and reset semantics, Consent identity and Web Push binding, route placement and PUT behavior, notifications, and legacy audit/adult-gate disposition open. These decisions determine persistence and cross-surface authority; the owner instruction does not specify their concrete shapes, and the repository's data-shape and destructive-change rules still apply. No further five.md product, route, cookie, schema, or dump change was safe in this pass. This is the concrete remaining implementation boundary; no new five-specific product decision was inferred.
