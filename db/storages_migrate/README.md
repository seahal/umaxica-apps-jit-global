# Storage database migrations

This directory is the configured `migrations_paths` owner for the reserved
`storage` / `storage_replica` databases (`db/storages_migrate` in
`config/database.yml`).

It is intentionally empty. Publishing owns media metadata in the publishing
database; this storage database is reserved for a separate purpose and must
not be merged with publishing, identity, or other application databases.
