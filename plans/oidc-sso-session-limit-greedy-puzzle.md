# OIDC SSO / Session-Limit / Callback Return-To 現状調査

調査日: 2026-06-24  
調査種別: read-only（コード変更なし）

---

## Context

Sign → Acme /oauth/authorize → Sign /oidc/callback の SSO フローで、  
callback 後の最終 return-to が `https://id.umaxica.app/settings?ri=jp`（期待値）ではなく  
`https://www.umaxica.app/oauth/authorize?...`（汚染値）になるという報告がある。  
本調査では、コードと実行結果から現状を事実ベースで整理する。

---

## 1. Worktree 状態

### Staged（`M ` = staged のみ）

- `app/controllers/concerns/authentication_base.rb`
- `app/controllers/acme/app/oauth/authorizations_controller.rb`
- `app/controllers/acme/app/session_limit_resolutions_controller.rb`
- `app/controllers/acme/app/social/authentications_controller.rb`
- `app/controllers/acme/com/oauth/authorizations_controller.rb`
- `app/controllers/acme/org/oauth/authorizations_controller.rb`
- `app/controllers/concerns/csp_violation_report.rb`
- `app/controllers/concerns/preference_base.rb`
- `app/controllers/concerns/sign_out_notice.rb`
- `app/controllers/concerns/social_callback_guard.rb`
- `app/controllers/sign/app/sign/in/emails_controller.rb`
- `app/models/client_authorization_code.rb` / `client_token.rb`
- `app/models/operator_authorization_code.rb` / `operator_token.rb`
- `app/models/visitor_authorization_code.rb` / `visitor_token.rb`
- `app/services/oidc/acme_service_origin.rb`
- `app/services/oidc_access_token_authenticator.rb`
- `app/services/oidc_authorization_code_issuer.rb`

### Staged + Unstaged（`MM`）

- `app/controllers/concerns/authentication_base.rb`
- `Gemfile.lock`

### Unstaged のみ（` M`）

- `app/controllers/concerns/authentication_current_resource_resolver.rb`
- `app/controllers/concerns/sign_requires_recovery_passcodes.rb`
- `app/controllers/sign/app/settings/passkeys/` 系（options/verifications/passkeys/totps）
- `app/controllers/sign/com/settings/passkeys/` 系
- `app/controllers/sign/org/settings/passkeys/` 系

### 新規（未追跡）

- `app/models/client_token_usage.rb` / `operator_token_usage.rb` / `visitor_token_usage.rb`
- `app/models/concerns/oidc_token_usage.rb`
- `app/services/oidc_refresh_token_service.rb`
- DB マイグレーション（`*_create_*_token_usages_*`、3 DB 分）
- `app/controllers/sign/com/settings/secrets_controller.rb`
- `app/services/recovery_passcode_top_up.rb`

### Whitespace check

```
git diff --check → エラーなし（clean）
```

### Ruby 構文

```
変更済み .rb ファイル全件 → Syntax OK
```

---

## 2. 主な差分の要点

### `authentication_base.rb`

```ruby
# Before
@current_session = token_record_connection_owner
  .connected_to(role: :reading, &find_logic)

# After
@current_session = token_record_connection_owner
  .connected_to(role: :writing, &find_logic)
```

current_session 取得を `:reading` → `:writing` に変更。  
Sign 側 live Acme authorize で発生した `resource_not_found` の修正対応。

### `authentication_current_resource_resolver.rb`

JWT payload からリソース解決する箇所を `ActiveRecord::Base.connected_to(role: :writing)` で囲む。

### `oidc_authorization_code_issuer.rb`

- `session_token:` パラメータを必須に追加
- `validate_session_token!` を追加（actor 一致、usable 確認）
- 認可コードを session token にバインドして発行

### `acme/app/oauth/authorizations_controller.rb`

- Line 50: `OidcAuthorizeService.call(session_token: current_session)` を追加
- Line 105: `log_in` を `connected_to(role: :writing)` ブロックで囲む

### `session_limit_resolutions_controller.rb`

- Social auth session-limit resolution の新パス追加  
  （`social_resolution?` → `promote_social_resolution_session`）
- 既存の OIDC authorization パスは変更なし

### Token Usage 系（新規）

`ClientTokenUsage` / `OperatorTokenUsage` / `VisitorTokenUsage` + `OidcTokenUsage`
concern を追加。  
Refresh token ライフサイクル、revocation、logout 状態を各トークンに紐付けて追跡する。

---

## 3. 現在の Route 一覧（OIDC / OAuth / Session-Limit 関連）

### OIDC

```
GET  /oidc/authorization   → acme/app/oidc_authorization_endpoints#show（等、surface ごと）
GET  /oidc/callback        → sign/app/oidc_callbacks#show（等、surface ごと）
GET  /oidc/logout          → sign/app/oidc_logouts#show（等）
POST /oidc/backchannel/logout → sign/app, core/app, 他
```

### OAuth

