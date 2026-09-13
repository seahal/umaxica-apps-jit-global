# Project Umaxica: Passkey / WebAuthn 全面再設計プラン

## Context

未デプロイの Passkey /
WebAuthn 実装を全面監査した結果、既知 Finding をすべて一次検証で確認した。破壊的変更が許可されているため、局所パッチではなくサーフェス境界・ceremony・AAL2 評価・ライフサイクル・通知・テスト・文書を一体で再設計する。

### 確認済み Finding(すべて実コードで検証済み)

1. **面別設定が死んでいる**: `app/controllers/concerns/sign_webauthn.rb:88-97` の
   `webauthn_surface_env_key` は `/\ASign::App::/` 等で判定するが、実コントローラは `Auth::App::*` →
   `WEBAUTHN_APP_RP_ID` 等は一度も参照されず、共有 `WEBAUTHN_RP_ID`/`WEBAUTHN_ORIGIN` →
   `request.host`/`request.base_url` へ fallback(:26-35)。
2. **Origin 比較が scheme+host のみ**(:57-70)— ポート未比較。
3. **challenge が surface / RP ID / Origin / account に未束縛**(:208-253)—
   purpose と expiry、one-time use のみ。
4. **UV policy**: 登録 `"preferred"`(:129)、認証デフォルト `"preferred"`(:148)、MFA challenge
   controller は `"discouraged"` を渡す。AAL2 相当の保証なし。
5. **テストが偽 namespace でバグを隠蔽**: `test/controllers/concerns/sign/webauthn/config_test.rb`
   が `::Sign::App::WebauthnConfigTestController`
   を定義し面別 env が「効く」ように見せている。全 controller フローテストは `verify → true`
   スタブで実暗号経路未検証。UV=false 拒否・sign_count 後退・クロスサーフェス再利用・ポート不一致・controller レベル replay のテストが存在しない。
6. **`Webauthn` モジュール二重定義**: `app/controllers/concerns/webauthn.rb`(WEBAUTHN_RP_MAP)vs
   `config/initializers/webauthn.rb`(TRUSTED_ORIGINS、production の `validate_rp_id_configuration!`
   は共有キーを許容)。
7. **passkey lifecycle 通知が皆無**(登録/削除/失効/compromise すべて)。mailer も view も存在しない。
8. **`configured_webauthn_value` の ENV.fetch
   1 引数バグ**は既知(`plans/1-webauthn-origin-webauthn-app-origin-harmonic-biscuit.md`)だが、本再設計で concern ごと消滅する。

### 決定事項

- **Surface decision**: APP / COM / ORG すべてで passkey を維持。APP/COM = primary sign-in + MFA +
  step-up。**ORG = 維持(ユーザー確認済み)** — リポジトリに AWS IAM Identity
  Center の痕跡はなく、実際の ORG 方針は Entra ID
  SSO(sign-in、`adr/org-entra-id-sign-in-boundary.md`)+ ローカル passkey/passcode(step-up・AAL2 唯一の phishing-resistant 手段、`docs/security/step-up-mfa-status.md`)。責務重複なし。用途・AAL・recovery・失効主体を ADR に明文化する。
- **Assurance decision**: 「**AAL2-aligned**」を主張(NIST conformant は主張しない — 既存
  `adr/authentication-assurance-level-boundaries.md` の「NIST-inspired product
  terms」方針と整合)。AAL2 経路は `userVerification: "required"` + サーバ側 UV/UP
  flag 検証必須。UV=false assertion は AAL2 として絶対に受理しない。`preferred`/`discouraged`
  は全廃。
- **RP ID / Origin**:
  app=`auth.umaxica.app`、com=`auth.umaxica.com`、org=`auth.umaxica.org`。Origin は scheme+host+実効ポートの完全一致。親ドメイン RP
  ID 禁止、クロスサーフェス credential 共有禁止。
- **Config**: production は deployment env から面別注入・欠落時起動失敗(`ENV.fetch`
  1 引数)。非 production は Rails encrypted
  credentials(`webauthn.{app,com,org}.{rp_id,origin}`)。production での
  `request.host`/`request.base_url`/共有キー fallback を実装ごと排除。
