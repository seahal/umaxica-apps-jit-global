# FakeCloud connectivity verification

## Verification scope

Verified read-only connectivity from the repository development container to the FakeCloud service
on 2026-09-04. No FakeCloud resources were created, modified, or deleted.

The Compose service name resolved inside the container, while the host-loopback publication was not
part of this verification. The verified endpoint was:

```text
http://fakecloud:4566
```

## Checks performed

### Service health

Command:

```bash
curl --silent --show-error --fail --max-time 5 \
  http://fakecloud:4566/_fakecloud/health
```

Result:

- Request succeeded.
- FakeCloud reported `status: ok` and version `0.44.10`.
- The advertised service list included `s3`, `eks`, and `rds`.

### S3 API

Used the repository's bundled `aws-sdk-s3` client with the development-only FakeCloud endpoint,
region `us-east-1`, path-style addressing, and the documented dummy credentials.

Operation and result:

```text
ListBuckets: succeeded
Bucket count: 0
```

### EKS API

Command:

```bash
curl --silent --show-error --fail --max-time 5 \
  -H 'Host: eks.us-east-1.amazonaws.com' \
  http://fakecloud:4566/clusters
```

Result:

```json
{ "clusters": [] }
```

The EKS read API was reachable and reported no configured clusters.

### Rails S3 round trip

Command:

```bash
RAILS_ENV=development bin/rails object_storage:smoke
```

Result:

- Created the configured `umaxica-local` bucket because it did not yet exist.
- PUT, HEAD, and GET succeeded for a generated object under `smoke/`.
- The task deleted the generated object and verified that a subsequent HEAD returned not found.
- The bucket remains as the intended persistent development resource; the temporary object does not.

## Limits of this evidence

This record proves network reachability, successful read-only API responses, and one S3 object round
trip from the current development container. It does not prove persistence across a FakeCloud
restart, Terraform provisioning, EKS workload execution, host-side access through `127.0.0.1:4566`,
or compatibility with real AWS.
