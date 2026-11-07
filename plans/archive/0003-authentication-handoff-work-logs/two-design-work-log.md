# two.md — 作業1〜3 統合詳細設計書
> Archived snapshot prepared for the 2026-11 handoff; the ignored root original remains in the working tree.


作業文書。zero.md規則6とオーナーの明示指示により日本語で記す。昇格するADR/spec/docsは英語。

> **2026-11-03 オーナー指示による移管:** Preference に関する内容（§1.1 の WU-P0 / WU-7 / WU-9 の行、§2.1 の Preference ADR の行、§3.1 の WU-P0、§3.4 WU-7、§3.12 WU-9、§4、§12.5、§12.7、§12.8 の Preference の行、付録S）は five.md に移した（five.md 付録T に原文を転記）。**本書の Preference の部分は実装しない。** Preference の設計・実装は five.md で行う。本書のそれ以外の部分は従来どおり。

## 0. 入力の固定と再開記録

| 項目 | 記録 |
|---|---|
| 版 | 第0.25版。2026-10-28。ClaudeレビューRV-68〜70と確定版追補の反映版（実装未許可） |
| 要件正本 | one.md第4.2版＋RV-68/69のオーナー承認済み追補（D-58/AC-53）。**Codexは変更しない** |
| 入力SHA-256 | `0347db322f41e5b50d3e1c44219c6ad72af3c595847ef12906c05ad3ccb8dc2b`。今回の実ファイルから再計算。版識別であり承認の代用ではない |
| 入力差分 | 前回入力 `e15f62ecfa356e0aafcfeaf2bb785f99f30b95e81d4df2c241bf092b97725747` → 上記。変更はD-58のOTP進行先行、AC-53の初回競合例外、§13のRV-68/69記録。差分を照合し、Codexによるone.md編集は行わない |
| コードの設計基準 | `b6e7871073bdc43a55fc5f05e8476de8ee71252f`。G-の事実はこのtreeから再確認 |
| 今回のHEAD | `336811e5072a93c0523e484f905082635b28f48f`。基準後の差分は翻訳、Switch検索、ADR、compose等。実装時はHEADの差分を保って適用 |
| 作業ツリー | 読取り開始時、`docs/backlog/2026-10-28-sign-in-attempt-limits-and-switch-limit.md`が未追跡。変更しない |
| 外部基準 | Edge `7437ca5c2847d78ad354ad506817934447a36261`。Jump/Awayのcheckout・実環境は未確認。段階5の実行前に固定する |
| 役割 | two.mdはCodex、敵対的レビューはClaude。three.mdはClaudeの草案で停止中。今回はthree.mdを変更しない |
| 許可範囲 | 今回はtwo.mdのみ編集。one.md、twelve.md、zero.mdは変更しない。アプリ、DB、migration、外部環境、依存関係を変更/実行しない |
| 実装準備 | 採用方式は§4〜6/12、WUの適用票は§3/12・付録F/S。B-01/02は承認済み追補で要件上解決（§11.2）。実装の受入検証・shape/ADR/破壊的操作等の承認は別に残る |
| 固定した旧設計 | twelve.md。SHA-256 `d09a2df4da9068da068bef0ec01a444b820e664ff2a2cbb15cda34f273e0383f`。材料/履歴のみ、本書と矛盾する旧案を実装しない |

**読む順:** §1の順序→§3のWU→§4〜6/12の採用方式→付録F/Sの差分→§7の追跡→§10のQA→§11の残条件。
**レビュー境界（第0.25版）:** one.md第4.2版＋確定版追補のSHA-256を入力と照合し、変更対象をtwo.mdに限定した。本文の【P】は技術提案であり、未証明の箇所を実装可能と断定しない。外部コード・DB・環境はこのレビューで確認・変更していない。
過去の議論・旧案は固定したtwelve.mdで参照する。旧§11〜19の重複転載を本書から除き、現行の採用方式だけを本文に置く。§9.2の原レビューID/判定と§10の参照番号・QA IDは保持する。

- **【確定】** one.mdのD/R/AC。今の契約は第4.2版§0の最新要約、D-53〜59、書き直した§6.2とD-58/AC-53の確定版追補を優先する。
- **【事実G】** 基準コードの静的読取り。テスト成功/実環境での安全性を意味しない。
- **【設計P】** 本書で選ぶ方式・型・処理順・失敗応答。要件を変える権限はない。
- **【実施関門】** 未確認の技術条件、ADR/shape/破壊的操作の承認。要件OQを再び未決に戻すものではない。

### 0.1 第0.21版からの読み替え（RV-63〜67）

| 旧設計 | 現行設計 |
|---|---|
| OQ-1 A、親ごとの並行Auth | D-53 B。ブラウザ/surfaceで進行するceremonyは1つ。同じ手続きの複数タブは可 |
| opaqueマスターキー、BaseだけがDB書込み | D-54。署名JWT。Base/Visaが共通concern経由でDB/cookie書込み |
| experienceに言語、2枚cookie | D-54/57。JWT、language、言語なしexperience、Base host-onlyのbindingの4枚 |
| Visaは表示だけ更新、匿名DBを変更しない | D-55。明示保存済みのaccount項目を匿名行へ反映しDBからcookieを作る |
| sign-outで同意/Web Pushをコピーしない、同意改良を先送り | D-55/57で決着。値とbinding記録をコピー。同意backlogは今回の契約に優先しない |
| Passkey optionsで方式開始 | D-58。署名確認成功かつ適格性確認時。options/失敗/ダイアログ取消では進めない |
| OQ-4/7/11/15/16の回答待ち | D-59で方針決定済み。操作表・HTTP・版の全writer・revocationの実現方式は本書の担当 |
| Switch回数を有限にする | R-AU-42。回数制限は追加しない。親期限/既存rateで制限。BL-26は次サイクル |

## 1. Work Unitと実行順

### 1.1 一覧

| WU | 段階 | 目的 | 先行 |
|---|---|---|---|
| WU-0 | 0 | 基準テストID集合・重要集合・HEAD差分の記録 | なし |
| WU-0R | 0 | 参照データの構築経路、欠落の解消 | 調査は先行可、実変更は0後 |
| WU-P0 | 0/設計 | Preference関連ADRの置換案・shapeレビュー | なし。9の詳細実装前に結論 |
| WU-1 | 0 | realmの境界A、未知値の明示拒否 | 0 |
| WU-2 | — | D-51で廃止。旧APIの一時修正は行わない | 実行しない |
| WU-3 | 1 | **単一WU**でcom route/controller/匿名Base/Warp/realm境界B/participant | 0/1 |
| WU-4 | 1 | 共有参照→com model/job/service/config、health、native push撤去 | 3 |
| WU-5 | 1 | com DBと共有com専用テーブルの削除 | 4、B-5の別途承認 |
| WU-6 | 1 | com撤去のboot・HTTP・重要集合・失敗ID差分の閉鎖 | 5 |
| WU-7 | 2a | comの新Preference、JWT/表示/同意binding/Web Push | 6、P0の必要部分 |
| WU-8 | — | 旧鍵分離のみのWUは撤回済み | 実行しない |
| WU-A1 | 2b | Sentry分類宣言と入口/OTPの停止検査 | 4 |
| WU-A2 | 2b | D-58進行、D-52拒否、Cancel、sign-up片付け | A1、A3との共通SID契約 |
| WU-A3 | 2b | D-53置換、Switch binding状態/一意性、BL-11、purge | 4。A2より先に共通SID契約を設計 |
| WU-A4 | 2b | 跨DB台帳、許可消費順・resource binding | 4 |
| WU-A5 | 2b | Passkey slot/ORG external_id/監査・配送/表示 | A4の対象writer契約 |
| WU-A6 | 2b | ORG Normal/Standby scopeと操作認可 | 4 |
| WU-A7 | 2b | 明示的退会状態、暫定(c)の封鎖維持 | 作業1完了 |
| WU-A8 | 2b | BL-13、Base本人解決、標準RP、停止/復帰、RFC7009 | 4、A7、共有の認証結果契約 |
| WU-A9 | 2b | SignInResult/HTTP、social理由別案内と安全な再開 | A2/A3の必要契約。独立UI差分は先行可 |
| WU-A10 | 2b | 認証情報版の取得/更新/Root再検証 | A4/5の対象writer契約 |
| WU-A11 | 2b | 非Base RPのJump経路 | A8 |
| WU-A12 | 2b | 継続画面の簡素化、Baseから他RPへ展開 | A11、A1/2/3の入口契約 |
| WU-A13 | 2b | 生後1日からの登録、機能側年齢確認のリリース条件 | 4 |
| WU-A14 | 2b | BL-19/22/23、翻訳/属性、残る不具合 | 対象WUのみ |
| WU-9 | 3 | app/org新Preference、Visa sign-in/out、adoption撤去 | 7/P0、A8本人解決、A2/A9の関連契約 |
| WU-X1 | 4 | route/settings/翻訳/N5の整理 | 作業1/3、9完了 |
| WU-X2 | 4 | BL-14/20・Not runの全仕分け/受入 | X1と対象WU |
| WU-E | 5 | Edge/Jump/Away/xt | Rails全体完了、外部基準固定、接続ADR |

### 1.2 依存の根拠と循環防止

| 辺/制約 | 種類 | 根拠/理由 |
|---|---|---|
| 0→0R実変更 | 要件 | 変更前基準を先に採る。例外的先行変更は記録し別の基準を採り直す |
| 1→3 | 要件 | R-RT-3。Aはvisitor受理、Bはcom登録削除と同時にvisitor拒否 |
| WU-3を分割しない | 要件 | R-PREF-1/6/7、R-RT-1/3/4。routeだけ消して匿名化/bootを後回しにしない |
| 3→4→5→6 | 要件 | 共有定数参照を先に外し、DBは最後。D-8/10、B-5 |
| 作業1→A7→A8、4→A8 | 要件 | R-AU-40、BL-13。退会状態の準備とcom分岐除去後 |
| A8→A11→A12 | 要件 | R-AU-32→R-AU-33 |
| P0→9の実装、7→9 | 要件 | R-P-16、D-21 |
| A1/A3共通契約→A2の共有編集 | 共有ファイル | auth_ceremony_admission、coordinator、sign_entry_exit。RV-63の循環を除く。A2/A3の全体完了を相互依存にしない |
| 共通結果設計C→A9-S→A8-S→統合V | 共有ファイル | AuthenticationSequenceGate/失敗応答とRP入口が重なる部分のみ |
| C→A8-I→V、A9-Iは独立 | 共有ファイル | A9全体の完了をA8開始条件にしない。逆向きの辺を置かない |
| A4→A5/A10の重複writer編集 | 共有ファイル | lock/版/監査を別々に壊さない。独立の配送/表示修正は先行可 |
| 4→A2 | オーナー確定の順 | R-AU-43〜49の前倒しをしない。comの欠陥は修復せず撤去 |
| 9の入場 | 契約 | com新方式、adoption ADR、Base本人/操作認可、Visa結果/ログアウト境界。A10〜14全体を待たせない |
| 9＋作業3→X1→X2→E | 要件 | 段階4/5、D-42〜44 |

ReadyなWUから実施できる。実行順の例は0/P0準備→0R/1→3〜6→7とA群→9→X1/X2→E。
設計の合意と、schema/ADR/破壊的操作/外部適用の承認を混同しない。

## 2. コードの起点・差分・ADR

以下は全て基準コミットの静的事実。付録Iの全参照抽出は設計の棚卸しで、実行成功の証跡ではない。

| G | 確認した事実 | 基準ファイル/行 |
|---|---|---|
| G-1 | realm正規化は未知値をclientへ落とす | `app/values/oidc_subject.rb:36-52` |
| G-2 | Browser nonceはBase initiation POSTごとに新規。digestはentry_refも含む | `app/controllers/concerns/base_admission_browser_binding.rb:19-38`、`app/models/concerns/auth_admission_binding.rb:35-41` |
| G-3 | 旧SIDの行をlockして取消し新SIDを作る。active-only検索は終端を返さない | `app/models/concerns/auth_ceremony_session.rb:47-105` |
| G-4 | Cancel handoff/cancelはpending限定、registerとresult発行は予約を一律に見ていない | `app/models/concerns/oidc_authorization_transactionable.rb:154-208,225-294,339-363` |
| G-5 | Switchの最初判定と取消が別。親lockで進行と一体化していない | `app/controllers/auth/app/sign/switches_controller.rb:17-37`、`app/controllers/concerns/sign_entry_exit.rb:22-45` |
| G-6 | RP本人はRPのprincipalへ結び付く。新callbackは独立principalを作る | `app/models/rp_base_app_identity_binding.rb:11-20`、`app/operations/rp_callback_committer.rb:92-99` |
| G-7 | 標準RP要求は署名とlocal sessionから認証する | `app/services/rp_request_authenticator.rb:41-85` |
| G-8 | OIDC subjectの正準表現は型prefix＋本人の参照 | `app/values/oidc_subject.rb:13-34` |
| G-9 | Preferenceの現在JWTは旧claims/鍵解決、rowにjti等、単回/DBSC concernあり | `app/values/security_jwt_preference_token_codec.rb:12-35,126-149`、`app/models/app_preference.rb:49-89` |
| G-10 | 旧sign-outは新行/表示copy/旧行退役、同意copyなし | `app/controllers/concerns/preference_sign_out_rotation.rb:49-51,84-105,121-149` |
| G-11 | Cookie子行は同意booleanをfalseで作る | `app/controllers/concerns/preference_base.rb:136-147,165-175` |
| G-12 | account同意mirrorがある | `app/controllers/concerns/preference_resource_sync.rb:90-101` |
| G-13 | 名前/通知変更はOP外側→Z内側、登録確定はZ外側→OP内側 | `app/operations/identity_passkey_name_committer.rb:11-32`、`identity_email_preference_committer.rb:14-22`、`identity_passkey_registration_final_committer.rb:63-67,133-166`（後2つもapp/operations内） |
| G-14 | socialの完成はZでidentityとClient verifiedを記録する | `app/operations/social_auth_signup_finalizer.rb:18-67` |
| G-15 | Email/電話の登録完成はZ actor lock内、電話はPasskeyも確認 | `app/models/client.rb:392-430`、`app/operations/sign_app_up_telephone_registration_finalizer.rb:46-67` |
| G-16 | Secret jobはFlow先行でcomplete/terminateを選び、complete入口はFlow completed必須 | `app/jobs/client_secret_lifecycle_job.rb:89-104`、`app/operations/client_secret_passkey_reservation_issuer.rb:12-70,183-211` |
| G-17 | 登録complete後、通常sign-inへ合流しMFA/上限/期限も扱う | `app/controllers/concerns/sign_up_sequence_controller_support.rb:255-291,608-669` |
| G-18 | L1/L2は内部で区別、release/競合も同じconflictに集約 | `app/services/social_auth_login_handler.rb:23-51,59-75,102-104`、`app/controllers/concerns/social_auth.rb:404-445` |
| G-19 | 現RP logoutはlocal session/cookieを先に終了してOPへ移動 | `app/controllers/concerns/oidc_rp_logout_launcher.rb:31-65` |
| G-20 | `/revoke`側の取消操作はclient認証・refresh検証後にRP sessionを取り消す | `app/operations/oidc_token_revoker.rb:25-29,73-89` |
| G-21 | AuthのPasskeyはRP ID/originを固定し、RP IDはorigin hostと一致 | `app/values/webauthn/relying_party_config.rb:28-44,59-68` |
| G-22 | Email既存/dummy経路、OTP cooldownは登録有無を区別させない | `app/controllers/auth/app/sign/in/emails_controller.rb:119-123,354-383` |
| G-23 | 旧HTTP social試験はL1/L2同一応答を期待 | `test/integration/social_login_admission_test.rb:488-511` |

### 2.1 ADRの処理（今回ファイルは変更しない）

| ADR | 現契約との関係 | 担当 |
|---|---|---|
| `adr/sign-up-flow-admission-binding-and-cardinality.md` | HEADでD-53 Bへの改訂済み。基準時のAは実装の根拠にしない | A3 |
| `adr/preference-relogin-reconciliation-record-recency.md` | Acceptedは双方向/記録全体のrecency。D-50/54/55への置換候補。明示項目の一方向反映へ | P0→9 |
| `adr/preference-extended-option-reference-tables.md` | 子record/option FK維持。Web Push追加、adult gate休眠、旧prefix撤去を追記候補 | 7/9 |
| `adr/preference-browser-transport-family-capability.md`、`adr/preference-credential-entry-recovery.md` | 署名/更新者/不正JWTの扱いを新契約へ改訂候補 | P0/7/9 |
| `adr/passkey-current-state-limit-and-chronicle-outbox.md` | D-39のDB上限/slotと旧application-only制限の差。監査outboxは維持 | A5 |
| `adr/root-login-establishment-boundary.md` | Rootのみsuccess、cooldownと上限は維持。evidenceを成功扱いしない | A2/A9/A10 |
| `adr/idp-flow-lifecycle-vocabulary.md`、`adr/sign-in-first-and-sign-up-handoff.md` | D-58/Cancel/置換の条項差を改訂候補、登録→sign-in維持 | A2/A3 |
| `adr/app-com-withdrawal-deadline-snapshot.md` | 暫定(c)、明示退会状態へ。目的別保証の拡張は次サイクル | A7 |
| `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` | RP取消とOP全体SSOを分離。D-59 RFC7009を追記候補 | A8 |
| `adr/sign-up-one-day-minimum-age-and-feature-level-age-restrictions.md` | HEADでAccepted。判定日/機能別責務を守る | A13 |
| `adr/jump-directed-rails-handoff-contract.md` | com匿名とJump/Away別の許可、戻り先検証 | A11/A12/E |

one.mdの確定によりADRのファイルが自動的に改訂済みにはならない。条項差はP0/各WUで具体的な改訂案にする。
コードに合わせて要件を弱めず、既存ADRとの衝突はzero.mdに報告する。

## 3. WUごとの実装定義

### 3.0 全WUに適用する実行契約

目的/R/ACの全件対応は§7。各WUはこの節の変更と§4〜6の該当処理を一体で実装する。
ファイル群は`{app,org}`等を展開した各実ファイルを指す。新規名は【P】であり存在する事実ではない。

- FQDN→サイズ/rate→CSRF/Origin/Fetch Metadata→読取りによる対象/状態判定→認可→副作用の順を、既存のsurface契約に沿って保つ。安全な拒否判定より前にrefreshやsession掃除をしない。
- 各stateの書込みは1つのnamed transition writer、owner DB時計、lock/reload/期限再確認で行う。actor/FlowをNULLで分類しない。
- 各WUの検証は公開HTTP/operation/jobの正常・拒否・他owner・期限直前/一致/直後、別接続で両commit順を固定する。時間待ちsleepで競合を祈らない。
- 参照データ/環境構築はMinitest/Vitestを追加せず実施結果をevidenceへ。今回は全て**実施計画**で、アプリを起動しない。
- migrationはgenerator→migrationのみでDDL→生成schema差分→drift検査。過去migrationを書き換えず、データ変更とschemaを分離。DB行数/削除件数は実測前に0と書かない。
- 破壊的操作は「DB/表/列、全行数と対象行数、lock時間、バックアップ識別子、復元手順/所要時間、復元不能な外部通知」を実行票に揃え別途承認。D-12の使い捨て前提だけで削除を開始しない。
- 新schema/JSON/API shapeは本書Before/Afterをレビューし、実装前にshape承認を得る。これは今回の文書作成を止める条件ではない。
- 変更時に対応する`docs/mermaid/idp-*.mmd`とtransition inventory、checklist、現行docsを同時更新。過去evidenceを改変しない。

### 3.1 WU-0 / WU-0R / WU-P0 / WU-1

| WU | ファイル/実施内容 | 不変条件・検証・承認 |
|---|---|---|
| 0 | コード変更なし。**D-34の基準コミット`b6e7871073bdc43a55fc5f05e8476de8ee71252f`**で`bin/rails test`を1回実行し、失敗/skip/削除のテストIDと重要集合（認証/route/Membership/Avatar/Preference）をevidenceへ記録。基準treeとは別に今回HEADとの差分・未追跡ファイルを固定 | 基準コミットの実行結果とHEADでの結果を混同しない。基準の件数だけで判定しない。過去の約400失敗を今回の実測として扱わない。環境不足はfailedでなくblockedと記録。基準checkoutとHEADでDB/設定が異なる場合も別記する |
| 0R | `db/*_migrate/`の参照値と構築経路、`db/seeds.rb`と既存seed呼出し、cleanup state参照model。必須の参照行をmigration後/再構築後に同じ定義から用意 | 調査は0前可、DB投入は0後。application modelをmigrationで参照しない。欠落時の誤った翻訳例外もA14で修正。件数/回復を記録して投入 |
| P0 | 上記Preference ADR群と`docs/architecture/preference.md`の改訂案。第4.2版への条項別対応を提示 | 既存Acceptedのadoptionを黙って消さず改訂をレビュー。7でcomのみ新方式、9でapp/orgのadoptionを除去 |
| 1 | `app/values/oidc_subject.rb`、`app/values/oidc_client_registry.rb`の正規化/推論。型ごとの明示case | nil/空/未知拒否。client/operator/visitorと許可別名の代表を受理。BL-13で撤去予定の`OidcAccessTokenAuthenticator`/`OidcRpIdentityProvisioning`は直さない。schema変更なし |

### 3.2 WU-3 — com匿名化とroute/controllerの一体撤去

- 対象: `config/routes/{base,auth,visa,core,warp}.rb`、host制約、static client/realm registry、`app/controllers/{auth,visa,core}/com/**`、対応view/helper/policy/test。Base comの全controllerは付録Eに1ファイルずつ処置を書く。
- `Base::Com::ApplicationController`はprincipal解決/認証/認可/withdrawal/admission/session-limitを外す。`ActorSupport`を丸ごと外してlocalizationまで壊さず、匿名`Actor.preferences`構築と要求終了時clearを専用の明示メソッドで行う。
- com rootは既存layoutで簡素なPreference入口のみ。`preference/emails`とBase com JWKSは撤去、screen/PWA/offline/表示設定/APIを維持。新しい商品コンテンツは足さない。
- Warp comは既存の公開read-onlyページとhealth/robots等を残し、sign-in/out/callback/BCL/認可要求のroute、RP cellの使用を外す。公開内容が認証modelを読んでいる場合は静的表示へ勝手に変換せずページ単位の削除候補を示す（§11）。
- Warp comの画面別処置【P】: `roots#index`は匿名landingのまま、`logged_in?`での404分岐とsign継続linkを削除する。`settings#show`は既存の匿名shellを維持し、RootとBase comのPreferenceへの固定許可linkだけにする。認証済み限定`dashboards#show`とそのpageはroute/controller/viewを撤去し、公開dashboardへ転用しない。sign/oidc/JWKS、Warp側Preference cookie/theme GET/PATCHのcontroller/routeも撤去する。health/revision/robots/sitemap/CSP/PWAの公開経路は維持。共有`WarpDashboardPage`/`WarpSettingsPage`をcomの動的helper呼出しに使わず、app/org向けは保持する。WU-7後のWarp comはJWT公開鍵readerだけでsetting DB接続0、保存案内はBaseへ。
- 【事実G-28】基準`app/controllers/warp/com/roots_controller.rb:14-19,29-38`は匿名landing＋Settings/認証開始link、`dashboards_controller.rb:15-20`はlogin/authorize必須、`settings_controller.rb:11-13`は匿名shell。上記はこの事実を踏まえた画面ごとの設計で、個人向け画面を匿名化する判断ではない。
- realm境界Bでvisitor/customer/com clientを拒否するのと、static com登録/OP participantの削除を同時に行う。Publishing audienceのCOMは維持。
- com Preferenceはこの時点では旧transportのまま。com actor-localのみ削除し`ComPreference`/Chronicle/旧binding/DBSC関連は7まで必要な分を残す。
- 検証: unknown hostと削除pathは既存404、匿名Preference全画面/index/reset/API/overlay、RP cookie注入で結果不変、接続先はcom_settingとChronicleのみ、CSRF/Origin/Fetch Metadata、app/org audiencesと重要集合。
- docs: surface/routing inventory、匿名hydration、comの軸の図/登録削除。DB削除は行わない。E-1aの詳細は付録E。

### 3.3 WU-4 / WU-5 / WU-6

| WU | ファイル/処理 | 完了条件と実施関門 |
|---|---|---|
| 4 | 付録Iの共有job/service/registryからcom認証参照を外してからVisitor/com認証modelを削除。`Health::Profiles::{Com,SignCom}`、health呼出し、`Gemfile`/lock、`config/push.yml`、`config/initializers/action_push_native.rb`、`ApplicationPush*`、OutboundChannelSuspensionとFlipperのpush項目 | eager load/公開job操作でapp/org維持。ComPreference/Chronicle、Info/Help/Docs/News、Publishing COMを消さない。gem設定は実行確認でevidence、環境テストを作らない |
| 5 | `config/database.yml`、CI/health/registryからcom_setting以外のcom接続を削除。新規migrationで共有のcom専用表・AvatarIndividualBindingのcom参照、native push表を撤去 | 各dev/test DB、共有表の実測行数とsnapshot/復元手順を揃えB-5承認。dropping migrationとdatabase dropを分ける。共有Chronicle/Avatar全体を消さない |
| 6 | AC-1〜12/35とcom参照の再抽出、test-ID差分、route/eager load、保存とcontext cleanupを集計 | 削除/skipした試験も全件理由。回帰1件でも未完了。実測接続/DB削除を記録。段階1の比較を閉じてから横断route整理へ |

削除の回復は、変更前checkout＋そのDBのsnapshot＋参照値を同じ版で復元する。旧comアカウントの新方式への移行は作らない。

### 3.4 WU-7 — com Preference新方式

- 改修: `app/controllers/base/com/preferences_base_controller.rb`とpreference/API controller、`preference_{global,transport,base,core,localization,web_cookie_endpoint,web_theme_endpoint,resource_sync}.rb`、`PreferenceIoKeys`/registry、`SecurityJwtPreferenceTokenCodec`、`ComPreference`と子record/option。
- 新規【P】: `app/controllers/concerns/preference_write_boundary.rb`、`app/values/preference_display_value.rb`、`app/values/preference_write_result.rb`、`app/operations/preference_lifecycle_purger.rb`、`app/jobs/preference_lifecycle_job.rb`。controller concernが共通の唯一のDB/cookie書込み入口を持つ。既存動的dispatchをコピーしない。
- §4のschema/JWT/4cookie/GET契約をcomで完成。Base以外のcom readerは公開鍵で読むだけ。秘密鍵のruntime roleによる切替を足さない。
- `__Secure-assurance`、旧項目cookie、Preference refresh/DBSCをcom分岐から削除。app/orgが使う共通分岐は9まで保持し、新旧同じrealmの互換実行は作らない。
- 保存/index/formは既存画面を保つ。screenのdispatchは閉じた列挙と同じ保存メソッドへ。Web Pushのoption/子record追加のみ、配信やsubscriptionは実装しない。R-P-24/26のcom側の再棚卸しを同WU内で行い、§4.3の列単位Before/Afterを承認対象にする。
- 検証: §4全表、realm6方向のうちcom↔app/orgの受理拒否、same-TLD reader、GET先読みでDB0、書込み不正JWTでdefaults新行、**resetの旧行退役＋新行作成**、D-57 cookie tossing、400日期限。DB構築/鍵配布の実施は別途承認。
- docs: Preference architecture、transport capability、option ADR、schemaと状態図。migrationの列変更/データ破棄は§3.0の実行票。

### 3.5 WU-A1 — Sentryと分類

- `Auth::{App,Org}::ApplicationController`、`sign/{ins,ups}_controller.rb`、`web/v0/in/email/otps_controller.rb`、`sign/oidc_handoffs_controller.rb`、`auth_ceremony_admission.rb`、既存SignEntrySentry関連を対象。
- D-59の宣言は`sign_entry_classification`の閉じた4分類（sign_in/sign_up/parent_intent/excluded）。controllerに静的宣言、action overrideは固定表。excludedには理由文字列を必須にし、未宣言を除外にしない。
- 通常入口/OTP resendは停止検査→Admission消費/rotation→表示/送信。parent_intentは検証済み親だけから分類、paramsを根拠にしない。handoffは結果登録の継続としてparent_intentに分類し新規送信の停止ルールと混同しない。
- Standby専用入口は確認済みの例外として宣言し、通常Sign In停止でも既存のStandby検証からRootまで可能とする。外部から`emergency=true`で切り替えない。
- routeの全reachable actionと宣言の差集合をstatic guardで0にする。期限前/一致/後、添付/確認済みAdmissionの両方で停止時に消費/OTP世代/送信0。schema変更なし。

### 3.6 WU-A2 / WU-A3 — 共通の確定境界

- A3: `auth_ceremony_session.rb`、`auth_ceremony_admission.rb`、`base_auth_admission_coordinator.rb`、`auth_admission_binding.rb`、`sign_entry_exit.rb`、app/org switch controller、admission purger。
- A2: `oidc_authorization_transactionable.rb`、`auth_email_otp_challenge.rb`、`authentication_base.rb`、`sign_in_path_refusal.rb`、`sign_in_phase_binding_controller_support.rb`、`sign_up_flow_entry.rb`、`org_normal_sign_in_transaction.rb`、cancel controller、Visa limitations、social/Passkey開始/検証、sign-up finalizer/cleanup/Secret job。
- 共通SID/対象/lockの設計を先に固める。§5を実装し、A3全体→A2全体→A3全体の循環を作らない。
- 変更する状態軸: ceremonyの開始/終端/置換、bindingの生存/Switched、OIDC親のauthenticatedからのCancel。全てreference state/transition writerに集約。Switch前bindingに明示終了を付け、親ごとの生存binding partial unique。回数上限を追加しない。
- 方式画面にCancel、通常のsign-up→sign-inリンクを削除。進行前のSwitchはCSRF付きの対象明示操作。socialの許されるBack/再送はR-AU-49と§10.7に限定し、成功Flowを巻き戻さない。
- 検証: AC-40/50/51/53、§5の全競合/未達/再送、registered account＋OP未完了のCancel後のSecret job、FlowなしEmail/印なしSecretのBack、Auth DBSC header非発行。
- schemaは付録S、完成履歴は§12.4、初回Admissionの例外と到達拒否は承認済みAC-53追補/§11.2。通常経路の方式を新しい要件OQへ戻さない。

