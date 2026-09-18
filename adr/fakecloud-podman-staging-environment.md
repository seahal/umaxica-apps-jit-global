# FakeCloud Staging on Podman, Provisioned with Terraform

Accepted: 2026-09-14

## Context

This repository has a local AWS emulation stack: the `fakecloud` service in `compose.yaml`
(`ghcr.io/faiscadev/fakecloud`, digest-pinned, persistent storage, published loopback-only on
`127.0.0.1:4566`), HCL under `terraform/`, and a `DEPLOYMENT_TIER` switch in
`lib/object_storage_shrine_configuration.rb` that accepts exactly `staging` or `production` and
raises otherwise. `docs/operations/local-aws-fakecloud.md` documents the service matrix and the
storage matrix.

Several decisions are already expressed in that code but were never recorded as decisions. They live
as inline comments and as an amendment banner on
`notes/implementation/fakecloud-aws-development-baseline.md`:

- OpenTofu was the original intent for the HCL under `terraform/`; it was not adopted, and Terraform
  is used instead, installed in the dev container through
  `ghcr.io/devcontainers/features/terraform`.
- `terraform/environments/staging-development/` exists with its own bucket defaults
  (`umaxica-avatar-staging`, `umaxica-publishing-staging`) deliberately distinct from the local
  development environment's.
- `terraform/modules/` names no endpoint and no credential; everything emulator-specific is confined
  to each environment's `providers.tf`.

What is genuinely undecided is the hosting shape. The existing prose assumes either a developer
workstation or an unspecified "integration VM". The intent now is a staging environment that runs on
Podman, against FakeCloud, provisioned by Terraform — the same container engine and the same
emulator as local development, rather than a cloud account or a hand-built VM.

Recording this matters because the alternative shapes have materially different consequences: a real
AWS staging account costs money and requires credential custody; a hand-built VM has no reproducible
definition; and leaving it unrecorded invites a future change to point the `staging` tier at real S3
without anyone noticing that the tier's whole purpose is to run production Rails configuration
against an emulator.

## Decision

1. **Staging's emulated AWS services are Podman-hosted FakeCloud, not an AWS account.** The staging
   environment runs the same `fakecloud` image as local development, on Podman. For object storage
   and streaming, no AWS account, no real AWS credentials, and no real AWS endpoint participate in
   staging.

   This scope is deliberate and was narrowed on 2026-09-14. An earlier wording claimed no real AWS
   participates in staging _at all_, which is not achievable: FakeCloud does not emulate a
   relational database (see decision 9), and the application requires PostgreSQL.

2. **Terraform is the provisioning tool.** Not OpenTofu, not shell scripts, not console clicks. This
   ratifies the amendment already applied to
   `notes/implementation/fakecloud-aws-development-baseline.md`. The supported installation path is
   the `ghcr.io/devcontainers/features/terraform` devcontainer feature — which this ADR originally
   described as already present. It was not: three documents and a `providers.tf` comment had
   claimed it since 2026-08-31 while the binary was absent from `core`. The feature was added on
   2026-09-14; see `evidence/2026-09-14-terraform-devcontainer-feature.md`.

3. **Module / environment split is the boundary.** `terraform/modules/` stays environment-agnostic —
   no endpoint, no credential, no bucket name literal. Every emulator-specific value lives in
   `terraform/environments/<env>/providers.tf` and `variables.tf`. A future real-cloud environment
   is added as a new directory under `terraform/environments/`, reusing the same modules unchanged.

4. **Staging owns its own bucket namespace.** `terraform/environments/staging-development` defaults
   to `umaxica-avatar-staging` and `umaxica-publishing-staging`. Staging and local development must
   never address the same bucket, so a staging run cannot read or overwrite a developer's objects
   and vice versa.

5. **`DEPLOYMENT_TIER=staging` means production Rails configuration against an S3-compatible
   emulator.** That is the tier's purpose: exercise the production code path without production
   data. `DEPLOYMENT_TIER=production` continues to take no key from the S3-compatible variables, use
   the AWS SDK default credential chain, and raise when `OBJECT_STORAGE_ENDPOINT` reaches the AWS S3
   path. Missing or unrecognized values keep failing at configuration resolution; no default is
   introduced.

6. **The application keeps its own `OBJECT_STORAGE_*` variable namespace** rather than `AWS_*`
   endpoint variables. An `AWS_*` endpoint variable is consumed implicitly by the SDK, which would
   silently redirect real production traffic past the tier check. This is a load-bearing constraint,
   not a naming preference.

