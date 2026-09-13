# db/ 配下の孤児フォルダ・ファイルの整理

## Context

publishing DB 移行完了後、`db/` を `config/database.yml` の全接続定義 (`migrations_paths` /
`schema_dump`)と突き合わせた結果、どの接続からも参照されない遺物が見つかった。これらは過去の DB 統合・削除(principal 統合、audits/documents/tokens
DB の廃止、CMS 削除)の残骸で、`bin/rails db:migrate` から一切実行されない。

## 調査結果

### 削除対象(どの接続からも未参照)

1. `db/audits_migrate/`(33 ファイル)—
   audit 用 DB 接続は database.yml に存在せず、audit テーブルはどの structure.sql にも存在しない。
2. `db/documents_migrate/`(2 ファイル)— 同上。document 接続なし。
3. `db/tokens_migrate/`(2 ファイル)— 同上。token 接続なし。
4. `db/{app,com,org}_principal_structure.sql` — 旧 principal DB のダンプ (app は CREATE TABLE
   0 件の空ダンプ)。現在の schema_dump は `*_zenith_structure.sql`。
5. `db/{app,com,org}_principal_reserved_migrate/`(.keep のみ、既にワーキングツリーで削除済み・未コミット)—
   database.yml 未参照。削除をコミットで確定する。
6. `db/migration_support/cms_schema.rb` — **untracked** の取り残し(Phase
   7 で git からは削除済みだがディスクに残存)。参照するのは適用済みの旧 CMS マイグレーション 3 本のみで、再実行・rollback しない限り不要。`rm`
   する。

### 残すもの(参照確認済み)

- `db/{app,com,org}_principals_migrate/` — zenith の `migrations_paths` に含まれる(現役)。
- `db/initial_schemas/` — `load_initial_*_schema` マイグレーション 4 本が require(現役)。
- `db/migration_support/publishing_schema.rb` — publishing マイグレーションが require(現役)。
- `db/searches_migrate/`, `db/storages_migrate/` —
  database.yml が参照するが空のため git 上に存在しないだけ(git は空ディレクトリを追跡できない)。問題なし・対応不要。

### 付随して発見した異常(要修復)

- ワーキングツリーの `db/{app,com,org}_zenith_structure.sql` と `db/publishing_structure.sql` が
  **中身をほぼ全削除された状態**(計 -18,752 行、publishing はヘッダのみ)に書き換わっている (未コミット)。HEAD のコミット済み版が正。何かの再ダンプが空 DB に対して走った模様。→
  `git restore` で HEAD へ戻し、dev/test の DB 実体にテーブルが残っているか確認する。

## 実行手順

1. `git restore db/app_zenith_structure.sql db/com_zenith_structure.sql db/org_zenith_structure.sql db/publishing_structure.sql`
2. dev DB の実体確認: `bin/rails runner 'puts Publishing::Edition.count'`
   とzenith 側の任意テーブル存在確認。空になっていたら原因を調査して報告(勝手に再構築しない)。
3. 削除: `git rm -r db/audits_migrate db/documents_migrate db/tokens_migrate`、
   `git rm db/app_principal_structure.sql db/com_principal_structure.sql db/org_principal_structure.sql`、
   `rm db/migration_support/cms_schema.rb`、principal_reserved の .keep 削除を stage。
4. `bin/rails db:migrate:status` 全 DB でエラーなしを確認(migrations_paths が壊れていないこと)。
5. publishing 関連テストスイープ(前回と同じ 7 対象)で回帰なしを確認。
6. 日本語コミットメッセージでコミット(Entra WIP と Gemfile は含めない)。

## Verification

- `bin/rails db:migrate:status` が全接続で正常出力。
- `bin/rails test test/integration/read_only_surfaces_test.rb test/controllers/info_surface_publishing_test.rb test/models/publishing/`
  → 0 failures。
- `git status` に Entra WIP / Gemfile 以外の残差がないこと。
