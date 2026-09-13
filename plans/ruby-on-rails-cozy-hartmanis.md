# Ruby 4.0.5 → 4.0.6 バージョンアップ

## Context

Podman イメージを焼き直すにあたり、Ruby のバージョンを 4.0.5 から 4.0.6 に上げたい。Rails 自体は
`github: "rails/rails", branch: "main"` で git 追従しており（現在
`8.2.0.alpha`、`load_defaults 8.2`）、"4.0.6" が指しているのは Rails ではなく Ruby のパッチバージョンであることを本人に確認済み。修正箇所が複数ファイルに分散しているため、一括で洗い出して番号を打ち直す。

## 修正対象ファイル（Ruby バージョンの正本のみ、6 箇所・4 ファイル）

1. `Gemfile:5` — `ruby "4.0.5"` → `ruby "4.0.6"`
2. `.ruby-version:1` — `4.0.5` → `4.0.6`
3. `Dockerfile:6` — `ARG RUBY_VERSION=4.0.5` → `ARG RUBY_VERSION=4.0.6`
4. `.github/workflows/integration.yml:28` — `RUBY_VERSION: "4.0.5"` → `"4.0.6"`
5. `.github/workflows/integration.yml:464` — `build-args: RUBY_VERSION=4.0.5` → `RUBY_VERSION=4.0.6`
6. `Gemfile.lock:1618` — `ruby 4.0.5` → `ruby 4.0.6`（`bundle install` / `bundle lock`
   の再実行で自動的に更新されるはずなので、手編集ではなく bundler 経由で反映する）

## 対象外（意図的に触らない）

- `pnpm-lock.yaml` の `picomatch@4.0.5` は無関係な npm パッケージのバージョンなので触らない。
- `memos/2026-06-24-*.md`, `memos/2026-06-23-sign-settings-audit.md`,
  `plans/you-are-working-in-enchanted-sunbeam.md` に "Ruby
  4.0.5" の記述があるが、これらは当時の監査記録・スナップショットなので更新しない（過去の事実の記録として残す）。

## 手順

1. `Gemfile`, `.ruby-version`, `Dockerfile`, `.github/workflows/integration.yml`
   の 4 ファイル・5 箇所を `4.0.5` → `4.0.6` に置換する。
2. ローカルに Ruby 4.0.6 がインストールされていれば `bundle install` を実行して `Gemfile.lock` の
   `ruby 4.0.6`
   を反映する。インストールされていない場合は rbenv/asdf 等で 4.0.6 を導入してから実行する（環境に依存するため、実行前に手元の Ruby 管理ツールの状態を確認する）。
3. Podman イメージのビルドは本計画の範囲外（ユーザーが自分で焼き直す）。ただし `Dockerfile` の
   `ARG RUBY_VERSION` が更新されていれば `podman build`
   時に自動的に 4.0.6 ベースイメージ（`ruby:4.0.6-slim-trixie` / `ruby:4.0.6-trixie`）が使われる。

## 検証

- `ruby -v`（コンテナ内、または `podman run` 後）で `4.0.6` になっていることを確認する。
- `bundle exec rails -v` で Rails 側の読み込みに問題がないことを確認する。
- `bin/rails test` を実行し、Ruby バージョン変更による既存テストへの影響がないことを確認する。
- CI（`.github/workflows/integration.yml`）が新しい `RUBY_VERSION` でグリーンになることを確認する。
