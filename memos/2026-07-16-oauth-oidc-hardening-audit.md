# OAuth/OIDC hardening 完了確認 + realm binding 追加監査レポート

日付: 2026-07-16 / HEAD: dec9f0e4d (develop) の worktree

## 前提

- 進行中の OAuth/OIDC hardening 実装(PKCE verifier 契約、ID Token aud/nbf、state
  TTL 等)は、監査開始時点で**既に完了**していた。追加調査の結果、実質的なギャップは「issuer/realm と redirect_uri の binding が存在しない」1件のみ。
- Ruby 環境ブロッカー: worktree は `.ruby-version`/`Gemfile`
  が 4.0.5→4.0.6 に更新済みだが、実行環境には 4.0.5 のみ導入されていた。テスト実行のため一時的に
  `Gemfile`/`.ruby-version`/`Gemfile.lock`
  を 4.0.5 に戻し、全テスト実行後に 4.0.6 へ復元済み(最終 diff は元の worktree 状態と同一)。

## A. Current implementation status

| Item                                                                        | Already implemented                            | Newly added                  | Not needed | Evidence                                                                            |
| --------------------------------------------------------------------------- | ---------------------------------------------- | ---------------------------- | ---------- | ----------------------------------------------------------------------------------- |
| PKCE verifier 43–128 + charset `[A-Za-z0-9._~-]`                            | ✅(3モデル同一実装)                            |                              |            | `client_authorization_code.rb:39,114-124`、operator/visitor は worktree で追加済み  |
| `code_challenge_method == "S256"` 必須・plain/nil拒否                       | ✅                                             |                              |            | 同上 + `validates :code_challenge_method, inclusion: %w(S256)`                      |
| coordinator は PKCE を model へ委譲(重複なし)                               | ✅                                             |                              |            | `oidc_token_exchange_coordinator.rb#verify_pkce` は blank check + 委譲のみ          |
| ID Token aud 配列化・nbf=iat・UTC・時系列検証                               | ✅                                             |                              |            | `security_jwt_oidc_id_token_codec.rb:37-62,79-101`                                  |
| aud exactly-one・scalar/multi-aud 拒否                                      | ✅                                             |                              |            | `OidcIdTokenVerifier#validate_audience!`、`id_token_verifier_test.rb:29-43`         |
| provisioning は canonical audience 使用                                     | ✅                                             |                              |            | `oidc_callback.rb:281-291`、`oidc_rp_identity_provisioning.rb:27-38`                |
| state TTL 10min・expired/consumed state deletion                            | ✅                                             |                              |            | `oidc_callback.rb:11,202-229`                                                       |
| cross-client code 拒否・redirect_uri mismatch・code reuse・expired code     | ✅                                             |                              |            | `oidc_token_exchange_coordinator.rb:111-179`、`token_exchange_service_test.rb`      |
| malformed PKCE / plain の behavioral test                                   | ✅(model単体)                                  | ✅(exchange path 経由に拡充) |            | 旧: 1テストに5ケース同居 → 新: DAMP に分割 + space/slash/plus/equals/non-ASCII 追加 |
| DPoP-bound token を Bearer 提示で拒否                                       | ✅                                             |                              |            | `palm_access_token_authenticator.rb:35-36`                                          |
| authorize: S256必須・state/nonce必須・redirect_uri完全一致・scope allowlist | ✅                                             |                              |            | `oidc_authorize_request_validator.rb`                                               |
| **issuer/realm と redirect_uri の binding**                                 | ❌                                             | ✅                           |            | 下記 C 参照。案 B を実装                                                            |
| Palm: aud=core-next-rp 拒否                                                 | ✅(既存 "rejects wrong audience" で一般化済み) | ✅(named case追加)           |            | `palm_access_token_authenticator_test.rb`                                           |
| app-ios-rp/app-android-rp のコード相互交換不可                              | (client_id mismatch の汎用テストでカバー済み)  | ✅(named case追加)           |            | `token_exchange_service_test.rb`                                                    |

## B. PKCE final verdict

