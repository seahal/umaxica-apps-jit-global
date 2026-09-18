# fdw-poc artifact removal

Executed the Cleanup Manifest (Gate 2c) in `docs/experiments/postgres-s3-fdw-poc.md`, removing the
PostgreSQL-to-S3 FDW proof-of-concept artifacts. Follows up the stale-overlay finding recorded in
`evidence/2026-09-14-root-compose-file-consolidation.md`.

## Why

Two independent reasons, both verified before deleting:

- The PoC was never executed. The document's Status was "Pending manual execution" and no Results
  field was ever populated, so nothing was lost by removing the artifacts.
- Its premise was gone. The overlay declared `depends_on: rustfs`, and `compose.yaml` no longer
  defines a `rustfs` service — RustFS was retired in favour of `fakecloud`. The overlay could not
  have started.

## State observed before deletion

| Check                                        | Result          |
| -------------------------------------------- | --------------- |
| `podman ps -a` filtered for `fdw`            | no containers   |
| `podman images` filtered for `fdw`           | no images       |
| `podman volume ls` filtered for `fdw`        | no volumes      |
| `git ls-files podman/fdw-poc docker/fdw-poc` | 8 tracked files |

Manifest steps 1-3 (stop container, remove image, empty and delete the S3 bucket) were therefore
no-ops and were not run; step 3's endpoint no longer exists at all.

## Removed

```sh
git rm -r podman/fdw-poc docker/fdw-poc
```

Eight tracked files — `Containerfile`, `compose.fdw-poc.yml`, `fixtures/generate_fixtures.sh`,
`smoke/run_smoke_checks.sql` under each of `podman/fdw-poc/` and `docker/fdw-poc/`. The manifest
named only the `podman/` tree; the `docker/` mirror postdates it and was removed too. Both parent
directories retain their other contents.

`docs/experiments/postgres-s3-fdw-poc.md` is deliberately kept as the permanent record, per the
manifest. Its Status section now states the PoC was abandoned unexecuted and why, and a new
"Execution record (2026-09-14)" section documents what the manifest actually did.

## References dropped

- `test/tooling/compose_host_port_exposure_test.rb` — both overlay paths out of `COMPOSE_FILES`
- `test/tooling/compose_local_override_optional_test.rb` — the comment excluding them
- `docs/operations/container-engine-podman-notes.md` — the `fdw-poc*` restart-policy row
- `docs/operations/fakecloud-migration-verification.md` — the clause justifying a healthcheck by
  `fdw-poc`'s `service_healthy` dependency

Left as historical record: `notes/implementation/fakecloud-aws-development-baseline.md`,
`plans/analysis/docker-to-podman-directory-migration.md`, and earlier `evidence/` entries.

## Verification

`bin/rails test` still cannot boot in this worktree — `Gemfile.lock` points at a
`vendor/bundle/.../rails-f3deab27b7b7` path that does not exist (pre-existing, unrelated). The
tooling guards are plain `Minitest::Test` with no Rails dependency and were run with `ruby <file>`:

| Test                                      | Result                             |
| ----------------------------------------- | ---------------------------------- |
| `compose_host_port_exposure_test.rb`      | 5 runs, 12 assertions, 0 failures  |
| `compose_init_reaping_test.rb`            | 2 runs, 3 assertions, 0 failures   |
| `compose_local_override_optional_test.rb` | 13 runs, 58 assertions, 0 failures |
| `compose_restart_policy_test.rb`          | 4 runs, 89 assertions, 0 failures  |
| `compose_tmpfs_compatibility_test.rb`     | 1 run, 0 failures                  |
| `evidence_layout_test.rb`                 | 3 runs, 6 assertions, 0 failures   |
| `global_portability_contract_test.rb`     | 5 runs, 59 assertions, 0 failures  |

RuboCop was NOT run — it needs the same broken bundle.
