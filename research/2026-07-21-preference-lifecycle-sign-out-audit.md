# 2026-07-21 Preference Lifecycle セキュリティ監査（サインアウト/サインイン/サインアップ境界）

## 0. 位置づけ

本メモは調査・設計・文書化のみであり、実装変更は行っていない。2026-07-02/2026-07-03 の Preference
audit・follow-up（`research/2026-07-02-preference-audit-report.md`,
`research/2026-07-03-preference-followup-report.md`）は CSRF・cookie consent 厳格化・Com
surface への
`PreferenceAdoption` 追加を扱ったが、サインアウト時の token
detach/rotation とサインイン時のマージ粒度は対象外だった。本メモはその2点を新たに監査する。

作業ログは `plans/project-umaxica-preference-humble-blossom.md`
に残っている（探索過程・grill-me の質問と回答を含む）。

---

## 1. Executive summary

Preference は token-scoped（`AppPreference`/`ComPreference`/`OrgPreference`、匿名可、
`app_setting`/`com_setting`/`org_setting` DB）と principal-scoped（`ClientPreference`/
`OperatorPreference`/`VisitorPreference`、`app_principal`/`org_principal`/`com_principal` DB、1:1
with account）の2層構造で、ログイン時に `PreferenceAdoption` が両者を同期する。

今回のコード直読で以下2点を確認した。

1. **サインアウト時、preference access/refresh/dbsc
   cookie とその token は一切失効・ローテーションされない。** 主要 auth cookie のみ
   `clear_auth_cookies!` で削除され、 `clear_preference_auth_cookies!`
   はサインアウト経路から一度も呼ばれていない。
2. **サインイン時のマージ (`PreferenceAdoption#sync_preferences!`) は per-key ではなく record 全体の
   `updated_at` 比較で、勝った側が全キーを無条件に上書きする。** `explicit_fields`
   カラム（自動生成 default 値と明示的変更を区別するためのカラム）は存在するが、`PreferenceAdoption`
   からは一切参照されていない。

この2点は、依頼された security
invariant のうち「サインアウト後のブラウザPreferenceは過去のprincipalから完全に切り離される」「サインアップ時はdefault値が既存ブラウザPreferenceを誤って上書きしない」「per-key
merge」を直接的に破っている。

---

## 2. Final verdict table

| Item                                          | Verdict                                                                         | 根拠                                                                                                                   |
| --------------------------------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| ゲスト/principal Preferenceの分離             | OK                                                                              | 別DB・別モデル（§3）                                                                                                   |
| サインアウト時のdetach                        | **NG**                                                                          | §4 — サインアウト経路のどこも preference cookie/token に触れない                                                       |
| サインアウト時のtoken rotation                | **NG**                                                                          | §4 — 同上                                                                                                              |
| サインアウト後のprincipal書き込み防止         | PARTIAL                                                                         | JWT claim に principal id は元々存在しない（§3）が、token 自体は同一行に紐付いたまま次回ログインで再アドプションされる |
| 安全なPreference値の継承                      | 現状「壊れていないから継続している」だけで意図した設計ではない                  | §4                                                                                                                     |
| サインイン時のマージ                          | **NG**                                                                          | §5 — 全体 `updated_at` 勝者総取り、per-key ではない                                                                    |
| サインアップ時のブラウザPreference継承        | **NG**                                                                          | §6 — signup default 行の `updated_at` が既存ブラウザ値より新しくなるため上書きされる                                   |
| default値と明示的変更の区別                   | **NG**                                                                          | `explicit_fields` はモデルに存在するが `PreferenceAdoption` から未参照                                                 |
| per-key conflict resolution                   | **NG**                                                                          | 同上                                                                                                                   |
| cross-browser/cross-account contamination防止 | **NG**                                                                          | §4 の直接帰結                                                                                                          |
| JWT claim境界                                 | OK                                                                              | 専用 issuer/audience/typ、PII・role・org claim なし                                                                    |
| Cookie scope                                  | OK（access/refresh/dbsc）/ PARTIAL（public cookie は apex domain 全体スコープ） | §3                                                                                                                     |
| PII排除                                       | OK                                                                              | JWT claim・registry allowlist に PII 不在を確認                                                                        |
| Chronicleとの責務分離                         | OK                                                                              | durable audit table と `Rails.logger` の分離が ADR と一致                                                              |
| last sign-in method badgeの保存先             | 未実装（設計のみ）                                                              | §7                                                                                                                     |

