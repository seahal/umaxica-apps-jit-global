# Controller 層 問題監査レポート(2026-07-17)

- 対象: develop HEAD `07ce89e3`(dirty worktree)。origin/main `69d7e3b`
  は develop の ancestor ではない点に注意。
- 経緯: Rack
  middleware 化監査(破棄済み)で可視化された情報を元に、controller 層の問題を再調査した。plans/grill-me-with-lucky-cocoa.md の Phase
  1(A/B/C/D 調査)+ 引用の自己検証を完了した結果をまとめる。
- 方針: 調査のみ。是正は提案であり、本レポートでは実装していない。rate limit は 2-way(edge +
  Rails-native `rate_limit`)を維持し、middleware 層は変更しない。

分類軸: (i) security boundary 違反 / (ii) 重複 drift / (iii) god concern 凝集度 / (iv)
docs・実装乖離 / (v) dead code。

---

## P0: security invariant テストが空振りしている(検証済み・最重要)

### P0-1. `Actor.install_context!` 境界 invariant が一度もマッチしない正規表現

- 根拠: `test/security/invariants/actor_context_invariant_test.rb` のスキャンが
  `line.match?(/\bActor\.install_context!\b/)` を使用。`!` は非 word 文字のため、直後が `(`
  や行末だと末尾の `\b` が成立せず**どの呼び出し行にもマッチしない**。
  - 検証: `ruby -e 'p "Actor.install_context!(".match?(/\bActor\.install_context!\b/)'` → `false`。
  - テスト実行結果: `bin/rails test test/security/invariants/actor_context_invariant_test.rb` → 6
    runs, 0 failures(= 空振りのまま green)。
- 実害: `app/controllers/concerns/base_step_up_completion.rb:35` が allowlist 外で
  `Actor.install_context!(step_up: StepUpResolver.call(...))`
  を呼んでいるのに検出されない。boundary 限定(`docs/.../current_context.md:42`)の防波堤が実質不在。
- 付随: allowlist(同テスト :42-67)に `sign_verification_step_up_lifecycle`
  が載っているが、当該ファイルに `install_context!` 呼び出しは存在しない(stale entry)。
- 是正案: 末尾を `(?=\s*\()` か単純に `\bActor\.install_context!/`(末尾 `\b` 削除)へ修正 →
  RED になった箇所を「allowlist 追加(レビュー済み境界として認定)」か「呼び出し撤去」で解消。allowlist の stale
  entry を削除。
- 影響: security(高)・docs 乖離。**優先度: 最高**。

### P0-2. `permit!` forbidden-pattern も同型の空振り

- 根拠: `test/security/invariants/forbidden_patterns_invariant_test.rb:18`
  `"mass-assignment permit!" => /\bpermit!\b/`。
  - 検証: `"params.permit!".match?(/\bpermit!\b/)` → `false`、`"params.permit!(" ...` →
    `false`、`"permit! foo"` → `false`(`!` の後が空白でも `\b` は word 文字を要求するため不成立)。
- 実害: AGENTS.md の非交渉境界「`permit!` 禁止」を守る唯一の自動チェックが無効。現時点で `permit!`
  の実使用が無いかは別途 grep で確認要(空振りのため grep が唯一の確認手段)。
- 是正案: `/\bpermit!/`(末尾 `\b`
  削除)へ修正。同ファイル内の他パターン(:19-26)は末尾が word 文字か構造が異なり同型の欠陥は無いことを確認済み。
- 影響: security(高)。**優先度: 最高**(P0-1 と同一 PR で修正可能)。

---

## P1: 境界違反(確定した問題)

### P1-1. `Actor.install_context!` の呼び出し分散(6+1 箇所)

- actor_support.rb:29,55,428 / authentication_base.rb:1680 / authentication_jwt_tokens.rb:110 /
  core_browser_api_boundary.rb:193 / verification_base.rb:86 は allowlist 済み。
- **base_step_up_completion.rb:35 のみ未認定**(P0-1 で不可視化されていた)。`if defined?(Actor)`
  ガード付きで呼んでおり、`defined?` ガード自体も silent-fallback 気味。
- 是正案:
  StepUp 完了時の context 更新を認定境界(verification_base か actor_support)へ寄せるか、レビューの上 allowlist に理由付きで追加。
- 影響: security boundary(中)。優先度: 高。

