# Storage database migrations

This directory is the configured `migrations_paths` owner for the reserved
`storage` / `storage_replica` databases (`db/storages_migrate` in
`config/database.yml`).

It holds only `20261025200000_create_extensions.rb` (pgcrypto), so the database has a `schema_migrations` history and its structure dump is stable. Publishing owns media metadata in the publishing
database; this storage database is reserved for a separate purpose and must
not be merged with publishing, identity, or other application databases.
