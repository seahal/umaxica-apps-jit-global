# 2026-09-14 FakeCloud advertised service inventory

`GET http://fakecloud:4566/_fakecloud/health` on FakeCloud **0.44.10**, run by the user from the
`core` container. The response advertises roughly 105 emulated services — far more than the two (S3
and the MSK control plane) that `docs/operations/local-aws-fakecloud.md` had recorded.

This corrects a claim the assistant made repeatedly during the 2026-09-14 session: that FakeCloud
offered no RDS, ElastiCache, SES, SNS, CloudWatch, or deployment surfaces. It offers all of them.
The repository's service matrix reflected only what had been investigated, not FakeCloud's
capability, and the assistant treated the former as the latter.

## Advertised services

```
account acm acm-pca amplify apigateway appconfig application-autoscaling appsync athena
autoscaling backup batch bedrock bedrock-agent bedrock-agent-runtime ce cloudcontrolapi
cloudformation cloudfront cloudtrail codeartifact codebuild codecommit codeconnections
codedeploy codepipeline cognito-identity cognito-idp comprehend config dms docdb dsql
dynamodb dynamodbstreams ec2 ecr ecs efs(elasticfilesystem) eks elasticache
elasticbeanstalk elasticloadbalancing emr es events firehose fis glacier glue iam
identitystore iot iotdata iotwireless kafka kinesis kinesisanalyticsv2 kms lakeformation
lambda logs managedblockchain mediaconvert memorydb monitoring mq mwaa neptune
organizations pinpoint pipes ram rds rds-data redshift resource-groups route53
route53resolver s3 s3tables sagemaker scheduler secretsmanager serverlessrepo
servicediscovery ses shield sns sqs sso ssm states sts support swf tagging textract
timestream transcribe transfer translate verifiedpermissions wafv2 xray
```

## How to read this list

**Being listed means the control plane answers with correct AWS response shapes. It does not mean
the service works.** The repository already contains the proof, and it is worth stating plainly
because the list invites the opposite conclusion:

`kafka` appears above. Yet `docs/operations/local-aws-fakecloud.md` records, with reasons, that the
MSK **data plane is unavailable here** — FakeCloud can back a provisioned cluster with a real
sibling Kafka container, but only when handed a Docker or Podman socket, and this repository mounts
no container socket anywhere. `GetBootstrapBrokers` returns well-formed addresses with nothing
listening on them.

Every service whose value lies in _executing_ something — databases, caches, build and deploy
pipelines, container runtimes — plausibly carries the same limitation. Services whose value lies in
_recording and returning state_ (S3, SQS, SNS, Secrets Manager, KMS) are the ones an API emulator
can serve fully.

Only S3 has been verified at runtime in this repository — see
`evidence/2026-09-14-fakecloud-s3-runtime-verification.md`. Every other entry above is FakeCloud's
claim about itself, unexercised here.

## What this changes, and what it does not

Unchanged, on grounds independent of FakeCloud's capability:

- **Valkey** stays a plain container despite `elasticache` and `memorydb` being listed. ElastiCache
  is a managed Valkey speaking the same protocol, so the container
  `adr/valkey-nonprod-logical-db-topology.md` already runs is the real thing.
- **Observability** stays on Alloy + Tempo/Prometheus/Grafana/Loki despite `monitoring`, `logs`,
  `events`, and `xray` being listed. `adr/traces-and-metrics-routing-via-alloy.md` decided this.
- **Email and SMS** stay on real AWS. Independently of whether `ses` and `sns` work here, the
  application cannot reach them: email uses SMTP rather than the SES API, and
  `app/services/outbound_sms_providers_aws_sns.rb` builds `Aws::SNS::Client` with no `endpoint:`
  option.

Reopened:

- **`rds` exists**, so `adr/fakecloud-podman-staging-environment.md` decision 10 was corrected. The
  conclusion (staging's database is chosen at implementation time) survives, but the reason changed
  from "no such surface" to "surface unverified, and an emulated RDS would be a plain PostgreSQL
  behind an RDS-shaped API — not Aurora".
- **`codepipeline`, `codebuild`, `codedeploy`, `codecommit`, `codeartifact`, `codeconnections`
  exist.** Deployment tooling remains undecided; these are execution services, so the socket
  constraint most likely applies, but that is now a testable question rather than a closed one.
- **`ses`, `sns`, `sqs`, `kms`, `secretsmanager`, `es` exist.**
  `notes/implementation/fakecloud-aws-development-baseline.md` marks them "out of scope by decision"
  without saying whether that was a capability limit or a scope limit. This settles it: it was a
  scope limit.

## Cheapest next checks

Each is one CLI call from a host with `aws` installed, and each would close an open item:

```bash
aws --endpoint-url http://localhost:4566 rds create-db-cluster \
  --db-cluster-identifier probe --engine aurora-postgresql
aws --endpoint-url http://localhost:4566 ses list-identities
aws --endpoint-url http://localhost:4566 codebuild list-projects
```

The RDS probe is the one that matters most: it decides whether
`adr/fakecloud-podman-staging-environment.md` decision 11 can be closed early.
