# OAuth 2.0 / OpenID Connect セキュリティ監査 — 調査結果と実装計画

## Context

対象は自作の OAuth/OIDC スタックを持つ Rails リポジトリ。`doorkeeper` / `openid_connect` OP
gem は不使用で、OP（認可サーバ）と RP（クライアント）の両方を独自実装している。本監査は「現在のコード・設定・テスト・実行結果のみ」を事実として、security
first でゼロから評価した。

結論を先に述べる。**中枢の実装（ID Token verifier、token exchange、client registry、redirect_uri
validator、PKCE）は成熟しており、静的読解で成立する Critical/High は現時点で確認できなかった。**
監査の主眼は次の3点になる。

1. RFC 7636 適合ギャップ（PKCE `code_verifier` の length/charset 未検証）＝ Low の実装修正。
2. `core-next-rp` / `base-rails-rp` / `side-rails-rp` が単一 `resource_type`
   のまま app/org/com の redirect_uri を横断登録している設計の意図確認（surface
   confusion の可能性、UNKNOWN）。
3. cross-boundary 拒否を behavioral に固定する **DAMP negative test の追加**。特に既存
   `test/services/oidc_token_exchange_boundary_test.rb`
   は挙動でなくソース文字列 grep のみで、cross-client 拒否を実際には検証していない（テスト品質 finding）。

---

## A. Topology map（コードから復元）

surface は URL
prefix でなく**ホスト constraints**で分離（`config/routes/*.rb`）。app=`*.umaxica.app`、org=staff=`*.umaxica.org`、com=corporate=`*.umaxica.com`。**3つは別の登録可能ドメイン（別 TLD）**であり、これが cookie/セッション分離の土台。

- **Base** = 唯一の OP
  / 認可サーバ（`app/controllers/base/{app,com,org}/oauth/*`：authorize/token/jwks/userinfo/revoke）。
- **Auth** = credential ceremony ゲートウェイ兼 Base への RP（RP 権威は持たない）。
- **Core** = リージョナル BFF、RP（client_id `core-next-rp`）。
- **Side** = control-plane、RP（client_id `side-rails-rp`）。
- **Palm** = **native RP（`app-ios-rp` / `app-android-rp`, public client, PKCE）+ Resource
  Server**（bearer/DPoP、aud `palm-api`、`app/services/palm_access_token_authenticator.rb`）。app
  realm のみ、com/org は不在。

client_id と resource_type（＝realm/issuer）の対応（`app/values/oidc_client_stores_static_client_store.rb`）:

| client_id           | resource_type→issuer | redirect_uri host              | aud           | auth method       |
| ------------------- | -------------------- | ------------------------------ | ------------- | ----------------- |
| sign-rp             | client / BASE_APP    | id.app/org/com.localhost       | sign-rp       | private_key_jwt   |
| base-rails-rp       | client / BASE_APP    | www・side .app/org/com         | base-rails-rp | private_key_jwt   |
| side-rails-rp       | client / BASE_APP    | side.app/org/com               | side-rails-rp | private_key_jwt   |
| core-next-rp        | client / BASE_APP    | jpx.umaxica.app/org/com        | core-next-rp  | private_key_jwt   |
| app-ios-rp          | client               | umaxica://oidc/callback        | palm-api      | none(public+PKCE) |
| app-android-rp      | client               | com.umaxica.app:/oidc/callback | palm-api      | none              |
| docs/news/help _app | client/BASE_APP      | *.app.localhost                | umaxica-*-app | (default)         |
| docs/news/help _org | operator/BASE_ORG    | *.org.localhost                | umaxica-*-org | (default)         |
| docs/news/help _com | visitor/BASE_COM     | *.com.localhost                | umaxica-*-com | (default)         |

**重要な設計事実**:
Base/Side/Core/Sign の RP は「component ごとに1つの client_id」で、その client が app/org/com の redirect_uri を横断保持する。すなわち surface 分離は client_id 単位では行われず、redirect_uri
host と（docs/news/help 系のみ）resource_type で表現される。監査プロンプトの「app/Auth・app/Core… を別 client とみなす」前提は実態と異なる。