---

## 3. 確認済みアーキテクチャ

```text
Browser
  ↓ (preference_access / preference_refresh / preference_dbsc cookies)
PreferenceToken JWT (SecurityJwtPreferenceTokenCodec, ES384, typ=preference-access-token)
  ↓
AppPreference / ComPreference / OrgPreference   (token-scoped, 匿名可)
  ↔ PreferenceAdoption#sync_preferences!  (ログイン時, whole-record updated_at 比較)
ClientPreference / OperatorPreference / VisitorPreference  (principal-scoped mirror)
  ↓
Public non-HttpOnly cookies (ct/language/tz/cu/df/tf/mo/dn/ps/preference_consented)
```

- Preference JWT claim (`app/values/security_jwt_preference_token_codec.rb:126-140`):
  `preferences, host, preference_type, public_id, jti, typ, iss, aud, iat, exp`。role・org_id・PIIなし。`public_id`
  は preference レコード自身の id であり principal/account id ではない。
- Cookie 属性: access/refresh/dbsc は HttpOnly
  (`app/controllers/concerns/preference_base.rb:1004-1010, 1044-1049, 1051-1056`)。公開オプション cookie
  (`ct`/`language`/`tz`等) は明示的に非 HttpOnly、 `domain: true`（apex
  scope）(`app/controllers/concerns/preference_cookie_writer.rb:9-17`)。 `__Host-`
  prefix は production のみ access/refresh/dbsc に付与 (`app/controllers/concerns/preference_cookie_name.rb:54-58`)。

---

## 4. サインアウト時の finding（新規・最重要）

- `app/controllers/concerns/authentication_cookie_store.rb:28-36` `clear_auth_cookies!` は
  `ACCESS_COOKIE_KEY`・`REFRESH_COOKIE_KEY`・auth用 DBSC cookie のみを削除する。
  `clear_preference_auth_cookies!` は呼ばれない。
- `app/controllers/auth/{app,com,org}/sign/outs_controller.rb` の `clear_sign_cleanup_state!` は
  `AuthenticationBase::REFRESH_COOKIE_KEY` のみを削除し、 `logout_current_session!` を呼ぶ。
- `app/controllers/concerns/authentication_logoutable.rb:25-43` `logout_current_session!` の
  `ensure` ブロックは `clear_auth_cookies!`・`Actor.clear`・`reset_session` のみで、preference
  cookie/record には一切触れない。
- `clear_preference_auth_cookies!`
  (`app/controllers/concerns/preference_base.rb:1058-1066`) の呼び出し元は全て preference-refresh の失敗・replay・binding-denied 分岐 (`preference_access_token_issuer.rb:40`,
  `preference_core.rb:634`, `preference_refresh_token_transport.rb:197`,
  `preference_base.rb:834/848/911`) であり、サインアウト経路からは一度も呼ばれていない。

**結果**: サインアウト後も `preference_access`/`preference_refresh`/`preference_dbsc`
cookie と、その裏にある `jti`/refresh token の principal-mirror
preference への紐付きがそのまま生存する。同一ブラウザでの次回未認証操作は同じ token を使い続け、次回同一principalの再ログイン時には「サインアウト後にゲストとして行った変更」が同じ token 行を経由して再アドプションされる——「一度サインアウトしたら過去の principal から完全に切り離す」という要件を満たしていない。

JWTクレーム自体に principal id は含まれない（§3）ため、直接的な principal
identifier 漏洩ではないが、token
fixation 的な懸念（サインアウト前後で同一 credential が有効であり続ける）は現に存在する。