- **Surface 解決**:
  controller クラス名の正規表現推測を廃止し、明示的宣言(class マクロ)+ 値オブジェクトへ。
- **Removal**: 物理 DELETE でなく status 遷移による auditable
  invalidation(既存 Retainable/retention 方針に整合)。通常削除は step-up 必須、compromise 報告は低フリクション(step-up 不要、代わりに全 session 失効)。
- **Notification**: 登録/削除/失効/compromise/recovery で必須。transactional outbox(既存
  `chronicle_outbox_entry`)+ Solid Queue job + retry。
- **経路構成**: classic インプロセス経路(session challenge)と JWT
  ceremony 経路(`IdentityPasskeyCeremony*` + durable transaction)は用途が別(同一オリジン XHR vs
  sign/id 境界、`adr/identity-authority-boundary.md`)のため両方維持。ただし検証コアは共通 Verifier に一本化。

### gem API 確認済み

webauthn 3.4.3。`AuthenticatorResponse#verify(..., user_verification: true)` で
`authenticator_data.user_verified?` を検証。`WebAuthn::FakeClient`/`FakeAuthenticator`
が gem に同梱されておりテストで実暗号経路を使える。

---

## Phase 0 — 既知欠陥の failing tests 先行

新規(最初に赤を確認):

- `test/unit/webauthn/relying_party_config_test.rb` — production env 欠落で fail-fast、request.host
  fallback 不存在、ポート込み Origin 完全一致(`https://auth.umaxica.app:8443` 拒否等)
- `test/unit/webauthn/challenge_test.rb` —
  surface/rp_id/origin/purpose/actor バインディング不一致拒否、one-time、TTL
- UV=false
  assertion 拒否(FakeClient で UV フラグ制御)、sign_count 後退拒否、クロスサーフェス credential 再利用拒否、controller レベル challenge
  replay 拒否、通知(outbox 行 + job enqueue + mail)テスト

削除: `test/controllers/concerns/sign/webauthn/config_test.rb`(偽 `Sign::App` ハーネス)。

検証: `bin/rails test test/unit/webauthn`(赤の確認)

## Phase 1 — 設定・値オブジェクト層

新規:

- `app/values/webauthn/surface.rb` — `:app/:com/:org` 閉じた列挙。actor / passkey model / status /
  ceremony transaction / mailer namespace への写像を持つ不変 VO。
- `app/values/webauthn/relying_party_config.rb` — `rp_id`,
  `origin`(URI、scheme+host+実効ポート比較)、memoized `WebAuthn::RelyingParty`。`trusted_origin?`
  は正規化 URI 完全一致のみ。
- `app/resolvers/webauthn/relying_party_config_resolver.rb` — production:
  `ENV.fetch("WEBAUTHN_APP_RP_ID")` 等(KeyError = fail-fast、fallback なし)。非 production:
  `Rails.application.credentials.dig(:webauthn, :app, :rp_id)` 等、欠落時明示エラー。dev/test
  credentials に 3 面 ×
  rp_id/origin を登録(dev の値は現行 localhost ホスト群に合わせて確定 — リスク 1 参照)。
- `app/controllers/concerns/webauthn_surface_declarable.rb` — `webauthn_surface :app`
  クラスマクロ。各面の Auth 基底 controller に 1 行宣言。未宣言で raise。

書き換え: `config/initializers/webauthn.rb`
— 起動時に production で 3 面分 resolver 実行 fail-fast。共有キー許容の
`validate_rp_id_configuration!` 廃止。グローバル `WebAuthn.configure` 廃止。

削除: `app/controllers/concerns/webauthn.rb` +
`app/controllers/concerns/webauthn/`(参照 grep 後)、空スタブ
`app/controllers/sign/org/configuration/passkeys/`。

## Phase 2 — チャレンジストア再設計

- `app/values/webauthn/challenge.rb` — `challenge`,
  `purpose`(registration/authentication/step_up)、`surface`, `rp_id`, `origin`, `actor_global_key`,
  `expires_at`。`consume!` で全一致検証、不一致は種類別例外。
- `app/services/webauthn_challenge_store.rb` — 現行 `store_challenge!`/`fetch_and_delete_challenge!`
  を置換。one-time・TTL 10min・上限 5 は踏襲。
