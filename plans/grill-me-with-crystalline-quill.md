# Mac Codex App → Podman 内 Rails 開発コンテナへの Remote SSH 接続 — 調査結果と実装計画

日付: 2026-07-19 / 対象: `seahal/umaxica-apps-jit-global` / 承認後は本レポートを `memos/`
へ日付付きで保存する運用に従う。

## Context

Mac の ChatGPT Desktop (Codex App) の Remote SSH 機能から、Linux Desktop 上の rootless Podman で動く
`core` 開発コンテナ (`global-devcontainer-core`) に直接 SSH し、コンテナ内の `codex app-server` を
`global` ユーザーとして起動したい。Linux ホストへは sshd / tailscaled /
Codex を一切入れず、ホストへのポート公開もしない。

## 1. Executive summary

- **推奨案: 案A' (Tailscale sidecar + JSON `TCPForward` で `core:22`
  へ転送、フォールバックとして sidecar 内 socat)**。
- **採用理由**: rootless Podman で userspace networking
  (TUN 不要・capability 不要) のまま動き、`core` の既存 4 ネットワーク構成・Dev
  Container 構成を一切変えない。SSH 終端は `core` 内 OpenSSH。
- **不採用**: 案B (`network_mode: service:`) は podman-compose で既知バグがあり、`core`
  の複数ネットワーク (backend/frontend/observability/outer + 大量 alias) と両立不可能。案C
  (core へ tailscaled 同居) は entrypoint 複雑化と 1 コンテナ 1 責務違反。案D (ホスト経由
  `podman exec`) はホスト sshd という攻撃面追加そのもので要件違反。Tailscale SSH は不使用 (`--ssh`
  を渡さない)。
- **未解決事項 (スパイク必須)**: ①`TS_SERVE_CONFIG` の `TCPForward: "core:22"`
  (非 localhost 宛) はソースコード上サポートされるが KB 未文書化 ②Codex App Remote SSH が
  `AllowTcpForwarding no` / PTY なしで動くか ③codex の非対話シェル PATH 解決 ④任意 cwd
  `/home/global/workspace` を開けるか。
- **セキュリティ判定**: 「ホストへの脆弱性ゼロ」は不可能だが、ホスト側の追加攻撃面 (sshd/tailscaled/Codex/ポート公開/Podman
  socket) は **ゼロ**。残存リスクはカーネル・ランタイム・イメージ supply
  chain・コンテナ内エージェント。blast radius はコンテナ + マウント済み認証情報に限定。

## 2. Current-state findings (リポジトリ現状)

- `compose.yaml:4-245` — `core`: build target 指定なし → Dockerfile 最終 stage `development`
  が使われる。entrypoint `docker/core/entrypoint.sh` (12-14 行)、command `bin/dev`。networks:
  `backend` / `frontend`(大量 alias, 178-234 行) / `observability` / `outer`(alias `global`,
  236-238 行)。ports は base では未公開。
- `compose.yaml:506-512` — networks は全て通常 bridge (`internal: true` なし)。`outer`
  のみ external 可変。
- `compose.yaml:492-505` — 既存の外部 ingress は `cloudflare-tunnel`
  のみ。secrets/env_file 機構は未使用 (`.env` + inline environment)。
- `Dockerfile` — Debian trixie ベース (apt-get)。`development` stage (199 行〜) : `global`
  (UID/GID は build arg、shell `/bin/bash`、**passwordless sudo あり**、257 行)。`production` stage
  (113 行〜) は root ロック・sudo 削除済みで SSH 無関係を維持できる。socat は dev に導入済み (216-248 行)。openssh-server は未導入。
- `.devcontainer/devcontainer.json:3` — `dockerComposeFile`
  は配列で追加 compose ファイルを足せる。`remoteUser: global`。codex は Dockerfile ではなく feature
  `ghcr.io/jsburckhardt/devcontainer-features/codex:1` (92-97 行) で導入。`~/.codex` は host から
  **rw bind mount** (116 行)、`~/.ssh` は **readonly mount** (121 行)。
- `.devcontainer/compose.override.yml:11` — `userns_mode: keep-id`。ports
  3000/3036 のみ公開 (36-38 行)。workspace bind mount (30-35 行)。
- `docker/core/entrypoint.sh` — `global` として実行、sudo で tmpfs chown 後
  `exec "$@"`。root→降格構造ではない。
- `.gitignore:60,62` — `.ssh`/`.envrc`
  は ignore 済み。docs/adr/plans に tailscale・sshd の言及は皆無 (新規領域)。

## 3. Official documentation findings

