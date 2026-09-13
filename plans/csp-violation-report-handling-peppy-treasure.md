# CSP Violation Report Handling — Grill Me 再評価と最小修正計画

最終更新: 2026-06-17ステータス: Draft (planning) 関連:
`plans/backlog/gh645-csp-violation-reporting.md`, `plans/archive/csp-violation-reporting-plan.md`,
`adr/csp-and-permissions-policy.md`, `adr/csp-violation-report-route-naming.md`,
`adr/application-logging-boundary.md`, `docs/security/observability-boundary.md`

## Context

CSP violation report を「DB 永続化しない観測イベント」として再評価する依頼。前提:

- raw report を DB に保存しない
- controller concern で受信・正規化・イベント発火を共通化
- Rails 8.1 の `Rails.event` subscriber が回収して structured log に流す
- 大量 / 悪意 / 壊れた JSON / 巨大 payload でアプリを壊さない

現状はすでに Phase 1 (intake + structured log) は実装済み。本 plan はその grill
me 評価と、不足分の最小修正計画である。新規テーブル追加・新規 model 追加・外部監視サービス連携は行わない。

## 重要な事前矛盾 (要相談)

`adr/application-logging-boundary.md` (2026-05-21 accepted) は次を宣言している:

- 「`Rails.event` is not the application logging API」
- 「Application code no longer depends on custom `Rails.event.info/warn/error/debug/record`
  methods」
- ただし同 ADR は「It may be reconsidered later for **non-log event reporting**」とも明記

ユーザ依頼「Rails 8.1 の Rails.event subscriber で回収」は、CSP violation report を **non-log
observability event** として扱う限りは ADR と整合する。ADR が禁じたのは「Rails.event を application
logging のフロントとして使うこと」であり、「Rails.event を非ログ観測イベントの回収経路として使うこと」は明示的に保留扱い。

→ 本 plan は「CSP violation report を non-log observability event とみなし、Rails 8.1 ネイティブ
`Rails.event` API (`Rails.event.notify` + subscriber) を解禁する」案として進める。ただし
`adr/application-logging-boundary.md` の追補 ADR (Rails.event は non-log
observability に限定) を同時に書く必要がある。これを Phase 0 とする。

## 観測した現状

### 構成 (現存ファイル)

- `app/controllers/concerns/csp_violation_report.rb` (24 行): concern。
  `rate_limit to: 120, within: 1.minute, only: :create`、`record_csp_violation!`、
  `ignore_malformed_csp_report` のみ
- `app/services/csp_violation_report_intake.rb` (191 行): JSON parse、normalize、scrub、allowlist
  payload 組立、`logger.info(JitLogEvent.format("security.csp_violation", report))`
- `app/controllers/**/csp_violation_reports_controller.rb` × 26 (surface × host): 各 controller は
  `include CspViolationReport` し、`record_csp_violation!` 後 `head :no_content`。全て
  `BareController < ActionController::Base` を継承
- `config/routes/{acme,base,core,docs,help,news,palm,sign}.rb`:
  `resource :csp_violation_report, only: :create, path: "csp-violation-report"`
- `config/initializers/content_security_policy.rb:52`: `policy.report_uri("/csp-violation-report")`
- `test/controllers/csp_violation_reports_controller_test.rb` (96 行) と
  `test/services/csp_violation_report_intake_test.rb` (230 行)
- DB テーブル / model / migration / job / mailer / fixture: **存在しない**

### grill me checklist 観測結果

1. **DB 保存していないか** → ✅ PASS。AR
   model、migration、create!、insert_all、upsert_all、job いずれも未検出。raw
   payload を保存している箇所なし。
2. **concern の責務** → ⚠️
   concern は薄すぎず太すぎず。だが現在 concern が持つのは rate_limit 宣言と service 呼び出しと rescue だけ。size
   limit / parse / truncate / event notify / 204 response が
   **service に集中**している。設計判断として妥当だが境界が unclear。後述。