### 3.7 WU-A4 / WU-A5 — 書込み順・Passkey

- A4は§6.1の全操作台帳を実装の差分と照合する。`identity_*_committer.rb`、`client_secret_{name,storage_confirmation}_committer.rb`とSecret取消、`sign_app_up_telephone_registration_finalizer.rb`、signup/retention/Enforcementを対象。
- actor/対象をZでlockし入力/所有を確認→OPでdevice/token/proofをlock/再確認/消費commit→Zの変更/監査commit。`resource_ref`は当該対象の不透明な参照を必須とし別対象へ流用不可。
- A5はClientPasskey/OperatorPasskeyに`slot`（NOT NULL、1〜10、owner+slot UNIQUE）を置く。保持中の全行がslotを占有し、soft revokeだけで再利用しない。物理削除後だけ解放。
- `identity_passkey_registration_final_committer.rb`とORG controller/committerはexternal_idを一貫使用。`public_id` aliasを作らない。row構築と監査outboxを同じZ transactionで必須にする。
- `app/jobs/passkey_audit_delivery_job.rb`と既存の配送operationは失敗事実を残して後続を進める。古いpoison1件のためbatch全体を先頭から繰り返さない。page checkpointで先へ進み、失敗は既存再試行/監査に残す。
- Activity Logは空履歴と読取り障害を明確に区別。`docs/operations/passkey-runbook.md`、slot/credential lifecycle図、迂回writer guardを更新。
- 試験: slot0/1/10/11、同owner重複/別owner再利用/soft revoke/物理削除、直接INSERT、監査欠落rollback、前後のDB障害、poison後続配送、Activity Log障害。slot backfill対象行数/既存11件以上の処置/回復を実測し承認する。勝手に既存鍵を消さない。

### 3.8 WU-A6 / WU-A7

- A6: `AuthenticationContextValue#constrain_scopes`とORG発行/認可policy、Standby/Normal controller。scopeをNormalと同じにし、操作のStep-Up要求で制限する。`docs/security/org-emergency-access.md`を更新。policyから列挙した全操作でNormal/Standby比較、Entraを無効化しない。
- A7: `app/services/withdrawal_lifecycle.rb`、`app/models/concerns/withdrawable.rb`、Client/Operator、withdrawal/privacy writer/guard。§6.3のstatusを導入しNULL/時刻から状態を推測しない。
- 暫定(c)は維持。回復のactor/目的/期限を再検証してもRootを出さない。privacy依頼は書込み/外部通知/job/occurrence0で拒否。目的別の新規の不可逆操作は次サイクル。
- migration: actorのNOT NULL state/reference、期限の明確化。旧データの状態を時刻で決めるのは移行の一回だけで、曖昧な行は一覧にして勝手に有効化しない。件数/復元とowner承認。
- A7はA8より先。認可/code交換/refresh全てでBase以外への退会中tokenを拒否。ORGは独立operator手続き。

### 3.9 WU-A8 — OP-chain撤去と本人/ログアウト

- `browser_rp_authentication.rb`、`oidc_callback.rb`、`oidc_rp_logout_launcher.rb`、`core_browser_api_boundary.rb`、`actor_support.rb`、`RuntimeRole`とその全call site、RP cellの各controllerを対象。
- `RpRequestAuthenticator`を全RPの入口に揃え、JWKS＋RP自身のsession/identity bindingを使用。OP tokenやBaseのsessionを別RPのcredential fallbackにしない。
- Baseのみ、検証済みRP identityのiss/subから§6.4のZenith resolverを使い、本人を解決する。管理対象はそのactorのassociationから限定し、必要なStep-Upを別途認可する。RP local principalの数値IDをClient/Operator.idにしない。
- `Core*Bridge`は実際の全readerを再検索してからmodel/操作と表を撤去。OP-chainの代わりに新認証APIやOP DB joinを足さない。
- §6.5のRPローカルlogout→RFC7009→OP全体の確認を実装。`/revoke`既存endpointと登録済みclient認証を使う。local BCLは登録origin/path/portだけ、SSRF例外を一般化しない。
- 試験: `UMAXICA_RUNTIME_ROLE`なしboot、全RP sign-in/要求/refresh/sign-out、別issuer/同sub/別realm、URL/form actor差替え、期限切れ/失効session、停止→復帰の旧JWT、Base Preferenceと全管理操作の他owner拒否。
- `/revoke`のsession影響範囲は§6.5と§11で明示。外部接続の実施は別途。docsはBrowser RP/セル/ログアウト/BCL、ADR改訂案、RP stop図。

### 3.10 WU-A9 / WU-A10

- A9は`authentication_sequence_gate.rb`、`SignInResult`、social callback/handler、ORG Entra/Standbyの結果adapter、form/API/継続view。§6.6の公開HTTP表を共通結果へ対応付ける。内部結果のsuccessの意味を増やさない。
- social L1/L2をtyped reasonとして伝える。provider本人確認とstate/nonce/ceremony照合後だけ理由を出す。release/停止/未完了/障害を未登録と呼ばない。OTP宛先入力だけでは列挙させない。案内先は新しいRP起点の要求で、失敗evidenceを再利用しない。
- A10はClient/Operatorの`credential_version`（仮名、bigint NOT NULL、初期1）と全credential writer、verification/evidence、Root/refresh入口。§6.7のsnapshot方式を使う。
- evidence capture後にcredential/連絡先/管理変更が入った場合、Root/refreshを拒否し古いevidenceを再利用できなくする。`authentication_epoch`と兼用しない。
- docs/図はsocial callback/refusal、Credential version/evidence/Root。actor列追加/移行はshapeと件数/回復の承認。

### 3.11 WU-A11 / WU-A12 / WU-A13 / WU-A14

| WU | ファイルと処理 | 検証/同時文書 |
|---|---|---|
| A11 | `JumpRtReturnPolicy`、非Base RP sign entry、url/pt/rt生成。same-originはpath、別originはJumpの既存registry辺だけ | app/org各RPからAuthまで。query漏えい/二重エンコード/任意host拒否。Jump contract更新 |
| A12 | `base/shared/authorization_exit_continuation.html.erb`とhandoff controller、他RPのcontinuation。Baseで完成した簡素な経路を展開 | no-referrer/null Origin問題を既存のstrict-origin候補で解消。ref/nonceをRefererへ出さず、Origin checkを緩めない。CSRF確認が必要なPOSTをGETにしない |
| A13 | `SignUpEligibilityPolicy`/`HasBirthdate`、app/org登録controller、文言/locale、signup eligibility docs。**案P:** app/orgの双方に「サービス日付より少なくとも1日前」の明示判定を置き、ORGの招待/資格判定と独立にANDで適用。従来の16歳表記と年齢不足HALTEDの分岐を、今日・未来日付の拒否へ置換し、他のHALTED理由は維持 | 昨日/今日/明日、日付切替前/一致/後、ORG招待有/無。今のORG分岐でArgumentErrorにならないことと、拒否が別の年齢基準にfallbackしないことを確認。年齢依存機能の一覧確認は本番前条件。adult gateを復活させない |
| A14 | `suspended_notice`未使用、BL-23の当該host既定値、R-AU-46属性翻訳、BL-19候補を個別に分類 | 一般ENV全置換はしない。HEADで直ったBase org翻訳/N+1は再実装せず回帰を確認。BL-19各件のコード根拠と公開試験を残す |

### 3.12 WU-9 — app/org新方式とVisa

- 7の方式をAppPreference/OrgPreference/ClientPreference/OperatorPreferenceへ展開。`Visa::{App,Org}::AuthorizationBaseController`とlogout確定処理が§4の**同じconcernメソッド**を呼ぶ。
- sign-inは本人明示項目だけをaccount→匿名行へ、sign-upも既存handoff→同じVisa経路。sign-outは旧匿名行の表示/同意/Web Push/bindingを新匿名行へ写す。cookieからDBへのコピーは禁止。
- Base本人resolver/操作認可はA8の完成契約を使う。account値をrequest actor_idやcookie subから選ばない。
- `PreferenceAdoption`と旧refresh/DBSC/assuranceとitem cookie群、actor同意mirrorを撤去。`adult_content_gate`のモデル層外参照/registry/stopperをまとめて外す。モデル/option/子表の休眠は維持。
- explicit metadataを新しい一方向保存/反映に使用し、saveで送られていない項目をaccountへ埋めない。地域だけ固定4項目を伴う。地域そのものをVisa sign-inで匿名行へ反映することはしない（D-50）。
- R-P-24/26のapp/orgのlegacy class・table・NULL状態/nullable booleanを各実ファイル/列で再棚卸しし、Sharedとactor-localの正規の子recordだけを残す。D-27の休眠modelと他realmの参照表は誤削除しない。実表/NULL列とAfterは付録S、migrationは§12.8のshapeレビュー対象。
- §4の失敗表/同時保存/retire/response順/D-57、**resetでの旧匿名行退役・本人設定退役・共有3cookie再発行と旧binding cookie破棄**、AC-20b〜37/49/52を3realmで閉じる。migration/既存値の消去はapproval票。新方式のADR/diagram/checklistを同時更新。

### 3.13 WU-X1 / WU-X2 / WU-E

- X1: `config/routes/{base,auth}.rb`のORG configuration→settings、controller/view/helper/links/testsを一括改名。旧URL aliasを作らない。Base com残存翻訳guard、N5のauthority規則、database_consistencyは変更表のみを対象。
- X2: 前サイクルNot run166件を一つずつ「合格/失敗/未実施/撤去により不要」にし、テストID/実行結果/理由を残す。未受領tmp資料は入手前に完了扱いしない。全失敗修復BL-18は範囲外。
- E: Edge/Jump/Awayの基準SHAとファイルをcheckoutの読取りで固定→接続ADR/registry差分→owner承認後に実装。comの公開ページ/匿名Preferenceとの役割を保持し、勝手にRails Base comのDNSを変更しない。
- xtはAwayを経由する独立の許可、rtはJumpの許可。どちらも完全originと許可edgeで検査。外部repoの具体パスは未取得なので捏造せず、§11で実行関門にする。

## 4. Preferenceの横断詳細設計

### 4.1 所有・Cookie・署名

| Cookie | 内容 | 属性/書ける主体 |
|---|---|---|
| `__Secure-preference` | 表示値を含む署名JWT | Domain=`umaxica.<realm>`、Path=/、Secure、HttpOnly、SameSite=Lax。Base/Visa共通write入口のみ |
| `language` | 言語option名1個 | 同Domain/Path/Secure/SameSite、JS可。JWTと同じDB snapshotから発行 |
| `__Secure-experience` | 言語を除く表示JSON | 同Domain/Path/Secure/SameSite、JS可。JWT/認可の代わりにしない |
| `__Host-preference_binding`【P名】 | 32byte CSPRNGのbase64url乱数 | Domainなし、Base hostのみ、Path=/、Secure、HttpOnly、SameSite=Lax。Baseの同意/Web Push保存だけで発行 |

3枚の共有cookieの寿命は書込みDB時計から400日。binding cookieも【P】Base保存時から400日、GETで延命しない。
Visaはbinding cookieを発行/変更できず、bindingのDB記録だけをsign-out時にコピーする。
Base/Visa以外は公開鍵だけでJWTを検証し表示。公開JWKSを追加せず、realm別公開鍵集合をrequired設定で注入する。
署名は【P】ES384/P-384固定（基準`lib/jit_security_jwt_jwk.rb:10-11`と同じalgorithm/curve。鍵はrealm別に新設）。alg/kid/iss/audを閉じた定義から検証、kidをURLやファイル名へ展開しない。
秘密鍵は既存の管理された秘密設定からBase/Visaの経路だけが使う。実装の鍵供給方式と配布/切替は§12.7。鍵の実値・環境への配置は今回未確認。
JWT/cookieの大きさは【P】1枚3KiB以下を設計上限、文字列/enum値はoption allowlist。超過はerrorで発行せず既定表示へ。

### 4.2 shape（実装前レビュー対象）

Before: 旧JWTの`public_id/preference_type/host/scope/client_id/nbf`と項目cookie、refresh/DBSC。
After【P】:

```json
{
  "header": {"alg":"ES384", "kid":"realm-key-version", "typ":"JWT"},
  "claims": {
    "iss":"https://www.umaxica.app", "sub":"anonymous-row-public-id", "aud":"app",
    "iat":0, "exp":34560000, "jti":"random-generation",
    "preferences": {"theme":"system", "language":"ja", "timezone":"Asia/Tokyo", "currency":"jpy",
      "date_format":"iso", "time_format":"hour_24", "motion":"standard", "density":"standard", "page_size":"20"}
  }
}
```

このJSONはshape説明例でありseed値ではない。実装では付録Sの既存optionのnameをそのままwire値にし、`system`/`hour_24`を例から新設しない。`iat=0`は相対例で、実発行はDB時刻のNumericDate。
JWTのissuerはrealm内でBase/Visa共通の固定識別子（上例）を使用。アカウントID/同意/地域/Web Push/OIDC sidを入れない。
`preferences`は独立項目でtupleではなく閉じたキーのobject。JSON experienceは上のpreferencesからlanguageだけを除く。
不明キー/不正型/重複cookie名の曖昧入力は信用せず明示errorへ。JWT値からDBを作らない。

### 4.3 DBのBefore/After

| 対象 | Before（G-9等） | After【P】 |
|---|---|---|
| App/Com/OrgPreference | public_id/jti、SingleUseToken/DbscBindable、used_at等のNULL/infinity分岐 | public_id UNIQUE NOT NULL、jti UNIQUE NOT NULL、status_id NOT NULL（active/retired、既存referenceを更新）、last_issued_at/last_issued_expires_at NOT NULL。purge期限はexp＋猶予から計算し重複列を追加しない。旧token digest/DBSC/binding method/single-use状態を撤去 |
| 表示子record/option | 既存option FK、各prefix | 維持。閉じたoptionと1親1子のunique/FKを保証。NULLが状態を表す列を撤去 |
| account Preference | snapshot/explicit metadata、同意mirror | 表示/地域と項目ごとのexplicit metadata。NOT NULL。ブラウザ同意/Web Push/bindingは置かない |
| binding | なし | realm setting DB内`*_preference_browser_bindings`。preference_id FK/UNIQUE、digest NOT NULL。行がなければ未結合。digest NULLで未結合と表現しない |
| Web Push | なし | `*_preference_web_push_options`（enabled/disabled）、`*_preference_web_pushes`（preference_id FK/UNIQUE、option_id FK/NOT NULL） |
| adult gate | 既存model/option/子表 | モデル層のみ休眠、外部registry/参照なし |

bindingはcopy元/先の2匿名行が一時的に同じdigestを持てるため、digest自体はUNIQUEにしない。
stateはnamed writerだけが変更し、retiredはactiveへ戻さない。timestampをNULL/infinityかどうかで分類しない。
旧データは未デプロイ前提で互換移行しないが、削除/再作成の件数と回復は実施前に承認する。
- **R-P-24/26の処置:** 付録Sを列/表の差分の起点とする。匿名側のNULL運搬列を撤去し、actor-localは表示の子record/optionを正規の保存先に統一、親の表示重複列・同意mirrorを撤去する。`explicit_fields`はNOT NULLの閉じた配列、退役はreference状態で表す。`adult_content_gate`のmodel/option/子表はD-27により維持する。実データの件数/移行値は承認票で測り、旧backlogのUser/Staff/Customer名やDB配置を転記しない。
匿名modelでは`Retainable`/`SingleUseToken`/`DbscBindable`/匿名用`PreferenceExplicitFields`、`expires_at→discard_at` alias、replaced_by/binding_method/dbsc associationとそのcallerを同じWUで外す。新規Pの`app/models/concerns/preference_lifecycle.rb`に、各realmの明示referenceを使う`retire!`（active→retired）、発行snapshotの確定、purge可否の読取りを置く。retired→activeはない。共通concernにcallback hook/動的class解決を追加せず、各modelでassociationとreference classを静的宣言する。resetは共通write入口で退役＋新行を作り、旧resettableのsingle-use/DBSC処理へ戻さない。子recordと監査/holdの参照はpurge前に確認し、期限だけで監査履歴を削除しない。
新しいmodel/columnは全てmigrationに定義し、生成schemaを手で編集しない。

### 4.4 共通write入口（D-54/AC-24）

`PreferenceWriteBoundary#write_preference!(operation:, actor:, submitted:)`【P】をBase/Visaが呼ぶ唯一のconcernメソッドとする。
operationはsave/sign_in/sign_out/resetの閉じた列挙。actorは検証済みサーバーcontextだけで与え、request値から選ばない。
署名codecは鍵/claimsだけ、modelは状態/所有、concernはrequest/cookieとtransaction順を所有する。新しい汎用service層は作らない。

**共通の処理順（Z→Sのcommit順、S lock、HTTP cookie発行を混同しない）:**

1. 既存のCSRF/Origin/Fetch Metadata・対象surface・当該親/本人の認可を確定する。VisaのOIDC継続は既存の検証済みhandoff/親と結び付け、一般GETをwrite起点にしない。GETをPOSTへ置き換えるだけでprompt=noneや既存response_modeを破壊しない（§12.5）。
2. JWTの署名/alg/kid/iss/aud/exp/閉じたshapeを**DB write前**に検証し、要求されたoperation/明示入力を検証する。この段階ではS行をlockせず、有効性はまだ仮判定とする。表示readで古いjtiを許すこととwrite認可は分離する。
3. Baseの本人`save`または`reset`では、認証済みactorをZでlock/照合し、許可された項目の変更またはactor-local Preference退役を**先にZでcommit**する。S行のlockを保有したままZ actorを取得しない。Z成功後にSが失敗した場合は部分成功を記録して保存成功としない。Base匿名saveではZ書込0。Visa `sign_in`はZのexplicit値を読取り専用でsnapshot取得し、Visa `sign_out`は既存認証のsign-outをPreferenceとは独立に先に確定する。
4. **その後にS transactionを開始**し、JWTの`sub`が指す行をlock/reloadし、active/jti/期限/realmを再確認する。全て一致した場合だけ既存行を更新対象とする。不正/欠損/期限切れ/古いjti/retired/不存在なら参照先を一切更新せず、**既定値の新行**を作る。旧JWTの表示値・同意・binding・Web Pushをseedしない。
5. `save`は明示項目（regionの場合のみ固定4項目も）、`sign_in`はZのexplicit表示項目だけ、`sign_out`は有効旧匿名行の**DB**表示/同意/Web Push/binding、`reset`は新行の既定値を扱う。`sign_in`は未明示の匿名行項目を変えず、region自体を反映しない。`sign_out`は新行作成＋旧有効行のcopy＋旧行退役を**同じS transaction**で確定。`reset`も旧有効行を退役させ新行を作る。無効JWTが指す行は`sign_out/reset`でも変更しない。
6. 同じS transaction内でnamed writerの変更、新規jti、DB snapshot/発行時刻の確定、JWTの**署名完了**、`language`・`__Secure-experience`の**全量生成**を行う。同意/Web Pushの保存で新しいbindingが必要なら、乱数生成とdigest保存もここで完了する。署名・鍵取得・生成失敗ではS transactionをrollbackする。commit前に`Set-Cookie`を一枚もqueueしない。
7. **S commit成功後だけ**同じsnapshot/expの共有3枚をresponseへqueueする。D-57のBaseの保存で新bindingを発行する場合は事前に確定した4枚目もqueueし、`reset`では古いhost-only binding cookieを削除する。Visaの`sign_out`ではbinding cookieに触れない。commit失敗ならcookieを発行・削除しない。headerへのqueue失敗・応答未達・ブラウザ到達はDB transactionとは原子的でないので成功/未達を偽らない（§4.8）。

共有concernのメソッドを呼ぶことはBase/Visa以外のcontrollerや任意のserviceからの実行権限を意味しない。呼出し可能surface/operation/検証済みparentの組を閉じた表で静的検査し、app/org/com各realmでBase/Visa以外のDB writer・秘密鍵利用を0にする。

### 4.5 項目別の書込みと取得元

| 項目 | Base匿名save | Base本人save | Visa sign-in | Visa sign-out |
|---|---|---|---|---|
| theme/language/timezone/currency/date/time/motion/density/page_size | setting | Z→setting | Zのexplicit→匿名行、その他は匿名行→既定 | 旧匿名行→新匿名行 |
| region | setting＋固定4項目 | Z→setting、固定4項目もexplicit | **地域自体は匿名行へ反映しない**。地域保存時に明示保存扱いとなった4表示項目は上段の各項目として反映 | DBの地域を新行へ、cookieへ出さない |
| consent | setting＋binding | 同じ。Z書込0 | accountから反映しない | 値＋binding記録をcopy |
| Web Push | setting＋binding | 同じ。Z書込0 | accountから反映しない | 値＋binding記録をcopy |
| adult gate | 保存入口なし | 保存入口なし | 利用しない | 利用しない |

regionの固定表は既存REGIONAL_DEFAULT_OPTION_NAMESを正とし、例jp→ja/ISO/24時間/JPY。cookieを元に導かない。
Base本人saveのcommitはZ→setting。入力/JWTの静的検証を先に済ませ、Z actorをlockしてZを確定し、**Z lock解放後にS行をlock/reloadしてjti等を最終確認**する。SをlockしたままZを取りに戻らない。
途中停止はZ新/setting旧で明示error。新補償は足さず次sign-inで反映。認証の権限付与とは異なる順序を混同しない。
Visa sign-inはaccountを読み取り、account行/explicitフラグを変更しない。sign-upの初期自動取込みもない。

### 4.6 GET/HEAD、Actor.preferences、設定form

| 入力/host | DB/認証 | 表示とcookie |
|---|---|---|
| 正しいJWT、表示cookieも正しい | 書込0。非Base/VisaはDBアクセス0 | JWTの検証済み表示をserver renderingへ。JSはlanguage/experienceを使用。世代差だけで再発行しない |
| 正しいJWT、表示cookie欠損/一部不正、Base | 書込0、JWT発行/延長0 | DBからaccount explicit→匿名行→既定の順で**全体**を再構築し、表示2枚だけ発行。残存JWT expを超えて延命しない |
| 同条件、Base以外 | DBアクセス0、cookie発行0 | JWTの検証済み表示。JWTもなければ既定値。エラーを残す |
| JWT欠損/署名不正/期限切れ/別realm/拒否kid、GET/HEAD | 行/JWTを作らない | 既定値で描く。**Base/Visaだけ**が自身に許された応答で無効な共有cookieの削除を発行する。読取り専用の他hostはJWT/表示cookieの発行・削除をせず、無効値を表示に使わない。D-54によるwriter限定を優先する解釈（§12.7）。全host一律のcookie削除にはしない |
| 署名/期限は正しいがjtiが古いJWT | 表示readではjti比較を要求しない | expまで表示利用可。writeでは§4.4へ。表示readのために全hostへDBを広げない |

`Actor.preferences`は検証済みJWTの表示値＋Base自身の認可済みDB項目（同意/地域/Web Push）から明示的に組み立てる。
Base設定formの初期値は本人explicit→匿名DB→既定。保存は変更した項目だけ、他の画面初期値を一括POSTしない。
URL overlayは表示contextのみで、DB/署名JWTを勝手に変更しない。
D-52 Authの409ではこのGET cookie掃除/再構築も走らせない（認証cookieと混同しないだけでなく事前副作用を止める）。

### 4.7 同意/Web Pushのbrowser binding

BaseはJWTの署名・realm・期限を検証した後、当該`sub`のsetting行の**active状態**を確認し、`__Host-preference_binding`のdigestをconstant-timeで照合する。署名済みJWTだけで同意・Web Pushを肯定しない。表示用には古いjtiを期限まで許すが、退役行のbindingは有効な同意として使わない。
一致する場合だけDB同意/Web Pushが有効。不一致/欠損ならno consent/disabledとして返し、GETで行/bindingを変えない。
保存はBase自身のCSRF付き操作で、新規なら乱数を生成してdigestを行へ保存。既存cookieが形式正しければ同じ値をそのブラウザの明示操作で新しい対象rowへ結び直せる。
Domain JWTの差込みだけではbindingを更新しない。JS/兄弟hostがbinding cookieを発行できる経路を作らない。
Visa sign-outは旧rowの同意/Web Pushとbinding recordを新rowへ一体copy。Base cookieは変更しない。
Base以外では常に同意なし/Web Push disabled。バナーは「設定はBaseで確認」のリンクだけで、同意済み表示や第三者送信を有効にしない。scope外の通知配信を実装しない。

### 4.8 保存・sign-out・resetの障害応答

| 障害点 | DBに残るもの | 公開結果/回復 |
|---|---|---|
| DB読取り失敗 | 変更なし | 表示GETは既定表示＋error。保存は503、成功表示なし。認証を匿名へ黙って変更しない |
| 不正JWTでwrite | 指された旧行は不変、defaults新行を作る | 新行に明示入力を適用し新JWT発行。旧表示をseedしない。作成不能なら503/既定表示＋error |
| signing/key取得失敗、Preference commit前 | transactionをrollback、旧行維持 | 503で保存失敗。sign-outの認証終了は維持。鍵障害をcredential不正と呼ばない |
| 本人saveのZ確定→setting前 | account新/匿名旧 | 503、error、保存完了としない。次sign-inでDBから反映 |
| sign-out新行/copy/旧行退役の途中 | setting transaction全rollbackで旧行のみ、または全commitで新行のみ | 認証sign-outは独立して完了。Preference片付け失敗を記録し虚偽の成功なし |
| DB commit→cookie queue/配達が失敗 | 新jti/新行は確定、browserに旧cookieが残り得る | 再び旧JWTでwrite→defaults新行。既定値に戻ることを許容、元のrowを復活させない |
| 表示cookieだけが欠落/破損 | DB/JWT不変 | §4.6。全体を作り直す。部分的に不正な値を混ぜない |
| resetのaccount退役→setting失敗 | Z旧account設定は退役済み、匿名旧の可能性 | errorで部分成功を明示。account設定を自動復元せず次の明示保存で新規作成 |

HTML保存の成功は303で許可済み設定/戻り先へ、API PATCHは200で検証済み結果。入力不正は422、レート429、依存障害503。
戻り先はscheme/host/effective portの完全一致＋既存の許可辺。任意URL/二重decode/資格情報付きURLを拒否。

### 4.9 寿命・purge・鍵rotation

- `now < exp`を有効、`now == exp`は失効とする。GET/HEADはjti/exp/DB最終利用時刻を更新しない。
- 【P】Preference rowのpurge猶予は最終発行exp＋30日。retired行も最後に発行したJWTの期限＋30日まで保持。既存hold/監査参照があれば削除しない。
- purgeはowner DB時計で期限を再確認し、子→親を同一DB transactionで削除、batch200。expiry直前/一致/直後、hold、並行save/sign-out、途中rollbackを公開jobから試す。実測件数/回復と別途承認が必要。
- 通常鍵rotation: 新公開鍵をreader全体へ先配布→新kid署名へ切替→旧exp最長400日＋時計差期間を過ぎて旧鍵撤去。事故時は旧kidを即拒否してrealm内の再作成を受容。
- kid拒否の設定は既存デプロイ経路で全readerへ適用し、鍵本体/tokenをログへ出さない。private keyが取得不能なら新cookieを出さない。
- public keys・issuer・audience・active kid・失効kid集合は必須設定。起動時に欠落を明示しコード側の既定値を作らない。実環境の鍵供給方式は§11。

## 5. Authの進行・置換・Cancel

### 5.1 進行点（D-58）

| 方式 | 進行を確定する点 | その前 |
|---|---|---|
| Email sign-in/signup、telephone signup | OTP世代の発行とceremony進行をOPでcommitしてから送信へ渡す（D-58追補/RV-69） | 入力/認可/期限/cooldownの拒否、発行commit失敗は未進行・送信0 |
| Secret sign-in | 正しいSecretの確認成功 | 不一致で消費/Flow進行しない |
| Google/Apple sign-in/signup | 正しいproviderの成功callbackと、そのattemptへの結び付けを確認 | 送り出すだけ/Backは未進行。新送り出しで旧state/nonceを置換 |
| ORG Entra | 1段目の正しい成功callback | 失敗/取消は未進行 |
| app Passkey、ORG Standby | 署名成功＋適格性確認時 | options/失敗/ダイアログ取消は未進行、Switch/Back可 |

**D-58確定版追補（RV-69）:** 「OTPを送った」は、OTPを発行し、進行を先にcommitして送信へ渡すことを指す。発行/進行commit→enqueue/外部送信の順を守り、利用者への実配達の成否とは区別する。commit後に送信失敗・結果不明・process停止があっても進行を戻さず、既存の再送またはCancelを案内する。結果不明だけを理由に世代を捨てたり、新しい終端/全再開始を要求したりしない（§12.2）。
署名後に上限/MFAへ進んだ場合は進行済み、Root successではない。停止など資格不足の署名前拒否を成功としない。

### 5.2 D-53の置換とSwitch

