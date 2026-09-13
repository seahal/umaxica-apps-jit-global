# Sign Settings 包括的監査レポート

**作成日:** 2026-06-23 **対象ブランチ:** develop **調査範囲:**
Sign 全 3 サーフェス (app/com/org) の settings 配下コントローラ・ルート・ビュー・サービス・テスト
**調査者:** Claude Code (claude-sonnet-4-6)

---

## 1. Executive Summary

**全体判定: MOSTLY_HEALTHY_WITH_GAPS**

Sign
settings の実装は概ね健全で、認証・オーナシップスコープ・ルート整合性については高い品質を保っている。しかし、4 件の明確な問題（P0
× 1、P1 × 0、P2 × 3、P3 × 多数）と、ADR で確定した Acme 権威境界に未対応の状態が残存している。

| 重大度 | 件数 |
| ------ | ---- |
| P0     | 1    |
| P1     | 0    |
| P2     | 6    |
| P3     | 14   |

**Confidence 分布:** HIGH 15件 / MEDIUM 4件 / LOW 2件

---

### 最優先修正事項（3項目）

1. **P0 — `Sign::Org::Settings::RemovalsController` が `authenticate_client!` を呼んでいる**
   `app/controllers/sign/org/settings/removals_controller.rb:14` org サーフェスに
   `authenticate_client!`（app サーフェス用）が混入。operator としてのセッションが存在しない Client のリクエストを誤って通過させる可能性がある。

2. **P2 — Sign `settings/sessions` がセッション破棄を直接実行している（Acme 権威逸脱）**
   `app/controllers/sign/app/settings/sessions_controller.rb:29`、
   `app/controllers/sign/com/settings/sessions_controller.rb:24`、
   `app/controllers/sign/org/settings/sessions_controller.rb:24` `token.revoke!`
   を Sign コントローラ内で直接呼んでいる。ADR
   (acme-sign-core-base-port-boundary) によりセッション変異は Acme 権威。バックログ Stage
   2 でヒューマンレビュー待ちのまま未対処。

3. **P2 — no-flash-messages ルール違反が全 3 サーフェスに蔓延** `flash.now[:alert]` および
   `redirect_to(..., notice:/alert:)`
   が app・com・org の settings コントローラ合計 12 ファイル以上で使用されている。

---

### セキュリティ境界リスク概要

- org サーフェスに app サーフェス用認証メソッドが混入（P0）。
- session 変異（revoke!）が Sign 内で直接実行されており ADR 違反の可能性。
- `params(:id)` 形式のフィルター付きパラメタ取得は owner-scoped であり IDOR リスクはないが、  
  org passkeys のみ `find(params[:id])` でデータベース整数 PK を直接使用しており、  
  他サーフェスと不整合（public_id を使用していない）。

### Acme 移行負債概要

- `AcmeAppSettingsActivityLog` / `AcmeComSettingsActivityLog` / `AcmeOrgSettingsActivityLog`  
  という Acme プレフィックスを持つサービスクラスが Sign コントローラ内で呼ばれている。  
  これは命名上の負債であり動作上の境界違反ではない。
- `AcmeSettingsWithdrawalFlow` concern が Sign 側に include されており、  
  アカウント退会ロジックの権威所在が曖昧。
- `SignSettingsAuthorityRedirect` を include しながら全アクションを自前実装している  
  Telephone コントローラが 3 サーフェス全てに存在（dead include）。

### 既存テストの十分性判定

**十分（実行確認済み）:**
app 設定テスト 152runs/658assertions、com 設定テスト 61runs/269assertions、org 設定テスト 77runs/292assertions
— 全て 0failures/0errors/0skips。 **不足:**
unauthorized アクセス・オーナシップ違反・ホスト制約のテストが不足。統合テスト（sign-acme ラウンドトリップ）は未実装。

---

## 2. Repository and Environment

| 項目                             | 値                                                           |
| -------------------------------- | ------------------------------------------------------------ |
| Branch                           | develop                                                      |
| Working tree uncommitted changes | あり（下記参照）                                             |
| Ruby version                     | 4.0.5 (2026-05-20 revision 64336ffd0e) +PRISM [x86_64-linux] |
| Rails version                    | 8.2.0.alpha                                                  |
| Test framework                   | Minitest                                                     |
| Test execution availability      | 利用可能（全スイート正常実行確認済み）                       |

**Sign/Acme settings 関連の未コミット変更ファイル:**

| ファイル                                                                   | 関連分類          |
| -------------------------------------------------------------------------- | ----------------- |
| `app/controllers/acme/app/session_limit_resolutions_controller.rb`         | Acme/session      |
| `app/controllers/acme/app/social/authentications_controller.rb`            | Acme/social       |
| `app/controllers/concerns/oidc_callback.rb`                                | OIDC/concern      |
| `app/controllers/concerns/sign_out_notice.rb`                              | Sign/concern      |
| `app/controllers/sign/app/application_controller.rb`                       | Sign/app base     |
| `app/controllers/sign/app/settings/secret_credentials_controller.rb`       | Sign/app/settings |
| `app/controllers/sign/app/settings/sessions_controller.rb`                 | Sign/app/settings |
| `app/controllers/sign/com/application_controller.rb`                       | Sign/com base     |
| `app/controllers/sign/com/settings/passkeys_controller.rb`                 | Sign/com/settings |
| `app/controllers/sign/com/settings/secret_credentials_controller.rb`       | Sign/com/settings |
| `app/controllers/sign/org/application_controller.rb`                       | Sign/org base     |
| `app/controllers/sign/org/settings/passkeys_controller.rb`                 | Sign/org/settings |
| `app/controllers/sign/org/settings/secret_credentials_controller.rb`       | Sign/org/settings |
| `docs/security/preference-settings-authority.md`                           | ドキュメント      |
| `test/controllers/sign/app/settings/secret_credentials_controller_test.rb` | テスト            |
| `test/controllers/sign/app/settings/sessions_controller_test.rb`           | テスト            |
| `test/controllers/sign/com/settings/secret_credentials_controller_test.rb` | テスト            |
| `test/controllers/sign/com/settings/sessions_controller_test.rb`           | テスト            |
| `test/controllers/sign/org/settings/secret_credentials_controller_test.rb` | テスト            |
| `test/controllers/sign/org/settings/sessions_controller_test.rb`           | テスト            |
| `notes/implementation/coverage-batch-15.md`                                | 未追跡ノート      |
| `plans/sign-settings-virtual-meteor.md`                                    | 未追跡プラン      |

---

## 3. TLD / Surface Mapping

| surface  | host (test/prod) | boot config / env var                              | route constraint           | Rails namespace | actor type               | authentication method    | status   |
| -------- | ---------------- | -------------------------------------------------- | -------------------------- | --------------- | ------------------------ | ------------------------ | -------- |
| sign/app | id.umaxica.app   | `SIGN_SERVICE_URL` / fallback `id.app.localhost`   | `{host: "id.umaxica.app"}` | `Sign::App`     | Client (end user)        | `authenticate_client!`   | VERIFIED |
| sign/com | id.umaxica.com   | `SIGN_CORPORATE_URL` / fallback `id.com.localhost` | `{host: "id.umaxica.com"}` | `Sign::Com`     | Visitor (corporate user) | `authenticate_visitor!`  | VERIFIED |
| sign/org | id.umaxica.org   | `SIGN_STAFF_URL` / fallback `id.org.localhost`     | `{host: "id.umaxica.org"}` | `Sign::Org`     | Operator (staff)         | `authenticate_operator!` | VERIFIED |

ホスト名解決: アプリ起動時に `ConfigValues::HostFamilyValues.build` が ENV を読み込み、
`sign_route_mapper` マクロが各 `sign_surface :app/:com/:org`
ブロックにホスト制約を付与。本番環境では ENV 必須（fallback なし）。テスト環境は `*.umaxica.*`
ドメインで設定済み。

---

## 4. Feature Coverage Matrix

| feature                             | app                  | com                  | org                  | route    | controller | view           | service/model  | existing test | result        |
| ----------------------------------- | -------------------- | -------------------- | -------------------- | -------- | ---------- | -------------- | -------------- | ------------- | ------------- |
| settings root                       | verified             | verified             | verified             | verified | verified   | verified       | not_applicable | verified      | HEALTHY       |
| passkey/WebAuthn                    | verified             | verified             | verified             | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| TOTP                                | verified             | intentional_absence  | intentional_absence  | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| email settings                      | verified             | verified             | verified             | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| telephone settings                  | verified             | verified             | verified             | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| Google social                       | verified             | intentional_absence  | intentional_absence  | verified | verified   | verified       | not_applicable | unknown       | HEALTHY       |
| Apple social                        | verified             | intentional_absence  | intentional_absence  | verified | verified   | verified       | not_applicable | unknown       | HEALTHY       |
| identity binding (Apple/Google)     | verified             | intentional_absence  | intentional_absence  | verified | verified   | verified       | not_applicable | unknown       | HEALTHY       |
| sessions list/show                  | verified             | verified             | verified             | verified | verified   | verified       | not_applicable | verified      | HEALTHY       |
| session revocation                  | verified             | verified             | verified             | verified | verified   | not_applicable | verified       | verified      | GAP (ADR境界) |
| withdrawal/deletion                 | verified (full CRUD) | verified (full CRUD) | verified (show only) | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| secret credential                   | verified             | verified             | verified             | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| MFA challenge                       | verified             | verified             | verified             | verified | verified   | verified       | not_applicable | verified      | HEALTHY       |
| MFA reset                           | verified             | intentional_absence  | intentional_absence  | verified | verified   | verified       | not_applicable | unknown       | PARTIAL       |
| activity log                        | verified             | verified             | verified             | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| operator lifecycle request          | not_applicable       | not_applicable       | verified             | verified | verified   | verified       | verified       | verified      | HEALTHY       |
| birthdate                           | verified             | verified             | verified             | verified | verified   | verified       | not_applicable | verified      | HEALTHY       |
| passkey options (WebAuthn API)      | verified             | verified             | verified             | verified | verified   | not_applicable | not_applicable | partial       | HEALTHY       |
| passkey verification (WebAuthn API) | verified             | verified             | verified             | verified | verified   | not_applicable | not_applicable | partial       | HEALTHY       |
| email redelivery                    | verified             | intentional_absence  | intentional_absence  | verified | verified   | not_applicable | not_applicable | unknown       | HEALTHY       |
| secrets overview                    | verified             | intentional_absence  | intentional_absence  | verified | verified   | verified       | not_applicable | unknown       | HEALTHY       |

---

## 5. Complete Route Inventory

### Sign::App Settings Routes

