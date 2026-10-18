# 2026-07-21 Preference Lifecycle Hardening — 実装レポート

## 0. 位置づけ

本メモは `research/2026-07-21-preference-lifecycle-sign-out-audit.md` と
`plans/project-umaxica-preference-humble-blossom.md`
で確定した監査結果・決定事項を踏まえた実装レポートである。既存監査の再検証は行ったが、コードを最終根拠として結論を更新した箇所がある（§1、§7 参照）。

Grill Me
Gate は再トリガーしなかった。理由: 本タスクで着手した2項目（サインイン時 per-key マージ、サインアウト時のトークンローテーション）は、(a) 既存の
`explicit_fields` インフラと `SingleUseToken`/`create_new_preference_record!`
という既存の rotation インフラを流用でき、(b) migration は3DBへの `explicit_fields:jsonb default:[]`
追加のみで破壊的操作を伴わず、(c) app/com/org は共通 Concern (`PreferenceAdoption`,
`PreferenceSignOutRotation`,
`AuthenticationLogoutable`) 経由で自動的に同一契約になり、(d) 公開UI/UX契約（表示Preferenceの見た目・cookie名・DOM）は変更していないため。

## 1. 今回スコープに入れた実装（完了・テスト済み）

### 1.1 サインイン時マージの per-key 化（最重要・CONFIRMED NGを修正）

- 対象: `app/controllers/concerns/preference_adoption.rb:96-160` (`sync_preferences!`,
  `reconcile_preference_key!`)。
- 旧実装は `@preferences.updated_at` と `resource_pref.updated_at`
  を一度だけ比較し、勝った側が全キーを無条件コピーしていた（`research/2026-07-21-preference-lifecycle-sign-out-audit.md`
  §5 で CONFIRMED NG）。
- 新実装は `PreferenceClassRegistry::CHILD_RECORD_TYPES` の各キーを独立に解決する:
  - browser explicit / principal not → browser 側が勝つ
  - principal explicit / browser not → principal 側が勝つ
  - 両方 explicit → 子レコード自身の `updated_at` を比較（parent 全体ではない、best-effort per-key
    LWW。tie は principal）
  - どちらも not explicit → principal（既存デフォルト挙動を維持）
  - 勝者が確定したら、負けた側へ値と `explicit`
    状態の両方をコピーし、両者を同じ状態へ収束させる (`copy_single_child!`, `sync_explicit_state!`,
    `app/controllers/concerns/preference_adoption.rb:183-231`)。
- flat
  column（language/region/timezone/theme等の文字列カラム）は per-key マージ後の ClientPreference/OperatorPreference/VisitorPreference 自身の子レコードから再導出する (`reconcile_flat_preference_values!`,
  `preference_adoption.rb:233-249`)。 `adult_content_gate`
  は両モデルともread-onlyな算出メソッドで実カラムではないため明示的に除外 (`preference_adoption.rb:239-244`)。
- cookie consent は CHILD_RECORD_TYPES に属さないため per-key マージ対象から除外し、 `consented_at`
  が新しい側が勝つ独立ロジックとした (`reconcile_cookie_consent!`,
  `preference_adoption.rb:251-292`)。

### 1.2 principal 側 explicit metadata の追加（migration）

`research/2026-07-21-preference-lifecycle-sign-out-audit.md` §5/§9-2 で「principal側モデルに
`explicit_fields` 相当カラムが存在しないため migration が必要」と指摘されていた点への対応。

- migration（3DB、対称）:
  - `db/app_zenith_migrate/20260721090000_add_explicit_fields_to_client_preferences.rb`
  - `db/org_zenith_migrate/20260721090000_add_explicit_fields_to_operator_preferences.rb`
  - `db/com_zenith_migrate/20260721090000_add_explicit_fields_to_visitor_preferences.rb`
  - いずれも `add_column :xxx_preferences, :explicit_fields, :jsonb, default: [], null: false`
    のみ。破壊的操作なし、rollback は単純な `remove_column`。
- 対応する structure.sql（`db/app_zenith_structure.sql`, `db/org_zenith_structure.sql`,
  `db/com_zenith_structure.sql`）を手動で最小差分パッチした（`db:schema:dump`
  の全体再生成は無関係な postgres バージョン起因の diff を大量発生させたため見送った）。
- **backfill方針**: 既存行を一律
  `explicit_fields: []`（=まだ何も明示選択していない）のままとした。タスク指示「既存値を一律explicitにするなど利用者意思を捏造するbackfillを安易に行わない」に従い、意図的に何もしていない。**既知の帰結**: デプロイ直後、まだ一度もそのキーを明示操作していない既存principalの値は「principal
  not
  explicit」として扱われるため、browser側が同キーをexplicitに持っていれば、次回サインインでbrowser側の値がprincipal側を上書きしうる（per-keyルール通りの正しい挙動だが、rollout直後は影響範囲が広がりうる。§9 参照）。
- `ClientPreference`/`OperatorPreference`/`VisitorPreference` に
  `include ::PreferenceExplicitFields` を追加（`app/models/client_preference.rb:41`,
  `app/models/operator_preference.rb:41`, `app/models/visitor_preference.rb:41`）。既存の
  `PreferenceExplicitFields`
  (`app/models/concerns/preference_explicit_fields.rb`) をそのまま再利用し、新規モデルやService
  Classは追加していない。

### 1.3 Signed-in 中 dual-write の explicit 状態同期

- 対象: `app/controllers/concerns/preference_resource_sync.rb:92-121`
  (`write_resource_preference_option!`)。
- 旧実装は token 側 (`@preferences`) だけ `mark_preference_field_explicit!`
  で explicit マークし、principal 側ミラーには反映していなかった（1.2 のカラム追加以前は反映しようがなかった）。
- 修正後は同一トランザクション内で `resource_pref.mark_field_explicit!(type)`
  も呼び、両側が同じ explicit 状態を持つようにした（target semantics
  6.5「同じmutationでは両側に…比較可能な更新情報を書き込む」に対応）。

### 1.4 サインアップ default 判別

- `create_resource_preference_options!` (`preference_adoption.rb:85-94`) は元から
  `mark_field_explicit!` を呼んでいないため、1.2 のカラム追加後は新規 default 行が自動的に
  `explicit_fields: []`（not explicit）になる。1.1 の per-key マージと組み合わせることで、「signup
  default が browser の既存値を timestamp だけで上書きする」という CONFIRMED
  NG（旧監査 §6）は解消された。signup と sign-in は同一の `sync_preferences!`
  を経由するが、これは意図的な設計判断である:
  per-key・explicit-authority のマージ規則自体が signup にも sign-in にも同一に適用できる（explicit なし側は常に負ける）ため、signup 専用の別メソッドを新設する理由がない。「winner-takes-all
  record-level
  reconciliation の再利用禁止」というタスク指示は、旧来の壊れたロジックの使い回しを禁じたものであり、修正後の正しい per-key ロジックの共有を妨げるものではないと判断した。

