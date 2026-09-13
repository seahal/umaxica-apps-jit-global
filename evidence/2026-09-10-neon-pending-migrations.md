# 2026-09-10 Neon pending migrations

## Goal

Apply the five migration versions present on disk but missing from Neon
`production_*_db` `schema_migrations` after the 2026-09-04 schema imaging.

## Why not `RAILS_ENV=production bin/rails db:migrate`

Production boot still fails at `AppConfigLoader` (`BASE_SERVICE_URL` required).
This workspace does not hold a complete production environment. Migrations were
run through development boot, with `ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection`
pointed at the Neon primary (`NEON_PGHOST` / `NEON_PGUSER`, `sslmode=require`).
`current_database()` was printed for each target before migrate.

## Applied

| Database | Versions | Result |
| --- | --- | --- |
| `production_org_ticket_db` | `20260909100000`, `20260909100001` | `operator_tokens.authentication_context` nullable string, concurrent index, validated check `chk_operator_tokens_authentication_context` |
| `production_app_ticket_db` | `20260905000000` | table `security_one_time_reveals` |
| `production_avatar_db` | `20260906000001`, `20260906000002` | `avatars.image_data` nullable, default none; empty `{}` rows set to NULL (0 rows) |

Post-apply `schema_migrations` counts: org_ticket 45, app_ticket 62, avatar 38,
matching on-disk `*.rb` counts for those paths.

## Not applied

- `production_primary_db` does not exist on Neon (`db/migrate` Flipper).
- `production_cache_db` still holds 4 imaged versions; this repository no longer
  has a cache migration directory (Valkey move).
- Chronicle disk has 19 files vs Neon 20 (one extra version on Neon, not pending).