| method    | path                                      | helper                                              | controller#action                                 | constraints          | response target    | status   |
| --------- | ----------------------------------------- | --------------------------------------------------- | ------------------------------------------------- | -------------------- | ------------------ | -------- |
| GET       | /settings                                 | `sign_app_settings_path`                            | `sign/app/settings#show`                          | host: id.umaxica.app | settings root view | VERIFIED |
| GET       | /settings/mfa/challenge                   | `sign_app_settings_mfa_challenge_path`              | `sign/app/settings/mfa/challenges#show`           | same                 | view               | VERIFIED |
| PATCH/PUT | /settings/mfa/challenge                   | `sign_app_settings_mfa_challenge_path`              | `sign/app/settings/mfa/challenges#update`         | same                 | redirect           | VERIFIED |
| GET       | /settings/mfa/reset                       | `sign_app_settings_mfa_reset_path`                  | `sign/app/settings/mfa/resets#show`               | same                 | view               | VERIFIED |
| POST      | /settings/mfa/reset                       | `sign_app_settings_mfa_reset_path`                  | `sign/app/settings/mfa/resets#create`             | same                 | redirect           | VERIFIED |
| GET       | /settings/totps                           | `sign_app_settings_totps_path`                      | `sign/app/settings/totps#index`                   | same                 | view               | VERIFIED |
| GET       | /settings/totps/new                       | `new_sign_app_settings_totp_path`                   | `sign/app/settings/totps#new`                     | same                 | view               | VERIFIED |
| POST      | /settings/totps                           | `sign_app_settings_totps_path`                      | `sign/app/settings/totps#create`                  | same                 | redirect           | VERIFIED |
| GET       | /settings/totps/:id/edit                  | `edit_sign_app_settings_totp_path`                  | `sign/app/settings/totps#edit`                    | same                 | view               | VERIFIED |
| PATCH/PUT | /settings/totps/:id                       | `sign_app_settings_totp_path`                       | `sign/app/settings/totps#update`                  | same                 | redirect           | VERIFIED |
| DELETE    | /settings/totps/:id                       | `sign_app_settings_totp_path`                       | `sign/app/settings/totps#destroy`                 | same                 | redirect           | VERIFIED |
| GET       | /settings/passkeys                        | `sign_app_settings_passkeys_path`                   | `sign/app/settings/passkeys#index`                | same                 | view               | VERIFIED |
| GET       | /settings/passkeys/new                    | `new_sign_app_settings_passkey_path`                | `sign/app/settings/passkeys#new`                  | same                 | view               | VERIFIED |
| POST      | /settings/passkeys                        | `sign_app_settings_passkeys_path`                   | `sign/app/settings/passkeys#create`               | same                 | redirect           | VERIFIED |
| GET       | /settings/passkeys/:id                    | `sign_app_settings_passkey_path`                    | `sign/app/settings/passkeys#show`                 | same                 | view               | VERIFIED |
| GET       | /settings/passkeys/:id/edit               | `edit_sign_app_settings_passkey_path`               | `sign/app/settings/passkeys#edit`                 | same                 | view               | VERIFIED |
| PATCH/PUT | /settings/passkeys/:id                    | `sign_app_settings_passkey_path`                    | `sign/app/settings/passkeys#update`               | same                 | redirect           | VERIFIED |
| DELETE    | /settings/passkeys/:id                    | `sign_app_settings_passkey_path`                    | `sign/app/settings/passkeys#destroy`              | same                 | redirect           | VERIFIED |
| POST      | /settings/passkeys/options                | `sign_app_settings_passkeys_options_path`           | `sign/app/settings/passkeys/options#create`       | same                 | JSON               | VERIFIED |
| POST      | /settings/passkeys/verification           | `sign_app_settings_passkeys_verification_path`      | `sign/app/settings/passkeys/verifications#create` | same                 | redirect           | VERIFIED |
| POST      | /settings/passkeys/:passkey_id/removal    | `sign_app_settings_passkey_removal_path`            | `sign/app/settings/removals#create`               | same                 | redirect           | VERIFIED |
| GET       | /settings/emails                          | `sign_app_settings_emails_path`                     | `sign/app/settings/emails#index`                  | same                 | view               | VERIFIED |
| GET       | /settings/emails/:id/edit                 | `edit_sign_app_settings_email_path`                 | `sign/app/settings/emails#edit`                   | same                 | view               | VERIFIED |
| PATCH/PUT | /settings/emails/:id                      | `sign_app_settings_email_path`                      | `sign/app/settings/emails#update`                 | same                 | redirect           | VERIFIED |
| DELETE    | /settings/emails/:id                      | `sign_app_settings_email_path`                      | `sign/app/settings/emails#destroy`                | same                 | redirect           | VERIFIED |
| GET       | /settings/emails/registrations/new        | `new_sign_app_settings_emails_registration_path`    | `sign/app/settings/emails/registrations#new`      | same                 | view               | VERIFIED |
| POST      | /settings/emails/registrations            | `sign_app_settings_emails_registration_path`        | `sign/app/settings/emails/registrations#create`   | same                 | redirect           | VERIFIED |
| GET       | /settings/emails/registrations/edit       | `edit_sign_app_settings_emails_registration_path`   | `sign/app/settings/emails/registrations#edit`     | same                 | view               | VERIFIED |
| PATCH/PUT | /settings/emails/registrations            | `sign_app_settings_emails_registration_path`        | `sign/app/settings/emails/registrations#update`   | same                 | redirect           | VERIFIED |
| POST      | /settings/emails/registrations/redelivery | `sign_app_settings_emails_redelivery_path`          | `sign/app/settings/emails/redeliveries#create`    | same                 | redirect           | VERIFIED |
| GET       | /settings/telephones                      | `sign_app_settings_telephones_path`                 | `sign/app/settings/telephones#index`              | same                 | view               | VERIFIED |
| GET       | /settings/telephones/new                  | `new_sign_app_settings_telephone_path`              | `sign/app/settings/telephones#new`                | same                 | view               | VERIFIED |
| POST      | /settings/telephones                      | `sign_app_settings_telephones_path`                 | `sign/app/settings/telephones#create`             | same                 | redirect           | VERIFIED |
| GET       | /settings/telephones/:id/edit             | `edit_sign_app_settings_telephone_path`             | `sign/app/settings/telephones#edit`               | same                 | view               | VERIFIED |
| DELETE    | /settings/telephones/:id                  | `sign_app_settings_telephone_path`                  | `sign/app/settings/telephones#destroy`            | same                 | redirect           | VERIFIED |
| GET       | /settings/secrets                         | `sign_app_settings_secrets_path`                    | `sign/app/settings/secrets#show`                  | same                 | view               | VERIFIED |
| GET       | /settings/secret_credentials              | `sign_app_settings_secret_credentials_path`         | `sign/app/settings/secret_credentials#index`      | same                 | view               | VERIFIED |
| GET       | /settings/secret_credentials/new          | `new_sign_app_settings_secret_credential_path`      | `sign/app/settings/secret_credentials#new`        | same                 | view               | VERIFIED |
| POST      | /settings/secret_credentials              | `sign_app_settings_secret_credentials_path`         | `sign/app/settings/secret_credentials#create`     | same                 | redirect           | VERIFIED |
| GET       | /settings/secret_credentials/:id          | `sign_app_settings_secret_credential_path`          | `sign/app/settings/secret_credentials#show`       | same                 | view               | VERIFIED |
| GET       | /settings/secret_credentials/:id/edit     | `edit_sign_app_settings_secret_credential_path`     | `sign/app/settings/secret_credentials#edit`       | same                 | view               | VERIFIED |
| PATCH/PUT | /settings/secret_credentials/:id          | `sign_app_settings_secret_credential_path`          | `sign/app/settings/secret_credentials#update`     | same                 | redirect           | VERIFIED |
| DELETE    | /settings/secret_credentials/:id          | `sign_app_settings_secret_credential_path`          | `sign/app/settings/secret_credentials#destroy`    | same                 | redirect           | VERIFIED |
| POST      | /settings/secret_credentials/:id/rotation | `sign_app_settings_secret_credential_rotation_path` | `sign/app/settings/rotations#create`              | same                 | redirect           | VERIFIED |
| GET       | /settings/sessions                        | `sign_app_settings_sessions_path`                   | `sign/app/settings/sessions#index`                | same                 | view               | VERIFIED |
| GET       | /settings/sessions/:id                    | `sign_app_settings_session_path`                    | `sign/app/settings/sessions#show`                 | same                 | view               | VERIFIED |
| POST      | /settings/sessions/:session_id/revocation | `sign_app_settings_session_revocation_path`         | `sign/app/settings/revocations#create`            | same                 | redirect           | VERIFIED |
| POST      | /settings/revocations/others              | `sign_app_settings_revocations_others_path`         | `sign/app/settings/revocations/others#create`     | same                 | redirect           | VERIFIED |
| POST      | /settings/revocations/all                 | `sign_app_settings_revocations_all_path`            | `sign/app/settings/revocations/alls#create`       | same                 | redirect           | VERIFIED |
| GET       | /settings/activities                      | `sign_app_settings_activities_path`                 | `sign/app/settings/activities#index`              | same                 | view               | VERIFIED |
| GET       | /settings/activities/:id                  | `sign_app_settings_activity_path`                   | `sign/app/settings/activities#show`               | same                 | view               | VERIFIED |
| GET       | /settings/apple                           | `sign_app_settings_apple_path`                      | `sign/app/settings/apples#show`                   | same                 | view               | VERIFIED |
| GET       | /settings/google                          | `sign_app_settings_google_path`                     | `sign/app/settings/googles#show`                  | same                 | view               | VERIFIED |
| GET       | /settings/birthdate                       | `sign_app_settings_birthdate_path`                  | `sign/app/settings/birthdates#show`               | same                 | view               | VERIFIED |
| GET       | /settings/withdrawal/new                  | `new_sign_app_settings_withdrawal_path`             | `sign/app/settings/withdrawals#new`               | same                 | view               | VERIFIED |
| POST      | /settings/withdrawal                      | `sign_app_settings_withdrawal_path`                 | `sign/app/settings/withdrawals#create`            | same                 | redirect           | VERIFIED |
| GET       | /settings/withdrawal/edit                 | `edit_sign_app_settings_withdrawal_path`            | `sign/app/settings/withdrawals#edit`              | same                 | view               | VERIFIED |
| PATCH/PUT | /settings/withdrawal                      | `sign_app_settings_withdrawal_path`                 | `sign/app/settings/withdrawals#update`            | same                 | redirect           | VERIFIED |
| DELETE    | /settings/withdrawal                      | `sign_app_settings_withdrawal_path`                 | `sign/app/settings/withdrawals#destroy`           | same                 | redirect           | VERIFIED |

### Sign::Com Settings Routes（代表的なもの）

| method | path                                      | helper                                      | controller#action                            | status   |
| ------ | ----------------------------------------- | ------------------------------------------- | -------------------------------------------- | -------- |
| GET    | /settings                                 | `sign_com_settings_path`                    | `sign/com/settings#show`                     | VERIFIED |
| GET    | /settings/mfa/challenge                   | `sign_com_settings_mfa_challenge_path`      | `sign/com/settings/mfa/challenges#show`      | VERIFIED |
| GET    | /settings/passkeys                        | `sign_com_settings_passkeys_path`           | `sign/com/settings/passkeys#index`           | VERIFIED |
| GET    | /settings/emails                          | `sign_com_settings_emails_path`             | `sign/com/settings/emails#index`             | VERIFIED |
| GET    | /settings/telephones                      | `sign_com_settings_telephones_path`         | `sign/com/settings/telephones#index`         | VERIFIED |
| GET    | /settings/secret_credentials              | `sign_com_settings_secret_credentials_path` | `sign/com/settings/secret_credentials#index` | VERIFIED |
| GET    | /settings/sessions                        | `sign_com_settings_sessions_path`           | `sign/com/settings/sessions#index`           | VERIFIED |
| GET    | /settings/activities                      | `sign_com_settings_activities_path`         | `sign/com/settings/activities#index`         | VERIFIED |
| GET    | /settings/withdrawal/new                  | `new_sign_com_settings_withdrawal_path`     | `sign/com/settings/withdrawals#new`          | VERIFIED |
| POST   | /settings/sessions/:session_id/revocation | `sign_com_settings_session_revocation_path` | `sign/com/settings/revocations#create`       | VERIFIED |