## B. Protocol flow map（RP=Core 代表、evidence 付き）

1. login start / authorize：`app/controllers/base/app/oauth/authorizations_controller.rb`、検証
   `app/services/oidc_authorize_request_validator.rb:15-23`
2. code 発行：`OidcAuthorizationCodeIssuer` →
   `app/models/{visitor,operator,client}_authorization_code.rb`（TTL
   10s、`code = SecureRandom.urlsafe_base64(32)`、code UNIQUE index）
3. callback：`app/controllers/concerns/oidc_callback.rb`
4. token
   exchange：`app/services/oidc_token_exchange_coordinator.rb:27-47`（grant_type→client 認証→code→scope→PKCE→DPoP→atomic
   consume+issue）
5. ID Token 検証（RP側）：`app/services/oidc_id_token_verifier.rb` +
   `app/values/security_jwt_oidc_id_token_codec.rb`
6. provisioning：`app/controllers/concerns/oidc_rp_identity_provisioning.rb`（verifier 確定の canonical_audience 使用）
7. cookie/session：`__Host-auth_*`（`auth_io_keys.rb`）、apex domain
   scope（`core_cookie_domain.rb`、別 TLD なので surface を跨がない）
8. logout：RP-initiated +
   back-channel（`oidc_logout_token_codec.rb`、`oidc_backchannel_logout_notifier.rb`）

## C. Docs との差分（主要項目）