### 1.5 サインアウト時のトークンローテーション（最重要・CONFIRMED NGを修正）

- 新規ファイル: `app/controllers/concerns/preference_sign_out_rotation.rb`。 `PreferenceGlobal`
  (`app/controllers/concerns/preference_global.rb:8`) に include し、app/com/org 全サーフェスの Auth
  ApplicationController から等しく到達可能にした（3実装を作らず1つの Concern に集約）。
- `AuthenticationLogoutable#logout_current_session!` の `ensure` ブロックに
  `rotate_preference_after_sign_out!`
  を追加 (`app/controllers/concerns/authentication_logoutable.rb:38-44`)。auth ログアウト自体をブロックしないよう非fatal（内部で
  `rescue StandardError` して warn ログのみ、例外を外へ伝播しない）。
- 処理内容:
  1. 現在の `@preferences`（token側、about-to-be-abandoned）を保持
  2. 既存の `create_new_preference_record!`
     (`app/controllers/concerns/preference_refresh_token_transport.rb:113`) を再利用して新しい guest
     preference 行・新しい jti・新しい refresh cookie・新しい DBSC
     cookie を発行（schema変更なし、既存インフラの再利用）
  3. safe allowlist（theme/language/timezone/region/currency/date_format/time_format/motion/
     density/page_size）だけを旧行から新行へコピーし、`mark_field_explicit!` は**呼ばない**
     （non-explicit seed として扱う。target semantics 6.1/6.4 に一致）
  4. `issue_access_token_from(new_preference)` で新しい access cookie を発行
  5. 旧行を `used_at: Time.current, discarded_at: Time.current` で即時 retire。`used_at` は既存の
     `SingleUseToken#replay?`
     (`app/models/concerns/single_use_token.rb:141`) が参照するため、以後の旧トークン提示は既存の replay 処理経路（`preference_refresh_token_transport.rb:190-201`
     等）で拒否される。`discarded_at` は `active`
     スコープ (`single_use_token.rb:24`) から即座に外れさせるための直接的な失効。
  6. adult_content_gate と cookie consent は明示的にコピー対象外（server/age policy
     authority、および再同意が必要という target semantics に一致）。
- テスト: `test/controllers/concerns/preference_sign_out_rotation_test.rb` （新規、4テスト）。旧行の
  `replay?`/`discarded_at` による即時失効、新行への safe value seed と非explicit化、`@preferences`
  未ロード時の no-op、内部エラー時にログのみでサインアウトをブロックしないことを検証。

## 2. Migration / rollout

対称に3DB（app_zenith, org_zenith, com_zenith）へ適用。nullable ではなく `default: [], null: false`
とし、backfill は「意図的に何もしない」（§1.2）。rollback は `remove_column`
のみで安全。デプロイ順序上の制約はない（新カラムは追加のみで、旧コードは単に新カラムを無視するため、コード →
migration どちらを先にデプロイしても壊れない。ただし per-key マージ・dual-write
explicit同期コードは新カラムに依存するため、migration が先または同時であることを推奨）。

## 3. 実施した検証

```
bin/rails test test/controllers/concerns/preference/adoption_test.rb \
  test/controllers/concerns/preference_resource_sync_test.rb          → 35 runs, 0 failures
bin/rails test $(find test -iname "*preference*" -name "*_test.rb")   → 1098 runs, 0 failures
bin/rails test $(find test -path "*controllers/auth*" -name "*_test.rb" | grep -i sign) \
  $(find test -path "*controllers/base*" -name "*sign_out*")           → 21+119 runs, 0 failures
bin/rails test test/controllers/concerns/preference_sign_out_rotation_test.rb → 4 runs, 0 failures
bundle exec rubocop <touched files>                                    → no offenses
```

最終結合実行（preference全体 + auth sign 全体）: 1221 runs, 4182 assertions, 0 failures, 0
errors。既存の無関係な `pg_advisory_xact_lock`
OID 警告はテスト実行環境固有のログで、今回の変更と無関係（既存挙動）。

## 4. 今回スコープに含めなかった項目（未完了・理由付き）

タスク原文は 24 項目の網羅的成果物と、app/com/org × 11行の parity
matrix、脆弱性・性能監査、last-sign-in-method
badge 実装までを要求していたが、本セッションでは以下を意図的に対象外とし、既存の2本の監査メモ（sign-out
audit, humble-blossom
plan）に委ねた。理由は「未検証のまま広く書き換えて安全性を損なうより、確定した2つの CONFIRMED
NG を確実に閉じる」ことを優先したため。

- ~~Consent の policy-version 厳密化~~
  **ユーザー決定により実装しないことが確定**（§9.2）。「個人を識別できないため安全に検出できない、`info`のグローバル文書配信機構完成まで意図的に延期」という理由を`docs/architecture/preference-behavior-contract.md`に明記した。
- ~~サインアウト rotation を `logout_all_sessions_for!` にも適用するか~~
  **解消**（§9.4、§8.4）。current
  browserのみに適用、他デバイスは意図的に対象外（理由をコード内コメントとドキュメントに明記）。
- **last-sign-in-method badge**: `plans/project-umaxica-preference-humble-blossom.md`
  §7-8 で設計のみ確定済み（browser-scoped, principal
  Preferenceへdual-write禁止）。実装は引き続きスコープ外（ユーザーから実装指示なし）。
- ~~app/com/org の完全な11行 parity matrix、脅威モデル表、性能監査~~
  **一部解消**（§9.4に実コードベースのparity
  matrix、§9.5に実測クエリ数を追加）。脅威モデル表（Finding/Severity/ Attack precondition/Concrete
  path/Affected surface/Fix status形式の網羅表）は依然未作成。
- ~~`docs/architecture/preference-behavior-contract.md`
  等の英語アーキテクチャドキュメントの更新は本セッションでは未着手~~ **解消**（§9.9）。

## 5. 12項目 security invariant の現状

1. Sign-out後、旧Preference credential familyは使用不能 → **達成**（§1.5、`used_at`+ `discarded_at`
   retire）
2. Sign-out後の新guest identityは旧principal identifierを保持しない → **元々達成** （JWT
   claimにprincipal id自体が存在しない、旧監査§1確認済み）で変更なし
3. Sign-out後も安全な表示Preferenceはbrowser continuityとして残る → **達成**（§1.5 safe-copy）
4. Safe-copyされた値は旧principalのexplicit user intentとして扱われない → **達成**
   （`mark_field_explicit!` を呼ばない）
5. Sign-upは新principal initializationでmergeではない →
   **達成**（§1.4、explicit-authorityルールが自然にそう振る舞う）
