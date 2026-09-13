# config/routes の「nasty entrypoint」FIXME 解消リファクタリング

## 追記: auth.rb / base.rb の確認結果(実装不要)

ユーザ依頼によりリファクタ実装後に `config/routes/auth.rb` と `base.rb` を確認。

- `base.rb`: `FIXME`/`TODO` は0件。この2ファイルは今回の "nasty
  entrypoint" 解消で手本にしたクリーンなルート定義であり、`to:`
  越境や複合名詞の問題は元から存在しない。
- `auth.rb`: 唯一のマーカーは199行目 `# TODO: cache passkeys/passkey lookups.`
  (`resources :passkeys`
  上)。これはルーティング規約違反(FIXME)ではなくパフォーマンス改善の別カテゴリの TODO。

ユーザ確認の結果、このTODOは今回のスコープ外として対応しない方針。**追加の実装作業なし。**

## 追記2: config/routes/{news,info}.rb の同様のFIXME解消

`info.rb`(3箇所)・`news.rb`(3箇所の`param: :slug` + 3箇所の`module: :entries`)に、docs.rbと同型の
`# FIXME: remove param: :slug !` / `# FIXME: remove module: :entries !` が残っていた。

- `param: :slug`: パスセグメントを公開識別子に変える設定。ADRの禁止リスト対象外で route は resourceful。
- `module: :entries`(newsのみ): `resources :revisions` を `entries/revisions_controller.rb`
  (`News::App::Api::V0::Entries::RevisionsController`
  等)にネストさせるために必要。これも禁止リスト対象外。

docs.rbで採った方針と同じく、ルートは変更せず FIXME を事実コメントに置換。
`help.rb`にも同型の`# FIXME: remove module: :entries !`が1箇所残っているが、ユーザ指示のスコープ (news.rb/info.rbのみ)外のため今回は未対応。

検証:
`bin/rails test test/integration/routes/info_route_contract_test.rb test/integration/routes/news_route_contract_test.rb test/integration/docs_help_news_revisions_test.rb test/controllers/help_docs_news_surface_smoke_test.rb`
— 12 runs, 0 failures。

## Context

`config/routes/side.rb` などに残る `# FIXME: nasty entrypoint!` は、resourceful
routing ポリシー (`adr/rails-routing-resourceful-policy.md`、コミット b2aef365aa で導入) に違反する箇所への自己フラグ。違反の実体は 2 種類:

1. **oidc ルートの `to:` 越境指定** — コントローラが `<realm>/<surface>/auth/` にあるのに routes は
   `namespace :oidc` のため `to: "/side/app/auth/authorizations#show"` が必要になっている。
   `auth.rb` / `base.rb` はコントローラを `oidc/` 配下に置くことで `to:`
   なしを実現済み(これが手本)。
2. **sign_out の複合名詞 + `path: "sign/out"`** — `auth.rb` は
   `namespace :sign { resource :termination, path: "out", controller: :outs, as: :out }` 形式。

ユーザ承認済みスコープ: **side.rb / core.rb / palm.rb /
docs.rb 全部**(core.rb は FIXME 無しだが同型)。sign_out は **auth.rb 型へ再構成**。

**不変条件**: 公開 URL (`/oidc/authorization`, `/oidc/callback`, `/sign/out`,
`/sign/out/complete`) と helper 名 (`side_app_sign_out_path`, `*_oidc_authorization_path`
等) は一切変えない。 `namespace :sign` + `as: :out`
は現行と同一の helper 名を生成することを検証済み。redirect_uri は `OidcClientRegistry` 由来(route
helper 非依存)のため外部登録への影響なし。view は全て明示テンプレート文字列で render されているため
**view ディレクトリは移動しない**。

## 変更内容

### 1. oidc コントローラの移設 (Auth → Oidc モジュール、git mv + module 名変更のみ)

| 旧                                                                                 | 新                                                                                                   |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `app/controllers/side/{app,com,org}/auth/{authorizations,callbacks}_controller.rb` | `app/controllers/side/{app,com,org}/oidc/...` (`Side::X::Auth::*` → `Side::X::Oidc::*`)              |
| `app/controllers/core/{app,com,org}/auth/{authorizations,callbacks}_controller.rb` | `app/controllers/core/{app,com,org}/oidc/...`(既存の `oidc/backchannel/` と同居)                     |
| `app/controllers/palm/app/auth/authorizations_controller.rb`                       | `app/controllers/palm/app/oidc/authorizations_controller.rb`                                         |
| `app/controllers/palm/app/oauth/callbacks_controller.rb`                           | `app/controllers/palm/app/oidc/callbacks_controller.rb` (`Palm::App::Oauth::` → `Palm::App::Oidc::`) |

- routes: 各 `namespace :oidc` 内の `to:` と FIXME を削除し `resource :authorization, only: :show` /
  `resource :callback, only: :show` に。