| Contract                          | Location                                                         | Behavioral test                                        | Verdict                                                 |
| --------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------- |
| verifier required                 | 3モデル `verify_pkce`                                            | `token_exchange_service_test.rb` (missing verifier)    | 実装済み                                                |
| length 43–128                     | `PKCE_CODE_VERIFIER_PATTERN`                                     | 42/129文字の個別DAMPテスト追加                         | 実装済み、テスト拡充                                    |
| charset `[A-Za-z0-9._~-]`         | 同上                                                             | space/slash/plus/equals/non-ASCII の個別DAMPテスト追加 | 実装済み、テスト拡充                                    |
| method は exactly `S256`          | `validates :code_challenge_method` + `verify_pkce`               | plain method テスト(単独化)                            | 実装済み                                                |
| nil method 拒否                   | 同上(inclusion validationがnilも拒否)                            | 既存                                                   | 実装済み                                                |
| S256 challenge 再計算・安全な比較 | `Digest::SHA256` + `ActiveSupport::SecurityUtils.secure_compare` | 既存                                                   | 実装済み                                                |
| 重複実装なし                      | coordinator は model に委譲                                      | コードレビューで確認                                   | 良好(3モデルへの逐語コピーは follow-up として H に記載) |

## C. Realm/redirect_uri binding

採用案:
**B(issuer/realm ごとに利用可能な redirect_uri を制限)**。新規抽象は追加せず、既存の resource_type 語彙(client/operator/visitor)と env-key 構造(`PUBLIC_*`=app,
`*_STAFF_*`=org, `*_CORPORATE_*`=com)をそのまま realm キーとして再利用した。

実装:

1. `oidc_client_stores_static_client_store.rb`:
   `sign-rp`/`base-rails-rp`/`side-rails-rp`/`core-next-rp` の `redirect_uris` を
   `redirect_uris_by_realm: { "client" => [...], "operator" => [...], "visitor" => [...] }`
   に再構成。単一realm client(Palm native, docs/news/help)は既存の flat `redirect_uris` +
   `resource_type` のままとし、registry 側でフォールバック変換する。
2. `OidcClientRegistry::VisitorAccount` に `redirect_uris_by_realm`
   フィールドを追加。`valid_redirect_uri?(client_id, uri, resource_type:)`
   を追加(realm 完全一致、既存の resource_type省略時の挙動は後方互換のため維持)。
3. `oidc_authorize_request_validator.rb`: authorize 要求元の realm を、呼び出し元コントローラの
   `resource_type`(認証前は resource が nil でもコントローラ自身が知っている値)で明示的に受け取り、redirect_uri をその realm に完全一致検証。認証済みコード発行経路(`oidc_authorize_coordinator.rb`)は既存どおり
   `resource.class` から realm を導出(常に non-nil resource)。
4. `oidc_token_exchange_coordinator.rb#validate_code`: defense in
   depth として、code に保存済み redirect_uri がその code の
   `resource_type`(モデル固有メソッド、既存)の登録済み realm set に属することを再検証。

| Issuer/realm    | Client        | Redirect URI realm | Authorization result      | Code issued | Final verdict                    |
| --------------- | ------------- | ------------------ | ------------------------- | ----------- | -------------------------------- |
| BASE_APP        | core-next-rp  | org (operator)     | 拒否(400 invalid_request) | されない    | 修正済み・テストで固定           |
| BASE_ORG        | core-next-rp  | app (client)       | 拒否                      | されない    | 修正済み・テストで固定           |
| BASE_COM        | core-next-rp  | org (operator)     | 拒否                      | されない    | 修正済み・テストで固定           |
| BASE_APP        | sign-rp       | org / com          | 拒否(両方)                | されない    | 修正済み・テストで固定           |
| BASE_ORG        | side-rails-rp | app / com          | 拒否(両方)                | されない    | 修正済み・テストで固定           |
| 各 issuer/realm | 該当 client   | 同一 realm         | 許可・redirect            | される      | 従来どおり成功(既存テストで固定) |

「最後に provisioning が失敗するだけ」ではなく、**authorize 時点(code 発行前)で拒否**されることを確認済み(`ClientAuthorizationCode.count`等を
`assert_equal 0` で明示検証)。