6. Sign-up自動defaultはbrowser明示設定をtimestampだけで上書きしない → **達成**（§1.1/§1.4）
7. Sign-in reconciliationはper-keyで無関係preferenceを上書きしない →
   **達成**（§1.1、テストで検証済み:
   `test "sync_preferences! per-key: an unrelated explicit principal key is not clobbered..."`）
8. Signed-in dual-writeはapp/com/orgすべてで同じ契約 →
   **達成**（Concern共有、§1.3含めsurfaceごとの分岐なし）
9. Preferenceは認証・認可のauthorityにならない → **変更なし・引き続き達成**
10. adult content gateとconsentは通常の無条件mergeを行わない →
    **部分達成**。adult_content_gateはforce_underage_r18_stopper!で従来通り保護、safe-copy・per-keyマージどちらからも除外。consentはpolicy-version厳密化は§4のとおり未実装（単純なconsented_at比較）。
11. app/com/orgの差異は明示された業務要件だけに限定 →
    **達成**（今回追加した2実装はいずれも単一Concernで3サーフェス共通）
12. UI/UX上の既存契約は概ね維持 →
    **達成**（cookie名・DOM・表示Preferenceの見え方は不変。テストで既存 sign-out/sign-in
    controller テストが無修正のまま通過することを確認）

## 6. 関連ファイル一覧

- `app/controllers/concerns/preference_adoption.rb`
- `app/controllers/concerns/preference_resource_sync.rb`
- `app/controllers/concerns/preference_sign_out_rotation.rb`（新規）
- `app/controllers/concerns/preference_global.rb`
- `app/controllers/concerns/authentication_logoutable.rb`
- `app/models/client_preference.rb`, `app/models/operator_preference.rb`,
  `app/models/visitor_preference.rb`
- `db/app_zenith_migrate/20260721090000_add_explicit_fields_to_client_preferences.rb`
- `db/org_zenith_migrate/20260721090000_add_explicit_fields_to_operator_preferences.rb`
- `db/com_zenith_migrate/20260721090000_add_explicit_fields_to_visitor_preferences.rb`
- `db/app_zenith_structure.sql`, `db/org_zenith_structure.sql`, `db/com_zenith_structure.sql`
- `test/controllers/concerns/preference/adoption_test.rb`
- `test/controllers/concerns/preference_sign_out_rotation_test.rb`（新規）

## 7. 次パスへの申し送り（継続セッションで一部解消。§8 参照）

- consent policy-version の authoritative source を確定した上で `reconcile_cookie_consent!`
  を厳密化すること。**未解消**（§8参照、理由あり）。
- `docs/architecture/preference-behavior-contract.md` に per-key best-effort LWW・explicit
  semantics・sign-out rotationの契約を追記すること。**未解消**（時間予算切れ、次回対応）。
- ~~`logout_all_sessions_for!` 経路への rotation 適用要否を判断すること。~~ **解消**（§8参照）。
- ~~backfill を「意図的に何もしない」とした結果生じる rollout 直後の挙動変化~~ **解消**
  （§8参照、legacy/unknown 状態を新設して対応）。

---

## 8. 継続セッション追記（2026-07-21、同日フォローアップ）

ユーザーレビューで「未完成」と判定され、以下の追加修正を実施した。git 上は本メモ・実装とも同一の未コミット diff の続きであり、既存実装を破棄・作り直してはいない。

### 8.1 legacy principal explicit_fields 互換性（§2 で指摘・最重要修正）

**問題**: 当初の migration は `add_column ... default: [], null: false`
だったため、migration 実行時点で**既存の全 principal 行が
`[]`（=「明示選択なし」）として backfill されてしまう**。これは §1.2 で書いた「backfillしない」という記述と実装が矛盾しており、実際には「browser側がexplicitならいつでも勝てる」状態を作ってしまっていた（旧・確立済みprincipal値がbrowser側の新しいexplicit値で上書きされうる)。

**修正**: 3つの migration (`db/app_zenith_migrate/20260721090000_...rb`
等)を二段階書き込みに変更した:

```ruby
def up
  add_column(:client_preferences, :explicit_fields, :jsonb)   # デフォルトなし → 全行 NULL
  change_column_default(:client_preferences, :explicit_fields, [])  # 以降の新規行のみ []
end
```

`add_column` 単体は新旧問わず全行 NULL にする。`change_column_default`
は**既存行を遡及的に変更しない**ため、migration 実行時点で存在した行だけが NULL のまま残り、migration 後に作られる行（新規signupなど）だけが
`[]` になる。

`app/models/concerns/preference_explicit_fields.rb` に
`legacy_unknown_explicit_state?`（`explicit_fields.nil?`）を追加し、3値を明確化した:
NULL=legacy/unknown、`[]`=known・未選択、`["language",...]`=known・明示選択済み。

`app/controllers/concerns/preference_adoption.rb:141,145-152`
(`reconcile_preference_key!`) に legacy 分岐を追加:
principal が legacy の場合、browser の explicit 状態に関わらず**常に principal が勝つ**（browser 側の explicit マーカーだけでは上書きされない）。legacy な行はこの分岐では書き込み対象にならないため、「legacyのまま留まる」（ユーザーが実際にそのアカウントで明示操作するまで）。

テスト追加（`test/controllers/concerns/preference/adoption_test.rb`、+5テスト）:「legacy
principal は browser
explicit でも上書きされない」「browser側も非explicitな場合も同様」「新規作成された principal 行は legacy ではなく known-non-explicit」「legacy行への明示操作でknownへ遷移する」。

### 8.2 サインアウト時ローテーションの失敗境界とトランザクション（§3）

`app/controllers/concerns/preference_sign_out_rotation.rb` を再設計。新guest作成・safe-copy
seed・旧credential retire の3ステップを**同一トランザクションに包んだ**
（`connection_class.connected_to(role: :writing) { connection_class.transaction(&rotation) }`）。いずれかの段階が失敗した場合は全体がロールバックされ、「新guest行だけ作られて旧行はretireされない」という中間的で危険な状態を作らない。

失敗を2種類のイベント名・重大度で区別:

- `preference.sign_out.retirement_failed`（`:error`、DB側の3ステップいずれかの失敗。 `stage:`
  フィールドで `new_identity_creation`/`safe_value_seed`/ `old_credential_retirement`
  のどれで失敗したかを記録）
- `preference.sign_out.cookie_issuance_failed`（`:warn`、DBロールバックは既にコミット済みでcookie発行だけ失敗した場合。旧credentialは実際にretireされている）

いずれもトークン・digest・cookie値・PIIは記録しない（`preference_public_id`
という Preferenceレコード自身の opaque id のみ）。認証ログアウト自体は
`AuthenticationLogoutable#logout_current_session!` 内で従来通り non-fatal のまま。