### P1-2. `request.env` 直読 16 行 / 8 ファイル

- authentication_base.rb:639,2632 / minimum_response_budget.rb:12,18 /
  social_omniauth_callback_flow.rb:13,39,93 / social_callback_guard.rb:201,204,210,240,333 /
  social_auth.rb:316 / omniauth_callbacks_controller.rb:229,529。
- minimum_response_budget.rb は自前キー `"jit.min_response.started_at"` の書き読みで、controller
  ivar で代替可能(最易)。omniauth 系は `omniauth.auth`
  等 gem 契約のため読むこと自体は必然だが、読む場所が 5 ファイルに散っている。
- 是正案: omniauth env の読み出しを単一の reader(値オブジェクト or 1
  concern)へ集約。minimum_response_budget は ivar 化。
- 影響: 保守(中)。優先度: 中。

### P1-3. `controller_path` 文字列分解への結合(36 参照 / 13 concern)

- 代表: authentication_jwt_tokens.rb:124-133 が `controller_path` を分解して JWT
  namespace を導出。authentication_withdrawal_gate.rb:30-95 が `controller_path.start_with?`
  で surface 分岐。
- **withdrawal_gate の rescue fallback は cross-surface 事故の芽**: `withdrawal_gate_redirect_path`
  が `rescue StandardError` で `acme_withdrawal_gate_redirect_path` へ落ち、その戻りは
  `edit_base_app_identity_withdrawal_path`(app
  surface のパス)。org/com リクエストで route 解決に失敗すると **app
  surface へ redirect され得る**。no-silent-fallback ルールにも抵触。
- 是正案:
  surface ごとの redirect 先を継承(surface 別 controller が自分のパスを宣言)で解決し、`rescue StandardError`
  fallback を撤去。memory 済み嗜好(structural inheritance over flags)と整合。
- 影響: security(中)+ 保守(高)。優先度: 高。

### P1-4. format 分岐の散在(29 箇所)

- authentication_base.rb 6 箇所、verification_base.rb
  4 箇所ほか。`transparent_refresh_access_token, unless: -> { request.format.json? }`
  のような callback 条件にも混入。
- 是正案: HTML/JSON の応答差は base
  controller 階層(browser 用/API 用)で分けるのが repo の既定路線(core_browser_api_boundary が前例)。一括是正は大きいので god
  concern 解体(P2-1)と同時に扱う。
- 影響: 保守(中)。優先度: 中(P2-1 に従属)。

### P1-5. concern 内の広域 rescue 46 箇所

- `rescue StandardError`
  が withdrawal_gate ほか concern 群に 46 箇所。個別監査は未実施(全量 grep のみ)。P1-3 の実害例が 1 件確定しているため、少なくとも fallback 値を返す rescue は個別レビュー対象。
- 優先度: 中(まず fallback 付き rescue のみ棚卸し)。

---

## P2: god concern と重複 drift

### P2-1. authentication_base.rb = 2909 行の god concern

- 10 sub-concern を include し、session / cookie / JWT / DPoP / DBSC / withdrawal /
  redirect を一体で保持。責務クラスタ E,F,G,H,K,L,M(約 1600 行)がドメインロジックで、value-object-boundaries.mdc の Services/Resolvers へ出すべきもの。
- 循環的な concern 依存の結び目が 4 箇所。`AuthenticationCurrentResourceResolver`
  と重複する実装が 9 箇所あり、うち
  **withdrawal 状態リストが resolver と concern で不一致**(drift の実例)。
- `device_session_class` の二重定義など重複定義もあり。
- 是正案: (1) withdrawal 状態リストの単一ソース化(即効・小)、(2)
  resolver 重複 9 箇所の resolver への一本化、(3) クラスタ単位の Services/Resolvers 抽出(長期)。一括リライトは提案しない。
- 影響: 保守(高)・drift(高)。優先度: 高(ただし段階実施)。

### P2-2. 12 surface ApplicationController の scaffold 重複と差分

Agent B の callback matrix + git 履歴突合の結論:

| 差分                                                                     | 判定           | 根拠                                                                           |
| ------------------------------------------------------------------------ | -------------- | ------------------------------------------------------------------------------ |
| org に withdrawal gate 無し                                              | **意図**       | preference-behavior-contract.md:131、sign-withdrawal-and-membership.md:148,154 |
| auth/app に `set_locale` あり `set_timezone` 無し(base/app:80-81 は両方) | **drift 疑い** | auth/app/application_controller.rb:74-84 で確認。意図の記録なし                |
| com/org の `set_locale` 欠落                                             | **drift 疑い** | 記録なし                                                                       |
| core/side に restricted_session_guard 無し                               | **drift 疑い** | 記録なし                                                                       |
| `verify_jump_return_rt!` が auth/com+org に無し                          | **drift 疑い** | 記録なし                                                                       |
| telephone 登録強制が auth/com のみ                                       | **drift 疑い** | 記録なし                                                                       |

- drift 疑い群の導入コミット(b0cd9351c3, 6cefdb39f7, 3683d7aecb,
  7d7561cac5)はいずれも一括変更で rationale 記載なし → 判定 UNKNOWN のまま。
- 是正案: まず各差分を「意図なら docs/ADR に明記、drift なら揃える」の二択でユーザー裁定 → その後、共通 scaffold は shallow
  nesting 方針(境界ごと 1 base)で重複を吸収。
- 影響: drift(高)・security(locale/timezone は低、guard 欠落は中)。優先度: 高。

### P2-3. callback 順序の防波堤が invariant テストのみ

- controller_lifecycle_order_invariant_test.rb:27-40 の REQUIRED_ORDER(12
  filter)が唯一の保証。P0 で見た通り invariant テスト自体の品質リスクがあるため、順序保証をテストに一任するのは脆い。
- 是正案: 短期はテスト維持(このテストは実 filter
  chain を読むため P0 型の空振りは無い)。中期は P2-2 の base 統合で順序を構造(1 箇所の宣言)に落とす。
- 優先度: 中。

---

## P3: dead code・legacy

### P3-1. dead seam(即削除可能)

- config/application.rb:12-13 が存在しない `app/middleware/core/surface_middleware.rb`
  を条件 require。`CoreSurface::ENV_KEY = "jit.surface"`(core_surface.rb:5)は定義のみで未使用。導入コミット e90cded944。
- 影響: なし(dead)。優先度: 高(コスト最小・独立タスク)。

### P3-2. `Finisher#purge_current` legacy

- finisher.rb:7-9。current_context.md:73-75 が legacy と明記。runtime 呼び出しゼロを確認済み。削除のブロッカーは「include を assert するテスト」のみ。
- 是正案: テストごと削除。優先度: 高(独立タスク)。

### P3-3. docs 乖離の解消確認(良いニュース)

- controller-lifecycle.md:177-191 の migration gaps(preference
  concern の callback 登録禁止など)は**解消済み**を確認。docs 側の gaps 記載を「完了」へ更新するだけでよい。
- 優先度: 低。

### P3-4. rack-attack gem の残置

- Gemfile に残り railtie が inert
  middleware を stack 末尾に積む。不採用決定済みのため gem 削除が整合的。ただし middleware 構成に触れるため、実施時期はユーザー判断。
- 優先度: 低。

---

## Phase 3: 独立着手できる後続タスク候補(優先順)

1. **invariant 正規表現の修正**(P0-1, P0-2)+ base_step_up_completion.rb:35 の扱い決定 + stale
   allowlist 削除 — 小さく閉じる、security 効果最大。
2. **withdrawal_gate の cross-surface fallback 撤去**(P1-3)。
3. **dead seam 削除**(P3-1)と **Finisher 削除**(P3-2)— 各々独立の小 PR。
4. **withdrawal 状態リストの単一ソース化**(P2-1 の即効部分)。
5. **surface 差分 6 件の意図裁定**(P2-2)— ユーザー判断が必要。裁定後に scaffold 統合へ。
6. minimum_response_budget の ivar 化 + omniauth env reader 集約(P1-2)。
7. docs 更新(P3-3)、rack-attack gem 削除(P3-4、時期はユーザー判断)。

GH issue 起票はユーザー確認後に行う。

## 検証メモ

- 本レポートの file:line 引用は調査中に全件実ファイルで確認した(agent 報告の転記のみの箇所なし)。特に P0 の 2 件は ruby ワンライナーとテスト実行で再現済み。
- production 環境の middleware/設定は ENV 必須(BASE_SERVICE_URL 等)のため未実測。dev/test 実測 +
  railtie ソースからの導出。
