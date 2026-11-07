# five.md — Experience / Consent / Affinity の再設計
> Archived snapshot prepared for the 2026-11 handoff; the ignored root original remains in the working tree.


作業文書（gitignored）。オーナーの指示により日本語で記す。昇格する ADR / spec / docs は英語。

本書は 2 部に分かれる。

- **第I部 現行契約（C0〜C15）:** 2026-11-04 時点で有効な名称・決定・制約・未決。実装の根拠にできるのは第I部と、C8 で Active とした付録T の条項だけ。
- **第II部 歴史的記録（旧 §0〜§14、付録T）:** 2026-11-03〜04 の議論・調査・レビューの記録。§番号は当時のまま。当時の名称（Preference、S / Z、guest / user experience など）、当時の実装の引用、置き換え済みの決定、未承認の案を含む。**第II部の文章を、第I部で採用していない限り実装の根拠にしない。** 第I部から第II部を引くときは「記録 §12.4」のように書く。

# 第I部 現行契約

## C0. 位置づけ

| 項目 | 内容 |
|---|---|
| 対象 | 旧 Preference の抜本的な作り直し。Experience / Consent / Affinity の 3 単位に分ける（記録 §12.1、§14.1） |
| 範囲 | Base の app / com / org、Visa の sign-in / sign-out、Auth / Core / Warp の読み取り。step-up（`specs/op-mediated-step-up/`）は別作業で扱わない |
| 要件の正本 | この領域については本書（2026-11-04 オーナー決定、記録 §12.4-6）。one.md の冒頭に移管を注記済み |
| two.md との関係 | two.md の冒頭に「Preference の部分は five.md に移した。実装しない」と注記済み。two.md の原文は付録T。付録T の状態は C8 |
| 版 | **最終稿（2026-11-04）。** 命名・責務・決定事項の整理を終え、未決事項（C5）を明示して実装設計へ引き継ぐ版。外部レビュー 6 回と Claude Code の最終レビュー（C15）を反映。実装してよい完成仕様ではない。本書は gitignored の作業文書なので、引き継ぎではこの版を固定して参照する（版の固定の方法は C5-21） |
| 状態 | 設計中。**実装計画は確定しない。** Implementation is limited to the individually closed slices recorded in C9; unresolved C5 items remain design blockers. This document's edits do not imply that ADRs, code, or DB were changed |
| 読む順 | C1（要約）→ C2（用語）→ C3（制約）→ C4（決定）→ C5（未決）→ C6（命名の対応表）→ C7（cookie）→ C8（付録T の状態）→ C9（実装の状態と ADR）→ C10（レビュー 1・2 の指摘の状態）→ C11（レビュー 3 の処置）→ C12（レビュー 4 の処置）→ C13（レビュー 5 の処置）→ C14（レビュー 6 の処置）→ C15（最終レビュー） |

## C1. 現行の要約（2026-11-04）

- 旧 Preference を **Experience / Consent / Affinity** の 3 単位に分ける。「Preference」は新しい設計・新しい自前実装の総称として使わない（過去の記録、旧実装への参照、外部仕様の名称は機械的に変えない）。
- Experience は **Browser Experience**（setting 系、app / com / org）と **Account Experience**（zenith 系、app / org。所有者は既存の Client / Operator）に分かれる。
- 表示する値は **Display Snapshot**（独立した DB の正本を持たない導出結果）。ログイン中は「Account Experience の明示した値 → Browser Experience → 既定値」、未ログインは「Browser Experience → 既定値」。
- **Guest / User** は要求の認証状態と書き込み経路の区分。Guest は Browser Experience を、User は Account Experience を変更する。相互にフォールバックしない。
- **Cookie Consent** は Consent の具体的な概念。ログインの有無によらず独立した経路で変更する。
- **Affinity** は setting 系に置き、ブラウザには JWS を置く。本人のレコードと関連させず、認証・認可に使わない。
- 名称は確定したが、cookie の枚数・属性、JWS / JWT の claims・鍵、復旧手順などの詳細は未決（C5）。

## C2. 正式用語

| 用語 | 意味 | 置き場 | 備考 |
|---|---|---|---|
| **Experience** | 表示・操作などに関する好みの大分類 | — | 表示の 10 項目と Web Push の設定（Browser / Account の両方）、通知の希望（Account だけ） |
| **Browser Experience** | ブラウザ側の保存領域に対応する好み | setting 系（`app_setting` / `com_setting` / `org_setting`） | app / com / org に存在。**未ログイン時だけのデータではない**（ログイン中も Account Experience の未指定項目のフォールバックとして読む）。物理端末の識別や同一人物の保証を意味しない。旧称: guest experience、ブラウザ設定、S |
| **Account Experience** | アカウントに属する好み | zenith 系（`app_zenith` / `org_zenith`） | app / org に存在、com には作らない。所有者は既存の Client / Operator。Account model・User model は作らない。旧称: user experience、アカウント設定、Z |
| **Consent** | 同意の大分類 | — | 修飾のない Consent という具体的なモデルは作らない |
| **Cookie Consent** / `CookieConsent` | Cookie の利用に関する同意 | setting 系（app / com / org） | OAuth / OIDC の同意、Apple 連携の同意撤回（`consent_revoked`）、登録時の規約同意とは別。既存の consent の名前を一括で `cookie_consent` に変えない |
| **Affinity** | 過去の操作・選択に由来し、次回の案内を補助するブラウザ側の記憶（信頼しない補助情報） | setting 系（app / org から実装。com は用途ができたとき、C4-23）＋ブラウザの JWS | zenith の本人レコードへの関連を持たない（これは法的・技術的な完全匿名の保証ではない）。項目は具体名にする。最初の候補は `last_sign_in_method`（**前回選択した方式**。前回認証に成功した方式ではない） |
| **Display Snapshot** | Browser Experience / Account Experience / 既定値から導出した表示の値 | 独立した DB の正本を持たない（cookie / JWT で運ぶことはある） | 第 4 の設定機構ではない。Browser Experience の行を特定・更新するための情報とは論理上区別する。クラスが必要なら値オブジェクトの候補（Active Record model や form object は作らない） |
| **Guest** | 書き込み先の surface 自身で未ログインと判定された要求 | — | Browser Experience を変更する経路 |
| **User** | 書き込み先の surface 自身でログイン済みと判定された要求 | — | 認証済みの Client / Operator の Account Experience を変更する経路。他の RP のログイン状態を横断的に調べる仕組みは作らない |

Browser / Account はデータの所属、Guest / User は要求の認証状態と書き込み経路。この 2 軸を混同しない。モデル名を Browser / Account に揃えることを理由に、Guest / User のルート・controller の区分を改名しない。

## C3. 現行の制約

1. **`localStorage` と `sessionStorage` は使わない。** 代わりに IndexedDB などの新しい保存機構を無断で導入しない（記録 §10.3 の `localStorage` 候補は失効）。
2. form object は使わない。User model は復活させない。
3. Experience / Consent / Affinity のルートと controller の責務を分ける。
4. Guest / User の書き込みを、認証状態で相互にフォールバックさせない。
5. Account Experience の保存時に Browser Experience へ複製しない（旧二重書き込みは廃止。記録 §9.5 は置き換え済み）。
6. 表示の優先順位は C1 のとおり。sign-out 後の表示は Browser Experience または既定値から導出する。sign-out 時に Account Experience の値を Browser Experience へ転記しない。
7. Experience の反映の失敗だけで、成立すべき認証を失敗させない。
8. Cookie Consent はログインの有無によらず独立した経路で変更する。
9. Affinity は sign-out 後も保持する。
10. 各単位のリセットは独立した操作とし、一括リセットを新設しない。
11. Web Push の `enabled` / `disabled` は Browser Experience と Account Experience の両方に置き（ログイン中は Account Experience を優先、C4-20）、通知の希望は Account Experience に置く。Web Push の設定を、ブラウザの通知許可や実際の Push の購読と同一視しない。
12. realm 間のデータ・資格情報の分離を維持する。
13. 認可は命名や controller の分離だけで足りるとしない。Account Experience の対象は認証済みの Client / Operator から決め、request の `actor_id` やブラウザ用の資格情報から別人の設定を選ばない。Strong Parameters を認可の代わりにしない。
14. 設定値を配布・キャッシュする API は復活させない（記録 §2-7、§2-8、ADR の Amendment）。
15. 本番未公開・既存利用者データの移行は考慮しない。ただし、DB の作り直しや破壊的操作の実行の承認ではない。
16. DB が SSOT で JWT に優先する。壊れた・古い JWT の判定後の扱いは記録 §12.7-1（オーナー確認済み）の方針で、手順の詳細は未決（C5）。
17. テスト環境の確認を本実装の前に終わらせる。テスト DB の残骸と構造 dump の問題は、一律の障害ではなくなっている可能性がある（C9.1）。確認済みの具体的な欠陥は `db/chronicle_structure.sql` に表の定義がないこと（C9.1）。どのテスト・DB・dump が健全かを確かめ、残る問題だけを直す。
18. GET / HEAD では DB を書かない。表示の作り直し（C4-3）と、壊れた・古い JWT の新しい JWT の発行（C4-9）は、cookie を出し直すだけにする（記録 §12.4-3）。初回の GET で永続の行を作るかどうかの整合は C5-3。

## C4. 決定済み（2026-11-04 時点）

| # | 決定 | 根拠 |
|---|---|---|
| 1 | 3 単位（Experience / Consent / Affinity）への作り直し。「Preference」の語を新設計で使わない | 記録 §12.1、§14.1、本書 C1 |
| 2 | Experience の 2 つの置き場と名称（Browser Experience / Account Experience） | 記録 §14.1、本書 C2 |
| 3 | Display Snapshot の導出順と、作り直す時（保存の直後、sign-in、sign-out、Base の GET で壊れている・古いとき。作り直しは cookie だけで DB を書かない） | 記録 §12.4-1、§12.4-3 |
| 4 | **Experience の保存**は、ログイン中は Account Experience、未ログインは Browser Experience（Cookie Consent と Affinity はそれぞれ独立した経路で保存する） | 記録 §12.4-4 |
| 5 | Guest / User の controller 分離、相互フォールバックの禁止、form object 不採用 | 記録 §2-1、§2-2 |
| 6 | Cookie Consent は setting 系、独立した経路 | 記録 §12.4-1、§14.2、本書 C2 |
| 7 | Affinity は setting 系、ブラウザに JWS、本人と関連させない、認証・認可に使わない、sign-out で残す | 記録 §13.1、§12.8-1 |
| 8 | 3 単位のルートと controller を完全に分ける。リセットは単位ごと | 記録 §12.8-2、§12.8-3 |
| 9 | 壊れた・古い JWT は新しい JWT を発行（GET は止めて再読み込み、書き込みは拒否してやり直し）。中身は DB の行から作り、信頼できる行がなければ初回と同じ扱い。**判定と発行ができるのは、DB を読み cookie を書ける Base と Visa だけ。** Auth / Core / Warp は DB を読まないので `jti` の古さを判定できず、署名・realm・期限が正しい JWT は期限まで表示に使う（C5-4）。どの操作にこの規則を当てるかは C5.1 の 1 つめ | 記録 §12.7-1 |
| 10 | sign-in で Experience の反映に失敗してもログインは完了させる。表示は既定値に退避し、Base の GET で作り直す | 記録 §9.3、§12.7-2 |
| 11 | sign-out 後は Browser Experience（なければ既定値）で表示する（旧要件 D-55 を改める） | 記録 §12.4-2 |
| 12 | 設定値の配布・キャッシュ API の破棄と、廃止するルート | 記録 §2-7、§2-8 |
| 13 | 既存データの移行は考慮しない | 記録 §12.4-5 |
| 14 | 要件の正本は本書 | 記録 §12.4-6 |
| 15 | `localStorage` / `sessionStorage` を使わない | 2026-11-04 オーナー指示（命名整理の指示） |
| 16 | 名称体系（C2、C6 の目標名） | 2026-11-04 オーナー指示（命名整理の指示） |
| 17 | **Affinity の名前に統一する。** Affinity は「過去の操作・選択に由来し、次回の案内を補助するブラウザ側の記憶」（ブラウザに属する状態の総称ではない。Browser Experience と Cookie Consent は含まない。レビュー 3 で定義を修正）。Accepted ADR が予約する cookie 名 `continuity` は使わず `affinity` にする（ADR の Amendment は 2026-11-04 に実施済み。範囲も C4-21 で Affinity に絞った） | 2026-11-04 オーナー決定 |
| 18 | 紛らわしい既存の名前の改名先: `ActorPreferenceExplicitDisplay#explicit_display_snapshot` → `explicit_values`（列 `explicit_fields` と対にする）、`SecurityJwtPreferenceTokenCodec.valid_anonymous_display_snapshot?` → `valid_display_snapshot?`。「snapshot」の語は Display Snapshot だけに使う（コードの改名は 2026-11-04 に完了。`valid_display_snapshot?` は、ログイン中の表示値にも同じ検証規則が当てはまることを改名時に確認。`anonymous` を外すと適用範囲が広がって読めるため。`explicit_values` は地域を含まない（C5.1）） | 2026-11-04 オーナー決定 |
| 19 | Cookie Consent のパスは単数の `/consent/cookie`（`resource :cookie`） | 2026-11-04 オーナー決定 |
| 20 | **Web Push の設定は、配信に使わなくても設定できるようにする。** 表示の 10 項目と同じ扱いで、Browser Experience（app / com / org）と Account Experience（app / org）の両方に置き、ログイン中は Account Experience を優先する。com と、未ログインの app / org でも設定できる。通知の希望は Account Experience のまま。設定はブラウザの通知許可や Push の購読と同一視しない（C3-11） | 2026-11-04 オーナー決定。C5-9 を解消 |
| 21 | **ADR の `affinity` を Affinity の定義に絞る。** 以前の `continuity` が指していた「ブラウザに属する状態」全般のうち、Affinity 以外（以前使ったアカウント、ブラウザの識別子など）は、機能ごとに専用の cookie を持つ（ADR の Decision 節どおり）。ADR の Amendment と「Affinity Cookie」の節を修正済み（2026-11-04） | 2026-11-04 オーナー決定。C5-15 を解消 |
| 22 | **Web Push の優先順位は表示の項目と同じ。** ログイン中は、Account Experience で本人が明示した値だけを優先し、未設定なら Browser Experience、なければ既定値（`disabled`） | 2026-11-04 オーナー決定。C5-18 の一部を解消（Display Snapshot に含めるか、通知の希望との関係は未決） |
| 23 | **Affinity の概念の定義は realm 間で共通にし、データと資格情報は realm ごとに分離する（C3-12）。実装は用途のある realm（app / org）から。** `ComAffinity` は com で記憶したいものができたときに作る | 2026-11-04 オーナー決定。C5-19 を解消 |
| 24 | **com には User のルート（`/experience/user/...`）を置かない。** app / org は Guest と User、com は Guest だけ | 2026-11-04 オーナー決定。C5-20 を解消 |

## C5. 未決（名称の承認は、これらの承認ではない）

1. cookie の物理的な枚数、共有範囲、属性、寿命（C7）。
2. JWS / JWT の具体的な claims、鍵、署名方式、更新・失効規則。複数用途の JWT を扱う場合の、用途の取り違えを拒否する検証規則。
3. 壊れた JWT、古い `jti`、初回アクセスの復旧・作成の手順。GET では DB を書かない方針と、初回扱いの具体的な整合。ステータスコードと文言。
4. Display Snapshot の最新性、遅延応答、sign-out 後の残存値（「sign-out 後に本人の好みが絶対に残らない」とは保証しない。DB を読まない Auth / Core / Warp では、古い JWT が期限まで表示に使われ得る）。
5. DB 保存後に cookie の生成・配送が失敗した場合の公開結果。
6. Affinity の記録の契機（記録 §11.2-8 の「選んだ時点で記録する」は未承認の案）、記録用の経路（GET で記録しない・認証の POST を流用しない・Auth に新しい DB writer を足さない、を前提に設計する）、DB 行の失効・削除・保持期間、DB 保存にしたことによるリセットの契約、JWS の cookie 名・範囲・鍵。
7. Experience 内の Browser / Account それぞれのリセットの対象と経路。
8. Cookie Consent の本人への証跡の関連付け（案 C1 / C2 / C3、記録 §12.8.1。法務の確認が前提）。
9. ~~com に Account Experience がないことと、Web Push の従来要件（D-20）の関係。~~ **解消（C4-20）。**
10. 3 単位のルートの具体的なパス、置き場所（Base / Auth / Visa のどこが発行・参照・更新するか）。~~com の `/experience/user/...` を置くか~~（C4-24 で置かないと決定）。
11. HTML 画面の `resource ... only: :update` が PUT も作ること（JSON API の PUT 回避の ADR との関係）。
12. Accepted ADR の改訂（C9.2）。
13. 旧 `IdentityEmailPreferenceCommitter`（zenith の email の `notifiable` / `promotional`）と、Account Experience の「通知の希望」の関係。
14. 旧監査表（`*_preference_chronicles`）と adult gate の扱い。
15. ~~ADR の `continuity` の範囲。~~ **解消（C4-21）。** 当時の記録: ADR `preference-scope-and-browser-persistent-state-separation.md` の `continuity` は「1 つのブラウザに永続的に属する状態」全般（例: このブラウザで以前使ったアカウント、ブラウザごとの識別子、sign-in をまたいで残す機能の状態）を指していた。2026-11-04 の Amendment はこれを文字列として `affinity` に置き換えたので、ADR 上の `affinity` は C4-17 の Affinity より広い。ADR の `affinity` を C4-17 の定義に絞り、その他のブラウザに属する状態は機能ごとに専用の cookie を持つ（ADR の Decision 節どおり）と書き直すか、を決める。
16. **Cookie Consent の行を何で特定するか。** 旧 `AppPreferenceCookie` は旧親の子だった。Browser Experience のリセットに Cookie Consent を巻き込まないなら、Cookie Consent の有効性とリセットを独立させるための識別情報が要る（Browser Experience の資格情報を流用するとライフサイクルが結合し、独自の識別子を設けると資格情報が増える）。物理的な cookie の追加はまだ決めない。
17. **binding と Web Push。** 旧 binding は同意と Web Push の両方を守っていた。C4-20 で Web Push を Browser Experience にも置くので、「Web Push は AE になったから binding は不要」という理由は成り立たない。Web Push の設定を単なる好みとして扱い、配信の許可に使わないなら binding は不要、という設計なら成立する。どちらにするかを決める。
18. **Web Push の優先順位と `explicit_fields`。**（優先順位は C4-22 で解消済み）Web Push を Display Snapshot に含めるか（設定画面の初期値に使うだけか、配信の判断に使うか）。通知の希望と Web Push の設定の関係。
19. ~~com の Affinity。~~ **解消（C4-23）。** 当時の記録: 最初の用途 `last_sign_in_method` は com にない（認証がない）。Affinity は realm をまたぐ概念として定義しつつ、用途のある realm から実装するか（`ComAffinity` を先回りして作らない）。今の決定（C2、C6.1: app / com / org に置く）の再検討。
20. ~~com の User のルート。~~ **解消（C4-24）。** 当時の記録: com には Account Experience も認証もないので、`/experience/user/...` を置かない案（記録 §2-3「com は Guest だけ」と整合）。C5-10 の該当部分を置き換える候補。