| Pri | Item                         | Expected                                              | Current                                                                      | Verdict                  | Evidence                                                   |
| --- | ---------------------------- | ----------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------ | ---------------------------------------------------------- |
| P1  | ID Token `aud`               | 配列・要素1・client_id 完全一致                       | `aud=[client.client_id]`、verifier で Array/size==1/secure_compare           | **OK**                   | codec:47, verifier:63-71                                   |
| P1  | issuer 検証                  | 完全一致                                              | `verify_iss:true, iss:` 指定                                                 | **OK**                   | codec:87-88                                                |
| P1  | alg 固定                     | 期待 alg のみ                                         | ES384 pin、header/payload typ・act チェック                                  | **OK**                   | codec:16-17,31-32,81                                       |
| P1  | 時刻 claim                   | iat/nbf/exp を1回の issued_at から                    | build_payload で単一 issued_at 使用                                          | **OK**                   | codec:39-49                                                |
| P1  | redirect_uri                 | 完全一致・prefix/wildcard 不可                        | `Array(redirect_uris).include?(uri)`                                         | **OK**                   | validator:7-9                                              |
| P1  | code binding                 | client_id/redirect_uri/PKCE 拘束＋single-use          | validate_code + lock! transaction で atomic consume                          | **OK**                   | coordinator:111-123,142-179                                |
| P1  | client 認証                  | 登録 method に厳格 dispatch                           | private_key_jwt が secret に fallback 不可                                   | **OK**                   | coordinator:59-83                                          |
| P1  | PKCE method                  | S256 のみ                                             | authorize/model/verify すべて S256                                           | **OK**                   | validator:34, model inclusion, verify_pkce                 |
| P1  | PKCE verifier 形式           | 43–128・unreserved charset                            | **length/charset 未検証**（blank のみ）                                      | **NG(Low)**              | coordinator:135-139, model verify_pkce                     |
| P1  | Palm RS                      | aud=palm-api＋scope＋client 許可＋DPoP は Bearer 拒否 | 実装済み・多層                                                               | **OK**                   | palm_authenticator:34-52                                   |
| P1  | surface/realm 分離           | app が org/com を侵害しない                           | client_id/aud は共有だが iss/act/subject-realm/OP host が surface ごとに分離 | **OK（追加調査で確定）** | core/*/application_controller, oidc_callback:81-90,261-265 |
| P4  | token exchange boundary test | cross-client 拒否を behavioral に検証                 | ソース grep のみ                                                             | **NG**                   | oidc_token_exchange_boundary_test:8-22                     |

## D. Finding 一覧

- **F1 (Low, RFC7636)** PKCE `code_verifier`
  length/charset 未検証。`OidcTokenExchangeCoordinator#verify_pkce`（coordinator:135-139）と各
  `*_authorization_code#verify_pkce` は `blank?`
  のみで SHA256 比較へ。challenge 拘束が効くため直接悪用は不可だが、非適合。43–128 かつ
  `[A-Za-z0-9._~-]` 以外を `invalid_request` で拒否する。
- **F2 (Info→P4)** `oidc_token_exchange_boundary_test.rb` はソース文字列 grep のみで、client
  A の code を client B で交換不可、redirect_uri mismatch、code 再利用、wrong
  verifier などを**挙動として**検証していない。DAMP behavioral test で置換・補強。
- **F3 (RESOLVED — 脆弱性ではない)**
  ユーザーの最重要懸念「app が org/com に干渉するのでは」を追跡調査した結果、**surface 分離は保たれている**。仕組み:
  - client_id `core-next-rp` と aud `core-next-rp` は3 surface で共有だが、**RP
    callback は自身のコントローラ（Core::App/Org/Com）の actor
    class から resource_type を導出**する（`OidcCallback#oidc_resource_type` →
    `rp_actor_resource_type`：Operator→operator, Visitor→visitor,
    Client→client。oidc_callback:261-265, oidc_rp_identity_provisioning:126-132）。
  - この resource_type が verify に使う **issuer と act を surface ごとに切替**（app=BASE_APP,
    org=BASE_ORG, com=BASE_COM。codec decode_options で `verify_iss` 完全一致 + payload `act`
    一致。verifier:81-90, codec:32,87-88）。
  - さらに各 surface の callback は **別々の Base
    OP ホスト**を向く（Core::Org=`PRIVATE_BASE_STAFF_URL`=base.org、Core::App=`PRIVATE_BASE_SERVICE_URL`=base.app。core/*/application_controller.rb:81-86）。
  - provisioning は subject を **actor
    realm の namespace で復号**（`OidcSubject.public_id_from(sub, resource_type: rp_actor_resource_type)`、不一致は RecordNotFound。provisioning:50-58）。
  - 結論：app-realm token（iss=BASE_APP, act=client, sub=client-namespace）を org Core
    callback に流し込んでも、org は iss=BASE_ORG・act=operator・operator-namespace を要求するため
    **issuer 検証 → act 検証 → subject 復号の三重で拒否**され、consumer が staff
    Operator に昇格することはない。共有 client_id/aud は「同一 RP アプリを3ホストで提供、realm 分離は AS(issuer)側で担保」という設計で、RFC 上も aud=client 識別・iss=AS 識別の役割分担に沿う。
  - 任意の defense-in-depth（必須でない）：realm ごとに aud を分ける（例
    `core-next-rp-org`）と、issuer 検証をすり抜けた場合の第二の壁になる。**F3 は情報項目に降格し、修正スコープから外す**。

## E. Cross-boundary matrix（追加/確認する negative test）

| Source                       | Target               | Artifact           | Expected                                    | 対象                             |
| ---------------------------- | -------------------- | ------------------ | ------------------------------------------- | -------------------------------- |
| client A code                | client B token req   | authorization code | reject `invalid_request` client_id mismatch | coordinator:120                  |
| A redirect                   | A' の登録外 redirect | redirect_uri       | reject at authorize & exchange              | validator:62-67, coordinator:119 |
| 別 flow の verifier          | code                 | code_verifier      | PKCE 失敗 reject                            | coordinator:135-139              |
| aud `["evil","expected"]`    | Core RP              | ID Token           | verifier reject（size!=1）                  | verifier:63-71                   |
| scalar/empty aud             | Core RP              | ID Token           | reject                                      | verifier:63-71                   |
| core-next-rp 用 access token | Palm RS              | access token       | reject（aud/client 不一致）                 | palm_authenticator:88-96         |
| DPoP-bound token             | Palm RS as Bearer    | access token       | reject                                      | palm_authenticator:36            |
| 使用済み/期限切れ code       | token req            | authorization code | reject `invalid_grant`                      | coordinator:112-113,152-153      |

