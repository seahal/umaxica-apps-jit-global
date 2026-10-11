# Shrine + S3 Object Storage Foundation Implementation Notes

> **Partially superseded 2026-08-28** by the fakecloud migration. The Ruby-side design recorded here
> is unchanged and still current: `ObjectStorage::ShrineConfiguration`, the `OBJECT_STORAGE_*`
> namespace, the empty `Boundary::REGISTRY`, and the production rejection of an endpoint override
> all stand. What changed is the local S3 implementation behind that namespace: RustFS was replaced
> by fakecloud, `docs/operations/local-object-storage-rustfs.md` was replaced by
> `docs/operations/local-aws-fakecloud.md`, the service is no longer profile-gated, and the
> development credentials are now literal fake values instead of generated Podman secrets. Read
> references to RustFS below as historical.

## Context

- Original plan/spec: Shrine + AWS S3 attachment foundation; implement settled decisions only and
  leave explicitly deferred delivery design undecided.
- Related decisions/docs/plans: `adr/avatar-db-content-db-boundary.md`,
  `adr/publishing-db-content-authority.md` (§8), `adr/cross-db-reference-policy.md`,
  `docs/architecture/database-authority-placement.md`,
  `docs/operations/local-object-storage-rustfs.md`,
  `docs/audits/rails-intended-functionality-audit.md` (§4),
  `.agents/harnesses/rules/generic/no-silent-fallback.mdc`.
- Implementation date: 2026-08-28.

## Decisions Made During Implementation

- Decision: Ship infrastructure only; attach Shrine to no model, including `Avatar`.
  - Why: two independent blockers. (1) `adr/avatar-db-content-db-boundary.md` lists "media" and
    "Image posts" among what the avatar DB must not own and says it "must not become a UGC storage
    DB"; the profile-image-is-actor-state reading is defensible but is written nowhere. (2)
    `avatars.image_data` is `jsonb null: false, default: {}`, and Shrine's `Attacher#load_data` is
    `data && uploaded_file(data)` with no empty-hash guard, while `UploadedFile#initialize` raises
    unless both `id` and `storage` are present. Every existing row would raise on read, and
    detaching writes `nil`, violating NOT NULL.
  - Alternatives considered: enabling Avatar with a migration making the column nullable plus a `{}`
    -> NULL backfill (rejected as out of scope without an ADR); writing the ADR in this pass
    (rejected as a separate decision for the repository owner).
  - Follow-up needed: an ADR settling whether an avatar's own current identity image is actor state
    rather than UGC, then the migration and an `AvatarImageUploader`.

- Decision: Storage boundary is a third concept, separate from database connection name and public
  URL namespace, with an explicitly empty `ObjectStorage::Boundary::REGISTRY`.
  - Why: `§1.2` requires per-boundary buckets but forbids making a physical database name a public
    URL contract, and `docs/architecture/database-authority-placement.md` states authority must not
    be inferred from a database name. An empty registry also means databases without attachments
    (cache, queue, search, occurrence, chronicle, ticket, setting, signal) impose no bucket
    requirement on any deployment.
  - Alternatives considered: single bucket with key prefixes (loses per-boundary IAM and lifecycle
    isolation); a declarative config-file registry (more machinery than one or two boundaries need).
  - Follow-up needed: register a boundary only when a model actually declares an attachment.

- Decision: Production credentials come from the AWS SDK default provider chain, and an
  `OBJECT_STORAGE_ENDPOINT` set in production raises.
  - Why: keeps IAM roles and workload identity working, and
    `docs/operations/local-object-storage-rustfs.md` states production "must not set a RustFS
    endpoint override". Bucket and region still use one-argument `ENV.fetch`.
  - Follow-up needed: record the required least-privilege S3 IAM actions when a bucket is first
    provisioned; AWS infrastructure provisioning is outside this repository.

- Decision: Development without S3-compatible configuration falls back to `tmp/uploads`, never
  `public/`.
  - Why: the RustFS profile is opt-in, so requiring it unconditionally would break the default
    developer setup. The fallback is a legitimate expected case in development only; production has
    no file-system branch at all, so its fail-closed property is structural rather than a runtime
    check.

## Deviations From Plan

- Change: `lib/object_storage/{environment,boundary}.rb` became flat
  `lib/object_storage_environment.rb` and `lib/object_storage_boundary.rb`, each defining a nested
  constant plus a flat Zeitwerk alias.
  - Why: `docs/architecture/flat-ruby-source-layout.md` requires a flat layout under `lib`, and
    Zeitwerk resolves the flat constant from the file name. This follows the existing
    `lib/config_values_origin_value.rb` pattern
    (`ConfigValuesOriginValue = ConfigValues::OriginValue`).
  - Risk: low.

