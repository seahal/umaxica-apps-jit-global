# Passkey識別・重複登録防止・User Verification再設計 — 調査結果と実装計画

## 進捗状況(2026-07-19 再開時点)

**完了済み(worktreeに存在、テスト緑):**

- WS-A: `app/values/webauthn/uv_policy.rb` 新規、両verifierをUvPolicy経由化、全call
  siteにpurpose配線(direct_sign_in / mfa_challenge / ordinary_step_up /
  registration)、静的回帰テスト2件追加(`webauthn_invariants_test.rb`)
- WS-B: metadata永続化migration 3本 + `config/webauthn/aaguid_catalog.yml` +
  `Webauthn::AuthenticatorNameResolver` +
  `Webauthn::AuthenticatorMetadata`(permit付き)+ 登録経路(sign-up直接persist / settings commit /
  final committer)へ保存配線 + description初期値=provider名(案D)+ JSがresponse.transports送出 + show
  viewsにprovider表示 + locale4ファイル(provider_name / unknown_authenticator)
- WS-C: `webauthn_user_handle` migration 3本(backfill+UNIQUE+null:false)、`WebauthnUserHandleOwner`
  concern を Client/Visitor/Operator へ include、`passkey_ceremony_context.rb`のuser.idをhandleへ変更、fixtures更新
- WS-D/E:
  `test/models/webauthn_duplicate_registration_test.rb`(同一credential再登録拒否・別account拒否・DB
  race・revoked拒否・同一AAGUID許容・opaque handle)+
  `test/services/webauthn/verifier_uv_policy_test.rb`(全purpose UV=false拒否をFakeClient実暗号で)+
  `authenticator_name_resolver_test.rb` + 既存`test/unit/webauthn/verifiers_test.rb`をpurpose対応
- WS-F: org監査(`OperatorChronicleEvent::PASSKEY_REGISTERED = 15` +
  settings/committer両経路のaudit_event_id)。com はchronicle基盤自体が無いため対象外(docsに残存ギャップとして記載する)
- Operator drift解消: `name`→`description` rename、external_id
  uuid化、未使用カラム削除、関連テスト全修正
- migration実行済み(dev/test)、passkey関連スイート全緑(invariants 9 / unit+services+models 57 / auth
  controllers 884)

**残作業(2回目再開後に完了):**

1. ✅ docs 4本(invariants / architecture / runbook 新規、assurance-levels に UvPolicy 表追記)
2. ✅ ADR 3本(passkey-uv-policy / passkey-authenticator-metadata / webauthn-user-handle)
3. ✅ 検証: pnpm test 286件緑、passkey関連Rails 120件+auth controllers 884件+touched integration
   81件緑、rubocop(新規ファイル no offenses)、flat-layout invariant の allowlist に resolver 追加
4. ✅ フルスイート確認完了。本変更起因は flat-layout allowlist(修正済み)と `save(validate: false)`
   経路の user handle NOT NULL(`WebauthnUserHandleOwner` に before_save 追加で修正済み)。残る 2
   failures(`sign_out_notice_test` /
   `model_only_line_coverage_test`)はセッション開始前から worktree にあった別作業の変更・未追跡ファイル由来で本変更とは無関係(sign_out はユーザー変更分を stash すると消えることを確認)。

## Context

Passkey/WebAuthn について 3 項目(①認証器の商品名/プロバイダ名取得、②同一 Passkey の二重登録防止、③通常 sign-in での UV 必須化)を調査した。現行実装は
`plans/project-umaxica-passkey-delightful-melody.md`
の redesign がほぼ実装済みで、②③はすでに大部分が満たされている。本計画はギャップ(metadata 未永続化、friendly
name 解決なし、user handle が内部 PK、UV
policy の任意文字列化リスク、UV=false 回帰テスト不在、com/org 監査欠落)を埋める。未デプロイのため破壊的 migration を許可済み。

## Executive summary