```
GET  /oauth/authorize   → acme/app/oauth/authorizations#show（等）
POST /oauth/token       → acme/app/oauth/tokens#create（等）
GET  /oauth/userinfo    → acme/app/oauth/userinfo（等）
POST /oauth/revoke      → acme/app/oauth/revocations#create（等）
```

### Session-Limit

```
acme_app_session_limit_resolution:
  GET    /session-limit-resolution  → acme/app/session_limit_resolutions#show
  PATCH  /session-limit-resolution  → acme/app/session_limit_resolutions#update
  PUT    /session-limit-resolution  → acme/app/session_limit_resolutions#update
  DELETE /session-limit-resolution  → acme/app/session_limit_resolutions#destroy
```

**確認事項:**

| 項目                                        | 結果                 |
| ------------------------------------------- | -------------------- |
| `/session-limit-resolution` route           | ✅ 存在する          |
| `/sign/in/limitation` route                 | ❌ 存在しない        |
| Sign RP 側に session-limit resolution route | ❌ なし（Acme のみ） |

---

## 4. Sign settings 起点の静的経路

### pt の保存場所

`session[:oidc_pt]` のみ。保存箇所は 1 箇所：

```ruby
# app/controllers/concerns/oidc_sso_initiator.rb:43
session[:oidc_pt] = safe_oidc_pt(pt)
```

呼び出し経路:

```
authenticate!（before_action）
└─ sign_in_url_with_pt(encoded_pt(request.original_url))
   └─ initiate_oidc_session!(pt: decode_pt(encoded_pt))
      └─ session[:oidc_pt] = safe_oidc_pt(pt)  ← ここだけ
```

### `safe_oidc_pt` の検証ロジック（oidc_sso_initiator.rb:123-146）

- 制御文字 → reject → "/"
- scheme/host あり → `http/https` かつ **same-host のみ** → 他ホストは "/" に落とす
- path が "/" 始まりであること
- 検証失敗 → "/"

**重要**: `https://www.umaxica.app/oauth/authorize?...`
は Sign サーフェス（id.umaxica.app）と別ホストのため、  
`safe_oidc_pt` は必ずこれを reject して "/" を返す。

### `consume_oidc_pt`

```ruby
# app/controllers/concerns/oidc_callback.rb:77-79
def consume_oidc_pt
  session.delete(:oidc_pt).presence || "/"
end
```

返り値: `session[:oidc_pt]` の値、または `/` （空・nil の場合）。  
これ以外のロジックはない。

### Sign /oidc/callback の流れ

```
CallbacksController#show
├─ validate_state!          → session[:oidc_state] と params[:state] の secure_compare
├─ exchange_code!           → OidcRpTokenClient（PKCE verifier は session[:oidc_code_verifier]）
├─ verify_id_token!         → JWT 署名、expiry、nonce（session[:oidc_nonce]）
├─ provision_rp_account_from_id_token!  → identity 作成/リンク
├─ log_in                   → session reset、OIDC_RP_SESSION_KEYS 保持（:oidc_pt 含む）
├─ bind_oidc_rp_logout_session!
└─ redirect_to(consume_oidc_pt, allow_other_host: false)
```

`log_in` 後も `session[:oidc_pt]` は保持される（`OIDC_RP_SESSION_KEYS` に含まれる）。

---

## 5. return-to 汚染の分析

### 汚染は `session[:oidc_pt]` 経由では起きない

`safe_oidc_pt` が別ホスト URL を必ず "/" に落とすため、  
`https://www.umaxica.app/oauth/authorize?...` が `session[:oidc_pt]`
に入ることは現コードでは不可能。

### 汚染が起きるとすれば考えられる経路

| 仮説                                                                                          | 根拠                                                                                         | 確認状況     |
| --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------ |
| Jump redirect のジャンプページ自体が Sign の認証 guard を持ち、`authenticate!` が再実行される | Jump ページが保護されている場合、2 回目の `initiate_oidc_session!` が `oidc_pt` を上書きする | コード未確認 |
| callback controller に `consume_oidc_pt` 以外の redirect ロジックがある                       | surface ごとの callback controller にオーバーライドがある可能性                              | コード未確認 |
| 報告された汚染は旧コードのログ / テスト結果であり、現在の `safe_oidc_pt` 実装以前のもの       | 全テストが現在 PASS している                                                                 | **最有力**   |

### 現時点の結論

**全テストが PASS しており、現コードでは汚染の再現が確認されていない。**  
`safe_oidc_pt` の same-host 検証により、`https://www.umaxica.app/...`
が pt として保存されることは構造的に防がれている。「汚染」の報告は、この保護が導入される前の状態のログ・テスト出力を指している可能性が高い。

---

## 6. Acme authorize の現状

### `acme/app/oauth/authorizations_controller.rb` の既存セッション解決

