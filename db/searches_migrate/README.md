# Search database migrations

This directory is the configured `migrations_paths` owner for the reserved
`search` / `search_replica` databases (`db/searches_migrate` in
`config/database.yml`).

It is intentionally empty. The search database has no application schema yet.
Do not silently point this connection at another database's migrations.
