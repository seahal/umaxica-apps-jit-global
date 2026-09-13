# OAuth/OIDC hardening 最終終了判定 — 残 3 項目の検証と最小修正プラン

## Context

authorization redirect_uri の realm binding 完了(538 tests / 0
failures)を受けての最終終了判定。Summary 未記載の 3 点(post_logout_redirect_uri realm binding /
private_key_jwt cross-realm・jti replay / back-channel logout realm
selection)を現行コード・テストから検証した。

注: この環境の Ruby は 4.0.5、Gemfile は 4.0.6 を要求しており `bin/rails test` は
`Bundler::RubyVersionMismatch`
で実行不可。テスト実行結果はユーザー環境での直近 538/0 に依拠し、本プラン実装後にユーザー環境で再実行して確認する。

## 検証結果

| 項目                                   | Verdict | 実装根拠                                                                                                                                                                                                                                                                                                                       | Behavioral test                                                                                                                                                                                                                                      | 実行結果              | 追加修正         |
| -------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- | ---------------- |
| post_logout_redirect_uri realm binding | **NG**  | `app/validators/oidc_redirect_uri_validator.rb:13-15` が flat exact match。`oidc_client_registry.rb:87-91` に resource_type 引数なし。store は app+org+com を `+` で単一配列に連結(`oidc_client_stores_static_client_store.rb:19-21` ほか)。plan `oauth-oidc-hardening-hashed-bubble.md:66` が「post_logout は現状維持」と明記 | exact match の accept/reject のみ(`test/services/oidc/end_session_request_test.rb:112,123`、`client_registry_test.rb:56`、`base/app/oidc/logouts_controller_test.rb:72`)。cross-realm 拒否テストなし                                                 | 環境要因で未実行      | **要修正**(下記) |
| private_key_jwt cross-realm binding    | **OK**  | `aud` = 呼び出し先 token endpoint の正確な URL(`base_oauth_token_endpoint.rb:18` で `request.original_url` → `oidc_client_assertion_jwt.rb:76` `verify_aud: true, aud: token_url`)。`iss`/`sub` == client_id(`:79-80`)、`exp`/`iat` 検証(`:72-75,82`)、署名は per-client 登録鍵(namespace+kid、`:60-64`)                       | wrong aud: `oidc_client_assertion_jwt_test.rb:81` と `token_exchange_service_test.rb:75`(別 endpoint URL で拒否 = cross-realm と同一機構)。別 client: `oidc_client_assertion_jwt_test.rb:95`。**exp/iat 失効・wrong signing key の直接テストは欠落** | 前回 538/0 に含まれる | テストのみ追加   |
| private_key_jwt jti replay             | **OK**  | `oidc_client_assertion_jwt.rb:95-121` — `Rails.cache` の put-if-absent、TTL=exp+leeway、store 障害時 fail-closed                                                                                                                                                                                                               | 同一 assertion 2 回拒否: `oidc_client_assertion_jwt_test.rb:123`、2 つ目の code 交換でも拒否: `token_exchange_service_test.rb:100`、fail-closed: `:142`                                                                                              | 前回 538/0 に含まれる | なし             |
| back-channel logout realm selection    | **OK**  | 同一 client registration に 3 realm の URI が混在するが、notifier は `backchannel_logout_uris_for(resource_type:)` で選択(`oidc_backchannel_logout_notifier.rb:19-22`)。`filter_logout_uris` が host で operator/visitor/client に分類(`oidc_client_registry.rb:236-283`)                                                      | `client_registry_test.rb:111-136` が app/org/com URI の realm 別分離を厳密に assert                                                                                                                                                                  | 前回 538/0 に含まれる | なし             |
| logout token realm/replay checks       | **OK**  | `oidc_logout_token_codec.rb:65-78` — `verify_iss`(iss = resource_type 別 issuer → 別 realm token は拒否)、`verify_aud`、`verify_iat/exp`、events 厳密一致(`:89`)、jti replay は `SecurityConsumedJti`(DB、`:92-102`)で fail-closed                                                                                             | wrong issuer `:288`、aud mismatch `:129`、replay `:53`、iat/exp `:216-258`、events `:267-287`(logout_token_codec_test.rb)。receiver 側も `rp_logout_receivers_test.rb:88,105,122`                                                                    | 前回 538/0 に含まれる | なし             |

## 修正プラン(最小差分・新規 service なし)

### 1. post_logout_redirect_uri の realm binding(必須)

realm 判定は既存の host 分類
`logout_uri_resource_type`(`oidc_client_registry.rb:245-253`、post_logout URI と backchannel
URI は同じ host ファミリー)を再利用する。store の構造変更はしない。

- `app/services/oidc_client_registry.rb:87-91`
  `valid_post_logout_redirect_uri?(client_id:, uri:, resource_type:)`
  に resource_type を必須追加し、exact match に加えて
  `logout_uri_resource_type(uri) == normalize_resource_type(resource_type)` を要求。
- `app/services/oidc_end_session_request.rb:48-51` 呼び出しに
  `resource_type: resource_type_for_request` を渡す(既存 private メソッド `:151-158` を再利用)。
- validator(`oidc_redirect_uri_validator.rb`)は exact
  match のまま変更不要(realm 判定は registry 層)。呼び出し元が end_session_request のみか grep で確認し、他があれば同様に realm を渡す。

### 2. テスト追加

- `test/services/oidc/client_registry_test.rb` cross-realm 拒否: app realm で org/com の post_logout
  URI を拒否、org realm で app/com を拒否、com realm で app/org を拒否。同 realm
  URI は引き続き許可。
- `test/services/oidc/end_session_request_test.rb` app
  surface のリクエストに org 登録 post_logout_redirect_uri → `invalid_request` かつ redirect なし。
- `test/controllers/base/{app,org,com}/oidc/logouts_controller_test.rb` 各 surface で cross-realm
  URI が外部 redirect にならないこと(既存 `:72` パターンに倣う)。
- `test/services/oidc_client_assertion_jwt_test.rb`(private_key_jwt の欠落分)
  - 失効した assertion(exp 過去)を拒否
  - iat が未来の assertion を拒否
  - client の登録鍵以外(未登録鍵)で署名した assertion を拒否

### 3. 変更しないもの

- private_key_jwt の実装コード(既に安全)
- back-channel logout 全体(realm selection・logout token 検証とも実装/テスト済み)
- PKCE 3 モデル重複 → 別 follow-up issue として残す(コード変更なし)

## 終了判定

- Remaining Critical/High: **post_logout_redirect_uri realm binding の 1 件のみ**(本プランで解消)
- Remaining Medium/Low: private_key_jwt の exp/iat・wrong-key behavioral
  test 欠落(本プランでテスト追加)、PKCE 3 モデル重複(follow-up issue 化)
- 本プラン実装 + ユーザー環境で `bin/rails test` green をもって OAuth/OIDC
  hardening は**終了判定可**

## Verification

```bash
bin/rails test test/services/oidc/client_registry_test.rb \
  test/services/oidc/end_session_request_test.rb \
  test/services/oidc_client_assertion_jwt_test.rb \
  test/controllers/base/app/oidc/logouts_controller_test.rb \
  test/controllers/base/org/oidc/logouts_controller_test.rb \
  test/controllers/base/com/oidc/logouts_controller_test.rb
bin/rails test   # full suite
```

(この環境では Ruby 4.0.5 vs Gemfile 4.0.6 の mismatch で実行不可 — ユーザー環境での実行が必要)