TOTP・Apple・Google・secrets・MFA reset は com に意図的に存在しない。

### Sign::Org Settings Routes（代表的なもの）

| method | path                                                | helper                                                       | controller#action                                                 | status   |
| ------ | --------------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------- | -------- |
| GET    | /settings                                           | `sign_org_settings_path`                                     | `sign/org/settings#show`                                          | VERIFIED |
| GET    | /settings/passkeys                                  | `sign_org_settings_passkeys_path`                            | `sign/org/settings/passkeys#index`                                | VERIFIED |
| GET    | /settings/emails                                    | `sign_org_settings_emails_path`                              | `sign/org/settings/emails#index`                                  | VERIFIED |
| GET    | /settings/telephones                                | `sign_org_settings_telephones_path`                          | `sign/org/settings/telephones#index`                              | VERIFIED |
| GET    | /settings/secret_credentials                        | `sign_org_settings_secret_credentials_path`                  | `sign/org/settings/secret_credentials#index`                      | VERIFIED |
| GET    | /settings/sessions                                  | `sign_org_settings_sessions_path`                            | `sign/org/settings/sessions#index`                                | VERIFIED |
| GET    | /settings/activities                                | `sign_org_settings_activities_path`                          | `sign/org/settings/activities#index`                              | VERIFIED |
| GET    | /settings/withdrawal                                | `sign_org_settings_withdrawal_path`                          | `sign/org/settings/withdrawals#show`                              | VERIFIED |
| GET    | /settings/operator_lifecycle_requests               | `sign_org_settings_operator_lifecycle_requests_path`         | `sign/org/settings/operator_lifecycle_requests#index`             | VERIFIED |
| POST   | /settings/operator_lifecycle_requests               | same                                                         | `sign/org/settings/operator_lifecycle_requests#create`            | VERIFIED |
| POST   | /settings/operator_lifecycle_requests/:id/approval  | `sign_org_settings_operator_lifecycle_request_approval_path` | `sign/org/settings/operator_lifecycle_requests/approvals#create`  | VERIFIED |
| POST   | /settings/operator_lifecycle_requests/:id/execution | same (executions)                                            | `sign/org/settings/operator_lifecycle_requests/executions#create` | VERIFIED |
| POST   | /settings/operator_lifecycle_requests/:id/rejection | same (rejections)                                            | `sign/org/settings/operator_lifecycle_requests/rejections#create` | VERIFIED |

TOTP・Apple・Google・secrets・MFA reset は org に存在しない（適切）。

---

## 6. Route–Controller–View Matrix

| surface | feature                     | controller                                                 | action                         | view/response            | authentication                                      | ownership scope                                     | existing test | status                           |
| ------- | --------------------------- | ---------------------------------------------------------- | ------------------------------ | ------------------------ | --------------------------------------------------- | --------------------------------------------------- | ------------- | -------------------------------- |
| app     | settings root               | `Sign::App::SettingsController`                            | show                           | `settings/show.html.erb` | `authenticate_client!`                              | N/A                                                 | VERIFIED      | HEALTHY                          |
| app     | passkeys index              | `Sign::App::Settings::PasskeysController`                  | index                          | view                     | `authenticate_client!`                              | `current_client.client_passkeys`                    | VERIFIED      | HEALTHY (no authorize! on index) |
| app     | passkey destroy             | same                                                       | destroy                        | redirect                 | `authenticate_client!`                              | `find_by!(public_id:)` owner-scoped                 | VERIFIED      | HEALTHY                          |
| app     | TOTP index                  | `Sign::App::Settings::TotpsController`                     | index                          | view                     | `authenticate_client!`                              | `current_client.client_totp_credentials`            | VERIFIED      | HEALTHY (no authorize! on index) |
| app     | TOTP destroy                | same                                                       | destroy                        | redirect                 | `authenticate_client!`                              | `find_by!(public_id:)` owner-scoped                 | VERIFIED      | HEALTHY                          |
| app     | email index                 | `Sign::App::Settings::EmailsController`                    | index                          | view                     | `authenticate_client!`                              | `current_client.client_emails`                      | VERIFIED      | HEALTHY                          |
| app     | email destroy               | same                                                       | destroy                        | redirect                 | `authenticate_client!`                              | `find_by!(public_id:)` owner-scoped                 | VERIFIED      | HEALTHY (flash violation)        |
| app     | email registration          | `Sign::App::Settings::Emails::RegistrationsController`     | new/create                     | view/redirect            | `authenticate_client!`                              | `current_client`                                    | partial       | HEALTHY                          |
| app     | telephone index             | `Sign::App::Settings::TelephonesController`                | index                          | view                     | **:open (no authenticate_client!)**                 | `current_client.client_telephones`                  | partial       | GAP (open mode)                  |
| app     | telephone edit              | same                                                       | edit                           | view                     | **:private declared, no authenticate_client! hook** | `current_client.client_telephones.find_by!`         | partial       | GAP (authentication gap)         |
| app     | sessions index              | `Sign::App::Settings::SessionsController`                  | index                          | view                     | `authenticate_client!`                              | `current_client.client_tokens`                      | VERIFIED      | HEALTHY (no authorize!)          |
| app     | session revoke              | `Sign::App::Settings::RevocationsController`               | create                         | redirect                 | `authenticate_client!`                              | `current_client.client_tokens.find_by!`             | VERIFIED      | HEALTHY                          |
| app     | secret credential index     | `Sign::App::Settings::SecretCredentialsController`         | index                          | view                     | `authenticate_client!`                              | `current_client`                                    | VERIFIED      | HEALTHY (no authorize! on index) |
| app     | secret credential destroy   | same                                                       | destroy                        | redirect                 | `authenticate_client!` + step_up                    | `find_by!(public_id:)` owner-scoped                 | VERIFIED      | HEALTHY                          |
| app     | activities                  | `Sign::App::Settings::ActivitiesController`                | index/show                     | view                     | `authenticate_client!`                              | `AcmeAppSettingsActivityLog.new(current_client)`    | VERIFIED      | HEALTHY                          |
| app     | withdrawal                  | `Sign::App::Settings::WithdrawalsController`               | new/create/edit/update/destroy | view/redirect            | `authenticate_client!`                              | `current_client` + policy                           | VERIFIED      | HEALTHY                          |
| app     | Apple show                  | `Sign::App::Settings::ApplesController`                    | show                           | view                     | `authenticate_client!`                              | `current_client`                                    | unknown       | HEALTHY                          |
| app     | Google show                 | `Sign::App::Settings::GooglesController`                   | show                           | view                     | `authenticate_client!`                              | `current_client`                                    | unknown       | HEALTHY                          |
| app     | secrets                     | `Sign::App::Settings::SecretsController`                   | show                           | view                     | `authenticate_client!`                              | token consumption (no params-driven AR)             | unknown       | HEALTHY                          |
| app     | MFA reset                   | `Sign::App::Settings::Mfa::ResetsController`               | show/create                    | view/redirect            | `authenticate_client!`                              | `current_client`                                    | unknown       | PARTIAL (create disabled)        |
| com     | settings root               | `Sign::Com::SettingsController`                            | show                           | `settings/show.html.erb` | `authenticate_visitor!`                             | N/A                                                 | VERIFIED      | HEALTHY                          |
| com     | passkeys                    | `Sign::Com::Settings::PasskeysController`                  | index/show/edit/update/destroy | view/redirect            | `authenticate_visitor!`                             | `current_visitor.visitor_passkeys`                  | VERIFIED      | HEALTHY                          |
| com     | telephone index             | `Sign::Com::Settings::TelephonesController`                | index                          | view                     | **:open (no authenticate_visitor!)**                | `current_visitor.visitor_telephones` (crash if nil) | partial       | GAP (crash risk)                 |
| com     | activities                  | `Sign::Com::Settings::ActivitiesController`                | index/show                     | view                     | `authenticate_visitor!`                             | `AcmeComSettingsActivityLog.new(current_visitor)`   | VERIFIED      | HEALTHY (no authorize!)          |
| com     | withdrawal                  | `Sign::Com::Settings::WithdrawalsController`               | new/create/edit/update/destroy | view/redirect            | `authenticate_visitor!`                             | `current_visitor` + policy                          | VERIFIED      | HEALTHY                          |
| org     | settings root               | `Sign::Org::SettingsController`                            | show                           | `settings/show.html.erb` | `authenticate_operator!`                            | N/A                                                 | VERIFIED      | HEALTHY                          |
| org     | removals                    | `Sign::Org::Settings::RemovalsController`                  | create                         | redirect                 | **`authenticate_client!` (WRONG)**                  | none                                                | unknown       | **P0 BUG**                       |
| org     | passkeys                    | `Sign::Org::Settings::PasskeysController`                  | index/show/edit/update/destroy | view/redirect            | `authenticate_operator!`                            | `current_operator.staff_passkeys`                   | VERIFIED      | HEALTHY                          |
| org     | passkey destroy             | same                                                       | destroy                        | redirect                 | `authenticate_operator!`                            | `staff_passkeys.find(params[:id])` (**integer PK**) | VERIFIED      | P3 (PK not public_id)            |
| org     | operator lifecycle requests | `Sign::Org::Settings::OperatorLifecycleRequestsController` | index/show/new/create          | view/redirect            | `authenticate_operator!`                            | policy-gated (global scope)                         | VERIFIED      | HEALTHY                          |
| org     | withdrawal                  | `Sign::Org::Settings::WithdrawalsController`               | show                           | view                     | `authenticate_operator!`                            | `current_operator` + policy                         | VERIFIED      | HEALTHY (read-only only)         |

---

## 7. Settings Navigation Inventory

### Sign::App: `app/views/sign/app/settings/show.html.erb`