## D. Cross-boundary behavioral matrix

| Source                                 | Target                          | Artifact                         | Expected rejection point              | Actual | Test                                                                  |
| -------------------------------------- | ------------------------------- | -------------------------------- | ------------------------------------- | ------ | --------------------------------------------------------------------- |
| app core-next-rp code                  | org core-next-rp token exchange | 誤realm redirect_uri を含む code | token exchange (realm binding)        | 拒否   | `token_exchange_service_test.rb`(realm binding defense-in-depth test) |
| org redirect_uri                       | BASE_APP authorize              | redirect_uri                     | authorize(code発行前)                 | 拒否   | `authorize_service_test.rb`                                           |
| app redirect_uri                       | BASE_ORG authorize              | redirect_uri                     | authorize(code発行前)                 | 拒否   | 同上                                                                  |
| org redirect_uri                       | BASE_COM authorize              | redirect_uri                     | authorize(code発行前)                 | 拒否   | 同上                                                                  |
| org/com redirect_uri(sign-rp)          | BASE_APP authorize              | redirect_uri                     | authorize                             | 拒否   | 同上                                                                  |
| app/com redirect_uri(side-rails-rp)    | BASE_ORG authorize              | redirect_uri                     | authorize                             | 拒否   | 同上                                                                  |
| app-android-rp code                    | app-ios-rp token exchange       | authorization code               | token exchange(client_id mismatch)    | 拒否   | `token_exchange_service_test.rb`                                      |
| core-next-rp audience access token     | Palm RS                         | access token                     | Palm authenticator(invalid_token)     | 拒否   | `palm_access_token_authenticator_test.rb`                             |
| palm-api audience だが非許可 client_id | Palm RS                         | access token                     | Palm authenticator                    | 拒否   | 同上(既存+named case)                                                 |
| DPoP-bound token                       | Palm RS(Bearer提示)             | access token                     | Palm authenticator(cnf.jkt検出)       | 拒否   | 既存                                                                  |
| cross-client authorization code        | 別 client の token exchange     | authorization code               | token exchange(client_id mismatch)    | 拒否   | 既存 `token_exchange_service_test.rb:484`                             |
| 別 redirect_uri                        | 同一 client の token exchange   | redirect_uri                     | token exchange(redirect_uri mismatch) | 拒否   | 既存                                                                  |
| 消費済み code                          | 再交換                          | authorization code               | token exchange(already consumed)      | 拒否   | 既存                                                                  |
| 期限切れ code                          | 交換                            | authorization code               | token exchange(expired)               | 拒否   | 既存                                                                  |
| aud配列複数/scalar/空/誤り             | ID Token 検証                   | ID Token                         | verifier(validate_audience!)          | 拒否   | 既存 `id_token_verifier_test.rb`                                      |
| expired/consumed/cross-client state    | callback                        | pending flow                     | callback(state検証)                   | 拒否   | 既存 `callback_test.rb`                                               |

## E. DAMP test review

| Test                                                    | Behavioral or source grep                                    | Clear attack intent                                 | Excessive DRY | Action                                                                             |
| ------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------------- | ------------- | ---------------------------------------------------------------------------------- |
| `test/services/oidc_token_exchange_boundary_test.rb`    | source grep                                                  | N/A(アーキテクチャガード)                           | —             | 維持(behavioral は他ファイルでカバー済みのため削除せず、重複追加もしない)          |
| "rejects malformed PKCE verifiers and plain method"(旧) | behavioral だが 1テストに5ケース同居                         | 低(ケース名なし)                                    | あり          | DAMP に分割、命名を個別化、attack surface(space/slash/plus/equals/non-ASCII)を追加 |
| realm binding 系新規テスト                              | behavioral                                                   | 高(surface/component/artifact/拒否地点を命名に含む) | なし          | 追加                                                                               |
| Palm named audience/client_id テスト                    | behavioral                                                   | 高                                                  | なし          | 追加                                                                               |
| 既存 operator/visitor authorize/exchange テスト         | behavioral だが realm 区別なく `.redirect_uris.first` を誤用 | 中(realm混同のバグを隠していた)                     | —             | 修正(realm-scoped redirect_uri を明示使用するよう是正)                             |

