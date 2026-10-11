# fakecloud as the Development AWS Baseline — Implementation Notes

> **Amendment, 2026-08-31.** This note records the state at implementation time, when OpenTofu was
> the intended driver for the HCL under `terraform/`. OpenTofu was subsequently not adopted;
> `terraform` is used instead. This note originally said it was installed in the dev container by
> `ghcr.io/devcontainers/features/terraform`; that was not true when written. The feature was
> actually added on 2026-09-14 — see `evidence/2026-09-14-terraform-devcontainer-feature.md`. Read
> every "OpenTofu" below as "Terraform". Nothing else in this note changed, and the HCL itself is
> unchanged -- it was always plain HCL.

## Context

- Goal: replace the two unused per-service AWS stand-ins (RustFS for S3, a standalone `cp-kafka`
  broker for MSK) with a single AWS emulator, and move AWS resource lifecycle out of Compose and
  into OpenTofu.
- Related: `docs/operations/local-aws-fakecloud.md` (runbook),
  `docs/operations/development-host-port-exposure.md`,
  `notes/implementation/shrine-s3-object-storage-foundation.md` (the Ruby side, unchanged),
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`.
- Implementation date: 2026-08-28.

## Evidence Gathered Before Changing Anything

- **The standalone Kafka broker had no consumer.**
  `grep -rniE "kafka|karafka|racecar|waterdrop|rdkafka|ruby-kafka"` over
  `app lib config src db Gemfile package.json` returned nothing. `Gemfile.lock` carries
  `opentelemetry-instrumentation-rdkafka` and `-ruby_kafka` only as transitive members of
  `opentelemetry-instrumentation-all`; they instrument clients that are not installed. The service
  ran unprofiled with a 30s healthcheck purely as dead weight.
- **RustFS had no consumer either.** `ObjectStorage::Boundary::REGISTRY` is empty, so no model
  declares an attachment and no bucket was required.
- **The `OBJECT_STORAGE_*` namespace is not RustFS debt.**
  `lib/object_storage_shrine_configuration.rb` raises in production when `OBJECT_STORAGE_ENDPOINT`
  is set, and `test/unit/storage/shrine_configuration_test.rb` guards it. That is a deliberate
  "production must never take an endpoint override" rule, not a RustFS artefact, so the namespace
  was kept and only its values changed.

## Decisions and Why

### No container runtime socket, so no Kafka data plane

fakecloud backs a provisioned MSK cluster with a real sibling Apache Kafka container, but only when
handed a Docker or Podman socket. Mounting one would grant fakecloud the invoking user's complete
container-management rights — start any image, bind-mount any reachable host path. This repository
mounts no container socket anywhere today, and rootless Podman has no fixed socket path to write
into a project-common `compose.yaml` (`$XDG_RUNTIME_DIR/podman/podman.sock` is UID-dependent, unlike
Docker's `/var/run/docker.sock`), so a portable mount would also have forced host-specific
configuration into a file that is meant to be identical for every developer.

Without a socket fakecloud serves the MSK control plane with the same response shapes, which is what
the OpenTofu resources exercise. Kafka produce/consume is therefore **deferred**, and
`test_fakecloud_mounts_no_container_socket` was added so a future change cannot quietly reverse this
by adding a socket mount.

### `OBJECT_STORAGE_*` kept rather than migrating to `AWS_ENDPOINT_URL_S3`

`AWS_ENDPOINT_URL_S3` is supported by the AWS SDK for Ruby and would collapse two namespaces into
one. It was rejected because the SDK consumes it **implicitly**: the explicit production rejection
in `ObjectStorage::ShrineConfiguration` only works because the application reads a namespace the SDK
does not. Migrating would have meant rewriting a security regression guard to be weaker. OpenTofu
and the AWS CLI use `AWS_*` as they must; the application does not.

### Literal fake credentials instead of Podman secrets

The three `dev_rustfs_*` secrets existed because the RustFS entrypoint rejected weak or `/`-bearing
access keys. fakecloud validates only the shape of a SigV4 signature, never the key material, so the
generation machinery bought nothing. `test`/`test` literals are the safer choice here: a real AWS
key pasted into `compose.yaml` is visible on sight rather than hidden behind a generated
`/run/secrets` file. The regression test was rewritten to assert that property rather than deleted.

### Health probe cannot use curl

fakecloud's own documentation publishes a `curl`-based healthcheck. Inspecting the image config
through the GHCR API shows the image is Debian bookworm with only
`ca-certificates nftables kmod procps` installed — **no curl, no wget**. The published probe would
fail. The Compose healthcheck uses bash's `/dev/tcp` (bash is `Priority: required` in Debian) to
request the same documented `/_fakecloud/health` endpoint with no added package.

### Digest pinning was forced, not chosen

Querying the GHCR tag list directly shows only `latest`, `main`, and `sha-<commit>` tags — the
project publishes no semver tag. `latest@sha256:...` is the only form that is both reproducible and
updatable by the existing Dependabot `docker` ecosystem, and it matches the `tailscale` pin already
in `compose.override.yaml`'s `remote-access` overlay.

## Deviations from the Approved Plan

- The plan assumed the health probe might need checking; it turned out the documented `curl` probe
  is unusable in this image, and the `/dev/tcp` approach was substituted (see above).
- The plan did not anticipate that the MSK module needs a VPC. Real Amazon MSK requires client
  subnets in distinct availability zones, so `terraform/environments/development` creates a minimal
  VPC, three subnets, and a security group rather than passing placeholder IDs. Keeping the module
  signature honest matters more than a smaller development environment, because the same module is
  meant to be reused for production.
- `docker/fdw-poc/smoke/run_smoke_checks.sql` and its `podman/` twin named their FDW server
  `fdw_poc_rustfs`. Renamed to `fdw_poc_s3` so the identifier does not outlive the product it named.

## Not Done, and Why

- **`bin/setup-dev-secrets`, `.devcontainer/compose.override.yml`, and
  `.devcontainer/devcontainer.json` were not edited.** Those paths are read-only bind mounts inside
  the Dev Container (`read_only: true` in the override), so they cannot be written from a shell
  running in `core`. The required edits are small and mechanical; they must be applied from the
  host, and `podman compose up` fails until they are.
- **No runtime verification was performed.** `podman`, `docker`, `tofu`, `terraform`, and `aws` are
  all absent from the `core` image. Every claim in this note is from static inspection, the Ruby
  test suite, and the GHCR registry API. In particular the `/dev/tcp` healthcheck and every line of
  HCL under `terraform/` have never executed.
- Both of the above are carried, with the exact diffs and a full checklist, in
  **`docs/operations/fakecloud-migration-verification.md`**. That document is the handoff to a
  machine that can rebuild, and is deleted once its checklist passes.
- Production Terraform environment, OpenSearch, and the remaining AWS services (SQS, SNS, SES, KMS,
  Secrets Manager) are out of scope by decision.

## Unrelated Problems Found and Deliberately Left Alone

Reported rather than fixed, because none is caused by or blocking this change:

1. `docker/` is a near-complete dead duplicate of `podman/` (only `docker/tailscale` is unique);
   every `compose.yaml` reference points at `./podman/...`.
2. `compose.yaml` and `compose.custom.yaml` both describe a `tunnel` profile that does not exist —
   `compose.custom.yaml` has no `profiles:` key at all, and the real opt-in is the `:?` on
   `CLOUDFLARED_TOKEN`.
3. Four observability images (`loki`, `grafana`, `otel-collector`, `prometheus`) float on `:latest`.
4. `devcontainer.json` forwards port 5050 with no service behind it, and lists
   `anthropic.claude-code` and `-sorbet.sorbet-vscode-extension` twice each.
5. `podman/alloy/config.alloy` configures a service defined in no Compose file, and is the only
   remaining mention of `docker.sock` in the repository.
6. `lib/tasks/object_storage.rake` uses a singular `OBJECT_STORAGE_BUCKET` while
   `ObjectStorage::Boundary` uses per-boundary `OBJECT_STORAGE_BUCKET_<SUFFIX>`. Two disjoint
   namespaces, documented but easy to misread.
7. `DevelopmentContainerContractTest#test_the_Dev_Container_loads_only_the_two_repository_Compose_files`
   fails on `develop` before this change: `devcontainer.json` loads three Compose files and
   `.devcontainer/compose.override.yml` is tracked, both of which the test forbids. (Both files were
   untracked and gitignored on 2026-09-14, and the test itself has since been deleted.)