- palm.rb は 2 つに分かれている `namespace :oidc` ブロックを 1 つに統合。
- 空になった `side/*/auth/`, `palm/app/auth/`, `palm/app/oauth/`(空の `oauth/callback/`
  含む)を削除。
- **注意**: `core/{com,org}/auth/logouts_controller.rb` は未配線(backchannel は
  `oidc/backchannel/logouts` が担当)。スコープ外として `auth/`
  ディレクトリごと残す(authorizations/callbacks のみ移動)。

### 2. sign_out の auth.rb 型再構成 (side ×3, core ×3, palm ×1)

routes (side/core、パスと helper は不変):

```ruby
namespace :sign do
  resource :termination, only: %i(new edit create), path: "out", controller: :outs, as: :out do
    resource :completion, only: :show, path: "complete", module: :outs
  end
end
```

palm は
`resource :termination, only: %i(show create), path: "out", controller: :outs, as: :out`(completion なし)。

コントローラ移設(クラス本体は無変更、モジュール入れ子と completions の親クラス参照のみ更新):

| 旧 | 新 | | ---------------------------------- |
------------------------------------------------------- |
----------------------------------------------------------------------------------- | |
`side                              | core/{app,com,org}/sign_outs_controller.rb` |
`.../sign/outs_controller.rb` (`X::SignOutsController` → `X::Sign::OutsController`) | |
`side                              | core/{app,com,org}/sign_outs/completions_controller.rb` |
`.../sign/outs/completions_controller.rb` | | `palm/app/sign_outs_controller.rb` |
`palm/app/sign/outs_controller.rb` |

`render "auth/shared/sign_outs/edit"` 等の明示 render、`sign_out_notice.rb` /
`acme_logout_transaction_coordinator.rb` の動的 helper 組み立ては helper 名不変のためそのまま。

### 3. docs.rb — FIXME をコメント置換のみ

`param: :slug` は ADR の禁止リスト対象外で route は完全に resourceful。FIXME を削除し、 `param:`
はパスセグメント名の変更にすぎず routing 例外ではない旨の事実コメントに置換。

### 4. テスト更新・追加

- 期待コントローラ文字列の更新:
  `test/integration/routes/core_route_contract_test.rb`(auth→oidc、sign_outs→sign/outs)、
  `palm_route_contract_test.rb`、`test/integration/core_rp_browser_flow_test.rb`、
  `test/controllers/core/auth_boundary_test.rb`、`test/controllers/palm/app/oauth_boundary_test.rb`。
- クラス定数参照: `test/controllers/concerns/oidc/rp_identity_provisioning_test.rb` の
  `Core::App::Auth::CallbacksController` → `Core::App::Oidc::CallbacksController`。
- パス許可リスト: `test/security/invariants/forbidden_patterns_invariant_test.rb:223`、
  `test/unit/security/redirect_target_usage_test.rb:28-29`、
  `test/controllers/controller_inheritance_invariant_test.rb:50-55`、
  `test/unit/security/public_entrypoint_inventory_test.rb:194`(`end_with?("/sign_outs", "/sign/outs")`
  に拡張)。
- テストファイルのリネーム: `test/controllers/{side,core}/*/sign_outs_controller_test.rb` →
  `.../sign/outs_controller_test.rb`、`test/controllers/palm/app/oauth/callbacks_controller_test.rb`
  → `.../oidc/callbacks_controller_test.rb`(クラス名も追従)。
- **route 契約テストの拡充**:
  `test/integration/routes/side_route_contract_test.rb`(現状 roots のみ)に各サーフェスの
  `/oidc/authorization`・`/oidc/callback`・`/sign/out`(new/edit/create)・`/sign/out/complete` の
  `recognize_path` と DELETE `/sign/out` の RoutingError を追加。palm にも `/sign/out`
  認識を追加。これがパス不変の証明になる。

### 5. ADR 例外台帳更新 (`adr/rails-routing-resourceful-policy.md`)

- `to:` override の行を「2026-07-14 にコントローラを oidc/ へ移設して解消」として更新/退役。
- `path: "sign/out"` 行を新形式(`namespace :sign` + `path:`/`controller:`/`as:`
  override)と対象ファイル(core.rb, palm.rb 追加)で更新。

## 検証

1. `bin/rails routes | grep -E "sign/out|oidc/(authorization|callback)"` でパス不変を目視。
2. `bin/rails test test/integration/routes/` → 移設対象のコントローラテスト → concerns/oidc →
   boundary テスト。
3. `bin/rails test test/unit/security/ test/security/ test/controllers/controller_inheritance_invariant_test.rb`。
4. `bin/rails zeitwerk:check`(あれば)→ 最後に `bin/rails test` 全体。

## リスク

- Zeitwerk: ファイルパスとモジュール入れ子の完全一致が必須。completions の親クラス参照更新を同時に行う。
- 文字列パスの許可リストテストはリネーム漏れがあれば大きく失敗する(先に回すことで検知)。
- Sorbet RBI なし(全ファイル `# typed: false`)、view 移動なし、i18n 影響なし。