| source file                       | label i18n key                                        | helper/path                                      | method | status   |
| --------------------------------- | ----------------------------------------------------- | ------------------------------------------------ | ------ | -------- |
| `sign/app/settings/show.html.erb` | `controller.sign.app.setting.index.totp`              | `sign_app_settings_totps_path`                   | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.passkey`           | `sign_app_settings_passkeys_path`                | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.secret_credential` | `sign_app_settings_secret_credentials_path(ri:)` | GET    | VERIFIED |
| same                              | `sign.app.settings.show.mfa`                          | `sign_app_settings_mfa_challenge_path`           | GET    | VERIFIED |
| same                              | `sign.app.settings.show.mfa_reset`                    | `sign_app_settings_mfa_reset_path(ri:)`          | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.email`             | `sign_app_settings_emails_path`                  | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.telephone`         | `sign_app_settings_telephones_path(ri:)`         | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.birthdate`         | `sign_app_settings_birthdate_path(ri:)`          | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.session`           | `sign_app_settings_sessions_path`                | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.activity`          | `sign_app_settings_activities_path`              | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.google`            | `sign_app_settings_google_path`                  | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.apple`             | `sign_app_settings_apple_path`                   | GET    | VERIFIED |
| same                              | `sign.app.settings.show.logout`                       | `new_sign_app_sign_out_path(ri:)`                | GET    | VERIFIED |
| same                              | `sign.app.settings.show.withdrawal`                   | `new_sign_app_settings_withdrawal_path`          | GET    | VERIFIED |

**欠落リンク（ルートは存在するがリンクなし）:**

- `/settings/birthdate` (edit フォームへのリンク) — show のみで表示はリンク経由
- `/settings/secrets` — show からリンクはないが `secrets` ページが独立して存在、`secret_credentials`
  経由でアクセス

### Sign::Com: `app/views/sign/com/settings/show.html.erb`

| source file                       | label i18n key                                                         | helper/path                                 | method | status                      |
| --------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------- | ------ | --------------------------- |
| `sign/com/settings/show.html.erb` | `controller.sign.app.setting.index.passkey` (app namespace!)           | `sign_com_settings_passkeys_path`           | GET    | VERIFIED (i18n naming debt) |
| same                              | `controller.sign.app.setting.index.secret_credential` (app namespace!) | `sign_com_settings_secret_credentials_path` | GET    | VERIFIED                    |
| same                              | `sign.app.settings.show.mfa` (app namespace!)                          | `sign_com_settings_mfa_challenge_path(ri:)` | GET    | VERIFIED                    |
| same                              | `controller.sign.app.setting.index.email` (app namespace!)             | `sign_com_settings_emails_path`             | GET    | VERIFIED                    |
| same                              | `controller.sign.app.setting.index.telephone` (app namespace!)         | `sign_com_settings_telephones_path(ri:)`    | GET    | VERIFIED                    |
| same                              | `controller.sign.app.setting.index.birthdate` (app namespace!)         | `sign_com_settings_birthdate_path(ri:)`     | GET    | VERIFIED                    |
| same                              | `controller.sign.app.setting.index.session` (app namespace!)           | `sign_com_settings_sessions_path`           | GET    | VERIFIED                    |
| same                              | `controller.sign.app.setting.index.activity` (app namespace!)          | `sign_com_settings_activities_path`         | GET    | VERIFIED                    |
| same                              | `sign.app.settings.show.logout` (app namespace!)                       | `new_sign_com_sign_out_path(ri:)`           | GET    | VERIFIED                    |
| same                              | `sign.app.settings.show.withdrawal` (app namespace!)                   | `new_sign_com_settings_withdrawal_path`     | GET    | VERIFIED                    |

**注:** com の settings root は page_title・section heading・ほぼ全ラベルで `sign.app.*`
i18n キーを流用している。動作上の問題はないが、命名負債。

### Sign::Org: `app/views/sign/org/settings/show.html.erb`

| source file                       | label i18n key                                                         | helper/path                                          | method | status   |
| --------------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------- | ------ | -------- |
| `sign/org/settings/show.html.erb` | `controller.sign.app.setting.index.passkey` (app namespace!)           | `sign_org_settings_passkeys_path`                    | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.secret_credential` (app namespace!) | `sign_org_settings_secret_credentials_path`          | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.email` (app namespace!)             | `sign_org_settings_emails_path`                      | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.telephone` (app namespace!)         | `sign_org_settings_telephones_path(ri:)`             | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.birthdate` (app namespace!)         | `sign_org_settings_birthdate_path(ri:)`              | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.session` (app namespace!)           | `sign_org_settings_sessions_path`                    | GET    | VERIFIED |
| same                              | `controller.sign.app.setting.index.activity` (app namespace!)          | `sign_org_settings_activities_path`                  | GET    | VERIFIED |
| same                              | `sign.app.settings.show.logout` (app namespace!)                       | `new_sign_org_sign_out_path(ri:)`                    | GET    | VERIFIED |
| same                              | `sign.org.settings.show.withdrawal`                                    | `sign_org_settings_withdrawal_path`                  | GET    | VERIFIED |
| same                              | `sign.org.settings.show.operator_lifecycle_requests`                   | `sign_org_settings_operator_lifecycle_requests_path` | GET    | VERIFIED |

---

## 8. Confirmed Breakages

| severity | confidence | surface     | feature                           | file:line                                                                                                                                                   | finding                                                                                                                                                                                                                                               | evidence                                                                     | user impact                                                                              |
| -------- | ---------- | ----------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| P0       | HIGH       | org         | removals (compatibility redirect) | `app/controllers/sign/org/settings/removals_controller.rb:14`                                                                                               | `before_action :authenticate_client!` が org サーフェスコントローラで呼ばれている。org サーフェスは `authenticate_operator!` が正しい。`Client` セッションで org の `/settings/passkeys/:id/removal` に POST した場合、認証が通ってしまう可能性がある | STATICALLY_CONSISTENT (全 20 件の org settings コントローラの中で唯一の逸脱) | org 利用者の passkey removal 互換リダイレクトが間違った認証コンテキストで動作する        |
| P2       | HIGH       | app/com/org | sessions (revoke)                 | `app/controllers/sign/app/settings/sessions_controller.rb:29`, `sign/com/settings/sessions_controller.rb:24`, `sign/org/settings/sessions_controller.rb:24` | `token.revoke!` を Sign コントローラ内で直接呼んでいる。ADR `acme-sign-core-base-port-boundary` によりセッション変異は Acme 権威                                                                                                                      | STATICALLY_CONSISTENT + バックログ Stage 2 未対処確認                        | ADR 境界違反、ただし現状はユーザーへの機能的影響なし                                     |
| P2       | HIGH       | app/com/org | flash messages                    | (下記参照)                                                                                                                                                  | `flash.now[:alert]` および `redirect_to(..., notice:/alert:)` が settings コントローラ全体で使用されている                                                                                                                                            | STATICALLY_CONSISTENT                                                        | no-flash-messages アーキテクチャルールに違反、フィードバック表示の一貫性が損なわれている |
| P2       | MEDIUM     | com         | telephone index                   | `app/controllers/sign/com/settings/telephones_controller.rb` (index action)                                                                                 | `declare_authentication_mode! :open` かつ `authenticate_visitor!` なしで `current_visitor.visitor_telephones` を呼んでいる。`current_visitor` が nil の場合 `NoMethodError` が発生する可能性                                                          | STATICALLY_CONSISTENT                                                        | 未認証リクエストがテレフォン一覧ページで 500 エラーになる可能性                          |
| P2       | MEDIUM     | app         | telephone edit                    | `app/controllers/sign/app/settings/telephones_controller.rb` (edit action)                                                                                  | `AUTHENTICATION_MODE = :private` が宣言されているが `authenticate_client!` の `before_action` が `:edit` を対象としていない                                                                                                                           | STATICALLY_CONSISTENT                                                        | `edit` アクションへの未認証アクセスが基底クラスのモード enforcement に依存している       |
| P3       | HIGH       | org         | passkey destroy                   | `app/controllers/sign/org/settings/passkeys_controller.rb:257`                                                                                              | `set_passkey` が `current_operator.staff_passkeys.find(params[:id])` を使用しており、DB 整数 PK を URL に晒している。app/com は `find_by!(public_id: ...)` を使用                                                                                     | STATICALLY_CONSISTENT                                                        | 列挙可能な PK による passkey ごとのアドレス可能性（IDOR なし、パターン不整合）           |

**flash violation 対象ファイル（全 12 ファイル）:**

| file                                                                                 | violations                                                                                                  |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `app/controllers/sign/app/settings/emails_controller.rb:32,44`                       | `flash.now[:alert]` (×2)                                                                                    |
| `app/controllers/sign/app/settings/secret_credentials_controller.rb:67`              | `flash[:notice]`                                                                                            |
| `app/controllers/sign/app/settings/passkeys_controller.rb:223`                       | `flash.now[:alert]`                                                                                         |
| `app/controllers/sign/app/settings/telephones/registrations_controller.rb:59,99,151` | `flash.now[:alert]` (×2), `flash[:alert]`                                                                   |
| `app/controllers/sign/app/settings/mfa/challenges_controller.rb:45`                  | `flash.now[:alert]`                                                                                         |
| `app/controllers/sign/app/settings/secrets_controller.rb:34`                         | `flash.now[:alert]`                                                                                         |
| `app/controllers/sign/com/settings/emails_controller.rb:35,44`                       | `flash.now[:alert]` (×2); `redirect_to(..., notice:)` (line 40,74); `redirect_to(..., alert:)` (line 56,64) |
| `app/controllers/sign/com/settings/emails/registrations_controller.rb:75,102,207`    | `flash[:notice]`, `flash[:alert]`, `flash[:notice]`                                                         |
| `app/controllers/sign/com/settings/mfa/challenges_controller.rb`                     | `redirect_to(..., notice:)`, `flash.now[:alert]`                                                            |
| `app/controllers/sign/com/settings/passkeys_controller.rb:135,160,176`               | `redirect_to(..., alert:)` (×3)                                                                             |
| `app/controllers/sign/com/settings/secret_credentials_controller.rb:63,101,116,173`  | `flash[:notice]`, `redirect_to(..., alert:)` (×3)                                                           |
| `app/controllers/sign/com/settings/telephones_controller.rb:58,68`                   | `redirect_to(..., alert:)`, `redirect_to(..., notice:)`                                                     |
| `app/controllers/sign/com/settings/telephones/registrations_controller.rb`           | 複数の `redirect_to(..., notice:/alert:)` (7 箇所以上)                                                      |
| `app/controllers/sign/org/settings/secret_credentials_controller.rb`                 | `flash[:notice]` (create 後)                                                                                |
| `app/controllers/sign/org/settings/operator_lifecycle_requests_controller.rb`        | `flash.now[:alert]`                                                                                         |
| `app/controllers/sign/org/settings/mfa/challenges_controller.rb`                     | `flash.now[:alert]`                                                                                         |
| `app/controllers/sign/org/settings/emails_controller.rb`                             | `flash.now[:alert]` (×2)                                                                                    |
| `app/controllers/sign/org/settings/emails/registrations_controller.rb`               | `flash.now[:alert]`                                                                                         |
| `app/controllers/sign/org/settings/telephones/registrations_controller.rb`           | `flash.now[:alert]` (×2)                                                                                    |

---

## 9. Security Boundary Risks

