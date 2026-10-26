# Search database migrations

This directory is the configured `migrations_paths` owner for the reserved
`search` / `search_replica` databases (`db/searches_migrate` in
`config/database.yml`).

It holds only `20261025200000_create_extensions.rb` (pgcrypto), so the database has a `schema_migrations` history and its structure dump is stable. The search database has no application schema yet.
Do not silently point this connection at another database's migrations.
