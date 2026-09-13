# SSH鍵配布の簡素化(Tailscale公式ドキュメント調査結果)

## Context

tailscale-codexサイドカーの認証は完了し、`core`へのSSHもtailscale経由で到達可能になった。運用上の残課題は「Macの公開鍵を`~/.config/umaxica/agent-authorized-keys`へ手動でコピーする」という人力作業で、ユーザーはこれをTailscale純正機能で解消したいと希望した。ただし、次にTailscaleやCloudflare
Tunnelを外す可能性を見据え、`core`のSSHサーバー自体は標準OpenSSHのまま・疎結合を維持したいという制約がある。

Tailscale公式ドキュメントを調査した結果、次の事実が判明した。

## 調査結果(公式ドキュメントに基づく)

- **Tailscale SSH(`tailscale up --ssh`)は「別コンテナへの代理接続」を公式にサポートしていない。**
  Tailscale
  SSHは「tailscaled自身がSSHサーバーになる」機能であり、必ずSSH対象と同じOS/コンテナで動く必要がある (https://tailscale.com/docs/features/tailscale-ssh,
  https://tailscale.com/learn/ssh-into-docker-container)。 →
  `core`とは別コンテナの`tailscale-codex`にTailscale
  SSHを有効にしても、ログインできるのは`tailscale-codex`自身であり、`core`には届かない。
- 逆に言うと、**現状の構成(`core`は素のOpenSSH + `tailscale serve`でTCP転送 +
  ACLで認可)こそが、Tailscale公式が推奨する「既存sshdをTailscaleの背後に隔離する」パターンそのもの**(https://tailscale.com/blog/protect-ssh-servers-with-tailscale/,
  ACLの`ssh`ブロック: https://tailscale.com/docs/reference/syntax/policy-file)。
- **「Tailscaleのtailnet
  identityを使ってOpenSSHのauthorized_keysを自動生成する」公式機能は存在しない。**
  `tailscale whois`をAuthorizedKeysCommandに使う案はGitHub上のfeature
  requestとして存在するのみで、Tailscaleは未実装・未サポート (公式ドキュメントに記載なし)。
- 結論: **鍵配布そのものをTailscaleの機能だけで自動化する公式な方法はない。**
  Tailscaleが提供できるのは「誰がSSHポートに到達できるか」の認可(ACL/serve)まで。

## 提案する対応方針

### 採用: 現状構成を維持し、鍵配布の手間は「稀な作業」として許容する

- `core`のsshd/`agent-authorized-keys`は変更しない。Tailscale/Cloudflareを外す将来の選択肢を最大限保つ。
- 公開鍵の追加は「新しいデバイスを追加する初回のみ」発生する作業であり、日常運用の手間ではない。頻度に見合わない複雑化(サイドカーへのSSHクライアント組み込み、内部中継鍵の自動生成など)を避ける。

### 追加報告: Tailscaleより良い、Tailscaleと無関係な選択肢

鍵配布の自動化自体を望むなら、Tailscaleではなく**GitHubが公式に提供する
`https://github.com/<username>.keys`エンドポイント**を`sshd`の
`AuthorizedKeysCommand`から参照する方法がある。これはGitHub公式機能であり、Tailscaleに一切依存しないため、依頼にあった「いつか外せるように」という要件と最も相性が良い。ただし新たな外部依存(GitHub可用性、対象ユーザーの公開鍵管理をGitHubアカウントに委ねる)が発生するため、要否は別途判断が必要。このリポジトリのAGENTS.md方針(秘密情報の扱い、silent
fallback禁止)に照らし、 `AuthorizedKeysCommand`の失敗時にフォールバックしない設計にする必要がある。

## 次のアクション

ユーザーに、上記2案(現状維持 / GitHub
`.keys`によるAuthorizedKeysCommand自動化) のどちらを採用するか確認し、採用する場合のみ実装に進む。今回はコード変更なし。