| severity | confidence | surface     | feature                                 | endpoint/file                                                                        | risk                                                                                                                                                                                                                       | evidence                               | required verification                                                                                                                    |
| -------- | ---------- | ----------- | --------------------------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| P0       | HIGH       | org         | passkey removal redirect                | `app/controllers/sign/org/settings/removals_controller.rb:14`                        | `authenticate_client!` が org コントローラで呼ばれている。org に `Client` セッションで到達した場合、認証が通り org サーフェスのリダイレクト処理が実行される可能性がある                                                    | STATICALLY_CONSISTENT                  | `authenticate_client!` が org サーフェスで完全に失敗するかどうか（セッション構造が別物かどうか）を統合テストで確認                       |
| P2       | HIGH       | app/com/org | session revocation authority            | `sign/*/settings/sessions_controller.rb:destroy`, `revocations_controller.rb:create` | `token.revoke!` を Sign コントローラが直接呼んでいる。ADR でセッション権威は Acme とされているため、Sign がセッションを変異させることは境界逸脱                                                                            | STATICALLY_CONSISTENT + バックログ確認 | ADR `acme-sign-core-base-port-boundary` と `acme-session-and-token-authority.md` を照合して Sign が session 変異を行って良いケースを特定 |
| P2       | MEDIUM     | app         | email registration post-verify redirect | `app/controllers/sign/app/settings/emails/registrations_controller.rb:65`            | メール認証完了後に `https://#{oidc_acme_host}/preference?ri=...` へクロスホストリダイレクト。`ri` パラメータがそのまま Acme に転送される                                                                                   | STATICALLY_CONSISTENT                  | `ri` パラメータのサニタイズ・オープンリダイレクト可能性の確認。`oidc_acme_host` が信頼できる値のみを返すかどうかの確認                   |
| P3       | HIGH       | org         | passkey destroy                         | `app/controllers/sign/org/settings/passkeys_controller.rb:257`                       | `find(params[:id])` は DB 整数 PK を使用。IDOR はない（`current_operator.staff_passkeys` でスコープ済み）が、URL から PK が推測可能で passkey の存在確認ができる                                                           | STATICALLY_CONSISTENT                  | 低リスクだが公開 ID パターンに揃えるべき                                                                                                 |
| P3       | MEDIUM     | com         | telephone registration ownership        | `app/controllers/sign/com/settings/telephones/registrations_controller.rb:158,219`   | `VisitorTelephone.find_by(id: session[...])` は visitor 関連でスコープされておらず、session キーが改ざんされた場合に別 visitor の電話番号レコードを取得できる（ただし `valid_registration_session?` で所有権チェックあり） | STATICALLY_CONSISTENT                  | セカンダリチェック (`visitor_id == current_visitor.id`) が確実に実行されるかを確認                                                       |

---

## 10. Migration Debt

| severity | confidence | file:line                                                        | old Acme element                                                  | current Sign usage                                                                                         | classification     | recommended action                                                                                                          |
| -------- | ---------- | ---------------------------------------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| P3       | HIGH       | `app/controllers/sign/app/settings/activities_controller.rb:34`  | `AcmeAppSettingsActivityLog`                                      | Sign/app の設定画面でアクティビティログを表示するために使用                                                | naming_debt        | `Sign::App::Settings::ActivityLog` に改名                                                                                   |
| P3       | HIGH       | `app/controllers/sign/com/settings/activities_controller.rb`     | `AcmeComSettingsActivityLog`                                      | Sign/com の設定画面で使用                                                                                  | naming_debt        | `Sign::Com::Settings::ActivityLog` に改名                                                                                   |
| P3       | HIGH       | `app/controllers/sign/org/settings/activities_controller.rb`     | `AcmeOrgSettingsActivityLog`                                      | Sign/org の設定画面で使用                                                                                  | naming_debt        | `Sign::Org::Settings::ActivityLog` に改名                                                                                   |
| P2       | HIGH       | `app/controllers/sign/app/settings/withdrawals_controller.rb:10` | `AcmeSettingsWithdrawalFlow` (concern)                            | app 設定の退会フローロジック全体を提供                                                                     | authority_boundary | 退会処理の権威が Acme なのか Sign なのかを ADR で明確化し、concern を適切な名前空間に移動                                   |
| P2       | HIGH       | `app/controllers/sign/com/settings/withdrawals_controller.rb`    | `AcmeSettingsWithdrawalFlow` (concern)                            | com 設定の退会フローロジック                                                                               | authority_boundary | 同上                                                                                                                        |
| P2       | HIGH       | `app/controllers/sign/app/settings/telephones_controller.rb`     | `SignSettingsAuthorityRedirect` (include)                         | 全アクションをオーバーライドしており concern のメソッドは一切呼ばれない                                    | orphaned_code      | include を削除                                                                                                              |
| P2       | HIGH       | `app/controllers/sign/com/settings/telephones_controller.rb`     | `SignSettingsAuthorityRedirect` (include)                         | 同上                                                                                                       | orphaned_code      | include を削除                                                                                                              |
| P2       | HIGH       | `app/controllers/sign/org/settings/telephones_controller.rb`     | `SignSettingsAuthorityRedirect` (include)                         | 同上                                                                                                       | orphaned_code      | include を削除                                                                                                              |
| P2       | HIGH       | `app/controllers/sign/*/settings/sessions_controller.rb`         | `destroy`, `others`, `revoke_all` actions                         | ルートが `Revocations::*Controller` に向いているため、SessionsController のこれら 3 アクションは到達不可能 | orphaned_code      | dead action を削除（app は `destroy` のみルート存在、com/org の `others`/`revoke_all` は未ルート）                          |
| P3       | MEDIUM     | `app/services/acme_com_settings_activity_log.rb`                 | `sign.app.settings.activity.events.*`                             | com サービスが app の i18n キーを参照                                                                      | naming_debt        | `sign.com.settings.activity.events.*` キーを作成するか共通キーとして明示的に共有                                            |
| P3       | HIGH       | `app/views/sign/com/settings/show.html.erb`                      | `sign.app.settings.show.*`, `controller.sign.app.setting.index.*` | com 設定 root ビューが app namespace の i18n キーを多用                                                    | naming_debt        | com 用 i18n キーを作成するか共通化を明示                                                                                    |
| P3       | HIGH       | `app/views/sign/org/settings/show.html.erb`                      | `sign.app.settings.show.*`, `controller.sign.app.setting.index.*` | org 設定 root ビューが app namespace の i18n キーを多用                                                    | naming_debt        | 同上                                                                                                                        |
| P3       | MEDIUM     | `app/controllers/sign/org/settings/mfa/challenges_controller.rb` | `sign.app.settings.mfa.update.*`                                  | org コントローラで app namespace の翻訳キーを参照                                                          | naming_debt        | org 用翻訳キーを作成                                                                                                        |
| P3       | LOW        | `app/controllers/sign/com/settings/activities_controller.rb`     | `Sign::Com::FullAccessController` を継承                          | com activities のみが FullAccessController を継承（他コントローラは ApplicationController を直接継承）     | naming_debt        | 一貫性のために全 settings コントローラが ApplicationController を継承するよう整理、または FullAccessController の利用を拡大 |

---

## 11. Acme/Sign Duplication

| surface     | feature                               | Acme implementation                                        | Sign implementation                                                                                                                                                       | routes reachable | data/service shared                                          | classification           | severity |
| ----------- | ------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------ | ------------------------ | -------- |
| app/com/org | email settings (index/update/destroy) | なし（Acme には email settings コントローラが存在しない）  | `Sign::*/Settings::EmailsController` — 直接 `*Email` モデルを変異                                                                                                         | yes (Sign)       | `ClientEmail`/`VisitorEmail`/`OperatorEmail` モデル共有      | authority_boundary       | P2       |
| app/com/org | email registration ceremony           | なし                                                       | `Sign::*/Settings::Emails::RegistrationsController` — OTP 発行・検証・email 作成                                                                                          | yes (Sign)       | OTP ceremony は Sign 権威内だが email record 作成は境界      | intentional_design       | P3       |
| app/com/org | telephone settings (create/destroy)   | なし                                                       | `Sign::*/Settings::TelephonesController`                                                                                                                                  | yes (Sign)       | `*Telephone` モデル                                          | authority_boundary       | P2       |
| app/com     | withdrawal (full CRUD)                | Acme に `AcmeSettingsWithdrawalFlow` concern が存在        | `Sign::App/Com::Settings::WithdrawalsController` が同 concern を include                                                                                                  | yes (Sign)       | `AcmeSettingsWithdrawalFlow` concern                         | authority_boundary       | P2       |
| app/com/org | session revocation                    | Acme が session 権威                                       | `Sign::*/Settings::Revocations::*Controller` が `token.revoke!` を直接実行                                                                                                | yes (Sign)       | `*Token` モデルを直接操作                                    | authority_boundary       | P2       |
| app/com/org | activity log display                  | `AcmeApp/Com/OrgSettingsActivityLog` サービス (Acme named) | `Sign::*/Settings::ActivitiesController` が当該サービスを使用                                                                                                             | yes (Sign)       | `ClientChronicle`/`OperatorChronicle` テーブルの読み取り共有 | naming_debt              | P3       |
| com         | telephone verification logic          | なし                                                       | `Sign::Com::Settings::TelephonesController` と `Sign::Com::Settings::Telephones::RegistrationsController` の両方に `initiate_visitor_telephone_verification` 等が重複実装 | yes              | ロジック重複（DRY 違反）                                     | duplicate_implementation | P3       |

---

## 12. Backlog Remediation Status

計画書: `plans/backlog/sign-acme-boundary-remediation.md`