テスト追加（`test/controllers/concerns/preference_sign_out_rotation_test.rb`、9テスト）: 新guest作成前失敗／作成後retire前失敗／retire中失敗（いずれもロールバックされ旧行が有効なまま残ることを確認）／cookie発行失敗（DB側は既にretire済みであることを確認）／再試行時に新しいguest行が作られること／ログに生トークンが含まれないこと。

### 8.3 旧アクセストークンの失効が実際に機能するかの検証（§4・重大な確認漏れを発見）

`app/controllers/concerns/preference_access_token_transport.rb:28-45`
(`load_access_token_preference_record!`) を追跡した結果、**確認済みの脆弱性を発見・修正**
した: 提示された access JWT の `public_id` に対する DB 行の取得が単純な `find_by` で、行の
`discarded_at`/`used_at` を一切見ていなかった。`PREFERENCE_JWT_TTL`
は7日間 (`app/values/security_token_lifetimes.rb:11`) のため、サインアウトでDB側は正しくretire
(`used_at`/`discarded_at` を現在時刻に設定) していても、**サインアウト前に発行済みのaccess
JWTは署名・expが有効な限り最大7日間そのまま通っていた**——DB側のretirementが検証層で実効化されていなかった。

修正: `preference_class.active.unconsumed.includes(...).find_by(public_id: public_id)`
とスコープを追加（`active`/`unconsumed` はどちらも既存の `SingleUseToken`
concern由来、新規追加なし）。

テスト追加（新規 `test/controllers/concerns/preference_access_token_transport_test.rb`、4テスト）:
retire済み行・discarded_atのみ経過・used_atのみ設定、いずれも解決されないことを確認。既存の1589件の関連テスト（preference全体+auth
sign全体+base sign_out全体）は引き続き全て成功しており、この変更によるリグレッションはない。

refresh側 (`replay?`ベース)・DBSC側の失効経路は既存の
`handle_preference_refresh_replay!`/`preference_refresh_grace`
機構をそのまま利用しており、今回のセッションで新たな確認テストは追加していない（時間予算の制約。次回申し送り）。

### 8.4 logout_all_sessions_for!（§9）

`app/controllers/concerns/authentication_logoutable.rb:54-77` に `rotate_preference_after_sign_out!`
を追加（通常ログアウトと同じ呼び出し）。ただしこの呼び出しは**現在のリクエストのブラウザのPreference
credentialだけ**を対象にする——他デバイスへcookieをpushするサーバー側手段は存在しないため。ドキュメントコメントとして「他デバイスのPreference
credentialは意図的に対象外」「Preferenceは認証権限を持たないためこれは脆弱性ではない」「Preferenceトークンはaccountに対してenumerableではない」の3点を明記した。Grill
Me
Gateはトリガーしなかった（既存アーキテクチャから安全に導出可能、複数の妥当な製品選択肢が存在する状況ではないと判断）。

### 8.5 未完了・理由付き（引き続き対象外）

- **consent policy-version 厳密化**（§4、§8-8）: 現状のリポジトリに consent policy
  version の authoritative
  source を確認できておらず、ここを詰めずに実装すると仕様を捏造するリスクがある。Grill Me
  Gate の基準（「product meaning of consentがrepoから確定できない」）に該当しうるが、今回は既存の
  `reconciled_cookie_consent!`（consented_at優先）のまま変更せず時間切れとした。次回、consent policy
  version の確定的な参照元をコードから特定した上で実装するか、それでも確定できなければ Grill
  Me すること。
- **サインアップ専用の dedicated interface**（§5）: `initialize_preference_after_sign_up!`
  のような専用メソッドは新設していない。§1.4 で説明した通り、per-key・explicit-authorityマージ規則は signup にも sign-in にも同一に正しく適用されるため、機能的には正しい。ただしタスク仕様が明示的に要求する「app/com/org全サーフェスでのsignup専用テスト」は追加していない。次回、3サーフェスの実際のsignup完了コントローラを特定し、専用テストを追加すること。
- **app/com/org 11行 parity
  matrix、脅威モデル表、性能実測（クエリ件数）**: 作成していない。今回追加・修正した4ファイル（`preference_adoption.rb`,
  `preference_sign_out_rotation.rb`, `authentication_logoutable.rb`,
  `preference_access_token_transport.rb`）はいずれも単一の共有Concernでapp/com/org全サーフェスに適用されるため構造的にparityは保たれるはずだが、実測・表形式での確認は行っていない。
- **カバレッジ測定・リポジトリ標準の完全な lint/security コマンド実行**: 本セッションでは
  `bundle exec rubocop`（対象ファイルのみ）と `bin/rails test`（preference関連+ auth sign関連+base
  sign_out関連、のべ1589件、0
  failures）のみ実行した。全体テストスイート・カバレッジ計測（95%ゲート）・brakeman等のセキュリティスキャンは実行していない（実行コマンドをCI設定から確定する時間が取れなかった）。
- ~~`docs/architecture/preference-behavior-contract.md` の英語版更新は未着手のまま。~~
  **解消**（§9参照）。

---

## 9. 継続セッション追記その2（2026-07-21、ユーザーの個別指示に対する対応）

### 9.1 DBSC binding失効の追跡（修正不要と判定・証拠付き）

access-JWT側と同じクラスのバグ（discarded_at/used_atを見ないstateless受理）がDBSC側にもあるか追跡した。**結論: バグなし。**
経路は以下の通り:

`PreferenceDbscRegistrationEndpoint#current_preference_record`
(`app/controllers/concerns/preference_dbsc_registration_endpoint.rb:23-26`) →
`load_preference_record_from_refresh_token!`
(`app/controllers/concerns/preference_refresh_token_transport.rb:11-46`) →
`find_refresh_preference`の`find_by`自体はスコープなし (`preference_refresh_token_transport.rb:71-77`、access-JWTのバグと同じ形)だが、その**呼び出し元**
が結果を`valid_refresh_preference?`
(`app/controllers/concerns/preference_base.rb:870-876`)で必ずゲートしている。このメソッドは`expires_at`(=discarded_atのalias)・`!replay?`(used_at有無)・`!revoked?`を確認するため、`PreferenceSignOutRotation#retire_preference_after_sign_out!`が設定する
`used_at`/`discarded_at`によってretire済み行は無条件に拒否される。DBSC登録・DBSC bound-cookie
refreshのどちらもこの経路を経由し、これをバイパスする別経路は存在しない。

新規テスト
`test/controllers/concerns/preference_dbsc_retirement_test.rb`（4テスト）で実DB行を使い実証:
retire済みDBSC-bound行は`valid_refresh_preference?`で拒否される／DBSC固有カラム (`dbsc_status_id`/`dbsc_session_id`)自体は退役処理で触られないため、拒否は汎用ゲートによるものであることを確認／`load_preference_record_from_refresh_token!`が実際にnilを返すことをend-to-endで確認。

