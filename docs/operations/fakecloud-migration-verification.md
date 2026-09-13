# fakecloud Migration — Pending Host Steps and Verification

**Status: incomplete. Do not treat the fakecloud migration as working until this document is
finished and deleted.**

The migration from RustFS + standalone Kafka to fakecloud was implemented from inside the `core` Dev
Container, which could neither write three required files nor run any container tooling. This
document carries the remainder so it can be completed on a machine that can rebuild.

Everything here is mechanical. No design decisions are outstanding.

## Part 1 — Three Edits That Must Be Applied From the Host

`bin/`, `.devcontainer/`, and `.github/` are mounted `read_only: true` into `core` (see
`.devcontainer/compose.override.yml`), so these could not be written from inside it.

> **All three edits have since been applied and Part 1 is closed.** 1.2 and 1.3 landed with the
> fakecloud consolidation (`64f66841b`, 2026-08-31). 1.1 was resolved differently: the script it
> asked to edit was deleted outright, along with the Podman Secret machinery it registered, so there
> is nothing left to patch. The steps are kept below as the record of what the migration required;
> do not apply them.

### 1.1 `bin/setup-dev-secrets` — resolved by deleting the script

The edit described here was never applied. `compose.yaml` declares no `secrets:` block and no
service consumes a `dev_*` secret, `devcontainer.json` declares no `initializeCommand`, and the
script was therefore orphaned; it was removed rather than corrected. Development service passwords
are fixed literals in `compose.yaml` (`docs/operations/development-credential-provisioning.md`).

The one file it created that something still reads is `.secrets/codex_authorized_keys`, whose bind
mount in `compose.remote-access.yaml` needs a file to exist.
`docs/operations/remote-codex-over-tailscale.md` already documents creating it by hand as step 1 of
enrolment.

Stale local state from the RustFS era is inert but worth clearing once per developer machine:

```bash
rm -f .secrets/rustfs-access-key .secrets/rustfs-secret-key .secrets/rustfs-rpc-secret
podman secret rm dev_rustfs_access_key dev_rustfs_secret_key dev_rustfs_rpc_secret
podman volume rm umaxicaappsglobaldc_rustfs-data0 \
                 umaxicaappsglobaldc_rustfs-data1 \
                 umaxicaappsglobaldc_rustfs-data2 \
                 umaxicaappsglobaldc_rustfs-data3
```

### 1.2 `.devcontainer/compose.override.yml`

```diff
       - RUBY_DEBUG_OPEN=false
-  rustfs:
-    ports:
-      - "127.0.0.1:${RUSTFS_API_HOST_PORT:-9000}:9000"
-      - "127.0.0.1:${RUSTFS_CONSOLE_HOST_PORT:-9001}:9001"
+  # fakecloud needs no devcontainer override: compose.yaml already publishes it
+  # on loopback for every developer, and it is not a Dev Container-only service.
   primary:
     container_name: global-devcontainer-primary
   replica:
     container_name: global-devcontainer-replica
   valkey-cache:
     container_name: global-devcontainer-valkey-cache
   valkey-rate-limit:
     container_name: global-devcontainer-valkey-rate-limit
-  # kafka needs no devcontainer override: it publishes no host port and its
-  # container name is not referenced by tooling.
   loki:
     container_name: global-devcontainer-loki
```

### 1.3 `.devcontainer/devcontainer.json`

```diff
   // Podman Secrets under /run/secrets carry only locally generated, dev-only
-  // service passwords (Postgres, RustFS, Grafana, HMAC salts) created by
+  // service passwords (Postgres, Grafana, HMAC salts) created by
   // bin/setup-dev-secrets. No user credential is registered there.
```

## Part 2 — What Was Already Verified

Static checks only, all run inside `core`:

- All six Compose files parse as YAML.
- No dangling `depends_on`, secret, or volume reference across the merged `compose.yaml` +
  `.devcontainer/compose.override.yml`; no orphaned volume or secret.
- `bin/rails test` — 10401 runs, 3 failures, each shown to be pre-existing or environmental:
  `DevelopmentContainerContractTest#test_the_Dev_Container_loads_only_the_two_repository_Compose_files`
  (proven pre-existing by stashing the test file; it reads `devcontainer.json` from the git index),
  `ViteAssetNonceTest` (fails in isolation too; needs built Vite assets), and
  `TelephonesControllerTest#test_resend_cooldown_is_30_seconds` (passes in isolation; parallel-run
  flake).