| backlog item                                                                            | current evidence                                                                                            | status             | related files                                                                 | remaining work                                                                                 | severity |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------ | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | -------- |
| §1 — タスク前提の修正（Sign はセッション/認証権威ではない）                             | 計画書が前提修正を文書化済み。現コードも OIDC/OAuth/selector エンドポイントを Sign に持たないことを確認     | resolved           | `config/routes/sign.rb`                                                       | なし                                                                                           | —        |
| §2 — Sign 側の残存権威エンドポイント — `dashboard` (app/com/org)                        | `Sign::App::DashboardsController` 等が実際のビューをレンダリング（redirect shell でない）                   | unresolved         | `app/controllers/sign/*/dashboards_controller.rb`                             | dashboard が redirect shell か実 UI かの決定                                                   | P2       |
| §2 — Sign/org top-level (configuration, accounts, iam, system, audit, support, billing) | 全 7 件が `Sign::RedirectOnlyController` サブクラスで `redirect_to_acme_authority!` を即時呼び出し          | resolved           | `app/controllers/sign/org/` 直下の 7 ファイル                                 | なし（`# FIXME: I want to delete this file.` コメントが `redirect_only_controller.rb` に残存） | P3       |
| §2 — `settings/sessions` + revocation                                                   | `Sign::*/Settings::Sessions/Revocations::*Controller` が `token.revoke!` を直接呼んでいる。ADR 違反の可能性 | unresolved         | 上記参照                                                                      | ADR 照合・Acme delegation への移行判断                                                         | P2       |
| §2 — `settings/activities`                                                              | Sign コントローラが `Chronicle` テーブルを直接読み取っている                                                | unresolved         | `app/controllers/sign/*/settings/activities_controller.rb`                    | Acme への read-proxy 化の要否を判断                                                            | P3       |
| §2 — `settings/withdrawal`                                                              | app/com は `AcmeSettingsWithdrawalFlow` を include した本格コントローラ。org は show のみ（適切）           | partially_resolved | `app/controllers/sign/app/com/settings/withdrawals_controller.rb`             | app/com の退会処理権威の確認                                                                   | P2       |
| §2 — `settings/emails` index/update/destroy                                             | Sign が直接 email レコードを変異                                                                            | unresolved         | `app/controllers/sign/*/settings/emails_controller.rb`                        | Acme preference エンドポイントへの redirect shell 化の要否                                     | P2       |
| §2 — `settings/telephones` create/destroy                                               | Sign が直接 telephone レコードを変異                                                                        | unresolved         | `app/controllers/sign/*/settings/telephones_controller.rb`                    | 同上                                                                                           | P2       |
| §2 — social connections (com/org)                                                       | com/org に social connection ルートは存在しない                                                             | resolved           | `config/routes/sign.rb`                                                       | なし                                                                                           | —        |
| §2 — org `operator_lifecycle_requests`                                                  | `Sign::Org::Settings::OperatorLifecycleRequestsController` が全 CRUD を実装（redirect shell でない）        | unresolved         | `app/controllers/sign/org/settings/operator_lifecycle_requests_controller.rb` | org lifecycle が Sign 権威内か Acme 権威かの判断                                               | P2       |
| §3 — Acme 側エンドポイントの保全                                                        | Acme は OIDC/OAuth/selector/sessions/withdrawal/dashboard/welcome/preference を保有。削除なし               | resolved           | `config/routes/acme.rb`                                                       | なし                                                                                           | —        |
| §4a — welcome ルート重複解消                                                            | 各サーフェスに `resource :welcome, only: :show, as: :welcome_entry` が 1 件のみ存在                         | resolved           | `config/routes/acme.rb`                                                       | なし                                                                                           | —        |
| §4b — preference ルーティング簡略化                                                     | named preference screen helpers が全て存在                                                                  | resolved           | `config/routes/acme.rb`                                                       | なし                                                                                           | —        |
| §4c — クロスサーフェス jump ラウンドトリップカバレッジ                                  | JumpRT 実装は存在するが統合テストの網羅性は未検証                                                           | unable_to_verify   | `test/integration/`                                                           | 統合テストで Acme→Sign→Acme round-trip を確認                                                  | P2       |
| §5.1 — `sign/in/session` のセッション制限処理                                           | `promote_to_active!` / `AuthenticationSelectedSessionRevoker.call` が mid-ceremony フロー内で実行           | partially_resolved | `app/controllers/sign/*/sign/in/sessions_controller.rb`                       | ADR `acme-session-and-token-authority.md` との照合                                             | P2       |
| §5.2 — `settings/mfa/reset`                                                             | `create` が現在無効化されリダイレクト返却のみ                                                               | unable_to_verify   | `app/controllers/sign/app/settings/mfa/resets_controller.rb`                  | `adr/mfa-reset-account-recovery.md` との照合                                                   | P2       |
| §5.4 — org `operator_lifecycle_requests`                                                | 上記 §2 と同じ                                                                                              | unresolved         | 上記参照                                                                      | 上記参照                                                                                       | P2       |
| §5.5 — Base/Port ターゲット曖昧性                                                       | Base/Port の controller 分割は未着手。全コントローラが既存の `ApplicationController` 継承                   | unresolved         | 全 Sign settings コントローラ                                                 | Base/Port 導入計画の具体化                                                                     | P3       |

---

## 13. Authentication and Authorization Matrix

| endpoint/feature                            | unauthenticated                             | authenticated_owner     | authenticated_non_owner     | wrong_surface_actor    | reauthentication (step_up) | existing test |
| ------------------------------------------- | ------------------------------------------- | ----------------------- | --------------------------- | ---------------------- | -------------------------- | ------------- |
| settings root (app/com/org)                 | 認証リダイレクト                            | 200 view                | N/A                         | 認証失敗（ホスト制約） | なし                       | VERIFIED      |
| passkeys index (app/com/org)                | 認証リダイレクト                            | 200 view                | N/A                         | ホスト制約で到達不可   | なし                       | partial       |
| passkey destroy (app/com/org)               | 認証リダイレクト                            | 302 redirect            | 404 (owner-scoped find_by!) | ホスト制約で到達不可   | なし                       | partial       |
| passkey new/create (app/com/org)            | 認証リダイレクト                            | step_up 要求            | N/A                         | ホスト制約で到達不可   | `step_up` (before_action)  | partial       |
| TOTP destroy (app only)                     | 認証リダイレクト                            | 302 redirect            | 404                         | N/A                    | なし                       | partial       |
| email update/destroy (app/com/org)          | 認証リダイレクト                            | success/204             | 404 (owner-scoped)          | ホスト制約で到達不可   | なし                       | partial       |
| email registration new/create (app/com/org) | 認証リダイレクト                            | step_up 要求            | N/A                         | ホスト制約で到達不可   | `step_up` (before_action)  | partial       |
| telephone index (app/com)                   | **200 view (open mode)**                    | 200 view                | N/A                         | ホスト制約で到達不可   | なし                       | partial       |
| telephone edit (app)                        | **基底クラス依存（gap）**                   | 200 view                | N/A                         | ホスト制約で到達不可   | なし                       | unknown       |
| telephone destroy (app/com/org)             | 認証リダイレクト                            | 302 redirect            | 404 (owner-scoped)          | ホスト制約で到達不可   | なし                       | partial       |
| session revocation create (app/com/org)     | 認証リダイレクト                            | 302 redirect            | 404 (owner-scoped)          | ホスト制約で到達不可   | なし                       | VERIFIED      |
| session revoke-all create (app/com/org)     | 認証リダイレクト                            | 302 sign_out            | N/A                         | ホスト制約で到達不可   | なし                       | partial       |
| secret credential destroy (app/com/org)     | 認証リダイレクト                            | last-method guard → 302 | 404 (owner-scoped)          | ホスト制約で到達不可   | なし                       | VERIFIED      |
| secret credential new/create (app/com/org)  | 認証リダイレクト                            | step_up 要求            | N/A                         | ホスト制約で到達不可   | `step_up` (before_action)  | partial       |
| org removals create                         | **authenticate_client! (P0: wrong method)** | P0 境界違反             | N/A                         | 不明                   | なし                       | unknown       |
| withdrawal new/create (app/com)             | 認証リダイレクト                            | authorize! 実行         | N/A                         | ホスト制約で到達不可   | なし                       | VERIFIED      |
| withdrawal show (org)                       | 認証リダイレクト                            | authorize! 実行         | N/A                         | ホスト制約で到達不可   | なし                       | VERIFIED      |
| operator lifecycle request create (org)     | 認証リダイレクト                            | `require_step_up!`      | policy gate                 | ホスト制約で到達不可   | `require_step_up!`         | VERIFIED      |
| activities index (app/com/org)              | 認証リダイレクト                            | 200 view                | N/A                         | ホスト制約で到達不可   | なし                       | VERIFIED      |
| birthdate show (app/com/org)                | 認証リダイレクト                            | step_up + authorize!    | N/A                         | ホスト制約で到達不可   | `step_up`                  | VERIFIED      |

---

## 14. Existing Test Inventory

| test file                                                                    | surface | feature            | runs    | assertions | success test | failure test | auth test | ownership test | host test | persistence test | execution result  |
| ---------------------------------------------------------------------------- | ------- | ------------------ | ------- | ---------- | ------------ | ------------ | --------- | -------------- | --------- | ---------------- | ----------------- |
| `test/controllers/sign/app/settings/activities_controller_test.rb`           | app     | activity log       | unknown | unknown    | yes          | unknown      | yes       | unknown        | unknown   | N/A              | passed (suite)    |
| `test/controllers/sign/app/settings/birthdates_controller_test.rb`           | app     | birthdate          | unknown | unknown    | yes          | unknown      | yes       | N/A            | unknown   | N/A              | passed            |
| `test/controllers/sign/app/settings/emails_controller_test.rb`               | app     | email settings     | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed            |
| `test/controllers/sign/app/settings/emails/registrations_controller_test.rb` | app     | email registration | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed            |
| `test/controllers/sign/app/settings/passkeys_controller_test.rb`             | app     | passkeys           | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed            |
| `test/controllers/sign/app/settings/secret_credentials_controller_test.rb`   | app     | secret credentials | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed (modified) |
| `test/controllers/sign/app/settings/sessions_controller_test.rb`             | app     | sessions           | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed (modified) |
| `test/controllers/sign/com/settings/passkeys_controller_test.rb`             | com     | passkeys           | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed            |
| `test/controllers/sign/com/settings/secret_credentials_controller_test.rb`   | com     | secret credentials | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed (modified) |
| `test/controllers/sign/com/settings/sessions_controller_test.rb`             | com     | sessions           | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed (modified) |
| `test/controllers/sign/org/settings/passkeys_controller_test.rb`             | org     | passkeys           | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed            |
| `test/controllers/sign/org/settings/secret_credentials_controller_test.rb`   | org     | secret credentials | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed (modified) |
| `test/controllers/sign/org/settings/sessions_controller_test.rb`             | org     | sessions           | unknown | unknown    | yes          | partial      | yes       | partial        | unknown   | partial          | passed (modified) |
| `test/controllers/sign/app/settings_controller_test.rb`                      | app     | settings root      | 2       | 4          | yes          | unknown      | yes       | N/A            | unknown   | N/A              | 0 failures        |
| `test/controllers/sign/com/settings_controller_test.rb`                      | com     | settings root      | 2       | 4          | yes          | unknown      | yes       | N/A            | unknown   | N/A              | 0 failures        |
| `test/controllers/sign/org/settings_controller_test.rb`                      | org     | settings root      | 2       | 4          | yes          | unknown      | yes       | N/A            | unknown   | N/A              | 0 failures        |
| `test/integration/routes/sign_route_contract_test.rb`                        | all     | route contracts    | 7       | 336        | yes          | N/A          | N/A       | N/A            | yes       | N/A              | 0 failures        |

**実行確認合計:** app settings: 152 runs / 658 assertions、com settings: 61 runs / 269
assertions、org settings: 77 runs / 292 assertions、route contract: 7 runs / 336 assertions — 全て 0
failures / 0 errors / 0 skips

---

## 15. Test Failures

**実行済みテストでの失敗は 0 件。**

No failures detected in executed tests.

実行したスイート:

- `RAILS_ENV=test bin/rails test test/controllers/sign/app/settings` → exit 0
- `RAILS_ENV=test bin/rails test test/controllers/sign/app/settings_controller_test.rb` → exit 0
- `RAILS_ENV=test bin/rails test test/controllers/sign/com/settings` → exit 0
- `RAILS_ENV=test bin/rails test test/controllers/sign/com/settings_controller_test.rb` → exit 0
- `RAILS_ENV=test bin/rails test test/controllers/sign/org/settings` → exit 0
- `RAILS_ENV=test bin/rails test test/controllers/sign/org/settings_controller_test.rb` → exit 0
- `RAILS_ENV=test bin/rails test test/integration/routes/sign_route_contract_test.rb` → exit 0

非致命的な警告: `unknown OID 2278: failed to recognize type of 'pg_advisory_xact_lock'` — pg
gem の PostgreSQL advisory lock OID 警告。テスト結果に影響なし。

---

## 16. Missing Verification