3. **CSRF / routing / 204 応答**
   - CSRF: `BareController` は
     `protect_from_forgery using: :header_or_legacy_token, with: :exception`。CSP report は header
     token を持たない外部 POST なので **このままでは ParseError でなく
     `ActionController::InvalidAuthenticityToken` で落ちる可能性あり**。→ controller 側で
     `skip_forgery_protection` を明示する必要があるか要確認。AGENTS.md は `skip_forgery_protection`
     全面禁止だが、CSP report endpoint は仕様上 cross-site
     POST を受ける必要があり例外設計が必要。**未解消の整合性問題。**
   - POST のみ: ✅ `only: :create` で OK
   - 204: ✅ controller は常に `head :no_content`、service は `Result` を返すだけ
   - rescue: ✅ `ActionDispatch::Http::Parameters::ParseError` → 204、 `JSON::ParserError` →
     service 内で吸収
   - 認証: ✅ BareController は AUTHENTICATION_MODE=:bare で session/actor 不要
4. **入力サイズ制御**
   - `request.body.read` を **controller (concern) で全部読み込んでから**
     service に渡す (`csp_violation_report.rb:15`)。`MAX_BODY_BYTES = 64.kilobytes` チェックは
     **read 完了後** `service#call` 内で `raw_body.bytesize > MAX_BODY_BYTES`
     (line 50)。→ 攻撃者が 1GB の Content-Length を投げた場合、read 段階で全部メモリに乗る。**Rack 側 (`config.action_dispatch.maximum_request_form_size`
     相当) または `request.body.read(MAX_BODY_BYTES + 1)` で
     **読み込み量を制限**するべき。**現状の欠陥。\*\*
   - field truncate: ✅ `MAX_STRING_LENGTH = 256`
   - invalid encoding: ✅ `encode("UTF-8", invalid: :replace, undef: :replace, replace: "")` 済み
   - URL scrub (query/fragment 除去): ✅ `sanitize_url` で実施
5. **JSON parse 耐性**
   - malformed → ✅ `rescue JSON::ParserError` で `:malformed` status
   - nested `csp-report` + Reporting API array 両対応 ✅ (`legacy_report_body` /
     `reporting_api_body`)
   - nil / number / array / string / null JSON: ✅ tests passing (intake_test.rb 87-220)
   - `symbolize_names: true` を使っていない: ✅ attacker-controlled symbol を作っていない
6. **payload 安全性**
   - allowlist 方式 ✅: `URL_FIELDS` / `DIRECTIVE_FIELDS` / `NUMERIC_FIELDS`
     以外を payload に含めない。`script-sample` も載らない (テストで `data[:script_sample]`
     nil 確認)
   - cookie / authorization header / query string: ✅ load していない
   - blocked_uri / document_uri / source_file は query/fragment 削除済み
   - remote_ip は payload に**含まれていない**。プロキシ判別の不確定さを避けたため許容
   - host: ✅ `request.host` のみ
7. **subscriber 責務** → ❌ **subscriber 自体が存在しない**
   - 現状は service から直接 `Rails.logger.info(JitLogEvent.format(...))` で書く
   - 既存の `app/subscribers/jwt_anomaly_subscriber.rb` は `JwtAnomalyEvent.create!` で
     **DB 書き込み** する subscriber (CSP の参考にはならない構成)
   - `Rails.event.notify` / `ActiveSupport::Notifications.instrument` の使用箇所なし
   - **本 plan の主たる修正対象。**
8. **rate limit / sampling**
   - controller `rate_limit to: 120, within: 1.minute`: IP × controller ×
     :create のキャッシュキー (Rails 8.0+ の `ActionController::RateLimiting`)。✅
   - aggregation_key (`category:directive:blocked_origin`) を計算しているが **dedup /
     sampling に使われていない**。同一 storm の抑制なし
   - rate limit 超過時の応答: `ActionController::TooManyRequests` でデフォルト 429。→ **CSP
     report は storm を悪化させないため 429 でなく 204 を返す方が安全**。要確認
   - Rack/Rails 側の `Rack::Request` body limit 設定なし → 4-1 の問題に直結
9. **event name / schema**
   - event 名: `"security.csp_violation"`。ユーザ希望は `"security.csp_violation.reported"`。
     **動詞付きの方が将来 `.rate_limited`, `.dropped` を追加できる。今回 rename 推奨。** ただし
     `analytics_consent_guard_pre_consent_allowlist.rb` の `SECURITY_EVENTS` パターンは
     `/\Asecurity\./` で prefix match なので rename は consent guard と非破壊的に整合
   - payload key: ✅ snake_case (`blocked_uri`, `document_uri`, `effective_directive`, ...)
   - surface: ❌ payload に surface (app/com/org) が**含まれていない**。host のみ。→
     host から surface を導出する logic は既存に `JitSecurityJwtAnomalyReporter.preference_context`
     があるが CSP 側は使っていない。**surface を payload に含める修正必要。**
   - schema 変更検出: 現テストは `data.fetch(:blocked_uri)`
     等で個別 assert している。schema 全体のキーセットを assert するテストは未整備。**追加推奨。**
