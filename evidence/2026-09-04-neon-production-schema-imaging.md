# 2026-09-04 Neon production schema imaging

## Goal

Populate the Neon `production_*_db` databases with the current schema so a production-shaped
environment can be inspected during development. Not a deployment; the Neon production tier is
disposable and slated for replacement by Amazon Aurora.

## Why `bin/rails db:migrate` could not be used

`RAILS_ENV=production bin/rails db:migrate` loads the full application. Boot aborts in
`config/initializers/jwt.rb`:

```
JitSecurityJwtRegistry::ConfigurationError:
  AUTH_JWT_PUBLIC_KEYSET must be a JWK Set object with keys array
```

- `config/credentials/production.yml.enc` and `config/credentials/production.key` present in the
  working tree are byte-identical copies of the `development` files (md5 `d91bba6a…` and `eef2177f…`
  respectively). They decrypt, but carry development JWT material, which the registry rejects for a
  non-local env.
- Production boot additionally requires `PUBLIC_ASSET_URL`, `TRUSTED_PROXIES`,
  `RATE_LIMIT_REDIS_URL`, `AUTH_JWT_*` / `PREFERENCE_JWT_*` keysets, AR encryption keys, and the
  `AppConfigLoader` host set. None are available in this workspace; `.env` carries only `NEON_*`,
  `CLOUDFLARED_*`, `UID`/`GID`.
- `db/*_structure.sql` are session-setting stubs (no `CREATE TABLE`), so `db:schema:load` is not an
  option either (`docs/operations/db-workflow.md`).

## Method used

Schema copy from the local, fully-migrated `development_*_db` databases (local PostgreSQL 17.7) into
the Neon `production_*_db` databases (PostgreSQL 18.6), with no production Rails boot.

Per database:

1. `pg_dump --schema-only --no-owner --no-privileges --no-tablespaces`
2. `pg_dump --data-only --table=schema_migrations --table=ar_internal_metadata`
3. On the target: `DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;` then load the dump
   with `psql -v ON_ERROR_STOP=1 --single-transaction`.
4. `ar_internal_metadata.environment` set to `production` (source value was `development`).

Connection used `sslmode=require channel_binding=require` against both `NEON_PGHOST` and
(verification only) `NEON_REPLICA_PGHOST`.

Step 3's schema drop was required: `production_app_zenith_db`, `production_org_zenith_db`, and
others already held partial schema from an earlier failed attempt (e.g. `production_org_zenith_db`
had ~28 leftover tables). `pg_dump --clean --if-exists` alone failed on constraint drop ordering
(`cannot drop constraint workspace_statuses_pkey … because other objects depend on it`).

Each generated dump was first replayed into a throwaway local database
(`ON_ERROR_STOP=1 --single-transaction`) to confirm it applies cleanly; all 21 passed before any
Neon write.

## Result — all 21 databases, Neon primary

`public` table count / `schema_migrations` row count, matching the local development source exactly:

| DB          | tables/migrations | DB         | tables/migrations |
| ----------- | ----------------- | ---------- | ----------------- |
| publishing  | 17/4              | com_ticket | 28/54             |
| com_zenith  | 71/92             | app_ticket | 39/61             |
| app_zenith  | 100/354           | app_signal | 4/3               |
| org_zenith  | 87/259            | org_signal | 4/3               |
| app_setting | 29/8              | com_signal | 3/3               |
| org_setting | 29/7              | cache      | 3/4               |
| com_setting | 29/7              | storage    | 2/0               |
| search      | 2/0               | queue      | 15/5              |
| chronicle   | 60/20             | occurrence | 54/114            |
| org_ticket  | 29/43             | avatar     | 47/36             |
|             |                   | platform   | 4/1               |

`search` and `storage` are reserved (empty migration directories); the two tables are
`schema_migrations` and `ar_internal_metadata` only.

Migration counts equal the on-disk file counts, including the multi-path databases: com_zenith =
`com_principals` 63 + `com_zenith` 29 = 92; app_zenith = `app_principals` 322 + `app_zenith` 32 =
354; org_zenith = `org_principals` 223 + `org_zenith` 36 = 259.

`ar_internal_metadata.environment = production` on all 21.

## Replica

`NEON_REPLICA_PGHOST` is a Neon read replica (`pg_is_in_recovery() = t`) of the same project.
`production_app_zenith_db` on the replica reports 100 tables / 354 migrations without separate
action, so applying to the primary is sufficient. `config/database.yml` `*_replica` entries target
this endpoint.

## Not done / follow-up

- `config/credentials/production.yml.enc` (untracked) is still the development copy. It is not
  gitignored (only `*.key` is) and should be removed or replaced with real material; it is not
  needed for this imaging.
- `config/environments/production.rb` working-tree edit (removal of
  `warn_on_records_fetched_greater_than`) was reverted — unrelated to this task.
- `config/database.yml` rewrite to `NEON_*` env vars and its new test in
  `test/unit/database_password_config_test.rb` are kept: the 21 `production_*_db` databases exist on
  Neon and connectivity is verified.