| 項目                  | 判定                                                                                                                                                                                                                                                                                |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ① 商品名/プロバイダ名 | **部分的に可能**。gem 3.4.3 で AAGUID/transports/attachment/backup flags 取得可能(`Webauthn::AuthenticationContext` が計算済み・未永続化)。`attestation: "none"` のため AAGUID は自己申告値=表示補助専用。friendly name はローカルカタログで解決(将来 MDS 差し替え可能な interface) |
| ② 二重登録            | **exact duplicate は既に完備**(3 テーブル `webauthn_id` UNIQUE + model validation + `RecordNotUnique`→409 + excludeCredentials 全件 + JS `InvalidStateError`)。同一認証器の別 credential 生成は WebAuthn 標準で判定不能(明記)。残作業はテスト強化と user handle 改善                |
| ③ 通常 sign-in UV     | **既に実装済み**(全 ceremony required + `verify(..., user_verification: true)` + `user_verified?`/`user_present?` 再検証 + 静的回帰テスト)。残作業は用途別 policy object 化と UV=false FakeClient 回帰テスト                                                                        |

## Grill Me 確定事項

1. 表示: **案D** — 登録時に friendly name を `description`
   初期値に自動設定、利用者は自由変更可。metadata 名は別カラム保持で上書きしない
2. 名前解決: **ハイブリッド** — ローカル AAGUID カタログ + `Webauthn::AuthenticatorNameResolver`
   interface(`source:` 付き)、将来 MDS 差し替え可
3. unknown AAGUID: 現行 default 名(「パスキー」/"My Passkey")維持、詳細画面は「不明な認証器」
4. revoked credential の再登録: **拒否維持**(現行どおり)
5. password fallback: **既存 sign-in 選択画面へ戻す**(新 flow なし、WebAuthn ceremony と混在しない)
6. step-up UV:
   **policy 化しつつ全用途 required 維持**(挙動不変、将来 ordinary_step_up だけ緩和可能な構造)
7. 同一 provider 複数 credential: UI 警告**なし**
8. user handle: **opaque `webauthn_user_handle` へ破壊的変更**

## 実装計画

### WS-A: UV policy object 化(挙動不変)

- 新規 `app/values/webauthn/uv_policy.rb`: 閉じた enum。`DIRECT_SIGN_IN` / `REGISTRATION` /
  `MFA_CHALLENGE` / `ORDINARY_STEP_UP` / `HIGH_RISK_STEP_UP` — 全て現状 `required`。call
  site から任意文字列を排除。
- `app/services/webauthn/registration_verifier.rb`(`USER_VERIFICATION` 定数)と
  `assertion_verifier.rb` を policy 経由に変更。server 側 `verify(..., user_verification: true)` +
  `user_verified?`/`user_present?` 再検証は維持。
- `test/unit/security/webauthn_invariants_test.rb` に追加ガード: verifier 以外での
  `user_verification:` 文字列直指定禁止、`UvPolicy` 以外からの値供給禁止。

### WS-B: metadata 永続化 + friendly name

- migration(app_principal / com_principal / org_principal、破壊的可):
  - 追加: `aaguid` (uuid, null 可), `transports` (string/json), `backup_eligible` (bool),
    `backup_state` (bool), `authenticator_attachment` (string), `provider_name` (string, null 可),
    `metadata_source` (string, null 可)
  - Operator: `name`→`description` rename、`external_id` 型統一、未使用
    `user_handle`/`webauthn_id_binary` 整理
- `config/webauthn/aaguid_catalog.yml`: 主要 passkey provider の AAGUID→名前(数十件)。
- 新規 `app/services/webauthn/authenticator_name_resolver.rb`:
  `resolve(aaguid) → {name:, source:}`。zero/未知 AAGUID→nil(登録は拒否しない、失敗で ceremony を壊さない)。