P: 既存のSID lineage（previous_sid_digest）を、共通SIDを提示した要求の直列化の起点にする。新Admissionの全検査を終えた後だけ、
旧SIDを先に、次いで必要な親/binding/Flow/proofを正規順でlockし、未置換を再確認→旧ceremony終端→新ceremony作成/結合→commit→新SID発行。
同じ旧SIDから同時に2つが入る場合、旧rowのlock/`previous_sid_digest`の一意性で後着を409にし、負けた応答にSet-Cookieを出さない。
前のterminal Flow locator・MFA/上限/social stateは、置換対象に属するものだけを新要求のcommitした経路で掃除しBL-11を解消する。
旧親はRPへaccess_deniedを返さず、期限後purgeへ。明示Cancelと区別する。遅いcallbackは親/ceremony/binding/世代を全て照合する。

**初回競合の確定した例外（AC-53追補/RV-68）:** SIDなしの2 attachが独立SIDを作り、サーバーに余分なadmitted ceremonyが残る場合は許容する。ブラウザに最後に残るauth_sidに結び付いた手続きだけが、後続要求で進行できる。残らないSIDの手続きへの画面/POST/provider callbackは現在の共通Cookieを送るため、対象との不一致を副作用前に409で拒否し、その余分な行は使わず期限後にpurgeする（§12.1）。行数が一時的に2であることだけを不合格にしない。同じ旧SIDを共有する通常の置換では従来どおりCASで1件だけを受け入れる。
新Cookie、親別sessionStorage、IP/UA fingerprintを導入しない。旧SIDや親参照から余分なceremonyを探して認証を続けるfallbackは作らない。

Switchは開始前だけ。親lockの下で旧bindingをswitchedへ終端化し新bindingを作成する。active partial UNIQUEはparent kind/ref/purposeで設計。
回数上限はなし。親期限/既存rateを維持。nonce/stateの旧世代を復活させず、初期画面に戻れることとterminalをactiveへ戻すことを区別する。

### 5.3 D-52の無変更409

- 3拒否口は共通privateの`render_phase_refusal!`【P名】だけを使う。固定409/text「はじめからやりなおしてください」/no-store/Locationなし、HEAD body0。
- 要求の対象/現在状態の読取り判定はsession cleanup/refresh/actor利用時刻更新/DBSC発行より前。許す副作用は安全なログ/rate計数のみ。
- 【P】最外側response boundaryは、サーバーのみが設定できるrequest-localのphase拒否印とstatus409が一致する場合だけ、認証cookieのSet-CookieとAuth DBSC headerを送出しない。Cookies/Session middlewareのcommit後に適用する位置を選ぶ。
- exact cookie名は`JitSessionCookieConfig`、`AuthCeremonySidCookie`、`AuthenticationCookieName`のhost/secure別設定から列挙。DBSCは`AuthIoKeys::Headers`の閉じた集合。prefix wildcardや全Set-Cookie削除をしない。
- session.options[:skip]単独ではcookie jarの先行書込みを止められない。response filterだけでも先行DB変更を取り消せない。両方の条件を全入口で検証する。
- 正当Cancelはこのfilterの対象にしない。通常のCSRF拒否/依存障害の契約も統合して409に変えない。
- 旧隔離実験M8R2はframeworkの反例として保持するが、今のapplication pipelineの合格証拠ではない。配置は§12.3、差分対象と公開検証は付録F。

### 5.4 Cancelのlockと確定

| 親 | Cancel | register | finalize |
|---|---|---|---|
| pending、予約なし | 同じ親lockで予約commit | 可 | 不可 |
| pending、予約あり | 同じhandoffの再送のみ | 拒否 | 拒否 |
| authenticated、finalize前、予約なし | 予約してcancelへ | 済み | 可 |
| authenticated、予約あり | 同じhandoffのみ | 拒否 | 拒否 |
| consumed/finalized | 不成立、状態不変 | 拒否 | 既存の同確定の再送のみ |
| canceled | 同じhandoffの配達のみ | 拒否 | 拒否 |

formは推測不能な対象ceremony/親参照。現在auth_sidと対象所有を照合し、親をlock/reloadして予約をcommitする。sign-up生成には検証済み親を必須にする（§12.4）。既存callerを全件更新し、未結合入力はFlow作成前に拒否する。formを省く・架空の親を補う対応はしない。
親予約は認証登録/result発行/OTP/Rootの全writerで拒否条件にする。OTPの親→ceremonyと、現actor→Flow→ceremonyの逆順を末尾lock追加で解決しない。
P lock順は、Zに触れる操作ではactor→対象、OPではbrowser SID→親→Flow/binding→proof、複数同種IDは昇順（§12.1）。
OP lockを保持したまま新しくZ actorを取りに行かず、actor判明後はlockを解放して正規順で取り直し全条件を再検証する。
Cancel確定後のZ cleanupはOP親lockを離してから既存cleanup jobへ。片付けの完了を親の確定条件にしない。

### 5.5 状態/ブラウザ/DBの対照

| 要求 | server | reset/session/cookie | account/RP |
|---|---|---|---|
| 不一致409、無効Cancel | 変更なし、要求終了 | resetなし、認証Set-Cookie/DBSCなし | 正当な他要求/独立session不変 |
| 正当Cancel、現在SIDが対象 | 予約を確定、復活不可 | reset_session＋auth_sid削除 | 対象の未完了分のみcleanup、access_deniedをVisaへ。既存RPは消さない |
| Cancel確定→process/通信断 | 取消確定のまま | browser片付け未達 | 配達/片付けを成功済みと記録しない |
| 同Cancel再送、同じSID | 終端を照合、予約再作成なし | 未達分のreset/削除を実行 | 同handoffのaccess_denied配達 |
| 同Cancel再送、新しいSID | 古い終端を維持 | 新session/SIDを変更しない | 認可済みhandoffの配達だけ |
| auth_sid欠損の再送 | 一致と推測しない | resetしない | 既存handoffの配達認可を別途確認 |
| finalizeが先 | Cancel拒否 | reset/削除なし | 完成account/成立RP保持。Sign Outは別操作 |

終端SIDの照合はactive-only resolverとは別のcleanup-only読取り。rawSID digest＋対象ceremony＋親＋同handoffを確認するだけで、認証に使えるactive contextを返さない。
取消済み行の保持はhandoff期限より短くしない。purgeは期限＋【P】30日、参照/監査holdがあれば保留。
古い暗号化Rails cookieが再送されてもserver terminalから認証を復活させない。

### 5.6 sign-up完成とcleanup

完成していないZ actor/所有連絡先/保留Passkey/予約/Flowだけを、同じ登録操作の帰属とowner lockの下で片付ける。
完成の判定はZの永続事実が正で、OP Flowの記録遅延を未登録の証拠にしない。§12.4の登録完成receiptをsource変更と同じZ transactionへ置く方式を採用する。これは完成事実の保存であり、補償queue/outbox/再ログイン経路ではない。

| 方式 | 完成判定に使うZ事実 | 禁止 |
|---|---|---|
| app Email | Client verifiedと当該owned emailのverified/effective binding、登録の帰属 | Flow期限切れだけで未完成に戻す |
| app Telephone | Client verified、当該owned telephone verified/effective binding、登録済みPasskey | 他Flowの資格情報だけで今回完成とする |
| app social | verified Client＋provider/issuer/subjectのactive identityと、そのsignup/link監査の帰属 | 別subject/単なる同メールを本人とする |
| Secret後段 | 同actor/Flow/operationのissuance・完了監査/完了時刻 | account行だけを残してSecret資格情報を終了する |

現在状態が停止/失効でも、過去の完成が消えるわけではない。現在login_allowedだけを完成履歴の条件にしない。
既存Solid Queue/Secretのjobと直接terminate入口は、Z完成/帰属を先に再確認し、完成済みなら資格情報を止めない。
FlowはCANCELLEDにせず既存の合法なcomplete遷移で登録完了として閉じる。OP親ログインだけ取消し、真実の履歴を保つ。
source直後の帰属は§12.4の完成receiptに保存し、既存FlowのFINALIZING→COMPLETEDと後段jobで処理する。新outbox/補償は作らない。

## 6. DBをまたぐ設計・本人解決・HTTP

### 6.1 所有と部分成功

Z=app/org Zenith（本人/資格情報）、T=op_base（認証/許可/grant）、R=RP自身のDB、S=realm setting、C=既存監査/Chronicle。
現在のDB分離を維持する。同じRails processだから同一transactionとみなさない。別DB AR関連は不透明参照へ、同DBのFKは維持する。
操作表の「先」はcommit順、lock順はZ→Tが基本。Cへの既存outbox/配送/回収は全て維持し新補償を増やさない。

### 6.2 操作台帳（AC-44の入力）

全行は【設計P】の目標順序と失敗時の契約。現コードがすでにこの順序だという事実ではない。現在順との差はG-13〜20と各実装差分で比較する。

| ID/対象ファイル・操作群 | commit順 | 第1commit前/後で止まると残るもの | 次の要求/監査 |
|---|---|---|---|
| XDB-01 `identity_passkey_registration_final_committer.rb` | T候補/proof消費→Z credential＋outbox | 前:変更なし。後:消費済み/鍵なし | 再確認が必要。operation帰属で既存鍵の二重作成なし |
| XDB-02 `identity_passkey_name_committer.rb` | T消費→Z名称＋監査 | 後:proofだけ消費 | Step-Up再実施。名称成功と報告しない |
| XDB-03 `identity_email_preference_committer.rb` | T消費→Z通知設定＋監査 | 同上 | 元設定のまま。依存障害503 |
| XDB-04 `identity_totp_name_committer.rb` | T消費→Z名称＋監査 | 同上 | 同じproofで別対象更新不可 |
| XDB-05 `client_secret_name_committer.rb` | T消費→Z名称＋audit | 同上 | actor/Secret帰属再確認 |
| XDB-06 `client_secret_storage_confirmation_committer.rb` | T消費→Z保管確認＋audit | 同上 | 既存確認記録とoperationで冪等性を判定 |
| XDB-07 `identity_credential_removal_committer.rb`、Secret取消 | T許可消費/失効→Z credential失効＋audit | 後:許可失効、資格情報は残り得る | 再確認して失効。証明/旧evidenceから認証を発行しない |
| XDB-08 `identity_email_ceremony_final_committer.rb` | T候補消費→Z連絡先/監査 | 後:候補だけ消費 | 既存候補/登録帰属で再試行。別emailへ転用不可 |
| XDB-09 `identity_telephone_ceremony_final_committer.rb` | T候補消費→Z電話/監査 | 同上 | 同上。配送済みOTPはロールバック不能 |
| XDB-10 `identity_totp_enrollment_final_committer.rb` | T確認/証明消費→Z TOTP/監査 | 同上 | secret候補をresponse/logへ出さない |
| XDB-11 `identity_secret_credential_ceremony_final_committer.rb` | T候補/proof消費→Z Secret＋監査 | 同上 | 新しい補償で資格情報を生成し直さない |
| XDB-12 `identity_social_ceremony_grant_issuer.rb`とlink確定writer | T証明消費→Z identity/監査 | 後:許可だけ消費 | issuer/subject/actor/目的を再確認 |
| XDB-13 `identity_step_up_*_verification_committer.rb` | Z actor/credential snapshot確認→T evidence | T後にZ credential変更可 | credential_versionをRoot/操作直前に比較、古いproofを拒否 |
| XDB-14 `auth_email_otp_challenge.rb`＋OTP adapter | Tで世代発行＋進行commit→必要なZ cooldown/監査commit→enqueue/外部送信 | T前:進行/送信0。T後:進行済み。Z失敗は送信0、外部失敗/不明も進行維持 | 進行維持。既存の再送/Cancel。結果不明だけで世代破棄/再開始を強制しない。旧世代は明示再送/取消/期限等で失効 |
| XDB-15 `email_sign_up_candidate_creator.rb`とFlow作成 | Z保留候補→T Flow | 後:孤立保留候補 | 未完成/所有を確認する既存cleanupで回収、完成は消さない |
| XDB-16 電話候補/`sign_app_up_telephone_registration_finalizer.rb` | Z保留候補/鍵/完成→T記録 | 後:Zに事実ありT遅延 | source完成を正とし既存jobで完了記録。逆順lockを修正 |
| XDB-17 `social_auth_signup_finalizer.rb`＋sign-up Flow | Z identity/Client完成＋audit→T完了 | 後:登録済み/ログイン未完 | Cancelは登録保持、通常sign-inへ既存handoff |
| XDB-18 `client_secret_claim_committer.rb` | 対象を確認、Secret消費とFlow/evidenceを明示順で分離 | 消費のみの可能性 | Secretを再利用可に戻さない。未ログインを成功表示しない |
| XDB-19 `client_secret_passkey_reservation_issuer.rb`/lifecycle job | Z完成事実→T bookkeeping/既存Z完了監査 | OP遅延を未完成としない | 完成済みSecretをretireしない。§12.4のreceiptを先判定 |
| XDB-20 Cancel/`sign_up_artifact_cleanup.rb` | T親Cancel予約→子終端→Z保留cleanup | 後:取消のみ/cleanup未達 | 認証不可、既存cleanup再試行。完成source保持 |
| XDB-21 `withdrawal_lifecycle.rb`/stop recorder | Z停止＋epoch/停止記録→T権限停止→C等 | 後:上位停止、下流一時残存 | 発行拒否、既存sweep/配送で回収。復帰で旧世代を戻さない |
| XDB-22 `op_authority_stop_committer.rb`/BCL | T stop＋participant同transaction→R通知 | 後:OP停止/R残存可能 | token寿命までの残り、既存配送。通知成功をOP commit前提にしない |
| XDB-23 RP callback/`rp_callback_committer.rb` | T OIDC成立→R session/identity | 後:R未成立 | RP失敗でRoot/登録を補償削除しない。ref/code再利用不可 |
| XDB-24 RP logout/`oidc_rp_logout_launcher.rb` | R revoke→T RFC7009→任意のOP全体stop | 後:local終了、grant残存可能 | §6.5の上限。local session復活なし |
| XDB-25 Base本人Preference save | Z設定/explicit→S設定/jti | 後:Z新/S旧 | 503＋error、次sign-inで反映。accountへのcookieコピーなし |
| XDB-26 Visa sign-in | Z explicit読取→S反映/jti | S前停止なら表示旧 | 認証と表示の成功を分離。S後RP失敗でも表示保持 |
| XDB-27 Visa sign-out | T認証停止→S新行/copy/退役 | 後:認証終了/Preference旧も可 | S内は一括transaction、失敗を認証successへ混ぜない |
| XDB-28 Base reset | Z account設定退役→S新行/退役 | 後:account退役/S旧 | 明示失敗、次writeは残った行に対し検証し直す |
| XDB-29 監査outbox各delivery job | Z/Tの監査factと状態を同DB確定→C配送 | 後:監査未配達だが事実は保持 | 既存retry、poisonを飛ばして後続へ、失敗を消さない |
| XDB-30 Enforcement apply/end/retention/backfill | ownerの強制/hold状態→既存projection/配送 | 後:保護を緩める推測をしない | 既存Enforcement recovery維持。新reconcilerなし |

XDB-01〜12の最終Z commit直前/直後をそれぞれ障害注入し、credential/設定/監査が同じZ transactionで変わることを確認する。
XDB-15〜19は権限付与前の保留sourceと登録完成を別に扱う。単純に「全てTを先に」へ機械置換しない。
付録F.2の実ファイル集合をXDB-18/30を含む実装レビューの入力とする。用途の分類は設計であり、各下位call siteが既に安全であるという認定ではない。
実装時は`connected_to`/`transaction`/全writerの静的差分を台帳と突合し、表外の跨DB操作があればAC-44を閉じない（§12.6/付録F.2）。**各行について「第1DB commit前/直後」「第2DB commit前/直後」を別々に故障注入し、権限・資格情報・監査・次要求を明示する。** 単なるZ/Tの順序表だけを全commit境界の証明とみなさない。manifestに載った各下位writerも同じ受入対象であり、入口だけ直してAC-44完了にしない。

### 6.3 退会状態（R-AU-40）

actorに`withdrawal_state_id` NOT NULLのreferenceを置く【P】: active / recoverable_suspended / recovery_expired / anonymized。
申込みだけのREQUESTEDはFlowが持ち、actorの架空closingを作らない。回復可能期限はsuspendedの必須事実として別の期間record（actor FK UNIQUE、deadline NOT NULL）へ置き、activeでNULLの期限を意味づけしない。

| 遷移 | 確定するもの | 守ること |
|---|---|---|
| 申込み | Flow REQUESTED | actor activeのまま。申込みだけで停止済みと呼ばない |
| 停止 | actor recoverable_suspended、期限、epoch/停止fact | Z停止を先に、OP/RP配送は既存経路 |
| 回復（期限内） | active、Flow recovered、旧期間recordを履歴化 | actor/目的/期限一致、通常ログインsession0 |
| 期限到達 | recovery_expiredへnamed transition | 期限だけで「匿名化済み」にしない |
| 匿名化の完了 | 実際の処理が確定してanonymized | 不可逆操作は別途承認。暫定(c)中に新しい消去経路を足さない |

用途別証明の本設計は次サイクル。既存のstatus回復とprivacy request拒否を維持し、未決をNULLや一般OTPへのfallbackで解決しない。

### 6.4 Baseの本人解決

1. BaseのRP authenticatorがJWKS、iss/aud/realm/sid、local session有効性とidentity bindingの不変性を確認する。
2. Base appならclient、orgならoperatorの正準subjectを`OidcSubject`の既存規約でdecodeし、許可issuer＋realm＋subを照合して、そのZenithのpublic_idから本人を引く。
3. 正準subjectを同じ規約で再構成し完全一致を要求。RP local principalのid、URL actor_id、Preference JWT subを本人の根拠にしない。
4. 認証済み本人と操作認可を分け、対象credentialは本人のscopeから検索、Step-Upのactor/目的/resource/version/期限を再検証。停止/退会なら拒否。
5. dependency障害は503、欠損/不整合はfail closed。別のログイン経路や匿名への黙ったfallbackを足さない。

【P新規】`app/resolvers/base_zenith_identity_resolver.rb`。Client/Operatorの明示caseを持ち、他RPからは呼べないguardを置く。
既存subjectが`oidc_subject`等の別属性を使う場合はpublic_idと同一と推測せず、実装前に実発行/consumerの対応表を固定する（§12.6）。

### 6.5 RFC7009とlogoutの失敗上限

- RPのCSRF付きsign-outでlocal sessionを先にrevoke、local cookiesを消去する。local revokeのDB確定に失敗した場合は503とし、local logout済みと報告しない。取り消すrefresh tokenはそのsessionに対応するものだけを、消去前にrequest内で保持。
- 既存Visa `/revoke`へ登録済みclient認証で送信する。token_hintはrefresh_token。生tokenをURL/log/job payloadへ入れない。
- 【P】ネットワーク失敗時の再試行は同一要求内1回まで、合計timeout2秒を設計値とする。成功を偽らず、localを復活させず、その後既存OP全体の確認へ進む。
- 新しい補償queueは作らない。再試行後も未達なら、grant/refreshはそのtokenの元の失効時刻まで残る上限を記録し受容対象として提示する。無期限のrefresh/再延命は認めない。
- 発行済みaccess JWTは受信側のlocal停止/BCLまたはJWT expまで受理され得る。OP確認でCancelしてもlocal logoutを取り消さない。
- 他RPのgrant/OP SSO、同じRPの別browserを勝手に止めない。基準の`OidcTokenRevoker`→`RpSessionRevoker(scope: :rp_session)`のgrant単位停止を維持する（G-26、§12.6）。
- `/revoke`のrateは登録済みclient単位へ対応を設計し、IP制限を迂回する汎用例外を足さない。自己HTTP呼出しがPuma threadを占有するためdeadlock/飽和とタイムアウトを実測する。今回は接続しない。

### 6.6 公開HTTP結果表（D-59/OQ-11）

| 共通結果/理由 | browser form | API/challenge | OIDC/provider callback | session/DB |
|---|---|---|---|---|
| root success | 303既定の継続先 | 200＋許可済み継続先 | OIDC responseの既存継続 | Root commit済みのみ成功監査/cookie |
| authentication_evidence_recorded | 303 Visa継続 | 200、status=evidence、ログイン成功とはしない | 親にevidenceを結んでVisaへ | Root/RP発行0 |
| mfa_required | 303当該MFA | 200、status=mfa_required | 既存MFA継続へ | 権限追加0、本人/親/期限固定 |
| session_limit_pending | 303当該上限解決 | 200、status=session_limit_pending | 既存上限継続へ | 仮tokenなし、別sessionを無断削除しない |
| 再入力可能な不一致 | 422同じform | 401署名/資格確認失敗、入力形422 | socialのprovider errorは次行 | 正当手続きを保持。消費済みSecretを再入力可能と呼ばない |
| social L1/L2（検証済み） | 400理由＋固定の新入口 | 400閉じた公開reason | 400理由別HTML | 自動登録/ログイン0、旧state/evidence再利用なし |
| state/owner/phase不一致 | **409固定text** | 同409 | 同409（置換済みcallbackを含む） | D-52、認証変更/Set-Cookie/DBSC0 |
| 停止/禁止 | 403一般拒否 | 403 | 公開理由を許可リストに限定し403 | Root/送信/Admission消費0、登録有無を出さない |
| 入力レート/OTP cooldown | 429既存一般文言 | 429 | 429 | Retry-Afterは既存契約、登録有無で残時間を変えない |
| dependency | 503、再試行可能表示 | 503 | 503、成功へredirectしない | credential消去と混同せずerror記録 |
| CSRF/Origin/Fetch Metadata不成立 | 既存422/403 | 同 | Apple等の既存検証済み例外のみ維持 | 新しい認証例外を追加しない |

表は新実装の設計P。外部protocolがerror redirectを必須にする箇所は既存の検証済みredirect_uri/stateへ返す契約を優先し、HTML化しない。
HTTP statusだけでなく本文/Location/所要時間/再送制限を登録有無の同値分割で比較する。個別public endpointへの割付け規則と継続POSTは§12.5/付録F。**この表の400/401/422/303は全入口へ機械適用しない。** 既存のOIDC error response・検証済みcallback・HTML form/APIごとの既定statusとredirect契約を実route行単位で確かめ、状態不一致の409とproviderからの一般errorを同一視しない。

### 6.7 認証情報の単調な版

【P】Client/Operatorのcredential_versionはbigint NOT NULL、初期1、減少/巻戻し禁止。authentication_epochは別目的で維持。
追加/変更/削除/再設定/失効/管理者操作/ログイン連絡先変更の全writerがactor lock内で増分し、同じZ transactionで監査を記録する。
verificationはactor/credential snapshotと版を同時に取得し、そのsnapshotを検証する。外部検証後に最新版を読み直して合格に付け替えない。
長い外部処理中にlockを保持しない場合は、取得済み版とcredentialの不変な検証対象を検証後actor lockで再比較してからevidenceへ記録する。
Root直前は同actor lockでcaptured版と現在版、資格情報/連絡先/停止/退会を再確認。不一致ならRoot0、evidence終端、古い結果から自動再開しない。**読取り検査の直後にZ lockを解放してTのRootをcommitすると、その間の変更を防げない**。**Z actor lockをTのRoot commit確定まで保つ方式を採用する**。全credential writerも同じactor lockを取る。Z→Tの順、timeout/失敗の処置は§12.6。単なる「直前に再読取り」ではAC-55合格にしない。
全writer inventoryは§12.6/付録F.2と連動し、管理コマンド/既存job/直接model入口も含める。図はcredential-version軸とRoot境界へ追加。

### 6.8 同時更新するMermaidの具体対象

| 軸 | 既存図/更新の内容 |
|---|---|
| Auth進行/置換/取消 | `docs/mermaid/idp-{client,operator}-auth-ceremony-session.mmd`、D-58の開始点、replaced/terminalの拒否 |
| Admission/Switch | `docs/mermaid/idp-{client,operator}-auth-admission-binding.mmd`、旧binding switched/生存unique |
| OIDC親 | `docs/mermaid/idp-{client,operator}-oidc-authorization.mmd`、authenticated→Cancel、予約後のregister/finalize禁止 |
| signup/cleanup | `docs/mermaid/idp-client-sign-up.mmd`、`idp-client-sign-up-cleanup.mmd`、登録完成保持/認証取消 |
| credential/slot | `docs/mermaid/idp-{client,operator}-passkey-credential.mmd`、retained slotと監査 |
| withdrawal | `docs/mermaid/idp-client-actor-withdrawal.mmd`とoperator軸、新しいreference state |
| Preference | 旧`idp-*-preference-dbsc.mmd`を廃止履歴へ。新しい匿名行active/retired/JWT/binding図とinventory行を追加 |

全て`docs/mermaid/idp-state-machine-transition-inventory.md`へwriter/lock/guard/参照表を同時反映する。
図は実装変更と同時に更新し、本書の未実装案を現在実装図として上書きしない。

## 7. 要件・受入条件の追跡

各行は担当WUと本書の実装契約を指す。定義されていない番号を補番しない。
AC-20は廃止履歴、WU-2/8は非実行。要件の古い文はone.mdの現行D-53〜59で読み替える。

### 7.1 全R（101件）

| ID | 担当WU | 本書の適用箇所 |
|---|---|---|
| R-P-16 | WU-P0、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-PREF-1 | WU-3 | §3.2/3.3、付録E/I |
| R-PREF-2 | WU-3 | §3.2/3.3、付録E/I |
| R-PREF-3 | WU-3 | §3.2/3.3、付録E/I |
| R-PREF-4 | WU-3 | §3.2/3.3、付録E/I |
| R-PREF-5 | WU-3 | §3.2/3.3、付録E/I |
| R-PREF-6 | WU-3 | §3.2/3.3、付録E/I |
| R-PREF-7 | WU-3 | §3.2/3.3、付録E/I |
| R-RT-1 | WU-3 | §3.2/3.3、付録E/I |
| R-RT-2 | WU-3 | §3.2/3.3、付録E/I |
| R-RT-3 | WU-1、WU-3 | §3.2/3.3、付録E/I |
| R-RT-4 | WU-3 | §3.2/3.3、付録E/I |
| R-RT-5 | WU-4 | §3.2/3.3、付録E/I |
| R-RT-6 | WU-4 | §3.2/3.3、付録E/I |
| R-RT-7 | WU-4、WU-5 | §3.2/3.3、付録E/I |
| R-P-1 | WU-7、WU-9、WU-E | §4、D-54〜57。7はcom、9はapp/org |
| R-P-2 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-3 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-4 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-5 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-6 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-7 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-8 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-9 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-10 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-11 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-12 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-13 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-14 | WU-E、WU-7 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-15 | WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-17 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-18 | — | §4、D-54〜57。7はcom、9はapp/org |
| R-P-19 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-20 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-21 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-22 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-23 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-24 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-25 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-P-26 | WU-7、WU-9 | §4、D-54〜57。7はcom、9はapp/org |
| R-EDGE-1 | WU-E | §3.13、T-8 |
| R-EDGE-2 | WU-E | §3.13、T-8 |
| R-EDGE-3 | WU-E | §3.13、T-8 |
| R-EDGE-4 | WU-E | §3.13、T-8 |
| R-EDGE-5 | WU-E | §3.13、T-8 |
| R-EDGE-6 | WU-E | §3.13、T-8 |
| R-AU-1 | WU-A1 | §3の担当WU、§5/6 |
| R-AU-2 | WU-A1 | §3の担当WU、§5/6 |
| R-AU-3 | WU-A1 | §3の担当WU、§5/6 |
| R-AU-4 | WU-A1 | §3の担当WU、§5/6 |
| R-AU-5 | WU-A1 | §3の担当WU、§5/6 |
| R-AU-6 | WU-A1 | §3の担当WU、§5/6 |
| R-AU-7 | WU-A1 | §3の担当WU、§5/6 |
| R-AU-8 | WU-A2 | §3の担当WU、§5/6 |
| R-AU-9 | WU-A2 | §3の担当WU、§5/6 |
| R-AU-10 | WU-A6 | §3の担当WU、§5/6 |
| R-AU-11 | WU-A3 | D-53 B、§5.2/T-1 |
| R-AU-12 | WU-A5 | §3の担当WU、§5/6 |
| R-AU-13 | WU-A5 | §3の担当WU、§5/6 |
| R-AU-14 | WU-A4、WU-A5、WU-A2 | §3の担当WU、§5/6 |
| R-AU-15 | WU-A5 | §3の担当WU、§5/6 |
| R-AU-16 | WU-A5 | §3の担当WU、§5/6 |
| R-AU-17 | WU-A5 | §3の担当WU、§5/6 |
| R-AU-18 | WU-A5 | §3の担当WU、§5/6 |
| R-AU-19 | WU-A5 | §3の担当WU、§5/6 |
| R-AU-20 | WU-A8 | D-59本人、§6.4 |
| R-AU-21 | WU-A8、WU-A7 | §3の担当WU、§5/6 |
| R-AU-22 | WU-A8 | §3の担当WU、§5/6 |
| R-AU-23 | WU-A9 | OQ-8 B、§6.6/10.7 |
| R-AU-24 | WU-A9、WU-A2 | D-59結果、§6.6 |
| R-AU-25 | WU-A14 | §3の担当WU、§5/6 |
| R-AU-26 | WU-A10 | D-59版、§6.7 |
| R-AU-27 | WU-A14 | §3の担当WU、§5/6 |
| R-AU-28 | WU-4、WU-A14 | §3の担当WU、§5/6 |
| R-AU-29 | WU-A7 | §3の担当WU、§5/6 |
| R-AU-30 | WU-X1 | §3の担当WU、§5/6 |
| R-AU-32 | WU-A11 | §3の担当WU、§5/6 |
| R-AU-33 | WU-A12 | §3の担当WU、§5/6 |
| R-AU-31 | WU-X2 | §3の担当WU、§5/6 |
| R-AU-40 | WU-A7 | §3の担当WU、§5/6 |
| R-AU-41 | WU-A4 | §3の担当WU、§5/6 |
| R-AU-42 | WU-A3 | Switch回数制限なし、§5.2 |
| R-AU-43 | WU-A2 | D-52/58追補、§5.1/5.3/10.8/12.2 |
| R-AU-44 | WU-A2 | §3の担当WU、§5/6 |
| R-AU-45 | WU-A2 | §3の担当WU、§5/6 |
| R-AU-46 | WU-0R、WU-A14 | §3の担当WU、§5/6 |
| R-AU-47 | WU-A2 | 署名/適格性成功後、§10 |
| R-AU-48 | WU-A2 | §3の担当WU、§5/6 |
| R-AU-49 | WU-A2 | social成功callback、§5.1/10.7 |
| R-AU-50 | WU-A13 | §3の担当WU、§5/6 |
| R-AU-51 | WU-A2 | Z完成/cleanup、§5.6 |
| R-AU-52 | WU-A2 | 親予約/Cancel再送、§5.4/5.5 |
| R-AU-34 | WU-A2、WU-A9 | §3の担当WU、§5/6 |
| R-AU-35 | WU-A8 | D-59 RFC7009、§6.5/T-6 |
| R-AU-36 | WU-A8 | §3の担当WU、§5/6 |
| R-AU-37 | WU-A8 | §3の担当WU、§5/6 |
| R-AU-38 | WU-A4、WU-A10 | §3の担当WU、§5/6 |
| R-AU-39 | WU-A2 | §3の担当WU、§5/6 |
| R-X-1 | WU-X1 | §3.13 |
| R-X-2 | WU-X1、WU-3 | §3.13 |
| R-X-3 | 全schema変更WU（例: WU-5/7/A2/A3/A5/A7/A8/A10/9） | §3.13 |