---

## 5. サインイン時マージの finding（コード直読で確定）

`app/controllers/concerns/preference_adoption.rb` を全文直読した結果:

- `sync_preferences!` (97-111行) は `@preferences.updated_at` と `resource_pref.updated_at`
  を一度だけ比較し (98-101行)、勝った側から `copy_preference_values!` で **全キーを無条件にコピー**
  する (114-156行)。 `target_child` 側の `updated_at` は一度も参照されず、上書き後に `touch_target!`
  (155/310行) で強制的に更新されるのみ。
- `explicit_fields`/`PreferenceExplicitFields`
  (`app/models/concerns/preference_explicit_fields.rb:12`) は本ファイル内で一度も参照されない。
- **結果**: ゲスト状態でテーマだけを変更したユーザーが再ログインすると、ゲスト側が新しければ言語・タイムゾーン・通貨等、principal 側が意図的に設定していた他の全キーまで巻き添えで上書きされる。これは依頼仕様の「各キーを独立してマージする、一つのレコード全体を丸ごと上書きしない」に明確に反する。
- optimistic locking /
  version カラムはどの Preference モデルにも存在しない（`app/models/*preference*`,
  `app/controllers/concerns/preference_*`
  を grep して確認）。タイムスタンプ精度・時計差・同時刻 tie の曖昧さを解消する手段が timestamp 以外に存在しない。
- `force_underage_r18_stopper!`
  (158行) は年齢制限による adult_content_gate 強制 DENY をマージ後に無条件適用しており、マージ方向に関わらずバイパス不可。これは意図通り。

---

## 6. サインアップ時継承の finding（コード直読で確定）

- `ClientPreference`/`OperatorPreference`/`VisitorPreference` の `set_defaults` は
  `after_initialize` で走るため、新規行は生成直後に default 値を持つ。
- `create_resource_preference!`
  (`preference_adoption.rb:73-83`) が signup 時にこの行と11個の default child
  record を作成し (`create_resource_preference_options!`, 85-94行)、その `created_at`/ `updated_at`
  はサインアップ完了時点のタイムスタンプになる——ほぼ確実に既存のブラウザPreferenceより新しい。
- §5 で確認した通り `sync_preferences!` は `explicit_fields` を見ないため、この新規 default 行が
  `updated_at`
  比較で勝ち、**サインアップ以前からブラウザで使っていた言語・テーマ等が signup 完了時に default 値で上書きされる**——依頼文書が明示的に懸念していた失敗モードそのものが実際に発生しうることを確認した。

---

## 7. 「前回使用したサインイン方法」バッジ

現状コードベースにこの概念は一切存在しない（3方向の独立調査で確認）。 `activity_log.rb`
presenter が監査ログの JSON context から `auth_method`/ `method`
を読むのは活動履歴表示専用であり、Preference/cookie/JWT のいずれにも関与しない。よってこれは監査対象ではなく新規設計項目。

### 決定済み仕様（ユーザー承認）

- **意味論**: 「このブラウザが最後に使った方法」（principal スコープではない）。
- **dual-write**: principal Preference への書き込みは禁止。
- 既存 Preference JWT/DB へは載せず、別途 **サインイン surface ごとに scope された signed
  cookie**（暗号化ではなく署名、非 HttpOnly の JS 可視化は不要）として実装する方針が妥当（実装は本メモの対象外）。

---

## 8. データ分類（要点）

| 項目                                                                                                                                | browser-local | principal Preference | dual-write     | JWT claim        | JS可視cookie                    |
| ----------------------------------------------------------------------------------------------------------------------------------- | ------------- | -------------------- | -------------- | ---------------- | ------------------------------- |
| theme/language/timezone/currency/locale/motion/density                                                                              | Yes           | Yes                  | Yes            | Yes（短縮キー）  | Yes                             |
| last sign-in method                                                                                                                 | Yes（決定）   | **No**（決定）       | **No**（決定） | **No**（決定）   | 未実装、既存JWTには載せない方針 |
| principal ID / resource ID / email / telephone / org ID / role / MFA state / passkey情報 / provider identifier / IP / login history | No            | No                   | No             | 現状も確認上不在 | No                              |

