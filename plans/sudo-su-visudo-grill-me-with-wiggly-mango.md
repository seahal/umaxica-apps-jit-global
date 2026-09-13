# 開発コンテナの sudo/su/visudo 廃止 — 監査と bundle install バグ修正

## Context

依頼文は「sudo/su/visudo をゼロから排除し、UID/GID・所有権・マウント設計を再設計する」という広範な内容だったが、Grill
Me で実コードを読んだ結果、次のことが判明した。

- `sudo` / `su` / `visudo` / `sudoers` / `NOPASSWD`
  は本番・開発の両ステージで既に排除済みか、そもそも導入されていない。
- `devcontainer.json` の
  `remoteUser`/`containerUser`/`updateRemoteUserUID`、`.devcontainer/compose.override.yml` の
  `keep-id` + `DOCKER_UID`/`DOCKER_GID` は既に権限モデルの原則（ホスト UID/GID への追従、bind
  mount 所有権の一致）に沿って設計済み。
- ホスト側リポジトリに root 所有ファイルは存在しない。

ユーザーへのヒアリングで、実際に困っている症状は **`bundle install`/`bundle update`
が非 root ユーザー（`global`）で権限エラーになる**
ことだと判明した。調査の結果、これは sudo の欠如が原因ではなく、`development`
Docker ステージ固有の所有権バグだった。ユーザーは今回のスコープとして、この本質的バグの修正に加え、監査中に見つかった副次的な問題（UID/GID 未エクスポート）も合わせて修正することを希望した。一方で、`compose.yaml`
の常時 root サービス（kafka/loki/tempo/prometheus）と開発イメージの `su`
バイナリ削除は、リスクとリターンを検討した結果、現状維持（対応見送り、理由をドキュメント化）と決定した。

## 本質的な修正: `/usr/local/bundle` の所有権バグ

**原因**（`Dockerfile`）:

- `development-base` ステージの `RUN gem update --system && gem install bundler`（174-175行目）が
  **root** として実行され、`GEM_HOME=/usr/local/bundle`（ベースイメージ `ruby:trixie`
  が設定、`production` と異なり `development` 系ステージは
  `BUNDLE_PATH`/`BUNDLE_APP_CONFIG`/`GEM_HOME`
  を一切上書きしていない）配下に root 所有ファイルを作る。
- `development`
  ステージの「最終所有権修正」（274-275行目、`chown -R "${DOCKER_UID}:${DOCKER_GID}" "${HOME}"`）は
  `$HOME` のみが対象で `/usr/local/bundle` を含まない。
- `docker/core/entrypoint.sh` も `/tmp` 系と `workspace/tmp`, `workspace/log` のみが対象で
  `/usr/local/bundle` は対象外。かつ `keep-id`
  経路（現在の devcontainer 構成）では chown 処理自体が完全にスキップされる（entrypoint.sh
  45-54行目の早期 exec 分岐）。
- `production` ステージは同じ構造の問題を
  `COPY --from=production-build --chown=${DOCKER_UID}:${DOCKER_GID} /usr/local/bundle /usr/local/bundle`（128行目）で正しく回避しているが、この処理が
  `development` に引き継がれていない。

**修正**: `Dockerfile` の `development` ステージ、既存の「Final ownership fix for the home directory
and workspace」（274-275行目）を拡張し、`/usr/local/bundle` も対象に含める。

```dockerfile
# Final ownership fix for the home directory, workspace, and bundler's own
# GEM_HOME (gem install bundler above runs as root; production handles this
# via COPY --chown, development has no equivalent step).
RUN mkdir -p "${HOME}/workspace" \
    && chown -R "${DOCKER_UID}:${DOCKER_GID}" "${HOME}" /usr/local/bundle
```

`vendor/bundle`（アプリの gem 本体、`.bundle/config` の `BUNDLE_PATH: vendor/bundle` および
`compose.yaml:27` の環境変数で指定）は named volume
`umaxica-bundle`（`compose.yaml:193-195`）にマウントされており、今回のバグとは別物。ホスト上の
`vendor/bundle` は現状 `mslo:mslo`
で一致しているため今回は対象外とするが、修正後の必須テストで named
volume 経由の書き込み可否も確認する。

## 副次的な修正: UID/GID のホスト追従が壊れている