### 7.2 全AC（51件、廃止AC-20を含む）

| ID | 担当WU | 設計/試験箇所 |
|---|---|---|
| AC-1 | WU-3 | §3の担当WU、§5/6/10 |
| AC-2 | WU-3 | §3の担当WU、§5/6/10 |
| AC-3 | WU-3、WU-6 | §3の担当WU、§5/6/10 |
| AC-4 | WU-1、WU-3 | §3の担当WU、§5/6/10 |
| AC-5 | WU-3 | §3の担当WU、§5/6/10 |
| AC-6 | WU-3 | §3の担当WU、§5/6/10 |
| AC-7 | WU-3、WU-4 | §3の担当WU、§5/6/10 |
| AC-8 | WU-4 | §3の担当WU、§5/6/10 |
| AC-9 | WU-4 | §3の担当WU、§5/6/10 |
| AC-10 | WU-5 | §3の担当WU、§5/6/10 |
| AC-11 | WU-0、WU-3〜6 | 基準と失敗/skip/削除ID集合の差。件数比較を合格にしない |
| AC-12 | WU-3〜6 | §3の担当WU、§5/6/10 |
| AC-35 | WU-3 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-20 | — | 廃止履歴、D-51。AC-20bで新方式を検証 |
| AC-20b | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-21 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-22 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-23 | WU-7、WU-9、WU-E | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-24 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-25 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-26 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-27 | WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-28 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-29 | WU-P0、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-49 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-30 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-31 | WU-7、WU-9、WU-X2 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-32 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-33 | WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-34 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-36 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-37 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-52 | WU-7、WU-9 | §4の公開HTTP/ブラウザ/状態/障害表 |
| AC-38 | WU-A1 | §3の担当WU、§5/6/10 |
| AC-39 | WU-A1 | §3の担当WU、§5/6/10 |
| AC-40 | WU-A2、WU-A3 | §3の担当WU、§5/6/10 |
| AC-41 | WU-A6 | §3の担当WU、§5/6/10 |
| AC-42 | WU-A5 | §3の担当WU、§5/6/10 |
| AC-43 | WU-A5 | §3の担当WU、§5/6/10 |
| AC-44 | WU-A4、WU-A5、WU-A2 | §6.2の全操作/全commit障害、T-4 |
| AC-45 | WU-A8 | §3の担当WU、§5/6/10 |
| AC-46 | WU-0、WU-A8 | §3の担当WU、§5/6/10 |
| AC-47 | WU-A14、WU-A10、WU-X1、WU-X2 | §3の担当WU、§5/6/10 |
| AC-48 | WU-A7 | §3の担当WU、§5/6/10 |
| AC-50 | WU-A2 | §3の担当WU、§5/6/10 |
| AC-51 | WU-A2 | §3の担当WU、§5/6/10 |
| AC-53 | WU-A3、WU-A2 | 確定版追補、§5.2/10.6/11.2/12.1、初回例外と通常置換/到達拒否/purge |
| AC-54 | WU-A8、WU-9 | §6.4 Base本人/操作の他owner拒否 |
| AC-55 | WU-A10 | §6.7 captured版とRoot再検証 |
| AC-56 | WU-A9 | §6.6/10.7 social/OTP非列挙 |
| AC-57 | WU-A3/A4/A7/A8/A13 | §3/6.2/6.5/6.7、各個別の公開境界 |

### 7.3 決定の追加差分

| 決定 | 担当/適用 |
|---|---|
| D-49 | A2、§5.4〜5.6/12.4、Cancelと登録完成/親finalizeの確定点 |
| D-50 | P0/7/9、§4.4〜4.8/6.2、項目別Z→S保存・一方向反映・部分成功 |
| D-51 | WU-2を実行しない、§1.1/3/7.4、旧APIの暫定修正を追加しない |
| D-52 | A2/A3、§5.3〜5.5/12.3、無変更409と正当Cancelのresetを分離 |
| D-53 | A3/A2、§5.2/12.1、通常のSID置換とAC-53追補の初回例外 |
| D-54 | P0/7/9、§4.1〜4.4/12.7、realm別署名JWTと唯一の共通writer |
| D-55 | 7/9、§4.5/4.8/12.5、Visaのsign-in反映/sign-out作り直し |
| D-56 | 7/9、§4.1/4.9/12.7、JWT/共有Cookieの400日、writeのみ延長、GET/HEAD延長0、purge猶予と鍵rotation |
| D-57 | 7/9、§4.7/12.7、Base host-only bindingと同意/Pushの保護 |
| D-58 | A2、§5.1/10/12.2、方式別進行点。OTPは追補どおり発行/進行commit後に送信 |
| D-59 | A1/A4/A7/A8/A9/A10、§3/6/12、分類・本人・結果・版・logoutの各契約 |

### 7.4 範囲外・次サイクル

BL-26の方式別試行回数/Switch回数制限、OQ-9の目的別証明の本設計、BL-18の全失敗修復、OQ-17のactor命名全面改名、一般ENV既定値全撤去、Web Push配信機構、BL-24のORG画面へのCancel導線追加は今回の実装対象にしない。
次サイクルの同意backlogはD-55/57で今回決着したため、先送りを現契約にしない。稼働環境/DNS/Cloudflare設定の変更は別途許可。

## 8. one.md §0の残作業の処理

| 項目 | この版での処理 | 実施時の完了条件 |
|---|---|---|
| 旧595行 | 元コマンド/元出力は入力にない。代替の基準tree検索を定義し、1880一致/632ファイルを付録Iで全件割当て。元の595行を全件同定したとは扱わない | 差分レビューで共有分岐を読む。付録Iの「共有」を機械削除しない。T-4と整合 |
| E-1a | 付録Eでcallback/helper/rescueの持ち主と、Base com全82 controllerの処置を定義 | 実装差分/route全件と突合、残すcontrollerを起動して確認 |
| Preference失敗応答 | §4.8と§6.6へ統合 | HTTP endpoint別の全件対応、障害点の試験 |
| WU-7列設計 | §4.2/4.3、generator/制約/保管期間/approval条件を定義 | shape承認→実測件数/回復→実装、schema drift確認 |
| adoption ADR | §2.1/P0、9実装と同時に置換案 | ADR承認は要件の確定と別。旧contractを黙って無視しない |
| WU-2 | D-51により省略、AC-20履歴 | 旧APIの一時修正を依存にしない。実利用者データ/段階3前本番なら再審議 |
| Base以外の戻り先 | A11/12、§4.8 | scheme/host/port完全一致、rt/pt/xtの責務を分ける |
| 行番号/旧audit | §2と付録Iは基準tree、HEAD差分を別記録 | 実装対象とHEAD差を再確認、古い行数を最新実測と呼ばない |
| 受入/QA | §10をD-58に改訂、three.md草案は未変更 | Claudeの再開時にTC対応を合わせる。今回はテスト実行なし |

## 9. レビュー処理

### 9.1 今回の判定

| ID | 判定/根拠 | 反映 |
|---|---|---|
| RV-45〜56 | 過去の採否は固定twelve.md/zero.mdに保持。案Y/BL-25はD-52で廃止、WU-2はD-51で省略 | §0/1/5/7 |
| RV-57 | 採用。無変更409とCancel resetを分離 | §5 |
| RV-58/61 | 採用。CookieStore自動再発行、先行副作用と最終headerを別の防御とする | §5.3/T-2 |
| RV-59 | 採用。終端SID照合をcleanup専用、未達/新SID配達を分離 | §5.4/5.5 |
| RV-60 | D-51のリスク受容で決着。外部非露出の証明ではない | §0/8 |
| RV-62 | 採用。Z登録完成とSecret資格情報/履歴を保護 | §5.6/T-3 |
| RV-63 | 採用。D-53 Bと改訂済みADRを入力にする。A2/A3の共通SID契約を先行 | §1/5.2、T-1 |
| RV-64 | 採用。項目ごとのaccount explicit→匿名DB→既定を1つの取得規則へ | §4.5/4.6 |
| RV-65 | 採用。旧§11〜19の逐次追記を現行§1/3〜6へ統合。旧記述は固定twelve.mdの非規範の履歴 | 本書全体 |
| RV-66 | D-54/55により方式変更。Visaでrotation、DBがcopy元、失敗は認証から分離 | §4.4/4.8、9 |
| RV-67 | one.mdに取り込まれたD-57〜59/AC52〜57を追跡。D-58の21:50改訂を最終入力とする | §3〜7/10 |

新しい要件のIDやACは発行しない。T-は本書の技術的関門であり、要件を再審議する番号ではない。

### 9.2 第0.4版のレビュー記録（履歴・原文保存）

指摘の原文は `zero.md`（2026-10-26 16:15 の Codex のエントリ）にあったが、2026-10-27 の zero.md のリセットで消した。判定の前に、引用されたコードをすべて読んで確かめた。

| RV | 対象 | 指摘 | 判定 | 反映先 |
|---|---|---|---|---|
| RV-11 | WU-2・E-8 | E-8 が D-29 以前の「拒否する」契約のままだった | 採用 | E-8 を D-29 に合わせて改訂（古い行は変えず、新しい行に書く）。入力の検証・CSRF は拒否のまま。テストを改訂 |
| RV-12 | E-1・E-2・WU-3 | `set_current_observability`（`ActorSupport`）と rescue の持ち主（`SignErrorResponses`）を外すのに、呼び出しは残していた。HTML の書き込みの `authorize!` も残っていた | 採用 | `SignErrorResponses` は残す。E-1 に `set_current_observability` を移し、E-1a（持ち主の表）・E-1b（`authorize!` と `ComPreferencePolicy` の削除）を追加 |
| RV-13 | §2.9・E-7・WU-3 | `OidcEndSessionRequest` が文字列で "visitor" を引いており、棚卸しのパターンで拾えない。境界 B で app の end-session が壊れる | 採用 | `oidc_end_session_request.rb:158` を確認。WU-3 の手順 5 に追加し、文字列の棚卸し（コマンド 4）を追加。コマンド 4 がこの行を拾うことを確認 |
| RV-14 | G-4・E-10 | Auth・Core・Warp にも Preference の更新 API とページの部品がある | 採用 | routes と `PreferenceBrowserControlsRegistry` を確認。G-4 を訂正し、§4 の再設計の条件に追加。WU-3 で com の行を MATRIX から外す（手順 5a） |
| RV-15 | E-9・E-11・AC-30 | 1 つの cookie にしても、応答の順序の逆転で古い credential に上書きされうる。原子的とは言えない | 採用 | §4 の再設計の条件に追加。E-8 に「jti はトランザクションの中で確定し、コミット後は署名だけ」を追加 |
| RV-16 | E-10・R-P-15 | Base 以外での sign-out で、Base の credential を退役させる経路がない | 採用 | `authentication_logoutable.rb:38-47` を確認。§4 の再設計の条件に追加 |
| RV-17 | §4.4・EQ-6 | Palm の RP セッションは Base の credential ではない。Base を訪れるだけでは adoption されない | 採用 | §4.4 に訂正を追記。§4 の再設計の条件に追加 |
| RV-18 | E-13・DQ-3 | Core の UI は利用者ごとの SSR をしない ADR がある。キャッシュの方針も未定 | 採用 | §4 の再設計の条件に追加 |
| RV-19 | §4.5 | 子レコードの種類の一覧が Shared と actor-local で共通なので、Web Push を Shared だけに足すと壊れる | 採用 | `preference_class_registry.rb:7-19`、`preference_base.rb:179-194`、`preference_resource_sync.rb:44-51` を確認。§4.5 に前提の修正を追加 |
| 補足 | E-7・WU 表・AC-3・WU-4 | 省略時の推論を残す。WU-9 と WU-E の前提を明示。EQ-1 による AC-3 の例外。環境の確認はテストにせず evidence に記録する | 採用 | E-7 に追記。WU 表の前提を修正。one.md AC-3 に例外を追記。WU-4 の boot 確認を evidence の記録に変更 |
| RV-20 | E-18 | 世代番号では要求の成否が分からない | 採用 | まず「求めた状態になったか」を確かめる契約に改めた。その後 EQ-12 で E-18 が Base の画面への移動になり、成否は通常の応答で分かるようになった。one.md AC-37 |
| RV-21 | E-9・D-32 | assurance は利用者に結び付いていない。差し込みと再生ができる | 採用 | E-19 を追加（用途の制限、Base の GET での修復、前提の記録）。one.md AC-36 |
| RV-22 | one.md の AC | 受入条件が旧 JWT 方式のまま | 採用 | one.md の R-P-9・AC-20〜30 を改訂し、AC-20b を追加 |
| RV-23 | E-10・E-13 | sign-out の退役も書き込みで、「Base だけ」と矛盾 | 採用 | E-13 に唯一の例外と権限の範囲を書いた。one.md D-32・AC-24 |
| RV-24 | E-18 | token なしの入口がルールと Base の CSRF の設定に合わない | 採用 | G-12 を確認。今の設定では Rails が拒否する。EQ-12 でオーナーが例外を作らない方式を選び、E-18 を Base の設定画面への移動に改めた |
| RV-25 | one.md D-22 等 | sign-in の同期の範囲が古い | 採用 | one.md の D-22・R-P-15・AC-27 を改訂 |


---

### 9.3 第0.23版・Codex実行前の設計レビュー（one.md非改変）

| 優先 | 指摘 | 本版での処置/なお必要な証明 |
|---|---|---|
| P0 | §4.4ではsigning時のrollbackとDB commit後のcookie発行が混在し、resetの旧行退役も手順として不明確 | 署名/3枚の準備→S commit→Set-Cookieを分離し、reset/sign-outの行の世代交代を共通writerへ明記。atomic HTTP配送は主張しない |
| P0 | §6.7の「Root直前再検証」だけでは検証後〜T commitの競合を止められない | Z actor lockをRoot commitまで維持する案とlock順/障害注入をT-13で関門化 |
| P0 | D-58のOTP送信と、送信「意図」をcommitする設計が一致するとは限らない | 外部受付/世代/進行の結合をT-12へ。DBとSMTP等の原子性は仮定しない |
| P0 | D-53 Bの同時初回/欠損SIDについて既存lineageで同一browserを証明できない | T-1の未証明を維持。CookieやsessionStorageの新設を決定済みにしない |
| P1 | 非Base/VisaのGETが無効なDomain cookieを削除すると「公開鍵で読むだけ」と衝突する | readerはSet-Cookieせずfail-closed、writerでの削除とAC-26との解釈をT-11へ |
| P1 | regionをVisaが匿名行へ反映するように読める。R-P-24/26の列/legacy棚卸しが実装差分として不足 | region自体は反映0、固定4表示項目のみ各explicitで反映。legacy/NULL列はWU-7/9とT-10へ |
| P1 | 親のないsign-upのCancel入口と、Visa GETをwrite-freeにしたままprompt=noneを成立させる経路が未証明 | T-3/T-7を明示し、架空の親/隠れたGET writeを禁止 |
| P1 | OQ-11のHTTP表とXDB台帳がendpoint/全commit境界の網羅を保証していない | T-7/T-4、全commit直前/直後の故障試験へ。unknown route/writerを0として閉じる |
| P2 | WU-0のテスト基準がHEADなのかD-34の基準commitなのか曖昧、A13のORG年齢判定も抽象的 | b6の実行結果とHEADを分離。ORG招待条件と0歳1日判定を独立ANDで設計 |

**第0.23版時点の判定（履歴）:** T-1〜13を関門化した。第0.24版では§9.4/11/12で方式と残る境界へ分解した。どちらも実装着手許可・テスト合格・外部接続承認とは扱わない。one.md第4.2版に矛盾・達成不能が確認された場合は、two.md側に記録してzero.md経由で照会し、one.mdを編集しない。

### 9.4 第0.24版での処置（当時の判定・履歴）

B-01/02に関する未決/推奨は当時の記録。第0.25版では§9.5/11.2の確定版追補が置き換える。

| 指摘/設計課題 | 判定 | 反映先 |
|---|---|---|
| 詳細設計に未決の技術方式を残しすぎている（T-2〜11/13） | 採用 | §12で採用方式、処理/commit順、失敗結果を固定。§11は実行確認とB-01/02へ分離 |
| 過去案が実装本文に混在する | 採用 | 重複履歴付録Hを除去。固定したtwelve.mdを参照。§9.2の原記録と§10のQA IDを保持 |
| WUから実ファイル/差分/検証へ辿れない | 採用 | §3に加え付録Fのcontroller action/下位writer集合、付録Sの全Preference表/NULL列を追加 |
| Rootの版検査後に資格情報が変更され得る | 採用 | §6.7/12.6でZ actor lockをOP commitまで保持。単なる再読取り案を撤回 |
| 完成判定が現在statusやOP Flowに依存する | 採用 | §12.4でsource transaction内の完成receipt。直接terminateも先判定、terminalの強制昇格禁止 |
| OTP enqueueを送信済みと誤認する | 採用 | G-25を基準から確認。§12.2で実配送guard、結果不明はB-02。推測による進行を不採用 |
| SIDなし初回を既存lineageだけで一意化できる | 不採用（保証として） | G-24と§11 B-01。同じ旧SIDなら直列化できるが、共通識別子のないHTTP要求の同一browser判定はできない |
| one.md/twelve.mdを編集して接続問題を解決する | 不採用 | 固定入力のままB-01/02とAC読み替えを提示。今回はzero.mdも編集しない |

### 9.5 第0.25版：ClaudeレビューRV-68〜70への応答

| 指摘 | 判定 | 根拠/反映先 |
|---|---|---|
| RV-68 / B-01 | 採用・要件上解決 | zero.md 23:00のオーナー承認とone.md AC-53追補。G-24のattach/redeem照合を基準で再読。初回は余分な行を許し、現在Cookieによる旧対象の409/期限purgeを§5.2/10.6/11.2/12.1へ。通常の同SID競合のCASは維持 |
| RV-69 / B-02 | 採用・要件上解決。旧①の世代破棄/強制再開始は撤回 | one.md D-58追補。G-25のissuer/adapter/実配送guardを基準で再読し、enqueue/受付/実配達を区別。発行/進行commit先行、失敗/結果不明も進行維持、再送/Cancelを§5.1/6.2 XDB-14/10.8/11.2/12.2へ |
| RV-70 / D-56の追跡 | 採用 | 第0.24版§7.3にはD-54/55/56/57の集約行があったがD-56単独の識別性が不足。D-49〜59を個別行に展開し、400日/GET延長0/purge/rotationへの参照を§7.3へ |

入力one.mdは第4.2版のまま、D-58/AC-53/§13の追補によってhashが変わったことを実差分で確認した（§0）。レビュー提案そのものを権限とせず、正本へ反映されたオーナー決定を採用する。コード/DB/環境を変更せず、今回もtwo.mdだけを編集する。

## 10. sign-in・sign-up QA（参照番号と既存IDを維持）

one.mdが参照するtwo.md §10を維持する。実施対象はappとORGの対応する経路、comは撤去対象。
下記は未実施の試験設計。three.mdのTCはClaudeの再開後に対応付ける。

### 10.1 比較する状態

P0=options前、P1=challenge発行後、P2=署名/入力確認後、P3=Root/evidence/MFA/上限待ちの結果。
D-58により**PasskeyのP1ではceremonyを進めない**。challenge自体の発行/消費と、方式の進行を別にassertする。
各試験はFlow/ceremony/親/binding、credential消費/利用記録、Root/RP token/監査、Rails session/auth_sid/最終Set-Cookie/DBSCを比較する。
失敗した場合もRoot0と、正当な手続きの継続可否を別々に確認する。private methodを直接試験しない。

### 10.2 Passkey（旧T-PK IDを保持）

| ID | ケース | 現行の期待 |
|---|---|---|
| T-PK-1 | options後にdialog取消 | challengeは発行されるがceremony未進行。Back/Switch可。Cancelは別の正当な終端操作 |
| T-PK-2a | 未登録メールの識別子 | optionsは非列挙、確認は401、Root/evidence0。ceremony未進行、必要なら新challengeで再試行 |
| T-PK-2b | 未登録電話識別子 | 2aと同じ。OTP登録有無を明かす案内にしない |
| T-PK-3a | 署名不正 | 401、未進行。消費したchallengeを再利用させず既存の再試行経路へ |
| T-PK-3b | UV=false | UV必須の境界で拒否、Root0、未進行 |
| T-PK-3c | UP=false | 既存UP契約で拒否、Root0、未進行 |
| T-PK-3d | sign count逆行/zero/同値 | verifier契約の同値分割、失敗でRoot/ceremony進行0。counterを都合よく補正しない |
| T-PK-4 | 署名/適格性成功後に上限/MFA/後段拒否 | 進行済み。Root/evidence/MFA/上限を区別。同じ初期ページは409。消費した証明は復活不可 |

署名前のactor停止、非ACTIVE資格情報、所有不一致、連絡先不足は未進行で拒否。試行上限の新設はBL-26で範囲外。

### 10.3 P3の境界

通常成功はRoot commitと成功監査/cookieが一致。OIDC evidenceだけは未ログインのままVisa継続。
MFA/上限待ちは仮tokenを発行しない。限界解決とCancelを別接続で両順に固定する。
証明取得後のcredential_version変更、停止、親Cancel予約、Admission置換、期限一致の各点でRootを拒否する。版再確認とRoot commitの間に別接続からcredential更新を挟み、Root側が同actor lockを維持しているかを決定的に再現する（§12.6）。

### 10.4 Secret（T-SC）

| ID | ケース | 期待 |
|---|---|---|
| T-SC-1 | 誤り/欠損/不正形式 | 422、Secret消費/Flow進行/Root0、正当session不変 |
| T-SC-2a | メール識別子不一致 | 誤りと同じ外向応答。登録状況を明かさない |
| T-SC-2b | 電話識別子不一致 | 2aと同じ |
| T-SC-3 | 正しいSecretの後で同じページGET | 409、無変更/固定本文/最終header。Secretは使用済み |
| T-SC-4 | 消費後の上限/衝突/拒否 | 「Secretが誤り」のformへ戻さず正しい結果を返す。Rootがないなら成功表示しない |

### 10.5 sign-up（T-SU）

T-SU-1は既存の総称を維持し、電話の1aとEmailの1bに分ける。

| ID | ケース | 期待 |
|---|---|---|
| T-SU-1a | 電話OTP送信後に方式画面へBack | 409/D-52、正当なOTP確認要求は現在状態で継続判定 |
| T-SU-1b | Email OTP送信後にBack | 1aと同じ |
| T-SU-2 | 進行前の初期画面 | 200、親がある場合Cancel/Switch。直リンクでintentを切り替えない |
| T-SU-3 | 正常/不一致のGET/HEAD | DB認証状態不変。不一致は認証Cookie/DBSC0。初期ページ表示が勝手に保留actorを作らない |

登録完成→親未finalizeのCancelではaccount/資格情報/履歴を保護し、Secret lifecycle job後にも同じ。親を持たないsign-upの生成を残さないようconstructor/callerを§12.4の契約へ揃える。未結合入力は生成前に拒否し、既存未結合データは削除対象と推測しない。

### 10.6 409・Cancel・置換の公開境界

1. 新tab Bの正常応答後に旧tab Aの409を適用し、Bが継続できる。Aにはsession/auth_sid/DBSCの発行なし。同じ旧SIDの同時受入は一方だけ成功させる。SIDなし初回だけはAC-53追補に従い余分なadmitted行を許し、最後に残る共有Cookieで両tabから要求し、一致対象だけ進行、他方409/無変更、期限後purgeを確認する。
2. 無効Cancelは何も消さない。正当Cancelは親予約→reset/削除。同対象再送で未達片付け、新SIDなら旧handoffの配達だけ。
3. Cancel/register/finalize/置換を逆順で固定し、terminal復活/二重成功がない。
4. 同ブラウザの新Admissionは旧ceremonyを置換し、別surfaceは置換しない。失効/使い回し/foreign Admissionは変更0。
5. 同じ初期ページ再読込は409、Forward先は現状態で判定する。bfcacheの表示だけではサーバーでの受理の証拠にしない。
6. expiryとpurge保持期間は直前/一致/直後、参照あり/hold/並行書込みの組合せを確認する。

### 10.7 socialのBack・理由別案内・新しい開始

| 局面 | 期待/担当 |
|---|---|
| providerへ送り出す→callback前にBack | Google/Apple sign-in/signupは未進行。初期画面を表示し、R-AU-49の再開始/Switchを許す。A2/A3 |
| 再びprovider開始 | state/provider/nonceを新世代に置換。旧callbackは拒否。別のEmail/telephoneでFlowができた後も拒否 |
| provider確認済みL1/L2 | 理由と正しい入口を案内。失敗したattemptは継続/自動切替しない。A9、AC-56 |
| 案内後にBackして別の入口を選ぶ | 新しいRP起点のAdmissionとして扱える経路を設計する。古い画面/旧stateを復活させる例外は足さない。D-52の409を200へ変える根拠にしない |
| 成功callbackでFlow/evidenceが進んだ後にBack | 初期ページは409。進行済みのSwitchを許さず、Cancelは親finalize前の合法状態だけ |
| 入れ替わった親/他tab/古いcallback | subject/親/ceremony/binding/世代を照合し、正当な新手続きを変更せず拒否 |
| ORG Entra | 1段目成功で進行。自己登録を追加しない。未登録/利用不可の案内範囲は既存ORG policyとR-AU-23を比較 |

OTP要求時は宛先を入力できるだけで本人とはいえないため登録有無を同じ応答にする。
social案内は、そのproviderアカウントで認証でき、今回の要求に結び付いたsubjectについてだけ行う。
provider account/sessionの侵害まで防げるとの主張や、毎回パスワードを入力させる要件にはしない。
前会話の「sign-in→sign-out」はsocialの反対入口へのSwitchと同一視せず、実際のSign Outは§6.5の既存認可/CSRFで扱う。

### 10.8 OTP進行先行・送信障害の公開経路

D-58追補/RV-69、AC-40/51とR-AU-43の検証を既存QAへ追加する。新しいAC番号は作らない。

| 注入点/要求 | 公開結果と状態の受入 |
|---|---|
| 発行/進行commit前の認可/入力/期限拒否、OP commit失敗 | 新進行/送信/queue0。既存状態は不変。正当な既存OTPの有無を一律に消さない |
| OP進行commit後のZ cooldown/監査commit失敗、enqueue前停止、enqueue拒否 | 進行済みを維持、Switch/古い画面は409。再送と正当Cancelは使える。全再開始/世代破棄を強制しない |
| enqueue済み/送信前、送信明示失敗、送信結果不明 | 進行済み、親/世代/元期限を維持。同期失敗は503で再送/Cancelを案内。async job失敗は元の応答を遡って成功/失敗へ書き換えず既存障害記録を残す |
| transport受付成功後にjob停止、配達済みだが結果不明 | 現行世代の正しいcodeは通常の所有/期限/試行制限で確認できる。配送成功receiptを認証の必須条件にしない |
| 利用者の明示再送 | 既存cooldown/rate/期限を再確認し新世代をcommitしてから送る。旧code/旧配送jobは無効。再送でceremonyを初期状態へ戻さない |
| Cancel/置換と配送jobの競合 | Cancel/置換先行なら旧jobのguardは送信0、OTP確認0。配送guard先行なら有限timeout内で送信境界を出てCancelが確定し、届いた旧codeでも認証再開0 |

Email sign-in、Email/telephone signup、実在/dummyの同値分割で確認する。DB別接続のbarrierで「進行commit前/後」「Cancel先/配送guard先」「再送先/旧job先」を固定し、sleepによる偶然の並行実行を合格証拠にしない。

## 11. 設計の完了条件・実施前の確認

