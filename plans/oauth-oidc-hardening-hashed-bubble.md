# OAuth/OIDC hardening 完了 + realm binding + behavioral DAMP tests 計画

## Context

進行中の OAuth/OIDC hardening を完了し、最新 worktree を前提に追加監査・DAMP behavioral
test 追加・最小修正を行う。調査の結果、指示書のハードニング項目の大半は **既に committed develop +
worktree に実装済み** と確認できた。残る実質的なギャップは 1 件のみ:
**issuer/realm と redirect_uri の binding が存在しない**(単一 client_id が app/org/com の全 redirect_uri を無差別に受理する)。

## 確定済みの現状(証拠付き)

### 実装済み(重複追加禁止)

| 項目                                                                           | 場所                                                                                                                      | 証拠                                                                                    |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| PKCE verifier 43–128 + charset `[A-Za-z0-9._~-]`                               | 3 モデル(`client_authorization_code.rb:39,114-124` は committed 済; operator/visitor は worktree diff で同一実装追加済み) | `PKCE_CODE_VERIFIER_PATTERN` + `verify_pkce`                                            |
| `code_challenge_method == "S256"` / plain・nil 拒否                            | 同上 + `validates :code_challenge_method, inclusion: %w(S256)`                                                            | model L49                                                                               |
| coordinator は PKCE を model へ委譲(重複なし)                                  | `oidc_token_exchange_coordinator.rb:135-140`                                                                              | blank check + `authorization_code.verify_pkce` のみ                                     |
| aud 配列化(`[client.client_id]`)・nbf=iat 発行・UTC・時系列検証                | `security_jwt_oidc_id_token_codec.rb:37-62,79-101`                                                                        | encode/decode 両方                                                                      |
| aud exactly-one / scalar・multi-aud 拒否                                       | `OidcIdTokenVerifier#validate_audience!` + provisioning 再検証(`oidc_rp_identity_provisioning.rb:27-38`)                  | `id_token_verifier_test.rb:29-43` で `[]`/scalar/`["evil",cid]`/`[cid,"evil"]` 拒否済み |
| provisioning は canonical audience 使用(raw `aud.first` 不使用)                | `oidc_callback.rb:281-291`                                                                                                | `verification_result.canonical_audience`                                                |
| state TTL 10min・expired/consumed state deletion                               | `oidc_callback.rb:11,202-229`                                                                                             | `callback_test.rb:144,181,216,265`                                                      |
| cross-client code 拒否・redirect_uri mismatch・code reuse・expired code        | `oidc_token_exchange_coordinator.rb:111-123,150-179`(transaction 内再検証 + atomic consume)                               | `token_exchange_service_test.rb:194,388,465,484,642,665,687`                            |
| malformed PKCE / plain の behavioral test                                      | `token_exchange_service_test.rb:445,1245` + worktree の operator/visitor model tests(42/129/不正文字 DAMP)                |                                                                                         |
| DPoP-bound token を Bearer 提示で拒否                                          | `palm_access_token_authenticator.rb:35-36`(`cnf.jkt` present → invalid_token)                                             | DPoP tests L1086-1165                                                                   |
| authorize: S256 必須・state/nonce 必須・redirect_uri 完全一致・scope allowlist | `oidc_authorize_request_validator.rb`                                                                                     | `authorize_service_test.rb:69,79,113,213`                                               |

### ギャップ(今回の実装対象)

1. **realm/redirect_uri binding なし**(案 B 未実装): `oidc_client_stores_static_client_store.rb` で
   `sign-rp`/`base-rails-rp`/`side-rails-rp`/`core-next-rp`
   が app/org/com の redirect_uri を一つの flat 配列で登録。`valid_redirect_uri?`
   は client 全体の完全一致のみ(`oidc_redirect_uri_validator.rb`)。→
   BASE_APP の authorize が org の redirect_uri へ authorization
   response を送れる(誤配送 B が許可されている)。
