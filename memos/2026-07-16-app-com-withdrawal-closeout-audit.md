# app/com Withdrawal Core — Final Closeout 監査レポート (2026-07-16)

## 最終判定

**A. Complete** — app/com withdrawal core は完了扱いでよい。security / recovery / erasure / purge /
occurrence の core invariant はコードとテストで確認できた。当初 focused suite で
`withdrawal_gate_invariant_test.rb`
の Visitor 系 3 テストがテスト自身のセットアップ不備（reference データ未シード）で error になっていたが、監査中に 1 行修正（`VisitorTokenBindingMethod.ensure_defaults!`）を適用し、focused
suite は 38 runs, 167 assertions, 0 failures, 0
errors で全て green になった。実装コード自体に問題はなかった。

## テスト結果

- focused suite 初回実行（指定 10 ファイル、PARALLEL_WORKERS=1）: 38 runs, 156 assertions, 0
  failures, **3 errors**, 0 skips
- 3 errors は全て `test/security/invariants/withdrawal_gate_invariant_test.rb` の Visitor 系:
  `PG::ForeignKeyViolation: visitor_token_binding_method_id=0 not in visitor_token_binding_methods`
  - 原因: `withdrawal_visitor_and_headers`（L200-210）が `VisitorToken.create!`
    で binding_method を指定せず DB default 0 (NOTHING) が入るが、テストの
    `ensure_visitor_token_reference_records!` は `LEGACY` しかシードしない。Client 側は
    `ClientTokenBindingMethod.ensure_defaults!` で全 default をシードしており非対称。
  - **適用済み修正**: `test/security/invariants/withdrawal_gate_invariant_test.rb` 内の2箇所の
    `ensure_visitor_token_reference_records!`（module-level helper と duplicate）を
    `VisitorTokenBindingMethod.find_or_create_by!(id: LEGACY)` →
    `VisitorTokenBindingMethod.ensure_defaults!` に変更。
  - **修正後再実行**: focused suite 全体で **38 runs, 167 assertions, 0 failures, 0 errors, 0
    skips**（全 green）。実装コード自体に不具合はなく、legacy binding method を廃止する必要もない。
- `bin/rails db:migrate` / `RAILS_ENV=test bin/rails db:migrate`: 差分なしで完走、structure
  dump 変化なし
- `bin/rails zeitwerk:check`: "all is good"
- `git diff --check`: クリーン

## Invariant 判定

- Ceremony C1–C11: **pass**。token_digest（SHA-256）のみ保存、plaintext は
  `attr_reader :plaintext_token`（非永続）。timing-safe compare、TTL
  30min、consume/revoke、`authenticate` は active + digest 一致 + `subject_withdrawal_restricted?`
  を要求（active subject のセレモニーは無効）。cookie は `withdrawal_ceremony`
  専用名で access/refresh/DBSC と分離。
- Re-entry R1–R9: **pass**。email OTP、existence-safe dummy 経路 + 最小経過時間、active subject は
  `withdrawal_reentry_subject_eligible?` で拒否、成功時は `issue_withdrawal_ceremony!`
  のみ（通常 token/refresh/DBSC 非発行）。
- Auth boundary A1–A8: **pass**（うち Visitor invariant
  3 件はテスト error のため integration 側でのカバレッジによる pass）。`AuthenticationWithdrawalGate`
  が closing/suspended/terminated/deactivated を allowlist（withdrawals コントローラ +
  health のみ）外で HTML redirect / JSON 403 `WITHDRAWAL_REQUIRED`。refresh 系は
  `withdrawn_resource_refresh_invariant_test` が pass。
- Privacy erasure P1–P12: **pass**。`PrivacyRequestState` に jurisdiction /
  request_source（self_service/support_manual/authorized_agent/guardian）/
  response_due_at（`PrivacyRequestDueDate`）/ BLOCKED_BY_LEGAL_HOLD / PARTIALLY_DENIED /
  retention_exception_code。recovery は
  `open_for_recovery_block`（VERIFIED/PROCESSING/COMPLETED/BLOCKED_BY_LEGAL_HOLD/PARTIALLY_DENIED）で拒否、RECEIVED は
  `cancel_from_recovery!`。active subject は `create_privacy_erasure_request!` 冒頭で 403。