21. **本書の版の固定。** 本書は gitignored だが、この領域の要件の正本。実装担当が確実にこの版を参照できるよう、保管先と版（日付と SHA-256 など）を固定する方法を決める（新しい設計書を増やすためではなく、確定した判断を失わないため）。

### C5.1 実装担当への注意事項（レビュー 4〜6）

- **JWT の復旧規則（C4-9）の適用範囲を限定する（C5-2、C5-3 の具体化）。** Browser Experience の更新用の資格情報と Display Snapshot の運搬は論理上分ける方針。古い Display Snapshot があることを理由に、独立した Cookie Consent の変更や、認証済みの利用者の Account Experience の保存まで一律に止めるのかを明確にする。共通の事前処理で無関係な操作を拒否すると、二重書き込みをなくしても処理の依存関係が再び生まれる。
- **「Base の GET で作り直す」（C4-10）は、Account Experience の復旧を保証しない（C5-4）。** Guest / User の判断は各 surface 自身の認証状態で行い、他の RP のログイン状態は横断的に調べない（C2）。たとえば Core にだけログインし Base では未ログインのとき、Base はその利用者の Account Experience を取得できない。その場合に Browser Experience / 既定値で作り直すのか、Account Experience の反映を次の適切な機会まで待つのかを決める。「後で直る」を、取得できない本人の情報まで復旧できる前提にしない。
- **古い世代の JWT による設定の消失を検出するテストを足す（レビュー 5 の 2）。** 今の並行テスト（`test/concurrency/app_org_preference_write_serialization_test.rb`）は既定値から同じ項目を 2 回変えるだけで、別の項目や既定値でない既存の値の消失を検出しない。
- **アカウントの保存の失敗と、ブラウザへの配送の失敗の意味を分ける（レビュー 5 の 3）。** 今の writer はアカウントの保存を確定してから setting 系を書くので、失敗応答でもアカウントは変わっている。新しい設計（C3-5）で二重書き込みはなくなるが、実装までは今の動きが残る。
- **`PreferenceSelect` の値の同期を再現してから直す（レビュー 5 の 4）。** `src/features/preferences/PreferenceSelect.tsx` は `form.value` を最初の表示でだけ読む。Inertia の `router.patch` は既定で `preserveState: true`。同じ画面のまま新しいサーバーの値が来たときに古い選択が残るかを、まずブラウザで再現する。直すときは、利用者の編集中の値を一律に捨てない。
- **Notification mock no-persistence contract (review 6, item 5): completed and verified 2026-11-04.** Guest PATCH tests cover app / com / org with ignored fields and an empty payload. Signed-in APP / ORG tests cover unchanged browser and account preference state. The snapshots include preference credential-generation columns, consent state, audit rows and email state. The frontend interaction test confirms that changing the display-only Web Push selection still submits an empty notification object. This verifies only the scaffold; it does not test unimplemented Guest / User persistence.
- **表示の項目は 10、運ぶ値は 9（レビュー 6）。** `ActorPreferenceExplicitDisplay` は 10 項目を持つが、地域を `NON_TRANSFERABLE_FIELDS` として外している（`app/models/concerns/actor_preference_explicit_display.rb:8-28`）。codec の表示の鍵は 9 で、閉じた形を検証する。`explicit_display_snapshot` を `explicit_values` に改名しても、アカウントの値を全部読むものにはならない。Account Experience の地域を導出にどう使うかと、地域の保存で言語・日付・時刻・通貨を揃える規則（`adr/localization-preference-flow.md`）を、どちらかの実装を流用する前に決める。
- **Web Push の「明示した disabled」と「未設定」を区別してテストする（レビュー 6）。** Account Experience で明示した enabled、明示した disabled、明示なしを、ブラウザの値と既定値（disabled）の組み合わせで確かめる。子の行があることや既定値の行があることは、明示した選択の証拠ではない。com の Guest と、間違った書き込みの経路に来た要求の拒否（フォールバックなし）も含める。
- **資格情報の分類ごとにテストする（レビュー 6）。** なし、空、形式不正、署名不正、別 realm・別用途、古い世代、退役済みの行、期限切れを区別する。決めた寿命や大きさの上限は、直前・ちょうど・直後で確かめる（Affinity の保持期間とリセットの有効性、cookie の大きさにも同じ方法を使う）。今の実装の値は JWT の上限 3,072 バイトと `now < expires_at`（新しい寿命として承認されたものではない）。
- **surface ごとの認証状態でテストする（レビュー 6）。** Base で未ログイン・Core でログイン中、とその逆。Base に認証済みのアカウントがないときにアカウントの値を復旧すると約束しない。それを理由に、RP をまたいだ身元の発見や Auth の DB writer を作らない。
- **status の ID は realm で違う（レビュー 6）。** App の status は 0 / 1、Com / Org は 1 / 2（各モデルの定数どおり）。移行で App の数値を他の realm に当てはめない。
- **Cookie Consent と Affinity の独立性は、リセットと失効で確かめる（C5-6、C5-7、C5-16）。** 「Browser Experience をリセットしても Cookie Consent を巻き込まない」「Affinity をリセットした後、ブラウザに残った古い参照で記憶が復活するかを定義する」など、操作の前後で何が残り何が無効になるかを受入条件にする。

## C6. 命名の対応表（目標名。実際の変更は行っていない）

調査: 2026-11-04、作業ツリー（HEAD `efdcd80d3`、未コミットの変更あり）と開発 DB の読み取り。テストは未実行。旧 Preference の各要素を、まず責務で分類してから新しい名前に対応させる（文字列の一対一の置換ではない）。

「単純改名」の意味（レビュー 3 で限定）: 責務は変わらないが、関連・外部キー・スコープ・定数参照・policy の対象・制約名の変更の確認は必要、という意味に限る。名前が長くなるので、PostgreSQL の識別子の上限（既定で 63 バイト）に注意する（例: Rails の通常の規則で組み立てた `index_app_browser_experience_date_formats_on_browser_experience_id` は 66 文字・ASCII で 66 バイト。実際の名前は migration を作る段階で確かめる）。

分類の記号: **BE** = Browser Experience、**AE** = Account Experience、**CC** = Cookie Consent、**AF** = Affinity、**DS** = Display Snapshot、**CR** = 旧資格情報・運搬処理、**X** = 廃止対象、**?** = 判断保留。

### C6.1 DB の表とモデル

| 旧（モデル / 表） | DB | 分類 | 目標（モデル / 表） | 種類 | 備考・未決 |
|---|---|---|---|---|---|
| `AppPreference` / `app_preferences`（`id, public_id, status_id, created_at, updated_at`） | app_setting | BE | `AppBrowserExperience` / `app_browser_experiences` | 責務分割 | `jti, last_issued_at, last_issued_expires_at` は CR（下の行）。Com / Org も同じ形（`ComPreference`、`OrgPreference`） |
| 同上の `jti`、`last_issued_at`、`last_issued_expires_at` | app_setting | CR | 未定（Browser Experience の資格情報の世代と発行記録） | 責務分割 | Display Snapshot の更新規則と 1 つの `jti` にまとめるかは C5-2 |
| `AppPreferenceStatus` / `app_preference_statuses` | app_setting | BE | `AppBrowserExperienceStatus` / `app_browser_experience_statuses` | 単純改名 | 行は 0, 1（App）。Com / Org は 1, 2（レビュー 6） |
| `AppPreference{Theme,Language,Timezone,Region,Currency,DateFormat,TimeFormat,Motion,Density,PageSize}` と各 `*Option`（20 モデル / 20 表） | app_setting | BE | `AppBrowserExperience{Theme,...}` / `app_browser_experience_themes` など、`*Option` も同様 | 単純改名（親の外部キー `preference_id` → `browser_experience_id` を含む） | 名前が長くなる。短縮するかは実装時に判断（代案を増やさない） |
| `AppPreferenceCookie` / `app_preference_cookies`（`consented, functional, performant, targetable`） | app_setting | CC | `AppCookieConsent` / `app_cookie_consents` | 責務分割（親を Browser Experience から切り離す） | 今は `preference_id` で旧親に属する。独立した所有（何に結びつくか）は C5-8 と関係。model の注釈に古い列（`consent_version`、`consented_at`）が残る（記録 §7.6-6） |
| `AppPreferenceConsentReceipt` / `app_preference_consent_receipts`（`version, recorded_at`） | app_setting | CC | `AppCookieConsentReceipt` / `app_cookie_consent_receipts` | 責務分割 | 証跡の意味は C5-8 |
| `AppPreferenceBrowserBinding` / `app_preference_browser_bindings`（`digest`） | app_setting | CC（Web Push の扱いは ?） | `AppCookieConsentBinding` / `app_cookie_consent_bindings`（仮） | 責務分割 | 旧 binding は同意と Web Push の両方を守っていた。Web Push は C4-20 で BE にも残るので、Web Push を binding の対象から外すかは C5-17 で決める。**同意・binding・Web Push を旧親と一緒に BE へ機械的に移さない** |
| `AppPreferenceWebPush` / `app_preference_web_pushes`、`AppPreferenceWebPushOption` | app_setting | BE | `AppBrowserExperienceWebPush` / `app_browser_experience_web_pushes`（Option も同様） | 単純改名（親の外部キーを含む） | C4-20 で BE にも置くと決定。Com / Org も同じ。AE 側は下の行で新設 |
| `AppPreferenceAdultContentGate(Option)` / `app_preference_adult_content_gate(s/_options)` | app_setting | X / ? | なし | 判断保留 | 休眠（記録 §7.2）。C5-14 |
| `AppPreferenceChronicle(Event/Level)` / `app_preference_chronicle(s/_events/_levels)` | **chronicle**（`ChronicleRecord` を継承、`app/models/chronicle_record.rb:4-7`。開発 DB `development_chronicle_db` で確認。レビュー 6 で訂正、以前は app_setting と誤記） | ? | 未定 | 判断保留 | 旧親の監査。Com / Org の監査も `ChronicleRecord` を継承（コードで確認、表は未照会）。どの単位の監査かは C5-14。監査は setting の子ではなく別 DB・別のトランザクション境界にある。`PreferenceLifecyclePurger` は setting の行を消す前に Chronicle の監査の参照を確かめ、監査のロックを取るので、分割・リセットの設計でもこの義務を保つ |
| `ClientPreference` / `client_preferences`（`client_id, public_id, explicit_fields, status_id`） | app_zenith | AE | `ClientExperience` / `client_experiences` | 単純改名 | `OperatorPreference` → `OperatorExperience` / `operator_experiences`（org_zenith）。`explicit_fields` は AE の「明示した値」の記録 |
| `ClientPreferenceStatus` と、表示 10 項目の子・`*Option`、`ClientPreferenceAdultContentGate(Option)` | app_zenith | AE / ? | `ClientExperience{Theme,...}` など | 単純改名（adult gate は判断保留） | Operator も同じ |
| （なし） | app_zenith / org_zenith | AE | Web Push の設定（`ClientExperienceWebPush` など、BE と同じ形）、通知の希望の表（名前は未定） | 新設 | 今の Client / Operator 側に Web Push の表はない（開発 DB で確認）。通知の希望は C5-13 と関係 |
| （なし） | app_setting / org_setting（com_setting は用途ができたとき、C4-23） | AF | `AppAffinity` / `app_affinities`、`OrgAffinity` / `org_affinities`（`ComAffinity` は後で） | 新設 | 項目（`last_sign_in_method`）の持ち方、保持期間は C5-6 |
| `IdentityEmailPreferenceCommitter`（`notifiable`、`promotional`） | app_zenith | ? | 変更しない | — | identity の email の通知設定。旧 Preference の単位ではない。C5-13 |

名前の衝突: `*Experience`、`*Affinity`、`*CookieConsent`、`DisplaySnapshot` のクラス・表は、作業ツリーと開発 DB に存在しない（`grep` と開発 DB の表一覧で確認）。`/experience`、`/consent`、`/affinity` のルートも存在しない。紛らわしい既存の名前: `ActorPreferenceExplicitDisplay#explicit_display_snapshot`（`app/models/concerns/actor_preference_explicit_display.rb:16`、Account Experience の明示した値の部分集合で、Display Snapshot ではない）、`SecurityJwtPreferenceTokenCodec.valid_anonymous_display_snapshot?`（JWT の表示値の検証）。改名先は C4-18 で決定（`explicit_values`、`valid_display_snapshot?`）。

### C6.2 コードの部品

| 旧 | 場所 | 分類 | 目標 | 種類 | 備考 |
|---|---|---|---|---|---|
| `PreferenceClassRegistry` | `app/controllers/concerns/preference_class_registry.rb` | BE / AE / CC | 単位ごとに分ける | 責務分割 | 今は表示 10 項目と cookie / status / chronicle を 1 つの registry に持つ |
| `PreferenceWriteBoundary`（`write_app_org_preference!`、`write_actor_preference!`、`write_visa_preference!`、`write_com_preference!`） | `app/controllers/concerns/preference_write_boundary.rb` | BE / AE / CC / DS | Guest（BE）・User（AE）・Cookie Consent・Display Snapshot の作り直しに分ける | 責務分割 | l.146-153 の actor の有無による分岐は廃止（C3-4、C3-5） |
| `PreferenceDisplayValue`（`#experience`、`#language`） | `app/values/preference_display_value.rb` | DS | `DisplaySnapshot`（値オブジェクトの候補） | 単純改名に近い | |
| `PreferenceToken`、`SecurityJwtPreferenceTokenCodec`（claims `iss sub aud iat exp jti preferences`、TTL 400 日） | `app/controllers/concerns/preference_token.rb`、`app/values/security_jwt_preference_token_codec.rb:9, 30` | CR + DS | 未定 | 責務分割 | `sub` / `jti` は行の参照（CR）、`preferences` は表示値（DS）。1 つの JWT に同居している（C7） |
| `PreferenceBrowserBinding` | `app/controllers/concerns/preference_browser_binding.rb:19` | CC（Web Push は ?） | Cookie Consent 用の binding への分離が候補 | 責務分割 | Web Push 側の保護は C5-17 の結論に従う |
| `PreferenceCookieName`（`anonymous_jwt` / `anonymous_experience` / `binding`） | `app/controllers/concerns/preference_cookie_name.rb:9, 13, 17` | CR / DS / CC | C7 | 責務分割 | |
| `PreferenceBrowserControlsRegistry`、`PreferenceBrowserApi`、`PreferenceWeb{Theme,Cookie}{Actions,Endpoint}` | `app/values/`、`app/controllers/concerns/` | X | なし | 廃止対象 | 配布・キャッシュ API の廃止（C3-14） |
| `PreferenceLifecycleJob`、`PreferenceLifecyclePurger` | `app/jobs/`、`app/operations/` | BE | Browser Experience の寿命・purge | 単純改名に近い | Cookie Consent・Affinity の寿命は別に決める |
| 各モデルの policy（計 120 ファイル: `app/policies/*_preference_*_policy.rb` の 115 ファイルと、親の 5 ファイル `{app,com,org,client,operator}_preference_policy.rb`。レビュー 6 で訂正） | `app/policies/` | モデルに従う | モデルの改名に合わせる | 単純改名 | 認可の中身は C3-13 で見直す |
| Base の画面の concern（`base_preference_*`、`preference_core.rb`、`preference_sign_screen_actions.rb` ほか） | `app/controllers/concerns/` | BE / AE / CC | Experience（Guest / User）と Consent の controller へ分ける | 責務分割 | |
| `Base::{App,Com,Org}::Preference::ScreensController` | `app/controllers/base/*/preference/screens_controller.rb` | X | なし | 廃止候補 | 利用者の指定値で更新対象を選ぶ重複の経路（記録 §7.8） |
| `Base::{App,Com,Org}::Preference::NotificationsController`（モック） | `app/controllers/base/*/preference/notifications_controller.rb` | AE / BE（機能ごと） | 画面の機能ごとに分ける: 本人の通知の希望 → Account Experience / User。Web Push の設定 → 未ログインは Browser Experience / Guest、ログイン中は Account Experience / User。com の Web Push の設定 → Browser Experience / Guest だけ | 責務分割 | 今は何も保存しない。同じ通知画面を使い続けるか、Web Push の編集画面を分けるかは未決 |
| `Base::{App,Org}::Preference::EmailsController` | `app/controllers/base/{app,org}/preference/emails_controller.rb` | — | 対象外 | — | 宣伝メールの配信停止（別の backlog） |
| 翻訳キー `base.{app,com,org}.preferences.*`、`acme.{app,com,org}.preferences.*` | `config/locales/{en,ja}.yml`（例: en l.136, 346, 541, 1288, 1454, 1784） | BE / AE / CC | 単位ごとの名前空間 | 責務分割 | `root.org.preferences`、`controller.sign.preferences` も存在。どれが Preference の画面のものかは未確認 |
| フロント `src/features/preferences/*`（`PreferenceCookie`、`PreferenceCustomization`、`PreferenceIndex`、`PreferenceNotification`、`PreferenceScreenFrame`、`PreferenceSelect`）と `src/pages/base/*/preference(s)/*`、共有の補助 `src/lib/cookies.ts`、`src/lib/theme.ts`（レビュー 6 で場所を訂正。`src/lib` はほかの画面からも使われるので機械的に改名しない。廃止する API の呼び出し元がここに残る） | `src/` | BE / AE / CC / DS | 単位ごとに分ける | 責務分割 | `PreferenceEmailUnsubscribe` は対象外。props の型名も同じ単位に揃える |
| ルートの所有の分類 `RuntimeRole::BASE_ANY_PREFIXES` の `preference preferences api/v0/preferences` | `lib/runtime_role.rb:112-113` | — | `experience`、`consent`、`affinity` の所有者を明示的に割り当てる | 追加 | 未分類のルートは例外になる作り（`route_owner`）。新しいルートには所有者の割り当てが必須 |

### C6.3 ルートの命名（目標例。今のルートは変えていない）

今のルート（`config/routes/base.rb`）: `resource :preference, only: :show`、`namespace :preference { resource :theme / :language / ... , only: %i(edit update); resource :cookie, only: %i(edit update); resource :customization, only: %i(edit destroy); resource :screen; resource :notification; resources :emails ... }`、`namespace :api { namespace :v0 { namespace :preferences { get/patch :cookie, :theme, :web_push } } }`。route helper の例: `edit_base_app_preference_theme_path`。