2. **`test/services/oidc_token_exchange_boundary_test.rb`
   が source-grep のみ**(23行、`assert_no_match`)。behavioral 版が別ファイルに散在しており boundary としての固定が弱い。
3. **surface cross-boundary の behavioral
   matrix が体系化されていない**(個別テストは存在するが、指示書 §2/§5 の組み合わせを網羅した DAMP テスト群がない)。
4. PKCE 実装が 3 モデルに逐語コピー(セキュリティ問題ではない。今回はスコープ外の follow-up として報告のみ — 「最小の一貫した変更」原則、かつ既存パターン踏襲)。

## 環境ブロッカーと合意済み対応

- worktree が Ruby 4.0.5→4.0.6 へ bump 済みだが環境は 4.0.5 のみ。`bin/rails`
  は boot 不可(確認済み)。
- **合意**: テスト実行中のみ `Gemfile`/`.ruby-version`
  を 4.0.5 に一時的に戻し、`bundle install`(Gemfile.lock の ruby 行のみ再生成される場合は復元)→テスト→**完了前に必ず 4.0.6 へ復元**。最終レポートに明記する。

## 実装ステップ

### Step 1: 進行中実装の完了確認(テスト実行)

Ruby 一時戻しの後:

```bash
SIGN_SERVICE_URL=sign.app.localhost RAILS_ENV=test bin/rails test \
  test/models/operator_authorization_code_test.rb \
  test/models/visitor_authorization_code_test.rb \
  test/models/client_authorization_code_test.rb \
  test/services/oidc/id_token_verifier_test.rb \
  test/services/oidc/token_exchange_service_test.rb \
  test/services/oidc/authorize_service_test.rb \
  test/controllers/concerns/oidc/callback_test.rb \
  test/controllers/concerns/oidc/rp_identity_provisioning_test.rb
```

green なら「進行中 hardening は完了」と確定。red なら test-first で最小修正。

### Step 2: realm/redirect_uri binding(案 B)— test-first

**設計**: 既存の env-key 構造が既に realm を表現している(`PUBLIC_*`=app, `*_STAFF_*`=org,
`*_CORPORATE_*`=com)ので、新抽象は足さず store の形だけ変える。

1. `oidc_client_stores_static_client_store.rb`: 各 client の `redirect_uris` を realm 別に構築する
   `redirect_uris_by_realm: { "client" => [...], "operator" => [...], "visitor" => [...] }`
   を追加 (realm キーは既存の resource_type 語彙 client/operator/visitor を使う: app=client,
   org=operator, com=visitor)。既存 flat `redirect_uris`
   は by_realm の flatten として導出し、post_logout/backchannel は現状維持。Palm
   native(`app-ios-rp`/`app-android-rp`)と docs/news/help は単一 realm。
2. `OidcClientRegistry` に `valid_redirect_uri?(client_id, uri, resource_type:)`
   を追加(realm-scoped 完全一致)。引数なし版は残すか、全 caller を realm 付きに移行(caller を確認して決定 — 少なければ移行)。
3. `oidc_authorize_request_validator.rb#validate_redirect_uri!`: 現在の issuer の resource_type で realm-scoped 検証に変更。resource_type は authorize
   endpoint が発行する code model 種別(Visitor/Operator/Client)から確定できる —
   validator の caller(authorize controller /
   `oidc_authorize_coordinator.rb`)を読んで受け渡し方法を確定。
4. token exchange: `oidc_token_exchange_coordinator.rb#validate_code`
   に、code に保存済み redirect_uri がその code model の realm の registered
   set に属することの再検証を追加(defense in
   depth、PKCE のような重複 regex ではなく registry への問い合わせ)。
5. callback 側の iss/act/subject namespace checks は現状維持(defense in depth)。

**テスト(先に書いて fail を確認)**:

- `authorize_service_test.rb` または新規: BASE_APP(client realm)の authorize が org/com
  realm の登録 redirect_uri を **code 発行前に** 拒否 — 指示書 §2 の 5 組み合わせを DAMP に。例:
  `test "BASE_APP authorize rejects an org Core redirect_uri before code issuance"`