10. **テスト現状**
    - valid nested / flat: ✅ (`intake_test.rb:6-38`, `:40-64`)
    - malformed: ✅ (`:66-85`, controller_test.rb:31-42)
    - empty body / null / numeric / array: ✅ (`:87-113`, `:180-220`)
    - oversized: ✅ (`:66-85`)
    - invalid encoding: ❌ 未テスト
    - long field truncated: ❌ MAX_STRING_LENGTH 境界の直接テストなし
    - `Rails.event.notify` 呼ばれることの assert: ❌ (現実装が logger 直書きのため)
    - raw payload が emit されていないことの assert: △ `script_sample` だけ確認
    - DB write は行われない assert: ❌ (テーブル不在なので暗黙確認)
    - subscriber が呼ばれる assert: ❌ (subscriber 不在)
    - subscriber 例外がリクエストを壊さない assert: ❌
11. **既存実装との整合性**
    - CSP policy 生成: 触らない方針 ✅
    - report-uri 向け先 (`/csp-violation-report`) は route と一致 ✅
    - host constraint × 26 routes: ✅ 既存
    - forgery_protection: BareController の前提と整合確認必要 (3 番参照)
12. **削除候補**: なし。raw 保存系は最初から存在していないため、削除すべきものは現時点 0。

## 主要な問題点 (優先順)

P1. **request body 読み込みに上限がない**
(`csp_violation_report.rb:15`)。read 完了後にサイズ判定。P2. **`Rails.event.notify`
を使っていない**。subscriber が存在しない。Phase 1 backlog plan
(`plans/backlog/gh645-csp-violation-reporting.md:20`) は元々 `Rails.event.record` 想定だったが、
`adr/application-logging-boundary.md`
で Rails.event の使用が引き下げられたまま、代替経路 (logger 直書き) のままになっている。P3.
**surface が payload に含まれていない**。host だけ。app/com/org の集計が pain。P4.
**aggregation_key を活かした dedup / sampling がない**。storm 抑制は IP rate limit のみ。P5. **rate
limit 超過時 429**。CSP report endpoint は 204 で吸収すべき (storm 悪化防止)。P6. **CSRF
skip の明示が controller にない**。BareController は token 要求モード。cross-site CSP
POST を取りこぼしている可能性。要検証。P7. **event 名が動詞なし**。`security.csp_violation.reported`
への rename 推奨。P8. **schema 全体の固定テストがない**。allowlist 変更を検知できない。

## 最小修正計画

### Phase 0 — ADR 追補

- `adr/application-logging-boundary.md` に対する追補 ADR を
  `adr/non-log-event-reporting-boundary.md` として新規作成。
  - 「`Rails.event.notify` は **non-log observability event** に限定して再導入する」
  - 「application log 出力には依然 `Rails.logger` を使う」
  - 「CSP violation report は non-log observability event の最初の利用例」
- `docs/security/observability-boundary.md` を該当箇所だけ追補。

### Phase 1 — request body の入力経路を堅牢化

- 変更: `app/controllers/concerns/csp_violation_report.rb`
  - `request.body.read` の代わりに `request.body.read(CspViolationReportIntake::MAX_BODY_BYTES + 1)`
    で先頭 N+1 バイトのみ取得
  - `Rack::Request` の body 読み戻しが必要なら `request.body.rewind` も併用
  - `request.content_length` が `MAX_BODY_BYTES`
    を超えていれば read を試みず service 呼び出しをスキップして 204 を返すショートサーキットを
    `record_csp_violation!` の入口に追加
- 変更: `app/services/csp_violation_report_intake.rb`
  - `raw_body.bytesize > MAX_BODY_BYTES` 判定はそのまま残し (defense in depth)
  - `Result.new(status: :too_large, reports_count: 0)` の挙動は維持