§12と付録F/Sが実装の指示であり、T-1〜13を以下へ分解する。B-01/02はone.mdの承認済み追補で要件上解決し、未決として実装を止める扱いは撤回する。設計の採用は実装・migration・環境適用の許可ではない。one.mdをCodexが変更することもない。

### 11.1 旧技術関門の処理

| 旧ID | 本版の結論 | 残る実施時の確認 |
|---|---|---|
| T-1 | 通常はSID照合＋旧SID lock/CAS。SIDなし初回はAC-53追補の余分な行を許し、現在Cookieと不一致の対象は409（§12.1） | cookie到着順、旧対象の到達不可、期限purgeを公開HTTPで確認 |
| T-2 | 読取り事前判定＋最外側のexact cookie filter（§12.3） | 実middleware列、3拒否口、Rails自動Set-Cookieも含む無変更比較 |
| T-3 | Z登録完成receipt＋既存jobの先判定（§12.4） | 全source writer/直接terminate、合法complete、完成後停止の試験 |
| T-4 | 全writerを用途別manifestへ割付け、未知経路はguard失敗（§12.6/付録F） | 新差分のcall-site閉鎖、AC-44。静的分類を実行成功と呼ばない |
| T-5 | 固定issuerと型付きsubjectの往復、Base local session所有照合（§12.6） | 全issuer/client/realm・他owner拒否のHTTP試験 |
| T-6 | RP grant単位のrevoke、local先行、2秒以内の要求内再試行（§12.6） | 元の親absolute expiry、別browser不変、HTTP飽和試験 |
| T-7 | 既存authorize POSTへ継続を統合（§12.5）、adapter表は付録F | prompt=none、response_mode、再送、form/API status |
| T-8 | 既存鍵設定のrealm別issuer namespace、reader公開鍵配布（§12.7） | 実鍵の配置・外部repo SHA/対象ファイルは段階5の入力票。実環境の安全性は未検証 |
| T-9 | 今回の再現可能な参照集合を撤去基準にする（付録E/I/F）。元595行は復元済みとしない | 未提供の旧出力との差分は未検証。Warp公開actionを対象経路で実行し、認証参照が残ればWU-3未完了 |
| T-10 | schema差分は付録S、migration順と回復は§12.8 | 実測件数、snapshot、復元所要時間と破壊的操作の別承認 |
| T-11 | 最新D-54のreader限定を採用。cookie削除はBase/Visaのみ（§12.7） | AC-24/26の旧文との対応をレビュー対象として明記。one.mdは編集しない |
| T-12 | D-58追補どおり世代発行/進行commit→送信。失敗/不明も進行維持、既存再送/Cancel（§12.2） | commit前送信0、kill/timeout、再送/Cancel/世代検査を§10.8で確認 |
| T-13 | Z actor lockをT Root commitまで保持、version単調更新（§12.6） | 別接続のcredential更新を前後両順で固定。lock待ち/rollbackも試験 |

### 11.2 B-01/02の解決記録（オーナー承認済み）

| ID / 対象WU | 確定した契約 | 実装/受入で守ること |
|---|---|---|
| B-01 / WU-A3、RV-68 | one.md AC-53追補。Cookieなし初回の競合で余分なadmitted ceremonyが残ることは許容。最後に残るauth_sidで進める対象は一つ | 表の行数だけを一意性の判定にしない。余分な対象への後続要求/遅延callbackは現在Cookieとの不一致で無変更409、旧参照から復帰0、期限後purge。通常の共通SID置換はCASで一方のみ受理 |
| B-02 / WU-A2、RV-69 | one.md D-58追補。OTP発行/進行commitを送信より先に確定。失敗/結果不明も進行済み、既存再送またはCancelを使用 | 送信済みなのに未進行という順序を作らない。配送成功を進行/OTP検証の必須条件にしない。失敗で巻戻し/世代破棄/強制再開始/新補償を追加しない。新世代は明示再送、終端は既存Cancel/置換/期限等の正当な操作でのみ扱う |

第0.24版のB-02①（世代を捨てて再開始）は不採用として履歴に残し、現行設計から除いた。両件の承認根拠はzero.md 2026-10-28 23:00とone.mdの確定版追補/§13。新しいAC番号を発行せず、既存AC-40/51/53の試験へ具体化する。今回はtwo.mdのみ編集し、zero.md/one.md/twelve.mdへは書き込まない。

### 11.3 批判的自己レビュー

- Domain JWTの差込みと遅延応答は防ぎ切れると主張しない。表示ずれは許すが、binding不一致・retired行・古いjtiで同意/Push/保存権限を得られない。
- 409の最終filterはDB rollbackの代替ではない。事前の副作用停止とexact認証header抑止を両方試験する。Cancelで新SIDを消さないことは、正当Cancel時reset必須の例外を新設するのでなく、同一対象でない再送をcleanup操作にしない設計である。
- Z登録完成receiptは新しいshape提案。完成済みaccountを保護するための事実記録であり、未承認の補償/再開を追加しない。Z commit後のOP失敗で完成事実を撤回しない。
- RootのZ→T保持は短いDB処理に限る。外部provider検証・メール送信・revoke HTTPをこのlockへ入れない。相互lock順違反が一件でも残ればAC-44/55未完了。
- prompt=noneの自動POSTは画面上の入力を要求しないが、JS/CSP/CSRF/Originで成立することを公開経路で検証する。GETへPreference writeを戻す回避策は認めない。
- 初回競合の例外はブラウザのCookie到達順を観測する契約であり、全admitted行数の一意性を証明するものではない。非同期jobやVisa継続を含む各writerの親/ceremony/世代照合を省略せず、他hostへAuthのhost-only Cookieが送られると仮定しない。迂回が試験で見つかればAC-53未達として止める。
- OTPは進行commitを外部callより先に終えるため、外部結果不明で進行を失わない。既存配送guardの失効検査は維持し、結果不明だから正しいcodeも拒否する旧案を残さない。
- 本文は静的設計と検証計画であり、アプリ/DB/ブラウザ/外部repoの実行結果を含まない。実装時の合格証拠と承認票が揃うまで本番適用可とはしない。

**実装可能性の判定:** B-01/02による要件上のblockerは解消した。本書の方式で実装へ進める設計として扱う。ただし実装許可ではなく、公開HTTP/ブラウザ/別接続の競合・障害試験、schema/ADR/破壊的操作と外部適用の承認は未実施/未取得。静的設計だけで全経路の安全性が実証されたとは判定しない。

## 12. 採用する処理・差分・検証の詳細

この節の方式はすべて【設計P】。G-は基準コードの事実、D/R/ACはone.mdの確定契約として区別する。旧版の「案」「第一候補」「後で方式を決める」は本節の範囲で置き換える。

### 12.1 Admissionのattach・確認・redeem・置換

G-24: `app/controllers/auth/{app,org}/ceremony_bindings_controller.rb:62-84,107-113`は、SIDがなければattach用sessionを発行し、bindingをそのsessionに結合する。`app/controllers/concerns/auth_ceremony_admission.rb:191-216`はredeem時に提示SIDとattach先sessionの一致を要求する。モデルのrotate単体がSIDなしで動くことを、公開経路がSIDなしで認証を受け入れる証拠にはしない。

| 入力/状態 | lock下の処理 | 結果/副作用 |
|---|---|---|
| 未attach、有効SIDあり | 当該SID→bindingの正規順でlockし所有/期限/用途を確認、attach | Base/Visaの既存確認画面へ。SID発行なし |
| 未attach、SIDなし | 認可済みbindingだけにbootstrap SIDを発行/attach | 既存host-only auth_sidを発行し確認へ。これは未admit、Root/evidenceなし。独立した同時初回attachから余分な行が生じることはAC-53追補で許容 |
| 確認POST | Base/Visaの既存nonce/本人/CSRFを検証、bindingをconfirmedへ | opaque参照でAuthへ。nonceの使い回しを追加しない |
| redeem、提示SIDとattach先が一致 | Zを必要とする場合は先にactor lock。OPでは旧SID→親→binding/Flow→proofの正規順で再検証し、新sessionと新bindingへの遷移を一つのOP transactionへ | commit後に新SID発行。前sessionとそのbindingを置換済み終端へ。旧親は期限へ |
| 旧SIDへの同時redeem | 同じ旧SID lockで一方だけ世代CASに成功 | 後着409、認証DB/cookie変更0 |
| SID不一致/期限切れ/取消済みbinding | 書込み前に拒否 | 409、対象も現行SIDも変更しない |
| 新SIDで同じredeem再送 | 既存bindingに記録済みのadmitted sessionと一致する場合だけ同じ継続先へ | rotation/新規session/期限延長0 |

**lock順の統一:** singleton置換では旧SIDが他親の所有者にもなるため、通常操作も`Z actor→OP browser SID→親→Flow/binding→proof`に統一する。複数SID/親を取る場合は各階層の主キー昇順。SIDを持たないpurge/取消配達は新SIDを取りに戻らず、対象親以下だけで閉じる。§5.4の親先行表は「SID lockの内側の順序」として読む。旧SIDから新SIDへ辿る認証fallbackを作らない。

**検証:** 同SIDの2 AdmissionはA先/B先の両順で片方だけ成功。SIDなし初回は異なるbootstrap SIDが両方redeemされた場合も作り、両応答のSet-CookieをA→B/B→Aで適用して、最後のCookieが指す対象だけ進行することを両tabから確認する。余分な行の対象URL/POST/provider callbackは409、認証DB/Set-Cookie/DBSC不変、進行/Root発行0、元の期限後purge。同じSIDの同時受入と初回例外の受入条件を混ぜない。attach後のCookie消去/差替え、別surface、期限前/一致/後も検証する。

### 12.2 OTPの発行・配送・進行

G-25: `app/operations/email_sign_up_otp_delivery_issuer.rb:17-28`はnotifier発行後にenqueueを記録する。`telephone_sign_up_otp_delivery_issuer.rb:17-32`のacceptedは`app/adapters/otp_telephone_adapter.rb:51-53`の`OutboundSms.deliver_later`の結果であり、利用者への実配達の証明ではない。`app/models/concerns/auth_email_otp_challenge.rb:100-129`には世代/親/宛先/コードを実配送前に検査するguardがある。

**採用順序（D-58追補/RV-69）:** 検証→OPでOTP世代発行＋ceremony進行をcommit→既存queue/送信adapterへ渡す。利用者への配達成功・enqueue成功と、進行確定を同一の事実として扱わない。

1. Z actor/連絡先→OP SID/親/Flow/OTPの正規順でlockし、Sentry、本人/宛先/対象、親のCancel予約なし、active、期限、cooldownを確認する。検証拒否は世代変更/進行/送信0。
2. **OTP世代発行と当該ceremonyの方式開始を同じOP transactionでcommitする**。既存named writerに集約し、progressをcontroller/jobから直接代入しない。初回は開始前→開始済み、再送は開始済みのまま新generationを確定する。OP commit完了より前にnotifier/adapter/jobを呼ばない。Z側の既存cooldown/監査変更がある経路は、OP commit後にZの変更をcommitしてから配送へ渡す。Z失敗なら送信0/依存障害とし、既にcommitしたOP進行は維持する（XDB-14）。これでSwitchは閉じ、前の方式画面は409になる。real/dummyも同じ公開進行にし、存在しない宛先からRootは発行しない。
3. commit成功後にlockを解放し、既存の配送queue/adapterへ当該親/ceremony/flow/generationに結び付く情報だけを渡す。commit後〜enqueue前の停止で送信が始まらなくても、進行済みのまま再送/Cancelを使う。新outbox/配送補償/自動の全再開始は作らない。
4. Email/telephone/sign-in/signupの**実配送adapter直前**は既存guardを正規lock順へ揃え、進行済みであること、現世代、同じ親/ceremony、未取消/未置換、元期限、宛先/codeを再確認する。古いjob/失効対象は送信0。guardとCancel/明示再送は同じowner lockで直列化する。外部callは既存adapterの有限timeout内だけとし、外部結果を得るために進行transactionを開いたまま待たない。送信guard内で進行を新たに確定する実装は作らない。
5. enqueue/外部送信が明示失敗または結果不明でも、進行・現世代・元期限を維持する。同期要求の依存失敗は503として既存の再送/Cancelを案内し、配達成功と報告しない。非同期jobの失敗は既存の障害記録/再試行規則に従う。元の応答がqueue受付済みだったことを配達済みと読み替えない。失敗だけを理由にOTPを破棄しないため、結果不明でも実際に届いた現行codeは通常の検証に使える。
6. OTP確認は現親/ceremony/世代/所有/期限/試行制限とcodeの一致を検査し、**配送成功receiptを認証の追加必須条件にしない**。利用者の明示再送では既存cooldown/rate/親期限を再検証して新世代をcommitしてから送信し、旧code/旧jobを失効させる。Cancel/置換/期限切れが確定した旧世代から認証を再開しない。再送によって方式開始前へ戻さない。宛先/OTPの生値を追加ログへ出さない。

| 障害/競合点 | OPに残るもの | 送信・公開結果 |
|---|---|---|
| 発行/進行commit前、commit失敗 | 新世代/新進行なし | 送信/queue0。依存障害503、既存の正当状態を維持 |
| OP commit後のZ cooldown/監査commit失敗、enqueue前停止/queue拒否 | 現世代＋開始済み | 未送信もあり得る。進行は戻さず、既存の再送/Cancel |
| 外部の明示失敗/timeout/受付成功後停止 | 現世代＋開始済み | 配達成否は別記、成功を偽らない。同期失敗503。全再開始/世代破棄を強制しない |
| 旧jobより明示再送が先 | 新世代＋開始済み | 旧job送信0、旧code拒否。新世代もcommit後に送信 |
| 配送guardよりCancel/置換が先 | 既存の終端/置換状態 | 旧job送信0、旧code認証0 |
| 配送guardが先、Cancelが後 | 開始済み→正当Cancel終端 | 既に外部受付された送信は取り消せないが、Cancel後にcodeが届いても手続きは復活しない |

**障害注入点:** 発行/進行commit前・後、enqueue前・後、job起動前、transport受付前・後、HTTP応答前。commit前の外部送信0を公開操作から確認し、別DB接続でSwitch/Cancel/再送/旧job/OTP確認の先後を固定する。§10.8の結果を全対象OTP経路で確かめる。新しい配送状態のqueue/outbox/自動補償は追加しない。

### 12.3 409とCancelのrequest/response境界

`Auth::{App,Org}::ApplicationController`とVisaのphase判定を所有する具体classにcallback順を宣言し、共有concernの`included do`で順序を隠さない。追加する`lib/auth_phase_refusal_response_boundary.rb`【P】は`config/application.rb`で**ActionDispatch::Cookiesより外側**へ挿入し、session/cookie middlewareが返した最終headersを扱う。request-localの専用印はcontrollerだけが立て、client header/paramsは参照しない。phase409を返すAuth/Visaの両hostを対象とし、Visaで親/世代不一致を返した応答もCookieStoreの自動更新で正常な認証を上書きさせない。一般のBase/RPやprotocol errorへこの印を拡張しない。

| 順序 | 所有者/処理 | D-52拒否時 |
|---|---|---|
| 1 | host、request size、既存rate、CSRF/Origin/Fetch Metadata。providerの既存例外は専用検証 | 既存拒否形式。state409へ一律変換しない |
| 2 | read-only対象解決＋全auth action分類＋phase/owner/expiry判定 | session/Actor refresh/locator cleanup/DBSC/Cookie復旧を呼ぶ前に共通private responderで409 |
| 3 | Sentryと認可、必要lockを取得し条件再確認 | 失敗ならDB mutation前に409/既存停止応答 |
| 4 | 当該writerだけで遷移commit、必要な通常session/cookie操作 | 正当Cancelだけreset_session＋SID削除。拒否と共用しない |
| 5 | CookieStore/Cookiesによるresponse commit | 自動更新cookieも最終filterへ渡る |
| 6 | 最外側response boundary | phase拒否印＋409の場合、当該hostのexact認証cookieとAuth DBSC headersだけを除去。Locationなし/no-store/HEAD body0を保証 |

期限読取りが暗黙にexpired/failedへ書き込む既存state-machine評価も事前判定から除く。拒否要求を自動終端化jobとして使わない。

filter対象cookieは`__Host-session`、`session`、`__Host-auth_sid`、`auth_sid`、`__Host-auth_access`、`auth_access`、`__Host-auth_refresh`、`auth_refresh`、`__Host-auth_dbsc`、`auth_dbsc`のexact集合（当該Auth/Visa hostのみ）。所有定義は`JitSessionCookieConfig`、`AuthCeremonySidCookie`、`AuthenticationCookieName`。DBSC headerは`Secure-Session-{Registration,Challenge,Id,Response,Skipped}`および`Sec-Session-{Registration,Challenge,Id,Response,Skipped}`のexact集合、所有定義は`AuthIoKeys::Headers`。一般のAuthorization headerをresponseから一律除去する設計にはしない。`Set-Cookie`はRackの配列/複数headerとして解析し、Expiresの日付のcommaでsplitしない。cookie名の完全一致で除去し、他hostのCookieや全headerを消すwildcardは使わない。

`session.options[:skip]`はphase409時に設定するが、最終filterの代用にしない。`SignInPathRefusal`のcontinuity削除、`SignInPhaseBindingControllerSupport`、`SignUpFlowEntry`の三拒否口は同じprivate responderへ寄せ、明示的な許可操作以外でsession mutationを行わない。filterが異常で完全に検査できない場合は認証cookie付き409を流さず、認証Set-Cookieを生成しない固定500へ閉じ、障害を記録する。

**Cancelの結果不明:** 親予約のcommitが応答より前なら取消確定。reset/cookie到達は独立の片付け結果。古いSIDを送る同一対象の再送だけcleanup-only検索し、新SIDなら削除0。既にconsumedなら409。Rails cookieの再送でserver terminalをactiveに戻す経路を作らない。

**公開試験:** 正常タブのcookie/OP全行snapshotを取得し、旧タブ409を遅延配達して正常タブで次の正当POSTが成功することを確認する。固定文言/Content-Type/Cache-Control/Location/Set-Cookie全値/DBSCを検査し、単にreset_session未呼出しをmockする試験にしない。

### 12.4 登録完成の帰属・合法な後段処理

sourceの完成事実を現在のaccount statusだけで判定しない。新規【P】`ClientRegistrationCompletion`（app Zenith）とORGの登録を完成させる同型recordは、**完成する登録が実在するrealmにだけ**置く。OPを参照するFKは作らず、不透明な`sign_up_flow_ref`を保存する。

| column/制約 | 設計 |
|---|---|
| actor FK、public_id、sign_up_flow_ref、method、completed_at | 全てNOT NULL。actor/flow_refは各UNIQUE、public_idは既存identifier規則。methodは固定reference。DB時計で時刻を決める |
| 完成証拠 | 当該Flow/actor/credential/contact/providerの照合後、source完成変更・既存監査と同じZ transactionで一度だけ作成。更新/退役で過去の完成を消さない |
| 保管/消去 | 登録取消cleanupから削除しない。将来の確定したaccount erasureは既存retention/holdを守る。新しいprivacy操作を有効化しない |

Email/telephoneのClient finalization、social signup finalizer、ORG招待登録のsource確定を対象にする。既存accountへcredentialを追加する処理では作らない。過去の未判定データからreceiptを勝手に生成しない。未完成扱いで削除できないデータは承認票で隔離対象として報告する。

**正常順:** Z actor lock→OP SID/親/Flowを正規順でlockし未取消/FINALIZING/帰属確認→OPの必要な認可消費をcommit→Zで登録・receipt・監査をcommit→lockを離した後、既存後段jobがZ receiptを先に読む→OP Flowの`FINALIZING→COMPLETED`を完成receipt専用の入口から既存complete writerで確定（generic evaluateの自動expireより先にreceiptを照合。完成時刻が当時の期限内であることを検証し、現在時刻による未完成化をしない）→既存sign-up→sign-inへ合流。親取消が後から確定しても完成登録を消さない。Z commit前に親取消が先行した場合は登録をcommitしない。未完成cleanupと自動expireもZ actor→OP親/Flowでreceiptを先判定し、完成済みFlowをexpired/cancelledにする競合を防ぐ。

**Z commit後〜OP記録前のCancel:** 親のみCancelし、既存後段jobはreceiptから完成を認識して合法completeを先に処理する。完成FlowをCANCELLEDへ変えず、今回の親ログインは終端のまま。Secret jobのcomplete/terminate分岐と`retire_signup_batch!`の直接入口も先にreceiptを検査し、完成済みなら保留資格情報を破棄しない。`complete_sign_up!`の既存「Flow completed必須」はFlowを合法completeしてから満たす。expired/cancelled等からCOMPLETEDへ強制昇格しない。receiptあり・矛盾する既terminal Flowは不変条件違反として削除を止め、errorを残す。

**CancelとZ commitの窓:** source finalizerがZ actor lockを保持する間、Cancel本体はOP親予約だけで確定できる。Z commitの直前に親をlockして再確認し、**その親lockをZ commitの成否確定まで保持する**。実装は二段に分ける。第1段はZ actor lockの下でOP認可を消費commitしZの変更なしで解放する。第2段はOPの読取りtransactionを先に開くがまだlockせず、その内側のZ transactionでactorをlock/reload→OPのSID/親をlockし第1段の消費帰属/未取消/版を再検証→Zの登録/receiptをcommit→外側OPの読取りtransactionを終了する。**transactionの開始順とrow lockの取得順を分け、Z→OPのlock順を守る**。OP読取りtransaction内で新たな認可消費/状態更新はしない。Z rollbackなら許可は消費済み/未登録として止め、補償ログインしない。Cancelが後ならreceipt保護が働く。独立DBの原子commitとは主張しない。

**親のない登録:** sign-up開始はAdmissionのauthorization parentへ必ず結び付け、未結合Flowを作る入口を残さない。Step-Upのcredential追加はsign-upと分類しない。既存の非HTTP呼出しもparent_ref必須のconstructorへ変更し、呼出し元を付録Fのguardに含める。親を捏造して穴を埋めない。

**検証:** Email/telephone/social各source commit直後の停止、完成後の停止/連絡先release、親Cancel先行/登録先行、job重複/直接terminate、別Flow/別actor receipt、未完成のみ破棄、完成資格情報/監査不変。新recordの追加はshapeレビュー対象であり、本版でDB作成はしない。

### 12.5 Visaの既存POSTへPreference確定を接続する

G-27: `config/routes/visa.rb:55-70`にはauthorize GET/POSTとresult/cancel/switch GETがある。`app/controllers/concerns/oidc_authorization_continuation.rb:14-29`はGETから確定処理を呼び、`visa/app/oauth/authorizations_controller.rb:16-28`は既存sessionのSSOをGETで処理する。これを新方式のPreference write入口として流用しない。

**採用方式:** 新しい認証APIを増やさず、既存`oauth/authorizations#create`を同一Visa originのCSRF付きPOSTの唯一の継続commit入口にする。差分の所有者は`app/controllers/concerns/oidc_authorization_result_post.rb`。現在の`create`（基準:13-44）はstart専用なので、検証済み署名continuationの分岐を明示追加する。署名なしの既存`ceremony_action=start`は既存開始契約のままとし、継続用paramsを混ぜた開始要求は従来どおり拒否する。GET result/SSOは読取り/検証と自動送信formの表示だけ。既存cancellation/switchも対象の終端/世代を検証したcontinuationとして同POSTへ送り、操作種別はサーバーが署名したpurposeから決める。任意paramsの`operation`をdispatchしない。

| GETの種類 | formに渡すもの | POSTで行う処理 |
|---|---|---|
| result | 既存opaque result handoff＋署名purpose、Visa CSRF token | handoff/親/世代/所有再検証→Root/MFA/上限の既存確定→Root成功時のみ共通Preference sign_in→元のOIDC応答 |
| 有効sessionのsilent SSO | 検証済みauthorize入力、session参照/digest、purpose、有効期限を含む署名continuation | client/redirect_uri/state/PKCE/prompt/max_age/sessionを再検証→同じ共通sign_in→code発行 |
| cancellation | 既存cancel handoff＋purpose | 同じ親の取消確認/既存access_denied配達。Preference sign_inなし |
| switch | 既存switch handoff＋purpose | 共通SID/世代/開始前を再検証し既存の新Admissionへ。Preference変更なし |

署名continuationは既存Rails MessageVerifierの専用purpose、期限はmin(親/現在sessionの期限,発行から60秒)。無親SSOはverified authorize要求の正規化hashとsession世代に結び付ける。秘密値/refresh/生provider tokenをformへ入れない。POSTにCSRF token、Origin/Fetch Metadata検証が必須で、署名だけでは代替しない。署名改ざん/expiry/別sessionなら既存拒否、phase不一致ならD-52。formに渡すauthorizeの公開protocol値は署名対象に含め二重decodeしない。

GETはno-store、frame制限、script nonce付きのローカル自動form送信だけで第三者scriptを含めない。Referrer-Policyは`strict-origin`として参照/queryを漏らさず、同origin POSTのOrigin判定を妨げない。JSなし時だけ通常の送信ボタンを表示する。prompt=noneで認証/同意入力を要求せず、認証不足なら既存login_requiredをそのまま返す。OIDCのresponse_mode/state/登録redirect_uri/Jump許可辺を変えない。HEADで自動form確定/DB書込みをしない。

Root commit済みだがPreferenceに失敗した場合はRootを取り消さず503/片側成功を記録し、code発行/成功redirectを行わない。親finalizedはRoot成立、OIDC code deliveryは別の既存一度限りの段階として扱う。再送は既存finalize再送契約で同じRootだけを使い、再ログイン監査/制限消費を追加しない。Preference保存の応答未達は§4.8の規則、初回と同じcookieを復元できると仮定しない。

**HTTP adapterの割付け:** form（emails/secrets/checks/guards）、Web JSON（passkey options/verifications、OTP resend）、provider callback（Google/Apple/Entra）、Visa継続の4種類をconcrete controllerで固定する。§6.6のtyped resultをそのadapterに渡し、serviceがHTTPを返さない。各actionは一つのadapterだけを選ぶ。未知reasonを未登録/成功へfallbackしない。social L1/L2案内は署名済み本人provider callback後だけ400の理由別HTML、新しい入口のリンクは新RP開始要求である。

**検証:** promptなし/login/create/none、認証済み/不足/期限一致、response_mode、PKCE、POST改ざん/CSRF/Origin、署名期限59/60/61秒、同参照二重POST、Cancel競合、Root後Preference障害、JS有/無とno-referrer漏えい。§1の共通契約Cとして先に設計適用し、A9の独立文言修正をA8の待ち条件にしない。

### 12.6 本人・credential version・跨DB writer・logout

**Base本人resolver:** `RpRequestAuthenticator`が検証したlocal session→anchor→identityについて、realmの固定issuer、当該Base client、subject、principal、sessionのactive状態を照合する。`OidcSubject.public_id_from(subject, resource_type:)`で型付きsubjectを解析し、対象Zの`Client.public_id`/`Operator.public_id`だけで検索する。発行者は同じ`OidcSubject.for`を使い、Baseの入力subjectとの再encode一致を要求する。現行Client/Operatorで独自oidc_subjectを追加する場合は発行/解決契約の変更として拒否し、曖昧な数値ID/メール照合をしない。取得したactorがinactive/withdrawnなら操作拒否。所有associationから対象を取り、URLのaccount_idを本人選択に使わない。OP DBは読まない。

**credential_version:** actorのbigint NOT NULL初期1。変更はactor lock内で`version+1`、同じZ transactionで資格情報/連絡先/状態/監査を確定する。登録/release/停止/再有効化/回復/管理更新/秘密情報変更/Entra/social結合変更を含む。名前/通知だけの変更は認証適格性を変えない限り増やさない。上限到達は例外、wrap/reuseしない。

proof検証前にactor/credential/版を整合snapshotとして取得し、高価な外部検証はlock外で行う。検証済み結果にcaptured版を保持する。Root/refreshの最終境界ではZ actor lock→OP SID/親/Flow/proofの正規順で再取得し、版・現在credential・停止/退会・期限を再照合する。**OP Root commitを確認するまでZ actor lockを保持する**。不一致はRoot0、古いproofで再開0。RootはZへ成功状態を書き込まないため、Z外側transactionの終了で発行の確定点を二重化しない。OP commit成否不明ならsession再発行せず依存障害として記録する。

**writer manifest:** 付録Fは対象の実ファイル集合。実装変更時の`transaction/with_lock/connected_to`と資格情報associationへのcreate/update/destroyの全呼出しを、§6.2 XDB用途＋actor lock＋versionの要否へ割り付ける。request以外のjob/retention/backfill/Enforcementも同じnamed writerを使う。既存writerを迂回する直接更新を残すことはAC-44/55不合格。static guardはsource textの一致だけで安全を証明せず、未登録のwriter追加をレビューへ出す補助として使う。

G-26: 基準`app/operations/rp_session_revoker.rb:25-32,63-75`の`:rp_session`は当該grantをstopし、他scopeのroot/identity停止とは別。`app/models/concerns/rp_session.rb:99-109,122-132,189-193`はrefresh期限をparentのabsolute expiryへcapしている。

**logout:** RP local session lockでraw refreshと発行時の親absolute期限をrequest内へ退避→local revoke commit→local cookie消去→既存Visa/revokeへ登録client認証で送信。送信timeoutはconnect/readを合わせ要求全体2秒、ネットワーク一時失敗だけ一回再試行、4xx/200を再送しない。同じlocal sessionの二重logoutは再送jobを作らない。他RP・同RP別browserのrefreshを列挙しない。revoke先は固定issuer originと既存登録path、redirect追従なし、tokenはbodyのみ。OP全体logoutの確認はその後の独立操作。