- ceremony 経路: `*_passkey_ceremony_transactions` に `rp_id`/`origin`/`purpose` NOT
  NULL 追加(未リリースにつき既存 migration 書き換え、`db/{app,com,org}_tickets_migrate/20260603123000-2`)。`IdentityPasskeyCeremonyResultConsumer`
  に一致検証を追加。

## Phase 3 — 検証コア + UV=required

- `app/services/webauthn_registration_verifier.rb` / `webauthn_assertion_verifier.rb` —
  `RelyingPartyConfig` + `Challenge` を受ける surface 非依存サービス。options 生成は
  `user_verification: "required"`(`resident_key` は現行 "discouraged" 踏襲 —
  allow-list 型フロー維持)。検証は `credential.verify(..., user_verification: true)` +
  `authenticator_data.user_verified?`/`user_present?` の明示再確認。`from_get`/`from_create` は常に
  `relying_party:` 付き。
- `app/values/webauthn/authentication_context.rb` — uv / up / sign_count / aaguid / backup_eligible
  / backup_state / method / time / assurance を保持。
- sign_count: 保存値未満は拒否 + `AuthenticationSecurityEventEmitter`(clone 疑い)。
- MFA challenge controller の `"discouraged"` 渡しを削除。`normalize_webauthn_options_for_json` 系は
  `app/values/webauthn/options_serializer.rb` へ移設(JS `src/controllers/webauthn_utils.js`
  との往復整合テスト付き)。

## Phase 4 — Concern 整理

- **削除**: `sign_webauthn.rb`(全機能移管完了後)。
- **統合**: sign-in 系 8 concern(`sign_passkey_*`)→ `passkey_sign_in_flow.rb` +
  `passkey_registration_flow.rb` の 2 つへ。`sign_settings_passkey_registration{,_endpoint}.rb`
  も registration flow + Phase 6 lifecycle サービスへ統合。
- **維持・書き換え**:
  `sign_verification_passkey_{actions,checks}.rb`(step-up)— 内部を Verifier 呼び出しへ、`"discouraged"`
  廃止。
- routes: org に app/com と同型の `settings/passkeys/{options,verifications}`
  を補う(controller は既存、route 欠落のみ)。org sign-up telephone
  passkey は追加しない(Entra 方針、ADR 明記)。

## Phase 5 — データモデル整合(migration 書き換え)

- `db/org_principals_migrate` の operator_passkeys を Client/Visitor 形状へ:
  `name`→`description`、`discarded_at`/`purged_at`(Retainable)、`public_id`、`sign_count`
  bigint、`webauthn_id_binary` 撤去。`user_handle` は使用箇所 grep 0 件確認の上削除。
- 3 テーブル共通追加: `aaguid`, `transports`, `backup_eligible`, `backup_state`, `revoked_at`,
  `compromised_at`, `uv_at_registration`。`expires_at`
  は採用しない(固定 expiration 不採用 — 長期未使用は棚卸し促し方式。threat
  model 上、強制再登録は弱い recovery 経路へ誘導するため)。
- 共通ロジック(MAX 4、active scope、status 遷移、sign_count 更新)を
  `app/models/concerns/passkey_credential.rb`
  に抽出。status 参照テーブル(ACTIVE/DISABLED/REVOKED/DELETED/NOTHING)維持。

## Phase 6 — ライフサイクル + 通知

- サービス: `PasskeyRegistrar` / `PasskeyRemover`(DELETED + discarded_at)/
  `PasskeyRevoker`(REVOKED + revoked_at)/ `PasskeyCompromiseReporter`(compromised_at +
  REVOKED、step-up 不要、全 session 失効)。各サービスは同一 DB transaction で状態遷移 +
  `chronicle_outbox_entry`(webauthn_id はダイジェストのみ — `ChronicleRecorder`
  の FORBIDDEN_KEY_PATTERN 遵守)+ `*_notification_record` + Solid Queue job enqueue。
- 通常削除は step-up 必須。**最後の credential 削除**: 他の有効な AAL2 手段がなければ拒否し、mfa-reset
  recovery(`adr/mfa-reset-account-recovery.md`:
  72h 冷却 + 二重 operator 承認 + 全 credential 失効)へ誘導。