## F. Changes

| File                                                                    | Change                                                                                                                                                 | Why here                                                                                          | Security effect                            |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| `app/values/oidc_client_stores_static_client_store.rb`                  | multi-realm client の `redirect_uris` を `redirect_uris_by_realm` に再構成                                                                             | redirect_uri の realm 情報を静的登録に持たせる唯一の場所(既存の client registry)                  | realm binding の情報源                     |
| `app/services/oidc_client_registry.rb`                                  | `VisitorAccount` に `redirect_uris_by_realm` 追加、`valid_redirect_uri?` に `resource_type:` オプション追加、単一realm client用フォールバック導出      | registry が client 登録情報の唯一の権威                                                           | realm-scoped 検証を可能に                  |
| `app/validators/oidc_redirect_uri_validator.rb`                         | `resource_type:` を受けて realm-scoped 完全一致に切替(省略時は従来どおり)                                                                              | 既存の検証責務の単一箇所                                                                          | 同上                                       |
| `app/services/oidc_authorize_request_validator.rb`                      | `resource_type:` を明示的に受け取れるように変更(nilなら既存の resource.class 由来ロジックにフォールバック)                                             | 認証前(resourceがnil)でも呼び出し元コントローラの realm を正しく伝播するため                      | 未認証フローでの realm 混同を修正          |
| `app/controllers/base/{app,org,com}/oauth/authorizations_controller.rb` | validator 呼び出しに `resource_type: resource_type` を追加                                                                                             | 各コントローラは自身の realm を`resource_type`で既に把握している                                  | authorize 時点での realm binding を有効化  |
| `app/services/oidc_token_exchange_coordinator.rb`                       | `validate_code` に realm binding の defense-in-depth 再検証を追加、`client_for_resource_type` に `redirect_uris_by_realm` 伝播を追加(Data必須キー対応) | token exchange 側での二重防御。PKCEのような正規表現重複ではなく registry への問い合わせに限定     | authorize 側のバグやバイパスに対する防御層 |
| `test/services/oidc/authorize_service_test.rb`                          | operator/visitor テストの redirect_uri を realm-scoped に是正、cross-realm 拒否の DAMP テスト6件追加                                                   | 既存テストが誤って client-realm URI を operator/visitor に使い回していた(realm binding欠如の実証) | realm binding の回帰防止                   |
| `test/services/oidc/token_exchange_service_test.rb`                     | 同様の realm-scoped 是正、realm binding defense-in-depth テスト・Palmクロスクライアントテスト・PKCE DAMPテスト(6ケース分割+4新規)追加                  | 同上                                                                                              | 同上                                       |
| `test/services/oidc/client_registry_test.rb`                            | test helper に `redirect_uris_by_realm` 追加                                                                                                           | `VisitorAccount.new` の必須キー対応                                                               | テスト実行に必要                           |
| `test/controllers/base/oauth_oidc_authority_test.rb`                    | `oidc_authorize_params` に `resource_type:` オプション追加、surface別に正しいrealmのredirect_uriを使用するよう是正                                     | 3surface共通ループが同一redirect_uriを使い回していた                                              | realm binding の回帰防止                   |
| `test/services/palm_access_token_authenticator_test.rb`                 | named audience/client_id テスト2件追加                                                                                                                 | 指示書§5準拠の明示的命名                                                                          | —                                          |
| `.ruby-version` / `Gemfile` / `Gemfile.lock`                            | テスト実行のため一時的に4.0.5へ変更 → 4.0.6へ復元                                                                                                      | 環境に4.0.6が未導入のため                                                                         | 変更なし(最終状態は元のまま)               |

新規 service は追加していない。PKCE validation のlayer重複も追加していない。

## G. Commands