revoke未達でもlocalは失効済み。残存grantの延命は元parent absolute expiryを超えないことを既存発行/refresh writerの同じlockで保証し、infinite/欠損期限を検出したら発行を拒否する。発行済みaccess JWTの残存はlocal stop/BCL/expの既存境界。新しい永続再試行/補償は足さない。自己HTTPは有限timeoutと既存client/IP rateを維持し、Pumaが塞がった場合も2秒でlocal終了へ戻ることを負荷確認する。timeoutでOP確認に進む場合は「このRPのログアウト済み、全体の終了は未確認」の結果とする。

**競合/障害試験:** 別Z接続から版変更をRootの検証前/commit待ち/commit後に挟む。Root先行なら変更側が待ち、変更先行ならRoot0。Z/OP各commit失敗、OP親取消、refresh先行/後行、revokeの200/400/timeout/TLS/redirect、別browser維持を検証する。lock timeout/deadlockは有限に失敗させ、消費済み許可で自動retryしない。

### 12.7 Preference writer、鍵、readerの確定事項

- 共通concernはsurface分岐を所有しない。concrete Base/Visa controllerが静的なrealm用model/codec/許可operationのcontextを渡す。共通メソッドは閉じたoperation caseとtransaction/cookie順だけを所有する。registryのconstantize/動的send/role fallbackを新設しない。
- Anonymous更新はrow lock下でactive/jti/expを再検証し、毎回新jti。account saveは項目子record/explicitを同じZ transactionで更新し、Z commit後にSへ反映。別requestのZ更新の後で古いsnapshotがSへ来ることによる表示ずれは許すが、S→Zへの上書き復旧はしない。
- 署名は既存JWT鍵設定の仕組みにrealm別`preference_app`/`preference_org`/`preference_com`の独立issuer namespaceを追加し、既存OP tokenの鍵と混ぜない。algorithmはES384固定、active kid一つ、public trust storeはactive＋移行中の旧kid。秘密鍵の値はリポジトリに置かず既存の管理された秘密設定から供給する。新KMSネットワークAPIは追加しない。秘密鍵利用メソッドのcallerは共通writerのみ、他hostはpublic key lookupだけとする。同一Ruby processのコード実行侵害に対する鍵隔離を、この論理境界だけで保証するとは主張しない。
- kid/issuerをrequestから秘密設定の任意pathへ変換しない。realmの固定表で選ぶ。鍵不足はboot/利用境界の明示error、別realm/旧共通鍵へfallbackしない。reader用配布は公開鍵の固定bundleで、公開JWKS endpointを新設しない。
- rotationはreaderに新公開鍵を先配布→writerのactive kid切替→最終旧発行expまで旧公開鍵保持→削除。漏えいkidの拒否は別途承認して即時無効化、GETでDB作成しない。400日readを約束する通常rotationと緊急失効を区別する。
- AC-24/26の旧文はone.md末尾のD-54/55読み替え注記に従い、readerのSet-Cookieは発行/削除とも0、Base/Visaだけ無効共有cookieを削除する。これは最新writer限定を守る設計解釈としてレビューに提示する。オーナーが全reader削除を要求する場合は衝突を報告し、一方を黙って弱めない。

**テスト:** realm鍵6方向、kid未知/拒否/旧/新、iat/exp境界、同名Cookie重複、3KiB直前/一致/超過、S commit前署名失敗、Z commit後S失敗、cookie3枚の部分未達、host-only binding差替え/欠損、別account signin、reset/signout同時保存。clock/leewayはPreferenceの`now < exp`を緩めない。

### 12.8 実行票、migration、完了の判定

| 操作 | 実装する順序 | 実行前に提出する値/回復 |
|---|---|---|
| 参照値 | WU-0でtest-ID/失敗baselineを採取→0Rで必要参照state/optionを構築 | 変更前/後の参照ID集合。例外的先行変更ならbaselineを別名で取り直す |
| com撤去 | route/匿名化/realmをWU-3で一体変更→共有参照撤去4→DB/table削除5→基準比較6 | 各DB/表の総行数・削除対象行数・snapshot ID・restoreコマンド/実測時間。未測定を0としない |
| Preference shape | 付録Sの維持/撤去/追加をrealm別migrationへ→新方式のみにcaller更新→承認済みデータ初期化→旧列/表撤去 | settingとZenithを別票。旧DB snapshotと旧checkoutを同時復元する手順。削除値をdownだけで復元可能とは書かない |
| Passkey slot | actorごとの保持数を計測→slot割当データ変更承認→NOT NULL/range/owner+slot unique | 11件以上なら自動削除せず対象一覧/選択肢。監査outboxを失わないsnapshot |
| lifecycle/version/receipt | state/reference/列/uniqueのschema migration→旧データ分類/版初期化の別承認→全writer切替 | 曖昧な旧完成事実/退会状態を勝手に補完しない。復元時はOP/RP/Zの版を揃える |
| 外部/鍵 | 固定SHAと登録origin/pathの差分を読取りで列挙→既存契約に対応する変更→別途適用許可 | Edge既知SHA、Jump/Away未取得SHA、鍵bundle fingerprint、配布/rollback順。秘密値は記録しない |

各WUの実装後は対象公開試験→関連重要集合→必要な全体試験の順に検証する。migrationでは生成schemaと`bin/rails db:verify_no_schema_drift`を確認する。環境構築は実行結果をevidenceへ残し、Minitestを追加しない。evidenceは実行HEADと未commit差分、失敗/未実施を含める。

**WU終了票の必須欄:** WU/対象R・AC（§7）、変更前後HEAD、付録F/Sからの実差分、公開試験IDと結果、別接続競合の先後、DB/外部障害結果、実施承認の識別子、docs/diagram/ADR差分、残存不合格。試験名だけの存在、static guardだけの通過、設計の署名を完了証拠にしない。

### 12.9 本版で実際に行った文書検証

コード基準は§0のHEAD/基準SHA。文書の生成・照合だけを実施し、アプリ/DBを起動していない。

| 確認 | 観測した結果 |
|---|---|
| 固定入力 | one.md、twelve.md、zero.mdの作業前後SHA-256一致 |
| 要件追跡 | one.mdの定義R 101件、AC 51件（廃止AC含む）が§7へ対応。新規ACの無断追加なし |
| 既存QA/レビュー | §9.2の原記録が作業前と一致。§10の18 QA IDを保持 |
| 撤去台帳 | Base com 82 controllerの処置、com参照1880一致/632ファイルの行番号集合を保持 |
| 新適用台帳 | F.2の74 writerファイルが基準treeに存在。S.2の127表と全CREATE TABLE行番号を基準SQLで照合 |
| 構造 | 明示した依存辺モデルに循環なし。節番号重複なし、code fence対応、末尾空白なし |
| 未実施 | アプリ試験、migration/DB件数、ブラウザの競合、外部repo・鍵・Cloudflareの実環境確認。上記静的検証はこれらの合格を意味しない |

検証用script/作業前snapshotは/tmpに置き、実装ファイル・生成schema・外部環境には変更を加えていない。実装時のevidenceは§12.8に従い、その時に実行したHEADと結果で新規作成する。

### 12.10 第0.25版の照合記録

今回の入力差分はD-58/AC-53/§13の確定版追補だけであることを旧入力と比較し、§0へ実測hashを記録した。G-24/25のattach/redeemとOTP issuer/guardは基準commitの実ファイルを再読した。これは変更後の実装試験ではない。RV-68/69の旧未決記述は§9の当時の履歴以外から取り除き、RV-70は§7.3で個別追跡する。文書の追跡/既存QA/台帳/構造と固定入力の非改変を静的に検査し、結果は終了報告に示す。コード/DB/アプリ試験/外部環境確認は行っていない。

検査結果: R 101件/AC 51件を保持、D-49〜59を個別追跡、RV-68〜70の判定を記録、既存QA 18 IDと§9.2の原レビューを保持。Base com 82 controller、com参照1880一致/632ファイル、writer 74ファイル、Preference 127表の台帳を保持し、実ファイル/表の行番号も再照合した。明示依存モデルは循環なし。one.md/twelve.md/zero.mdは作業前後SHA-256一致。

## 付録E. E-1a — Base comの持ち主とファイル処置

### E.1 callback/helper/rescueの処置

| 現在の要素 | 処置 | 残る持ち主/理由 |
|---|---|---|
| FqdnAvailabilityGate/RateLimit/DefaultNoStore | 維持 | 匿名surfaceのhost/負荷/既定no-store |
| protect_from_forgery、require_authenticity_token_for_unsafe_request! | 維持、書込みより前 | com自身のCSRF/Origin/Fetch Metadataを保護 |
| PreferenceGlobal/transport/localization | 匿名に限定して維持 | com_settingからの設定、7までは旧匿名transport |
| ActorSupportのset_current_actor/with_actor_lifecycle | principal解決部分を撤去、匿名context構築/ensure clearへ置換 | localization/theme/URL overlayを保持。別surfaceのprincipalを読まない |
| BrowserRpAuthentication、safe/unsafe refresh、OidcSsoInitiator | 撤去 | comのRP credential/sessionを読まない |
| PreferenceAdoption/VisitorPreference mirror | 撤去 | 匿名のみ。ComPreferenceのtransportとは別 |
| Withdrawal/Verification/SessionLimit/AuthorizationVisitor/ActionPolicy user認可 | 認証に属するcallback/helper/rescueを撤去 | anonymous Preferenceの明示的な入力/所有/CSRF検証へ。app/org policyを変更しない |
| BaseAdmissionBrowserBinding、Root/RP current_resource helpers | 撤去 | comに本人/Admissionはない |
| SignErrorResponses/ApplicationError/InvalidCrossOriginRequest handlers | 維持 | 匿名の一般エラーとCSRF失敗を処理。RV-45 |
| AuthenticationBase::LoginCooldownError rescue | 撤去 | comにlogin boundaryなし |
| ActionPolicy::Unauthorized→handle_authorization_error rescue | 対応する認証policyと同時に撤去 | 書込みを無検証にせず匿名入力検証の公開拒否へ |
| set_current_context/observability/Finisher | 匿名に限定して維持 | request context cleanup/既存計測。認証主体を復活させない |
| Session#reset_flash | 既存の無処理callbackは今回無関係なら維持 | 新しいflash通知を追加しない |
| default deny_allと認証before_action | 匿名controllerの必要な宣言へ置換 | `:open`宣言だけで認証を止めたとはせず、principal/credential readerが0かを確認 |

上表の起点は基準`app/controllers/base/com/application_controller.rb:7-101`。
`preferences_base_controller.rb:8-29`のauthorize_preference_write!は、匿名操作用に置換し削除policyに依存させない。
bare endpointは`Base::Com::BareController`の既存のFQDN/rate/no-store/CSRF契約を維持する。

### E.2 全controller（基準treeの82ファイル）

「維持改修」は既存controllerの匿名責務を維持する意味。対応route/view/helper/testも同じWUで直す。

