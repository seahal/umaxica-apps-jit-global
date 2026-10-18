# P1 observability verification and recovery

- Date: 2026-10-10
- HEAD: `2a1644f73238839ed7ed513bd4681ea393a86682`
- Worktree: pre-existing migration, structure-dump, documentation, research and
  script changes were preserved. This record covers the current dirty state and
  does not claim a reproducible implementation snapshot.
- CI, Podman, production services, external sinks and real email delivery were
  not used.
- Rails tests used the isolated PostgreSQL manifest
  `tmp/acceptance-isolated-20261009social3.json` with
  `PARALLEL_WORKERS=1` and the 20 disposable database names in the manifest.

## TDD and focused checks

The filter contract was first extended with positive and negative cases. The
first Red exposed broad substring filtering. After replacing only the short
ambiguous entries with Rails `ParameterFilter` regex entries, the focused test
passed with 6 runs and 51 assertions. A subsequent full-shard run exposed that
`code_verifier` also needed an explicit sensitive-key entry; the focused filter
and Entra secret-filtering tests then passed with 7 runs and 62 assertions.

The ActionMailer logger policy and OTel configuration tests passed with the
focused P1 set:

```text
8 files, 60 runs, 326 assertions, 0 failures, 0 errors, 0 skips
```

The local development boot check loaded the installed
`opentelemetry-instrumentation-action_mailer` version `0.8.1` with
`OPEN_TELEMETRY=true`. Its live configuration reported `email_address: :omit`;
the deliver transform returned only `email.x_mailer`, and the process transform
returned only `mailer` and `action` for a synthetic payload containing subject,
recipient and OTP arguments.

The direct `yq` checks confirmed the existing Compose declarations:

- core mounts `./podman/alloy` at `/home/global/workspace/podman/alloy` with
  `read_only: true` and `selinux: Z`;
- the Alloy service mounts `./podman/alloy/config.alloy` read-only;
- the pinned image is `docker.io/grafana/alloy:v1.19.2`.

Alloy/Podman binaries were unavailable in this container, so runtime recreation,
write-denial and processor execution remain NOT_RUN. No Compose file was
modified.

## Gate 3 Rails recovery

All 2,074 discovered Rails test files were run in 42 sequential, non-overlapping
shards with `bundle exec rails test`. The aggregate result for the current P1
state was:

```text
14,956 runs, 127,036 assertions, 3 failures, 0 errors, 0 skips
```

The three failures are the known `DatabaseReconstructionAuthorityTest` failures
in `test/tooling/database_reconstruction_authority_test.rb`: the 20 pre-existing
working-tree `structure.sql` files have no table definitions. No other shard had
a failure or error. The earlier monolithic Rails invocation remains classified
as exit 137 before summary; the shard run is the complete local coverage record.

## Gate 3 Vitest

Command: `bun run test`

```text
Test Files  99 passed (99)
Tests       1,140 passed (1,140)
```

`git diff --check` passed after the P1 changes.

The known structure-dump failures and unavailable Alloy runtime are limitations
of this verification; neither is claimed as an application test pass.