| 単位 | 目標の宣言（例） | パス | helper（例） | controller（例） |
|---|---|---|---|---|
| Experience の一覧 | `resource :experience, only: :show` | `GET /experience` | `base_app_experience_path` | `Base::App::ExperiencesController` |
| Experience の画面 | `namespace :experience { resource :theme, only: :edit }` | `GET /experience/theme/edit` | `edit_base_app_experience_theme_path` | `Base::App::Experience::ThemesController#edit` |
| Guest の書き込み | `namespace :experience { namespace :guest { resource :theme, only: :update } }` | `PATCH /experience/guest/theme` | `base_app_experience_guest_theme_path` | `Base::App::Experience::Guest::ThemesController#update` |
| User の書き込み | `namespace :experience { namespace :user { resource :theme, only: :update } }` | `PATCH /experience/user/theme` | `base_app_experience_user_theme_path` | `Base::App::Experience::User::ThemesController#update` |
| Cookie Consent | `namespace :consent { resource :cookie, only: %i(edit update) }` | `GET /consent/cookie/edit`、`PATCH /consent/cookie` | `edit_base_app_consent_cookie_path` | `Base::App::Consent::CookiesController` |
| Affinity | `resource :affinity, only: %i(show destroy)` | `GET /affinity`、`DELETE /affinity` | `base_app_affinity_path` | `Base::App::AffinitiesController` |

- Cookie Consent のパスは単数の `/consent/cookie` に決定（C4-19）。Rails の単数リソースは「1 つのブラウザにつき 1 つ」を表す正規の書き方で、controller 名が複数形（`CookiesController`）になるのは Rails の規約。
- `resource ... only: :update` は PATCH と PUT を作る（C5-11）。
- com には User の書き込みのルート（`/experience/user/...`）を置かない（C4-24）。
- Affinity の記録用の経路は定義しない（C5-6）。Base / Auth / Visa のどこに置くかは命名とは別（C5-10）。
- `Experience::User` の名前空間は、既存の `User` model がないことを確認済み（作業ツリーに `app/models/user.rb` はない）。ただし、`User` という定数名がほかのライブラリと衝突しないかは実装時に確認する（未確認）。

## C7. cookie と資格情報の対応表（名称の候補。枚数・構造は未決）

| 役割 | 旧名称 | 新名称の本体の候補 | 発行者（今） | 参照者（今） | 共有範囲（今） | 未決 |
|---|---|---|---|---|---|---|
| Browser Experience の行への参照・更新用の資格情報 | `__Secure-preference`（JWT の `sub`、`jti`） | `browser_experience` | Base（保存・リセット）、Visa（sign-in / sign-out） | Base、Visa（書き込み時）、Auth / Core / Warp（表示の読み取り） | `Domain=.<登録ドメイン>`、Secure、HttpOnly、SameSite=Lax、400 日（`preference_access_token_issuer.rb` の `anonymous_com_cookie_options`） | 今の 1 つの JWT は行の参照と表示値を両方持つ。中身を分けずに `__Secure-browser_experience` へ単純改名しない |
| 導出された表示の値 | `__Secure-preference` の `preferences` claim、`__Secure-experience`（JSON）、`language` | `display_snapshot`（`language` を統合するかは未決） | 同上 | サーバーの描画（JWT）、JS（`__Secure-experience`、`language`） | 同上（`__Secure-experience` と `language` は HttpOnly なし） | 資格情報と 1 つの `jti` や更新・失効規則にまとめるか。物理的に分けるか |
| Cookie Consent のブラウザ結合 | `__Host-preference_binding` | `cookie_consent_binding` | Base（同意・Web Push の保存） | Base | host-only（`__Host-`）、Secure、HttpOnly、Lax | Web Push を対象に残すかは C5-17。名前の候補は同意だけを守る場合のもの。接頭辞は発行ホストで決める |
| Affinity の参照用の情報 | （なし） | `affinity` | 未定 | 未定 | 未定 | 名前は Affinity に統一（C4-17）。Accepted ADR `preference-scope-and-browser-persistent-state-separation.md` の `continuity` の予約を `affinity` に置き換える改訂は**実施済み（2026-11-04）**。ADR の中身の制約（認証・身元の判断に使わない、なくても通常どおり動く、アカウント固有の状態を入れない）は Affinity の決定と一致 |

- `__Host-` / `__Secure-` の接頭辞は、発行ホストと共有範囲を確かめて決める。名前の見栄えで決めない。
- 複数用途の JWT を扱う場合は、cookie 名の違いに頼らず、用途の取り違えを拒否する検証を設計する（C5-2）。
- Affinity の JWS を認証用のトークンと同じ用途として扱わない。
- `__Secure-` は兄弟サブドメインからの差し込みを防がない（記録 §8.1 P1-4 の検証は残る）。

## C8. 付録T の状態（記録 §6.2 を置き換え）

| 付録T | 状態 | 注記 |
|---|---|---|
| T.1〜T.3、T.9、T.10 | 参考 | 実装の根拠にしない |
| T.4 WU-7（com） | **Superseded** | 3 単位への作り直しで、com の旧 Preference の形はそのまま実装しない |
| T.5 WU-9 | **Superseded** | 同上 |
| T.6 §4.1 所有・cookie・署名 | 参考 | cookie の名前・枚数は C7 で決め直す |
| T.6 §4.2〜§4.5、§4.7 | **Superseded** | 二重書き込み、sign-in での写し、sign-out での写し、同意・Web Push の旧 binding の扱いは採らない |
| T.6 §4.6 GET / HEAD | 参考 | GET で DB を書かない原則は C3-18 で維持。表示 cookie の作り直しは C4-3 |
| T.6 §4.8 障害応答 | **Superseded** | C4-9、C4-10 |
| T.6 §4.9 寿命・purge・鍵 | 参考 | 寿命と鍵は C5-1、C5-2 で決め直す |
| T.7 §12.5 Visa の POST | Active（GET を no-store の form にし、既存の POST だけで確定する部分）／**Superseded**（Preference の失敗で code を出さない部分、sign-in で旧行に写す部分） | |
| T.8 §12.7 | 参考 | |

## C9. 実装の状態と ADR

### C9.1 実装の状態

- The redesign remains unimplemented beyond these bounded slices: theme ordering (system → light → dark; 18 tests passed in `preference_screen_localization_test.rb` during review 6); the non-persisting notification mock; the C4-18 method rename and call-site/document update (57 runs / 426 assertions passed); the 2026-11-04 notification mock no-persistence tests recorded in C5.1; and the C13 `PreferenceSelect` synchronization fix (Chromium reproduction, 13 Vitest tests, 2 Chromium E2E tests and full typecheck passed). No Experience, Cookie Consent, or Affinity persistence model or route has been introduced.
- 本書の更新で、コード・ルート・テスト・DB スキーマ・cookie は変更していない。2026-11-04 に `preference-scope-and-browser-persistent-state-separation.md` の Affinity Amendment を維持した上で、決定済みの Experience 境界を記録するため `preference-sign-in-application-is-one-directional.md`、`preference-visa-writer-boundary.md`、`preference-extended-option-reference-tables.md`、`preference-soft-bubble-doctrine.md` も限定的に改訂した。これは ADR の衝突を明示する文書変更であり、Experience の実装ではない（C9.2）。
- **構造 dump の具体的な欠陥（レビュー 6）:** `db/chronicle_structure.sql` は 448 バイトで `CREATE TABLE` が 0（`config/database.yml:268-280` が chronicle の dump として指定）。開発 DB には `app_preference_chronicles` などがあるので、この dump だけでは監査の表を作れない。setting / zenith の dump は表の定義を持つ（app / com / org setting 各 31、app_zenith 128、org_zenith 111 の `CREATE TABLE`）が、空の DB に読み込んでの確認はしていない。dump の生成経路の確認と修復は、別に承認を得て行う。
- **現 worktree の追記（2026-11-04）:** 現在の `db/app_zenith_structure.sql` も 448 バイトで `CREATE TABLE` が 0。既存の未コミット差分が HEAD から 9,973 行を削除している。`db/org_zenith_structure.sql` は 262,172 バイト。これは worktree 上のファイル観測であり、DB の実状態を示すものではない。app_zenith dump は先のレビュー時点の開発 DB 観測と混同しない。既存差分を保持し、dump の再生成・修復は行っていない。
- テスト環境（2026-11-04、レビュー 5 で訂正。レビュー 6 で `preference_screen_localization_test.rb` も 18 件成功を確認）: 以前の「テスト DB の残骸でテストが実行できない」「構造 dump が空」は、一律の記述としては古い。Codex のレビューで `test/integration/preference_inertia_page_contract_test.rb` は起動・実行でき（36 件、失敗は契約の検証 3 件）、`db/{app,com,org}_setting_structure.sql` は中身がある（53,683 / 53,973 / 53,723 バイト、Claude Code も確認）。一方、以前 `preference_screen_localization_test.rb` は fixture の外部キー違反（`client_chronicles`）で止まった。どのテスト・DB・dump が健全かの全体の確認はまだ。
- **通知画面のモックで既存の契約テストが壊れた（レビュー 5 の 1）。** 一覧に `notification` を足したが、`test/integration/preference_inertia_page_contract_test.rb` の `SCREEN_KEYS`（l.22-24）と `SCREEN_COMPONENTS`（l.28-41）を更新していないため、app / com / org の 3 件が失敗する。Claude Code の変更による回帰。**2026-11-04 に修正済み**（オーナーの許可で、テストの `SCREEN_KEYS` に `notification` を、`SCREEN_COMPONENTS` に `"notification" => "notifications/edit"` を追加。`PARALLEL_WORKERS=1 bin/rails test test/integration/preference_inertia_page_contract_test.rb`: 36 runs, 1086 assertions, 0 failures, 0 errors, 0 skips。RuboCop 問題なし）。
- Notification scaffold no-write behavior is now tested for guest requests on all three Base surfaces and signed-in APP / ORG requests; see C5.1 for the scope and current verification results.
- The C13 synchronization defect was reproduced in Chromium against a live Rails-rendered Inertia page with a controlled same-page PATCH response. The component now derives its clean value from current server props and keeps a newer dirty edit through an in-flight response; scoped Vitest and two Chromium E2E cases passed on 2026-11-04. These cases verify synchronization behavior only and do not write preference data.

### C9.2 Accepted ADR の改訂状況と残る衝突

| ADR（状態） | 衝突する条項 | 改訂案の方向 |
|---|---|---|
| `preference-scope-and-browser-persistent-state-separation.md`（Accepted 2026-09-26） | 「Preference は表示・利用の設定に限る」「ブラウザに属する状態は `continuity` cookie、名前は予約」 | 3 単位の名称で書き直す。Cookie Consent は Preference から独立した単位とする。`continuity` の予約を `affinity` に置き換える部分は**改訂済み（2026-11-04、Amendment）**。範囲を Affinity に絞る修正も実施済み（C4-21）。3 単位の名称での書き直し、Cookie Consent の独立は未実施 |
| `preference-realm-jwt-and-host-bound-browser-binding.md`（Accepted 2026-10-31） | `__Secure-preference` / `__Host-preference_binding` の名前と役割、binding が同意と Web Push を守ること | C7 の決定後に改訂。Web Push を binding の対象に残すかは C5-17 で決め、その結論に合わせて改訂する |
| `preference-sign-in-application-is-one-directional.md`（Accepted 2026-10-31） | sign-in で account の明示した値を匿名の行へ一方向に反映する | **2026-11-04 Amendment 済み**。sign-in/save の相互コピーを廃し、Browser / Account ownership と Display Snapshot を C3-C4 に合わせた。実装は未着手 |
| `preference-visa-writer-boundary.md`（Accepted 2026-10-31） | sign-in で匿名の行へ反映、sign-out で旧行を写す。l.26 と l.60 の食い違い（記録 §8.1 P0-3） | **2026-11-04 Amendment 済み**。sign-in / sign-out で Experience を写さず、認証結果を保持する。cookie / recovery detail は C5 に残る |
| `preference-extended-option-reference-tables.md`（Accepted 2026-05-14、2026-10-31 改訂） | 子 record / option の表の名前、Web Push を setting 系に追加 | **2026-11-04 Amendment 済み**。Web Push の reference-table semantics と BE / AE の配置、優先順位を記録。新 schema / route 名は未決 |
| `preference-soft-bubble-doctrine.md`（Accepted 2026-05-06） | 「Interface」節の、統一 `Actor.preferences` runtime と、ログイン中の編集画面 GET で値を写す例外 | **2026-11-04 Amendment 済み**。realm DB 境界を残し、旧 read/sync/screen-entry contract は五の C0-C5 に従い supersede |
| `invalid-browser-credential-recovery.md`（Accepted、2026-10-31 改訂。レビュー 6 で追加） | l.95-107: 拒否された Preference の資格情報では GET は既定値で描く、Base の保存は既定値の行を作って入力を適用する、Visa / リセットは旧 two.md の写しの規則に従う、古い `jti` は期限まで表示に使える | C5-2 / C5-3 の決定後に Preference の節を改訂する（C4-9 は、該当する GET は作り直して再読み込み、書き込みは拒否してやり直し）。Auth の資格情報の切り離しなど無関係な規則は保つ |
| `preference-setting-configurator-url-boundaries.md`（Accepted 2026-06-02。レビュー 6 で追加） | l.23-38: `/preference` と `/setting` の所有。アカウントの通知の設定を `/setting` に置く | `/experience`、`/consent`（C6.3）と、Account Experience の通知（C6.2）に合わせて改訂する。identity やセキュリティの設定の移動や、その保護の仕組みの撤去までは含めない |
| `api-route-vocabulary-consolidation.md` | JSON API の PUT を作らない例外 | 廃止する API の削除後に例外の行を見直す。HTML 画面の PUT は C5-11 |
| `preference-tld-sharing-and-jwt-lifecycle-reassessment.md`（Proposed、2026-11-03 Amendment） | API での配布を破棄済み | 3 単位の名称で閉じるか、新しい ADR で置き換える |

## C10. レビュー指摘の状態（記録 §8、§11）

| 指摘 | 状態 | 根拠 |
|---|---|---|
| レビュー 1 P0-1 / P0-4（二重書き込み、Z 確定後の S の検証） | 解消済み（設計上） | C3-5（AE の保存で BE に複製しない） |
| レビュー 1 P0-2（古い `jti` で既定値の新しい行） | 採用済み・手順は未決 | C4-9、C5-3 |
| レビュー 1 P0-3（Preference の失敗でログインが止まる） | 採用済み | C4-10。`preference-visa-writer-boundary.md` を 2026-11-04 に C9.2 のとおり Amendment 済み。実装詳細は C5-3 などの未決事項に従う |
| レビュー 1 P1-1（共通 writer の形骸化） | 解消済み（設計上） | C3-4、C6.2 の書き込みの分割 |
| レビュー 1 P1-2（正本と表示のずれ） | 採用済み・詳細は未決 | C2 の Display Snapshot、C5-4 |
| レビュー 1 P1-3（同意・Web Push の所有） | 一部決定 | C3-11、C4-20（Web Push は BE と AE の両方）、C5-8（同意の証跡）、C5-17、C5-18 |
| レビュー 1 P1-4（cookie の差し込み） | 要確認 | C7 の注記。検証は未実施 |
| レビュー 1 P1-5（JWT の所持は所有の証明ではない） | 採用済み | C3-13 |
| レビュー 1 P1-6（リセットの保証） | 未決 | C5-6、C5-7 |
| レビュー 1 実装の指摘（ScreensController、廃止 API、テスト DB、構造 dump、PUT） | 要確認 / 未決 | C6.2、C3-17、C5-11 |
| レビュー 2 P0-1（Experience と Preference の矛盾） | 解消済み（設計上） | 3 単位への分割と C2 の定義 |
| レビュー 2 P0-2（Z 確定と JWT の競合） | 解消済み（設計上） | AE の保存は BE を書かない |
| レビュー 2 P0-3（再読み込みでは復旧しない） | 採用済み・手順は未決 | C4-9、C5-3 |
| レビュー 2 P0-4（新旧設計の優先順位） | 解消済み（文書） | 本書の第I部・第II部の分離と C8 |
| レビュー 2 P1（sign-in 失敗後の表示） | 採用済み | C4-10 |
| レビュー 2 P1（SSOT と読み取りの最新性） | 採用済み・詳細は未決 | C5-4 |
| レビュー 2 P1（「ブラウザごと」の技術的な境界） | 要確認 | `localStorage` を使わない決定（C3-1）と Affinity の DB 化で前提が変わった。cookie の範囲は C7 |
| レビュー 2 P1（通知・同意の分け方） | 一部決定 | C3-11、C5-8 |
| レビュー 2 P1（Affinity の境界） | 一部決定 | C2、C4-7、C5-6 |
| レビュー 2 P1（sign-out とリセット） | 一部決定 | C3-9、C3-10、C5-7 |
| レビュー 2 P2（cookie と概念の名前） | 一部決定 | C7（候補）、物理的な名前は未決 |
| レビュー 2 P2（テスト環境） | 一部確認済み・未決 | 対象のテスト 2 ファイルは実行できる。確認済みの欠陥は chronicle の構造 dump（C9.1）。全体の確認はまだ（C3-17） |

## C11. レビュー 3（外部レビュー、2026-11-04 受領）の処置

判定: 命名体系はおおむね承認できる。C4-17 の定義と C4-20 の関連記述は修正が必要。実装計画は未承認が妥当。

| 指摘 | 処置 |
|---|---|
| P0: C4-17「ブラウザに属する状態を Affinity と呼ぶ」は広すぎる | 採用。C4-17 の定義を修正。ADR の範囲も Affinity に絞った（C4-21、ADR 修正済み） |
| P1: C4-20 が C6.1 / C7 / C9.2 / C10 に反映されていない。binding を外す理由が成り立たない | 採用。各行を修正。binding は C5-17 |
| P1: Cookie Consent の行の特定と、Browser Experience からの独立 | 採用。C5-16 |
| P1: Web Push の優先順位と `explicit_fields`、Display Snapshot に含めるか | 採用。優先順位は C4-22 で決定。残りは C5-18 |
| P1: com の Affinity の必要性 | 採用。C4-23（用途ができたら作る） |
| P1: com に `/experience/user` は置かない | 採用。C4-24 |
| P1: JWT の復旧と「GET で DB を書かない」の衝突 | 既に C5-3 で未決として明示。提案（初回の GET は既定値の表示だけ、永続化は別の操作）を C5-3 の検討材料にする |
| P2: C9.2 の見出しと改訂状況の不一致、C9.1 の記述 | 採用。見出しと C9.1 を修正 |
| P2: 「単純改名」が楽観的、識別子の長さ、`valid_display_snapshot?` の適用範囲 | 採用。C6 の冒頭に「単純改名」の意味と識別子の長さを注記（66 文字の例は確認済み）。C4-18 に注記 |
| ADR の実ファイルを確認していない（レビューの限界） | ADR の Amendment は作業ツリーで実施・確認済み（`git diff --check` 問題なし） |

## C12. レビュー 4（外部レビュー、2026-11-04 受領）の処置

判定: 命名・責務分離・決定事項の引き継ぎ文書として、この版を基準に文章化を締めてよい。名称の再検討は不要。実装仕様が完成したという判定ではない。