| Command                                                                      | Result                                                                             | Runs/assertions                       | Blocker                                                                                                |
| ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `bundle check`                                                               | 成功(Ruby一時戻し後)                                                               | —                                     | Ruby 4.0.6 未導入(復元後は未検証、下記参照)                                                            |
| `bin/rails routes -g 'oauth\|oidc'`                                          | 未実行(明示的には省略、authorize/token endpointの存在はコントローラ読解で確認済み) | —                                     | —                                                                                                      |
| Step1 focused suite(model+verifier+exchange+authorize+callback+provisioning) | green                                                                              | 134 runs, 622 assertions, 0 failures  | —                                                                                                      |
| Step2 realm binding(authorize_service_test)                                  | green                                                                              | 28 runs, 132 assertions               | —                                                                                                      |
| token_exchange_service_test(realm binding含む全体)                           | green                                                                              | 61 runs, 228 assertions               | —                                                                                                      |
| palm_access_token_authenticator_test                                         | green                                                                              | 16 runs, 34 assertions                | —                                                                                                      |
| OIDC全体+security invariants+統合テスト(最終回帰)                            | green                                                                              | 538 runs, 2490 assertions, 0 failures | —                                                                                                      |
| Ruby 4.0.6 復元後の再実行                                                    | **未実行**                                                                         | —                                     | 環境に4.0.6が導入されていないため、復元後の状態でのテスト実行は次回4.0.6が利用可能になった時点で要実施 |

## H. Final verdict

- **Security**: PKCE・aud・nbf・state TTL・code
  reuse/expiry/cross-client 拒否は全て実装済みで behavioral に固定。今回追加した realm
  binding により、issuer/realm を跨いだ redirect_uri 誤配送(surface
  confusion)が authorize 時点(code発行前)で拒否されることを確認。
- **RP isolation**: cross-client code exchange・redirect_uri
  mismatch は従来から実装済み。app-ios-rp/app-android-rp 相互不可を named test で明示。
- **Surface/realm
  isolation**: 案B(issuer/realmごとのredirect_uri制限)を実装。新規抽象は追加せず、既存のresource_type語彙とclient
  registryの構造を再利用。
- **Palm isolation**: DPoP-bound token の Bearer拒否、palm-api
  audience + 非許可client_id拒否、core-next-rp audience拒否を確認・named test化。
- **Implementation responsibility**: PKCE検証はmodelに一元化、coordinatorは委譲のみ。realm
  binding検証もclient registryに一元化(authorize validatorとtoken exchange
  coordinatorはregistryに問い合わせるのみで、redirect_uri比較ロジックの重複はない)。
- **Runtime behavior**: 全ての新規/修正テストはbehavioral(実際のservice/coordinatorを経由)。source
  grepのみの検証には依存していない。
- **DAMP test quality**: 新規テストはsource/target
  surface・artifact・拒否地点を明示した命名。旧来の1テスト複数ケース(PKCE
  malformed)を分割し、攻撃文字種(space/slash/plus/equals/non-ASCII)を追加。
- **Remaining Critical/High**: なし。
- **Remaining Medium/Low**:
  PKCE検証ロジック(`PKCE_CODE_VERIFIER_PATTERN`+`verify_pkce`)が`ClientAuthorizationCode`/`OperatorAuthorizationCode`/`VisitorAuthorizationCode`の3モデルに逐語コピーされている。セキュリティ上の欠陥ではないが、将来の変更時に3箇所同時修正が必要になる保守性リスク。共通concernへの抽出は今回のタスクスコープ外のfollow-upとして記録。
- **Environment/DB blockers**: Ruby
  4.0.6が実行環境に未導入。テスト実行のため一時的に4.0.5へ戻して全テストを実行し、完了後4.0.6へ復元した(最終diffは影響なし)。4.0.6環境が用意され次第、同じfocused
  suiteの再実行を推奨(コード変更はRubyバージョンに依存しない内容のため、結果が変わる可能性は低い)。
- **Separate follow-up issues**:
  1. PKCE verifier検証ロジックの3モデル間重複を共通concernに抽出する(任意、保守性のみ)。
  2. Ruby 4.0.6を実行環境に導入する(CI/開発環境の整備)。