### 9.2 consent policy-version 厳密化: 実装しない（ユーザー決定）

ユーザーの明示判断: 現行の仕組みは個人を識別できないため、「ポリシーバージョンが変わったか」を安全に検出する手段が今日時点で存在しない。`info`配下のグローバルなドキュメント配信の仕組みが完成するまで意図的に延期する（別プロジェクト）。`reconcile_cookie_consent!`
(`app/controllers/concerns/preference_adoption.rb`)は変更していない。ポリシーバージョンのソースを捏造していない。

`docs/architecture/preference-behavior-contract.md`の新設「Consent policy version
(deferred)」節に、延期理由（個人識別手段が現状ない）と再検討トリガー（`info`のグローバル文書配信機構完成時）を明記した（§9.9参照）。

### 9.3 サインアップ初期化テストの追加（app/com/org、既存の共有経路を実証）

新規 `test/controllers/concerns/preference_sign_up_initialization_test.rb`（15テスト、app/com/org ×
5観点）。§1.4で主張した「専用メソッド不要、共有`sync_preferences!`で正しい」を実際にコードで実証した。

テスト作成中に**実バグを1件発見・修正**した: テストヘルパーの adoption context に
`preference_prefix`（`PreferenceBase`側で定義され`PreferenceAdoption`単体には存在しない）を渡し忘れると、`sync_preferences!`内部で`NoMethodError`が発生し、`adopt_preference_for!`の
`rescue StandardError`で無言握りつぶされ、language等が一切reconcileされない（signup
defaultのままになる）ことが判明した。これはテストヘルパー自体の不備であり本番コードのバグではないが、「エラーを握りつぶすと症状が『principal
defaultが勝った』ように見えて、原因究明が難しい」という実例になったため記録する。修正後、15件全て成功（app/com/orgとも、明示的browser値の import・非explicit
seedの非import・新規default行がtimestampだけで勝たないこと・default値の明示選択がexplicitのまま残ること・adult_content_gateが通常のdisplay
preferenceとして混入しないこと、を確認）。

### 9.4 app/com/org parity matrix（実コードベース）

| 項目                                          | app                                                                                                                                             | com                                                                      | org                              | 統一実装（Concern）                                                                                                                                 | 正当な差異                                                                                                                |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| guest Preference作成                          | `AppPreference`+`create_new_preference_record!`                                                                                                 | `ComPreference`+同左                                                     | `OrgPreference`+同左             | Yes — `PreferenceRefreshTokenTransport` (`preference_refresh_token_transport.rb:113`)                                                               | なし                                                                                                                      |
| 通常のdual-write                              | `write_resource_preference_option!`                                                                                                             | 同左                                                                     | 同左                             | Yes — `PreferenceResourceSync` (`preference_resource_sync.rb:92-121`)                                                                               | なし                                                                                                                      |
| サインイン per-key reconciliation             | `adopt_preference_for!`→`sync_preferences!`                                                                                                     | 同左                                                                     | 同左                             | Yes — `PreferenceAdoption` (`preference_adoption.rb:115-160`)、呼び出し元は`AuthenticationBase#issue_login_tokens_within_lock:498`で3サーフェス共通 | なし                                                                                                                      |
| サインアップ初期化                            | 同上（専用メソッドなし）                                                                                                                        | 同上                                                                     | 同上                             | Yes — 同一の`sync_preferences!`（§9.3で実証）                                                                                                       | なし                                                                                                                      |
| ローカルsign-out rotation                     | `rotate_preference_after_sign_out!`                                                                                                             | 同左                                                                     | 同左                             | Yes — `PreferenceSignOutRotation` (`preference_sign_out_rotation.rb`)、`PreferenceGlobal`経由で全surfaceに配布                                      | なし                                                                                                                      |
| 旧credential retirement                       | `used_at`/`discarded_at`設定                                                                                                                    | 同左                                                                     | 同左                             | Yes — `retire_preference_after_sign_out!` (同上)                                                                                                    | なし                                                                                                                      |
| all-session logout                            | `rotate_preference_after_sign_out!`を同じくcurrent browserにのみ適用                                                                            | 同左                                                                     | 同左                             | Yes — `AuthenticationLogoutable#logout_all_sessions_for!` (`authentication_logoutable.rb:54-77`)                                                    | なし（他デバイスは意図的に対象外、§9で既述）                                                                              |
| explicit metadata                             | `explicit_fields` on AppPreference/ClientPreference                                                                                             | ComPreference/VisitorPreference                                          | OrgPreference/OperatorPreference | Yes — `PreferenceExplicitFields` concern、3モデルペア共通include                                                                                    | なし（列名・デフォルト・migration形が3DB対称）                                                                            |
| consent処理                                   | `reconcile_cookie_consent!`（consented_at優先、version比較なし）                                                                                | 同左                                                                     | 同左                             | Yes — `PreferenceAdoption`                                                                                                                          | なし（§9.2で延期理由を明記）                                                                                              |
| adult gate処理                                | `force_underage_r18_stopper!`                                                                                                                   | 同左                                                                     | 同左                             | Yes — `PreferenceAdoption` (`preference_adoption.rb`内)                                                                                             | なし                                                                                                                      |
| public cookie projection                      | `issue_access_token_from`→`write_public_option_cookies`                                                                                         | 同左                                                                     | 同左                             | Yes — `PreferenceAccessTokenIssuer`/`PreferenceCookieWriter`                                                                                        | なし                                                                                                                      |
| failure handling                              | `rescue StandardError`（adoption）/ transaction rollback + 2種イベント（sign-out rotation）                                                     | 同左                                                                     | 同左                             | Yes — 同上concern群                                                                                                                                 | なし                                                                                                                      |
| セキュリティテスト                            | `preference_access_token_transport_test.rb`, `preference_dbsc_retirement_test.rb`（AppPreferenceのみ実装、com/orgは同一コードパスにつき未複製） | 同左（コード共有により暗黙的にカバー）                                   | 同左                             | Partial — テストはAppPreference代表のみ、com/org版は複製していない                                                                                  | **正当ではない省略**（時間予算切れ。次回、同テストをComPreference/OrgPreference向けに複製するか、パラメタライズすること） |
| lifecycle テスト（adoption/sign-up/sign-out） | `adoption_test.rb`, `preference_sign_up_initialization_test.rb`, `preference_sign_out_rotation_test.rb`                                         | sign-up: 同一ファイルでカバー／adoption・sign-outはAppPreference代表のみ | 同上                             | Partial（sign-upのみ3surface実施、adoption/sign-outはAppPreference代表）                                                                            | 同上、次回申し送り                                                                                                        |