| priority | surface     | feature                                           | missing verification                                                                                         | current evidence | risk                               |
| -------- | ----------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------------- | ---------------------------------- |
| P0       | org         | removals (P0 bug)                                 | `authenticate_client!` で org サーフェスへの到達が実際に阻止されるかどうかの動作確認                         | 静的解析のみ     | org 認証コンテキストでの不正通過   |
| P1       | app/com     | telephone edit/index authentication mode          | `declare_authentication_mode! :private` の enforcement が基底クラスで実際に `authenticate_*!` を呼ぶかどうか | 静的解析のみ     | 未認証アクセスの通過               |
| P2       | com         | telephone index with nil current_visitor          | `current_visitor` が nil の場合に `NoMethodError` が発生するかどうか                                         | 静的解析のみ     | 500 エラーの可能性                 |
| P2       | app         | email registration cross-host redirect `ri` param | `ri` パラメータが Acme に転送される際のサニタイズ検証                                                        | 静的解析のみ     | オープンリダイレクトの可能性（低） |
| P2       | app/com/org | session revocation ADR compliance                 | `token.revoke!` が Sign で直接呼ばれることが ADR 的に許容されるかどうか                                      | バックログ未解決 | 設計方針逸脱                       |
| P2       | org         | passkey destroy integer PK enumeration            | `find(params[:id])` で他 operator の passkey の存在が確認できるかどうか                                      | 静的解析のみ     | 列挙可能だが IDOR なし             |
| P2       | all         | Acme→Sign→Acme round-trip                         | JumpRT の統合テストが実際に正常動作しているかどうか                                                          | テスト未実装     | クロスサーフェスフローの回帰リスク |
| P2       | app         | MFA reset (create action)                         | 現在 create が無効化されているが、再有効化時の動作                                                           | コード確認のみ   | 機能未完成                         |
| P3       | com         | telephone registration unscoped `find_by`         | `valid_registration_session?` が必ず実行されるかどうかのテスト                                               | 静的解析のみ     | 低リスクだが所有権二次確認の堅牢性 |
| P3       | all         | flash message architectural compliance            | flash が実際にフロントエンドで表示されているかどうか                                                         | コード確認のみ   | UX 不整合                          |

---

## 17. Proposed Tests

### 1. [P0] org removals controller — 認証メソッド確認

| 項目                  | 内容                                                                       |
| --------------------- | -------------------------------------------------------------------------- |
| priority              | P0                                                                         |
| surface               | org                                                                        |
| feature               | removals compatibility redirect                                            |
| proposed file         | `test/controllers/sign/org/settings/removals_controller_test.rb`           |
| proposed test         | `test "POST create without operator session returns unauthorized"`         |
| setup                 | fixtures: operator fixture, client fixture（別物）; host: `id.umaxica.org` |
| actor type            | Operator                                                                   |
| authentication helper | `sign_in_as_client` (client のみ)                                          |
| HTTP method           | POST                                                                       |
| route helper          | `sign_org_settings_passkey_removal_path(passkey_id: "some-id")`            |
| expected status       | 401 または 302 (to org sign-in)                                            |
| expected redirect     | sign_org sign-in path                                                      |
| model state assertion | なし（redirect のみ）                                                      |

### 2. [P2] com telephone index — nil current_visitor クラッシュ確認

| 項目                  | 内容                                                               |
| --------------------- | ------------------------------------------------------------------ |
| priority              | P2                                                                 |
| surface               | com                                                                |
| feature               | telephone index (open mode)                                        |
| proposed file         | `test/controllers/sign/com/settings/telephones_controller_test.rb` |
| proposed test         | `test "GET index without session does not raise NoMethodError"`    |
| setup                 | host: `id.umaxica.com`; 未認証リクエスト                           |
| actor type            | なし（unauthenticated）                                            |
| authentication helper | なし                                                               |
| HTTP method           | GET                                                                |
| route helper          | `sign_com_settings_telephones_path`                                |
| expected status       | 200 または 302 (open mode なら 200)                                |
| model state assertion | `response.body` に NoMethodError のスタックトレースがないこと      |

### 3. [P2] app telephone edit — 未認証アクセスのブロック確認

| 項目                  | 内容                                                               |
| --------------------- | ------------------------------------------------------------------ |
| priority              | P2                                                                 |
| surface               | app                                                                |
| feature               | telephone edit (:private mode declared)                            |
| proposed file         | `test/controllers/sign/app/settings/telephones_controller_test.rb` |
| proposed test         | `test "GET edit without session is blocked"`                       |
| setup                 | host: `id.umaxica.app`; 未認証リクエスト; client fixture           |
| actor type            | なし（unauthenticated）                                            |
| authentication helper | なし                                                               |
| HTTP method           | GET                                                                |
| route helper          | `edit_sign_app_settings_telephone_path(id: telephone.public_id)`   |
| expected status       | 302 (to sign-in)                                                   |
| expected redirect     | `sign_app_sign_in_path` 相当                                       |
| model state assertion | なし                                                               |

### 4. [P2] app/com/org — session revocation ownership (non-owner)

| 項目                  | 内容                                                                                |
| --------------------- | ----------------------------------------------------------------------------------- |
| priority              | P2                                                                                  |
| surface               | app (rep)                                                                           |
| feature               | session revocation ownership                                                        |
| proposed file         | `test/controllers/sign/app/settings/revocations_controller_test.rb`                 |
| proposed test         | `test "POST create with another client's session_id returns 404"`                   |
| setup                 | fixtures: 2 client fixtures + それぞれの session tokens; host: `id.umaxica.app`     |
| actor type            | Client                                                                              |
| authentication helper | `sign_in_as_client(client_a)`                                                       |
| HTTP method           | POST                                                                                |
| route helper          | `sign_app_settings_session_revocation_path(session_id: client_b_session.public_id)` |
| expected status       | 404                                                                                 |
| expected redirect     | なし                                                                                |
| model state assertion | `client_b_session.reload.revoked_at` が nil のままであること                        |

### 5. [P2] org passkey destroy — integer PK vs public_id ownership

| 項目                  | 内容                                                                           |
| --------------------- | ------------------------------------------------------------------------------ |
| priority              | P2                                                                             |
| surface               | org                                                                            |
| feature               | passkey destroy                                                                |
| proposed file         | `test/controllers/sign/org/settings/passkeys_controller_test.rb`               |
| proposed test         | `test "DELETE destroy with another operator's passkey integer PK returns 404"` |
| setup                 | fixtures: 2 operator fixtures + それぞれの passkey; host: `id.umaxica.org`     |
| actor type            | Operator                                                                       |
| authentication helper | `sign_in_as_operator(operator_a)`                                              |
| HTTP method           | DELETE                                                                         |
| route helper          | `sign_org_settings_passkey_path(id: operator_b_passkey.id)`                    |
| expected status       | 404                                                                            |
| model state assertion | `operator_b_passkey.reload` が存在すること                                     |

### 6. [P2] app secret credential — update vs destroy guard 一致確認

| 項目                  | 内容                                                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| priority              | P2                                                                                                                              |
| surface               | app                                                                                                                             |
| feature               | secret credential disable guard vs destroy guard                                                                                |
| proposed file         | `test/controllers/sign/app/settings/secret_credentials_controller_test.rb`                                                      |
| proposed test         | `test "PATCH update to disable last secret credential is blocked"` と `test "DELETE destroy last secret credential is blocked"` |
| setup                 | client fixture with 1 secret credential and no other AAL1 method; host: `id.umaxica.app`                                        |
| actor type            | Client                                                                                                                          |
| HTTP method           | PATCH / DELETE                                                                                                                  |
| expected status       | どちらも 302 (to same path)                                                                                                     |
| model state assertion | `secret_credential.reload.active?` が変わらないこと                                                                             |

### 7. [P1] org secret credential — recovery identity guard absence

| 項目            | 内容                                                                                                                                         |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| priority        | P1                                                                                                                                           |
| surface         | org                                                                                                                                          |
| feature         | secret credential new (missing `ensure_verified_recovery_identity_for_registration!`)                                                        |
| proposed file   | `test/controllers/sign/org/settings/secret_credentials_controller_test.rb`                                                                   |
| proposed test   | `test "GET new without verified recovery identity is permitted (intentional or gap)"`                                                        |
| setup           | operator fixture with no verified recovery identity; host: `id.umaxica.org`                                                                  |
| actor type      | Operator                                                                                                                                     |
| HTTP method     | GET                                                                                                                                          |
| route helper    | `new_sign_org_settings_secret_credential_path`                                                                                               |
| expected status | 要確認（app/com は 302 でブロック、org で 200 なら gap）                                                                                     |
| note            | app: `ensure_verified_recovery_identity_for_registration!` で new をガード。org: この before_action なし。意図的か否かを明示するテストが必要 |

### 8. [P3] com telephone registration — unscoped find_by ownership secondary check

| 項目                  | 内容                                                                                                                             |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| priority              | P3                                                                                                                               |
| surface               | com                                                                                                                              |
| feature               | telephone registration (session-keyed find_by)                                                                                   |
| proposed file         | `test/controllers/sign/com/settings/telephones/registrations_controller_test.rb`                                                 |
| proposed test         | `test "PATCH update with another visitor's telephone id in session is blocked"`                                                  |
| setup                 | fixtures: 2 visitor fixtures + それぞれの telephone fixture; session に visitor_b の telephone id を注入; host: `id.umaxica.com` |
| actor type            | Visitor                                                                                                                          |
| authentication helper | `sign_in_as_visitor(visitor_a)`                                                                                                  |
| HTTP method           | PATCH                                                                                                                            |
| route helper          | `sign_com_settings_telephones_registration_path`                                                                                 |
| expected status       | 422 または 302 (ownership check 失敗)                                                                                            |
| model state assertion | `visitor_b_telephone.reload` が変更されていないこと                                                                              |

---

## 18. Executed Commands

| command                                                                                                      | exit status | classification | result summary                                     |
| ------------------------------------------------------------------------------------------------------------ | ----------- | -------------- | -------------------------------------------------- |
| `git status --short`                                                                                         | 0           | success        | 32 modified files + 2 untracked                    |
| `ruby --version`                                                                                             | 0           | success        | ruby 4.0.5 (2026-05-20 revision 64336ffd0e) +PRISM |
| `bin/rails --version`                                                                                        | 0           | success        | Rails 8.2.0.alpha                                  |
| `bin/rails zeitwerk:check RAILS_ENV=test`                                                                    | 0           | success        | "all is good" (rails_db vendor warning のみ)       |
| `bin/rails routes` (grep: sign settings)                                                                     | 0           | success        | 全設定ルートを確認                                 |
| `bin/rails routes` (grep: passkey/totp/email/telephone/session/withdraw/revoc/secret/lifecycle/apple/google) | 0           | success        | 各機能の route 確認                                |
| `find app/controllers/sign -name "*.rb" -path "*/settings/*"`                                                | 0           | success        | 全 62 コントローラファイルをリスト                 |
| `find app/views/sign -path "*/settings/*"`                                                                   | 0           | success        | 全 97 ビューファイルをリスト                       |
| `find app/services -name "*activity_log*"`                                                                   | 0           | success        | 3 サービスクラスを確認                             |
| `cat app/controllers/sign/org/settings/removals_controller.rb`                                               | 0           | success        | P0: `authenticate_client!` を確認                  |
| `grep -r "flash" app/controllers/sign/*/settings/`                                                           | 0           | success        | flash 違反を全ファイルで確認                       |
| `grep -r "SignSettingsAuthorityRedirect" app/controllers/sign/*/settings/telephones_controller.rb`           | 0           | success        | 3 サーフェスすべてで dead include を確認           |
| `cat config/initializers/webauthn.rb`                                                                        | 0           | success        | WebAuthn 設定（per-surface RP ID）を確認           |
| `grep -r "AuthMethodGuard" app/controllers/sign/`                                                            | 0           | success        | last-credential 削除ガードを全コントローラで確認   |
| `RAILS_ENV=test bin/rails test test/controllers/sign/app/settings`                                           | 0           | success        | 152 runs / 658 assertions / 0 failures             |
| `RAILS_ENV=test bin/rails test test/controllers/sign/app/settings_controller_test.rb`                        | 0           | success        | 2 runs / 4 assertions / 0 failures                 |
| `RAILS_ENV=test bin/rails test test/controllers/sign/com/settings`                                           | 0           | success        | 61 runs / 269 assertions / 0 failures              |
| `RAILS_ENV=test bin/rails test test/controllers/sign/com/settings_controller_test.rb`                        | 0           | success        | 2 runs / 4 assertions / 0 failures                 |
| `RAILS_ENV=test bin/rails test test/controllers/sign/org/settings`                                           | 0           | success        | 77 runs / 292 assertions / 0 failures              |
| `RAILS_ENV=test bin/rails test test/controllers/sign/org/settings_controller_test.rb`                        | 0           | success        | 2 runs / 4 assertions / 0 failures                 |
| `RAILS_ENV=test bin/rails test test/integration/routes/sign_route_contract_test.rb`                          | 0           | success        | 7 runs / 336 assertions / 0 failures               |

