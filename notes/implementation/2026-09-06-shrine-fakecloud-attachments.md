# Shrine FakeCloud Attachments — Implementation Notes

## Context

- Spec: FakeCloud-backed S3 storage and Shrine image uploads for Avatar and publishing media, with
  per-database metadata persistence.
- Related: `notes/implementation/shrine-s3-object-storage-foundation.md`,
  `adr/avatar-db-content-db-boundary.md`, `adr/publishing-db-content-authority.md`.

## Discovered ownership

- Avatar records live on the `avatar` connection (`db/avatars_migrate`, `AvatarRecord`).
- Publishing media files live on the `publishing` connection (`db/publishing_migrate`,
  `PublishingRecord`, table `publishing_media_files`).
- The `storage` database remains unused for attachments.

## Decisions

- Register `avatar` and `publishing` in `ObjectStorage::Boundary::REGISTRY` now that both domains
  have attachments.
- Keep Shrine metadata on the owning table (`avatars.image_data`,
  `publishing_media_files.file_data`). Do not write attachments into the `storage` database.
- Make `avatars.image_data` nullable. The previous `{}` default is not a valid Shrine payload.
- Keep existing publishing media columns (`storage_key`, `content_type`, `byte_size`, `digest`) and
  copy them from Shrine metadata on validation so revision/version media usages stay unchanged.
- Avatar identity images remain on Avatar as current actor-state, not as UGC posts. That reading was
  previously deferred; this change implements it because the request names Avatar as the owner.
- Development buckets: `umaxica-avatar-development`, `umaxica-publishing-development`.
- Staging-development buckets: `umaxica-avatar-staging`, `umaxica-publishing-staging`.
- Bootstrap remains `bin/rails object_storage:prepare` (idempotent `create_bucket`) plus Terraform
  modules. Production still refuses `OBJECT_STORAGE_ENDPOINT`.

## Follow-up

- Production AWS bucket provisioning and IAM policies.
- CDN/public URL layer. Attachment metadata must keep storing storage id, not environment URLs.
- Runtime verification of `object_storage:verify` against a live staging-development FakeCloud was
  not performed in this change unless recorded in evidence.
