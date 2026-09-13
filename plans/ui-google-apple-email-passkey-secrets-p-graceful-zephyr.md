# 「前回使ったサインイン方法」バッジ(最終使用ヒント)の調査結果

## Context

Cloudflare のサインイン画面にある「最終使用」バッジのように、前回どの方法 (email / passkey /
secret_credential / Google / Apple /
Entra) でサインインしたかをブラウザ側に記録し、次回のサインイン画面でハイライトしたい。作者の案は「preference 系に保存する」。本ファイルはその妥当性の調査メモ(実装はしない)。

## 現状の確認結果

- **「最終使用メソッド」の記録は現状どこにも存在しない。** `auth_method` は
  `app/controllers/concerns/authentication_base.rb` の `establish_signed_in_session!` /
  `set_pending_mfa!`
  で監査・セッション確立時に一時的に扱われるだけで、クライアント可視のヒントとしては永続化されていない。新規機能になる。
- **preference 系は非ログイン(ゲスト)でも動く。** `preference_core.rb` の
  `ensure_preferences_record` は `current_resource` に依存せず `create_if_missing: true`
  でトークン付きレコードを作る。値は `preference_refresh`/`preference_access` クッキー (`__Host-`
  プレフィックス、TTL 400日、 `preference_base.rb` の `REFRESH_TOKEN_TTL`) で運ばれる。
- 短い公開クッキー (`ct`=theme, `tz`, `cu` など、`preference_io_keys.rb`) は `httponly: false`
  で JS からも読め、サーバ側は preference テーブルに dual-write
  (`update_preference_child_dual_write!`) される。
- サインイン方法はサーフェスごとに違う (app: email/passkey/secret/Google/Apple、com:
  email/passkey/secret、org: passkey/secret/Entra)。preference は
  `AppPreference`/`ComPreference`/`OrgPreference`
  とサーフェス別に分かれているので、この点も preference 系と相性が良い。

## 評価: preference 案は妥当

理由:

1. 非ログイン状態で読める必要がある(サインイン画面はログイン前)——preference はまさにゲスト状態で動く唯一の永続レイヤ。auth クッキーはサインアウトで消えるので不適。
2. これは純粋な UX ヒントであり、セキュリティ判断には一切使わない前提なら theme や language と同格の「表示設定」として扱える。既存の
   `*_preference_theme` 等と同じ child テーブル + 短い公開クッキー (例: `lm` = last
   method) のパターンをそのまま踏襲できる。
3. TTL 400 日はこの用途にちょうど良い。

## 留意点(採用時の設計判断)

- **書き込みタイミング**: サインイン成功時 (`establish_signed_in_session!`
  到達時) のみ記録する。失敗した試行を記録するとヒントが汚れる。
- **per-browser の性質**: passkey はデバイス固有なので、resource 側ミラー (`VisitorPreference`
  等) への dual-write を theme と同様に行うと、別デバイスで「このブラウザには無い passkey」を推してしまう可能性がある。→ クッキー値をミラー値より優先する(またはこのキーだけ resource ミラーをしない) 判断が必要。これは実装時の主要な論点。
- **プライバシー**: 非 httponly クッキーに「Google でログインする人」という情報が乗る。theme 同様の軽い情報と割り切れる範囲だが、値は enum の短いコード (例:
  `em/pk/sc/gg/ap/et`) にして生の provider 名を晒さない程度の配慮はしてよい。
- **サーフェス別 enum**: 許容値はサーフェスごとに違うので、検証はサーフェス別ホワイトリストにする(app の
  `gg`
  を org が受け取ったら無視して default に落とす、ではなく明示的に破棄——no-silent-fallback 方針に沿って「不正値は未設定扱い」を明文化)。

## 実装する場合の骨子(参考、今回はやらない)

1. child テーブル `{app,com,org}_preference_sign_in_method` +
   resource ミラー列を追加 (ミラー要否は上記論点の決定次第)。
2. `preference_io_keys.rb` に公開クッキーキー(例 `lm`)を追加、 `preference_core.rb`
   に setter を追加。
3. `authentication_base.rb` のサインイン成功パスから preference 書き込みを呼ぶ。
4. `sign_ins/new.html.erb` (各サーフェス) でクッキーを読み「最終使用」バッジ表示。
5. テスト: サインイン成功で記録される/失敗では記録されない/不正値は無視、の各ケース。

## Verification(実装時)

- `bin/rails test test/controllers/auth/{app,com,org}/` の sign-in 系テスト
- ブラウザでゲスト状態 → email サインイン → サインアウト → 再訪でバッジ表示を目視