現在のシェルでは `$UID`/`$GID` が export されていない（`env | grep '^UID='`
は空）。`.devcontainer/compose.override.yml:9-10` の `DOCKER_UID: "${UID:-1000}"` /
`DOCKER_GID: "${GID:-1000}"` は、これらが export されていない限り常にリテラル `1000`
にフォールバックする。このホストでは実 UID/GID がたまたま 1000/1000 のため問題が表面化していないが、他ホスト・他開発者では UID/GID 不一致によるファイル所有権の破綻に直結する潜在的なバグである。

**修正**: `.devcontainer/devcontainer.json` に `initializeCommand`
を追加し、ホスト側で実行される devcontainer ビルド前フックとして、実際の `id -u`/`id -g` を
`.devcontainer/.env`（gitignore 対象、新規追加）に書き出すスクリプトを用意する。`docker compose`/`podman compose`
は起動ディレクトリの `.env` を自動読み込みするため、手動で `podman compose`
を叩く場合も同じスクリプトを一度実行すれば `${UID:-1000}`/`${GID:-1000}`
が正しいホスト値を拾うようになる。

- 新規スクリプト: `.devcontainer/write-host-ids.sh`（`id -u`/`id -g` を `.devcontainer/.env` に
  `UID=`/`GID=` として書き出すだけの小さいスクリプト）
- `devcontainer.json` に `"initializeCommand": ".devcontainer/write-host-ids.sh"` を追加
- `.gitignore` に `.devcontainer/.env` を追加
- 手動 `podman compose`
  運用者向けに、`docs/operations/development-container-targets.md`（既存ファイル）へ一言、事前に
  `.devcontainer/write-host-ids.sh` を実行する旨を追記

## 対応を見送った項目（実装しない、理由を記録する）

これらはユーザーの判断で見送り。実装時にコードコメントではなく `implementation-notes.mdc`
の運用に従い、判断記録として残す（AGENTS.md の指示に基づき、決定理由はコードコメントではなく実装ノート/ハンドオフ資料に記録する）。

1. **`compose.yaml` の `kafka`/`loki`/`tempo`/`prometheus` の常時
   `user: root`**: 監査の結果、これら4サービスの公式イメージは本来非rootデフォルトで、root→非root降格の内部機構を持たない（`grafana`/`pgadmin`/`rustfs-permissions`
   とは異なる）。rootless Podman の named
   volume 書き込み可能化のために全ライフサイクル root で固定されている。`rustfs-permissions`
   と同様の使い捨て init コンテナによる chown パターンへの置き換えが技術的には可能だが、今回はスコープ外として現状維持。
2. **開発/workspace イメージからの `su` バイナリ削除**: `su` は `util-linux`
   パッケージ由来（Dockerfile:254 で明示インストール、`docker/core/entrypoint.sh` が使う `setpriv`
   の提供元でもある）。`production` ステージと同様に `rm -f /usr/bin/su /usr/sbin/su`
   でバイナリのみ削除することは技術的に可能だが、`workspace`
   ステージのネスト化 Podman や tailscale スーパーバイザーが `su`
   を使うコードパスがないか、実ビルド後のコンテナでの検証が必要という不確実性があるため、今回は見送り。`sudo`
   が既に不在のため、非 root ユーザーが `su`
   を実行してもパスワード認証で失敗し、実質的な権限昇格経路にはならない点を根拠とする。

## 実装対象ファイル

- `Dockerfile` — 274-275行目の chown 対象に `/usr/local/bundle` を追加
- `.devcontainer/write-host-ids.sh` — 新規作成
- `.devcontainer/devcontainer.json` — `initializeCommand` 追加
- `.gitignore` — `.devcontainer/.env` を追加
- `docs/operations/development-container-targets.md` — 手動 `podman compose`
  利用時の UID/GID 反映手順を一言追記

## 検証

- `podman compose build --no-cache core` でイメージを再ビルド
- `podman compose up -d` 後、以下を非 root で確認:
  - `podman exec core sh -lc 'id; bundle check || bundle install; bundle exec ruby -v'`
  - `podman exec core sh -lc 'test -w /usr/local/bundle && echo writable'`
- `.devcontainer/write-host-ids.sh` を実行し `.devcontainer/.env` が実際のホスト `id -u`/`id -g`
  と一致することを確認
- 既存の sudo 不在確認（`! command -v sudo`,
  `! command -v visudo`）は変更後も引き続き true であることを確認（今回の変更が新たに sudo を持ち込まないことの回帰確認）
