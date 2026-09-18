# 2026-09-14 FakeCloud S3 runtime verification (development)

First runtime verification of FakeCloud in this repository. Every prior record — the banner at the
top of `docs/operations/local-aws-fakecloud.md`, the checklist in
`docs/operations/fakecloud-migration-verification.md`, and
`notes/implementation/fakecloud-aws-development-baseline.md` — stated that no FakeCloud claim had
ever been executed. The S3 path has now been executed.

**Performed by the user, not by the assistant.** This host does not run Rails. The results below are
reported from the `core` container and are recorded as given; the assistant verified only that the
task names, bucket names, and endpoint match the repository.

## What was run

From inside the `core` container, against `fakecloud:4566` (the in-network address, not the
`127.0.0.1:4566` loopback publication).

| Step                               | Result                                              |
| ---------------------------------- | --------------------------------------------------- |
| `GET /_fakecloud/health`           | `200 OK`, `{"status":"ok","version":"0.44.10", ...}` |
| `bin/rails object_storage:prepare` | Both buckets created                                |
| `bin/rails object_storage:smoke`   | PUT → HEAD → GET → DELETE succeeded on both buckets |

Buckets created:

- `umaxica-avatar-development`
- `umaxica-publishing-development`

Both match the `.env.example` defaults (`OBJECT_STORAGE_BUCKET_AVATAR`,
`OBJECT_STORAGE_BUCKET_PUBLISHING`, lines 68-69) and the Terraform defaults in
`terraform/environments/development/variables.tf` (lines 25, 31).

The smoke run used `aws-sdk-s3` with `force_path_style: true`, the same endpoint and the same
literal `test` / `test` credentials the application's Shrine configuration uses. Test objects were
deleted; no state was left behind. `object_storage:smoke` is the task defined at
`lib/tasks/object_storage.rake:128` ("Run a destructive temporary-object smoke test against each
boundary bucket").

## Result

**Object storage works.** Read and write through the AWS SDK against FakeCloud succeed in
development: PUT, GET, HEAD, and DELETE all return as expected on both boundary buckets. The S3
column of the service matrix in `docs/operations/local-aws-fakecloud.md` — previously "fully usable"
on the strength of static inspection alone — is now backed by execution.

This matters beyond S3 itself. `adr/fakecloud-podman-staging-environment.md` records that S3 is
FakeCloud's only live consumer in this repository; verifying it verifies the part FakeCloud is
actually being kept for.

## Explicitly NOT verified

- `bin/rails object_storage:verify` (the Shrine attachment-persistence task at
  `lib/tasks/object_storage.rake:138`) was not part of this run; `prepare` and `smoke` were.
- **Every Terraform command.** `terraform init`, `validate`, `plan`, `apply`, and `destroy` remain
  unrun against `terraform/environments/development` and `staging-development`. The HCL under
  `terraform/` has still never executed.
- MSK, in either plane.
- The `staging-development` environment and its `umaxica-*-staging` buckets.
- Anything under `DEPLOYMENT_TIER=staging`; this was a development-tier run.

`docs/operations/fakecloud-migration-verification.md` keeps the full outstanding checklist.

## Follow-up worth taking

The health response reportedly states that FakeCloud emulates many AWS services beyond S3. The
repository's own matrix lists only S3 and the MSK control plane, and
`notes/implementation/fakecloud-aws-development-baseline.md` marks SQS, SNS, SES, KMS, and Secrets
Manager "out of scope by decision" without recording whether that was a capability limit or a scope
limit. Capturing the service list this endpoint returns would settle several open questions in
`adr/fakecloud-podman-staging-environment.md` — most directly whether any RDS or Aurora surface
exists, which decision 11 defers to implementation time.