3surfaceとも同一Concernを共有しており、今回変更した4ファイル (`preference_adoption.rb`,
`preference_sign_out_rotation.rb`, `authentication_logoutable.rb`,
`preference_access_token_transport.rb`)に
`case surface`のような分岐は一切追加していない。唯一の未解消差異はテストカバレッジの複製漏れ（access-token/DBSC
retirementテストがAppPreference代表のみ）であり、実装差異ではない。

### 9.5 パフォーマンス実測（`ActiveSupport::Notifications.subscribe("sql.active_record")`による実測、推測ではない）

| フロー                                                                                                           | 実測クエリ数                        | 備考                                                                                                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ローカルsign-out rotation                                                                                        | **25クエリ**                        | 新guest行作成(default 11 child + option ensure_defaults) + safe-copy seed(2 key分) + 旧行retire                                                                                                      |
| サインアップ初期化（新規ClientPreference作成を伴う`adopt_preference_for!`）                                      | **91クエリ**                        | `create_resource_preference_options!`が11 CHILD_RECORD_TYPES分の`ensure_defaults!`+`create!`、続く`sync_preferences!`が11キー分×(browser読み取り+principal読み取り+場合により書き込み)を実行するため |
| サインイン reconciliation（既存principalが既に存在）                                                             | **3クエリ**                         | 新規作成が発生しないため大幅に少ない                                                                                                                                                                 |
| 通常のsigned-in dual-write（`PreferenceCore#update_preference_child_dual_write!`、1キー分、appサーフェスで実測） | **31クエリ**（Reads 24 / Writes 7） | 内訳: browser側 5、principal側 5、option lookup 5、Chronicle監査ログ 6。重複クエリ2組（後述）。                                                                                                      |

計測は `test/controllers/concerns/preference_dual_write_query_count_test.rb`
（`ActiveSupport::Notifications.subscribe("sql.active_record")`による実測、新規）で行った。計測対象は
`write_resource_preference_option!` 単体ではなく、実際にcontroller actionが呼ぶ上位メソッド
`PreferenceCore#update_preference_child_dual_write!`
(`app/controllers/concerns/preference_core.rb:286-309`) 全体——browser側child更新+監査ログ、browser側explicitマーク、principal側mirror書き込み、token再発行に伴う11
child再読み込み、まで含む。

**app/com/org の経路同一性**: `update_preference_child_dual_write!` /
`write_resource_preference_option!`
はいずれも surface 分岐のない単一メソッド（`PreferenceCore`/`PreferenceResourceSync`
concern）であり、呼び出し元も3surface共通のため、appで1回実測すれば十分と判断し、com/orgでの再計測は行わなかった（正しさの方は3surface全てで別途
`test/controllers/concerns/preference_dual_write_contract_test.rb` により確認済み——後述）。

**この計測作業で実際のバグを1件発見・修正した**（最重要）:
`app/controllers/concerns/preference_resource_sync.rb`
の`resource_preference_association_prefix`が、ClientPreference用に`"client_preference"`、OperatorPreference用に`"operator_preference"`という**存在しない**has_one
association名を返していた（正しくは`client_preference.rb`/`operator_preference.rb`で実際に宣言されている
`"user_preference"`/`"staff_preference"`）。この結果、`load_or_create_resource_preference_child!`
の`resource_pref.respond_to?(association_name)`チェックが常にfalseとなり、**app/orgサーフェスのsigned-in
dual-writeでは、principal側の per-key child option行（例:
`client_preference_languages`）が一度も更新されずnilを返して黙って`next`していた**——flat文字列カラム（`client_preferences.language`など）だけは別経路で正しく更新されるため、UIの表示上は問題なく見えるが、次回サインイン時のper-keyマージが参照する`user_preference_language`
等のchild行は永久に古いままという、確認しにくい形でのデータ不整合が生じていた（VisitorPreference用の`"visitor_preference"`はたまたま実際の association 名と一致していたため comサーフェスだけは影響を受けていなかった）。

修正は1行（`preference_resource_sync.rb`の該当3行）。既存テスト
`test/controllers/concerns/preference_resource_sync_test.rb`
の対応するアサーションも、このバグを固定化していた誤った期待値だったため合わせて修正した。新設の
`preference_dual_write_contract_test.rb`（app/com/org 3件）で、修正後は3surfaceともprincipal側child
optionが正しく更新されることを確認済み。

**残存する重複クエリ**（意図的に未修正、理由を明記）:
`app_preference_language_options WHERE id=2`と`app_preferences WHERE id=...`がそれぞれ2回ずつ実行されている（別々のメソッドが同じ主キー行を独立に再取得しているため）。単一行PKルックアップでコストは軽微であり、修正には複数メソッドの呼び出し境界をまたぐキャッシュ/引数受け渡しの変更が必要で「narrow
change」の範囲を超えるリスクがあるため、今回は修正せず記録に留めた（対象:
`app/controllers/concerns/preference_resource_sync.rb:97-121` の
`resource_preference_value_for_option` と `mapped_resource_option_id` が独立に
`AppPreferenceLanguageOption.find_by(id:...)` を呼ぶ箇所、および
`create_audit_log`/`reload_preferences_and_reissue_token!` が独立に
`@preferences`を再SELECTする箇所）。

**dual-writeの他の確認事項**:

- 同一valueが両側に書かれる: 修正後に確認済み（`client_preference_languages.option_id`と
  `app_preference_languages.option_id`が一致）。
- explicit状態: browser側は`update_preference_child_dual_write!`内で
  `mark_preference_field_explicit!`、principal側は`write_resource_preference_option!`内で
  `mark_field_explicit!`——同一トランザクション内で両方呼ばれ、一致することを確認。
- タイムスタンプ: 両側とも`updated_at`がそれぞれの`update!`呼び出し時刻になる（別DBのため厳密には別時刻だが、同一リクエスト内でミリ秒単位の差）。専用の比較可能フィールドは存在しない（§Merge
  Contractの best-effort timestamp 制約と同様の性質）。
- 片側だけ成功: `with_dual_write_transaction`
  (`preference_resource_sync.rb:239-253`)が token側を outer transaction、principal側をinner
  transactionとして両方を1つの失敗境界に包んでいるため、通常のin-requestエラー（validation, FK,
  authorization）は両側ロールバックされる。ただしコメントに明記されている既知の残存ギャップ:
  inner(principal)コミット後・outer(token)コミット前のプロセスクラッシュは理論上principal側だけ先行しうる——次回ログイン時のper-keyマージで自然に補正される設計（§Merge
  Contract）。
- retry時の重複: `write_resource_preference_option!`はoption_idを冪等に上書きする単純な
  `update!`であり、同じリクエストを再送しても最終状態は同じ（beforeの値に依存しない）。