- token exchange 側 realm 再検証テスト。

### Step 3: behavioral boundary tests の体系化

`test/services/oidc_token_exchange_boundary_test.rb`
は削除せず、同ファイルまたは隣接ファイルに behavioral ケースを追加:

- §4.1–4.6 のうち既存カバーは重複追加しない(上表のとおり大半は `token_exchange_service_test.rb`
  に存在)。不足分のみ追加: cross-client を「client A の code + client B の authenticated
  request」という指示書の形で明示する DAMP テスト、concurrent/2回目 exchange で 2 つ目の token
  set が出ないことの assertion、malformed verifier の各ケース (space/slash/plus/equals/non-ASCII —
  worktree の 42/129/`*` に追加)を **model 単体でなく exchange path 経由で**。
- §5 surface matrix: 同一 component 別 surface / 同一 surface 別 component
  / 別 surface 別 component の DAMP テスト。既存 verifier/callback テストでカバー済みのセルは「既に修正済み」として matrix に記録し、未カバーのセルのみ追加。
- §6 aud cases: `id_token_verifier_test.rb` でほぼ網羅済み — 「app Core audience token を app
  Auth が拒否」等の cross-component 命名のケースが無ければ追加。
- Palm: `palm_access_token_authenticator_test.rb` に `aud=core-next-rp`
  拒否 / 非許可 client_id 拒否 / DPoP-as-Bearer 拒否があるか確認し、不足分を追加。public
  client の PKCE 必須は authorize validator 側で既に強制(S256 必須)。
- §7 state/nonce: `callback_test.rb` の既存に対し、client_id 違い / redirect_uri 違い / nonce 違い /
  2 並行 flow 非干渉の不足ケースを追加。
- §8 cookie: `test/security/invariants/` の既存 cookie
  invariant テストを確認し、レポートで判定(実装変更は原則なし)。

テスト命名は「source surface/component + target + artifact + 拒否地点」形式。helper は signed
token 生成・PKCE challenge 計算・time freeze・fixture に限定。

### Step 4: 最終レポート

`memos/2026-07-16-oauth-oidc-hardening-audit.md` に日本語で、指示書 §13 の A〜H 表 (implementation
status / PKCE verdict / realm binding / cross-boundary matrix / DAMP review / changes / commands /
final verdict)を保存。Ruby 一時戻しと復元、PKCE 3 重複の follow-up、案 B 採用理由を明記。

## 変更ファイル(予定)

- `app/values/oidc_client_stores_static_client_store.rb` — redirect_uris の realm 別化
- `app/services/oidc_client_registry.rb` / `app/validators/oidc_redirect_uri_validator.rb` —
  realm-scoped 検証
- `app/services/oidc_authorize_request_validator.rb` — realm 付き redirect_uri 検証
- `app/services/oidc_token_exchange_coordinator.rb` — code の realm binding 再検証(最小差分)
- `test/services/oidc/authorize_service_test.rb`,
  `test/services/oidc/token_exchange_service_test.rb`,
  `test/services/oidc_token_exchange_boundary_test.rb`,
  `test/services/palm_access_token_authenticator_test.rb`,
  `test/controllers/concerns/oidc/callback_test.rb` ほか — DAMP behavioral tests 追加
- `memos/2026-07-16-oauth-oidc-hardening-audit.md` — 最終レポート

新規 service は追加しない。PKCE validation の layer 重複は追加しない。

## Verification

1. Ruby 一時戻し → `bundle check`
2. `SIGN_SERVICE_URL=sign.app.localhost RAILS_ENV=test bin/rails routes -g 'oauth|oidc'`
3. Step 1 の focused suite green
4. 新規テスト: 修正前 fail → 実装 → green
5. 隣接 boundary: `test/services/oidc/` 全体 + `test/models/*authorization_code_test.rb` + palm
   authenticator + `test/security/invariants/`
6. Gemfile/.ruby-version を 4.0.6 へ復元し、最終レポートに実行結果と blocker を記録