| 指摘 | 処置 |
|---|---|
| Web Push の binding が C9.2 で「外す」と断定されている | 修正。C9.2 を「C5-17 で決め、その結論に合わせて改訂」に、C6.2 の `PreferenceBrowserBinding` を「Cookie Consent 用への分離が候補、Web Push 側は C5-17 に従う」に |
| 通知画面のモックを丸ごと AE / User に分類している | 修正。C6.2 で機能ごとに分けた（通知の希望は AE / User、Web Push は未ログインで BE / Guest・ログイン中で AE / User、com は BE / Guest だけ） |
| C4-4 の対象を Experience に限定 | 修正 |
| C4-23 の「realm をまたぐ」をデータ共有と区別 | 修正（概念は共通、データ・資格情報は realm ごとに分離） |
| C5-18 に解決済みの問いが残る | 修正 |
| PostgreSQL の上限は 63 文字ではなく既定で 63 バイト | 修正（例の名前は 66 文字・66 バイト） |
| JWT の復旧規則の適用範囲、Base の GET で Account Experience を復旧できるとは限らない、Cookie Consent・Affinity の独立性はリセットと失効で確かめる | C5.1 に実装担当への注意事項として記録 |
| gitignored の正本の保管先と版の固定 | C0 に版を記録、方法は C5-21 |
| ADR の差分はレビューで独立に検証していない | 作業ツリーで実施し `git diff --check` で確認済み（Claude Code）。レビュー側の独立検証ではない |

## C13. レビュー 5（Codex、six.md、2026-11-04）の処置

対象: 本書（SHA-256 `b988c049…`）と今の実装。

| 指摘 | 判定 | 処置 |
|---|---|---|
| 1. [P2] 通知画面のモックで `preference_inertia_page_contract_test.rb` の 3 件が失敗する（`SCREEN_KEYS`、`SCREEN_COMPONENTS` の未更新） | 妥当（Claude Code がテストの定義を確認）。Claude Code の変更による回帰 | 修正済み（2026-11-04、C9.1）。テストのファイルだけを変更し、実装は変更していない |
| 2. [P1] 古い世代の JWT で既定値の新しい行が作られ、無関係な設定が消える | 既知（記録 §8.1 P0-2、C10）。今のコードに残っている | 本実装で C4-9 / C5-3 に従って直す。そのときに「別々の項目」と「既定値でない既存の値」を持つ並行テストを足す（今の並行テストは同じ項目を既定値から 2 回変えるだけで、消失を検出しない） |
| 3. [P1] アカウントの保存が失敗応答でも確定している（二重書き込み） | 既知（C10）。今のコードに残っている | C3-5 の設計で解消するが、実装はまだ。本実装で、アカウントの保存の失敗と、ブラウザへの配送の失敗の意味を分ける |
| 4. [P2] `PreferenceSelect` が、同じ画面のまま新しいサーバーの値を受け取っても、ローカルの選択を保つ | Chromium で再現。実 Rails の Inertia 初期ページに対し、同一画面の PATCH 応答で新しい `form.value` が来ても古い選択が残った | 2026-11-04 に修正。clean な選択は現在の server props を使い、送信中に利用者が行ったより新しい選択は応答後も保持する。Vitest 13 件、Chromium E2E 2 件、full `bun run typecheck` が成功 |
| 5. [P2] 「テストが実行できない」「構造 dump が空」は古い | 妥当（dump の大きさを Claude Code が確認） | C9.1、C3-17 を訂正 |
| 現行の振る舞いの文書（`docs/architecture/preference-behavior-contract.md`）は旧設計のまま | 妥当 | 移行中の既知の差として扱う。新しい契約が実装済みだという証拠ではない |

レビュー 5 の検証の記録（six.md より。six.md と seven.md は本書への反映後に削除した）: 対象 HEAD `efdcd80d3`（未コミットの変更あり）、入力の本書は SHA-256 `b988c049…`。`bin/rails test test/integration/preference_inertia_page_contract_test.rb` は 36 件中 3 件失敗（指摘 1、その後修正済み）。`bun run test gait/features/preferences/preference_screens_interaction.test.tsx gait/features/preferences/preference_screens.test.tsx` は 2 ファイル・23 件が成功。全体のテスト、ブラウザでの再現、並行テストの実行、障害の注入、migration は行っていない。

## C14. レビュー 6（Codex、seven.md、2026-11-04）の処置

対象: 本書（SHA-256 `461b2891…`）と今の実装。新しい P0 はない。前回（レビュー 5）の指摘 1 の修正は独立に確認された（36 件成功）。

| 指摘 | 判定 | 処置 |
|---|---|---|
| 1. [P1] C6.1 で監査（Chronicle）の表を app_setting と誤記 | 妥当（コードと開発 DB で確認されたと報告） | C6.1 を訂正。監査の境界と `PreferenceLifecyclePurger` の義務を注記 |
| 2. [P1] `db/chronicle_structure.sql` に表の定義がない | 妥当（448 バイトを Claude Code も確認済み） | C9.1、C3-17 に具体的な欠陥として記録。修復は別に承認を得る |
| 3. [P1] C9.2 に `invalid-browser-credential-recovery.md` が抜けている。`preference-setting-configurator-url-boundaries.md` も抜けている。soft-bubble の衝突箇所を確認 | 妥当 | C9.2 に 2 本を追加し、soft-bubble の行を確定 |
| 4. [P2] policy の glob は 115 件（親 5 件を含めて 120）。`cookies.ts` / `theme.ts` の場所の誤り | 妥当 | C6.2 を訂正 |
| 5. [P2] 通知画面のモックの「保存しない」契約がテストされていない | 妥当（テストの不足で、保存の不具合ではない） | C5.1 にテスト結果を記録し解消 |
| 引き継ぎの注意 1〜5（地域の扱い、Web Push の明示、資格情報の分類と境界値、独立したライフサイクル、surface ごとの認証状態）と status の ID | 妥当 | C5.1 と C6.1 に記録 |

レビュー 6 の検証の記録: `preference_inertia_page_contract_test.rb` 36 件成功、`preference_screen_localization_test.rb` 18 件成功（以前の fixture の失敗は今回は出ていない。すべての fixture が健全だという意味ではない）、Vitest 2 ファイル・23 件成功、開発 DB の読み取り専用の照会（`BEGIN READ ONLY` → `ROLLBACK`）。全体のテスト、並行テスト、ブラウザでの再現、障害の注入、空の DB への dump の読み込み、migration は行っていない。原文の seven.md は本書への反映後に削除した。

## C15. Claude Code の最終レビュー（2026-11-04）の処置

第I部（C0〜C14）を通読し、次を直した。設計の決定は変えていない。

| 見つけた問題 | 処置 |
|---|---|
| C4-18 の括弧が閉じていない | 修正 |
| C4-9（壊れた・古い JWT は新しい JWT を発行）が、どの surface でも判定できるように読める。Auth / Core / Warp は DB を読まないので `jti` の古さを判定できず、cookie も書かない | C4-9 に「判定と発行は Base と Visa だけ」を明記。C5-4 の「古い JWT が期限まで表示に使われ得る」を、DB を読まない surface に限定 |
| C8 が「GET で DB を書かない原則は C3 で維持」と書くが、C3 にその条項がない | C3-18 を追加（記録 §12.4-3 の決定を現行の制約に明記） |
| C9.1 の theme の並びが「テストは未実行」のまま | レビュー 6 の実行（同じテストファイル 18 件成功）に更新 |
| C10 のテスト環境の行が「未決（ブロッカー）」のまま | C3-17、C9.1 に合わせて「一部確認済み・未決」に更新 |
| C0 の版 | 最終稿に更新 |

確認したが直していないもの（判断が必要なため未決に残す）:

- C5-6 の前提（Auth に新しい DB writer を足さない）と、Affinity の最初の用途（Auth のサインインの方式の選択）の間には、記録する主体をどこにするかという設計上の緊張がある。前提を守ったまま設計できるかは C5-6 / C5-10 で決める。
- C5-21（本書の版の固定）。本書は gitignored のままで、版は日付と SHA-256 で識別するしかない。

# 第II部 歴史的記録（2026-11-03〜04。§番号は当時のまま）

以下は議論・調査・レビューの記録。当時の名称と当時の実装の引用を、現行名称に置き換えずに残す。第I部と食い違う箇所は第I部が優先する。

## 0. 位置づけ（旧。第I部 C0 で置き換え）

| 項目 | 記録 |
|---|---|
| 開始 | 2026-11-03。オーナーの指示「two.md の内容を five.md で拡張する。これからの Preference の内容は five.md でやる」 |
| 範囲 | Preference（app / com / org）の再設計と実装。two.md の WU-7 / WU-9 と §4 の Preference の部分を引き継ぐ |
| two.md との関係 | two.md の冒頭に「Preference の部分は five.md に移した。two.md の Preference の部分は実装しない」と追記済み（2026-11-03）。それ以外は two.md を変更しない。**有効な本文は §0〜§11。** 付録T は、§6.2 の状態表で Active とした条項だけを実装の根拠にできる。Superseded の条項は実装しない。Pending の条項は、本文の決定が出るまで実装しない（2026-11-04、レビュー 2 P0-4 による改訂） |
| 要件の正本 | **Preference については本書が要件の正本**（2026-11-04 オーナー決定、§12.4-6）。one.md の冒頭に移管を追記済み。one.md の Preference の条項（D-20〜24、D-32、D-50、D-54〜57、R-P-* など）は、本書と食い違う場合は本書が優先する |
| 別の作業 | OP 経由の step-up（`specs/op-mediated-step-up/`）は別のタブで進行中。本書では扱わない |
| 状態 | 設計中。**実装計画は確定しない**（§12.6 の決定待ち）。2026-11-04 に案 B（3 単位に分けて抜本的に作り直す）を決定（§12）。実装は未着手（例外は §3 のモック） |
| 読む順 | §0 → §0.1（上申用の要約）→ §14（用語）→ §11.4（決めること）→ §9（決定）→ §10（概念）→ §11（レビュー 2 の処置）→ §6（two.md との差分と付録T の状態）→ §7 / §8（棚卸しとレビュー 1）。§9 / §10 / §11 の未決事項は、実装できる仕様として扱わない |

## 0.1 上申用の要約（旧。第I部 C1 で置き換え）

本書の決定と未決を、上申のためにまとめる。詳細と根拠は各節。§0〜§9 の「Preference」「S / Z」は旧い呼び名（§14 で改定）。

### 決定済み

| # | 決定 | 節 |
|---|---|---|
| 1 | 今の Preference を抜本的に作り直す。**Experience / Consent / Affinity の 3 単位**に分け、「Preference」という語は新しい設計では使わない | §12.1、§14.1 |
| 2 | **Experience** は 2 つの置き場を持つ。guest experience（setting 系、ブラウザごと、app / com / org）と user experience（zenith 系、本人ごと、app / org）。表示の 10 項目は両方、通知の希望と Web Push の設定は user experience | §12.4-1、§14.1 |
| 3 | 表示の値（Display Snapshot）は導出結果で、保存しない。ログイン中は user experience の明示した値 → guest experience → 既定値、未ログインは guest experience → 既定値。JWT と表示 cookie はその運び手 | §12.1、§12.4-1、§14.2 |
| 4 | ログイン中の保存は常に user experience、未ログインは常に guest experience。二重書き込みはしない。Guest / User で controller を分け、認証状態による相互フォールバックはしない。form object は使わない | §2-1、§2-2、§12.4-4 |
| 5 | **Consent**（Cookie の同意）は setting 系、ブラウザごと。ログインの有無にかかわらず Consent のルートで書く | §12.4-1、§14.2 |
| 6 | **Affinity** は setting 系（app / com / org）に置き、zenith と紐づけない。各ブラウザに JWS を置き、信頼できる場合だけ DB を見て振る舞いを決める。認証・認可には使わない（表示の順番と案内だけ）。sign-out でも残す | §13.1、§12.8-1 |
| 7 | 3 単位はルート・controller を完全に分ける。リセットも単位ごとに別の操作 | §12.7-3、§12.8-2、§12.8-3 |
| 8 | DB が SSOT で、JWT に優先する。JWT が壊れている・古いと判断したら新しい JWT を発行する（GET は止めて再読み込み、書き込みは拒否してやり直し）。中身は DB の行から作り、信頼できる行がなければ初回と同じ扱い | §9.2、§12.7-1 |
| 9 | sign-in で Experience の反映に失敗してもログインは完了させる。表示は既定値に退避し、Base の GET で作り直す | §9.3、§12.7-2 |
| 10 | sign-out の後は guest experience（なければ既定値）で表示する。本人の好みはブラウザに残らない（旧要件 D-55 を改める） | §12.4-2 |
| 11 | Display Snapshot を作り直すのは、保存の直後、sign-in、sign-out、Base の GET で壊れている・古いとき。作り直しは cookie だけで DB は書かない | §12.4-3 |
| 12 | API で設定値を持たせる・キャッシュする設計は破棄。廃止するルートを ADR に記録済み | §2-7、§2-8 |
| 13 | 既存データの移行は考慮しない（本番は未公開）。開発とテストの DB だけ作り直す。migration と作り直しは実施前に改めて承認を得る | §12.4-5 |
| 14 | Preference に関する要件の正本は本書。one.md に移管を注記済み | §12.4-6 |
| 15 | テスト環境（テスト DB の残骸、構造 dump）の復旧を、本実装の前に終わらせる | §12.7-7 |

### 未決（上申後に決める）

| # | 論点 | 節 |
|---|---|---|
| 1 | com の Web Push: user experience がない com では設定できない。要件 D-20（app / com / org に追加）との関係 | §14.3-2 |
| 2 | Cookie の同意と本人の関係（GDPR の証跡）。案 C1 / C2 / C3。推奨は C2。法務の確認が前提 | §12.8.1 |
| 3 | Consent の語と既存の consent（Apple 連携など）の区別。コードでの修飾 | §14.3-1 |
| 4 | Affinity の JWS（cookie の名前と範囲、鍵、DB の表の形、保持期間） | §13.1 |
| 5 | 新しい Display Snapshot と JWT の形、cookie の名前を新しい語に揃えるか | §12.6-6、§14.3-5 |
| 6 | 3 単位のルートの具体的なパスと置き場所（Base / Auth） | §12.8-3 |
| 7 | 古い JWT の判定とステータスコード、文言 | §9.2 |

### 実装の状態

- 実装は未着手。例外は theme の選択肢の並び（system → light → dark）と、通知画面のモック（保存しない）（§3）。
- テストはテスト DB の残骸で実行できていない（§4-1）。
- 外部の敵対的レビューを 2 回受け、指摘はすべて採用（§8、§11）。

## 1. 入力

- 要件: `one.md`
- 旧設計: `two.md` §3.4（WU-7）、§3.12（WU-9）、§4（Preference の横断詳細設計）、付録 S
- ADR: `adr/preference-*.md`、`adr/api-route-vocabulary-consolidation.md`
- backlog:
  - `plans/backlog/2026-11-03-signed-in-preference-behavior-review.md`（ログイン状態の確認、www-jp の theme、通知画面）
  - `plans/backlog/2026-11-03-promotional-email-unsubscribe-redesign.md`（emails の作り直し）
- evidence: `evidence/2026-11-01-wu9-closure-result-R6T2.md` ほか WU-9 の記録

## 2. オーナー決定（2026-11-03）

1. **Guest / User の分離。** Guest は「ログインしていない」、User は「ログインしている」という意味。書き込みの経路（controller）を Guest と User で分ける。同じ controller の中で、認証状態によって書き込み先を切り替える構造はやめる。`User` model は復活させない。
2. **form object は使わない。** Rails Way（Active Record の validation、Strong Parameters、既存の認可）で行う。同日先に決めた「form object で切り替える」はこの決定で置き換える。
3. **com は Guest だけ。** com には認証がないため。ただし、インターフェイス（ルートや画面の形）は app / org と揃える。
4. **Guest の所有。** Rails の session ではなく、既存の Preference JWT（`__Secure-preference` の `sub` / `jti`）と、Base の `__Host-preference_binding` による匿名の setting の行の所有を前提にする。
5. **Visa の sign-in / sign-out の書き込みも、ちゃんと実装する範囲に含める。**
6. ~~Experience / Preference / Affinity の概念整理は今回扱わない。~~ **2026-11-04 オーナー指示で置き換え: 本書で扱う（§10）。**
7. **API で Preference の値を持たせる・キャッシュする設計は完全に破棄。** `adr/preference-tld-sharing-and-jwt-lifecycle-reassessment.md` の 2026-11-03 Amendment に記録済み。表示の値は、サーバが描く画面と、表示用の cookie（`language`、`__Secure-experience`）だけで渡す。
8. **廃止するルート**（実装は再設計の後）:
   - `GET /api/v0/preferences/{theme,cookie}`（Base、Auth、Core、Warp）
   - `GET` / `PATCH /api/v0/preferences/web_push`（Base の app / com / org）
   - `PATCH /api/v0/preferences/{theme,cookie}`（Auth、Core、Warp）。D-54 では、Preference を書けるのは Base と Visa だけ
9. **再設計で決めること:** 上のルートをなくした後の、保存した後の theme の確認、footer の theme の切り替え、Cookie の同意の部品の動き。Base に残る theme / cookie の PATCH の扱いも含む。
10. **通知画面。** 総合の通知ページとし、画面の名前は `notification` にする。Web Push はその中の 1 項目。`preference/emails` は通知画面と別のままにし、作り直しは別件として backlog に置く（Auth に置くかも含めて検討）。
11. **theme の選択肢の並び。** system → light → dark（実装済み、§3）。

## 3. 実装済みのもの（2026-11-03）

| 内容 | 状態 | 記録 |
|---|---|---|
| theme の選択肢を system → light → dark に（`app/controllers/concerns/base_preference_screen_page.rb`） | 実装済み。テストを追加したが、テスト DB の fixture の外部キー違反で未実行 | 本書 |
| 通知画面のモック（app / com / org の `/preference/notification/edit`、一覧のリンク、Web Push の表示だけの選択欄、何もしない update） | 実装済み。開発環境で表示と 303 を確認。テストなし。form object は 2026-11-03 に外した（§7.8） | backlog の「Notification page mock-up state」 |

注意: 通知画面のモックの form object は外した（§7.8）。本実装では Guest / User の controller に分ける。

## 4. 未解決の問題