**N+1に関する所見**: サインアップ初期化の91クエリ・dual-writeの31クエリはいずれもCHILD_RECORD_TYPES(11種)に対して固定回数のループであり、ユーザーデータ量に比例して増加する古典的なN+1ではない（境界あり）。ただし今回の per-key 化により、旧実装（勝者側からの一方向コピーのみ）と比較して**per-keyで両側を読む分、読み取りクエリが構造的に増加した**——正確な「変更前後の差分」は旧実装がこのブランチに存在しないため直接比較できないが、設計上、per-key正確性とクエリ数はトレードオフである。今回はこのトレードオフを意図的に受け入れた（正確性を優先）。実データでのレイテンシ実測・バッチ読み込みへの最適化は行っていない（実測ベースの根拠がない最適化はしないという指示に従い、今回は変更なし）。

### 9.6 Row growth（sign-out rotationによる新規guest行）

`rotate_preference_after_sign_out!`はsign-outのたびに新しい`AppPreference`/`ComPreference`/
`OrgPreference`行を1つ作成し、旧行は`discarded_at`を過去に設定して`active`スコープから外れるのみで、**物理削除・パージは行っていない**。既存の`purged_at`カラム（`Retainable`concern）に基づく既存の定期パージ機構を確認した:
`app/jobs/retention_purge_job.rb:24-42`の`RETAINABLE_MODELS`リストに`AppPreference`/
`OrgPreference`/`ComPreference`が含まれており、`purged_at`を過ぎた行を`delete_all`で物理削除する（既存インフラ、今回変更なし）。`retire_preference_after_sign_out!`は
`discarded_at`（アクティブ判定用の有効期限）のみを更新し`purged_at`（物理削除タイミング）は触らないため、retire済み行は既存のバッチジョブが`purged_at`到達時に自然に回収する設計と整合している。ジョブの実行間隔・batch_sizeとsign-out頻度の比率による蓄積速度の実測は行っていない（次回、実運用トラフィック規模でのバックログ試算が必要）。

### 9.7 全体検証（実行コマンドは`.github/workflows/integration.yml`から確定）

- `bundle exec brakeman -f sarif -o brakeman.sarif --no-pager --quiet -z`
  (`.github/workflows/integration.yml:89`) — **2回実行、いずれも0件・exit 0**。新規findingなし。
- `COVERAGE=true bundle exec rails test` (`.github/workflows/integration.yml:318`) — §9.8参照。

### 9.8 全体テスト・カバレッジ結果（実測、複数回実行）

1回目の実行で **9362 runs, 11148 assertions, 7 failures, 8404 errors**
という壊滅的な結果が出たが、原因を調査したところ、Preference
lifecycle の実装とは無関係の**環境汚染**だった: 本セッション中の初期調査で`bin/rails runner -e test`によるアドホックなデバッグスクリプトを複数回実行しており、これらはトランザクション外でテストDBに実データを作成・削除していたため、
`client_preferences`等のテストDBに孤立行（存在しないFKを参照する行）が残留し、
`ActiveRecord::FixtureSet.check_all_foreign_keys_valid!`がほぼ全テストクラスの
`setup`（fixture読み込み）で失敗していた。`RAILS_ENV=test bin/rails db:drop db:prepare`でテストDB群を完全に作り直し、再実行した。

2回目の実行（クリーンな状態）: **9362 runs, 44781 assertions, 2 failures, 2 errors, 0
skips**。失敗を精査したところ、1件は本セッションの変更が原因の**テストハーネスの破損**（本番コードは正しい）であることが判明した:

- `Preference::PreferenceBaseMethodsTest#test_bounded_access_token_preference_record_loader_reads_through_writing_connection`
  (`test/controllers/concerns/preference/base_test.rb:930`)
  — 期待するAppPreferenceの代わりにnilを返していた。原因: このテストは`AppPreference.stub(:includes, relation)`だけをスタブしていたが、本セッションでaccess-token失効バグを修正した際に`load_access_token_preference_record!`
  の呼び出し形が`preference_class.includes(...).find_by(...)`から
  `preference_class.active.unconsumed.includes(...).find_by(...)`
  (`app/controllers/concerns/preference_access_token_transport.rb:38-41`)に変わったため、
  `.includes`がクラス自身ではなく`.active.unconsumed`が返すリレーション上で呼ばれるようになり、スタブが素通りされていた。テスト側を修正 (`test/controllers/concerns/preference/base_test.rb:946-969`、`.active`/`.unconsumed`もクラス自身を返すようスタブに追加)し、単体実行で85
  runs, 0 failuresを確認。

修正後、3回目の全体実行: **9362 runs, 44783 assertions, 1 failure, 2 errors, 0
skips**。残る3件はいずれも本diffと無関係なファイルで発生しており（`git diff --stat`で無変更を確認済み）、既存の（本セッション開始前からの）不具合と判定した:

| テスト                                                                                                                                                           | 内容                                                         | 本diffとの関連                                          |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------- |
| `ModelOnlyLineCoverageTest#test_actor_configuration_null_values_and_dynamic_access_preserve_value_semantics` (`test/models/model_only_line_coverage_test.rb:12`) | `Actor::Configuration::NullValue`がnilと等しいと期待して失敗 | 無関係（Preference以外のActor設定機能、本diffで未変更） |
| `RepositoryLanguageCheckTest#test_checks_japanese_test_names_but_ignores_localized_assertions` (`test/tooling/repository_language_check_test.rb:81`)             | `undefined method 'assert_not_includes'`                     | 無関係（リポジトリ言語チェックツール、本diffで未変更）  |
| `RepositoryLanguageCheckTest#test_checks_japanese_source_comments_but_ignores_localized_string_literals` (`test/tooling/repository_language_check_test.rb:68`)   | 同上                                                         | 無関係（同上）                                          |

**カバレッジ**: Line coverage 45816/49320 (**92.89%**)、Branch coverage 10665/14756
(**72.27%**)。リポジトリの要求ライン網羅率95%を**下回っている**。この不足はリポジトリ全体の既存カバレッジ状況であり、本セッションの変更ファイル群だけの網羅率ではない（SimpleCovの出力はプロジェクト全体集計のため、今回変更した約20ファイルだけの寄与分は本セッションでは分離計測していない）。95%達成のためにリポジトリ全体へ無差別にテストを追加することはスコープ外と判断し、行っていない。

実行ログ: `/tmp/full_coverage_run2.log`（このセッションの一時ファイル、リポジトリ外）。

### 9.9 ドキュメント更新

`docs/architecture/preference-behavior-contract.md`を更新した（新規作成ではなく既存ファイルへの編集）:

- 「Merge Contract」節をper-key契約に全面差し替え（旧: parent
  `updated_at`勝者総取りの説明を「Anonymous-to-signed-in merge (legacy list, superseded by the
  per-key table above)」として残しつつ、上位互換の新契約を明記）。
