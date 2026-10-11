# pg_cron infrastructure PoC

Local-only, infrastructure-capability PoC. Proves `pg_cron` installs, preloads, schedules, and
executes on the project's actual PostgreSQL primary — nothing more.

Not application lifecycle implementation. Does not touch `RetentionPurgeJob`, SolidQueue, or any
Rails-managed database. Runs entirely inside `db`, the PostgreSQL bootstrap database
(`POSTGRES_DB=db` in `compose.yaml`), which is also `pg_cron`'s configured metadata database
(`cron.database_name = 'db'` in `podman/psql-pub/postgresql.conf`) and is not used by Rails for
application data.

Nothing here runs automatically during normal Rails/devcontainer startup.

## Usage

Against the running `global-devcontainer-primary` container, using its own live
`POSTGRES_USER`/`POSTGRES_PASSWORD` (do not hardcode credentials):

```sh
podman exec -i global-devcontainer-primary sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -h 127.0.0.1 -d db -v ON_ERROR_STOP=1' \
  < podman/pg-cron-poc/setup.sql

# ... wait for a few scheduled executions, then inspect cron.job_run_details ...

podman exec -i global-devcontainer-primary sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -h 127.0.0.1 -d db -v ON_ERROR_STOP=1' \
  < podman/pg-cron-poc/teardown.sql
```

`teardown.sql` unschedules every PoC job. It intentionally leaves the `cron_poc` schema in place for
repeatable re-runs; drop it manually with `DROP SCHEMA cron_poc CASCADE;` if full removal is ever
needed.