| 基準ファイル | 処置 | WU/理由 |
|---|---|---|
| `app/controllers/base/com/accounts_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/api/v0/avatar/dashboard_identities_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/api/v0/avatar/switchers_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/api/v0/healths_controller.rb` | 維持改修 | 3/4。匿名のPreferenceまたは運用endpoint |
| `app/controllers/base/com/api/v0/identity/selections_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/api/v0/identity/standings_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/api/v0/membership/directory_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/api/v0/preferences/cookies_controller.rb` | 維持改修 | 3/4。匿名のPreferenceまたは運用endpoint |
| `app/controllers/base/com/api/v0/preferences/themes_controller.rb` | 維持改修 | 3/4。匿名のPreferenceまたは運用endpoint |
| `app/controllers/base/com/api/v0/revisions_controller.rb` | 維持改修 | 3/4。匿名のPreferenceまたは運用endpoint |
| `app/controllers/base/com/application_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/authority_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/bare_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/ceremony_binding_confirmations_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/csp_violation_reports_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/full_access_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/health/livenesses_controller.rb` | 維持改修 | 3/4。匿名のPreferenceまたは運用endpoint |
| `app/controllers/base/com/health/readinesses_controller.rb` | 維持改修 | 3/4。匿名のPreferenceまたは運用endpoint |
| `app/controllers/base/com/health/startups_controller.rb` | 維持改修 | 3/4。匿名のPreferenceまたは運用endpoint |
| `app/controllers/base/com/healths_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/identities_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/activities_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/birthdates_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/emails/registrations_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/emails_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/mfa/challenges_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/mfa/resets_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/passkeys_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/privacy/erasure/statuses_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/privacy/erasures_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/recoveries_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/recovery/appeals_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/recovery/completions_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/recovery/sessions_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/recovery_secrets_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/removals_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/revocations/others_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/rotations_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/secret_credentials_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/sessions_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/standings_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/telephones/registrations_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/telephones_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/withdrawal/sessions_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/identity/withdrawals_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/mcps_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/oidc/callbacks_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/oidc/closures_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/organizations/memberships_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/organizations_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/pre_access_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/preference/calendars_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/clocks_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/cookies_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/currencies_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/customizations_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/densities_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/emails_controller.rb` | 削除 | 3。VisitorEmail配信停止を撤去、D-27 |
| `app/controllers/base/com/preference/languages_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/motions_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/paginations_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/regions_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/screens_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/themes_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preference/timezones_controller.rb` | 維持改修 | 3で匿名契約維持、7で新方式へ。screen/PWAも維持 |
| `app/controllers/base/com/preferences_base_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/preferences_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/revisions_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/robots_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/roots_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/selectors_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/sign/entries_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/sign/interruptions_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/sign_outs_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/sitemaps_controller.rb` | 維持改修 | 3/4。公開/匿名/運用。依存先を残存DBだけに限定 |
| `app/controllers/base/com/switchers_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/verification/cancellations_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/verification/completions_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/verification/setups_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/verifications_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/welcomes_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |
| `app/controllers/base/com/well_known/jwks_controller.rb` | 削除 | 3。認証/本人/組織/Admission/RPまたは認証専用継承。対応routeと一体撤去 |

## 付録I. 基準treeのcom参照台帳

旧595行の元の抽出条件は入力に含まれないため、今回の再現可能な別検索として以下を定義する。
対象は基準treeの`app/`・`config/`・`lib/`内の`.rb/.yml/.yaml/.erb`。
検索式は`Base::Com|Auth::Com|Visa::Com|Core::Com|Warp::Com|Visitor|ComPreference|com_zenith|op_base_com|rp_base_com|rp_core_com|rp_warp_com|com_signal|com_setting|ActionPushNative|action_push_native`。
`git ls-tree -r --name-only <基準>`で対象パスを列挙し、`git grep -n -E <検索式> <基準> -- <対象パス>`で再現する。
**1880一致/632ファイル**。以下の行番号欄で全一致を列挙し、重複/欠落を文書検査した。
これはファイル名/定数による**設計上の処置割当て**で、各共有分岐の安全性を全件読了した証拠ではない。

- 削除: com認証専用ファイルを担当WUで削除。新設したmigrationでDBを撤去し過去migrationは残す。
- 維持/改修: ComPreference/Chronicle、公開host/Publishing COM、明示的な匿名経路を保持。
- 共有改修: com認証の分岐/定数参照だけを外しapp/orgを維持。ファイル全体を削除しない。
- 依存の実査: 同名だけでは用途を断定できない残り。実装diff前にT-9で行単位の採否を確認する。

| 基準ファイル | 一致行 | 処置割当て | 担当WU |
|---|---|---|---|
| `app/consumers/processor_erasure_notification_receipt_consumer.rb` | 41 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/controllers/auth/com/api/v0/healths_controller.rb` | 14 | 削除 | WU-3 |
| `app/controllers/auth/com/api/v0/revisions_controller.rb` | 14 | 削除 | WU-3 |
| `app/controllers/auth/com/application_controller.rb` | 18,23,24,61,134,142,146 | 削除 | WU-3 |
| `app/controllers/auth/com/ceremony_bindings_controller.rb` | 6,34 | 削除 | WU-3 |
| `app/controllers/auth/com/edge/v0/token/checks_controller.rb` | 4 | 削除 | WU-3 |
| `app/controllers/auth/com/edge/v0/token/dbsc_controller.rb` | 4 | 削除 | WU-3 |
| `app/controllers/auth/com/full_access_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/auth/com/preferences_base_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/auth/com/roots_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/auth/com/settings/removals_controller.rb` | 10 | 削除 | WU-3 |
| `app/controllers/auth/com/settings_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/cancellations_controller.rb` | 9,40 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/challenge/passkeys_controller.rb` | 9,160,161,162,182,220,221 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/challenges_controller.rb` | 8,22 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/checks_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/emails_controller.rb` | 8,75,79,94,100,142,241,284,313 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/guards_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/passkey/options_controller.rb` | 9 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/passkey/verifications_controller.rb` | 9,52,69 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/passkeys_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/in/sentries_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/ins_controller.rb` | 7,61 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/oidc_handoffs_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/outs_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/switches_controller.rb` | 9,42 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/check/email/birthdates_controller.rb` | 10,37 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/check/email/otps_controller.rb` | 10,78,151 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/check/telephone/birthdates_controller.rb` | 10 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/check/telephone/otps_controller.rb` | 10,79,166 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/check/telephone/passkeys_controller.rb` | 10,104,136 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/emails_controller.rb` | 10,61,68,84,100,157,243,244,298,301,314,332,369,374,377,379,381,406 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/guard/base_controller.rb` | 9,33 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/sentries_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/up/telephones_controller.rb` | 10,27,38,52,58,146,221,222,250,255,258,260,262,286 | 削除 | WU-3 |
| `app/controllers/auth/com/sign/ups_controller.rb` | 7,44 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/cancellations_controller.rb` | 3,39,41,43 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/emails_controller.rb` | 4,143,149,151,153 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/handoffs_controller.rb` | 3,12,14,16 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/passkeys_controller.rb` | 3,21,23,25 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/redeliveries_controller.rb` | 3 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/registration/handoffs_controller.rb` | 3,12,14,16 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/registration/passkeys_controller.rb` | 3,13,15,17 | 削除 | WU-3 |
| `app/controllers/auth/com/verification/setups_controller.rb` | 7,38,40,42 | 削除 | WU-3 |
| `app/controllers/auth/com/verifications_controller.rb` | 6,17,19,21 | 削除 | WU-3 |
| `app/controllers/auth/com/web/v0/in/email/otps_controller.rb` | 10 | 削除 | WU-3 |
| `app/controllers/base/com/accounts_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/api/v0/healths_controller.rb` | 14 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/api/v0/preferences/cookies_controller.rb` | 9 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/api/v0/preferences/themes_controller.rb` | 9 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/api/v0/revisions_controller.rb` | 14 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/application_controller.rb` | 27,28 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/authority_controller.rb` | 18,22,23 | 削除 | WU-3 |
| `app/controllers/base/com/ceremony_binding_confirmations_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/full_access_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/identities_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/identity/activities_controller.rb` | 7,24,28 | 削除 | WU-3 |
| `app/controllers/base/com/identity/birthdates_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/base/com/identity/emails/registrations_controller.rb` | 8,20,34,61,158,160,201,207,215,227,240,261,268,269,274,288,291,349,357,358,363,368,392 | 削除 | WU-3 |
| `app/controllers/base/com/identity/emails_controller.rb` | 7,11,17,18,24,29,35,56,167,177 | 削除 | WU-3 |
| `app/controllers/base/com/identity/mfa/challenges_controller.rb` | 8,28,35,83,87,94,100 | 削除 | WU-3 |
| `app/controllers/base/com/identity/mfa/resets_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/base/com/identity/passkeys_controller.rb` | 3,14,31,56,63 | 削除 | WU-3 |
| `app/controllers/base/com/identity/privacy/erasure/statuses_controller.rb` | 11,41,50 | 削除 | WU-3 |
| `app/controllers/base/com/identity/privacy/erasures_controller.rb` | 8,46,48,52 | 削除 | WU-3 |
| `app/controllers/base/com/identity/recoveries_controller.rb` | 7,28 | 削除 | WU-3 |
| `app/controllers/base/com/identity/recovery/appeals_controller.rb` | 8,54 | 削除 | WU-3 |
| `app/controllers/base/com/identity/recovery/completions_controller.rb` | 8,36 | 削除 | WU-3 |
| `app/controllers/base/com/identity/recovery/sessions_controller.rb` | 8,59,61,63,67,73 | 削除 | WU-3 |
| `app/controllers/base/com/identity/recovery_secrets_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/base/com/identity/removals_controller.rb` | 7,15,21,27 | 削除 | WU-3 |
| `app/controllers/base/com/identity/revocations/others_controller.rb` | 4,10 | 削除 | WU-3 |
| `app/controllers/base/com/identity/rotations_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/base/com/identity/secret_credentials_controller.rb` | 7,10,27,38,44,56,62,88,120,131,137,222,247,249,253,290,296,300,314,334,340 | 削除 | WU-3 |
| `app/controllers/base/com/identity/sessions_controller.rb` | 7,16 | 削除 | WU-3 |
| `app/controllers/base/com/identity/standings_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/base/com/identity/telephones/registrations_controller.rb` | 8,15,27,47,65,137,173,203,300,310,311 | 削除 | WU-3 |
| `app/controllers/base/com/identity/telephones_controller.rb` | 7,11,18,19,30,36,96,139,153 | 削除 | WU-3 |
| `app/controllers/base/com/identity/withdrawal/sessions_controller.rb` | 11,81,83,85,89 | 削除 | WU-3 |
| `app/controllers/base/com/identity/withdrawals_controller.rb` | 7,9,157,164,169 | 削除 | WU-3 |
| `app/controllers/base/com/oidc/callbacks_controller.rb` | 7,16,17 | 削除 | WU-3 |
| `app/controllers/base/com/oidc/closures_controller.rb` | 7,20 | 削除 | WU-3 |
| `app/controllers/base/com/organizations/memberships_controller.rb` | 9 | 削除 | WU-3 |
| `app/controllers/base/com/organizations_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/pre_access_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/preference/calendars_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/clocks_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/cookies_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/currencies_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/customizations_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/densities_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/emails_controller.rb` | 9,54 | 削除 | WU-3 |
| `app/controllers/base/com/preference/languages_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/motions_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/paginations_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/regions_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/screens_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/themes_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preference/timezones_controller.rb` | 7 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/preferences_base_controller.rb` | 6 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/roots_controller.rb` | 6 | 維持改修 | WU-3/4 |
| `app/controllers/base/com/selectors_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/sign/entries_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/base/com/sign/interruptions_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/base/com/sign_outs_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/switchers_controller.rb` | 6,8 | 削除 | WU-3 |
| `app/controllers/base/com/verification/cancellations_controller.rb` | 7,32,33 | 削除 | WU-3 |
| `app/controllers/base/com/verification/completions_controller.rb` | 7,51,52 | 削除 | WU-3 |
| `app/controllers/base/com/verification/setups_controller.rb` | 9 | 削除 | WU-3 |
| `app/controllers/base/com/verifications_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/com/welcomes_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/base/org/api/v0/support/accounts_controller.rb` | 9,29 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/controllers/base/org/support/visitors/revocations_controller.rb` | 7,9,10 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/controllers/base/org/support/visitors_controller.rb` | 7,10 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/controllers/concerns/auth_passkey_registration_ceremony.rb` | 108 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_audit_writer.rb` | 286,288,289,290,291,292,293,294,295 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_base.rb` | 1350,2541,2542,2558,2570,2590,2591,2592,2664,2665,2666,2667,2678,3116,3117,3137,3138,3139,3151,3185,3186,3405 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_current_resource_resolver.rb` | 210,286 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_device_binding.rb` | 29,34 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_jwt_tokens.rb` | 105 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_logout_all_sessions.rb` | 51,52 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_logout_current_session.rb` | 50,195,213,259,269 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_sequence_gate.rb` | 546,574,583 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_session_revoker.rb` | 23,24 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authentication_visitor.rb` | 4,44,57,73,96,98 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authorization_audit.rb` | 83 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authorization_base.rb` | 6 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authorization_token_claims.rb` | 117 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/authorization_visitor.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/base_ceremony_binding_confirmation.rb` | 150,168,173,174,278 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/base_identity_passkey_management.rb` | 81,155 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/base_preference_view_route_aliases.rb` | 28 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/base_settings_withdrawal_flow.rb` | 138,161 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/base_sign_in_limitations.rb` | 223,232 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/base_step_up_intent.rb` | 268,269,366 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/base_step_up_transaction_marker.rb` | 38,47 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/browser_rp_authentication.rb` | 348,357 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/core_browser_api_boundary.rb` | 88 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/email_validation.rb` | 25 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/oidc_rp_identity_provisioning.rb` | 91,147,193 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/oidc_sso_initiator.rb` | 241,244 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/org_support_session_revocation_page.rb` | 6 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/passkey_sign_in_flow.rb` | 139,286 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/preference_access_token_transport.rb` | 42 | 匿名ComPreference維持、Visitor枝削除、段階的置換 | WU-3/4/7/9 |
| `app/controllers/concerns/preference_adoption.rb` | 52,55,70,71,257,264,411,537,538,548 | 匿名ComPreference維持、Visitor枝削除、段階的置換 | WU-3/4/7/9 |
| `app/controllers/concerns/preference_base.rb` | 497,501,510,514,912 | 匿名ComPreference維持、Visitor枝削除、段階的置換 | WU-3/4/7/9 |
| `app/controllers/concerns/preference_class_registry.rb` | 84,85,86,87,88,89,91,92,93,94,95,96,97,98,99,100,101,104,105,106,107,108,109,110,111,112,113,114,209,210,212,213,214,215,216,217,218,219,220,221,222,225,226,227,228,229,230,231,232,233,234,235 | 匿名ComPreference維持、Visitor枝削除、段階的置換 | WU-3/4/7/9 |
| `app/controllers/concerns/preference_core.rb` | 617,676 | 匿名ComPreference維持、Visitor枝削除、段階的置換 | WU-3/4/7/9 |
| `app/controllers/concerns/preference_resource_sync.rb` | 24,26,27,139 | 匿名ComPreference維持、Visitor枝削除、段階的置換 | WU-3/4/7/9 |
| `app/controllers/concerns/preference_sign_out_rotation.rb` | 8 | 匿名ComPreference維持、Visitor枝削除、段階的置換 | WU-3/4/7/9 |
| `app/controllers/concerns/privacy_erasure_request_flow.rb` | 45 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/session_limit_gate.rb` | 165 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_acme_authority_redirect.rb` | 36 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_authority_redirect.rb` | 46,56 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_entry_exit.rb` | 44 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_entry_sentry_enforcement.rb` | 56 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_in_phase_binding_controller_support.rb` | 137 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_oidc_logout.rb` | 11 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_settings_secret_credential_registration.rb` | 35 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/sign_up_sequence_controller_support.rb` | 414,415,482,533,545,572,580,694,727,728,736,737,786 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/concerns/verification_visitor.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/controllers/core/com/api/v0/base_controller.rb` | 31,33 | 削除 | WU-3 |
| `app/controllers/core/com/api/v0/healths_controller.rb` | 14 | 削除 | WU-3 |
| `app/controllers/core/com/api/v0/preferences/cookies_controller.rb` | 9 | 削除 | WU-3 |
| `app/controllers/core/com/api/v0/preferences/dbsc_controller.rb` | 9 | 削除 | WU-3 |
| `app/controllers/core/com/api/v0/preferences/themes_controller.rb` | 9 | 削除 | WU-3 |
| `app/controllers/core/com/api/v0/revisions_controller.rb` | 14 | 削除 | WU-3 |
| `app/controllers/core/com/application_controller.rb` | 21,22 | 削除 | WU-3 |
| `app/controllers/core/com/oidc/callbacks_controller.rb` | 7,16,17,18 | 削除 | WU-3 |
| `app/controllers/core/com/oidc/closures_controller.rb` | 7,17 | 削除 | WU-3 |
| `app/controllers/core/com/roots_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/core/com/sign/entries_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/core/com/sign/interruptions_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/core/com/sign/outs_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/api/v0/healths_controller.rb` | 14 | 削除 | WU-3 |
| `app/controllers/visa/com/api/v0/revisions_controller.rb` | 14 | 削除 | WU-3 |
| `app/controllers/visa/com/authority_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/visa/com/authorization_base_controller.rb` | 8,105 | 削除 | WU-3 |
| `app/controllers/visa/com/ceremony_binding_confirmations_controller.rb` | 6 | 削除 | WU-3 |
| `app/controllers/visa/com/edge/v0/token/checks_controller.rb` | 4 | 削除 | WU-3 |
| `app/controllers/visa/com/edge/v0/token/dbsc_controller.rb` | 4 | 削除 | WU-3 |
| `app/controllers/visa/com/edge/v0/token/refreshes_controller.rb` | 4 | 削除 | WU-3 |
| `app/controllers/visa/com/oauth/authorizations_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/oauth/revocations_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/oauth/tokens_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/oauth/userinfos_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/oidc/cancellations_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/oidc/logouts/completions_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/visa/com/oidc/logouts/confirmations_controller.rb` | 8 | 削除 | WU-3 |
| `app/controllers/visa/com/oidc/logouts_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/oidc/results_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/oidc/switches_controller.rb` | 7 | 削除 | WU-3 |
| `app/controllers/visa/com/sign/in/limitations_controller.rb` | 7,18,20,24 | 削除 | WU-3 |
| `app/controllers/warp/com/api/v0/healths_controller.rb` | 14 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/api/v0/preferences/cookies_controller.rb` | 11 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/api/v0/preferences/themes_controller.rb` | 11 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/api/v0/revisions_controller.rb` | 14 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/application_controller.rb` | 21,22 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/dashboards_controller.rb` | 6 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/oidc/callbacks_controller.rb` | 7,16,17 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/oidc/closures_controller.rb` | 7,17 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/roots_controller.rb` | 6,36 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/settings_controller.rb` | 6 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/sign/entries_controller.rb` | 7 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/sign/interruptions_controller.rb` | 7 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/sign/outs_controller.rb` | 7 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/controllers/warp/com/well_known/jwks_controller.rb` | 7 | 公開部分を維持、RP/認証分岐を削除 | WU-3/4 |
| `app/helpers/auth/app/application_helper.rb` | 6 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/helpers/auth/com/application_helper.rb` | 9 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/helpers/auth/common_helper.rb` | 4 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/helpers/auth/org/application_helper.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/jobs/application_push_notification_job.rb` | 4,7,8,11 | 削除 | WU-4/5 |
| `app/jobs/contact_audit_delivery_job.rb` | 15 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/jobs/dpop_proof_state_purge_job.rb` | 21 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/jobs/outbound/sms_delivery_job.rb` | 38,59 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/jobs/passkey_audit_delivery_job.rb` | 9 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/jobs/processor_erasure_notification_job.rb` | 109,120,132 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/jobs/processor_erasure_notification_retry_job.rb` | 19 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/jobs/retention_purge_job.rb` | 27,29,31,32,33,34,35,36,37,39,40,41,42,43,44,45,47,135,143,152,154,158,162,166,170,172,278,279,404,462,510,534,568 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/jobs/sign_up_expiry_job.rb` | 10 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/mailers/email/com/otp_mailer.rb` | 40,56,94,111,112,122,123,124 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/account_access_event.rb` | 46 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/application_push_device.rb` | 6,7,20,22,24,25,28,29,32,34 | 削除 | WU-4/5 |
| `app/models/application_push_notification.rb` | 4,8,9,12 | 削除 | WU-4/5 |
| `app/models/area_visitor_occurrence.rb` | 25 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/com_enforcement_authentication_method_effect.rb` | 5 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/com_enforcement_case.rb` | 4,25 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/com_preference.rb` | 7,49,59,60,73,74,75,140,142 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_adult_content_gate.rb` | 7,25,26,28,35,37,44 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_adult_content_gate_option.rb` | 7,11 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_binding_method.rb` | 7,11 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_chronicle.rb` | 43,49,56,70,75,80 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_chronicle_event.rb` | 11,51 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_chronicle_level.rb` | 11 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_cookie.rb` | 7,29,30 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_currency.rb` | 7,25,26,28,38 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_currency_option.rb` | 7,11,21 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_date_format.rb` | 7,25,26,28,38 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_date_format_option.rb` | 7,11,22 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_dbsc_status.rb` | 7,11 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_density.rb` | 7,25,26,28,38 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_density_option.rb` | 7,11,21 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_language.rb` | 7,26,27,29,37 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_language_option.rb` | 7,12,20 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_motion.rb` | 7,25,26,28,38 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_motion_option.rb` | 7,11,21 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_page_size.rb` | 7,25,26,28,38 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_page_size_option.rb` | 7,11,24 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_region.rb` | 7,26,27,29,37 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_region_option.rb` | 7,12,20 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_status.rb` | 7,12,22 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_theme.rb` | 7,26,27,29,37 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_theme_option.rb` | 7,12,20 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_time_format.rb` | 7,25,26,28,38 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_time_format_option.rb` | 7,11,21 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_timezone.rb` | 7,26,27,29,37 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_preference_timezone_option.rb` | 7,12,36 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_rp_record.rb` | 6 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/com_setting_record.rb` | 9 | 維持/新方式へ改修 | WU-4/7 |
| `app/models/com_signal_record.rb` | 9 | 削除 | WU-4/5 |
| `app/models/com_zenith_record.rb` | 4,5,10 | 削除 | WU-4/5 |
| `app/models/company.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/company_ownership_transfer_request.rb` | 12,13 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/company_unit.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/company_unit_closure.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/auth_email_otp_challenge.rb` | 231,232,247,255,264 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/dbsc_bindable.rb` | 42,46,53,57 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/email_contact_binding.rb` | 32,145,174,175,176,210 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/email_dead_identifier_history.rb` | 35,56,62,101 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/enforcement_case_applicable.rb` | 118 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/identity.rb` | 4,13 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/mfa_status_credential.rb` | 31,32,34 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/passkey_audit_outbox.rb` | 47,60 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/refresh_tokenable.rb` | 132,287,432 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/rp_session.rb` | 92,222,240,241 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/secret_credential.rb` | 66,68,69,70,71,72,73 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/session_limit_resolution_transactionable.rb` | 32,44,54,64,74,84,94,530,564 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/step_up_session_consumable.rb` | 172 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/telephone_contact_binding.rb` | 33,34,64,92 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/telephone_dead_identifier_history.rb` | 35,54,60,91 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/token_status_management.rb` | 210 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/visitor_secret_credential_kinds.rb` | 4,7,8,9,10 | 削除 | WU-4/5 |
| `app/models/concerns/withdrawable.rb` | 4 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/concerns/withdrawal_occurrence_recording.rb` | 44,52,59,81 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/core_com_visitor_bridge.rb` | 7,24 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/email_visitor_occurrence.rb` | 25 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/individual.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/individual_assignment.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/individual_membership.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/individual_membership_kind.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/individual_membership_revoke_reason.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/individual_membership_state.rb` | 7 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/individual_ownership_transfer_request.rb` | 12,13 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/ip_visitor_occurrence.rb` | 25 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/op_base_com_record.rb` | 11 | 削除 | WU-4/5 |
| `app/models/op_com_authority_stop_root_target.rb` | 6 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/op_com_grant.rb` | 10,40 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/models/rp_base_com_callback_state.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_base_com_event_receipt.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_base_com_identity_binding.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_base_com_op_session_binding.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_base_com_principal.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_base_com_record.rb` | 8 | 削除 | WU-4/5 |
| `app/models/rp_base_com_session.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_core_com_callback_state.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_core_com_event_receipt.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_core_com_identity_binding.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_core_com_op_session_binding.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_core_com_principal.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_core_com_record.rb` | 8 | 削除 | WU-4/5 |
| `app/models/rp_core_com_session.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_warp_com_callback_state.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_warp_com_event_receipt.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_warp_com_identity_binding.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_warp_com_op_session_binding.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_warp_com_principal.rb` | 7 | 削除 | WU-4/5 |
| `app/models/rp_warp_com_record.rb` | 8 | 削除 | WU-4/5 |
| `app/models/rp_warp_com_session.rb` | 7 | 削除 | WU-4/5 |
| `app/models/visitor.rb` | 7,62,76,78,80,81,84,85,91,96,100,103,106,142,149,152,156,158,161,180,206,230,251,259,260,270,272 | 削除 | WU-4/5 |
| `app/models/visitor_account.rb` | 7,20 | 削除 | WU-4/5 |
| `app/models/visitor_auth_admission_binding.rb` | 4,7,8,9,10,11,31,33 | 削除 | WU-4/5 |
| `app/models/visitor_auth_ceremony_session.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_authority_lock.rb` | 5 | 削除 | WU-4/5 |
| `app/models/visitor_banner.rb` | 27 | 削除 | WU-4/5 |
| `app/models/visitor_contact_audit_outbox.rb` | 3 | 削除 | WU-4/5 |
| `app/models/visitor_device_session.rb` | 7,35,42 | 削除 | WU-4/5 |
| `app/models/visitor_dpop_proof_state.rb` | 7,27 | 削除 | WU-4/5 |
| `app/models/visitor_email.rb` | 43,57 | 削除 | WU-4/5 |
| `app/models/visitor_email_ceremony_transaction.rb` | 8,35 | 削除 | WU-4/5 |
| `app/models/visitor_email_history.rb` | 3,4 | 削除 | WU-4/5 |
| `app/models/visitor_email_status.rb` | 11 | 削除 | WU-4/5 |
| `app/models/visitor_enforcement_recovery_ceremony.rb` | 4,11 | 削除 | WU-4/5 |
| `app/models/visitor_identifier_rotation_audit.rb` | 3 | 削除 | WU-4/5 |
| `app/models/visitor_identity.rb` | 7,32,36,41 | 削除 | WU-4/5 |
| `app/models/visitor_identity_state.rb` | 7,11,21 | 削除 | WU-4/5 |
| `app/models/visitor_mfa_status.rb` | 11 | 削除 | WU-4/5 |
| `app/models/visitor_notification_record.rb` | 7,20 | 削除 | WU-4/5 |
| `app/models/visitor_occurrence.rb` | 33,38,39,41 | 削除 | WU-4/5 |
| `app/models/visitor_occurrence_status.rb` | 12 | 削除 | WU-4/5 |
| `app/models/visitor_oidc_authorization_transaction.rb` | 7,47 | 削除 | WU-4/5 |
| `app/models/visitor_oidc_connection.rb` | 7,24,29 | 削除 | WU-4/5 |
| `app/models/visitor_oidc_identity_binding.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_passkey.rb` | 7,46,53,57,68 | 削除 | WU-4/5 |
| `app/models/visitor_passkey_audit_outbox.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_passkey_ceremony_candidate.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_passkey_ceremony_transaction.rb` | 8,37 | 削除 | WU-4/5 |
| `app/models/visitor_passkey_status.rb` | 7,11 | 削除 | WU-4/5 |
| `app/models/visitor_preference.rb` | 40 | 削除 | WU-4/5 |
| `app/models/visitor_preference_adult_content_gate.rb` | 25,26,28,35,37,44 | 削除 | WU-4/5 |
| `app/models/visitor_preference_adult_content_gate_option.rb` | 11 | 削除 | WU-4/5 |
| `app/models/visitor_preference_currency.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_currency_option.rb` | 11,21 | 削除 | WU-4/5 |
| `app/models/visitor_preference_date_format.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_date_format_option.rb` | 11,22 | 削除 | WU-4/5 |
| `app/models/visitor_preference_density.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_density_option.rb` | 11,21 | 削除 | WU-4/5 |
| `app/models/visitor_preference_language.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_language_option.rb` | 15,25 | 削除 | WU-4/5 |
| `app/models/visitor_preference_motion.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_motion_option.rb` | 11,21 | 削除 | WU-4/5 |
| `app/models/visitor_preference_page_size.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_page_size_option.rb` | 11,24 | 削除 | WU-4/5 |
| `app/models/visitor_preference_region.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_region_option.rb` | 15,25 | 削除 | WU-4/5 |
| `app/models/visitor_preference_theme.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_theme_option.rb` | 15,24 | 削除 | WU-4/5 |
| `app/models/visitor_preference_time_format.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_time_format_option.rb` | 11,21 | 削除 | WU-4/5 |
| `app/models/visitor_preference_timezone.rb` | 25,26,28,38 | 削除 | WU-4/5 |
| `app/models/visitor_preference_timezone_option.rb` | 15,37 | 削除 | WU-4/5 |
| `app/models/visitor_privacy_request.rb` | 4,7,23 | 削除 | WU-4/5 |
| `app/models/visitor_privacy_request_status.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_processor_erasure_notification.rb` | 4,7,19,21 | 削除 | WU-4/5 |
| `app/models/visitor_processor_erasure_notification_attempt.rb` | 4,8 | 削除 | WU-4/5 |
| `app/models/visitor_processor_erasure_notification_status.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_retention_hold.rb` | 4,7,17 | 削除 | WU-4/5 |
| `app/models/visitor_retention_hold_status.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_secret_credential.rb` | 56,60,63,67,68,89,92 | 削除 | WU-4/5 |
| `app/models/visitor_secret_credential_ceremony_transaction.rb` | 8,35 | 削除 | WU-4/5 |
| `app/models/visitor_secret_credential_kind.rb` | 11 | 削除 | WU-4/5 |
| `app/models/visitor_secret_credential_status.rb` | 11 | 削除 | WU-4/5 |
| `app/models/visitor_security_mode.rb` | 13,19 | 削除 | WU-4/5 |
| `app/models/visitor_session_limit_resolution_state.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_session_limit_resolution_transaction.rb` | 4,15,17,19 | 削除 | WU-4/5 |
| `app/models/visitor_sign_in_flow.rb` | 7,44,51,94,95,96 | 削除 | WU-4/5 |
| `app/models/visitor_sign_in_flow_state.rb` | 4 | 削除 | WU-4/5 |
| `app/models/visitor_sign_up_flow.rb` | 7,59,66,138,139,141,142,143,165 | 削除 | WU-4/5 |
| `app/models/visitor_sign_up_flow_cleanup_status.rb` | 7,11 | 削除 | WU-4/5 |
| `app/models/visitor_sign_up_flow_status.rb` | 7,11 | 削除 | WU-4/5 |
| `app/models/visitor_status.rb` | 12 | 削除 | WU-4/5 |
| `app/models/visitor_step_up_ceremony_transaction.rb` | 8,49 | 削除 | WU-4/5 |
| `app/models/visitor_step_up_session.rb` | 7,30,60,62,64,66 | 削除 | WU-4/5 |
| `app/models/visitor_telephone.rb` | 36,47,78,85,87,94,115 | 削除 | WU-4/5 |
| `app/models/visitor_telephone_ceremony_transaction.rb` | 8,35 | 削除 | WU-4/5 |
| `app/models/visitor_telephone_history.rb` | 3,4 | 削除 | WU-4/5 |
| `app/models/visitor_telephone_status.rb` | 11 | 削除 | WU-4/5 |
| `app/models/visitor_token.rb` | 7,84,100,101,107,109,110,111,112,120,121,128,146 | 削除 | WU-4/5 |
| `app/models/visitor_token_binding_method.rb` | 7,11 | 削除 | WU-4/5 |
| `app/models/visitor_token_dbsc_status.rb` | 7,11 | 削除 | WU-4/5 |
| `app/models/visitor_token_kind.rb` | 7,11 | 削除 | WU-4/5 |
| `app/models/visitor_token_status.rb` | 7,11 | 削除 | WU-4/5 |
| `app/models/visitor_verification.rb` | 7,27 | 削除 | WU-4/5 |
| `app/models/visitor_visibility.rb` | 12 | 削除 | WU-4/5 |
| `app/models/visitor_withdrawal_ceremony.rb` | 4,11 | 削除 | WU-4/5 |
| `app/models/visitor_withdrawal_flow.rb` | 36,40,41,68 | 削除 | WU-4/5 |
| `app/models/visitor_withdrawal_flow_event.rb` | 36,41,43,45,46,56 | 削除 | WU-4/5 |
| `app/models/visitor_withdrawal_flow_status.rb` | 11 | 削除 | WU-4/5 |
| `app/notifiers/notify/com/step_up_otp_notifier.rb` | 11,16 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/operations/acme_refresh_token_issuer.rb` | 90 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/auth_admission_binding_purger.rb` | 10,13,102 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/authentication_other_sessions_revoker.rb` | 80,90 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/base_self_rp_credential_issuer.rb` | 133 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/base_step_up_admission_issuer.rb` | 221,222,227,228,348 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/company_creator.rb` | 4,30,31,52,58 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/contact_binding_audit_recorder.rb` | 28,29,35 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_credential_registration_bootstrap_guard.rb` | 21,22 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_credential_registration_otp_delivery_guard.rb` | 24,25,26,127,140 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_credential_registration_otp_finalizer.rb` | 27,28,175,204,209,210,231 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_credential_registration_otp_issuer.rb` | 50,51,158,169 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_credential_registration_otp_resend_issuer.rb` | 20,21,94 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_credential_registration_otp_verification_committer.rb` | 20,21,115,145,163,172 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_identifier_purger.rb` | 12,30,49,57,65 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_reentry_otp_issuer.rb` | 41,66 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_reentry_otp_verification_committer.rb` | 55,64 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_sign_up_candidate_creator.rb` | 18,21,22,23,24 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_sign_up_otp_delivery_guard.rb` | 52,53,57,67 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_sign_up_otp_delivery_issuer.rb` | 14 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_sign_up_otp_issuer.rb` | 44,45,47,62 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/email_sign_up_otp_verification_committer.rb` | 55,56,58,67 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_authentication_stop_recorder.rb` | 13 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_credential_removal_committer.rb` | 72,88,95,97,132,141,144,151,153,154,161,178,179,180,181,182,183 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_email_bootstrap_committer.rb` | 50,66,67,68,96,105,114,123 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_email_ceremony_final_committer.rb` | 25,27,30,31 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_email_ceremony_transaction_purger.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_passkey_ceremony_final_committer.rb` | 13 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_passkey_ceremony_transaction_purger.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_passkey_name_committer.rb` | 56,57,74,83 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_passkey_registration_final_committer.rb` | 25,26,27,28,29,30,31,217 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_passkey_registration_verification_committer.rb` | 20,21,22,23,24,25 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_secret_credential_ceremony_final_committer.rb` | 7,10,11,12 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_secret_credential_ceremony_transaction_purger.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_ceremony_cancellation_committer.rb` | 71,72,93 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_ceremony_freshness_committer.rb` | 26,226,240,241,242,246,269,271,356 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_ceremony_freshness_revoker.rb` | 14 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_ceremony_transaction_purger.rb` | 7,15,16,17,97,100,105,107 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_email_code_issuer.rb` | 66,67,68,69,73,85,87 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_email_delivery_recorder.rb` | 86,88,97,106 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_email_verification_committer.rb` | 64,65,66,67,80,82 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_step_up_passkey_verification_committer.rb` | 52,53,57,76,84,91 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_telephone_ceremony_final_committer.rb` | 22,24,27,28 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/identity_telephone_ceremony_transaction_purger.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/individual_creator.rb` | 4,34,35,37,66,73,75,82 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/oidc_authorization_code_issuer.rb` | 101,111 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/oidc_authorization_transaction_purger.rb` | 10,16 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/oidc_connection_recorder.rb` | 44 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/oidc_refresh_token_issuer.rb` | 222,230,250,251 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/op_authority_stop_committer.rb` | 45,47,109 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/op_identity_event_invalidator.rb` | 14,20,83 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/passkey_registration_operation.rb` | 12 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/processor_erasure_notification_recovery_operation.rb` | 53,61 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/public_id_null_only_backfill_operation.rb` | 10 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/refresh_token_reuse_activity_recorder.rb` | 41 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/rp_session_revoker.rb` | 42 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/sign_com_up_telephone_registration_finalizer.rb` | 7,28,44,45,46,49,71,89 | com専用は削除 | WU-4 |
| `app/operations/sign_flow_halt_recorder.rb` | 55,58,66 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_credential_registration_otp_delivery_guard.rb` | 22,23,70,84,92 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_credential_registration_otp_finalizer.rb` | 21,22,109,141,146,147,168 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_credential_registration_otp_issuer.rb` | 33,34,135,146,152 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_credential_registration_otp_resend_issuer.rb` | 20,21,73,86,103 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_credential_registration_otp_verification_committer.rb` | 21,22,96,116,168,174,182 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_identifier_purger.rb` | 12,30,49,57,65 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_sign_up_candidate_creator.rb` | 17,22,47,48,49,50,52 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_sign_up_otp_delivery_guard.rb` | 52,53,57,67 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_sign_up_otp_delivery_issuer.rb` | 14 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_sign_up_otp_issuer.rb` | 44,45,47,80 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/telephone_sign_up_otp_verification_committer.rb` | 52,53,55,56,65 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/operations/withdrawal_personal_data_anonymizer.rb` | 15,57,58,60,62,66,67,76,107 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/account_policy.rb` | 39 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/application_policy.rb` | 116,132 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/area_visitor_occurrence_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/auth_method_guard.rb` | 14,15,18,19,31 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/client_chronicle_policy.rb` | 6,13 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_binding_method_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_chronicle_event_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_chronicle_level_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_chronicle_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_cookie_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_currency_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_currency_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_date_format_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_date_format_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_dbsc_status_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_density_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_density_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_language_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_language_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_motion_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_motion_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_page_size_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_page_size_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_policy.rb` | 4,6 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_region_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_region_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_status_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_theme_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_theme_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_time_format_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_time_format_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_timezone_option_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/com_preference_timezone_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/email_visitor_occurrence_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/ip_visitor_occurrence_policy.rb` | 4 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/organization_membership_policy.rb` | 37,48,50 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/organization_policy.rb` | 19 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/sign_in/cycle_policy.rb` | 99 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/sign_up/base_policy.rb` | 97 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/sign_up_step_gate.rb` | 168,217 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/step_up_available_methods.rb` | 20 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/support_visitor_policy.rb` | 4,5,6,14 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/policies/visitor_account_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_banner_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_email_policy.rb` | 10,12,17,30,31 | com専用は削除 | WU-4 |
| `app/policies/visitor_email_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_identity_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_identity_state_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_mfa_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_notification_record_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_occurrence_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_occurrence_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_oidc_connection_policy.rb` | 10,12 | com専用は削除 | WU-4 |
| `app/policies/visitor_passkey_policy.rb` | 9,46,62 | com専用は削除 | WU-4 |
| `app/policies/visitor_passkey_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_currency_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_currency_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_date_format_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_date_format_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_density_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_density_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_language_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_language_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_motion_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_motion_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_page_size_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_page_size_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_policy.rb` | 4,6 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_region_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_region_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_theme_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_theme_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_time_format_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_time_format_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_timezone_option_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_preference_timezone_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_secret_credential_kind_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_secret_credential_policy.rb` | 11,13,17 | com専用は削除 | WU-4 |
| `app/policies/visitor_secret_credential_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_sign_in_flow_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_step_up_session_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_telephone_policy.rb` | 10,12,17,30,31 | com専用は削除 | WU-4 |
| `app/policies/visitor_telephone_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_token_binding_method_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_token_dbsc_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_token_kind_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_token_policy.rb` | 10,12,27 | com専用は削除 | WU-4 |
| `app/policies/visitor_token_status_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_verification_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_visibility_policy.rb` | 4 | com専用は削除 | WU-4 |
| `app/policies/visitor_withdrawal_policy.rb` | 8,10 | com専用は削除 | WU-4 |
| `app/presenters/auth/com/settings/activity_log_presenter.rb` | 3,19 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/queries/authentication_credential_inventory.rb` | 45,109,131,138,179,213,244,247,270 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/authority_owner_migration_inventory.rb` | 148,150,151,152,159,171,175,176,177,184 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/current_banner_query.rb` | 23 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/email_credential_registration_otp_form_query.rb` | 33,34,54 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/email_sign_up_otp_form_query.rb` | 33,34,36,46 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/identifier_contract_inventory_query.rb` | 18,22,26,29 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/passkey_sign_in_identity_resolver_query.rb` | 19,20,23,25 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/sign_up_contact_hold_query.rb` | 32,33,34,35 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/sign_up_stuck_registration_report_query.rb` | 34,35,36,40,43,47,50 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/step_up_bootstrap_eligibility_query.rb` | 19,20,22,23 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/telephone_credential_registration_otp_form_query.rb` | 23,46,55,64 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/queries/telephone_sign_up_otp_form_query.rb` | 32,33,35,45 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/resolvers/oidc_authorize_request_resolver.rb` | 167 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `app/services/account_session_revocation.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/acme_selector_surface_config.rb` | 72,73,74,76,77,94 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/administrative_access_lock.rb` | 5 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/base_auth_admission_coordinator.rb` | 73,79,85,617,618,844,847,986,989,999,1001,1010,1013,1024,1029,1125,1130,1131,1167,1178,1205,1208,1229 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/base_selector_bootstrap_authority.rb` | 218 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/credential_security_transition.rb` | 87,153 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/dpop_proof_state_store.rb` | 8 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identifier_blind_index_backfill.rb` | 22,23 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identifier_encryption_reencrypt.rb` | 19,20,54,55 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identifier_hmac_emergency_rotation.rb` | 47,54,156,158,169,170 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identity_email_ceremony_replay_store.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identity_passkey_ceremony_replay_store.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identity_secret_credential_ceremony_replay_store.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identity_step_up_ceremony_replay_store.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/identity_telephone_ceremony_replay_store.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/oidc_access_token_authenticator.rb` | 155,163 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/oidc_authorization_transaction_coordinator.rb` | 14 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/oidc_rp_browser_credential_contract.rb` | 7 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/oidc_token_exchange_coordinator.rb` | 326,468,688,765,776,1105,1157,1168,1181,1190,1232 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/recovery_passcode_top_up.rb` | 106,121,160 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/retention_cross_database_child_purge.rb` | 11,39,58,59 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/session_limit_resolution_token_ref.rb` | 32 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_in_cycle_locator.rb` | 13,19,25 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_in_otp_resend_state.rb` | 25 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_in_otp_resender.rb` | 11,32 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_in_selector_participant.rb` | 21,52 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_recovery_passcode_requirement.rb` | 48,63 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_risk_emitter.rb` | 75,79 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_risk_engine.rb` | 41 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_up_artifact_cleanup.rb` | 32,131,149,183,247,248,261,263,272,277,278,279,280,296,297,298,312 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_up_cycle_locator.rb` | 7,15 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_up_requirement_registry.rb` | 64 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/sign_up_termination.rb` | 112 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/services/visitor_secret_credentials_create.rb` | 4,34,40,53,54,60,89 | com専用は削除 | WU-4 |
| `app/services/withdrawal_lifecycle.rb` | 221,230,239,269,282,293,329,333 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/values/oidc_client_registry.rb` | 15,40,53,72 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/values/oidc_subject.rb` | 51 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/values/rp_cell_binding.rb` | 26,27,30,31,34,35 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/values/security_jwt_auth_access_token_codec.rb` | 29,219,220,237 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/values/security_jwt_oidc_id_token_codec.rb` | 81 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `app/values/webauthn/surface.rb` | 54,55,56 | 共有改修。com認証参照だけ除去 | WU-3/4（必要に応じAU/9） |
| `config/ci.rb` | 13,14,15,17,20 | com_settingを維持、廃止DBだけ除去 | WU-5 |
| `config/database.yml` | 21,22,23,96,98,102,103,104,107,111,112,175,177,179,180,181,184,186,187,210,212,214,215,218,220,269,271,273,274,277,279,355,357,360,361,362,365,368,369,422,424,425,426,427,430,431,432,453,455,456,457,460,461,462,505,507,508,509,512,513,514,589,591,598,599,600,603,612,613,706,708,713,714,715,718,725,726,786,788,793,794,797,804,885,887,892,893,896,903 | com_settingを維持、廃止DBだけ除去 | WU-5 |
| `config/initializers/action_push_native.rb` | 3,4,5 | 削除 | WU-4/5 |
| `config/initializers/preference_reference_defaults.rb` | 16,18,20,22,24 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `config/locales/en.yml` | 835,1091,1092 | 依存の実査。公開host/Publishing/匿名設定を保護 | WU-3/4、T-9 |
| `config/push.yml` | 2,6,8,27,32 | 削除 | WU-4/5 |
| `config/routes/base.rb` | 615,709 | 共有draw維持、com認証routeだけ除去 | WU-3 |

## 付録F. WUのファイル適用票と公開入口

### F.1 WUごとの実装差分と公開検証

以下のパスは現存する対象または「新規P」。`{app,org}`の展開は各realm独立の変更を意味し、共通controllerへの統合を意味しない。§3のファイル群、付録E/Iと合わせて適用する。対象R/ACは§7の全件表を正とし、ここで新IDは発行しない。