- **Tailscale** — `TS_USERSPACE` はデフォルト `true`
  で TUN/NET_ADMIN/NET_RAW 不要 (tailscale.com/docs/concepts/userspace-networking,
  docker-params)。`TS_AUTH_ONCE` は非推奨ではなくデフォルト `false`。CLI `tailscale serve`
  の TCP 転送先は **localhost 限定** [FACT]。一方 `TS_SERVE_CONFIG` JSON の `TCPForward`
  はソース (`ipn/serve.go`) 上 remote host:port を許容 [FACT/未文書化→SPIKE] (issue
  #19511 に実例)。auth key 失効は登録済みノードを無効化しない → state volume + `TS_AUTH_ONCE=true`
  でキー削除後も再起動可 [FACT]。**tagged node は key expiry がデフォルト無効**
  → 長期運用に必須 (blog/tagged-key-expiry)。Podman は公式に「alternative
  manager」としてサポート言及あり。grants で `tcp:22` を src 制限可能。
- **Codex** — Remote SSH は `~/.ssh/config` の**具体的 Host** を読む (pattern-only は無視)
  [FACT]。リモートのログインシェル PATH に `codex` が必要、**自動インストールなし**
  [FACT]。`codex app-server` は stdio JSON-RPC (SSH exec チャネル)、TCP デーモン不要 [FACT]
  (developers.openai.com/codex/app-server, codex-rs/app-server)。`AllowTcpForwarding no` /
  `PermitTTY` 可否は未記載 → SPIKE。`ForceCommand` はほぼ確実に破壊する → 使わない。
- **OpenSSH** — `AuthorizedKeysFile` は絶対パス可。home 外の root 所有・0644
  read-only ファイルで StrictModes を満たせる [FACT] (man.openbsd.org/sshd_config)。非対話
  `ssh host cmd` の PATH は sshd 既定 (`_PATH_STDPATH`) → `codex`
  が見えない典型問題。対策は sshd_config の **`SetEnv PATH=...`** か `/usr/local/bin` への symlink。
- **Podman/Compose** — `network_mode: service:` は podman-compose で既知バグ複数 (#316, #288 等)
  [FACT]。netavark/aardvark-dns では compose DNS 名 (`core`) が解決可、静的 IP 不要 [FACT]。

## 4. Architecture comparison

| 軸                         | 案A' sidecar+TCPForward                           | 案B netns 共有               | 案C core に tailscaled                           | 案D ホスト経由     |
| -------------------------- | ------------------------------------------------- | ---------------------------- | ------------------------------------------------ | ------------------ |
| 安全性/ホスト影響          | ◎ ホスト無変更                                    | ◎                            | ○                                                | × ホスト sshd 必要 |
| Podman 互換                | ○ (TCPForward は SPIKE、socat フォールバック確実) | × podman-compose バグ        | ○                                                | —                  |
| 既存 net/DevContainer 維持 | ◎ 無変更                                          | × core の 4 network 移行不能 | ○                                                | ◎                  |
| 複雑性/保守性              | ○ サービス 1 個追加                               | ×                            | × entrypoint にプロセス管理追加、prod 混入リスク | ○                  |
| 認証情報管理               | ◎ state volume + key 失効                         | 同左                         | △ core に TS state 同居                          | —                  |

案D 不採用理由の文書化: 要件 (ホスト sshd 禁止・podman
exec 中継禁止) に正面から違反し、ホストのログインサーフェスと Podman 制御権をエージェント経路に晒すため。

## 5. Recommended architecture

```text
Mac Codex App
  → SSH (Host umaxica-core, HostName umaxica-global-core=MagicDNS)
  → tailnet (grants: src=自分のデバイスのみ, dst=tag:umaxica-core, ip=tcp:22)
  → tailscale sidecar (userspace, TUN/cap なし, ports publish なし)
  → TS_SERVE_CONFIG {"TCP":{"22":{"TCPForward":"core:22"}}}   ※SPIKE 失敗時: serve→localhost:2222 + socat→core:22
  → core :22 sshd (root 起動 via sudo, dev image のみ)
  → global ユーザー (pubkey のみ)
  → codex app-server (stdio, ~/.codex は既存 host bind mount で永続)
```

sidecar と `core` は専用ネットワーク `remote-access`
のみで接続 (sidecar は他 network に入れない)。sidecar は compose profile `remote` で opt-in 起動。

## 6. Security model

- **Trust boundary**: tailnet (grants で端末限定) → sidecar → `remote-access` 内部 network → core
  sshd (pubkey only)。ホストには一切のポート・ソケット・バイナリを追加しない。
- **公開ポート**: ホストへの publish 追加ゼロ。sshd は compose 内部 network のみ。
- **認証情報**: `TS_AUTHKEY` は `~/.config/umaxica/tailscale.env` (chmod 600, git 外) →
  sidecar のみに `env_file`。one-off + pre-authorized + **tagged** key を使い、state
  volume 登録後に key を失効し env file から削除 (公式サポート挙動)。`podman inspect`
  で見えるのは失効済み key のみになる。Podman
  secrets はよりよいが podman-compose の secrets 対応が不安定なため env_file + 即時失効を採用。SSH は Mac 側専用 Ed25519 鍵、公開鍵のみ
  `~/.config/umaxica/agent-authorized-keys` → core へ read-only mount。
- **capabilities**: sidecar は userspace mode で `/dev/net/tun`・`NET_ADMIN`・`NET_RAW`
  不要 (デフォルトのまま何も付与しない)。privileged なし。
- **残存リスク** (ゼロではない): Linux カーネル / rootless Podman /
  netavark の脆弱性、tailscale・openssh パッケージ自体の脆弱性 (supply chain)、devcontainer
  feature のインストールスクリプト、コンテナ内エージェントによる workspace・`~/.codex`・`~/.claude`
  (rw mount) の改変。blast radius はコンテナ namespace + rw mount に限定され、`keep-id`
  によりホスト側実 UID は非 root の 1 ユーザーのみ。

## 7. Proposed file changes

| ファイル                                                | 変更                                                                                                                                                                                                                                                                                                                                                                            | production 影響                  |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| `Dockerfile`                                            | `development` stage にのみ `openssh-server` を apt 追加。`/usr/sbin/sshd` は起動しない (entrypoint 側で opt-in)                                                                                                                                                                                                                                                                 | なし (production stage 不変)     |
| `docker/core/sshd_config` (新規)                        | §8 の最小権限設定。`Port 22`, `AllowUsers global`, `AuthorizedKeysFile /etc/ssh/authorized_keys.d/global`, `SetEnv PATH=...` (codex 対策), host key は named volume 配下                                                                                                                                                                                                        | dev のみ                         |
| `docker/core/entrypoint.sh`                             | `REMOTE_SSHD=1` のときだけ `sudo ssh-keygen -A` (volume 上) + `sudo /usr/sbin/sshd -f docker/core/sshd_config` を実行してから `exec "$@"`                                                                                                                                                                                                                                       | 環境変数未設定なら完全に従来動作 |
| `compose.remote.yml` (新規, ルート)                     | `tailscale` sidecar サービス (profile `remote`, `TS_USERSPACE=true`/`TS_AUTH_ONCE=true`/`TS_STATE_DIR`/`TS_HOSTNAME=umaxica-global-core`/`TS_EXTRA_ARGS=--advertise-tags=tag:umaxica-core`/`TS_SERVE_CONFIG`、env_file、state named volume、network `remote-access`)。`core` へ `remote-access` network 追加・`REMOTE_SSHD=1`・authorized-keys read-only mount・host-key volume | compose ファイル自体が opt-in    |
| `docker/tailscale/serve.json` (新規)                    | `{"TCP":{"22":{"TCPForward":"core:22"}}}` (ディレクトリごと mount)                                                                                                                                                                                                                                                                                                              | なし                             |
| `.devcontainer/devcontainer.json`                       | `dockerComposeFile` 配列に `../compose.remote.yml` を追加 (profile 未指定なら sidecar は起動しないため常時追加で安全)                                                                                                                                                                                                                                                           | なし                             |
| `.gitignore`                                            | 変更不要見込み (`~/.config/umaxica/` はリポジトリ外)。念のため `tailscale.env` パターン追記のみ検討                                                                                                                                                                                                                                                                             | なし                             |
| `docs/operations/remote-codex-over-tailscale.md` (新規) | 運用手順 (鍵発行→登録→失効、Mac 側 ssh_config、検証マトリクス) を日本語で記載                                                                                                                                                                                                                                                                                                   | なし                             |

## 8. Implementation plan (依存順チェックリスト)

**Phase 0 — スパイク (実装確定前, 使い捨てコンテナで実施)**

1. rootless Podman で `tailscale/tailscale` を userspace・cap なしで起動し tailnet 登録できるか
2. `TS_SERVE_CONFIG` の `TCPForward:"core:22"` が別コンテナへ転送するか (失敗→socat 方式へ切替)
3. state volume + `TS_AUTH_ONCE=true` で auth key 失効後の再起動
4. Mac から `ssh umaxica-core 'command -v codex'` の PATH 解決 (`SetEnv` の要否確定)
5. Codex App Remote SSH 接続 + `/home/global/workspace` を開けるか + `AllowTcpForwarding no`
   で動くか (動かなければ `AllowTcpForwarding local` へ緩和)

**Phase 1 — サーバ側** 6. Tailscale 管理画面: `tag:umaxica-core` の tagOwners、grants
(`src: 自デバイス`, `dst: tag:umaxica-core`, `ip: ["tcp:22"]`)、one-off/pre-authorized/tagged auth
key 発行 7. Linux ホスト: `~/.config/umaxica/tailscale.env` (600) と `agent-authorized-keys`
(Mac の新規 Ed25519 公開鍵) を作成 8. `Dockerfile` dev stage へ openssh-server 追加 → rebuild 9.
`docker/core/sshd_config`・`serve.json`・`compose.remote.yml`・entrypoint 変更を実装 10.
`podman compose --profile remote up -d tailscale` → 登録確認 → **auth key 失効 + env file から削除**
→ 再起動確認

**Phase 2 — Mac 側** 11. `ssh-keygen -t ed25519 -f ~/.ssh/umaxica-core`
(未作成なら)、`~/.ssh/config` へ `Host umaxica-core` (HostName `umaxica-global-core`) 追加 12.
§9 の検証マトリクスを全通し 13. `docs/operations/remote-codex-over-tailscale.md`
執筆、devcontainer.json 反映

## 9. Verification matrix

| 検証                                    | 方法 / 期待値                                                                                               |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Tailscale 登録 / state 永続             | 管理画面に `umaxica-global-core`; sidecar 再作成後も同一ノード                                              |
| Auth key 削除後再起動                   | key 失効 + env から削除 → `up -d` 成功                                                                      |
| SSH 鍵認証 / パスワード拒否 / root 拒否 | `ssh umaxica-core whoami` → `global`; `ssh -o PubkeyAuthentication=no` → 即拒否; `ssh root@` → 拒否         |
| codex 検出                              | `ssh umaxica-core 'command -v codex'` → パス表示; `codex --version`                                         |
| Codex App Remote SSH                    | Host `umaxica-core` 選択 → `/home/global/workspace` を開けて app-server 起動                                |
| Rails/Vite/DB/Kafka                     | SSH セッションから `bin/rails test test/models/...` 成功、`bin/dev` 稼働継続、`psql`/valkey 接続            |
| コンテナ再作成 / Dev Container 再起動   | `podman compose up -d --force-recreate core` 後も SSH・既存機能維持                                         |
| ホスト非公開                            | Linux ホストで `ss -tlnp` に 22/tailscale 関連なし; sidecar に ports publish なし; Podman socket 非マウント |
| ACL 拒否                                | grants 外デバイスから `nc umaxica-global-core 22` → タイムアウト                                            |
| production 非混入                       | `podman build --target production` に sshd/tailscale なし (`dpkg -l openssh-server` 失敗を確認)             |

## 10. Rollback plan

1. Mac: `~/.ssh/config` から `Host umaxica-core` 削除。
2. `podman compose --profile remote down tailscale`、Tailscale 管理画面から Machines 削除、state
   volume 削除。
3. `devcontainer.json` の `compose.remote.yml`
   参照を戻し、`compose.remote.yml`/`serve.json`/`sshd_config`
   を削除、Dockerfile と entrypoint の変更を revert → rebuild。
4. `~/.config/umaxica/tailscale.env`・`agent-authorized-keys` 削除。既存 Dev
   Container は compose.remote.yml が opt-in なため、手順 3 だけで従来構成へ完全復帰できる。

## 最終判定 (10 問への回答)

1. **接続できるか**
   — できる見込みが高い (sidecar 経由、TCPForward は SPIKE)。断定: 経路自体は公式プリミティブの組合せで成立する。
2. **Codex App Server 起動** — 可。app-server は stdio/SSH
   exec で TCP 不要 [FACT]。cwd 選択は SPIKE。
3. **ホストに sshd/Tailscale/Codex 不要** — 可 [FACT]。全部コンテナ内。
4. **ホストへのポート publish 不要** — 可 [FACT]。ingress は tailnet のみ。
5. **SSH 終端** — `core`
   で終端 (sidecar は転送のみ)。ホームディレクトリ・codex・workspace が core にあるため。
6. **Tailscale SSH か OpenSSH か** — OpenSSH。Tailscale SSH は使わず `--ssh`
   も渡さない (要件どおり)。
7. **network_mode: service か TCP forwarding か** — TCP forwarding (TCPForward、fallback
   socat)。`network_mode: service:` は podman-compose バグ + core の複数 network と非互換 [FACT]。
8. **auth key 初回登録後に削除可か** — 可 [FACT]。失効は登録済みノードを無効化しない。tagged
   node で key expiry も無効化すること。
9. **rootless / keep-id / 複数 network 維持** — 維持できる。core への変更は network 1 本追加と env
   1 個のみ。
10. **ホスト追加攻撃面の最小化**
    — 満たす。ホスト側追加はローカルファイル 2 個 (600) のみで、リスニングポート・デーモン・ソケット共有はゼロ。数学的ゼロではなく、残存リスクは §6 に列挙のとおり。