- 変更: rate limit 超過時の応答
  - `CspViolationReport` concern に
    `rescue_from ActionController::TooManyRequests, with: :ignore_rate_limited_csp_report` を追加
  - `ignore_rate_limited_csp_report` は `head :no_content`

### Phase 2 — Rails.event.notify + subscriber 化

- 変更: `app/services/csp_violation_report_intake.rb`
  - `EVENT_NAME = "security.csp_violation.reported"` に rename
  - `log_report(report)` を `emit_event(report)` に rename し、中身を
    `Rails.event.notify(EVENT_NAME, report)` に変更
  - payload に `:surface` キーを追加 (host から導出。既存
    `JitSecurityJwtAnomalyReporter.preference_context` のロジックを切り出し再利用)
- 新規: `app/subscribers/csp_violation_subscriber.rb`
  - `def emit(event)` で `event.name == "security.csp_violation.reported"` のみ受け付ける
  - `Rails.logger.info(JitLogEvent.format(event.name, event.payload))` を発火
  - 全体 `rescue StandardError => e` で
    `Rails.logger.error(JitLogEvent.format("security.csp_violation.subscriber_failed", ...))`
  - DB 書き込み・外部 HTTP・重い処理は **入れない**
- 新規: `config/initializers/event_subscribers.rb` (なければ)
  - `Rails.event.subscribe(CspViolationSubscriber.new)` (Rails 8.1 ネイティブ API)
- 変更: `app/services/analytics_consent_guard_pre_consent_allowlist.rb`
  - コメント 「Application logging no longer uses Rails.event」を「Application logging uses
    Rails.logger. Non-log observability events use Rails.event.」に修正

### Phase 3 — schema 固定とテスト追加

- 変更: `test/services/csp_violation_report_intake_test.rb`
  - event 名 rename に伴う期待値更新
  - subscriber 経由でなく `Rails.event` への notify を assert する形へ書き換え (`Rails.event.stub`
    または `ActiveSupport::Notifications` 経由)
  - schema 固定: payload の expected key set を const として持ち、各 happy path テストで
    `assert_equal EXPECTED_KEYS, data.keys.to_set` する
  - 追加: invalid encoding (UTF-8 不正バイト) 投入で 204 + event 発火継続
  - 追加: MAX_STRING_LENGTH 境界 (255 / 256 / 257) で truncation
  - 追加: `surface` キーが host から正しく導出されること (app/com/org/network/dev)
- 変更: `test/controllers/csp_violation_reports_controller_test.rb`
  - 既存の `Rails.logger.stub(:info, ...)` を `Rails.event` 経由 assert に書き換え
  - 追加: `content_length` 1GB 詐称の場合に 204 + read を試みないこと (mock で read を assert)
  - 追加: rate limit 超過時に 204 を返すこと
  - 追加: BareController の forgery protection 下で CSRF token なしでも 204 を返すこと
- 新規: `test/subscribers/csp_violation_subscriber_test.rb`
  - 正常 payload で `Rails.logger.info` が JitLogEvent.format 文字列を受け取ること
  - subscriber 内例外で request 経路が壊れないこと (subscriber 単体 unit test)
- 確認: `test/integration/routes/*_route_contract_test.rb` は引き続き green

### Phase 4 — 後始末

- `plans/backlog/gh645-csp-violation-reporting.md` の Phase
  2 セクションを更新:「DB 永続化は採用しない方針が確定。aggregation_key ベースの将来の sampling 検討は別チケット」
- `plans/active/` に本 plan を移動 (`plans/active/csp-violation-report-event-handling.md` 等)
- 必要なら `docs/security/observability-boundary.md` に「CSP violation
  report の event 名と schema」を新節として追記 (現行コードの実装と一致するように)

## CSRF 取り扱いの未解消事項 (要確認)

`BareController` は `protect_from_forgery using: :header_or_legacy_token, with: :exception`。CSP
report はブラウザが cross-site で投げる POST であり、token を持たない。本来 ParseError ではなく
`InvalidAuthenticityToken`
で落ちるはずだが、現実テスト (`controller_test.rb`) は 204 を取得できている。これは
`Content-Type: application/csp-report` または `application/json`
の場合に Rails が token 検証を**スキップ条件に該当させている**可能性が高い (`xhr?` 判定 /
token 付き fetch モード)。本 plan の Phase 1 の前に、**現状の controller test を本物の cross-site
POST を模したヘッダなし状態で再走らせ**、CSRF が落ちていないことを再確認する。