| WU | 最初に変更する実ファイル/新規P | 作る差分 / 公開検証の終了条件 |
|---|---|---|
| 0 | code差分なし、evidence/の新規記録（実装時） | baselineのtest-ID/重要集合/未実施理由を保存。基準とHEADを別記 |
| 0R | `db/seeds.rb`、対象`db/*_migrate/`の新migration | 参照構築を単一の正規定義にする。baseline後に実データを変更。欠落/重複の実行確認 |
| P0 | §2.1のPreference ADR、`docs/architecture/preference.md` | 旧adoption/鍵/transport条項と新Dの対応を記述しレビュー。Acceptedを勝手に書換えない |
| 1 | `app/values/oidc_subject.rb`、`app/values/oidc_client_registry.rb` | 明示型分岐、未知値拒否。基準で許可したvisitorは3まで受理 |
| 3 | `config/routes/base.rb`、`auth.rb`、`visa.rb`、`core.rb`、`warp.rb`（全てconfig/routes内）、付録Eの82 controller | com認証route/participant/registryを削除、Base com匿名PreferenceとWarp公開readを残す。匿名・偽RP cookie・削除path・unknownhostのHTTP結果を確認 |
| 4 | 付録Iのshared entry、`app/models/visitor*.rb`、`lib/runtime_role.rb`と`lib/runtime_role_route_guard.rb`の実在caller | com分岐を先に消しdead model/job/configを撤去。eager loadとapp/org重要集合を維持。パスがない場合は同名shimを作らない |
| 5 | `config/database.yml`、com接続/共有com専用表の新migration | 個別承認票のDB/表だけ撤去。snapshot/復元確認が必要、Chronicle/Settingを消さない |
| 6 | 対象route/integration試験、evidence | baseline-ID差分、AC-1〜12/35、残存com認証参照0を集計 |
| 7 | `app/controllers/base/com/preferences_base_controller.rb`、`app/controllers/concerns/preference_write_boundary.rb`（新規P）、`app/values/security_jwt_preference_token_codec.rb`、付録SのCom family | §4/12.7をcomへ実装。JWT/同意binding/400日/reader/不正write/GET0を公開経路で閉じる |
| A1 | `app/controllers/auth/app/application_controller.rb`、org同型、付録F.3の各concrete action | 4分類/除外理由を静的宣言、未知はfail closed。停止時Admission消費/OTP0 |
| A2 | `app/models/concerns/oidc_authorization_transactionable.rb`、`app/controllers/concerns/sign_in_path_refusal.rb`、`sign_in_phase_binding_controller_support.rb`、`sign_up_flow_entry.rb`（後2つも同concerns内）、`lib/auth_phase_refusal_response_boundary.rb`（新規P） | §12.2〜4。三拒否口でsession/DB/認証headers0、正当Cancelだけ終端＋reset。登録完成後の資格情報保護を確認 |
| A3 | `app/controllers/auth/{app,org}/ceremony_bindings_controller.rb`、`app/controllers/concerns/auth_ceremony_admission.rb`、`app/models/concerns/auth_ceremony_session.rb`、`auth_admission_binding.rb`（同models/concerns内）、`app/controllers/auth/{app,org}/sign/switches_controller.rb` | §12.1のSID世代CAS、switched終端、binding一意性。別親/同SID/旧callbackを決定的に競合。初回例外はAC-53追補どおり到達拒否/期限purgeを検証 |
| A4 | 付録F.2の認可消費/committer/Enforcement writer、`app/models/concerns/auth_email_otp_challenge.rb` | Z→OP lock、許可消費→source commitと監査の順。XDB全行を各commit直前/後で障害注入 |
| A5 | `app/models/client_passkey.rb`、`operator_passkey.rb`（同models内）、`app/operations/identity_passkey_registration_final_committer.rb`、`app/jobs/passkey_audit_delivery_job.rb` | slot1..10をDBで強制、ORG external_id統一、outbox必須。11件目/競合INSERT/poison後続/Activity障害を検証 |
| A6 | `app/values/authentication_context_value.rb`とORG対象policy/controller | NormalとStandby scope一致、操作ごとのStep-Up認可。policy集合の漏れ0 |
| A7 | `app/services/withdrawal_lifecycle.rb`、`app/models/concerns/withdrawable.rb`、`client.rb`/`operator.rb`（同models内） | §6.3 reference状態/遷移。暫定(c)のprivacy副作用0、停止/復帰の旧token拒否 |
| A8 | `app/services/rp_request_authenticator.rb`、`app/controllers/concerns/browser_rp_authentication.rb`、`oidc_callback.rb`、`oidc_rp_logout_launcher.rb`、`actor_support.rb`（後3つも同concerns内）、`app/operations/oidc_token_revoker.rb` | §12.6。Base iss/sub/session/owner完全照合、OP DB0、全RP logoutと別browser不変。Bridge/RuntimeRoleは全caller更新後削除 |
| A9 | `app/controllers/concerns/authentication_sequence_gate.rb`、`app/values/sign_in_result.rb`、`app/services/social_auth_login_handler.rb`、`app/controllers/concerns/social_auth.rb` | typed reason→F.3のadapter。socialのみ本人provider確認後L1/L2案内、古いstate/任意redirect拒否 |
| A10 | `app/models/client.rb`、`operator.rb`、付録F.2のcredential writer、`app/controllers/concerns/authentication_base.rb` | dedicated version、snapshot/Root保持lock。変更先行はRoot0、Root先行は変更が待つ |
| A11 | `app/policies/jump_rt_return_policy.rb`と各RPのsign entry/URL生成 | same-origin path/別origin許可edge、rtの完全origin検証。二重decode/任意host拒否 |
| A12 | `app/views/base/shared/authorization_exit_continuation.html.erb`と各continuation | Baseで検証後他RPへ展開。strict-origin/nonce/CSRF、簡素な表示、許可edgeを維持 |
| A13 | `app/policies/sign_up_eligibility_policy.rb`、`app/models/concerns/has_birthdate.rb`、ORG招待/登録controller | サービス日昨日可/今日明日不可、ORG招待AND。休眠adult gateを入口に復活させない |
| A14 | BL-19/22/23に対応する実ファイル（付録Iと現行HEAD差分） | HEAD修正済みを再実装しない。locale既定値はhostごと、ENV一般置換をしない |
| 9 | `app/controllers/visa/{app,org}/authorization_base_controller.rb`、`oauth/authorizations_controller.rb`（各visa realm内）、`app/controllers/concerns/oidc_authorization_continuation.rb`、`oidc_authorization_result_post.rb`（同concerns内）、付録Sのapp/org/actor family | §12.5 POSTと共通writer、sign-up合流/signout copy/reset、旧adoption/DBSC/同意mirror完全撤去 |
| X1 | `config/routes/base.rb`、`auth.rb`とORG configuration caller | settingsへ一括置換、旧alias0、N5 host境界/翻訳/変更table整合 |
| X2 | 既存Not run166件のテスト/実行記録 | 1IDずつ結果/撤去理由。未提供資料や未実行を合格にしない |
| E | Edge/Jump/Awayの固定checkoutから採る実ファイル（適用票に記入） | Rails完了後、xtとrtを独立許可。外部write前に差分/回復を承認 |

新規Pの受入試験ファイル案: `test/integration/auth_phase_refusal_contract_test.rb`、`auth_cancel_commit_contract_test.rb`、`auth_admission_replacement_contract_test.rb`、`preference_writer_contract_test.rb`、`base_identity_preference_ownership_test.rb`、`visa_preference_continuation_test.rb`（全てtest/integration内）。既存の§10試験と重複するケースは既存側を更新し、ファイル数を満たすために複製しない。公開入口から状態/cookie/監査を観測し、private method直接試験/新test helperは作らない。

### F.2 下位writerの具体ファイル集合

基準treeの`app/operations/`/`app/jobs/`から対象名で抽出した**設計の適用集合**。各ファイルの安全性や全Ruby mutationの網羅を認定した一覧ではない。各行の全ファイルを読み、XDBとversion/receiptの適用有無を記録する。対象外とするなら理由を終了票へ残す。新しいwriterや呼出し元が増えれば同じWUの集合へ加える。

| 適用群 / WU | 基準の実ファイル | 変更の契約 |
|---|---|---|
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_credential_removal_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_email_bootstrap_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_email_ceremony_final_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_email_preference_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_passkey_ceremony_final_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_passkey_name_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_passkey_registration_final_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_passkey_registration_verification_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_secret_credential_ceremony_final_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_social_ceremony_grant_issuer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_step_up_ceremony_cancellation_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_step_up_ceremony_freshness_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_step_up_ceremony_grant_issuer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_step_up_email_verification_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_step_up_passkey_verification_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_step_up_totp_verification_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_telephone_ceremony_final_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_totp_ceremony_final_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_totp_enrollment_final_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_totp_enrollment_verification_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| 認証情報/連絡先 committer・grant / A4,A10 | `app/operations/identity_totp_name_committer.rb` | Z actor lock、対象/目的固定、許可消費先行。認証適格性変更はversion増分、表示名のみは増分0 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_audit_outbox_purger.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_claim_committer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_claim_finalizer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_credential_purger.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_issuance_expiry_invalidator.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_issuance_purger.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_manual_issuance_invalidator.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_manual_reattempt_issuer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_manual_reservation_issuer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_name_committer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_passkey_reservation_issuer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_presentation_issuer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_revocation_committer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_sign_in_receipt_purger.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| Secret source/claim/取消 / A2,A4,A10 | `app/operations/client_secret_storage_confirmation_committer.rb` | source完成receipt先判定、資格情報の追加/失効でversion増分。Flow/actor/operation帰属を維持 |
| 登録 source/候補/後段 / A2,A4 | `app/operations/email_sign_up_candidate_creator.rb` | 完成と保留を分離、§12.4、Z完成をcleanupで失わない |
| 登録 source/候補/後段 / A2,A4 | `app/operations/sign_app_up_telephone_registration_finalizer.rb` | 完成と保留を分離、§12.4、Z完成をcleanupで失わない |
| 登録 source/候補/後段 / A2,A4 | `app/operations/social_auth_signup_finalizer.rb` | 完成と保留を分離、§12.4、Z完成をcleanupで失わない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/email_credential_registration_otp_delivery_guard.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/email_credential_registration_otp_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/email_credential_registration_otp_resend_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/email_reentry_otp_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/email_sign_up_otp_delivery_guard.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/email_sign_up_otp_delivery_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/email_sign_up_otp_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/identity_totp_ceremony_result_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/identity_totp_enrollment_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/telephone_credential_registration_otp_delivery_guard.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/telephone_credential_registration_otp_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/telephone_credential_registration_otp_resend_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/telephone_sign_up_otp_delivery_guard.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/telephone_sign_up_otp_delivery_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| OTP発行/実配送 / A1,A2,A4 | `app/operations/telephone_sign_up_otp_issuer.rb` | Sentry、親/世代、正規lock、送信/進行の責務を用途別に区別。D-58対象のEmail sign-in/Email・telephone signupは進行commit後に送信、失敗/不明も再送/Cancel。TOTP/credential登録等へD-58を機械適用しない |
| Enforcement/retention/backfill / A4,A7,A10 | `app/jobs/enforcement_expiry_job.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/jobs/enforcement_reconciliation_job.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/jobs/retention_purge_job.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/authority_owner_direct_binding_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/authority_owner_family_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/authority_owner_predeployment_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/authority_resource_lifecycle_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/avatar_concrete_ownership_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/avatar_group_concrete_ownership_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/enforcement_case_apply_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/enforcement_case_end_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/operator_telephone_public_id_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/public_id_null_only_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| Enforcement/retention/backfill / A4,A7,A10 | `app/operations/staff_identity_audit_event_bigint_backfill_operation.rb` | owner/hold/recoveryを維持。認証状態変更はversion/epochの各責務を分離 |
| 監査/既存後段job / A2,A5 | `app/jobs/client_secret_audit_delivery_job.rb` | 既存配送/再試行のみ、poisonで後続停止0。Secret完成receiptを先に判定 |
| 監査/既存後段job / A2,A5 | `app/jobs/client_secret_audit_outbox_purge_job.rb` | 既存配送/再試行のみ、poisonで後続停止0。Secret完成receiptを先に判定 |
| 監査/既存後段job / A2,A5 | `app/jobs/client_secret_lifecycle_job.rb` | 既存配送/再試行のみ、poisonで後続停止0。Secret完成receiptを先に判定 |
| 監査/既存後段job / A2,A5 | `app/jobs/contact_audit_delivery_job.rb` | 既存配送/再試行のみ、poisonで後続停止0。Secret完成receiptを先に判定 |
| 監査/既存後段job / A2,A5 | `app/jobs/passkey_audit_delivery_job.rb` | 既存配送/再試行のみ、poisonで後続停止0。Secret完成receiptを先に判定 |
| 監査/既存後段job / A2,A5 | `app/jobs/social_audit_delivery_job.rb` | 既存配送/再試行のみ、poisonで後続停止0。Secret完成receiptを先に判定 |

この抽出集合は74ファイル。名前に一致しないcontroller/modelの直接更新は集合外として放置せず、§12.6のcall-site確認で同じmanifestへ割り付ける。実行時のmutation追跡/受入は未実施。

### F.3 Authの公開action分類とHTTP adapter

基準treeのAuth app/orgの公開action候補をconcrete fileごとに列挙する。Rubyの静的`public`/`private`境界で抽出した**候補**であり、実routeの全action集合そのものではない。継承actionと`public :create`等の宣言は実装時にRails route inventoryとの突合で補う。未知actionを名前のsubstringで除外しない。

| concrete controller file | そのファイルの公開method候補 | 宣言 / adapter |
|---|---|---|
| `app/controllers/auth/app/api/v0/healths_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/api/v0/revisions_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/apple/notifications_controller.rb` | `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/billings_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/ceremony_bindings_controller.rb` | `show` | parent_intent / 既存handoff・phase409 |
| `app/controllers/auth/app/csp_violation_reports_controller.rb` | `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/edge/v0/token/checks_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/health/livenesses_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/health/readinesses_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/health/startups_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/healths_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/omniauth/omniauth_callbacks_controller.rb` | `omniauth`, `handle_omniauth_callback`, `failure` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/revisions_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/robots_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/roots_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/settings/apples_controller.rb` | `show`, `edit`, `create`, `destroy` | parent_intent / provider callback |
| `app/controllers/auth/app/settings/googles_controller.rb` | `show`, `edit`, `create`, `destroy` | parent_intent / provider callback |
| `app/controllers/auth/app/settings/removals_controller.rb` | `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/settings/totps/enrollments_controller.rb` | `create`, `destroy` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/settings/totps_controller.rb` | `new`, `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/settings_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/sign/cancellations_controller.rb` | `create` | parent_intent / 既存handoff・phase409 |
| `app/controllers/auth/app/sign/in/challenge/passkeys_controller.rb` | `new`, `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/challenges_controller.rb` | `show`, `destroy` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/checks_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/emails_controller.rb` | `new`, `edit`, `create`, `update`, `destroy` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/guards_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/passkey/options_controller.rb` | `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/passkey/verifications_controller.rb` | `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/passkeys_controller.rb` | `new` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/secrets_controller.rb` | `new`, `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/in/sentries_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/ins_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/app/sign/outs_controller.rb` | `show`, `new`, `edit`, `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/sign/switches_controller.rb` | `create` | parent_intent / 既存handoff・phase409 |
| `app/controllers/auth/app/sign/up/check/apple/confirmations_controller.rb` | `show`, `update`, `destroy` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/check/email/birthdates_controller.rb` | `show`, `update`, `destroy` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/check/email/otps_controller.rb` | `show`, `create`, `update`, `destroy` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/check/google/confirmations_controller.rb` | `show`, `update`, `destroy` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/check/telephone/otps_controller.rb` | `show`, `create`, `update`, `destroy` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/check/telephone/passkeys_controller.rb` | `show`, `create`, `update`, `destroy` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/check/telephone/secrets_controller.rb` | `show`, `create`, `update`, `reattempt`, `destroy` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/emails_controller.rb` | `new`, `create` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/guard/base_controller.rb` | `show` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/sentries_controller.rb` | `show` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/up/telephones_controller.rb` | `new`, `create` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sign/ups_controller.rb` | `show` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/app/sitemaps_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/social/link_completions_controller.rb` | `create` | parent_intent / provider callback |
| `app/controllers/auth/app/social/registrations_controller.rb` | `create` | parent_intent / provider callback |
| `app/controllers/auth/app/social/sessions_controller.rb` | `create` | parent_intent / provider callback |
| `app/controllers/auth/app/verification/cancellations_controller.rb` | `create` | parent_intent / 既存handoff・phase409 |
| `app/controllers/auth/app/verification/emails_controller.rb` | `new`, `edit`, `create`, `update` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/verification/redeliveries_controller.rb` | `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/verification/setups_controller.rb` | `new` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/verification/totps_controller.rb` | `new`, `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/app/web/v0/in/email/otps_controller.rb` | `create` | sign_in / JSON（親purposeでsignupなら静的override） |
| `app/controllers/auth/org/accounts_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/api/v0/healths_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/api/v0/revisions_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/application_controller.rb` | `acme_authority_host` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/audit_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/billing_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/ceremony_bindings_controller.rb` | `show` | parent_intent / 既存handoff・phase409 |
| `app/controllers/auth/org/configurations_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/csp_violation_reports_controller.rb` | `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/edge/v0/token/checks_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/health/livenesses_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/health/readinesses_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/health/startups_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/healths_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/iam_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/omniauth/omniauth_callbacks_controller.rb` | `omniauth`, `failure` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/revisions_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/robots_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/roots_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/settings/entras_controller.rb` | `show`, `edit`, `create`, `destroy` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/settings/removals_controller.rb` | `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/settings_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/sign/cancellations_controller.rb` | `create` | parent_intent / 既存handoff・phase409 |
| `app/controllers/auth/org/sign/in/checks_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/emergency/passkey/options_controller.rb` | `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/emergency/passkey/verifications_controller.rb` | `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/emergency/passkeys_controller.rb` | `new` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/guards_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/passkey/options_controller.rb` | `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/passkey/verifications_controller.rb` | `create` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/passkeys_controller.rb` | `new` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/in/sentries_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/ins_controller.rb` | `show` | sign_in / form（options/verificationsはJSON） |
| `app/controllers/auth/org/sign/outs_controller.rb` | `show`, `new`, `edit`, `create` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/sign/up/invitations_controller.rb` | `new`, `create` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/org/sign/up/sentries_controller.rb` | `show` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/org/sign/ups_controller.rb` | `show` | sign_up / form（provider callbackは専用adapter） |
| `app/controllers/auth/org/sitemaps_controller.rb` | `show` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/social/sessions_controller.rb` | `new`, `create` | parent_intent / provider callback |
| `app/controllers/auth/org/support_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/system_controller.rb` | `index` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |
| `app/controllers/auth/org/verification/cancellations_controller.rb` | `create` | parent_intent / 既存handoff・phase409 |
| `app/controllers/auth/org/verification/setups_controller.rb` | `new` | excluded（sign entry対象外） / 元のHTTP契約、除外理由を具体classへ宣言 |

Standbyの公開actionはsign_inであり「excluded」の停止回避にはしない。確認済みの専用方針を宣言して通常停止と区別する。health/robots/独立設定/Step-Up等のexcludedは「認証入口/OTP再送ではない」を具体理由として持つ。親purposeによる分類はサーバーで検証したbindingから決め、URLの名称/paramsでsign_in/signupを自由選択させない。F.3で誤分類があれば実routeと所有契約に照らして差分を直すまでA1完了にしない。

## 付録S. Preferenceの実表・NULL列・migration差分

以下の【事実】は基準commitの生成structure.sqlを静的に読んだもので、DBの実行件数ではない。表の存在・列型・NOT NULLを事実として記し、維持/撤去/変更は【設計P】として分ける。生成SQLを手編集せず新migrationで変更する。

### S.1 親/同意列のBefore/After

| 対象 | 基準の列 | 採用するAfter / migration |
|---|---|---|
| 3 realm匿名親 | `binding_method_id`, `dbsc_status_id`, `dbsc_challenge`, `dbsc_challenge_issued_at`, `dbsc_public_key`, `dbsc_session_id`, `token_digest`, `used_at`, `replaced_by_id` | 全て撤去。認証/DBSC/単回tokenの状態を匿名Preferenceに残さない |
| 同親 | `public_id`, nullable `jti`, `status_id`, `discard_at`, `purge_eligible_at`, `explicit_fields`, timestamps | public_id維持、jti NOT NULL UNIQUE、statusはactive/retired reference。discard/purgeのinfinity状態列と匿名explicit_fieldsを撤去し、last_issued_at/last_issued_expires_at NOT NULLを追加。purgeは最終exp＋30日から計算 |
| 3 realm cookie子 | consented/functional/performant/targetable（全NOT NULL boolean）、nullable consent_version/consented_at | boolean維持、nullable metadataは新`*_preference_consent_receipts`子record（preference FK UNIQUE、version UUID/recorded_at NOT NULL）へ。肯定保存は同transactionでreceipt必須、未保存はreceiptなし。拒否保存も事実を記録し、falseと未保存をNULLで区別しない |
| Client/Operator Preference親 | `user_id`/`staff_id`、表示値10列、NULL許容explicit_fields、同意boolean4列＋consented_at/consent_version | FK列をclient_id/operator_idへstrict renameしcallerも同時変更、aliasなし。表示の正規値は既存option FK子recordへ統一、親の重複表示列/同意6列を撤去。explicit_fields NOT NULL default []、status referenceを追加しactive/retiredを明示 |
| 同actor親のunique | actor FKの全行unique | 退役済み設定を保持できるようactive行だけactor UNIQUE。同actorにactive設定二行はDB拒否。reset後の明示保存は新active設定を作成 |
| 表示子/option | 各tableの既存NOT NULL/FK | 全項目preference_id UNIQUE、option_id NOT NULL/FK。realm/DBを跨ぐFKやoption ID流用はしない。wireはそのrealmのoption.name |
| browser binding / Web Push | なし | §4.3の新table/NOT NULL/FK/unique。bindingはpreferenceだけunique、digest重複可。Push初期disabled |
| registration/version（Preference外） | なし | §12.4 completion receipt、Client/Operator credential_version、A7 withdrawal referenceを各所有Z migrationへ。OPのFKをZへ跨がせない |

displayの10項目はtheme/language/timezone/currency/date_format/time_format/motion/density/page_size/region。cookie表示はregionを除く9項目。`adult_content_gate`は休眠の子record/optionとして維持し、D-27どおりruntimeの表示/保存registryから除く。

cookie receiptのcopyはsignoutの匿名DB transaction内で値/receipt/bindingと一緒に行い、Base cookieをVisaで発行しない。旧データを移す場合はNULLの意味をアプリに残さず一回の承認済みデータ処理で判別する。判別不能値を肯定同意へ変換しない。

### S.2 基準の全Preference表とNULL列

表単位の全件集合（setting3、actor Zenith2）。各表のid/timestamps等を含むNULL許容列を列挙。NULL列が「なし」でもFK/unique/referenceの受入は省略しない。

| 基準ファイル:行 / 実表 | NULL許容列【事実】 | 処置【設計P】 |
|---|---|---|
| `db/app_setting_structure.sql:58` / `app_preference_adult_content_gate_options` | なし | 休眠model/option/子表として維持 |
| `db/app_setting_structure.sql:86` / `app_preference_adult_content_gates` | なし | 休眠model/option/子表として維持 |
| `db/app_setting_structure.sql:118` / `app_preference_binding_methods` | なし | 旧transport referenceを撤去 |
| `db/app_setting_structure.sql:146` / `app_preference_cookies` | `consent_version`, `consented_at` | boolean維持、NULL metadataをreceiptへ |
| `db/app_setting_structure.sql:183` / `app_preference_currencies` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:215` / `app_preference_currency_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:243` / `app_preference_date_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:271` / `app_preference_date_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:303` / `app_preference_dbsc_statuses` | なし | 旧transport referenceを撤去 |
| `db/app_setting_structure.sql:331` / `app_preference_densities` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:363` / `app_preference_density_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:391` / `app_preference_language_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:419` / `app_preference_languages` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:451` / `app_preference_motion_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:479` / `app_preference_motions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:511` / `app_preference_page_size_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:539` / `app_preference_page_sizes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:571` / `app_preference_region_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:599` / `app_preference_regions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:631` / `app_preference_statuses` | なし | 匿名active/retiredの明示referenceへ |
| `db/app_setting_structure.sql:659` / `app_preference_theme_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:687` / `app_preference_themes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:719` / `app_preference_time_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:747` / `app_preference_time_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:779` / `app_preference_timezone_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:807` / `app_preference_timezones` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_setting_structure.sql:839` / `app_preferences` | `dbsc_challenge`, `dbsc_challenge_issued_at`, `dbsc_public_key`, `dbsc_session_id`, `jti`, `replaced_by_id`, `token_digest`, `used_at` | S.1の匿名親へ |
| `db/org_setting_structure.sql:70` / `org_preference_adult_content_gate_options` | なし | 休眠model/option/子表として維持 |
| `db/org_setting_structure.sql:98` / `org_preference_adult_content_gates` | なし | 休眠model/option/子表として維持 |
| `db/org_setting_structure.sql:130` / `org_preference_binding_methods` | なし | 旧transport referenceを撤去 |
| `db/org_setting_structure.sql:158` / `org_preference_cookies` | `consent_version`, `consented_at` | boolean維持、NULL metadataをreceiptへ |
| `db/org_setting_structure.sql:195` / `org_preference_currencies` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:227` / `org_preference_currency_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:255` / `org_preference_date_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:283` / `org_preference_date_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:315` / `org_preference_dbsc_statuses` | なし | 旧transport referenceを撤去 |
| `db/org_setting_structure.sql:343` / `org_preference_densities` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:375` / `org_preference_density_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:403` / `org_preference_language_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:431` / `org_preference_languages` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:463` / `org_preference_motion_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:491` / `org_preference_motions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:523` / `org_preference_page_size_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:551` / `org_preference_page_sizes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:583` / `org_preference_region_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:611` / `org_preference_regions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:643` / `org_preference_statuses` | なし | 匿名active/retiredの明示referenceへ |
| `db/org_setting_structure.sql:671` / `org_preference_theme_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:699` / `org_preference_themes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:731` / `org_preference_time_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:759` / `org_preference_time_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:791` / `org_preference_timezone_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:819` / `org_preference_timezones` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_setting_structure.sql:851` / `org_preferences` | `dbsc_challenge`, `dbsc_challenge_issued_at`, `dbsc_public_key`, `dbsc_session_id`, `jti`, `replaced_by_id`, `token_digest`, `used_at` | S.1の匿名親へ |
| `db/com_setting_structure.sql:70` / `com_preference_adult_content_gate_options` | なし | 休眠model/option/子表として維持 |
| `db/com_setting_structure.sql:98` / `com_preference_adult_content_gates` | なし | 休眠model/option/子表として維持 |
| `db/com_setting_structure.sql:130` / `com_preference_binding_methods` | なし | 旧transport referenceを撤去 |
| `db/com_setting_structure.sql:158` / `com_preference_cookies` | `consent_version`, `consented_at` | boolean維持、NULL metadataをreceiptへ |
| `db/com_setting_structure.sql:195` / `com_preference_currencies` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:227` / `com_preference_currency_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:255` / `com_preference_date_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:283` / `com_preference_date_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:315` / `com_preference_dbsc_statuses` | なし | 旧transport referenceを撤去 |
| `db/com_setting_structure.sql:343` / `com_preference_densities` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:375` / `com_preference_density_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:403` / `com_preference_language_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:431` / `com_preference_languages` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:463` / `com_preference_motion_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:491` / `com_preference_motions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:523` / `com_preference_page_size_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:551` / `com_preference_page_sizes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:583` / `com_preference_region_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:611` / `com_preference_regions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:643` / `com_preference_statuses` | なし | 匿名active/retiredの明示referenceへ |
| `db/com_setting_structure.sql:671` / `com_preference_theme_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:699` / `com_preference_themes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:731` / `com_preference_time_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:759` / `com_preference_time_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:791` / `com_preference_timezone_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:819` / `com_preference_timezones` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/com_setting_structure.sql:851` / `com_preferences` | `dbsc_challenge`, `dbsc_challenge_issued_at`, `dbsc_public_key`, `dbsc_session_id`, `jti`, `replaced_by_id`, `token_digest`, `used_at` | S.1の匿名親へ |
| `db/app_zenith_structure.sql:1770` / `client_preference_adult_content_gate_options` | なし | 休眠model/option/子表として維持 |
| `db/app_zenith_structure.sql:1798` / `client_preference_adult_content_gates` | なし | 休眠model/option/子表として維持 |
| `db/app_zenith_structure.sql:1830` / `client_preference_currencies` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:1862` / `client_preference_currency_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:1890` / `client_preference_date_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:1918` / `client_preference_date_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:1950` / `client_preference_densities` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:1982` / `client_preference_density_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2010` / `client_preference_language_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2038` / `client_preference_languages` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2070` / `client_preference_motion_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2098` / `client_preference_motions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2130` / `client_preference_page_size_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2158` / `client_preference_page_sizes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2190` / `client_preference_region_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2218` / `client_preference_regions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2250` / `client_preference_theme_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2278` / `client_preference_themes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2310` / `client_preference_time_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2338` / `client_preference_time_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2370` / `client_preference_timezone_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2398` / `client_preference_timezones` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/app_zenith_structure.sql:2430` / `client_preferences` | `consented_at`, `consent_version`, `explicit_fields` | S.1のactor親へ（同意/表示重複を撤去） |
| `db/org_zenith_structure.sql:1943` / `operator_preference_adult_content_gate_options` | なし | 休眠model/option/子表として維持 |
| `db/org_zenith_structure.sql:1971` / `operator_preference_adult_content_gates` | なし | 休眠model/option/子表として維持 |
| `db/org_zenith_structure.sql:2003` / `operator_preference_currencies` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2035` / `operator_preference_currency_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2063` / `operator_preference_date_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2091` / `operator_preference_date_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2123` / `operator_preference_densities` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2155` / `operator_preference_density_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2183` / `operator_preference_language_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2211` / `operator_preference_languages` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2243` / `operator_preference_motion_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2271` / `operator_preference_motions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2303` / `operator_preference_page_size_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2331` / `operator_preference_page_sizes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2363` / `operator_preference_region_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2391` / `operator_preference_regions` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2423` / `operator_preference_theme_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2451` / `operator_preference_themes` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2483` / `operator_preference_time_format_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2511` / `operator_preference_time_formats` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2543` / `operator_preference_timezone_options` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2571` / `operator_preference_timezones` | なし | option/表示子を維持、S.1のunique/FK/NOT NULL保証 |
| `db/org_zenith_structure.sql:2603` / `operator_preferences` | `consented_at`, `consent_version`, `explicit_fields` | S.1のactor親へ（同意/表示重複を撤去） |

表数: `db/app_setting_structure.sql` 27, `db/org_setting_structure.sql` 27, `db/com_setting_structure.sql` 27, `db/app_zenith_structure.sql` 23, `db/org_zenith_structure.sql` 23、合計127表。

### S.3 旧class/橋渡しの判定

`plans/backlog/legacy-preference-models-retirement-plan.md`の旧User/Staff/Customerや約70classという数値は現在の実装事実に使わない。現在のClient/OperatorとShared App/Org/ComをS.2に対応付け、actorのassociation名/旧user/staff foreign keyはmigrationとcaller更新を同時に行う。橋渡しは実在class/tableと読取りがある場合だけ撤去対象にし、過去文書にあるという理由で架空migrationを作らない。Chronicle/auditの履歴はこの表の外で保持する。com actor-localはWU-4/5の撤去範囲で、ComPreferenceはWU-7で再設計する。

S.2はDDLの棚卸しを完了した表であり、既存データの全行数/NULL実件数/移行の安全性を測ったものではない。削除対象の実数と回復票は§12.8で取得する。承認済みD-12を理由にデータ削除の実行承認を省略しない。