1. **テスト DB の残骸。** fixture の外部キー違反（`enterprise_units` / `persona_memberships`、`client_chronicles` など）で、多くのテストが setup で止まる。WU-9 の締めと本書の検証の前提。掃除の範囲か、原因の修正を決める必要がある。
2. **www-jp に theme が反映されない。** コードの読み取りでは反映される作り。ブラウザでの確認がまだ（backlog に手順あり）。
3. **WU-9 の未完了。** 3 realm の受入条件の一覧での確認、全テストの締め、Preference の契約テストの一部。
4. **User の保存は 2 か所に書く。** two.md §4.5 では、本人の account（Z）を確定した後に、匿名の setting の行（S）も更新する。Guest / User の分離の設計で詰める（オーナー「おいおい詰める」）。
5. **ルートの PUT。** `resource ... only: :update` は PUT も作る。HTML の画面は既存の画面と同じ扱いでよいが、JSON の API が残る場合は `adr/api-route-vocabulary-consolidation.md` との関係を決める。
6. **User の書き込みに未ログインで来た場合の応答。** 今の `:private` は HTML ならログイン画面へ 3xx。書き込みはリダイレクトしない案を推奨（未決）。Guest の書き込みにログイン中で来た場合は 403（`declare_authentication_mode! :guest, status: :forbidden`）。
7. **reassessment の ADR の残り。** API の配布は破棄したが、ADR 全体は「Proposed — Decision Deferred」のまま。閉じるか、新しい ADR で置き換えるか。
8. **ほかの surface で動かす話。** オーナーの記憶にあるが、記録の場所は未確認。

## 5. 次の手順

2026-11-04 以降は §11.4 の順で決める（レビュー 2 で §8.2 を置き換え）。下の 1（棚卸し）は §7 で 1 回目を実施済み。

1. **棚卸し**（コードと文書を読むだけ）: 項目ごと（theme、言語、地域、timezone、通貨、日付、時刻、motion、density、件数、cookie の同意、Web Push、通知、リセット）に、保存先、cookie、画面、API、書く人（Base / Visa / ほかの surface）、Guest / User での動きを表にする。two.md や ADR との食い違いも書く。
2. **論点の一覧**: 表をもとに決めることを並べる。
3. **決定**: 論点を 1 つずつオーナーと決め、本書に記録する。必要なものは ADR / spec へ昇格する。
4. **実装**: 小さい単位で実装し、検証を evidence に残す。

範囲の確認が残っている: Base の app / com / org だけで始めるか、Visa や読み取り側（Core、Warp など）も最初から含めるか。

## 6. two.md との差分

### 6.1 決定による差分

| two.md | 本書 | 理由 |
|---|---|---|
| §3.4 / §4: Base の theme / cookie の API（host-local endpoint）を前提に含む | API での配布・キャッシュは破棄。Auth / Core / Warp の PATCH と web_push の API も廃止 | §2-7、§2-8 |
| §4.4: 共通の書き込み入口（concern）で Base / Visa が書く | Base の書き込みは Guest / User の controller に分ける。共通の書き込み処理はあり得るが、認証状態で書き込み先を切り替えない | §2-1 |
| §4.4 手順 4: 不正・古い `jti` などなら既定値の新しい行を作る | 新しい行は作らない。初回と明示リセットだけ作る | §9.2 |
| §12.5（付録T.7）: Root 確定後に Preference が失敗したら 503、code を発行しない | ログインは完了させ、code を発行する | §9.3 |
| §4.4 / §4.5: Z → S を順に確定し、両方を正しいものとして扱う | Z が正本、S は写し。User の保存の結果の意味は §11.4-2 で決める | §9.5、§11 |
| §4.6: GET では書かない。表示 cookie だけ DB から作り直す | 未決（ずれの修復を GET で行うか） | §9.6-2、§11.4 |

### 6.2 付録T の状態（2026-11-04）— **第I部 C8 で置き換え**

| 付録T | 状態 | 注記 |
|---|---|---|
| T.1 WU 一覧の行 | 参考 | 実装の根拠にしない |
| T.2 ADR の処理 | 参考 | ADR の改訂は本書の決定に従って別に行う |
| T.3 WU-P0 | 参考 | P0 の ADR 置換は 2026-10-31 に承認済み（zero.md）。本書の決定と食い違う ADR は改めて改訂する |
| T.4 WU-7（com） | Active（下の例外を除く） | API の配布（§2-7）、Web Push の API（§2-8）は Superseded |
| T.5 WU-9（app / org、Visa） | Pending | §9 / §11 の決定が出るまで実装しない |
| T.6 §4.1 所有・cookie・署名 | Active（cookie の 4 枚、`__Host-` binding） | §11.2-4（cookie の差し込み）の検証が残る |
| T.6 §4.2 shape / §4.3 DB の Before / After | Pending | §11.4-1（案 A / 案 B）で変わり得る |
| T.6 §4.4 共通の書き込み入口 | **Superseded**（手順 4 の新しい行の作成、Z → S を両方正しいとする扱い） | §9.2、§9.5、§11.4-2 |
| T.6 §4.5 項目別の書込み | Pending | §11.4-1、§11.4-5 |
| T.6 §4.6 GET / HEAD | Pending | §9.6-2、§11.4-3 |
| T.6 §4.7 同意 / Web Push の binding | Pending | §11.4-5 |
| T.6 §4.8 障害応答 | **Superseded**（不正 JWT での新しい行、sign-in の 503） | §9.2、§9.3 |
| T.6 §4.9 寿命・purge・鍵 | Active | 400 日の JWT と古い表示の残り方は §11.2-6 で明記 |
| T.7 §12.5 Visa の POST | Active（GET を no-store の form にし、POST だけで確定する部分）。**Superseded**（Preference 失敗で code を出さない部分） | §9.3 |
| T.8 §12.7 writer・鍵・reader | Pending | §11.4 の決定後に見直す |
| T.9 §12.8 実行票 | 参考 | migration と破壊的操作には別の承認が必要 |
| T.10 付録S 実表・NULL 列 | 参考 | 現在の DB は §7.1（開発 DB で確認）が新しい |

## 7. 棚卸し（2026-11-03、コードと開発 DB の読み取り。テストは未実行）

範囲: Base の app / com / org を中心に、Visa の書き込みと、Auth / Core / Warp の読み取り・API を含む。
根拠は各行のファイル。DB の列は開発 DB から読んだ（`db/*_structure.sql` は中身が空のため使えない）。
「設計」は two.md §4（付録T.6）。

### 7.1 データの置き場所

| DB | 表（Preference 関係） | 持ち主 |
|---|---|---|
| `app_setting` / `com_setting` / `org_setting` | `{app,com,org}_preferences`（`id, jti, public_id, status_id, last_issued_at, last_issued_expires_at`）と子表: 10 の表示項目（`_themes` など、`preference_id` + `option_id`）、`_cookies`（同意 4 列）、`_consent_receipts`、`_browser_bindings`、`_web_pushes`、`_adult_content_gates`、各 `_options`、`_statuses`（行は 0, 1） | 匿名の行（ブラウザ）。Guest も User も、表示はこの行から JWT を作る |
| `app_zenith` / `org_zenith` | `client_preferences` / `operator_preferences`（`client_id` / `operator_id, public_id, explicit_fields(jsonb), status_id`）と 10 の表示項目の子表、`_adult_content_gates`、`_statuses` | 本人の account。同意・binding・Web Push の表はない |

### 7.2 項目ごとの表

記号: S = 匿名の setting の行、Z = 本人の account の行。

| 項目 | 画面（Base） | S | Z | JWT / 表示 cookie | Base の保存（Guest） | Base の保存（User） | Visa sign-in | Visa sign-out |
|---|---|---|---|---|---|---|---|---|
| theme | `/preference/theme` | あり | あり | JWT `preferences.theme`、`__Secure-experience` | S を更新 | Z を更新して explicit に追加 → S を更新 | Z の explicit を S へ | 旧 S → 新 S |
| language | `/preference/language` | あり | あり | JWT、`language` cookie | 同上 | 同上 | 同上 | 同上 |
| timezone / currency / date_format（calendar）/ time_format（clock）/ motion / density / page_size（pagination） | 各 `/preference/<screen>` | あり | あり | JWT、`__Secure-experience` | 同上 | 同上 | 同上 | 同上 |
| region | `/preference/region` | あり | あり | JWT に地域そのものは入らない（`ANONYMOUS_PREFERENCE_VALUES` に region なし）。地域の保存は固定 4 項目を伴う | S を更新（4 項目も） | Z → S | 地域は反映しない（設計 D-50） | 旧 S → 新 S |
| cookie の同意 | `/preference/cookie`、API `/api/v0/preferences/cookie` | `_cookies`、`_consent_receipts`、`_browser_bindings` | なし | JWT に入らない。binding cookie `__Host-preference_binding`（Base の host だけ） | S に保存し binding を発行 | 同じ（Z には書かない） | 反映しない | 値と binding を写す |
| Web Push | 画面なし（通知画面のモックに表示だけ）。API `/api/v0/preferences/web_push` | `_web_pushes` | なし | JWT に入らない | API で S に保存 | 同じ | 反映しない | 写す |
| adult gate | なし | 表あり | 表あり | なし | なし | なし | なし | なし（休眠。two.md §3.12） |
| リセット | `/preference/customization`（edit / destroy） | 旧 S を退役 | 旧 Z を退役 | cookie を出し直し、binding を消す | — | — | — | — |
| 通知（モック） | `/preference/notification`（edit / update） | 書かない | 書かない | なし | 何もしない | 何もしない | — | — |

根拠: `app/controllers/concerns/preference_write_boundary.rb`（`write_app_org_preference!` l.133、`write_actor_preference!` l.275、`write_visa_preference!` l.438、`write_com_preference!` l.82）、`app/controllers/concerns/preference_core.rb`（`write_anonymous_realm_option!` l.274）、`app/values/security_jwt_preference_token_codec.rb` l.16-31。

### 7.3 書き込みの入口（allowlist）

`PreferenceWriteBoundary.writer_callers`（`preference_write_boundary.rb` l.907-1000）が、書いてよい controller を閉じた一覧で持つ。

- Base app / com / org の `save`: 各 `Preference::*Controller`（theme、cookie、currency、calendar、clock、motion、density、pagination、language、timezone、region、screens）と、`Api::V0::Preferences::{Cookies,Themes,WebPushes}Controller`
- Base の `reset`: `Preference::CustomizationsController#destroy`
- Visa app / org: `sign_in` は `Oauth::AuthorizationsController#create`、`sign_out` は `Oidc::Logouts::ConfirmationsController#create`
- Auth / Core / Warp: 一覧になし。これらの theme / cookie の `PATCH` は `require_preference_browser_writer!` で拒否される（`PreferenceBrowserControlsRegistry` が `NONE`、`app/values/preference_browser_controls_registry.rb` l.30-35）。`GET` は値を返す

### 7.4 Guest / User の分岐が今ある場所

| 場所 | 分岐 |
|---|---|
| `preference_write_boundary.rb` l.146-153 | `actor`（= `preference_write_actor`）があり、表示項目か地域の保存なら Z にも書く。ない場合は S だけ。同じメソッドの中で認証状態によって書き込み先が増える |
| `base/{app,org}/application_controller.rb` の `preference_write_actor` | ログイン中の resource を actor として返す。型が違えば `RecordNotFound` |
| `preference_core.rb` l.289 | Base の画面の保存は、すべて `write_preference!(actor: preference_write_actor, ...)` を通る |
| com | `write_com_preference!` を通る。com には認証がないので、実質 Guest だけ |

§2-1 の決定（controller を分ける）では、l.146-153 の分岐が分離の対象になる。

### 7.5 読み取り

| 読む側 | 何を読むか | DB |
|---|---|---|
| Base の画面の GET | JWT を検証し、表示 cookie が壊れていれば DB から作り直す（`preference_transport.rb` `set_app_org_preferences_cookie`） | 読む |
| Base の編集画面の初期値 | 匿名の行 S だけ（`preference_core.rb` `load_or_refresh_preference_child_for_edit` l.357） | 読む |
| Visa | sign-in で Z の explicit を読む（`explicit_actor_preference_snapshot`） | 読む |
| Auth / Core / Warp の画面 | JWT の値だけ（`ActorSupport#resolved_current_preference`） | 読まない |
| Auth / Core / Warp / Base の `GET /api/v0/preferences/{theme,cookie}` | 保存した後の theme の確認など | 廃止予定（§2-8） |

### 7.6 設計・決定との食い違い

1. **編集画面の初期値。** 設計 §4.6 は「本人の explicit → 匿名の行 → 既定値」。実装は、ログイン中も匿名の行 S だけを読む。
2. **書き込みの分岐。** §2-1 の決定（Guest / User で controller を分ける）に対し、実装は 1 つのメソッドで actor の有無によって Z への書き込みを足す（§7.4）。
3. **廃止予定の API。** §2-8 の対象（`GET` theme / cookie、web_push の API、Auth / Core / Warp の `PATCH`）は残っている。Auth / Core / Warp の `PATCH` は書き込まずに拒否する。
4. **Web Push の画面。** 要件 D-23 は「既存の項目と同じ書き方」。実装は API だけで画面がない（通知画面のモックは表示だけ）。
5. **通知画面のモック。** form object を使っている（§2-2 の決定と逆）。writer の allowlist に入っていない（書かないので今は問題ない）。
6. **cookie の同意の列。** model の注釈には `consent_version`、`consented_at`（NULL 可）が残っているが、開発 DB の `app_preference_cookies` にはない。注釈が古い可能性（未確認）。
7. **`ScreensController`。** writer の allowlist に入っているが、`SCREEN_ACTIONS` に `screen` の鍵がない。何の画面かは未確認。
8. **構造の dump が空。** `db/app_setting_structure.sql` などの中身がない（WU-X の記録にある既知の問題）。schema の差分を dump で確かめられない。

### 7.7 未確認

- テストの実行（テスト DB の残骸で止まるため）。
- ブラウザでの実際の cookie と、www-jp の theme（§4-2）。
- `ScreensController` の役割、`explicit_fields` の書き込みと読み取りの全経路。
- Auth / Core / Warp の `GET` を呼ぶフロントの全箇所（theme は 3 か所を確認、cookie は未確認）。

### 7.8 棚卸しへのオーナー判断（2026-11-03）

| §7.6 | 判断 | 次の扱い |
|---|---|---|
| 本人の account に同意・binding・Web Push がない（§7.1） | 良くない。改善が必要 | 設計で詰める。注意: 要件 D-24 / D-32 の改訂（同意と Web Push の opt-in は Base の DB にだけ置き、account と同期しない）と、D-50（sign-in で同意と Web Push を反映しない）に関わる。要件の変更として決める必要がある |
| 1. 編集画面の初期値 | 改善する（設計 §4.6 の「本人の explicit → 匿名の行 → 既定値」に合わせる） | 実装の対象 |
| 2. 書き込みの分岐 | Guest と User で実装の部品は同じにする。User は「Guest の処理 + 追加の処理（account への書き込み）」という形で書く | **再検討（§8.3）**。共通部分は認証の判断を持たない低水準処理に限る条件で、§8.2-5 で決める |
| 3. 廃止予定の API | §2-8 のとおり | 実装の対象 |
| 4. Web Push の API | 消す（§2-8 と同じ） | 実装の対象。画面は通知画面で作る |
| 5. 通知画面のモックの form object | 改める | **済み（2026-11-03）**: `app/forms/preference_notification_form.rb` を削除し、`base_preference_notification_screen.rb` の update は strong parameters を読んで 303 で戻すだけにした。開発環境で 3 surface とも 303 を確認、RuboCop 問題なし。テストなし |
| 6. 同意の model の注釈 | 改める | 未着手（実装に触らない指示のため） |
| 7. `ScreensController` | 調べる | 調べた（下）。扱いは未決 |
| 8. 構造の dump が空 | オーナーから質問あり | 下の説明 |

**`ScreensController` の調査結果。** `Base::{App,Com,Org}::Preference::ScreensController` は `/preference/screen`（`resource :screen, only: %i(edit update)`、`config/routes/base.rb` l.67, 330, 439）。URL のパラメータ `preference_screen`（例: `theme`）で、どの項目の画面・保存かを選ぶ汎用の入口（`base_preference_screen_dispatch.rb` の `preference_key` が `params[:preference_screen]` を読む）。アプリと画面からのリンクは見つからない。使っているのはテスト（`test/integration/anonymous_com_web_push_initialization_test.rb` の generic screen のケース、ルートの契約テスト）だけ。各項目の専用の controller と同じ保存を、クライアントが選んだ値で振り分ける重複の経路なので、廃止の候補。

**構造の dump が空の件。** `db/app_setting_structure.sql` などは、テーブルの定義がなく、ヘッダだけ（448 バイト）。DB の構造を記録するファイルで、テスト DB の作成や差分の確認に使う。evidence `2026-10-31-wux-structure-dumps-R7T3.md` に、10/30 に dump が空になった件と、原因が未特定であることが記録されている。Preference には直接関係しないが、migration を伴う実装の前に、開発 DB から dump を作り直す必要がある（`bin/rails db:schema:dump` の実行。DB の書き込みはしない）。

## 8. レビュー 1（外部の敵対的レビュー、2026-11-04 受領）

判定: 現段階では実装計画を確定させない。Guest / User の controller 分離、form object 不採用、GET 共通・書き込み URL 分離、認証状態による相互フォールバック禁止は維持。以下は再検討。

### 8.1 指摘と検証

| ID | 指摘 | Claude Code の検証（2026-11-04、コード読み取り） | 判定 |
|---|---|---|---|
| P0-1 | User の保存が Z → S の逐次 commit で、途中失敗で不一致になる。どちらが正本か曖昧 | 設計 two.md §4.4 / §4.8（付録T.6）が部分成功を許容 | 妥当。再検討必須 |
| P0-2 | 古い `jti` の保存で既定値の新しい S を作り、設定が消える。競合とリセットが同じ処理 | `preference_write_boundary.rb` l.516-530 `current_realm_preference_for_write` は `jti` 不一致で `nil` を返し、呼び出し側が既定値の新行を作る。2 タブで再現し得る | 妥当（実装で確認）。再検討必須 |
| P0-3 | Preference の失敗でログイン（OIDC のコード発行）が止まる | `visa/{app,org}/authorization_base_controller.rb`（l.131 / l.137）と `oidc_authorization_result_post.rb` l.468 が `rescue StandardError` で 503、コード未発行。ADR `preference-visa-writer-boundary.md` は l.26（結果を変えない）と l.60（コードを出さず一時失敗）で食い違う | 妥当（実装で確認）。再検討必須。例外を一括で扱う点も問題 |
| P0-4 | Z 確定後に S の世代不一致が判明する。どの検証失敗なら Z を更新してよいかが未定義 | P0-1 と同じ設計 | 妥当 |
| P1-1 | 共通 writer が actor の有無で Z を書き分けるなら、controller 分離が形骸化 | §7.4 の現状どおり | 妥当。共通部分は認証判断を持たない低水準処理に限る |
| P1-2 | 正本が状況で異なる。表示 cookie の再構築で JWT と表示 cookie がずれ得る | 設計 §4.6 は表示 cookie だけ再発行し JWT は延長しない | 妥当。1 応答内の優先順位を統一する |
| P1-3 | 同意・Web Push の所有主体が未確定。Web Push の `enabled` と購読（Push API / Service Worker）は別物。sign-out で写す扱いと共有端末 | §7.8 の「account にない」判断と D-24 / D-32 / D-50 が衝突 | 妥当。同意（ブラウザとサイト）、購読（ブラウザ・端末）、通知の希望（本人）を分けて考える |
| P1-4 | `__Secure-` cookie は兄弟サブドメインから差し込める（cookie tossing） | 同名 cookie の曖昧入力の拒否は既存（WU-7 の evidence）。十分かは未確認 | 妥当。由来、同名解析、CSRF、Origin、account と S の関連付けを検証 |
| P1-5 | 署名付き JWT の所持はブラウザの所有の証明ではない。User の Z は認証基盤の actor から決める | User の Z は `preference_write_actor` から決めている（§7.4） | 妥当。同意・Web Push には追加の所有確認が必要か判断 |
| P1-6 | リセットの保証内容（表示を戻す / 古い行の失効 / 削除）が曖昧。古い JWT は期限まで表示に使える | 設計 §4.6 / §4.9 | 妥当 |
| 実装 | `ScreensController` 廃止候補、廃止 API の呼び出し元の未調査、通知の update が保存しない（モック）、テスト DB、構造 dump、PUT | §7.6 / §7.7 と一致 | 妥当。テスト DB と構造 dump は本実装前のブロッカー |
| §4 | GitHub の `feature` ブランチとの照合 | 公開ブランチは作業ツリーより古い。`preference_write_boundary.rb` などは作業ツリーに存在する | 採用しない（照合対象が古い） |