7. **Credentials in emulator environments are visibly fake literals** (`test` / `test` in
   `providers.tf`). The safeguard is visibility, not absence: a real access key pasted into an
   environment directory is obvious on sight, whereas a generated `/run/secrets` file hides it. Note
   that `docs/operations/local-aws-fakecloud.md` credits this assertion to
   `development_container_contract_test.rb`, which no longer exists; no current test asserts that
   the Terraform environment credentials stay literal and uninterpolated. Adding one is open work.

8. **FakeCloud is not treated as a datastore for port-exposure purposes.** Loopback-bound
   publication of `4566` is permitted so Terraform and the AWS CLI can run from the host. This does
   not weaken the never-publish rule for PostgreSQL and Valkey in
   `docs/operations/development-host-port-exposure.md`.

9. **Staging's unit of deployment is the OCI container, run by Podman, with no host-OS assumption.**
   An earlier intent to build staging on a RHEL host is dropped as of 2026-09-14, because a
   Kubernetes platform is now likely to be available. Committing to containers rather than to a host
   build keeps both substrates open: the same images Podman runs locally are what a Kubernetes
   cluster would run later.

   No ADR or document in this repository ever recorded the RHEL plan — `rhel` appears only in
   SELinux bind-mount labeling notes (`compose.yaml`, `.devcontainer/compose.yaml`,
   `docs/operations/container-engine-podman-notes.md`). This decision therefore records a direction
   rather than reversing a written one.

   This does **not** adopt Kubernetes. The repository contains no manifests and no
   `config/deploy.yml`. Podman is the engine staging targets now; Kubernetes is a possibility this
   decision declines to foreclose.

10. **The relational database does not come from FakeCloud, despite FakeCloud listing `rds`.**
    Corrected 2026-09-14: an earlier version of this decision claimed FakeCloud emulates no
    relational database. That was wrong. `GET /_fakecloud/health` on version 0.44.10 advertises
    roughly 105 services including `rds`, `rds-data`, `dsql`, `docdb`, and `neptune` — see
    `evidence/2026-09-14-fakecloud-service-inventory.md`.

    The decision stands on a different footing. **Appearing in that list means the control plane
    answers with correct response shapes; it does not mean the service works.** This repository
    already holds the proof: `kafka` is on the list, yet `docs/operations/local-aws-fakecloud.md`
    records that the MSK data plane is unavailable here, because backing a cluster with a real
    broker requires mounting a container socket and this repository mounts none. A database is
    likewise an execution service — it needs a real engine behind the API — so the same constraint
    applies. And even a working emulated RDS would be an ordinary PostgreSQL behind an RDS-shaped
    API, which is precisely not what `adr/staging-aurora-postgresql-topology.md` needs to exercise.

    FakeCloud remains staging's object storage, unchanged.

11. **Which PostgreSQL staging uses is deferred, not decided here.** What must be settled when
    staging implementation begins — not now — is whether FakeCloud's `rds` surface is usable in
    practice under this repository's no-container-socket constraint, and which alternative is chosen
    if it is not. Testing that costs one `aws rds create-db-cluster` call against the emulator; it
    is cheap, and it has not been done. `adr/staging-aurora-postgresql-topology.md` records the
    topology that applies whenever Aurora is the backend, and carries this as an open item.