---

## 19. Recommended Implementation Order

### 1位: org settings removals_controller.rb の `authenticate_client!` → `authenticate_operator!` 修正

- **対象ファイル:** `app/controllers/sign/org/settings/removals_controller.rb:14`
- **修正理由:**
  org サーフェスで app サーフェス用の認証メソッドが使用されており、セキュリティ境界を誤っている。
- **先に必要な作業:** `authenticate_client!`
  が org セッション構造でどのように失敗するか確認（完全失敗なら影響範囲が限られるが、partial 通過なら即時修正必須）
- **追加すべきテスト:** org
  removals コントローラへの未認証・client セッション・operator セッションそれぞれでのアクセスを確認する 3 テスト
- **想定リスク:** 変更は 1 行 (`authenticate_client!` →
  `authenticate_operator!`) のみ。後方互換性の影響なし。

### 2位: com/app telephone index/edit の authentication gap 解消

- **対象ファイル:**
  `app/controllers/sign/com/settings/telephones_controller.rb`、`app/controllers/sign/app/settings/telephones_controller.rb`
- **修正理由:** com の index で `current_visitor` が nil の場合に `NoMethodError`
  が発生する可能性。app の edit は `:private` 宣言があるが `authenticate_client!`
  が hookされていない。
- **先に必要な作業:** `AUTHENTICATION_MODE = :private`
  の基底クラス enforcement 機構を確認し、`:private` モードが実際に before*action として
  `authenticate*\*!` を呼ぶかどうかを確認
- **追加すべきテスト:** 未認証リクエストが適切に 302 で弾かれることの確認テスト（各サーフェス ×
  edit/index）
- **想定リスク:** `:open`
  mode の index が現在認証なしで到達可能であり意図的かもしれない。電話番号リストが公開情報として設計されているかどうかを確認してから修正する

### 3位: 全サーフェス settings コントローラの flash message 違反解消

- **対象ファイル:** 上記 §8 flash violation 表に記載の全ファイル（12 ファイル以上）
- **修正理由:** プロジェクトの no-flash-messages ルール違反。`flash.now[:alert]`
  は render 直前に設定されるが、次回リクエストで残存するリスクがある (`flash[:notice]`
  は確実に次リクエストへ引き継がれる)。
- **先に必要な作業:** インライン feedback の UI コンポーネント実装方針を確認（既存の inline error
  rendering パターンを特定してから統一的に置換）
- **追加すべきテスト:** 各コントローラの failure
  path で flash が設定されず、レスポンス body にエラーメッセージが含まれることを確認するテスト
- **想定リスク:**
  UI の変更を伴うため、ビジュアルリグレッションのリスクがある。段階的に修正（1 コントローラ ×
  1 サーフェスずつ）が推奨

### 4位（推奨: バックログ継続）: `SignSettingsAuthorityRedirect` の dead include 削除（Telephone controllers × 3）

- **対象ファイル:** `app/controllers/sign/*/settings/telephones_controller.rb` (3 ファイル)
- **修正理由:**
  concern の全メソッドが各コントローラでオーバーライドされており、`include ::SignSettingsAuthorityRedirect`
  は完全に死コード。誤解を招く。
- **先に必要な作業:** `SignSettingsAuthorityRedirect`
  が他のコントローラでも利用されているかどうかを確認
- **追加すべきテスト:** 既存テストが引き続き pass することを確認
- **想定リスク:** include を削除するだけ。機能変更なし。

### 5位（バックログ Stage 2 対応）: Session revocation の Acme 権威確認と移行

- **対象ファイル:**
  `app/controllers/sign/*/settings/revocations_controller.rb`、`sign/*/settings/revocations/alls_controller.rb`、`sign/*/settings/revocations/others_controller.rb`
- **修正理由:** ADR によりセッション変異は Acme 権威。現状 Sign が直接 `token.revoke!`
  を呼んでいる。
- **先に必要な作業:** ADR `acme-session-and-token-authority.md`
  を照合し、Sign 側の session 変異が明示的に許容されているかどうかを確認
- **追加すべきテスト:** Acme への委譲が正しく機能することの統合テスト
- **想定リスク:** アーキテクチャ変更のため慎重な計画が必要。Stage
  2 ヒューマンレビューを先に実施すること

---

## 20. Unknowns

| 不明事項                                                                                  | 理由                                                                                                                                                                                  |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AUTHENTICATION_MODE = :private` の enforcement 機構                                      | `Sign::App::ApplicationController` の実装を詳細確認していない。`:private` mode 宣言が `before_action :authenticate_*!` を動的に登録するかどうかが telephone edit gap の判断に直結する |
| `authenticate_client!` が org セッションで完全失敗するかどうか                            | セッション構造（クッキー名・store key）がサーフェス間で分離されているかどうかを確認していない。分離されていれば P0 の実害は nil セッションによる 401 のみ                             |
| org secret credential に `ensure_verified_recovery_identity_for_registration!` がない理由 | 意図的か（operator は recovery identity 不要）か、実装漏れかが不明                                                                                                                    |
| MFA reset の `create` 無効化がいつ再有効化されるか                                        | `adr/mfa-reset-account-recovery.md` を確認していない                                                                                                                                  |
| `AcmeSettingsWithdrawalFlow` concern の権威所在                                           | concern が Acme concern なのか Sign concern なのか、ファイルパス (`app/controllers/concerns/`) のみで判断しており `concerns/` 内の具体的な実装は確認していない                        |
| `SessionsController#others` / `#revoke_all` がルート上到達不可であることの意図            | 将来のルート追加に備えた dead code か、完全に削除すべき remnant かが不明                                                                                                              |
| Acme→Sign→Acme JumpRT round-trip テスト                                                   | `test/integration/` に sign+settings 関連の統合テストは存在しないことを確認したが、JumpRT 自体のテストが他のファイルに存在するかどうかは確認していない                                |
| flash messages が UI で実際に表示されているかどうか                                       | コントローラで flash が設定されていてもビュー側が表示していなければ実害は小さい。ビューの flash 表示ロジックを確認していない                                                          |
| `com/settings/telephones_controller.rb` の `create` action の `head :unauthorized` ガード | `authorize_telephone_registration!` がすでに auth+authz を行っているのに `head :unauthorized` が追加されており、どのシナリオを想定しているかが不明                                    |

---

## 21. Final Assessment

### 1. Sign settings は現状、実用可能か

**Yes — 実用可能。** 全 3 サーフェスのテストが 0
failures で通過しており、ルート・コントローラ・ビューの整合性は高い。ユーザーが日常的に使用する機能（パスキー・メール・電話・セッション管理・退会）は全て正常に動作している。

### 2. app/com/org のうち壊れている surface はあるか

**明確に壊れている surface はないが、org に P0 の静的欠陥がある。**
`Sign::Org::Settings::RemovalsController` が `authenticate_client!`
を呼んでいるが、これは compatibility redirect
endpoint であり通常の使用では到達頻度が低い。com の telephone
index は未認証でのクラッシュリスク（P2）がある。

### 3. settings root のリンクはすべて生きているか

**Yes — 全リンクが対応するルートを持ち、コントローラが存在する。** app: 14 リンク全て有効。com:
10 リンク全て有効（TOTP・Apple・Google は意図的に欠落）。org:
10 リンク全て有効（オペレーターライフサイクルリクエストが追加）。

### 4. Acme と Sign の二重実装は安全か

**機能的には安全だが、権威境界が曖昧な領域が残存している。** `AcmeSettingsActivityLog`
は読み取り専用で Sign ビュー専用のラッパー — データ漏洩リスクなし。 `AcmeSettingsWithdrawalFlow`
は Sign に include されているが `WithdrawalsController`
で authorize! が実行されており所有権保護は機能している。Session
revocation は ADR 境界上の懸念があるが、現状は全て owner-scoped であり IDOR リスクはない。

### 5. ActivityLog の Acme namespace は命名負債だけか、実害があるか

**命名負債のみ。実害はない。**

- `AcmeAppSettingsActivityLog` → `Client` actor → `ClientChronicle` — サーフェス正確にスコープ済み
- `AcmeComSettingsActivityLog` → `Visitor` actor → `ClientChronicle` (subject-only) — サーフェス正確
- `AcmeOrgSettingsActivityLog` → `Operator` actor → `OperatorChronicle` — サーフェス正確

唯一の実質的問題は `AcmeComSettingsActivityLog` が `sign.app.settings.activity.events.*` という app
namespace の i18n キーを参照していること（これも表示上の問題のみ、データ境界違反ではない）。

### 6. unauthorized / ownership は十分にテストされているか

**不十分。** 既存テストは success path を中心にカバーしているが:

- 別ユーザーの resource ID を指定した 404 確認テストが少ない
- 未認証アクセスの 302 確認テストが全 action をカバーしていない
- ホスト制約（別ホストからのアクセス）のテストが存在しない
- `AuthMethodGuard` の最終認証手段削除ガードのエッジケーステストが少ない

### 7. 次に最初に直すべき 3 項目

1. **`app/controllers/sign/org/settings/removals_controller.rb:14`** — `authenticate_client!` を
   `authenticate_operator!` に変更（1 行修正、P0）
2. **com telephone index/app telephone edit の authentication gap** — `declare_authentication_mode!`
   enforcement の確認と、必要に応じて `authenticate_visitor!` / `authenticate_client!` を追加（P2）
3. **全 settings コントローラの flash message 違反解消** — `flash.now[:alert]` と
   `redirect_to(..., notice:/alert:)` を inline feedback rendering に置換（P2、全 3 サーフェス横断）

---

_このメモは 2026-06-23 時点の静的解析と限定的なテスト実行結果に基づく。Stage
2 の Acme 権威境界移行については `plans/backlog/sign-acme-boundary-remediation.md`
を参照。次のエンジニアへ: §8 の P0 修正を最優先とすること。_