### 8.2 決める順序（レビューの推奨を採用）

**2026-11-04: §11.4 で置き換え。** 1〜3 は §9 で一部決定済み。残りは §11.4 の順で決める。

1. S と Z の所有・正本・同期の方式（ログイン中は Z が正本か、S が常に表示の正本で Z は永続の保存先か）
2. JWT の世代不一致と回復の規則（初回、正常、古い `jti`、改ざん、別 realm、明示リセットを区別。古い `jti` は 409 などの競合通知が候補）
3. 認証の成功と Preference の反映を切り離すか（OIDC 応答の重複発行の防止、再試行、途中障害の回復を含む）
4. 同意・Web Push・通知の希望の所有単位
5. Guest / User の書き込みの具体的な決まり
6. テスト環境の復旧（テスト DB の残骸、構造 dump）

### 8.3 本書への影響

- §7.8 の「User は Guest の処理 + 追加の処理」は**再検討**に戻す。共通部分は認証の判断を持たない低水準の保存処理に限る、という条件付きで 8.2-5 で決める。
- §7.8 の「account に同意・binding・Web Push がないのは良くない」は、8.2-4 で、同意・購読・通知の希望を分けて決める。
- 二重書き込み、古い JWT、ログインとの結合は、two.md の設計（付録T.6、T.7）をそのまま実装しない。8.2 の決定で置き換える。

## 9. オーナー決定（2026-11-04、§8.2 への回答）

### 9.1 呼び名

「S」「Z」は分かりにくいので、本書では今後次の呼び名を使う（§7 と §8 の S / Z は読み替える）。

| 新しい呼び名 | 旧略称 | 実体 |
|---|---|---|
| **ブラウザ設定**（browser preference） | S | `{app,com,org}_setting` の `{app,com,org}_preferences` と子表。ブラウザごと。JWT と表示 cookie の元 |
| **アカウント設定**（account preference） | Z | `app_zenith` / `org_zenith` の `client_preferences` / `operator_preferences` と子表。本人ごと |

### 9.2 決定 2: JWT と DB が食い違うとき（§8.2-2）

- **DB が SSOT で、JWT に優先する。**
- 保存のときに JWT の `jti` などが DB と合わなければ、JWT の値は使わずに捨てる。既定値の新しい行は作らない。
- 応答は plain で「システムエラーが出ました。再読み込みしてください」のような案内にし、利用者に読み込み直してもらう。GET の処理であれば、再アクセスを促す。
- 既定値で新しく作るのは、初回（JWT がない）と明示的なリセットだけ（§8.2-2 の区別による。改ざん・別 realm も同様に作らない）。
- 未決: ステータスコード（409 などの候補）、文言の翻訳キー、JSON の場合の形、GET で「再アクセスを促す」の具体的な動き。
- **レビュー 2 P0-3 の指摘（採用）:** GET で JWT を出し直さない限り、再読み込みしても同じ古い JWT が送られ、同じ拒否が続く。「再読み込みしてください」だけでは復旧にならない。復旧の経路は §11.4-3 で決める。
- **レビュー 2 P0-2 の指摘（採用）:** 「保存を進めない」は Guest の保存には当てはまるが、User の保存では Z を先に確定するので（§9.5）、S の世代不一致が分かった時点で Z は確定済み。User の保存の結果の意味は §11.4-2 で決める。

### 9.3 決定 3: sign-in と Preference の切り離し（§8.2-3）

- **ログインは完了させる。** Visa の sign-in で Preference の反映に失敗しても、記録するだけで OIDC のコードを発行し、ログインを完了させる。
- Preference は後で作り直す（作り直す時点と方法は §9.4 の結論に合わせて決める）。
- `adr/preference-visa-writer-boundary.md` の食い違い（l.26 と l.60）は、l.26（結果を変えない）に揃える改訂が必要。
- 今の `rescue StandardError` での一括の 503 は改める。
- **レビュー 2 P1（採用）:** 認証そのものの失敗（本人の識別、OIDC の要求の検証）を Preference の失敗として扱ってはならない。Preference の失敗だけを切り離す。
- **レビュー 2 P1（未決）:** 失敗したときのブラウザの表示（前の利用者の表示が残り得る）と、作り直す時点・回数・作り直せないときの扱いは §11.4-4 で決める。

### 9.4 決定 1 の前提調査: 二重書き込みは無駄か（オーナー依頼による精査）

オーナーの疑問: sign-in / sign-out でブラウザ設定を作り直しているので、ログイン中の保存でアカウント設定とブラウザ設定の両方に書くのは無駄ではないか。

コードで確かめたこと（`preference_write_boundary.rb`）:

| 場面 | アカウント設定 | ブラウザ設定 |
|---|---|---|
| ログイン中の保存（`write_app_org_preference!`） | 変えた項目を書き、`explicit_fields` に足す（`write_actor_preference!` l.275） | 同じ項目を書き、JWT と cookie を出し直す |
| Visa sign-in（`write_visa_preference!`） | 読むだけ（`explicit_actor_preference_snapshot` l.580、明示した項目だけ） | 今のブラウザ設定に、明示した項目を上書き |
| Visa sign-out | 触らない | 新しい行を作り、旧い行の表示 10 項目・同意・binding・Web Push を写し（`copy_realm_preference_state!` l.651）、旧い行を退役 |

ブラウザ設定への書き込みが担っている役目:

1. **ログイン中にすぐ表示を変える。** 表示（JWT と cookie）はブラウザ設定から作るので、保存の直後に画面へ反映するには、ブラウザ設定か JWT のどちらかを変える必要がある。
2. **sign-out の後も最後の表示を残す。** sign-out は旧いブラウザ設定を写すので、ログイン中に変えた値がブラウザ設定に入っていないと、sign-out 後にログイン前の表示へ戻る（要件 D-55「最後に使っていた表示をブラウザに残す」）。
3. **ほかの surface（Auth / Core / Warp）への反映。** これらは JWT だけを読むので、JWT を出し直さないと変わらない。

結論（Claude Code の評価）:

- sign-in / sign-out の作り直しだけでは、上の 1〜3 を満たせない。ブラウザ設定への反映そのものは無駄ではない。
- 問題は「2 つの DB に順に書き、どちらも正しいものとして扱う」こと（§8.1 P0-1）。役目を分けると、二重書き込みを「アカウント設定を確定 → ブラウザ設定はそれを写す（失敗しても後で作り直せる写し）」と扱える。これが決定 1 の推奨案（アカウント設定が正本、ブラウザ設定は写し）。
- 写しが失敗したときに作り直す場面は、決定 3 の「Preference は後で作り直す」と同じ仕組みにできる（例: Base の GET で、ログイン中の利用者のブラウザ設定がアカウント設定の明示した項目と合わなければ作り直す）。ただし、GET で書き込まない現在の規則（two.md §4.6）との関係を決める必要がある。
- 無駄が残る点: sign-in のたびに明示した項目を上書きする処理は、写しが常に正しく保たれていれば省ける可能性がある。ただし別のブラウザでの初回 sign-in では必要なので、なくせない。

決定 1 は §9.5 で決定。

### 9.5 決定 1（2026-11-04）

- **ずれたらアカウント設定（Z、zenith）を優先する。** ログイン中は Z が正本、ブラウザ設定（S、setting）は Z の写し。
- **書く順は Z が先、S が次。** Z を確定させてから S を書く。S の書き込みに失敗しても、Z は正しいまま（保存を失敗とするか、成功として S を後で作り直すかは §9.6）。
- **com は S だけ。** com には Z がないため（§2-3）。
- 二重書き込みは「2 つとも正しく保つ」ものではなく、「Z が正本、S は写し」として残す（§9.4）。

### 9.6 決定 1 に続いて決めること（未決）

1. Z を確定した後に S の書き込みが失敗したときの応答（保存は成功で S は後で作り直す、または保存の失敗として案内する）。
2. ずれを直す機会: 保存の直後と sign-in だけか、ログイン中の Base の GET でも直すか（GET では書き込まない規則への例外になる）。
3. ずれを見分ける目印（Z の版と、S に「どの版から写したか」を持たせる。migration が必要）を持たせるか。

## 10. Experience / Preference / Affinity の概念整理（2026-11-04 統合）

以前の議論で決めた概念整理を、オーナーの指示により本書に統合する。決定済みなのは名称、概念上の責務、DB 名を維持する方針。保存方式や同期規則は今後の設計事項。要件定義（one.md）の改訂を目的とするものではない。

### 10.1 定義

| 項目 | Experience | Preference | Affinity |
|---|---|---|---|
| 所属 | 利用者 | ブラウザ | ブラウザ |
| 主な目的 | 好みの継承 | ブラウザ固有の設定 | 過去の選択の記憶 |
| アカウントとの紐づけ | あり | 原則なし | なし |
| ブラウザ間の共有 | あり | 原則なし | なし |
| 主な保存場所 | サーバーの DB | サーバーの DB | ブラウザ内 |
| 代表例 | 言語・テーマ | ブラウザ固有の通知設定 | 前回選んだサインインの方式 |

- **Experience:** 利用者本人に属する好み。別のブラウザや端末でサインインしても引き継ぐ。
- **Preference:** ブラウザごとに独立した設定。アカウントに依存しない。サーバー側で保存する場合もある。
- **Affinity:** ブラウザ内に、過去の選択や利用傾向を記憶する。最初の用途は前回選んだサインインの方式（前回 Passkey を選んだブラウザでは、次回 Passkey を優先して案内する）。将来は認証以外の操作の案内にも使える。

### 10.2 命名の検討結果

| 名称 | 判断 | 理由 |
|---|---|---|
| Experience | 採用 | 利用者の体験や好みを表す |
| Preference | 採用 | ブラウザ固有の設定を表す |
| Assurance | 不採用 | 認証の保証やセキュリティ上の保証と混同しやすい |
| Hint | 不採用 | 概念名として軽い |
| Recall | 候補止まり | 過去の選択を思い出すという意味 |
| Oracle | 候補止まり | 予測・判断を行う仕組みを連想させる |
| Affinity | 採用 | 過去の利用から形成された親和性・傾向を表す |

DB 名（`*_setting` など）は変更しない。3 つは責務を整理するための概念名で、DB の物理名と一致させる必要はない。

### 10.3 Affinity の方針

- アカウントに紐づけない。原則ブラウザ内で完結し、サーバーの DB に保存しない。
- 認証・認可の判断に使わない。失われても通常の操作を続けられる。
- ~~保存方式は `localStorage` が候補。~~ **失効**（2026-11-04: Affinity は setting 系の DB に置く（記録 §13.1）。`localStorage` / `sessionStorage` は使わない（第I部 C3-1））。形式、保持期間、削除方法、更新の契機は未定。

### 10.4 本書の用語との対応（Claude Code の整理。未承認）

注意（レビュー 2 P0-1）: 下の対応は今の実体の対応で、§10.1 の定義と矛盾する箇所がある。今のブラウザ設定はログイン中にアカウント設定の写しを含む（§9.5）ので、§10.1 の「Preference はアカウントに依存しない」とそのままでは一致しない。どちらに揃えるかは §11.4-1（案 A / 案 B）で決める。

| 概念 | 本書の呼び名（§9.1） | 今の実体 |
|---|---|---|
| Experience | アカウント設定（Z） | `app_zenith` / `org_zenith` の `client_preferences` / `operator_preferences`。表示 10 項目と `explicit_fields` |
| Preference | ブラウザ設定（S） | `{app,com,org}_setting` の `{app,com,org}_preferences` と子表。表示 10 項目、同意、binding、Web Push |
| Affinity | （なし） | 実装なし（前回のサインイン方式の記憶は、今のコードで別にあるかは未確認） |

この対応で見えてくる論点:

1. **同じ項目が Experience と Preference の両方にある。** 表示 10 項目は Z と S の両方にある。§9.5 の決定（ずれたら Z を優先、Z を先に書き S は写し）は、「ログイン中は Experience が Preference に優先する」と言い換えられる。
2. **cookie の名前のずれ。** 今の `__Secure-experience` は、ブラウザ設定（S）から作った表示の状態で、§10.1 の「利用者に紐づく Experience」とは意味が違う。名前を改めるか、意味を定義し直すかを決める必要がある（cookie の名前の変更は既存のブラウザに影響する）。
3. **同意・Web Push・通知の希望（§8.1 P1-3、§8.2-4）。** ~~同意と Web Push の購読はブラウザに属するので Preference~~（レビュー 2 で訂正: 今の `_web_pushes` は `enabled` / `disabled` の設定で、Push API の購読ではない。購読と同一視しない）。分け方は §11.2-7 の案で再検討する。§7.8 の「account に同意などがないのは良くない」もそこで扱う。
4. **com。** Experience がない（Z がない）ので、Preference だけ（§2-3、§9.5）。
5. **one.md との関係。** one.md の用語（account Preference、匿名の行など）は変えない。本書の設計で概念名を使い、必要になった時点で要件の変更として扱う。

### 10.5 今後の検討事項（統合元の一覧）

| 論点 | 内容 |
|---|---|
| Experience と Preference の関係 | 同じ項目が両方にある場合の扱い（§9.5 で一部決定） |
| サインイン時の反映 | Experience をブラウザの表示にどう反映するか |
| サインアウト時の保持 | 利用者の設定をブラウザにどこまで残すか |
| cookie の整理 | `__Secure-experience` の名前と責務 |
| Affinity の保存方式 | `localStorage` などの採用判断 |
| Affinity の適用範囲 | 前回のサインイン方式以外に何を記憶するか |

## 11. レビュー 2（外部の敵対的レビュー、2026-11-04 受領）と処置

判定: 方向は妥当（3 概念、DB 名の維持、Guest / User の分離、認証を Preference に依存させない、古い `jti` で新しい行を作らない、アカウント設定の優先と逆流の禁止）。実装計画の確定には反対。本書はこの判定を受け入れ、§0 の状態を「実装計画は確定しない」とした。

### 11.1 指摘と処置

| ID | 指摘 | 処置 |
|---|---|---|
| P0-1 | Experience と Preference の独立を宣言しながら、Preference を Experience の写しとして扱っている（§9.5 と §10.1 の矛盾）。共有ブラウザで、B の未設定の項目に A の残した値が出る | 採用。§10.4 に注意を追加。§11.4-1 で案 A / 案 B を決める |
| P0-2 | Z を先に確定するのに、S の `jti` 不一致で保存を拒否するのは両立しない | 採用。§9.2 に注記。§11.4-2 で User の保存の結果の意味を決める |
| P0-3 | 「再読み込みしてください」は、GET で JWT を出し直さない限り復旧にならない | 採用。§9.2 に注記。§11.4-3 で復旧の経路を決める |
| P0-4 | 付録T が §0〜§6 と矛盾しない限り有効、としたため、§9 の新しい決定より古い付録T が優先し得る | 採用し、本書で修正済み（§0 の有効範囲を §0〜§11 に、§6.1 の差分を追記、§6.2 に付録T の状態表） |
| P1 | sign-in で Preference が失敗した後の表示と復旧が未定義。認証の失敗と Preference の失敗の混同 | 採用。§9.3 に注記。§11.4-4 |
| P1 | 「DB が SSOT」が読み取りの最新性を説明していない（Auth / Core / Warp は JWT を読み、古い `jti` の JWT も期限まで表示に使える） | 採用。§11.2-6 で保証を 2 つに分ける |
| P1 | 「ブラウザごと」の技術的な境界が未定義（Domain cookie、host cookie、`localStorage` は origin ごと） | 採用。§11.2-5 |
| P1 | 通知の希望、ブラウザの通知許可、Push の購読、同意の意味が混ざっている | 採用。§10.4 を訂正。§11.2-7、§11.4-5 |
| P1 | Affinity が認証に介入する境界（何を記録するか、信用しないこと、識別に結びつく情報）が未定義 | 採用。§11.2-8、§11.4-6 |
| P1 | sign-out とリセットの対象が 3 概念に対応していない | 採用。§11.2-9、§11.4-7 |
| P2 | `__Secure-experience` の名前と Experience の概念がずれる | 採用（名前は直ちに変えない）。§11.2-10 |
| P2 | テスト環境が壊れたままでは検証できない | 採用。§11.3 に受入条件。テスト DB と構造 dump は本実装の前のブロッカー（§4-1、§7.8） |

### 11.2 Claude Code の改訂案（未承認。§11.4 の判断材料）

1. **Experience と Preference の関係（§11.4-1）。**
   - 案 A（今の構造を維持）: ブラウザ設定は、アカウント設定から写した値を含むと正式に定義する。§10.1 の「アカウントに依存しない」は「アカウントに紐づく DB の行ではない」に改める。共有ブラウザで B の未設定の項目に A の値が出ることを許容するかを、別に決める。
   - 案 B（概念に揃える）: Experience と Preference をそれぞれ独立した正本とし、表示する値は両者から導出する（項目ごとに「Experience の明示した値 → Preference → 既定値」など）。JWT と表示 cookie は導出結果の運び手（Display Snapshot、§11.2-10）で、第 4 の設定ではない。ログイン中の保存はアカウント設定だけに書き、ブラウザ設定には書かない。sign-out の後の表示の保持、Auth / Core / Warp の表示、表示 cookie が消えたときの復元を一体で設計し直す必要がある。
   - 評価: §10.1 を厳密に守るなら案 B。今の実装を活かすなら案 A に意味を改める。両方の説明を同時に採らない。案 B は二重書き込み（§8.1 P0-1）を根本からなくせる。