`adult_content_gate`
は Preference の子フィールドだが、年齢適格性という security-relevant な上書き対象でもあり、クライアントが緩い方向に設定できない制御が
`preference_adoption.rb:158` に既存（今回の指摘とは独立に妥当）。

---

## 9. 推奨する最小改修計画（設計のみ、未実装）

1. **サインアウト時ローテーション** — 対象:
   `app/controllers/concerns/authentication_logoutable.rb#logout_current_session!` および各surfaceの
   `sign/outs_controller.rb#clear_sign_cleanup_state!`。 `clear_auth_cookies!` と併せて、現在の
   `@preferences`
   から安全な値（theme/language/timezone/currency/date_format/time_format/motion/density/
   page_size。cookie
   consent フラグは対象外——同意状態は新しいゲストIDで再確認されるべき）だけをコピーした新しい guest
   preference token を発行し（既存の `create_new_preference_record!`,
   `preference_refresh_token_transport.rb:113-162` を流用可能）、旧cookieは既存の
   `clear_preference_auth_cookies!` で削除する。schema変更不要。
2. **per-key マージ** — 対象: `preference_adoption.rb#sync_preferences!` と
   `copy_preference_values!`。全体 `updated_at` 比較をやめ、 `CHILD_RECORD_TYPES`
   の各キーごとに「principal側が `explicit_field?`
   なら principal 値、そうでなければ browser 側の値（存在すれば）」で決定する。**principal側モデル（Client/Operator/VisitorPreference）に相当する
   `explicit_fields` 相当カラムが存在しないため、migration が必要。**
3. **サインアップ default 判別** — 対象: `create_resource_preference_options!`
   (85-94行)。新規作成されるdefault child record は明示的に「not
   explicit」としてマークし、(2) のマージが自然にブラウザ側の既存値を優先するようにする。
4. **last sign-in method badge** — 新規、browser-scope専用の signed cookie。既存 Preference
   JWT/DB には一切載せない（§7 決定）。

各項目の migration要否・後方互換・rollout順序・failure handling・test 追加は
`plans/project-umaxica-preference-humble-blossom.md`
§10 に詳細を記載済み。(2)と(3)は同時リリースが必須（同じ explicit flag
semantics に依存するため）、(1)と(4)は独立に実施可能。

---

## 10. Test plan（要点）

- サインアウトで preference token がローテーションされる（新cookie/jti、旧cookie削除）。
- サインアウト後、旧token の replay が拒否される。
- per-key マージ: ブラウザ側で1キーだけ変更した場合、principal側の他のexplicit値が保持される。
- サインアップ: サインアップ前から明示的に設定されていたブラウザ値が signup
  default 値で上書きされない。
- 既存の regression: `adopt_preference_for!`
  の merge 失敗がログイン自体を壊さないこと（現状 rescue で担保済み、(2)(3)の変更後も維持を確認）。
- last sign-in method badge: 主認証成功時のみ書き込み、MFA失敗・step-upでは上書きしない、principal
  Preferenceには一切現れない。

詳細チェックリストは `plans/project-umaxica-preference-humble-blossom.md` §11を参照。

---

## 11. 未確認・Assumption

- Preference public cookie の `domain: true`（apex
  scope）が実際にどのサブドメインから読めるかは、本監査では cookie
  option の記述レベルまでの確認に留まり、ブラウザでの実測は行っていない（`Assumption` 扱い）。
- 既存テストの実行結果（baseline
  vs 編集後の diff）は今回の監査では取得していない——本メモは調査・設計のみで、実装をしていないため。次パスで (2)(3) を実装する際は
  `test/controllers/concerns/preference/adoption_test.rb` を baseline として使うこと。