- `CredentialSecurityTransition` フック: 登録/削除/失効時に他 session・step-up 鮮度を失効。
- Chronicle イベントに PASSKEY_REVOKED/PASSKEY_COMPROMISED を追加(client/visitor/operator)。`AuthenticationSecurityEventEmitter`
  allowlist に `passkey.registered/removed/revoked/compromised` 追加。
- `app/mailers/email/{app,com,org}/passkey_mailer.rb` + views + ja/en
  locale(registered/removed/revoked/compromise_reported。credential ID・public
  key・challenge を含めない。event type / 時刻 / 表示名 / 対処導線のみ)。

## Phase 7 — 回帰ガード + テスト実質化

- `test/unit/security/webauthn_invariants_test.rb`(既存 `forbidden_rails_patterns_test.rb`
  と同形式の静的ガード): `request.host`/`request.base_url` の WebAuthn 文脈使用、共有
  `WEBAUTHN_RP_ID`/`WEBAUTHN_ORIGIN`、`user_verification.*(preferred|discouraged)`、`WebAuthn.configure`/global
  mutation、`relying_party:` 無し `from_get|from_create`、host-only Origin 比較 — をすべて禁止。
- `verify → true` スタブ全廃: `WebAuthn::FakeClient` ベースの
  `test/test_helpers/webauthn_fake_client_helper.rb`
  を作り controller フローテストを実暗号経路へ置換。UV フラグは FakeClient で制御。
- `satisfy_user_verification` ヘルパ(~20 ファイル)を実 step-up 実行ベースへ置換。
- Phase 0 の赤テストを全緑化。

検証: `bin/rails test`(全体)

## Phase 8 — ドキュメント / ADR(日本語)

- `docs/security/webauthn-architecture.md`(構成・ceremony
  flow・二経路の用途分離・challenge/credential lifecycle・notification/recovery/session 統合)
- `docs/security/webauthn-security-invariants.md`(機械検証可能な不変条件 ↔ 回帰ガード対応表)
- `docs/security/authentication-assurance.md`(AAL2-aligned の定義、満たす/満たさない要件、syncable
  passkey・attestation="none" の扱い)
- `docs/operations/passkey-runbook.md`(登録問題・compromise・emergency
  revocation・通知失敗・設定事故・recovery・metrics/alert・未デプロイ時再設定手順)
- 利用者向けポリシー文言(views/locale)
- ADR 新規:
  webauthn-surface-config、passkey-challenge-binding、passkey-lifecycle-notifications、**org-passkey-purpose**(Entra=SSO
  / passkey=step-up・AAL2、失効主体)、passkey-expiration-policy(固定 expiration 不採用の根拠)
- 既存 `docs/security/webauthn-rp-id-origin-boundary.md`
  改訂、obsolete 文書(`docs/shared/tasks/security_key.md`
  等)supersede。`plans/1-webauthn-origin-*.md` は本再設計で superseded とマーク。

## Verification(フェーズ毎)

各フェーズで narrow → broad の順:

1. `bin/rails test test/unit/webauthn`
2. `bin/rails test test/models`(+ `bin/rails db:reset` 各 principal DB、Phase 5)
3. `bin/rails test test/controllers/auth/{app,com,org}`
4. `bin/rails test test/services test/mailers test/jobs`
5. `bin/rails test test/integration`
6. `bin/rails test`(全体)+ lint(rubocop 等 README/CI 記載のコマンド確認)
7. JS: `pnpm test`(webauthn_utils / Stimulus controller 変更時)

## リスク

1. **dev/test の rp_id/origin**: credentials 値は現行 localhost ホスト群(`sign.app.localhost:3000`
   等)と一致させないとローカル全滅。Phase 1 冒頭で確定。
2. **`user_handle` 削除**は grep 0 件確認必須(ceremony committer が書いている可能性)。
3. **JS 往復整合**: options serializer のパラメータ名変更時は 4 つの Stimulus
   controller をすべて更新。
4. **`Webauthn` 旧モジュール削除**は `::Webauthn.trusted_origins` 等の参照 grep 後に実施。
5. **UV=required の UX**:
   UV 非対応 authenticator は登録不可になる。未デプロイのため既存ユーザー影響なし。文言を用意。