12. **Outbound email and SMS use real AWS, now and through staging.** This may be revisited later;
    it is not open at present. Neither routes through FakeCloud, and for different reasons:

    - **SES (email) structurally cannot.** `config/environments/production.rb` sets
      `delivery_method = :smtp` and connects to the SES SMTP endpoint per
      `adr/email-provider-resend-to-amazon-ses.md`. No AWS API call is made, so there is nothing for
      an emulator to intercept.
    - **SMS (SNS) cannot as the code stands.** `app/services/outbound_sms_providers_aws_sns.rb`
      builds `Aws::SNS::Client` with `access_key_id`, `secret_credential_access_key`, `region`, and
      an optional session token — but **no `endpoint:` option**. Unlike S3, which is redirected by
      `OBJECT_STORAGE_ENDPOINT`, there is no way to point SMS at a local emulator without changing
      that class.

    Consequently, a staging environment that actually sends SMS needs real AWS credentials:
    `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are read with `Rails.app.creds.require`, which
    fails closed when absent. This is the second exception to decision 1's no-real-AWS scope, after
    the relational database. **Whether staging sends SMS at all, or disables the transport, is not
    decided here.**

13. **Valkey is outside the emulation question regardless of FakeCloud's `elasticache` surface.**
    FakeCloud does list `elasticache` and `memorydb` (corrected 2026-09-14; an earlier version of
    this decision said it listed neither). They are not used. ElastiCache is a managed Valkey
    speaking the same protocol, so the plain container `adr/valkey-nonprod-logical-db-topology.md`
    already runs _is_ the real thing — there is nothing an emulator would add. Staging points
    `CACHE_REDIS_URL`, `RATE_LIMIT_REDIS_URL`, and `AUTH_STATE_REDIS_URL` at a Valkey container.

14. **Observability does not use FakeCloud's `monitoring`, `logs`, `events`, or `xray` surfaces.**
    `adr/traces-and-metrics-routing-via-alloy.md` makes Alloy the only observability agent, with
    Tempo, Prometheus, Grafana, and Loki behind it. CloudWatch has no place in that design, so its
    availability in the emulator changes nothing.

## Status of implementation

The decision is ahead of the code, and this ADR does not claim otherwise.

- Built: the `fakecloud` compose service, `terraform/modules/{object_storage,streaming}`,
  `terraform/environments/development`, `terraform/environments/staging-development`, and the
  `DEPLOYMENT_TIER` switch with its unit tests.
- Not built: the Podman host definition for staging itself, and any deployment of the Rails
  application into it. `terraform/environments/staging-development` currently provisions buckets
  only.
- Not verified: no `terraform init`, `validate`, `plan`, or `apply` has been run against any
  environment in this repository. `docs/operations/fakecloud-migration-verification.md` carries the
  open checklist, and `evidence/2026-09-06-shrine-fakecloud-attachments.md` records that
  `object_storage:verify` was exercised against local FakeCloud only, never a staging host.

Deferred with the reasons already recorded in
`notes/implementation/fakecloud-aws-development-baseline.md`: Kafka produce/consume (FakeCloud's MSK
support does not reach a working broker, so `GetBootstrapBrokers` returns an unreachable address),
OpenSearch, and the remaining AWS services (SQS, SNS, SES, KMS).

## Consequences

- FakeCloud's justification is narrower than its advertised surface suggests, though not because the
  surface is small: version 0.44.10 lists roughly 105 services. S3 is simply its only live consumer
  here. The repository has no Kafka client at all, so the MSK control plane serves nothing; email
  bypasses FakeCloud over SMTP; SMS cannot reach it; observability is committed to Alloy. What
  FakeCloud supplies today is object storage plus a local target the Terraform AWS provider can
  apply against — which is exactly what decisions 2 and 3 depend on. Dropping Terraform would leave
  little that a plain MinIO could not do.
- The gap between that narrow use and the 105-service list is an opportunity rather than waste: the
  surfaces are already running, so testing whether any of them is usable costs one CLI call each.
  `evidence/2026-09-14-fakecloud-service-inventory.md` lists the probes worth running first.
- Staging fidelity is bounded by FakeCloud's coverage. Anything FakeCloud does not emulate correctly
  is untested until a real-cloud environment exists. `docs/operations/local-aws-fakecloud.md` holds
  the current per-service matrix and is the place to check before trusting a staging result.
- IAM, quotas, throttling, cross-region behaviour, and real S3 consistency semantics are not
  exercised. Staging proves wiring and code paths, not AWS behaviour.
- Adding a real-cloud environment later is a new directory under `terraform/environments/`, not a
  module rewrite — provided decision 3 is held.
- The HCL is unexecuted, so the first `terraform apply` should be expected to surface provider and
  attribute errors. Treat the second `terraform plan` reporting no changes as the acceptance signal;
  a large diff there means a resource attribute is not round-tripping through FakeCloud.
- Choosing the container as the unit of deployment leaves real work undone rather than finished:
  `compose.yaml` is a Compose definition, not a Kubernetes one, and nothing translates between them
  today. The SELinux `:z` / `:Z` bind-mount labels that Podman needs on Fedora/RHEL hosts have no
  Kubernetes counterpart, so a later move to a cluster reworks volume handling rather than reusing
  it.
- `DEPLOYMENT_TIER` becomes load-bearing for a second reason beyond storage selection: it is the
  marker distinguishing an emulator-backed deployment from a real one. Any future code that branches
  on deployment shape should read this variable rather than inventing a parallel signal.

## References

- `adr/staging-aurora-postgresql-topology.md` — the staging relational database, which FakeCloud
  does not emulate: one Aurora PostgreSQL cluster, writer 1 + reader 1.
- `docs/operations/local-aws-fakecloud.md` — service matrix, storage matrix, endpoint table,
  Terraform apply procedure.
- `docs/operations/fakecloud-migration-verification.md` — the unrun verification checklist.
- `docs/operations/development-host-port-exposure.md` — the port publication rule this ADR stays
  inside.
- `notes/implementation/fakecloud-aws-development-baseline.md` — OpenTofu-to-Terraform amendment and
  the deferral reasons.
- `lib/object_storage_shrine_configuration.rb` — the `DEPLOYMENT_TIER` switch.