- Retention/purge H1–H7: **pass**。`RetentionPurgeJob#anonymize_accounts` が `active_at`
  hold で skip（RELEASED/EXPIRED/期限切れは非 block）、skip は idempotent、`withdrawal.purge_skipped_by_hold`
  occurrence 記録、open request を
  `block_by_legal_hold!`。子テーブルの delete_all は anonymizer が purged_at を確定するまで Infinity のため実質 hold-gated。
- Occurrence O1–O10: **pass**。`WithdrawalOccurrenceRecording`
  は ALLOWED_CONTEXT_KEYS の allowlist、UA/IP はハッシュ or 参照 ID のみ、plaintext
  token/PII なし。requested/deactivated/recovered/terminated/ceremony issue・consume・revoke/privacy
  requested・cancelled・blocked/purged/shredded/processor
  requested・notified・failed を記録。履歴専用（state 判定は actor カラム）。
- Processor notification N1–N7:
  **pass**（ただし成功パスはスタブ、下記 finding）。request 作成時に PROCESSOR_KEYS 全件
  `find_or_create_by!` + job enqueue。`terminal?` で idempotent。unsupported key は
  `mark_failed!(code: "processor_unavailable")` + occurrence で silent
  success なし。failure は retry_count increment。

## Diff 分類（working tree）

- withdrawal-related: なし（実装は全てコミット済み）
- unrelated pre-existing: Gemfile.lock, string_primary_key.rb / uuid_v7_primary_key.rb 削除, pnpm-*,
  CMS/test_helper/simplecov 系テスト変更, turnstile_replay_test.rb（Turnstile 差分は本実装と無関係）
- accidental: なし。org migration 追加なし、org controller 変更なし。

## Findings

1. **[Medium → Fixed] Visitor gate invariant テスト 3 件がセットアップ不備で error**
   - `withdrawal_gate_invariant_test.rb` の visitor helper が `VisitorTokenBindingMethod`
     の NOTHING(0) を未シード。挙動は `withdrawal_gate_test.rb`
     で pass しており実装バグではなかった。監査中に `ensure_defaults!` へ修正済み、focused
     suite 全 green を確認。
2. **[Medium] Processor notification の成功パスが実外部連携なしのスタブ**
   - SUPPORTED_PROCESSORS は即
     `mark_notified!`。状態機械・監査・失敗経路は完備であり、実 processor 連携は out-of-scope（inventory
     follow-up）。
3. **[Low] 報告と実体のパス齟齬**
   - `authentication_current_resource_resolver.rb` は不存在（gate は
     `AuthenticationWithdrawalGate` + `AuthenticationBase` に実装）。sessions controller は
     `identity/withdrawal/sessions_controller.rb`、erasure status は
     `privacy/erasure/statuses_controller.rb`。実装欠落ではなく報告記述の齟齬。

## UX / Legal readiness

- status ページ（edit.html.erb）: recovery / early termination / erasure リンク /
  ceremony 終了ボタンのみ。通常設定・credential 系リンクなし。**pass**
- app/com 分離: ceremony
  class がサーフェスごとに別モデル・別 DB（Client/Visitor）で構造的に分離。**pass**
- §7 legal readiness: withdrawal と erasure は別 state machine、31日 recovery window ≠
  response_due_at、legal
  hold 優先、denial/retention_exception 記録可、request_source 拡張済み。**pass**

## Completion checklist

app/com withdrawal complete: yes / org out of scope: yes / re-entry: yes / auth hardening: yes /
privacy erasure: yes / legal hold guard: yes / occurrence: yes / processor notification:
yes（外部連携は inventory follow-up）/ docs updated: 未確認（follow-up）/ unrelated diffs isolated:
yes

## Recommendation

**checkpoint / merge** — invariant テスト修正済み、focused suite 全 green。