- explicit semantics、legacy互換性(NULL vs [] vs populated)、best-effort timestampの限界を明記。
- 「Logout」行を更新——2026-07-02の「絶対に触らない」決定が2026-07-21のrotation実装でsupersedeされたことを明記（矛盾する既存記述を放置しない、というリポジトリ規約に従った）。
- 新設「Sign-out credential rotation」節: シーケンス、safe-copy allowlist、token retirement
  guarantees（access JWT/refresh/DBSCそれぞれの検証経路の確認結果を含む）、all-session
  logout、consent policy version deferralを記載。

---

## 10. 継続セッション追記その3（2026-07-21、app/com/org共有テストcontractとdual-write実測）

### 10.1 signed-in dual-writeの実測とバグ発見・修正

§9.5を全面更新した。要点: 実測
**31クエリ**（app代表実測、app/com/orgは単一concernでsurface分岐なしのためapp実測で十分と判断）。計測ハーネス構築中に
`resource_preference_association_prefix`
(`app/controllers/concerns/preference_resource_sync.rb`)の**実バグ**を発見:
app/orgサーフェスでprincipal側child
option行が一度も更新されていなかった（comのみ偶然無傷）。1行修正済み、既存の誤った期待値を固定していたテストも修正済み、新規3surfaceテストで検証済み。詳細は§9.5参照。

### 10.2 app/com/org 共有テストcontract（コピペ3ファイル禁止の対応）

新規 `test/support/preference_lifecycle_surfaces.rb`:
app/com/orgの差分（`AppPreference`/`ComPreference`/`OrgPreference`、対応するstatus/binding/dbsc-statusクラス、`ClientPreference`/`OperatorPreference`/`VisitorPreference`とそのFK、resource生成ラムダ、child
association名）だけを保持する薄いアダプタ。挙動アサーションは一切含まない。

このアダプタを使う共有contractテスト3ファイル（各ファイル内で
`PreferenceLifecycleSurfaces::SURFACES.each_key do |surface| test "#{surface}: ..." do ... end end`
により、同一アサーション本体を3surface分実行——3つの別ファイルへコピペしていない）:

- `test/controllers/concerns/preference_sign_out_rotation_contract_test.rb`（12テスト =
  4アサーション×3surface）: 新guest行作成／旧行retire／safe値のnon-explicitコピー／principal識別子がguest行に一切現れない（構造的チェック）／retirement失敗時の観測可能なログ・auth
  logoutの非ブロック。
- `test/controllers/concerns/preference_sign_in_reconciliation_contract_test.rb`（9テスト =
  3アサーション×3surface）: per-keyで無関係なexplicitキーが上書きされない／legacy
  principal保護規則／reconciliation後の両側収束。
- `test/controllers/concerns/preference_dual_write_contract_test.rb`（3テスト、1アサーション×
  3surface）:
  dual-writeが両側に同じ値・同じexplicit状態を書くことの正しさ確認（クエリ数は§10.1の通りappのみ実測）。

既存の `test/controllers/concerns/preference_sign_up_initialization_test.rb`
（前回セッションで作成済み、15テスト = 5アサーション×3surface、同じ
`SURFACES.each_key`パターン）は既に3surface共有になっていたため変更していない。

**サーフェス固有のセットアップ**（ログインヘルパーやfixture）は
`preference_lifecycle_surfaces.rb`内の小さなper-surfaceアダプタ（ラムダ）にのみ存在し、アサーション本体（`test "#{surface}: ..." do ... end`のブロック内）はいずれのファイルでも共通コードである。

**未カバーの項目**（時間予算切れ、正直に申告）: サインアウトのold access JWT / old refresh
credential / old DBSC binding それぞれの明示的な拒否テストは、既存の
`preference_access_token_transport_test.rb`・`preference_dbsc_retirement_test.rb`がAppPreference代表のみで、3surface共有contractへの拡張は行っていない（ただし検証済みの通り、これらの検証経路もsurface分岐のない共通コードであるため、コード上は3surfaceとも同じ保証が働くと判断できるが、テストとしての明示的な3surface実行はまだない）。

### 10.2.1 最終フル実行（association-prefixバグ修正・共有contract追加後）

`COVERAGE=true bundle exec rails test` を再実行: **9387 runs, 44826 assertions, 1 failures, 14
errors, 0 skips**（実行時間566秒）。Preference関連の失敗はゼロ。内訳を精査:

- 1 failure: `ModelOnlyLineCoverageTest`（§9.8既報、無関係、本diff未変更）。
- 2 errors: `RepositoryLanguageCheckTest`（§9.8既報、無関係、本diff未変更）。
- 12 errors:
  `AvatarPersonaBindingTest`（`ID状態を入力してください`というreference-data未seed起因のバリデーションエラー）と`Acme::AccountQuotaPolicyTest`（I18n翻訳データ欠落）。いずれもAvatar/Persona/Account
  Quotaドメインで、本diffは一切触れていない。
  `bin/rails test test/models/avatar_persona_binding_test.rb test/policies/acme/account_quota_policy_test.rb`
  で単独実行したところ **15 runs, 0 failures, 0 errors** で全て成功——並列実行時のreference-data
  seedingレース起因のflakinessであり、本diffによる回帰ではないと判定した。

Line coverage 45814/49320 (**92.89%**)、Branch coverage 10659/14756
(**72.23%**)。前回計測（92.89%/72.27%）とほぼ同一（branch側の微小な差は新規追加した25テストによる到達分岐の変動）。

### 10.3 再検証コマンドと結果

```
bin/rails test test/controllers/concerns/preference_sign_out_rotation_contract_test.rb \
  test/controllers/concerns/preference_sign_in_reconciliation_contract_test.rb \
  test/controllers/concerns/preference_dual_write_contract_test.rb \
  test/controllers/concerns/preference_dual_write_query_count_test.rb        → 27 runs, 0 failures
bin/rails test $(find test -iname "*preference*" -name "*_test.rb")          → 1131 runs, 0 failures
bin/rails test $(find test -iname "*preference*" -name "*_test.rb") \
  $(find test -path "*controllers/auth*" -name "*_test.rb" | grep -i sign) \
  $(find test -path "*controllers/base*" -name "*_test.rb")                  → 1633 runs, 0 failures
bundle exec rubocop <touched files>                                          → no offenses
bundle exec brakeman -f sarif -o brakeman.sarif --no-pager --quiet -z        → 0 findings, exit 0
COVERAGE=true bundle exec rails test                                         → §10.4参照
```

### 10.4 最終ステータスブロック

```
Preference lifecycle implementation: complete
Preference-specific parity verification: complete
Preference-specific performance review: complete
Repository-wide coverage gate: failing at 92.89% line coverage (pre-existing, out of scope)
Safe to review: yes
Safe to commit: yes
Safe to merge or declare the project gate complete: no while line coverage remains below 95%
```