2. **User の保存の結果（§11.4-2）。** User の保存を「アカウント設定の保存」と「ブラウザへの反映」に分ける。Z の確定が保存の結果で、その後の S の世代不一致や失敗は Z を取り消さない（反映だけが保留になり、§11.2-3 の経路で直す）。Guest の保存は S が唯一の正本なので、`jti` 不一致で保存全体を拒否する。案 B を採る場合、User の保存は S に書かないので、この問題は小さくなる。
3. **古い JWT の復旧（§11.4-3）。** 「再読み込み」と「復旧」を分ける。
   - 署名・期限・realm が正しく、`sub` の行が有効で、`jti` だけが古い場合: 明示的な復旧の操作（POST、CSRF・Origin・所有の検証付き）で、DB の今の行から JWT と表示 cookie を出し直す。古い JWT を持つ別の人が今の表示値を得られる残余リスクがある（表示値だけ。同意と Web Push は binding がなければ有効にしない）。
   - 署名不正・別 realm・行がない・退役済み: 復旧させず、既定値で始め直す明確な終端（利用者の操作による新しい行）を用意する。再読み込みの繰り返しにしない。
4. **sign-in で Preference が失敗したとき（§11.4-4）。** 認証は完了させ、表示は既定値へ退避する（前の利用者の表示 cookie を残さない）。作り直す時点は §9.6-2（ログイン中の Base の GET など）と同じ仕組みにし、回数の上限と、作り直せないときは既定値のまま表示することを決める。
5. **「ブラウザごと」の技術的な境界。** Preference は「realm の登録ドメイン内のブラウザ状態」（`__Secure-preference` などは `Domain=.umaxica.<tld>`、binding は Base の host だけ）。Affinity は「特定の origin のローカル状態」（`localStorage` は scheme・host・port ごと。`auth.umaxica.app` と `visa.umaxica.app` は共有しない）。プライベートブラウズや別プロファイルは別のブラウザとして扱う。
6. **正本と表示の保証を分ける。**
   - 永続の正本の保証: Experience の永続値は zenith の DB、Preference の永続値は setting の DB。JWT や cookie から永続値を自動で復元しない。
   - 表示の整合の保証: JWT と表示 cookie はスナップショットで、一時的に DB と違ってよい。どの操作で整合を戻すか（保存の直後、sign-in、復旧の操作、ログイン中の Base の GET など）を定める。JWT の寿命が 400 日なので、更新されない限り古い表示が長く残り得ることを明記する。
   - 保存の認可: User は認証済みの Client / Operator と既存の認可、Guest は検証済みの JWT と binding。
7. **通知・同意の分け方（§11.4-5）。**
   - Experience: 通知を受けたいという本人の希望。
   - Preference: ブラウザでの通知に関する設定（今の `_web_pushes` の `enabled` / `disabled` はここ）。
   - ブラウザの通知許可（Notification permission）と Push の購読（Push subscription）: 外部のブラウザ API の状態として区別する。新しい概念にはしない。one.md の範囲外（配信機構）は変えない。
   - 同意: Preference に置く場合も、何に対する、どの範囲の同意で、記録が何を意味するかを明示する。ブラウザに残った同意が、別の利用者の本人に関するデータ処理への同意になるとは扱わない。
8. **Affinity の契約（§11.4-6）。**
   - 最初は「前回選んだサインインの方式」を、Auth のサインインの方式を選ぶ画面の origin だけに記録する（選んだ時点で記録し、認証の成功に結びつけない案）。
   - 使ってよいのは表示の順番と案内だけ。方式の利用可否、OIDC の要求、MFA、Step-Up、認証の状態遷移に影響させない。保存値で自動送信や確認の省略をしない。
   - 保存する項目は許可リストで限定し、利用者・セッションの識別子を入れない。サーバーへ送らない。期限と消し方を決める。読み書きに失敗してもサインインを続ける。sign-out で残すかを決める。
9. **sign-out とリセットの範囲（§11.4-7）。** 次の対応を案とする。

   | 操作 | Experience | Preference | Affinity |
   |---|---|---|---|
   | sign-out | 維持 | 最後の表示を保持（D-55） | 未決 |
   | Experience のリセット | 初期化 | 反映の方法は未決 | 維持 |
   | Preference のリセット | 維持 | 初期化 | 維持 |
   | Affinity のリセット | 変えない | 変えない | 初期化（Auth の origin の画面で行う必要がある） |
   | 全設定のリセット | 範囲を明示 | 範囲を明示 | 範囲を明示 |

   sign-out は認証情報の破棄で、ブラウザのすべての記憶の消去ではないことを明記する。
10. **Display Snapshot。** 画面の表示に使う、導出された値を Display Snapshot と呼ぶ。`__Secure-experience` と `language`、JWT の `preferences` はその運び手と定義する。cookie の名前は直ちに変えない（変えても安全性は上がらず、既存のブラウザに影響する）。名前を揃えるかは、cookie を整理する機会に改めて決める。`__Secure-` は兄弟サブドメインからの差し込みを防がないので、§8.1 P1-4 の検証は残す。

### 11.3 受入条件の案（テスト環境の復旧後）

| 試験 | 確かめること |
|---|---|
| 同時保存（2 タブ） | 古い `jti` が Z と S の整合を壊さない。Guest は拒否、User は Z の保存を取り消さない |
| DB の部分障害 | Z 確定後に S が失敗したときの応答（§11.4-2 の決定どおり） |
| 古い JWT の復旧 | 復旧の操作で回復できる。再読み込みの繰り返しにならない |
| 利用者の切り替え | A の設定が B のアカウント設定に保存されない。B の表示に A の値が出るかは §11.4-1 の決定どおり |
| Visa の Preference 障害 | Preference が失敗しても認証が完了する。表示は §11.4-4 の決定どおり |
| 遅延応答 | 古い `Set-Cookie` が後から届いても、新しい状態を壊さない（保存の成功の順と表示の反映の順を分けて確かめる） |
| Affinity の消失 | 記録がなくても通常の方式選択の画面が出る |
| sign-out | 認証情報だけが確実に失効し、残す情報は §11.4-7 の決定どおり |
| リセット | 対象の概念だけが初期化される |
| 改ざん・別 realm・同名 cookie | 拒否し、どの行も更新しない |

### 11.4 オーナーが決めること（この順で決める。§8.2 を置き換え）

1. **Preference は Experience の写しを含んでよいか（案 A / 案 B、§11.2-1）。** 最優先。ここで二重書き込み、sign-in / sign-out、復旧、cookie の責務の形が決まる。
2. **User の保存の結果の意味（§11.2-2）。** Z の確定を保存の成功とし、S の失敗・不一致は反映の保留とするか。
3. **古い JWT の復旧の経路（§11.2-3）。** 明示的な復旧の操作を設けるか。復旧させない場合の終端。
4. **sign-in で Preference が失敗した後の表示と作り直し（§11.2-4）。**
5. **通知・同意の分け方（§11.2-7）。**
6. **Affinity の記録の契機と範囲（§11.2-8）。**
7. **sign-out とリセットの範囲（§11.2-9）。**
8. §9.6 の残り（ずれを直す機会、版の目印）。1 の決定によって不要になる可能性がある。
9. テスト環境の復旧（テスト DB の残骸、構造 dump）。実装の前のブロッカー。

## 12. オーナー決定（2026-11-04）: 案 B で抜本的に作り直す

### 12.1 決定

- **§11.4-1 は案 B。** Preference を一本にせず、**Experience / Preference / Affinity の 3 つの単位に分ける**。今の実装はバグが入りやすいので、抜本的に作り直す。今しかない、というオーナーの判断。
- Experience と Preference はそれぞれ独立した正本。表示する値は両者から導出し、JWT と表示 cookie はその運び手（Display Snapshot、§11.2-10）とする。
- §10.1 の定義をそのまま守る（「Preference はアカウントに依存しない」を改めない）。

### 12.2 この決定で変わること（Claude Code の整理。詳細は今後決める）

| 対象 | 今 | 案 B の後 |
|---|---|---|
| ログイン中の保存 | Z（アカウント設定）と S（ブラウザ設定）に順に書く | Experience（zenith）だけに書く。Preference に写さない。二重書き込みはなくなる |
| 未ログインの保存 | S に書く | Preference（setting）に書く |
| 表示の値 | S から JWT と表示 cookie を作る | 項目ごとの規則で Experience と Preference から導出し、Display Snapshot として JWT と表示 cookie に載せる |
| Visa sign-in | Z の明示した項目を S に上書き | Preference は書き換えない。Display Snapshot を Experience と Preference から作り直す |
| Visa sign-out | 旧い S を新しい S に写して旧い行を退役 | Experience の値を Preference に写さない。sign-out 後の表示は Preference と既定値から作る（D-55「最後の表示を残す」との関係は要決定） |
| 共有ブラウザ（B に A の値が出る） | 起こり得る | Experience の値は Preference に残らないので、起こらない |
| §9.5（Z が正本、S は写し） | — | **置き換え。** S に写さない |
| §9.6（版の目印、GET での修復） | — | 写しがないので、版の目印は不要になる見込み。表示の作り直しの機会は別に決める |
| §11.4-2（User の保存の結果） | — | User の保存は Experience だけなので、S との競合の問題はなくなる見込み |

### 12.3 案 B で次に決めること

1. **項目ごとの所有と導出の規則。** 各項目（theme、言語、地域、timezone、通貨、日付、時刻、motion、density、件数、同意、通知、Web Push の設定）が Experience / Preference のどちらに属するか（両方に置くか）と、表示の優先順位（例: ログイン中は Experience の明示した値 → Preference → 既定値）。
2. **sign-out の後の表示（要件 D-55 との関係）。** ログイン中に変えた値は Experience にしかないので、sign-out 後は Preference の値に戻る。D-55「最後に使っていた表示をブラウザに残す」を変えるか、sign-out のときに Experience の値を Preference に写す例外を設けるか。
3. **Display Snapshot の作り直しの機会。** ログイン中の保存の直後、sign-in、sign-out、表示 cookie が壊れたとき、古い JWT の復旧（§11.4-3）。GET で書き込まない規則との関係。
4. **ログイン中に「このブラウザだけ」の設定をしたい場合。** 画面で Experience と Preference のどちらに保存するかを選ばせるか、項目で固定するか。
5. **データの移行。** 今の S（ログイン中に写された値を含む）と Z をどう扱うか。migration と既存データの扱いには別の承認が必要。
6. **要件（one.md）の変更。** D-50、D-54〜57 などの改訂が必要になる見込み。どの条項を変えるかを洗い出し、要件の変更として決める。
7. §11.4-3〜9 は引き続き有効（古い JWT の復旧、sign-in 失敗後の表示、通知・同意、Affinity、sign-out とリセット、テスト環境）。

### 12.4 案 B の詳細の決定（2026-11-04、オーナーの選択）

1. **表示の 10 項目**（theme、言語、地域、timezone、通貨、日付、時刻、motion、density、件数）は、Experience と Preference の**両方**に置く。表示の優先順位は、ログイン中は「Experience の明示した値 → Preference → 既定値」、未ログインは「Preference → 既定値」。
   **同意と Web Push の設定（`enabled` / `disabled`）は Preference**、**通知を受けたいという本人の希望は Experience**。ブラウザの通知許可と Push の購読は、外部のブラウザ API の状態として区別し、新しい概念にはしない（§11.2-7）。
2. **sign-out の後は Preference に戻す。** sign-out 後は、そのブラウザの Preference（なければ既定値）で表示する。本人の好みはブラウザに残らない。旧要件 D-55（最後の表示をブラウザに残す）は改める。
3. **Display Snapshot（表示用の JWT と cookie）を作り直す時:** 保存の直後、sign-in、sign-out に加え、Base の GET で JWT や表示 cookie が壊れている・古いとき。作り直しは DB を書かず cookie だけを出し直すので、「GET で DB を書かない」規則と両立する（GET で cookie を発行してよいかは、two.md §4.6 の「Base / Visa だけが cookie を出す」の範囲で扱う）。
4. **ログイン中の保存は常に Experience、未ログインは常に Preference。** 画面で保存先を選ばせない。Guest / User の controller の分け方（§2-1）と一致する。
5. **データの移行は考慮しない。** 本番は未公開で利用者のデータがない前提。開発とテストの DB だけを作り直す。migration と DB の作り直しは、実施の前に改めて承認を得る。本番にデータがあると分かった場合は、この決定を見直す。
6. **要件の正本は five.md。** Preference については five.md を要件の正本とし、one.md には移管の注記だけを書いた（2026-11-04）。

### 12.5 これで閉じた・置き換わった論点

| 論点 | 状態 |
|---|---|
| §9.5（Z が正本、S は写し）、§9.6（版の目印、GET での修復の DB 書き込み） | 置き換え。写しはなくなる |
| §11.4-1（案 A / 案 B） | 案 B で決定 |
| §11.4-2（User の保存の結果） | User の保存は Experience だけ。S との競合はなくなる |
| §11.4-5（通知・同意） | §12.4-1 で決定。同意の対象・範囲・記録の意味の明示は残る |
| §11.4-7 のうち sign-out の Preference | §12.4-2 で決定（Preference に戻す）。sign-out の Affinity、リセットの範囲は残る |
| §8.1 P1-1（共通 writer の形骸化）、P0-1 / P0-4（二重書き込み） | 案 B で解消の見込み |

### 12.6 残っている論点（次に決める）

1. 古い JWT の復旧の経路（§11.4-3）。
2. sign-in で Preference が失敗した後の表示（§11.4-4）。案 B では sign-in で DB を書かず Display Snapshot を作るだけになるので、失敗の範囲は狭くなる。
3. Affinity の記録の契機と範囲（§11.4-6）。
4. sign-out の Affinity と、リセットの範囲（§11.4-7 の残り）。
5. 同意の対象・範囲・記録の意味（§12.4-1 の残り）。
6. 新しい Display Snapshot と JWT の形（Experience と Preference から導出した値を載せる。sign-out 後に Experience の値が JWT に残らないこと）。
7. テスト環境の復旧（実装の前のブロッカー）。

### 12.7 §12.6 への回答（2026-11-04）

1. **古い・壊れた JWT（§12.6-1）。**
   - JWT が壊れている・古いと判断したら、**新しい JWT を発行する**。
   - **GET の場合:** その要求はいったん止め、新しい JWT を発行したうえで、再読み込みしてもらう。
   - **POST などの書き込みの場合:** 書き込みは**拒否**し、新しい JWT を発行したうえで、利用者にもう一度操作してもらう。
   - 解釈（Claude Code、2026-11-04 オーナー確認済み）: 「新しい JWT」の中身は DB を SSOT として作る（§9.2）。署名と realm が正しく、`sub` の行が有効で `jti` だけ古い場合は、その行の今の値から JWT を作り直す。署名不正・別 realm・行がない・退役済みの場合は信頼できる行がないので、初回と同じ扱い（既定値の新しい Preference）になる。これは §9.2 の「既定値で作るのは初回とリセットだけ」の例外ではなく、「信頼できる行がない = 初回」と読む。
2. **sign-in で Preference が失敗した後（§12.6-2）。** 事故が減るなら案 B の形でよい。案 B では sign-in で DB を書かず Display Snapshot を作るだけなので、失敗したら表示を既定値に退避し、認証は完了させる。作り直しは §12.4-3 の Base の GET で行う。
3. **Affinity と 3 単位の分離（§12.6-3）。**
   - Affinity はブラウザ内に保存し、個人情報と紐づかないデータにする（§10.3、§11.2-8 を確認）。
   - **Experience / Affinity / 新しい Preference の 3 つを、ルーティングを含めて別々に再設計する。** 今の「Preference」の名前のもとに 3 つを同居させない。ルート、controller、model、cookie / 保存場所を、単位ごとに分ける。
4. （§12.6-4: sign-out の Affinity とリセットの範囲は未回答。次回）
5. **同意の対象・範囲（§12.6-5）。** オーナーから「Cookie の同意のことか」と質問。→ はい。今の同意は Cookie の同意（`_cookies` の functional / performant / targetable と `_consent_receipts`）。決めることは、その同意が「このブラウザでの Cookie の利用」についてだけ有効か、ブラウザに残った同意が別の利用者にも有効か（ブラウザ単位なら有効になる）、記録（receipt）が何の証跡になるか。
6. **新しい Display Snapshot と JWT の形（§12.6-6）。** 決める（オーナー同意）。
7. **テスト環境の復旧（§12.6-7）。** 大事。**先行する作業を完了させてから**本実装に入る。テスト DB の残骸と構造 dump の復旧は、本実装の前に終わらせる。

### 12.8 残りへの回答（2026-11-04）

1. **sign-out のときの Affinity: 残す。** sign-out は認証情報の破棄で、ブラウザの記憶の消去ではない。
2. **リセット: Affinity / Preference / Experience の 3 つを、すべて別々の操作にする。** それぞれ自分の単位だけを初期化する（Affinity のリセットはブラウザ内の記憶を消すだけで、サーバーには何も残さない）。一括のリセットは用意しない（必要になったら改めて決める）。
3. **ルート: 3 つとも完全に分ける。** Experience、Preference、Affinity をルート・controller で分岐させる。Affinity はサーバーに保存しないので、ルートは画面（例: 記憶の確認・リセットの画面）のためだけに持ち、サーバー側で値を受け取ったり保存したりしない。具体的なパス・namespace・置き場所（Base / Auth）は次に決める。
4. **Cookie の同意: 未決。** オーナー: 「identity と紐づける必要もあるが、セキュリティや EU の GDPR が絡むので難しい」。

#### 12.8.1 Cookie の同意の判断材料（Claude Code。法的な判断ではない。専門家の確認が必要）

- ブラウザに Cookie を置くことへの同意（EU の ePrivacy 指令の考え方）は、端末（ブラウザ）ごとの話。ログインしていない人にも必要なので、Preference（ブラウザ）に置くのは自然。
- 一方、GDPR では、同意に基づく処理について、事業者が「同意を得たこと」を示せる必要があり（Art. 7(1)）、撤回は同意と同じくらい簡単でなければならない（Art. 7(3)）。ログイン中の人については、「誰が、いつ、どの版の説明に、何に同意したか」を本人と結びつけて示せることが求められ得る。
- 両立させる形の候補:
  - **案 C1（ブラウザだけ）:** 同意はブラウザ単位。記録（receipt）は「このブラウザで、いつ、どの版に同意したか」。本人とは結びつけない。単純だが、ログイン中の本人の同意の証跡にはならない。
  - **案 C2（ブラウザ + 本人の記録）:** 有効な同意はブラウザ単位（Preference）のまま。ログイン中に同意・変更・撤回したときは、その出来事を本人（identity）にも記録する（証跡のため。別のブラウザの同意としては使わない）。
  - **案 C3（本人単位）:** ログイン中は本人の同意を正とし、別のブラウザでも有効にする。共有ブラウザや、ログイン前後で同意が変わる場合の扱いが難しい。
- Claude Code の推奨: 案 C2。ただし、本人と結びつけた記録の保存先（zenith か Chronicle か）、保存期間、撤回の扱い、どの処理がどの同意に基づくかの一覧は、法務の確認を前提に決める。

## 13. 用語と単位の整理（2026-11-04）

### 13.1 Affinity の方針の変更（オーナー決定、§10.3 と §12.7-3 を置き換え）

