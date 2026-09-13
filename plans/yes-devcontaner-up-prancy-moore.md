# core コンテナ起動を bin/dev の失敗から切り離す

## Context

これまでの調査で、`core` コンテナが繰り返し再起動する事象を2件解消した:

1. `podman.socket` の実ファイル消失によるビルド失敗 → `systemctl --user restart podman.socket`
   で復旧。
2. devcontainer development stage で `bundle install`/`pnpm install`
   が一度も自動実行されない設計不備 → `postCreateCommand` を追加し、加えて手動で
   `bundle install`/`pnpm install` を実行して復旧。

この過程で、**より根本的な設計上の問題**が判明した。ユーザーはこれを次のように表現している:

> 起動した時点で bin/dev とかが動作する方がまずいと思うんです。こんかいのように、問題があって起動に失敗するっていうのは嫌です。

つまり、**「コンテナの起動」と「アプリ(Railsサーバー)の起動成否」が同じ生死判定に縛られている現在の設計そのもの**を変えてほしい、という要望。今回はこれを直す。

### 現在の結線(なぜ bin/dev の失敗がコンテナ全体を壊すのか)

- `compose.yaml`: `core` サービスは `restart: always`。
- `compose.custom.yaml`: `core.command` は `.devcontainer/tailscale-core-supervisor.sh bin/dev`。
- `.devcontainer/tailscale-core-supervisor.sh`(PID 1):
  - `setsid bin/dev &` でワークロードを起動し、並行して `tailscaled` を起動。
  - メインループは「ワークロードが死んだら」`stop_tailscaled` →
    **supervisor自身も exit**(`workload_status` をそのまま、または0なら1でexit)。
  - `tailscaled` 側だけは既に `MAX_TAILSCALED_RESTARTS=3`
    のリトライ+バックオフの仕組みを持っているが、ワークロード(`bin/dev`)側には同様の仕組みが無い。
- `bin/dev`(リポジトリ直下): `db:prepare` 失敗で即 `exit 1`、成功後は
  `exec foreman start -f Procfile.dev`。リトライや猶予は無い。
- supervisor が exit すると PID 1 が終了 → podman が `restart: always`
  によりコンテナ全体を作り直す → ワークロードが再び即死 → 無限ループ。

`docs/operations/remote-codex-over-tailscale.md:119-123` はこの「`bin/dev` が終了したら PID
1 も終了する」動作を**意図した仕様として明記**しているため、変更するならこのドキュメントも合わせて更新する必要がある。

また `.devcontainer/devcontainer.json` の jetbrains 向け `DEVCONTAINER_AUTO_START_BIN_DEV: "0"`
という環境変数は、リポジトリ全体を検索しても**どこからも参照されていない死んだフラグ**であることを確認済み(entrypoint.sh,
supervisor,
bin/dev のいずれも読んでいない)。VSCode/JetBrainsは今使っていないとのことなので、今回の修正はこれに依存しない形にする。

## 対応方針

`.devcontainer/tailscale-core-supervisor.sh`
を変更し、**ワークロード(`bin/dev`)の失敗をコンテナ全体の再起動に波及させない**ようにする。既存の
`tailscaled` 用リトライ+バックオフの仕組み(`MAX_TAILSCALED_RESTARTS`、`retry_delay`
によるバックオフ)と同じ考え方をワークロード側にも適用する:

1. **メインループの変更点**(`.devcontainer/tailscale-core-supervisor.sh` 174行目付近):
   - 現状: ワークロードが死んだら `stop_tailscaled` → `exit` して PID 1 ごと終了。
   - 変更後: ワークロードが死んだら
     - 終了ステータスをログに残す(現状通り)。
     - `tailscaled`
       は止めない(ワークロードの生死とリモートアクセスの生死を切り離す。エンジニアがSSHで入って原因調査できるようにするため)。
     - 指数バックオフ(例: 1s, 2s, 4s, 8s, 16s, 30s, 30s, ... の上限付き)で
       **ワークロードを再起動し続ける**。上限に達しても諦めずリトライを続ける(`bundle install`
       がまだ途中、DBがまだ起動中、など「時間が経てば直る」状況を自動回復させるため)。
     - **supervisor自身(PID
       1)は決して exit しない**(SIGTERM/SIGINTによる意図的なシャットダウン時を除く)。
   - `shutdown()` / `trap`
     によるSIGTERM/INT時の終了処理はそのまま維持(ここは「意図した停止」なので現状の即終了でよい)。
   - バックオフ中の `sleep` は既存コードと同様 `sleep N & wait $!`
     の形にして、シャットダウンシグナルに割り込み可能にする。

2. **`compose.yaml` の `restart: always` はそのまま維持**。今回の変更で PID
   1(supervisor)がワークロード失敗程度では二度と exit しなくなるため、`restart: always`
   が発火するのは「supervisorそのものが本当に落ちた場合(OOM等)」に限定される。これは既存のrestart方針と矛盾しない。

3. **`docs/operations/remote-codex-over-tailscale.md` の該当箇所を更新**し、「`bin/dev`
   が終了したら PID
   1 も終了する」という記述を、新しい「ワークロードはバックオフ付きで再起動され続け、コンテナ・Tailscaleは維持される」という実際の挙動に合わせて修正する。

4. **`.devcontainer/devcontainer.json` の未使用フラグ `DEVCONTAINER_AUTO_START_BIN_DEV`**
   は、今回の変更後は「常に安全に自動起動して問題ない」設計になるため意味を持たない。放置すると死んだ設定として紛らわしいので削除する(jetbrains設定ブロック自体は残す。設定していた項目だけ落とす)。

### やらないこと

- `bin/dev` 自体や `db:prepare` にリトライ・猶予ロジックを足すのは見送る。理由:
  supervisor層で失敗を吸収できれば十分であり、`bin/dev` 側に複雑さを持ち込むと `no-silent-fallback`
  方針(アプリ側での無言のリトライ/フォールバックの禁止)と抵触しやすい。supervisorはインフラ層のプロセス管理であり、アプリのビジネスロジックではないため、ここでのリトライは許容範囲と判断する。
- `restart`
  ポリシー自体の変更(`always`→`unless-stopped`等)は行わない。今回の本質的な修正はsupervisor層にあり、restartポリシーは変える必要がない。

## 変更対象ファイル

- `.devcontainer/tailscale-core-supervisor.sh` — メインループのワークロード失敗時挙動を変更(上記1)。
- `docs/operations/remote-codex-over-tailscale.md` — 挙動説明を更新(上記3)。
- `.devcontainer/devcontainer.json` — 未使用の `DEVCONTAINER_AUTO_START_BIN_DEV` を削除(上記4)。

## 検証方法

1. **正常系**: 現状問題なく `bundle install`/`pnpm install` 済みの状態で
   `podman compose ... up -d core`
   を実行し、これまで通り Puma/Vite/jobs が起動することを確認(既存の正常系を壊していないこと)。
2. **異常系(ワークロード失敗を意図的に再現)**: メインの永続コンテナには触れず、`podman compose run --rm`
   等の使い捨てコンテナ、または一時的に `SKIP_DB_PREPARE`
   やダミーの失敗コマンドを使うなどして、ワークロードが失敗するケースをシミュレートし、
   - コンテナ(supervisorプロセス)が exit せず生き続けること
   - バックオフ付きでワークロードの再起動が試みられること
   - ログにリトライの様子が出ることを確認する。
3. `podman inspect <core container> --format '{{.RestartCount}}'`
   が、ワークロード失敗時に増加しない(コンテナレベルの再起動が発生しない)ことを確認する。
4. 失敗要因(例: gem不足)を解消した後、次のリトライサイクルで自動的に `bin/dev`
   が正常起動することを確認する(手動でコンテナを再作成する必要がないこと)。
