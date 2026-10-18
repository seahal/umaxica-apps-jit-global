# Identifier capacity inventory recheck

Date: 2026-10-12

Repository: `/home/global/workspace`

Branch: `feature`

Code HEAD: `ccceabd05d2e3a8f923ce398046f99d026a5b78e`

The worktree was already dirty; the recheck preserved all existing changes. No application rows,
secrets or identifier values were exported. The catalog inventory was run against the run-owned
isolated PostgreSQL manifest with `bundle exec rails identifiers:inventory`, producing the ignored
report `tmp/identifier-contract/current-p8b-inventory.json`. It inspected 20 connections and 892
tables without reading application rows.

An aggregate read-only query then checked only tables whose `public_id` storage was unbounded or an
outlier. It reported counts, NULL/blank counts, maximum length and the count above 25; it did not
print identifier values. The observed rows in the run-owned database had no value above 25. The
catalog still contained 52 unbounded `public_id` columns, one `varchar(255)` (`app_zenith.clients`)
and one `varchar(16)` (`org_zenith.operators`). The operator value is governed by a separate
human-entered fixed 16-character code contract; it must not be mechanically changed to NanoID.

The current run-owned data therefore does not establish that every unbounded column has the same
semantic role or that a shared narrowing migration is safe for every consumer. Repository migration
rules prohibit an unapproved `change_column`, and the identifier contract requires producer,
reference and existing-data checks before narrowing. The remaining capacity work is consequently
kept as a per-column P12a inventory/decision item. No column was truncated, rewritten or narrowed
by this recheck.

This record is evidence for the disposable catalog only. It does not validate production/shared
data, complete semantic classification, consumer compatibility or the final identifier contract.
