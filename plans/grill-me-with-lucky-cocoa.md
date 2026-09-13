# Controller 層 問題監査の是正実装 — grill-me-with-lucky-cocoa

## Context

`memos/2026-07-17-controller-layer-problem-audit.md` の監査で、security
invariant テスト 2 件が正規表現の欠陥で常に green(空振り)であること、withdrawal gate の redirect
fallback が cross-surface 事故を起こし得ること、authentication_base.rb の resolver 重複、surface 間の callback 欠落 5 件(drift 疑い)、dead
code 3 件を確認済み。ユーザーは監査内容に同意し、指摘事項をすべて是正する方針。ただし god
concern の分解は「確定した重複のみ」に絞り(2909 行の全面リファクタは今回やらない)、surface 差分 5 件は「欠落側に揃える」方針、rack-attack
gem 削除も今回のスコープに含めることをユーザーに確認済み。

## 是正タスク一覧(優先度順)

### 1. security invariant 正規表現の修正(最優先)

- `test/security/invariants/actor_context_invariant_test.rb`: `/\bActor\.install_context!\b/` → 末尾
  `\b` を削除し `/\bActor\.install_context!/` に修正。
  - 修正後 RED になる `app/controllers/concerns/base_step_up_completion.rb:35`
    を allowlist に理由付きで追加するか、呼び出しを認定境界(verification_base 等)へ移すかを判断する。まずテストを RED にして実態を確認してから決める。
  - allowlist の stale entry(`sign_verification_step_up_lifecycle` — 呼び出しが実在しない)を削除。
- `test/security/invariants/forbidden_patterns_invariant_test.rb:18`: `/\bpermit!\b/` →
  `/\bpermit!/` に修正。修正後 RED が出れば実箇所を確認して是正(現状 `permit!`
  実使用は無い想定だが、テストで確定させる)。

### 2. withdrawal gate の cross-surface fallback 撤去

- `app/controllers/concerns/authentication_withdrawal_gate.rb:30-95` の
  `withdrawal_gate_redirect_path` にある `rescue StandardError` →
  `acme_withdrawal_gate_redirect_path`(app surface 固定)の fallback を撤去。
- 各 surface が自分の withdrawal
  redirect 先を明示的に解決する構造(surface 別 controller が自身のパスを宣言 /
  surface 引数で分岐)に変更し、silent fallback を無くす。

### 3. authentication_base.rb の確定重複のみ是正

- withdrawal 状態リストが `authentication_base.rb` と `AuthenticationCurrentResourceResolver`
  で不一致 → resolver 側を単一ソースとして base 側から参照する形に統一。
- resolver と重複する残り 8 箇所の実装を resolver 呼び出しに置き換え(ロジック変更なし、委譲のみ)。
- `device_session_class` の二重定義を 1 箇所に統合。
- 2909 行の全面クラスタ分解(Services/Resolvers への本格抽出)は今回やらない。

### 4. surface 差分 5 件を「欠落側に揃える」

- `app/controllers/auth/app/application_controller.rb` に `set_timezone`
  を追加(base/app に合わせる)。
- com/org の ApplicationController に `set_locale` を追加。
- core/side に `restricted_session_guard` を追加。
- auth/com・auth/org に `verify_jump_return_rt!` を追加。
- telephone 登録強制(`enforce_required_telephone_registration!`)を auth/com 以外にも追加(他 surface の要否は既存の対象 surface 一覧に倣う)。
- 各追加後、既存の callback順序 invariant
  test(`controller_lifecycle_order_invariant_test.rb`)が通ることを確認。

### 5. dead code 削除

- `config/application.rb:12-13` の存在しない `app/middleware/core/surface_middleware.rb`
  への条件 require を削除。
- `CoreSurface::ENV_KEY`(core_surface.rb:5)の未使用定義を削除(他に参照がないことを grep で確認してから)。
- `Finisher#purge_current`(finisher.rb:7-9)と、これを include アサートするだけのテストを削除。

### 6. rack-attack gem 削除

- Gemfile / Gemfile.lock から `rack-attack` を削除し `bundle install` を実行。
- 未設定のままの railtie 依存が他に無いことを確認。

### 7. docs 更新

- `docs/architecture/controller-lifecycle.md:177-191` の migration gaps 記載を「解消済み」に更新。

## やらないこと

- authentication_base.rb の全面クラスタ分解(god concern の本格解体)。
- request.env 直読の集約(P1-2)、format 分岐の整理(P1-4)、46 箇所の広域 rescue 個別監査(P1-5)は今回のスコープ外(必要なら別タスクで着手)。
- Rack middleware の新規導入、rate limit 構成の変更(2-way を維持)。

## 検証

- `bin/rails test test/security/invariants/`
  — 正規表現修正後、allowlist/実装修正を経て green になることを確認。
- `bin/rails test test/security/invariants/controller_lifecycle_order_invariant_test.rb` —
  surface 差分修正後も順序 invariant が保つことを確認。
- withdrawal
  gate 関連の既存テスト(該当 concern の test ファイル)を実行し、fallback 撤去後も既存シナリオが通ることを確認。
- `bin/rails test` の関連ディレクトリ(controllers/concerns 配下、Finisher関連)を実行。
- `bundle install` 後に `bundle exec rails middleware`(dev)で rack-attack が消えていることを確認。
- 変更ファイルの comment・docs 更新箇所をレビュー。
