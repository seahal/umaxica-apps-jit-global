# FakeCloud S3 and Shrine attachment implementation

## Environment

- Local development container against FakeCloud at `http://fakecloud:4566`.
- Rails environment for live verify: `development`.
- Test suite: `RAILS_ENV=test` (in-memory Shrine storage).
- Relevant HEAD at time of this record: `1012fedb8`.
- FakeCloud version: `0.44.10` (`GET /_fakecloud/health` → `status: ok`).

## Database ownership

- Avatar: `avatar` connection, migrations in `db/avatars_migrate`, model `Avatar` / `AvatarRecord`.
- Publishing media: `publishing` connection, migrations in `db/publishing_migrate`, model
  `Publishing::MediaFile` / `PublishingRecord`.
- The `storage` database was not used.

## Migrations applied

- Avatar: `20260906000001_allow_null_avatar_image_data`,
  `20260906000002_nullify_empty_avatar_image_data` via `bin/rails db:migrate:avatar` (development
  and test).
- Publishing: `20260906000001_add_file_data_to_publishing_media_files` via
  `bin/rails db:migrate:publishing` (development and test).

## Buckets

- Development: `umaxica-avatar-development`, `umaxica-publishing-development` created with
  `bin/rails object_storage:prepare`.
- Staging-named buckets on the same local FakeCloud: `umaxica-avatar-staging`,
  `umaxica-publishing-staging` created with `object_storage:prepare` after setting those bucket
  variables. This is not a staging-development VM run.

## Commands

- `bin/rails db:migrate:avatar db:migrate:publishing` (development and test)
- `bin/rails object_storage:prepare`
- `bin/rails object_storage:verify`
- `bin/rails test` on attachment, storage, avatar, publishing, and provisioning files listed below

## Upload verification (local development)

- `object_storage:verify` succeeded: FakeCloud reachable; Avatar object in
  `umaxica-avatar-development`; publishing object in `umaxica-publishing-development`; Shrine
  metadata in the matching databases; `avatars` table absent from publishing.

## Tests executed

- `test/models/avatar_image_attachment_test.rb`
- `test/models/publishing/media_file_attachment_test.rb`
- `test/unit/storage/application_uploader_test.rb`
- `test/unit/storage/object_storage_boundary_test.rb`
- `test/unit/storage/object_storage_bucket_isolation_test.rb`
- `test/unit/storage/shrine_configuration_test.rb`
- `test/lib/object_storage_shrine_configuration_modes_test.rb`
- `test/models/avatar_test.rb`
- `test/models/handle_assignment_test.rb`
- `test/models/avatar_agent_binding_test.rb`
- `test/models/avatar_individual_binding_test.rb`
- `test/models/publishing/schema_and_models_test.rb`
- `test/models/publishing/media_usage_ownership_test.rb`
- `test/services/avatar_provisioning/create_test.rb`

Observed: all of the above passed after the MediaFile store-key sync and MissingPublicIdError test
fixes.

## Unresolved

- Production AWS S3 buckets, IAM, and CDN URLs are not provisioned.
- Staging-development was configured (Terraform + distinct bucket names) and staging-named buckets
  were created on local FakeCloud. No separate staging-development VM was exercised.
- Compose services still running with the previous `OBJECT_STORAGE_BUCKET` process environment need
  a recreate to pick up `OBJECT_STORAGE_BUCKET_AVATAR` and `OBJECT_STORAGE_BUCKET_PUBLISHING`.
