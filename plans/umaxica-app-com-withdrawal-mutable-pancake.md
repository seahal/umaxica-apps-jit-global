# app/com Withdrawal Core — Final Closeout 監査実行プラン

## Context

app/com の退会（withdrawal ceremony / re-entry / recovery / early termination）、privacy erasure
request、retention hold / purge guard、occurrence 記録、processor erasure notification が「app/com
withdrawal
core として完了」と報告されている。本タスクは新機能追加なしの closeout 監査であり、成果物は指定フォーマットの最終レポート（判定 A/B/C +
invariant 結果 + severity 付き findings）である。

事前調査で確認済みの事実:

- 監査対象ファイルはほぼ全て実在。パス差異のみ:
  - withdrawal sessions controller →
    `app/controllers/base/{app,com}/identity/withdrawal/sessions_controller.rb`
  - erasure status view →
    `app/views/base/{app,com}/identity/privacy/erasure/statuses/show.html.erb`（`statuses_controller.rb`
    が提供）
- **欠落**: `app/models/authentication_current_resource_resolver.rb` は存在しない → 実際の current
  subject 解決箇所（`authentication_base.rb` /
  `authentication_withdrawal_gate.rb`）を代替として監査する。
- routes は `config/routes/base.rb` に app/com 両サーフェスで期待どおり存在（withdrawal
  resource、withdrawal/session new/create/destroy、privacy/erasure new/create、erasure/status
  show）。
- occurrence 基盤:
  `app/models/concerns/withdrawal_occurrence_recording.rb`、`occurrence.rb`、`occurrence_hmac.rb`、`app/models/occurrence_record.rb`、`client_occurrence.rb`
  / `visitor_occurrence.rb` 等。
- migrations は app/com principals に 20260703 系（ceremonies / privacy+retention tables / FK
  validate / processor notification status FK）が対で存在。org 側への追加なし（実行時に再確認）。
- working tree
  diff は withdrawal と無関係（CMS テスト、test_helper、.simplecov、pnpm、concern 削除）→ 「pre-existing
  unrelated」に分類見込み。withdrawal 実装は既にコミット済み。

## 実行手順

### 1. コードレビュー（read-only）

プロンプト §3 の実在ファイルを読み、§4 の invariant 群（C1–C11, R1–R9, A1–A8, P1–P12, H1–H7, O1–O10,
N1–N7）を pass/fail/unknown 判定する。重点:

- `withdrawal_ceremony_authentication.rb` / `withdrawal_ceremony_cookie.rb` /
  `withdrawal_ceremony_reentry.rb` —
  token_digest のみ保存か、cookie 分離、consume/revoke、wrong-surface/subject 拒否、re-entry で通常トークン非発行
- `authentication_base.rb` + `authentication_withdrawal_gate.rb` —
  deactivated/withdrawn の通常認証遮断、HTML redirect / JSON 403
  WITHDRAWAL_REQUIRED、refresh/DBSC 経路
- `client_privacy_request.rb` / `visitor_privacy_request.rb` + `privacy_erasure_request_flow.rb` —
  jurisdiction / request_source / response_due_at / denial / legal-hold
  state、recovery との相互作用（received→cancel、verified/processing/completed→block）
- `retention_purge_job.rb` + retention hold models — active hold
  block、released/expired 非 block、idempotency、durable event
- `withdrawal_occurrence_recording.rb` + occurrence models — plaintext token/PII 非混入、履歴専用
- `processor_erasure_notification_job.rb` + notification models — unsupported
  processor 非 silent-success、retry/failure、idempotency
- views（status/new）— §8 UX チェック（withdrawal 世界の操作のみ、通常設定リンクなし、app/com 分離）

### 2. Diff 分類

`git diff --name-status` / `--stat` / `--check` を実行し、working tree の変更を pre-existing
unrelated / required /
accidental に分類（現時点の見立て: 全て withdrawal 無関係の pre-existing）。org ファイル・Turnstile への副作用なしを確認。

### 3. テスト実行

```bash
PARALLEL_WORKERS=1 bin/rails test \
  test/integration/withdrawal_ceremony_session_test.rb \
  test/integration/withdrawal_ceremony_reentry_test.rb \
  test/integration/privacy_erasure_request_test.rb \
  test/jobs/retention_purge_legal_hold_test.rb \
  test/jobs/processor_erasure_notification_job_test.rb \
  test/security/invariants/withdrawal_gate_invariant_test.rb \
  test/security/invariants/withdrawn_resource_refresh_invariant_test.rb \
  test/integration/app_withdrawal_step_up_enforcer_test.rb \
  test/integration/withdrawal_lifecycle_security_test.rb \
  test/integration/withdrawal_gate_test.rb
```

続けて
`bin/rails db:migrate`、`RAILS_ENV=test bin/rails db:migrate`、`bin/rails zeitwerk:check`、`git diff --check`、structure
dump の差分有無確認。余力があれば broad suite（integration + jobs +
security/invariants）を流し、失敗を withdrawal-related / unrelated pre-existing /
introduced に分類する。

注意: db:migrate / schema dump が structure
SQL に差分を生む場合はレポートに記載し、コミットはしない（監査タスクのため working
tree への恒久変更は避け、生じた差分は報告のみ）。

### 4. Legal/privacy readiness + UX チェック

§7・§8 のチェックリストをコードとビューから確認（withdrawal と erasure の state
machine 分離、31日 recovery window ≠ erasure deadline、legal hold 優先、status
page の許可操作のみ、app/com 相互アクセス不可）。

### 5. 最終レポート

§10 のフォーマットそのままで出力。判定は §11 のルールに従う（focused suite pass + Critical/High
invariant 全 pass → checkpoint/merge、Critical あり or focused suite fail → block）。

既知の findings 候補（レポートに反映予定）:

- `authentication_current_resource_resolver.rb`
  が報告と異なり不存在 — 実装が別箇所にあれば Low（ドキュメント/報告齟齬）、認証境界の実装自体が欠けていれば High/Critical。
- パス差異（withdrawal/sessions、erasure/statuses）—
  routes と整合しており Low（報告記述の齟齬のみ）の見込み。

## 成果物

- チャット上の最終レポート（§10 フォーマット、判定 A/B/C、recommendation: checkpoint/merge/block）
- 運用メモに従い、レポートを `memos/2026-07-16-app-com-withdrawal-closeout-audit.md`
  にも保存（日本語）
