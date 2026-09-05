# Local AWS Emulation with fakecloud

> **Not yet verified at runtime.** This migration was implemented in an environment with no
> container tooling, and three files under `bin/` and `.devcontainer/` still need host-side edits
> before `podman compose up` works at all. Read
> `docs/operations/fakecloud-migration-verification.md` first.

`fakecloud` is this repository's single AWS compatibility layer for development. It replaces the
former RustFS service (S3) and the former standalone Kafka broker (MSK), so there is one local AWS
endpoint rather than one emulator per service.

It is **not** behind a Compose profile. A plain `podman compose up` starts it alongside `core`,
`primary`, `replica`, `valkey-cache`, and `valkey-rate-limit`, because S3 and MSK are meant to be
standing development
infrastructure rather than a special mode.

## What Is Available

| Surface                              | State                                                                                                                         |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| S3                                   | Fully usable. Bucket and object operations work through the AWS SDK, the AWS CLI, and the Terraform AWS provider.             |
| MSK control plane                    | Usable. `CreateCluster`, `DescribeCluster`, `GetBootstrapBrokers`, `DeleteCluster` all respond with real AWS response shapes. |
| MSK data plane (a real Kafka broker) | **Not available here.** See below.                                                                                            |

### Why There Is No Kafka Broker

fakecloud can back each provisioned MSK cluster with a real single-node Apache Kafka container, but
only when it is handed a Docker or Podman socket, because it spawns that broker as a sibling
container. Mounting a container runtime socket into `fakecloud` would grant it the invoking user's
complete container-management rights — the ability to start any image and bind-mount any host path
the user can reach. This repository mounts no container socket anywhere, and that boundary is worth
more than local `produce`/`consume`.

Without a socket fakecloud serves the MSK control plane with the _same response shapes_, which is
what the Terraform resources in `terraform/` exercise. `GetBootstrapBrokers` therefore returns
well-formed addresses with nothing listening on them. Producing and consuming against a local broker
is deferred; it is also not currently needed, because the repository contains no Kafka client at all
(no `rdkafka`, `karafka`, `racecar`, or `ruby-kafka`, and no producer, consumer, or job).

`test/tooling/compose_host_port_exposure_test.rb` guards this: no Compose service may mount a
`docker.sock` or `podman.sock`.

## Endpoints

There are two, and they are not interchangeable.

| Caller                                              | Endpoint                                                                                                                       |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| The Rails `core` container                          | `http://fakecloud:4566` — the Compose service name on the `backend` network. This is what `OBJECT_STORAGE_ENDPOINT` is set to. |
| The developer's host (Terraform, `aws` CLI, `curl`) | `http://localhost:4566` — the loopback publication in `compose.yaml`.                                                          |

The host publication is loopback-only (`127.0.0.1:${FAKECLOUD_HOST_PORT:-4566}:4566`), matching the
standing rule in `development-host-port-exposure.md`. Override the host port with
`FAKECLOUD_HOST_PORT` in the repository `.env` if 4566 is already taken.

## Credentials

Development uses the literal, obviously fake values `test` / `test`.

fakecloud validates the _shape_ of a SigV4 signature but never the key material, so these are not
secrets. The RustFS-era Podman secrets (`dev_rustfs_access_key`, `dev_rustfs_secret_key`,
`dev_rustfs_rpc_secret`) existed only because the RustFS entrypoint rejected weak or `/`-bearing
keys; they bought nothing here and have been removed.

Using visibly fake literals is the safeguard, not an absence of one: a real AWS access key pasted
into `compose.yaml` or `terraform/environments/development` is obvious on sight, rather than hidden
behind a generated `/run/secrets` file. `development_container_contract_test.rb` asserts these
values stay literal and uninterpolated.

**Production takes no key from these variables.** `lib/object_storage_shrine_configuration.rb` uses
the AWS SDK default credential chain in production and raises outright if `OBJECT_STORAGE_ENDPOINT`
is set there. That is why the application keeps its own variable namespace instead of
`AWS_ENDPOINT_URL_S3`: an `AWS_*` endpoint variable is consumed _implicitly_ by the SDK, which would
silently redirect production S3 traffic past that check.

### Migrating from RustFS

Nothing generates or validates `.secrets/` any more, so a stale checkout carries the three RustFS
files inertly rather than failing on them. Nothing reads them either -- the Podman Secrets they
backed are gone from `compose.yaml` -- but they are credential-shaped files with no owner. Clean up
once:

```bash
rm -f .secrets/rustfs-access-key .secrets/rustfs-secret-key .secrets/rustfs-rpc-secret
podman secret rm dev_rustfs_access_key dev_rustfs_secret_key dev_rustfs_rpc_secret
podman volume rm umaxica-apps-global-dc_rustfs-data0 \
                 umaxica-apps-global-dc_rustfs-data1 \
                 umaxica-apps-global-dc_rustfs-data2 \
                 umaxica-apps-global-dc_rustfs-data3
```

## Persistence

`FAKECLOUD_STORAGE_MODE: persistent` with `FAKECLOUD_DATA_PATH: /var/lib/fakecloud` writes state to
the `fakecloud-data` named volume. Without it fakecloud keeps everything in memory and a restart
silently discards every bucket and object.

This gives the two teardown verbs their natural meaning:

```bash
podman compose down       # buckets, objects, and MSK metadata survive
podman compose down -v    # fakecloud-data is removed with every other volume
```

Because no sibling containers are spawned (see above), `fakecloud-data` is the whole of fakecloud's
lifecycle. There is no second volume owned by a broker container to reason about.

## Health

The container image is Debian bookworm carrying only `ca-certificates`, `nftables`, `kmod`, and
`procps`. It has **no `curl` and no `wget`**, so the health probe published in fakecloud's own
documentation cannot run inside it. The Compose healthcheck instead uses bash's `/dev/tcp` — bash is
`Priority: required` in Debian — to request the documented introspection endpoint:

```bash
# From the host:
curl -s http://localhost:4566/_fakecloud/health
# => {"status":"ok","version":"...","services":[...]}
```

## Image Pinning

The upstream registry publishes only `latest`, `main`, and `sha-<commit>` tags — there is no semver
tag to track. The image is therefore pinned by digest:

```
ghcr.io/faiscadev/fakecloud:latest@sha256:48b0a8b3f0ee14d0d71f704954e1d2c6b48b88fab67468dd85beb633b33f7dc9
```

Dependabot's `docker` ecosystem updates the digest on this form. Because the upstream has no release
channel, a digest bump can carry a breaking change; review those PRs against the fakecloud changelog
rather than merging them as routine.

## Provisioning AWS Resources

Buckets and clusters are **not** created by a Compose `command:` or an init container. They are
declared in `terraform/` and applied with Terraform, so development exercises the same resource
definitions production will.

```bash
cd terraform/environments/development
terraform init
terraform validate
terraform plan
terraform apply
terraform plan      # must report no changes
```

`terraform/modules/` is environment-agnostic — it names no endpoint and no credential. Everything
fakecloud-specific lives in `terraform/environments/development/providers.tf`. A production
environment reuses the same modules with real AWS endpoints; it is deliberately not created yet.

State is a local backend and is gitignored: it describes a disposable emulator on one machine.

### Verifying S3

```bash
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url http://localhost:4566 s3 ls
aws --endpoint-url http://localhost:4566 s3 cp ./some-file s3://umaxica-local/probe
aws --endpoint-url http://localhost:4566 s3 cp s3://umaxica-local/probe -
aws --endpoint-url http://localhost:4566 s3 rm s3://umaxica-local/probe
```

`bin/rails object_storage:prepare` and `bin/rails object_storage:smoke` do the same round trip from
inside `core` using the application's own configuration.

### Verifying MSK

```bash
aws --endpoint-url http://localhost:4566 kafka list-clusters
aws --endpoint-url http://localhost:4566 kafka get-bootstrap-brokers --cluster-arn "$(
  cd terraform/environments/development && terraform output -raw msk_cluster_arn)"
```

The returned addresses are well-formed and unreachable. That is expected, not a fault.

## Differences from Real AWS

Do not read "it works against fakecloud" as "it works against AWS". Recheck each of these when
production infrastructure is built:

- **No Kafka data plane.** Broker behaviour, partitioning, consumer groups, and rebalancing are
  entirely unexercised.
- **IAM and STS are not enforced.** The provider runs with `skip_credentials_validation`,
  `skip_requesting_account_id`, and `skip_metadata_api_check`, so no permission boundary, bucket
  policy, or account-scoped ARN is validated.
- **S3 is exercised in path style only.** Real AWS uses virtual-hosted-style URLs, and the DNS and
  TLS behaviour of that path is untested here.
- **MSK runs PLAINTEXT in transit** so that a bootstrap address is returned at all. Production must
  use TLS.
- **No CloudTrail, no KMS enforcement, no cross-region behaviour, and no eventual-consistency or
  throttling semantics.**

## Out of Scope

OpenSearch, SQS, SNS, SES, KMS, and Secrets Manager are not configured, although fakecloud supports
them. Adding one means adding it to `terraform/`, not adding another Compose service.