- Change: added `ObjectStorage::ShrineConfiguration::STORAGE_CACHE` memoizing resolved boundary
  storages, plus a regression test.
  - Why: Shrine's `dynamic_storage` plugin calls the resolver on every `find_storage` and does not
    memoize (verified in the gem source). Unmemoized, each upload, URL, and delete would build a new
    `Aws::S3::Client` with a fresh connection pool and credential resolution, and under the memory
    and file-system modes each lookup would return a new empty store, silently losing files.
  - Risk: cached per `env/boundary/role`; storages are stateless configuration holders.

- Change: uploader boundary is an overridable `self.storage_boundary` method rather than a writable
  class attribute.
  - Why: `ThreadSafety/ClassAndModuleAttributes` and `ThreadSafety/ClassInstanceVariable` flagged
    the mutable forms. An override also fixes the boundary at class-definition time.

- Change: `docs/audits/rails-intended-functionality-audit.md` got a dated status note rather than
  rewritten findings, since it is a point-in-time audit record.

## Post-Implementation Review Corrections (2026-08-28, same day)

A self-review after the first pass found three real defects. All three are fixed and tested.

- Defect: the initializer claimed production "raises here, at boot", and the handoff report claimed
  configuration was resolved at boot. It was not. In `:s3` mode `.storages` returns `{}` and reads
  no environment variable; bucket and region were read lazily on first storage resolution.
  - Fix: corrected the comment and added `ShrineConfiguration.verify_registered_boundaries!`, called
    from the initializer, which resolves every registered boundary at boot. A no-op while `REGISTRY`
    is empty; real validation as soon as a boundary is registered.
  - Note: the fail-closed property itself was never broken -- production has no file-system branch
    and missing configuration raised rather than falling back. Only the timing claim was wrong.

- Defect: `Environment.configured?` returned false unless all five `OBJECT_STORAGE_*` variables were
  present, so a partial set (typo, missing secret mount) silently selected local file-system storage
  in development -- a masking fallback of the kind `generic/no-silent-fallback.mdc` prohibits.
  - Fix: none set returns false, all set returns true, and a partial set raises naming both the
    present and the missing variables.
  - This immediately caught a latent bug in the existing development-mode test, which deleted only
    the plain variable names and left the `_FILE` variants set by `compose.yaml`, so the test was
    running against a half-configured environment. That test now saves and restores the full set,
    including the `_FILE` variants.

- Defect: `LOCAL_ROOT = "tmp/uploads"` was relative to the process working directory, and the
  public-web-root guard test passed trivially against a relative path.
  - Fix: replaced with a `local_root` method returning `Rails.root.join("tmp", "uploads").to_s`,
    resolved at call time because `Rails.root` is unavailable when the file is first required. The
    test now asserts the path is absolute and equal to the expected root.

## Review Notes

- Tests run: `test/unit/storage/` (34 runs, 0 failures after the review corrections above);
  `test/models/avatar_test.rb` and `test/tasks/` (21 runs, 0 failures); `bin/rails zeitwerk:check`
  clean; `bin/rubocop` clean on all changed files; `bin/brakeman` 0 security warnings; full
  `bin/rails test` (10400 runs) with only two pre-existing unrelated failures —
  `DevelopmentContainerContractTest` (a local `compose.custom.yaml` entry in
  `.devcontainer/devcontainer.json`) and `Preference::PreferenceBaseMethodsTest` (a `purged_at`
  validation). Neither file is touched here.
- Tests not run: no real AWS S3 and no RustFS round trip. This work is unit and configuration tested
  only; nothing here verifies a live bucket, IAM policy, or S3 error behavior.
- Documentation promotion needed: deferred items remain undecided and must not be inferred from this
  code — CDN choice and public delivery hostname, per-resource public/private policy, the public
  object-key contract, direct and multipart upload, `Publishing::MediaFile` Shrine integration,
  background promotion, and orphan cleanup and retention.
- Contradiction found, not acted on: a since-removed v1 plan assumed media metadata lives in the
  `storage` database with Shrine, which contradicts `adr/publishing-db-content-authority.md` §8
  ("storage ... reserved for another purpose") and `adr/avatar-db-content-db-boundary.md`. The ADRs
  were treated as authoritative; that plan line should be corrected or retired.