- `passkey_registration_flow.rb` / `sign_settings_passkey_registration.rb` /
  `identity_passkey_ceremony_final_committer.rb`: `AuthenticationContext`
  相当の registration 側 context から aaguid 等を Candidate に載せて保存。`description`
  未入力時は resolver 名を初期値に(解決不能なら現行 i18n default)。`provider_name`
  は利用者 label と別カラム、上書きしない。
- 一覧/詳細 view(`app/views/auth/{app,com,org}/settings/passkeys/`): 主表示は
  `description`、詳細に provider 名(なければ「不明な認証器」)・登録日・last_used_at。

### WS-C: user handle opaque 化

- Client / Visitor / Operator に `webauthn_user_handle` (string, null: false,
  UNIQUE) 追加。`SecureRandom.urlsafe_base64(32)`、生成後不変。
- `app/controllers/concerns/passkey_ceremony_context.rb:40` の `user_id: resource.id.to_s.b`
  を handle に変更。
- PII でない・surface 間で独立・PK 変更耐性ありをテストで固定。

### WS-D: 二重登録テスト強化(実装は現状維持)

- FakeClient(`test/support/webauthn_fake_client_helper.rb`)で: 同一 credential 再登録拒否(sign-up /
  settings 両方)、別 account への登録拒否(DB
  UNIQUE)、race で片方のみ成功(`RecordNotUnique`→409)、excludeCredentials に revoked 含む全件、同一 AAGUID 別 credential を拒否しないこと。
- surface 間重複は「別 RP ID のため別 credential になる」旨を invariants
  doc に明記(コード変更なし)。

### WS-E: UV 回帰テスト

- FakeClient で UV=false の registration / direct sign-in / MFA / step-up
  assertion が全て拒否されることを追加(melody plan Phase 7 残作業の該当分)。
- sign-in 成功時の auth context(`auth_method: "passkey"`、UV 済み)記録をテスト。
- 静的回帰: UvPolicy 迂回禁止(WS-A)。

### WS-F: 監査の surface 揃え

- com/org の settings registration に app 同等の audit イベント(`PASSKey_REGISTERED`
  相当)を追加(`sign_settings_passkey_registration.rb` の `audit_event_id` 経路)。

## Migration plan(未デプロイ・破壊的可)

各 principal DB へ通常 migration で追加/rename(データ移行不要)。`webauthn_user_handle`
は backfill 付き `null: false`。Operator の rename/型統一も直接実施。

## Documentation plan(日本語)

- `docs/security/webauthn-security-invariants.md`(新規、静的テストが参照済み): UV
  policy 表、二重登録保証、user handle、surface 境界、標準上防げない重複の明記
- `docs/security/webauthn-architecture.md`(新規): ceremony map(本調査の表)、名前解決アーキテクチャ
- `docs/security/authentication-assurance-levels.md` 更新: UvPolicy と各 flow の対応表
- `docs/operations/passkey-runbook.md`(新規): カタログ更新手順、unknown AAGUID 対応、revoked 方針
- ADR(新規・日本語): passkey-authenticator-metadata(案D + local catalog +
  MDS 差し替え interface)、webauthn-user-handle、passkey-uv-policy

## Verification

```bash
bin/rails test test/unit/security/webauthn_invariants_test.rb
bin/rails test test/models/{client,visitor,operator}_passkey_test.rb
bin/rails test test/controllers/auth/app/settings/passkeys_controller_test.rb
bin/rails test test/controllers/auth/{app,com,org}  # passkey 関連一式
bin/rails test  # 最終
```

FakeClient による UV=false / duplicate / race の failing test を先に追加してから実装(承認後)。

## 仕様上の限界(残存)

- `attestation: "none"` のため AAGUID は改竄可能 → 表示専用、security 判定に不使用
- 同一物理認証器の別 credential 生成は WebAuthn 標準で確実に判定不可
- UV の具体手段(指紋/顔/PIN)は RP へ通知されない
- syncable passkey の provider 移動・restore 後の AAGUID 変化は追跡不可