- **Affinity の DB は setting 系に置く**（app / com / org のそれぞれ。`app_setting` / `com_setting` / `org_setting`）。
- **zenith 系（本人）とは紐づけない。**
- **各ブラウザに JWS を置く。** サーバーは、JWS が信頼できる場合（署名・realm・期限・行の有効性が正しい場合）にだけ DB のパラメータを見て、振る舞いを決める。信頼できなければ Affinity はないものとして扱う（通常の画面を出す）。
- 置き換えられた記述: §10.3 の「サーバーの DB に保存しない」「`localStorage` が候補」、§11.2-5 の「Affinity は特定の origin のローカル状態」、§11.2-8 の「サーバーへ送らない」、§12.8-3 の「サーバー側で値を受け取ったり保存したりしない」。
- 引き続き有効: 個人情報と紐づけない、認証・認可の判断に使わない（表示の順番と案内だけ）、失われても通常の操作を続けられる、保存する項目は許可リストで限定する、sign-out で残す、リセットは単独の操作。
- 未決: JWS の cookie の名前と範囲（Domain の共有か host 限定か）、Preference の JWT と同じ鍵か別の鍵か、DB の表の形、保持期間。

### 13.2 3 つの単位（**§14.2 で置き換え**）

| 単位 | 持ち主 | DB | ブラウザ側 | 中身 | 書く人（ルート） |
|---|---|---|---|---|---|
| **Experience** | 本人 | zenith 系（app / org。com にはない） | なし（表示は Display Snapshot で運ぶ） | 表示の 10 項目、通知を受けたいという希望 | User（ログイン中）のルートだけ |
| **Preference** | ブラウザ | setting 系（app / com / org） | `__Secure-preference`（JWT）、`__Host-preference_binding` | 表示の 10 項目、Cookie の同意、Web Push の設定（`enabled` / `disabled`） | Guest（未ログイン）のルートだけ。同意と Web Push はログイン中も書く（下の未決 1） |
| **Affinity** | ブラウザ | setting 系（app / com / org）。zenith とは紐づけない | Affinity の JWS | 前回選んだサインインの方式など（許可リスト） | Affinity のルート |
| （Display Snapshot） | — | 持たない（導出結果） | JWT の `preferences`、`language`、`__Secure-experience` | Experience と Preference から導出した表示の値 | 保存の直後、sign-in、sign-out、Base の GET で作り直す |

### 13.3 未決（用語の整理で見えたもの）

1. **ログイン中の同意と Web Push の保存先。** 同意と Web Push の設定は Preference（ブラウザ）だが、§12.4-4 は「ログイン中の保存は常に Experience」。ログイン中にこの 2 つを変えるときは Preference に書く（例外）か、ログイン中は変えられないようにするか。
2. **Affinity の JWS と Preference の JWT の関係**（§13.1 の未決）。
3. **`__Secure-experience` の名前。** Experience という単位ができたので、Display Snapshot の cookie が `experience` という名前のままだと紛らわしい（§11.2-10 では直ちに変えないとした）。

## 14. 用語の改定（2026-11-04、オーナー決定）: 「Preference」という語を廃止する

### 14.1 決定

- **「Preference」という語は、少なくとも新しい設計では使わない**（誤解の元のため）。今の Preference のほとんどは **Experience** とし、**Affinity** を新しく作り、Cookie の同意には **Consent** という新しい名前をつける。
- §10 と §12〜§13 の「Preference（ブラウザ設定）」は、下の 14.2 の語に読み替える。§0〜§9 と付録T、今のコード（`AppPreference` など）、one.md の「Preference」は、今の実装・旧設計の名前としてそのまま残す（名前の変更は実装で行う）。
- **Experience の 2 つの置き場は guest / user で修飾する。**（2026-11-04 の命名整理で、**Browser Experience**（旧 guest experience）と **Account Experience**（旧 user experience）に改めた。Guest / User は要求の認証状態と書き込み経路の区分として残す。第I部 C2）
  - **guest experience**（現 Browser Experience）**:** setting 系（app / com / org）。ブラウザごと。未ログインの人の表示の設定を保存する。
  - **user experience**（現 Account Experience）**:** zenith 系（app / org）。本人ごと。
- **Web Push の設定（`enabled` / `disabled`）は user experience（本人）に入れる。** 通知を受けたいという希望も user experience。

### 14.2 単位の一覧（§13.2 を置き換え。名称は第I部 C2 で改定: guest experience → Browser Experience、user experience → Account Experience、Consent → Cookie Consent）

| 単位 | 置き場 | DB | ブラウザ側 | 中身 | 書く人 |
|---|---|---|---|---|---|
| **Experience**（guest experience） | ブラウザ | setting 系（app / com / org） | JWT（今の `__Secure-preference`） | 表示の 10 項目 | Guest（未ログイン）のルート |
| **Experience**（user experience） | 本人 | zenith 系（app / org。com にはない） | なし | 表示の 10 項目、通知の希望、Web Push の設定 | User（ログイン中）のルート |
| **Consent** | ブラウザ（§12.8.1 の案で変わり得る） | setting 系（app / com / org） | `__Host-preference_binding`（名前は未定） | Cookie の同意（functional / performant / targetable）と記録 | Consent のルート（ログインの有無にかかわらず） |
| **Affinity** | ブラウザ | setting 系（app / com / org）。zenith とは紐づけない | Affinity の JWS | 前回選んだサインインの方式など（許可リスト） | Affinity のルート |
| （Display Snapshot） | — | 持たない | JWT の表示値、`language`、`__Secure-experience` | 表示の値（ログイン中は user experience → guest experience → 既定値、未ログインは guest experience → 既定値） | 保存の直後、sign-in、sign-out、Base の GET |

### 14.3 この改定で見えた論点（未決）

1. **Consent の語の衝突。** 「consent」は、Apple のソーシャル連携の `consent_revoked`（`client_external_identity.rb`、`client_apple_notification_event.rb`）や、Base の sign-up で同意を集める処理でも使われている。単位の名前は Consent とし、コードでは区別のために `cookie_consent` のような修飾をつけるかを決める。
2. **Web Push が user experience だけになることの影響。**
   - 未ログインの人は Web Push を設定できない。
   - com には user experience がない（認証がない）ので、com では Web Push を設定できない。今の `com_preference_web_pushes` と、要件 D-20（app / com / org に Web Push の項目を追加）との関係を決める。
   - 実際の購読（Push API）はブラウザごとに必要なので、本人の設定が「有効」でも、購読していないブラウザには届かない。
3. **guest / user の修飾とログイン中の表示。** ログイン中も guest experience を表示に使う（user experience に明示した値がない項目）。「guest」の名前でも、ログイン中に読まれることを明記する。
4. **§13.3-1 の解消。** Web Push が user experience になったので、ログイン中に変えるのは自然になった。Consent はログインの有無にかかわらず Consent のルートで書くので、「ログイン中の保存は常に Experience」の例外ではなくなる。
5. **cookie の名前**（`__Secure-preference`、`__Secure-experience`、`__Host-preference_binding`）を新しい語に揃えるか。

## 付録T. two.md からの転記（原文のまま）

two.md の Preference に関係する節を、原文のまま写した。two.md 自体は変更しない。転記元: two.md（SHA-256 `055a2c0141efb60962deac9dc910629eb35a35fa7cdba8a3517c46b9cb7402fb`、2026-11-03 時点）。行番号は転記元の行。本書の §2 の決定と食い違う箇所は §6 に記録し、本文（§0〜§6）を優先する。

### T.1 two.md §1.1 の該当行（l.48-49, 52, 59, 75）

| WU | 段階 | 目的 | 先行 |
|---|---|---|---|
| WU-P0 | 0/設計 | Preference関連ADRの置換案・shapeレビュー | なし。9の詳細実装前に結論 |
| WU-7 | 2a | comの新Preference、JWT/表示/同意binding/Web Push | 6、P0の必要部分 |
| WU-9 | 3 | app/org新Preference、Visa sign-in/out、adoption撤去 | 7/P0、A8本人解決、A2/A9の関連契約 |

### T.2 two.md §2.1 ADRの処理（l.132-150、Preference 以外の行も含む）


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


### T.3 two.md §3.1 の WU-P0 行（l.169-170, 173）

| WU | ファイル/実施内容 | 不変条件・検証・承認 |
|---|---|---|
| P0 | 上記Preference ADR群と`docs/architecture/preference.md`の改訂案。第4.2版への条項別対応を提示 | 既存Acceptedのadoptionを黙って消さず改訂をレビュー。7でcomのみ新方式、9でapp/orgのadoptionを除去 |

### T.4 two.md §3.4 WU-7（l.199-208）


- 改修: `app/controllers/base/com/preferences_base_controller.rb`とpreference/API controller、`preference_{global,transport,base,core,localization,web_cookie_endpoint,web_theme_endpoint,resource_sync}.rb`、`PreferenceIoKeys`/registry、`SecurityJwtPreferenceTokenCodec`、`ComPreference`と子record/option。
- 新規【P】: `app/controllers/concerns/preference_write_boundary.rb`、`app/values/preference_display_value.rb`、`app/values/preference_write_result.rb`、`app/operations/preference_lifecycle_purger.rb`、`app/jobs/preference_lifecycle_job.rb`。controller concernが共通の唯一のDB/cookie書込み入口を持つ。既存動的dispatchをコピーしない。
- §4のschema/JWT/4cookie/GET契約をcomで完成。Base以外のcom readerは公開鍵で読むだけ。秘密鍵のruntime roleによる切替を足さない。
- `__Secure-assurance`、旧項目cookie、Preference refresh/DBSCをcom分岐から削除。app/orgが使う共通分岐は9まで保持し、新旧同じrealmの互換実行は作らない。
- 保存/index/formは既存画面を保つ。screenのdispatchは閉じた列挙と同じ保存メソッドへ。Web Pushのoption/子record追加のみ、配信やsubscriptionは実装しない。R-P-24/26のcom側の再棚卸しを同WU内で行い、§4.3の列単位Before/Afterを承認対象にする。
- 検証: §4全表、realm6方向のうちcom↔app/orgの受理拒否、same-TLD reader、GET先読みでDB0、書込み不正JWTでdefaults新行、**resetの旧行退役＋新行作成**、D-57 cookie tossing、400日期限。DB構築/鍵配布の実施は別途承認。
- docs: Preference architecture、transport capability、option ADR、schemaと状態図。migrationの列変更/データ破棄は§3.0の実行票。

### T.5 two.md §3.12 WU-9（l.272-281）


- 7の方式をAppPreference/OrgPreference/ClientPreference/OperatorPreferenceへ展開。`Visa::{App,Org}::AuthorizationBaseController`とlogout確定処理が§4の**同じconcernメソッド**を呼ぶ。
- sign-inは本人明示項目だけをaccount→匿名行へ、sign-upも既存handoff→同じVisa経路。sign-outは旧匿名行の表示/同意/Web Push/bindingを新匿名行へ写す。cookieからDBへのコピーは禁止。
- Base本人resolver/操作認可はA8の完成契約を使う。account値をrequest actor_idやcookie subから選ばない。
- `PreferenceAdoption`と旧refresh/DBSC/assuranceとitem cookie群、actor同意mirrorを撤去。`adult_content_gate`のモデル層外参照/registry/stopperをまとめて外す。モデル/option/子表の休眠は維持。
- explicit metadataを新しい一方向保存/反映に使用し、saveで送られていない項目をaccountへ埋めない。地域だけ固定4項目を伴う。地域そのものをVisa sign-inで匿名行へ反映することはしない（D-50）。
- R-P-24/26のapp/orgのlegacy class・table・NULL状態/nullable booleanを各実ファイル/列で再棚卸しし、Sharedとactor-localの正規の子recordだけを残す。D-27の休眠modelと他realmの参照表は誤削除しない。実表/NULL列とAfterは付録S、migrationは§12.8のshapeレビュー対象。
- §4の失敗表/同時保存/retire/response順/D-57、**resetでの旧匿名行退役・本人設定退役・共有3cookie再発行と旧binding cookie破棄**、AC-20b〜37/49/52を3realmで閉じる。migration/既存値の消去はapproval票。新方式のADR/diagram/checklistを同時更新。

### T.6 two.md §4 Preferenceの横断詳細設計（l.289-428）


#### 4.1 所有・Cookie・署名

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

#### 4.2 shape（実装前レビュー対象）

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

#### 4.3 DBのBefore/After

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

#### 4.4 共通write入口（D-54/AC-24）

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

#### 4.5 項目別の書込みと取得元

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

#### 4.6 GET/HEAD、Actor.preferences、設定form

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

#### 4.7 同意/Web Pushのbrowser binding

BaseはJWTの署名・realm・期限を検証した後、当該`sub`のsetting行の**active状態**を確認し、`__Host-preference_binding`のdigestをconstant-timeで照合する。署名済みJWTだけで同意・Web Pushを肯定しない。表示用には古いjtiを期限まで許すが、退役行のbindingは有効な同意として使わない。
一致する場合だけDB同意/Web Pushが有効。不一致/欠損ならno consent/disabledとして返し、GETで行/bindingを変えない。
保存はBase自身のCSRF付き操作で、新規なら乱数を生成してdigestを行へ保存。既存cookieが形式正しければ同じ値をそのブラウザの明示操作で新しい対象rowへ結び直せる。
Domain JWTの差込みだけではbindingを更新しない。JS/兄弟hostがbinding cookieを発行できる経路を作らない。
Visa sign-outは旧rowの同意/Web Pushとbinding recordを新rowへ一体copy。Base cookieは変更しない。
Base以外では常に同意なし/Web Push disabled。バナーは「設定はBaseで確認」のリンクだけで、同意済み表示や第三者送信を有効にしない。scope外の通知配信を実装しない。

#### 4.8 保存・sign-out・resetの障害応答

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

#### 4.9 寿命・purge・鍵rotation

- `now < exp`を有効、`now == exp`は失効とする。GET/HEADはjti/exp/DB最終利用時刻を更新しない。
- 【P】Preference rowのpurge猶予は最終発行exp＋30日。retired行も最後に発行したJWTの期限＋30日まで保持。既存hold/監査参照があれば削除しない。
- purgeはowner DB時計で期限を再確認し、子→親を同一DB transactionで削除、batch200。expiry直前/一致/直後、hold、並行save/sign-out、途中rollbackを公開jobから試す。実測件数/回復と別途承認が必要。
- 通常鍵rotation: 新公開鍵をreader全体へ先配布→新kid署名へ切替→旧exp最長400日＋時計差期間を過ぎて旧鍵撤去。事故時は旧kidを即拒否してrealm内の再作成を受容。
- kid拒否の設定は既存デプロイ経路で全readerへ適用し、鍵本体/tokenをログへ出さない。private keyが取得不能なら新cookieを出さない。
- public keys・issuer・audience・active kid・失効kid集合は必須設定。起動時に欠落を明示しコード側の既定値を作らない。実環境の鍵供給方式は§11。

### T.7 two.md §12.5 Visaの既存POSTへPreference確定を接続する（l.1168-1190）


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

### T.8 two.md §12.7 Preference writer、鍵、readerの確定事項（l.1209-1219）


- 共通concernはsurface分岐を所有しない。concrete Base/Visa controllerが静的なrealm用model/codec/許可operationのcontextを渡す。共通メソッドは閉じたoperation caseとtransaction/cookie順だけを所有する。registryのconstantize/動的send/role fallbackを新設しない。
- Anonymous更新はrow lock下でactive/jti/expを再検証し、毎回新jti。account saveは項目子record/explicitを同じZ transactionで更新し、Z commit後にSへ反映。別requestのZ更新の後で古いsnapshotがSへ来ることによる表示ずれは許すが、S→Zへの上書き復旧はしない。
- 署名は既存JWT鍵設定の仕組みにrealm別`preference_app`/`preference_org`/`preference_com`の独立issuer namespaceを追加し、既存OP tokenの鍵と混ぜない。algorithmはES384固定、active kid一つ、public trust storeはactive＋移行中の旧kid。秘密鍵の値はリポジトリに置かず既存の管理された秘密設定から供給する。新KMSネットワークAPIは追加しない。秘密鍵利用メソッドのcallerは共通writerのみ、他hostはpublic key lookupだけとする。同一Ruby processのコード実行侵害に対する鍵隔離を、この論理境界だけで保証するとは主張しない。
- kid/issuerをrequestから秘密設定の任意pathへ変換しない。realmの固定表で選ぶ。鍵不足はboot/利用境界の明示error、別realm/旧共通鍵へfallbackしない。reader用配布は公開鍵の固定bundleで、公開JWKS endpointを新設しない。
- rotationはreaderに新公開鍵を先配布→writerのactive kid切替→最終旧発行expまで旧公開鍵保持→削除。漏えいkidの拒否は別途承認して即時無効化、GETでDB作成しない。400日readを約束する通常rotationと緊急失効を区別する。
- AC-24/26の旧文はone.md末尾のD-54/55読み替え注記に従い、readerのSet-Cookieは発行/削除とも0、Base/Visaだけ無効共有cookieを削除する。これは最新writer限定を守る設計解釈としてレビューに提示する。オーナーが全reader削除を要求する場合は衝突を報告し、一方を黙って弱めない。

**テスト:** realm鍵6方向、kid未知/拒否/旧/新、iat/exp境界、同名Cookie重複、3KiB直前/一致/超過、S commit前署名失敗、Z commit後S失敗、cookie3枚の部分未達、host-only binding差替え/欠損、別account signin、reset/signout同時保存。clock/leewayはPreferenceの`now < exp`を緩めない。

### T.9 two.md §12.8 実行票、migration、完了の判定（l.1220-1234、Preference 以外の行も含む）


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

### T.10 two.md 付録S Preferenceの実表・NULL列・migration差分（l.2250-末尾）


以下の【事実】は基準commitの生成structure.sqlを静的に読んだもので、DBの実行件数ではない。表の存在・列型・NOT NULLを事実として記し、維持/撤去/変更は【設計P】として分ける。生成SQLを手編集せず新migrationで変更する。

#### S.1 親/同意列のBefore/After

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

#### S.2 基準の全Preference表とNULL列

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

#### S.3 旧class/橋渡しの判定

`plans/backlog/legacy-preference-models-retirement-plan.md`の旧User/Staff/Customerや約70classという数値は現在の実装事実に使わない。現在のClient/OperatorとShared App/Org/ComをS.2に対応付け、actorのassociation名/旧user/staff foreign keyはmigrationとcaller更新を同時に行う。橋渡しは実在class/tableと読取りがある場合だけ撤去対象にし、過去文書にあるという理由で架空migrationを作らない。Chronicle/auditの履歴はこの表の外で保持する。com actor-localはWU-4/5の撤去範囲で、ComPreferenceはWU-7で再設計する。

S.2はDDLの棚卸しを完了した表であり、既存データの全行数/NULL実件数/移行の安全性を測ったものではない。削除対象の実数と回復票は§12.8で取得する。承認済みD-12を理由にデータ削除の実行承認を省略しない。