落ちる場合は `protect_from_forgery` の代わりに、CSP report endpoint に限定した
`skip_forgery_protection`
を controller 側で許可する PR を別に切る (AGENTS.md は全面禁止だが endpoint の仕様上不可避なため例外設計)。`.agents/harnesses/rules/generic/absolute-rules.mdc`
に例外を明示する別 ADR が必要になり、これは本 plan のスコープ外として注記。

## 変更ファイル一覧 (確定スコープ)

- 追加
  - `adr/non-log-event-reporting-boundary.md`
  - `app/subscribers/csp_violation_subscriber.rb`
  - `config/initializers/event_subscribers.rb` (存在しない場合)
  - `test/subscribers/csp_violation_subscriber_test.rb`
  - `notes/implementation/csp-violation-event-migration.md` (handoff note)
- 変更
  - `app/controllers/concerns/csp_violation_report.rb`
  - `app/services/csp_violation_report_intake.rb`
  - `app/services/analytics_consent_guard_pre_consent_allowlist.rb` (コメント修正のみ)
  - `test/controllers/csp_violation_reports_controller_test.rb`
  - `test/services/csp_violation_report_intake_test.rb`
  - `plans/backlog/gh645-csp-violation-reporting.md`
- 触らない
  - `app/controllers/**/csp_violation_reports_controller.rb` × 26 (現行 concern include で完結)
  - `config/routes/*.rb`
  - `config/initializers/content_security_policy.rb`
  - `bin/rails routes` 出力

## 追加/修正テスト一覧

| 種別 | テスト名                                                     |
| ---- | ------------------------------------------------------------ |
| 追加 | invalid encoding でも 204 + event 発火                       |
| 追加 | MAX_STRING_LENGTH 境界 truncation                            |
| 追加 | surface キーが host から正しく導出 (app/com/org/network/dev) |
| 追加 | payload schema fixed key-set check                           |
| 追加 | content_length 詐称で read 試行しない                        |
| 追加 | rate limit 超過時に 204 を返す                               |
| 追加 | CSRF token なし cross-site POST で 204 (現状確認)            |
| 追加 | subscriber 単体: 正常 payload で logger.info                 |
| 追加 | subscriber 単体: 内部例外で request 経路を壊さない           |
| 変更 | event 名 rename (`security.csp_violation.reported`)          |
| 変更 | logger.stub 方式 → Rails.event notify assert                 |

## 検証コマンド (実装後に実行)

```bash
bin/rails routes | grep -i csp
grep -R --line-number -i "csp.*report\|violation.*report\|Rails.event\|ActiveSupport::Notifications" app config lib test
bin/rails test test/services/csp_violation_report_intake_test.rb
bin/rails test test/controllers/csp_violation_reports_controller_test.rb
bin/rails test test/subscribers/csp_violation_subscriber_test.rb
bin/rails test test/integration/routes
bin/rails test
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## スコープ外 (今回やらないこと)

- 新規 AR model / migration / DB テーブル追加
- aggregation_key を使った sampling / dedup の実装 (将来別 plan)
- 外部監視サービス (Sentry / Datadog 等) への連携
- CSP policy 自体の見直し (`adr/csp-and-permissions-policy.md` 参照)
- 26 controller の重複解消 (surface routing 要件のため現状維持)
- 全 surface の `BareController` CSRF 設定見直し (別 ADR スコープ)
- `Rails.event` を application logging に広げる議論 (本 plan は non-log observability に限定)

## 残課題サマリ (Open Questions)

1. CSP report endpoint で CSRF が現状落ちていないのは Rails 側の
   **どの判定**による副作用か。再現テストで断定する必要あり。
2. `Rails.event.notify` の Rails
   8.1 ネイティブ API シグネチャが本リポジトリの依存と一致するか (`Rails.event.subscribe`
   のフック登録経路含む) を `Gemfile.lock` で確認。
3. payload に `surface` を入れる際の判別ロジックを `CspViolationReportIntake` 内に持つか、既存
   `JitSecurityJwtAnomalyReporter`
   のロジックを共有ヘルパに切り出すか。→ 共有ヘルパ化を推奨。`lib/observability/surface_from_host.rb`
   新設候補。