## F. 実装修正（最小差分）

| File                                              | Change                                                                              | 責務根拠                                                                    | Security eff果                                   |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------ |
| `app/services/oidc_token_exchange_coordinator.rb` | `verify_pkce` 前に verifier の 43–128・charset 検証を追加し不正は `invalid_request` | code/PKCE 不変条件は token endpoint coordinator の責務（新規 service 不要） | RFC7636 適合、不正 verifier の silent 受理を防止 |
| （代替）各 `*_authorization_code#verify_pkce`     | 同検証をモデル境界に集約                                                            | PKCE 不変条件を code model に置く選択肢                                     | 同上（配置はレビューで決定）                     |

新規 service は追加しない（方針準拠）。F3 の結論次第で `static_client_store` の redirect_uri 分割 or
RP verifier の resource_type 検証追加が発生し得るが、**ユーザー確認後に別スコープ**とする。

## G. テスト品質方針（DAMP first）

追加/置換テストは surface・component・攻撃条件・期待拒否地点をテスト名に含める。共通 helper は「正しい署名済み token 生成」「RFC 準拠 PKCE
challenge 計算」「time
freeze」に限定し、client_id/redirect_uri/攻撃条件は各テスト本体に明示（helper に隠さない）。代表名：

- `token exchange rejects a core-next-rp code presented with side-rails-rp client_id before issuing tokens`
- `token exchange rejects a code_verifier shorter than 43 chars as invalid_request`
- `Core RP id token verifier rejects a multi-audience token before provisioning`
- `Palm resource server rejects an access token issued for core-next-rp`
- `token exchange rejects a reused authorization code on the second exchange`

追加先：`test/services/oidc_token_exchange_*`（behavioral 版）、`test/services/oidc/`（verifier）、`test/services/palm_access_token_authenticator_test.rb`（既存に不足分追記）。

## H. 実行計画（この順で execute）

1. F3 をユーザーに確認（下記 Open question）。
2. 既存テスト精査：`test/services/oidc/`, `palm_access_token_authenticator_test.rb`,
   `oidc_token_exchange_boundary_test.rb`, `visitor_authorization_code_test.rb`
   を読み、E 表の各ケースが既に behavioral に存在するか確認。存在するものは重複追加しない。
3. F1 の再現テストを先に書き、修正前に fail することを確認（fail-fast）。
4. `verify_pkce` に length/charset ガードを最小差分で追加。
5. focused:
   `bin/rails test test/services/oidc_token_exchange_boundary_test.rb test/models/concerns/... test/services/palm_access_token_authenticator_test.rb`
6. E 表の欠落ケースを DAMP で追加し focused 実行。
7. 関連 suite：`bin/rails test test/services test/models` の OIDC 範囲。
8. routes/wiring 確認：`bin/rails routes | grep -Ei 'oauth|oidc'`
   で token/authorize/jwks の各 realm 存在を確認。
9. Final verdict（Security / Implementation / Runtime / Test quality に分けて）。

## Verification

- 修正前 fail 確認：新規 F1 テストを追加し `bin/rails test <file>:<line>`
  が意図した理由で fail することを提示。
- 修正後：同 focused test green、隣接 boundary（別 client/redirect/reuse）regression green。
- 実行不能時（test DB 未整備・ENV 不足）は「OIDC 実装不備」ではなく「test DB 準備不足 /
  ENV 不足」として分離報告。必要 ENV は `PUBLIC_CORE_*` / `BASE_*` /
  `SIDE_*`（`client_config_signature` 参照）。

## Open question

F3（app→org/com 干渉懸念）は追加調査で
**surface 分離が保たれている**と確定済み（上記 F3 参照）。修正不要。残る実装修正は F1（PKCE 適合、Low）のみで、それ以外は既存挙動を DAMP テストで固定する作業。実行フェーズに進んでよいか承認を求める。