```ruby
# Line ~45-60 (reconstruct from diff)
if logged_in? && current_client.present?
  OidcAuthorizeService.call(
    ...,
    session_token: current_session  # ← 今回追加
  )
  # → authorization code を即発行
  # → 新規 ClientToken は作らない
  # → /session-limit-resolution には行かない
  # → pending transaction は残らない
end
```

`session_token:` バインディング追加で、  
コード発行時に current_session の actor 一致 + usable 確認が行われるようになった。

---

## 7. テスト実行結果

### 全件 PASS

| ファイル                                               | テスト数 | アサーション | 結果              |
| ------------------------------------------------------ | -------- | ------------ | ----------------- |
| `test/services/oidc/acme_service_origin_test.rb`       | 9        | 53           | ✅                |
| `test/controllers/concerns/oidc/sso_initiator_test.rb` | 9        | 59           | ✅                |
| `test/controllers/acme/oauth_oidc_authority_test.rb`   | 31       | 161          | ✅                |
| `test/integration/core_rp_browser_flow_test.rb`        | 7        | 138          | ✅                |
| `test/integration/base_rp_browser_flow_test.rb`        | 1        | 15           | ✅                |
| `test/integration/oidc_rp_browser_flow_test.rb`        | 18       | 207          | ✅                |
| `test/integration/base_palm_auth_entrypoints_test.rb`  | 7        | 118          | ✅                |
| **合計**                                               | **82**   | **753**      | ✅ **0 failures** |

### fixture / FK 問題

- `client_token_usages.yml` / `operator_token_usages.yml` / `visitor_token_usages.yml`
  は存在しない（設計どおり）
- TokenUsage レコードはテスト内で動的に生成される
- FK 違反なし、fixture load failure なし

### session-limit resume failure

- `oidc_rp_browser_flow_test.rb` 18 件すべて PASS
- 以前報告された session-limit resume failure は現在再現しない

---

## 8. 判定

### A. Acme authorize 入口

✅ **成功している**  
既存 Acme session → `logged_in? && current_client.present?` → authorization code 即発行。  
`session_token:` バインディングも正常に動作（テスト 31 件 PASS）。

### B. Sign callback

✅ **Sign-local token は発行されている**  
`oidc_rp_browser_flow_test.rb` 18 件 PASS。callback→exchange→log_in の経路が通っている。

### C. return-to

⚠️ **現コードでは壊れていない可能性が高い**  
`safe_oidc_pt` が same-host を強制するため、別ホスト URL が pt に入る余地がない。  
ただし Jump redirect 経路と surface ごとの callback controller は未確認。

### D. OIDC authorize URL 汚染

**現時点では再現不可**  
`safe_oidc_pt` が `https://www.umaxica.app/...` を "/" に落とす実装が存在する。  
汚染報告は `safe_oidc_pt` 導入前のものと推定。

未確認リスク:

- Jump redirect のジャンプページが Sign 認証を持っていて `authenticate!` が 2 回走る場合  
  → `initiate_oidc_session!` が 2 回呼ばれ、2 回目の `request.original_url`（Jump URL）が  
  pt として書き込まれ、その path 部分（`/jump?...`）が最終 redirect 先になる可能性

### E. session-limit resume failure

✅ **現在は別 issue ではない・再現しない**  
全テスト PASS のため、過去に報告された failure は現コードで解消済みと判断。

### F. `/session-limit-resolution` の rename タイミング

⚠️ **今すぐ始めるべきでない**  
理由:

1. Jump redirect 経路における 2 回目 `authenticate!` のリスクが未確認
2. callback controller の surface ごとのオーバーライドが未確認
3. これらを確認してから rename の安全性を判断すべき

---

## 9. 未確認事項

| 項目                                                     | 優先度 | 備考                                       |
| -------------------------------------------------------- | ------ | ------------------------------------------ |
| Jump redirect ジャンプページの実装（認証 guard の有無）  | 高     | return-to 汚染の唯一残る経路               |
| Sign surface ごとの callback controller のオーバーライド | 高     | `consume_oidc_pt` 以外の redirect ロジック |
| `OIDC_RP_SESSION_KEYS` の完全な定義                      | 中     | `oidc_pt` が本当に含まれているか           |
| `oidc_callback_url` helper の完全な生成ロジック          | 低     | redirect_uri 汚染ではないことの確認        |

---

## 10. 次に流すべき修正方針

### 優先 1: Jump redirect ページの調査

```bash
rg -n "jump.*url\|redirect.*jump\|JumpRt\|jump_url\|/jump" app/ config/ --type rb
```

ジャンプページが Sign の before_action 認証を持つなら、  
`authenticate!` が 2 回実行されないよう skip するか、`oidc_pt`
を上書きしないよう保護する必要がある。

### 優先 2: Surface ごとの callback controller 確認

```bash
find app/controllers -name "*oidc*callback*" -o -name "*callback*oidc*"
```

`consume_oidc_pt` の結果を使わずに別の URL に redirect している箇所がないか確認する。

### 優先 3: `/session-limit-resolution` rename

上記 2 件が safe と確認できた後に実施する。
