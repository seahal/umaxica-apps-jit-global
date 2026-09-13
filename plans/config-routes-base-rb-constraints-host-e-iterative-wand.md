# Context

`config/routes/` の全ファイルで `constraints host:` のホスト解決方法がバラバラになっている。

- `base.rb` → `ENV.fetch("PUBLIC_BASE_SERVICE_URL")` + `URI.parse(...).host`（Rails ネイティブ）
- `auth.rb`, `palm.rb`, `side.rb`, `info.rb`, `help.rb` →
  `boot_config.fetch(:hosts).xxx.host`（独自層）
- `core.rb` →
  `ENV["PUBLIC_CORE_SERVICE_URL"] || ENV["CORE_SERVICE_URL"]`（フォールバック付き、fetch なし）
- `docs.rb`, `news.rb` → `ENV["PRIVATE_DOCS_SERVICE_URL"]`（nil 許容）

目標: 独自実装の `boot_config` を routes から排除し、`ENV.fetch` + `URI.parse` に統一する。

---

# 方針

`base.rb` のパターンを正とする:

```ruby
constraints host: URI.parse(ENV.fetch("HOST_VAR")).host do
```

- **必須ホスト**（auth, core, palm, side/base, help, info）→ `ENV.fetch` 必須
- **オプショナルホスト**（docs, news）→ `ENV["..."]` のままで良い（nil を `.compact` で除去）
- **net/dev ホスト** → env 設定済みなので `ENV.fetch` + `URI.parse` に統一
- dev 用 localhost フォールバック（ハードコード文字列）は不要 — dev の ENV 変数を localhost
  URL に設定すれば `URI.parse(...).host` が `"auth.app.localhost"` を返す

---

# 変更対象ファイルと ENV 変数名

## auth.rb（現在: boot_config）

```ruby
# 変更前
hosts = Rails.configuration.x.boot_config.fetch(:hosts)
auth_surface :app, host: [hosts.auth_service.host, "auth.app.localhost"]

# 変更後（dev では AUTH_SERVICE_URL=http://auth.app.localhost を設定すればよい）
auth_surface :app, host: URI.parse(ENV.fetch("AUTH_SERVICE_URL")).host
auth_surface :com, host: URI.parse(ENV.fetch("AUTH_CORPORATE_URL")).host
auth_surface :org, host: URI.parse(ENV.fetch("AUTH_STAFF_URL")).host
```

`hosts =` のローカル変数定義行（L15）を削除。

## palm.rb（現在: boot_config）

```ruby
# 変更前
boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
constraints host: [boot_hosts.palm_service.host, "palm.app.localhost"].compact

# 変更後
constraints host: URI.parse(ENV.fetch("PALM_SERVICE_URL")).host
```

`boot_hosts =` 行（L6）を削除。

## side.rb（現在: boot_config）

`side_service` は `base_service` のエイリアス。base*key ロジックは `SIDE_SERVICE_URL` →
`BASE_SERVICE_URL` → `PUBLIC_BASE_SERVICE_URL` の順で参照する。`base.rb` との一貫性から
`PUBLIC_BASE*\*\_URL` を使う（base.rb と同一ホスト）。

```ruby
# 変更前
boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
constraints host: [boot_hosts.side_service.host, "side.app.localhost"].compact

# 変更後
constraints host: URI.parse(ENV.fetch("PUBLIC_BASE_SERVICE_URL")).host
constraints host: URI.parse(ENV.fetch("PUBLIC_BASE_CORPORATE_URL")).host
constraints host: URI.parse(ENV.fetch("PUBLIC_BASE_STAFF_URL")).host
```

`boot_hosts =` 行（L6）を削除。

## info.rb（現在: boot_config）

```ruby
# 変更前
boot_config = Rails.configuration.x.boot_config
constraints host: [boot_config.fetch(:hosts).info_service.host, "info.app.localhost", "info.umaxica.app"].compact

# 変更後（ハードコードの alias ドメインは docs/news の PRIVATE_ パターンと異なり不要なら除く）
constraints host: URI.parse(ENV.fetch("INFO_SERVICE_URL")).host
constraints host: URI.parse(ENV.fetch("INFO_CORPORATE_URL")).host
constraints host: URI.parse(ENV.fetch("INFO_STAFF_URL")).host
```

`boot_config =` 行（L6）を削除。

## help.rb（現在: boot_config）

```ruby
# 変更前
boot_config = Rails.configuration.x.boot_config
constraints host: [boot_config.fetch(:hosts).help_service.host].compact

# 変更後
constraints host: URI.parse(ENV.fetch("HELP_SERVICE_URL")).host
constraints host: URI.parse(ENV.fetch("HELP_CORPORATE_URL")).host
constraints host: URI.parse(ENV.fetch("HELP_STAFF_URL")).host
```

`boot_config =` 行（L6）を削除。

## core.rb（現在: ENV["..."] || ENV["..."]、fetch なし）

AGENTS.md ルール: 必須設定は `ENV.fetch` のみ（デフォルト引数不可）。

```ruby
# 変更前
constraints host: [ENV["PUBLIC_CORE_SERVICE_URL"] || ENV["CORE_SERVICE_URL"], "core.app.localhost"].compact

# 変更後（AppConfigLoader の canonical 名は CORE_SERVICE_URL）
constraints host: URI.parse(ENV.fetch("CORE_SERVICE_URL")).host
constraints host: URI.parse(ENV.fetch("CORE_CORPORATE_URL")).host
constraints host: URI.parse(ENV.fetch("CORE_STAFF_URL")).host
constraints host: URI.parse(ENV.fetch("PRIVATE_CORE_NETWORK_URL")).host
constraints host: URI.parse(ENV.fetch("PRIVATE_CORE_DEVELOPER_URL")).host
```

## docs.rb, news.rb（変更なし）

`PRIVATE_DOCS_*_URL` / `PRIVATE_NEWS_*_URL`
はオプショナル（未設定時は .compact で除去、ハードコード済みドメインでカバー）。`ENV["..."]`
のまま据え置く。

## base.rb（部分変更）

主要 3 サーフェスはすでに正しいパターン。net/dev を更新:

```ruby
# 変更前
constraints host: ENV["PRIVATE_BASE_NETWORK_URL"] || ENV["BASE_NETWORK_URL"]
constraints host: ENV["PRIVATE_BASE_DEVELOPER_URL"] || ENV["BASE_DEVELOPER_URL"]

# 変更後
constraints host: URI.parse(ENV.fetch("PRIVATE_BASE_NETWORK_URL")).host
constraints host: URI.parse(ENV.fetch("PRIVATE_BASE_DEVELOPER_URL")).host
```

---

# 変更しないもの

- `config/auth_route_mapper.rb` — `auth_surface` マクロ自体は変更不要（host: 引数を受け取るだけ）
- `lib/app_config_loader.rb` 以下 —
  routes からの呼び出しがなくなるだけで他の用途（CSP、サービス層など）では引き続き使用

---

# 検証

```bash
# 変更後、全ルート確認
bin/rails routes | grep -E "(auth|palm|side|info|help|core)_"

# 起動時エラーがないか確認（ENV が揃っていることが前提）
bin/rails runner "puts Rails.application.routes.routes.count"

# ルーティングテストがあれば実行
bin/rails test test/routing/
```