- `test/unit/storage/` and `test/tooling/` — 43 runs, 0 failures.
- RuboCop reports the same 8 pre-existing offenses before and after the change.
- The fakecloud image digest and its lack of semver tags were read from the GHCR registry API, and
  the absence of `curl`/`wget` in the image was read from its image config blob.

## Part 3 — What Was Never Run

`podman`, `docker`, and `aws` are absent from the `core` image. `terraform` is present since
2026-08-31 via `ghcr.io/devcontainers/features/terraform`, but was not exercised, so **no runtime
verification of any kind was performed.** Two things in particular have never executed even once:

- **The healthcheck.** fakecloud's own documentation publishes a `curl`-based probe, but the image
  is Debian bookworm carrying only `ca-certificates nftables kmod procps` — no `curl`, no `wget`.
  The Compose healthcheck therefore uses bash `/dev/tcp`. That the container is healthy on this
  probe is a design inference from the image config, not an observation.
- **Every line of HCL under `terraform/`.**

## Part 4 — Verification Checklist

Run on a machine that can rebuild. Record failures here rather than deleting the line.

### Compose

- [ ] `podman compose -f compose.yaml config` succeeds (with `PODMAN_COMPOSE_PROVIDER` set as
      `docs/operations/container-engine-podman-notes.md` requires)
- [ ] `docker compose config` succeeds — syntax compatibility only, Docker is not a supported engine
- [ ] `podman compose config` still lists all five observability services (they are no longer
      profile-gated)
- [ ] plain `podman compose up -d` starts `core`, `primary`, `replica`, `valkey-cache`,
      `valkey-rate-limit`, `fakecloud`
- [ ] stop, restart, `down`, `up` again all succeed

### Existing infrastructure (regression)

- [ ] `primary` reaches healthy
- [ ] `replica` reaches healthy and `pg_stat_wal_receiver.status = 'streaming'`
- [ ] `valkey-cache` and `valkey-rate-limit` reach healthy
- [ ] Rails boots in `core`

### fakecloud

- [ ] `fakecloud` reaches healthy — **this exercises the untested `/dev/tcp` probe.** If it fails,
      the fallback is to install `curl` in a derived image or to drop to a plain TCP-connect probe;
      do not silently remove the healthcheck, because `fdw-poc` depends on `service_healthy`.
- [ ] `curl -s http://localhost:4566/_fakecloud/health` returns `{"status":"ok",...}` from the host
- [ ] `core` reaches `http://fakecloud:4566`
- [ ] persistence: create a bucket, `podman compose down`, `up` — the bucket survives
- [ ] `podman compose down -v` removes `fakecloud-data` and the bucket is gone

### S3

- [ ] `aws --endpoint-url http://localhost:4566 s3 mb / cp / cp / rm` round trip
- [ ] `bin/rails object_storage:prepare` and `bin/rails object_storage:smoke` pass from inside
      `core`

### Terraform

From `terraform/environments/development`:

- [ ] `terraform init`
- [ ] `terraform validate`
- [ ] `terraform plan`
- [ ] `terraform apply`
- [ ] `terraform plan` again reports **no changes** — a large diff here means a resource attribute
      fakecloud does not round-trip faithfully; record which one
- [ ] `terraform destroy`

The `aws_vpc` / `aws_subnet` / `aws_security_group` resources in `main.tf` exist because real Amazon
MSK requires client subnets in distinct availability zones. If fakecloud rejects or ignores them,
prefer adjusting this environment over weakening the shared module, which is meant to be reused
unchanged against real AWS.

### MSK — control plane only

- [ ] `terraform output -raw msk_cluster_arn` returns an ARN
- [ ] `aws --endpoint-url http://localhost:4566 kafka describe-cluster --cluster-arn ...` responds
- [ ] `aws ... kafka get-bootstrap-brokers --cluster-arn ...` returns well-formed addresses

**Do not test produce or consume.** No broker exists: fakecloud spawns a real Kafka container only
when handed a container runtime socket, and this repository deliberately mounts none. Unreachable
bootstrap addresses are the expected outcome, not a defect.
`test/tooling/compose_host_port_exposure_test.rb#test_fakecloud_mounts_no_container_socket` guards
this boundary.

## Part 5 — When Everything Passes

1. Record any fakecloud-vs-real-AWS discrepancy in the "Differences from Real AWS" section of
   `docs/operations/local-aws-fakecloud.md`, so it can be rechecked at production migration.
2. Update `notes/implementation/fakecloud-aws-development-baseline.md` — replace the "Not Done"
   section with what was actually observed.
3. Delete this document.

If a step fails, say so in the note rather than working around it silently. "It works against
fakecloud" and "it works against AWS" are different claims, and neither is "it was verified".
