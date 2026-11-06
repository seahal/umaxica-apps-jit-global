# WU-A14 local App Zenith test-database rebuild

- HEAD: `efdcd80d31c1ea3da77d49dce6edd6dbefa5c5b8`. Before this record, the shared worktree had 561
  tracked paths with uncommitted changes and 281 untracked paths; none were staged. No commit was
  created.
- A focused candidate run stopped in fixture setup with foreign-key violations on
  `client_telephones.user_id`. Before reset, `test_app_zenith_db` contained 23 Clients, 12
  Telephones, 0 Passkeys, 3 Secret credentials and 0 external identities. A read-only query found no
  pre-existing Telephone-to-Client orphan. The fixture loader error was therefore a collision
  between fixture replacement and existing dependent test rows, not an orphan measured before reset.
- Before resetting, saved a custom-format PostgreSQL dump at
  `/tmp/test-app-zenith-before-wua14-reset-20261102.dump` (565,442 bytes; SHA-256
  `4c215e98aabd0d1da0524e14536fc15533f0df1500ccfbf279d1dc94123c88d3`). `pg_restore --list`
  succeeded. Recovery command:
  `pg_restore --clean --if-exists --no-owner --no-acl --dbname=test_app_zenith_db /tmp/test-app-zenith-before-wua14-reset-20261102.dump`.
- Ran
  `UMAXICA_ENV_FILE=/home/global/workspace/.env.container.devcontainer RAILS_ENV=test bin/rails db:migrate:reset:app_zenith`.
  It completed successfully and targeted only `test_app_zenith_db`; production and Neon were not
  accessed.
- The reset left zero Clients, Telephones, Passkeys, Secret credentials and external identities.
  After the selected tests, counts were 7 Clients, 0 Telephones, 0 Passkeys, 3 Secret credentials
  and 0 external identities.
- The generated test and development App Zenith structure dumps differed from the pre-reset working
  file. The generated versions showed different foreign-key validation flags and local role-name
  digests. Restored the existing working file byte-for-byte from
  `/tmp/app-zenith-structure-before-wua14-reset-20261102.sql` (SHA-256
  `a710695c8d6a9596aebf24aec700191c4f312a8a8d9a1557895962c73376d054`). The generated differences
  were not retained; equivalence between the reset test DB and restored working dump was not
  verified. No migration or application source was changed in this rebuild.
- No full Rails suite was run.
