# rails-models-publishing: per-definition ledger

222 source definitions. [Audit scope and status legend](../README.md). Generated loops/each tables are represented once per source definition, not once per runtime case. Production links are static candidates, not verified call traces. Oracle excerpts are truncated; use the linked source for complete setup and assertions.

## `test/models/publishing/architecture_guard_test.rb`

[test/models/publishing/architecture_guard_test.rb](../../../test/models/publishing/architecture_guard_test.rb); SHA-256: `3d3bd208dad16767120f2ee4672b0072e4807333cbbdf165f07fa5c2d133a454`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08460"></a>T-08460 / [24](../../../test/models/publishing/architecture_guard_test.rb#L24) | "publishing models inherit PublishingRecord"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_empty offenders.map(&:name),` | [PublishingRecord](../../../app/models/publishing_record.rb#L6); [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08461"></a>T-08461 / [31](../../../test/models/publishing/architecture_guard_test.rb#L31) | "publishing models connect only to the publishing database"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_equal ["publishing"], databases` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08462"></a>T-08462 / [37](../../../test/models/publishing/architecture_guard_test.rb#L37) | "publishing models do not associate to authority records"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_empty offenders, "Publishing must stay decoupled from authority models:\n#{offenders.join("\n")}"` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08463"></a>T-08463 / [43](../../../test/models/publishing/architecture_guard_test.rb#L43) | "publishing models do not use Active Record polymorphism"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_empty offenders, "CMS publishing must not introduce AR polymorphism:\n#{offenders.join("\n")}"` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08464"></a>T-08464 / [49](../../../test/models/publishing/architecture_guard_test.rb#L49) | "publishing models do not use STI"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_empty named, "CMS publishing must not introduce STI:\n#{named.join("\n")}"` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08465"></a>T-08465 / [57](../../../test/models/publishing/architecture_guard_test.rb#L57) | "publishing models and public CMS controllers do not constantize untrusted names"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_empty offenders, "Public CMS path must not dispatch models via constantize:\n#{offenders.join("\n")}"` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08466"></a>T-08466 / [64](../../../test/models/publishing/architecture_guard_test.rb#L64) | "publishing tables do not use polymorphic type plus id ownership"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_empty offenders, "CMS persistence must not use *_type + *_id ownership:\n#{offenders.join("\n")}"` | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | conditional-reachability |
| <a id="t-08467"></a>T-08467 / [80](../../../test/models/publishing/architecture_guard_test.rb#L80) | "publishing tables do not keep exclusive-arc owner foreign keys"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_empty offenders,` | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08468"></a>T-08468 / [91](../../../test/models/publishing/architecture_guard_test.rb#L91) | "taxonomy kind remains a homogeneous classification column"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_includes columns, "kind"`; `assert_not_includes columns, "type"`; `assert_not_includes columns, "audience"`; +1 further assertion lines | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08469"></a>T-08469 / [100](../../../test/models/publishing/architecture_guard_test.rb#L100) | "generic discriminator entry tables have not returned"<br>Owner: `Publishing::ArchitectureGuardTest` | `assert_not PublishingRecord.connection.table_exists?(table)` | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/content_digest_contract_test.rb`

[test/models/publishing/content_digest_contract_test.rb](../../../test/models/publishing/content_digest_contract_test.rb); SHA-256: `7a37ce6bae61793f98cc66ac734b9f129df9baa1f90f5abfce14a9280293e963`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08470"></a>T-08470 / [23](../../../test/models/publishing/content_digest_contract_test.rb#L23) | "#{revision_class.name} and version preserve SHA256 storage and immutable updates"<br>Owner: `Publishing::ContentDigestContractTest` | `assert_match(/\A[0-9a-f]{64}\z/, digest)`; `assert_equal digest, revision.reload.content_digest`; `assert_equal digest, version.reload.content_digest`; +8 further assertion lines | [PublishingRevisionContentDigest](../../../app/lib/publishing_revision_content_digest.rb#L14) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08471"></a>T-08471 / [80](../../../test/models/publishing/content_digest_contract_test.rb#L80) | "#{revision_class.name} and version reject malformed digests before insertion"<br>Owner: `Publishing::ContentDigestContractTest` | `assert_not record.valid?, "#{model.name} must reject #{value.inspect}"`; `assert_not_empty record.errors[:content_digest]`; `I18n.with_locale(locale) { assert_not_empty record.errors.full_messages }`; +2 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/entry_revision_test.rb`

[test/models/publishing/docs/app/entry_revision_test.rb](../../../test/models/publishing/docs/app/entry_revision_test.rb); SHA-256: `4e9c29a5d8c0ac404ed28c16756888a820271d70d633aae86f3b30546011a736`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08472"></a>T-08472 / [9](../../../test/models/publishing/docs/app/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::EntryRevision)` | [Publishing::Docs::App::EntryRevision](../../../app/models/publishing/docs/app/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/entry_slug_test.rb`

[test/models/publishing/docs/app/entry_slug_test.rb](../../../test/models/publishing/docs/app/entry_slug_test.rb); SHA-256: `33c28a7123bf4aef6a8ea90ae0184a71cba4312ff6ef712f4f4692f9cd6f935a`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08473"></a>T-08473 / [9](../../../test/models/publishing/docs/app/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::EntrySlug)` | [Publishing::Docs::App::EntrySlug](../../../app/models/publishing/docs/app/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/entry_test.rb`

[test/models/publishing/docs/app/entry_test.rb](../../../test/models/publishing/docs/app/entry_test.rb); SHA-256: `1294f94d6fe379a7e6b8a3a328677d13e79d06d55307db39e835b27dfddaade7`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08474"></a>T-08474 / [9](../../../test/models/publishing/docs/app/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::EntryTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::Entry)` | [Publishing::Docs::App::Entry](../../../app/models/publishing/docs/app/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/entry_version_test.rb`

[test/models/publishing/docs/app/entry_version_test.rb](../../../test/models/publishing/docs/app/entry_version_test.rb); SHA-256: `5341e18e32e91a696f741747efb354c14ff00083a1930ffee41f86d2e2b8067d`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08475"></a>T-08475 / [9](../../../test/models/publishing/docs/app/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::EntryVersion)` | [Publishing::Docs::App::EntryVersion](../../../app/models/publishing/docs/app/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/publication_test.rb`

[test/models/publishing/docs/app/publication_test.rb](../../../test/models/publishing/docs/app/publication_test.rb); SHA-256: `cb1ec61a001a162e16e77e0c3954f0c7481de5f0c7c16757a4a1f18463a05534`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08476"></a>T-08476 / [9](../../../test/models/publishing/docs/app/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::Publication)` | [Publishing::Docs::App::Publication](../../../app/models/publishing/docs/app/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/revision_media_usage_test.rb`

[test/models/publishing/docs/app/revision_media_usage_test.rb](../../../test/models/publishing/docs/app/revision_media_usage_test.rb); SHA-256: `48f4fa031ba8f857c57927854e44ce7835c54ea2101dc89225818e8593ef471d`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08477"></a>T-08477 / [9](../../../test/models/publishing/docs/app/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::RevisionMediaUsage)` | [Publishing::Docs::App::RevisionMediaUsage](../../../app/models/publishing/docs/app/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/taxonomy_term_test.rb`

[test/models/publishing/docs/app/taxonomy_term_test.rb](../../../test/models/publishing/docs/app/taxonomy_term_test.rb); SHA-256: `c7fcf23d6f95215abfa07d81262497442251901dae7cd6e93e0a251dc5f5c28b`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08478"></a>T-08478 / [9](../../../test/models/publishing/docs/app/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::TaxonomyTerm)` | [Publishing::Docs::App::TaxonomyTerm](../../../app/models/publishing/docs/app/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/version_media_usage_test.rb`

[test/models/publishing/docs/app/version_media_usage_test.rb](../../../test/models/publishing/docs/app/version_media_usage_test.rb); SHA-256: `be35e3f6c696d70ef0837864a6c6c90a313f7ec46f03dec3db1b4eda943c9904`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08479"></a>T-08479 / [9](../../../test/models/publishing/docs/app/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::VersionMediaUsage)` | [Publishing::Docs::App::VersionMediaUsage](../../../app/models/publishing/docs/app/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/app/vocabulary_test.rb`

[test/models/publishing/docs/app/vocabulary_test.rb](../../../test/models/publishing/docs/app/vocabulary_test.rb); SHA-256: `85f43b7bb9ab6c43fee63344f245e14e058beeeec5cbbd6e5cdce443666186a8`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08480"></a>T-08480 / [9](../../../test/models/publishing/docs/app/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::App::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Docs::App::Vocabulary)` | [Publishing::Docs::App::Vocabulary](../../../app/models/publishing/docs/app/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/entry_revision_test.rb`

[test/models/publishing/docs/com/entry_revision_test.rb](../../../test/models/publishing/docs/com/entry_revision_test.rb); SHA-256: `2a1386c919a2af44cb6973164df5543ae52253249b375c25dd0df260c3deacc6`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08481"></a>T-08481 / [9](../../../test/models/publishing/docs/com/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::EntryRevision)` | [Publishing::Docs::Com::EntryRevision](../../../app/models/publishing/docs/com/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/entry_slug_test.rb`

[test/models/publishing/docs/com/entry_slug_test.rb](../../../test/models/publishing/docs/com/entry_slug_test.rb); SHA-256: `d28efc6e9e26dfc21fe40b26f05e281924e229d030e149ca9db3a3b3fa29d59f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08482"></a>T-08482 / [9](../../../test/models/publishing/docs/com/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::EntrySlug)` | [Publishing::Docs::Com::EntrySlug](../../../app/models/publishing/docs/com/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/entry_test.rb`

[test/models/publishing/docs/com/entry_test.rb](../../../test/models/publishing/docs/com/entry_test.rb); SHA-256: `c3382206dfbc92bb3b8d31cfba7f7f8188ebc77acf1ab31b121229bb47901981`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08483"></a>T-08483 / [9](../../../test/models/publishing/docs/com/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::EntryTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::Entry)` | [Publishing::Docs::Com::Entry](../../../app/models/publishing/docs/com/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/entry_version_test.rb`

[test/models/publishing/docs/com/entry_version_test.rb](../../../test/models/publishing/docs/com/entry_version_test.rb); SHA-256: `45766ec9e603bf3af049e5f8f89971c2e83527b17a908f322ef710fc41afb98e`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08484"></a>T-08484 / [9](../../../test/models/publishing/docs/com/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::EntryVersion)` | [Publishing::Docs::Com::EntryVersion](../../../app/models/publishing/docs/com/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/publication_test.rb`

[test/models/publishing/docs/com/publication_test.rb](../../../test/models/publishing/docs/com/publication_test.rb); SHA-256: `603268ee1590908b6dce90a802d19edf0e55b111cbfa90a03bfc53516902ae83`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08485"></a>T-08485 / [9](../../../test/models/publishing/docs/com/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::Publication)` | [Publishing::Docs::Com::Publication](../../../app/models/publishing/docs/com/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/revision_media_usage_test.rb`

[test/models/publishing/docs/com/revision_media_usage_test.rb](../../../test/models/publishing/docs/com/revision_media_usage_test.rb); SHA-256: `0deaaaee0a26eefde813940c9e261ee03786a773fb730ce82d99c85c71def67b`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08486"></a>T-08486 / [9](../../../test/models/publishing/docs/com/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::RevisionMediaUsage)` | [Publishing::Docs::Com::RevisionMediaUsage](../../../app/models/publishing/docs/com/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/taxonomy_term_test.rb`

[test/models/publishing/docs/com/taxonomy_term_test.rb](../../../test/models/publishing/docs/com/taxonomy_term_test.rb); SHA-256: `ed35acfe6f2da201a7cef5e19be71ca32b190f0af1bb4226001e8e2d9c4436f7`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08487"></a>T-08487 / [9](../../../test/models/publishing/docs/com/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::TaxonomyTerm)` | [Publishing::Docs::Com::TaxonomyTerm](../../../app/models/publishing/docs/com/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/version_media_usage_test.rb`

[test/models/publishing/docs/com/version_media_usage_test.rb](../../../test/models/publishing/docs/com/version_media_usage_test.rb); SHA-256: `29b4f2f85427b0a8a81c31b8712156e31b64693df07253447e7a898cb8c69fcf`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08488"></a>T-08488 / [9](../../../test/models/publishing/docs/com/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::VersionMediaUsage)` | [Publishing::Docs::Com::VersionMediaUsage](../../../app/models/publishing/docs/com/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/com/vocabulary_test.rb`

[test/models/publishing/docs/com/vocabulary_test.rb](../../../test/models/publishing/docs/com/vocabulary_test.rb); SHA-256: `5e62e7b3a404299bb8c2fe932824151e8354bfc0b734f731c74792578047e8ea`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08489"></a>T-08489 / [9](../../../test/models/publishing/docs/com/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Com::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Docs::Com::Vocabulary)` | [Publishing::Docs::Com::Vocabulary](../../../app/models/publishing/docs/com/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/entry_revision_test.rb`

[test/models/publishing/docs/org/entry_revision_test.rb](../../../test/models/publishing/docs/org/entry_revision_test.rb); SHA-256: `3f5215d3f505ada884ef9b67994d8d920f06592d9a52106662e7705d288c1137`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08490"></a>T-08490 / [9](../../../test/models/publishing/docs/org/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::EntryRevision)` | [Publishing::Docs::Org::EntryRevision](../../../app/models/publishing/docs/org/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/entry_slug_test.rb`

[test/models/publishing/docs/org/entry_slug_test.rb](../../../test/models/publishing/docs/org/entry_slug_test.rb); SHA-256: `8c63626ea24d63a0ccf91b83ebe9388d8b549572be1bf6428a99faeba0823c5c`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08491"></a>T-08491 / [9](../../../test/models/publishing/docs/org/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::EntrySlug)` | [Publishing::Docs::Org::EntrySlug](../../../app/models/publishing/docs/org/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/entry_test.rb`

[test/models/publishing/docs/org/entry_test.rb](../../../test/models/publishing/docs/org/entry_test.rb); SHA-256: `164b31a138011efd95620be23e239d881c1628daad42d2e89e5f10ed45f81e7b`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08492"></a>T-08492 / [9](../../../test/models/publishing/docs/org/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::EntryTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::Entry)` | [Publishing::Docs::Org::Entry](../../../app/models/publishing/docs/org/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/entry_version_test.rb`

[test/models/publishing/docs/org/entry_version_test.rb](../../../test/models/publishing/docs/org/entry_version_test.rb); SHA-256: `125175380838b0763aee8a84d176b79aed0e0eac7aaf9e51f2e7ab3907ddae62`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08493"></a>T-08493 / [9](../../../test/models/publishing/docs/org/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::EntryVersion)` | [Publishing::Docs::Org::EntryVersion](../../../app/models/publishing/docs/org/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/publication_test.rb`

[test/models/publishing/docs/org/publication_test.rb](../../../test/models/publishing/docs/org/publication_test.rb); SHA-256: `39eaae38e28cafc6b62c065dcb4303f1e1fef5313e3f8171eed04fe339abaf9a`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08494"></a>T-08494 / [9](../../../test/models/publishing/docs/org/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::Publication)` | [Publishing::Docs::Org::Publication](../../../app/models/publishing/docs/org/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/revision_media_usage_test.rb`

[test/models/publishing/docs/org/revision_media_usage_test.rb](../../../test/models/publishing/docs/org/revision_media_usage_test.rb); SHA-256: `8eb1093aa3e56f0d9aaef05c320b4606f067f4b6a86e3b7b6291f8aba0828a23`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08495"></a>T-08495 / [9](../../../test/models/publishing/docs/org/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::RevisionMediaUsage)` | [Publishing::Docs::Org::RevisionMediaUsage](../../../app/models/publishing/docs/org/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/taxonomy_term_test.rb`

[test/models/publishing/docs/org/taxonomy_term_test.rb](../../../test/models/publishing/docs/org/taxonomy_term_test.rb); SHA-256: `d1ba3ec2cee70da994235aa920251af94d19aad8281fb7c638a352c7af62a975`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08496"></a>T-08496 / [9](../../../test/models/publishing/docs/org/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::TaxonomyTerm)` | [Publishing::Docs::Org::TaxonomyTerm](../../../app/models/publishing/docs/org/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/version_media_usage_test.rb`

[test/models/publishing/docs/org/version_media_usage_test.rb](../../../test/models/publishing/docs/org/version_media_usage_test.rb); SHA-256: `47c3c5367c29881a20fe8560c4682ddeb4aa4e664075936dfdc88ba0c3212c04`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08497"></a>T-08497 / [9](../../../test/models/publishing/docs/org/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::VersionMediaUsage)` | [Publishing::Docs::Org::VersionMediaUsage](../../../app/models/publishing/docs/org/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/docs/org/vocabulary_test.rb`

[test/models/publishing/docs/org/vocabulary_test.rb](../../../test/models/publishing/docs/org/vocabulary_test.rb); SHA-256: `46e6a86068177269b8cc03a12b4310a19f60fbc34d117c480e47c9a9553ccd65`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08498"></a>T-08498 / [9](../../../test/models/publishing/docs/org/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Docs::Org::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Docs::Org::Vocabulary)` | [Publishing::Docs::Org::Vocabulary](../../../app/models/publishing/docs/org/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/encrypted_content_storage_test.rb`

[test/models/publishing/encrypted_content_storage_test.rb](../../../test/models/publishing/encrypted_content_storage_test.rb); SHA-256: `5332391038b945fdb83594a302b15a664c0f3d9047ba7efa4e6c9f8487e5a6e3`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08499"></a>T-08499 / [11](../../../test/models/publishing/encrypted_content_storage_test.rb#L11) | "docs/app revision ciphertext is not stored as plaintext"<br>Owner: `Publishing::EncryptedContentStorageTest` | `assert_equal PLAIN_TITLE, revision.title`; `assert_equal PLAIN_SUMMARY, revision.summary`; `assert_equal PLAIN_BODY, revision.body`; +6 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08500"></a>T-08500 / [37](../../../test/models/publishing/encrypted_content_storage_test.rb#L37) | "docs/app version ciphertext is written at insert and stays immutable"<br>Owner: `Publishing::EncryptedContentStorageTest` | `assert_equal PLAIN_TITLE, version.title`; `assert_kind_of Hash, version.body`; `assert_not_includes raw.fetch("title"), PLAIN_TITLE`; +2 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08501"></a>T-08501 / [55](../../../test/models/publishing/encrypted_content_storage_test.rb#L55) | "a body that is not a JSON object is refused with a readable error"<br>Owner: `Publishing::EncryptedContentStorageTest` | `assert_not revision.valid?, body.inspect`; `assert_equal ["must be a JSON object"], revision.errors[:body], body.inspect` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/family_promotion_matrix_test.rb`

[test/models/publishing/family_promotion_matrix_test.rb](../../../test/models/publishing/family_promotion_matrix_test.rb); SHA-256: `5377d4d49f3d8c96afb016aac8f38983100f20fcd4c6ff220b5d16ca9ca25c2c`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08502"></a>T-08502 / [12](../../../test/models/publishing/family_promotion_matrix_test.rb#L12) | "every family freezes its taxonomy assignments into the version it promotes"<br>Owner: `Publishing::FamilyPromotionMatrixTest` | `assert_equal "guide", single.term_slug_snapshot, cell`; `assert_equal "category", single.vocabulary_key_snapshot, cell`; `assert_equal "ruby", multiple.term_slug_snapshot, cell`; +3 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/entry_revision_test.rb`

[test/models/publishing/help/app/entry_revision_test.rb](../../../test/models/publishing/help/app/entry_revision_test.rb); SHA-256: `fdffa25c4df97caa17a767d87455039200c01200ebfdea3a4c385256f81647eb`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08503"></a>T-08503 / [9](../../../test/models/publishing/help/app/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Help::App::EntryRevision)` | [Publishing::Help::App::EntryRevision](../../../app/models/publishing/help/app/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/entry_slug_test.rb`

[test/models/publishing/help/app/entry_slug_test.rb](../../../test/models/publishing/help/app/entry_slug_test.rb); SHA-256: `dfe2bd04f303deabb252bfff7909d0e4d8e8bcbd3f43032222ce9b3c618dd261`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08504"></a>T-08504 / [9](../../../test/models/publishing/help/app/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Help::App::EntrySlug)` | [Publishing::Help::App::EntrySlug](../../../app/models/publishing/help/app/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/entry_test.rb`

[test/models/publishing/help/app/entry_test.rb](../../../test/models/publishing/help/app/entry_test.rb); SHA-256: `a1b1dfb62cf92719bbdeb446f611a80ed79fc90a8b0cbba207902c56213a9fc2`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08505"></a>T-08505 / [9](../../../test/models/publishing/help/app/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::EntryTest` | `assert_public_id_fixed_length(::Publishing::Help::App::Entry)` | [Publishing::Help::App::Entry](../../../app/models/publishing/help/app/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/entry_version_test.rb`

[test/models/publishing/help/app/entry_version_test.rb](../../../test/models/publishing/help/app/entry_version_test.rb); SHA-256: `becf93cbfdffa8831cfa76b22c0ffdda6046da1f69ec016d18d7a73eae9f3b8f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08506"></a>T-08506 / [9](../../../test/models/publishing/help/app/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Help::App::EntryVersion)` | [Publishing::Help::App::EntryVersion](../../../app/models/publishing/help/app/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/publication_test.rb`

[test/models/publishing/help/app/publication_test.rb](../../../test/models/publishing/help/app/publication_test.rb); SHA-256: `0bfe80400f9a218d699acedd31dc82f98ca5c68405ebb7af7b432760ffb7a10d`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08507"></a>T-08507 / [9](../../../test/models/publishing/help/app/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Help::App::Publication)` | [Publishing::Help::App::Publication](../../../app/models/publishing/help/app/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/revision_media_usage_test.rb`

[test/models/publishing/help/app/revision_media_usage_test.rb](../../../test/models/publishing/help/app/revision_media_usage_test.rb); SHA-256: `8bebb6c2993dcba5c5f25a585215bc505f0fb6a7a768b42f9f1548a7f27a9002`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08508"></a>T-08508 / [9](../../../test/models/publishing/help/app/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Help::App::RevisionMediaUsage)` | [Publishing::Help::App::RevisionMediaUsage](../../../app/models/publishing/help/app/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/taxonomy_term_test.rb`

[test/models/publishing/help/app/taxonomy_term_test.rb](../../../test/models/publishing/help/app/taxonomy_term_test.rb); SHA-256: `9634b3f660359709432440e2b807971e6700117bcc3f0064a1031ba5fdf84d42`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08509"></a>T-08509 / [9](../../../test/models/publishing/help/app/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Help::App::TaxonomyTerm)` | [Publishing::Help::App::TaxonomyTerm](../../../app/models/publishing/help/app/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/version_media_usage_test.rb`

[test/models/publishing/help/app/version_media_usage_test.rb](../../../test/models/publishing/help/app/version_media_usage_test.rb); SHA-256: `8940eba4a6b783f4ae77cb4018558ee9bf159e8ca24d8113227beb7c934b6ac9`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08510"></a>T-08510 / [9](../../../test/models/publishing/help/app/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Help::App::VersionMediaUsage)` | [Publishing::Help::App::VersionMediaUsage](../../../app/models/publishing/help/app/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/app/vocabulary_test.rb`

[test/models/publishing/help/app/vocabulary_test.rb](../../../test/models/publishing/help/app/vocabulary_test.rb); SHA-256: `2f03e1a86726276e5e1f7720d4d256300e1e6635a092ce11511c8b4fe9ce4349`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08511"></a>T-08511 / [9](../../../test/models/publishing/help/app/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::App::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Help::App::Vocabulary)` | [Publishing::Help::App::Vocabulary](../../../app/models/publishing/help/app/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/entry_revision_test.rb`

[test/models/publishing/help/com/entry_revision_test.rb](../../../test/models/publishing/help/com/entry_revision_test.rb); SHA-256: `fda4a2f7753a559f4caf2c397cb6943d846d9d3a523b3005448b37af487c3c03`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08512"></a>T-08512 / [9](../../../test/models/publishing/help/com/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::EntryRevision)` | [Publishing::Help::Com::EntryRevision](../../../app/models/publishing/help/com/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/entry_slug_test.rb`

[test/models/publishing/help/com/entry_slug_test.rb](../../../test/models/publishing/help/com/entry_slug_test.rb); SHA-256: `3fa3cbfd91eb05cbe1a5494868902b35db2b4fc556c6f3185a6924fcdaf9a594`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08513"></a>T-08513 / [9](../../../test/models/publishing/help/com/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::EntrySlug)` | [Publishing::Help::Com::EntrySlug](../../../app/models/publishing/help/com/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/entry_test.rb`

[test/models/publishing/help/com/entry_test.rb](../../../test/models/publishing/help/com/entry_test.rb); SHA-256: `8fc4a70d165d8327defc4fb2cac25be448c30d001a65ede35590a8730805de1f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08514"></a>T-08514 / [9](../../../test/models/publishing/help/com/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::EntryTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::Entry)` | [Publishing::Help::Com::Entry](../../../app/models/publishing/help/com/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/entry_version_test.rb`

[test/models/publishing/help/com/entry_version_test.rb](../../../test/models/publishing/help/com/entry_version_test.rb); SHA-256: `08fcf052394eea43f75cfbf5f59c57d8c2968bf512622b0127aab11bfaf05fcf`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08515"></a>T-08515 / [9](../../../test/models/publishing/help/com/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::EntryVersion)` | [Publishing::Help::Com::EntryVersion](../../../app/models/publishing/help/com/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/publication_test.rb`

[test/models/publishing/help/com/publication_test.rb](../../../test/models/publishing/help/com/publication_test.rb); SHA-256: `23c051336df12c96170a650e8230513e76ac804c6985ae79df9777045a452a2e`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08516"></a>T-08516 / [9](../../../test/models/publishing/help/com/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::Publication)` | [Publishing::Help::Com::Publication](../../../app/models/publishing/help/com/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/revision_media_usage_test.rb`

[test/models/publishing/help/com/revision_media_usage_test.rb](../../../test/models/publishing/help/com/revision_media_usage_test.rb); SHA-256: `bdca0995a63ac6ceb1fb78a8cb0d9c4435a59430bb35c6763d043cc9b2020687`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08517"></a>T-08517 / [9](../../../test/models/publishing/help/com/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::RevisionMediaUsage)` | [Publishing::Help::Com::RevisionMediaUsage](../../../app/models/publishing/help/com/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/taxonomy_term_test.rb`

[test/models/publishing/help/com/taxonomy_term_test.rb](../../../test/models/publishing/help/com/taxonomy_term_test.rb); SHA-256: `7b6018ca644186d9e894c1991585f631892598f9809f7eb920109f65c21d518f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08518"></a>T-08518 / [9](../../../test/models/publishing/help/com/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::TaxonomyTerm)` | [Publishing::Help::Com::TaxonomyTerm](../../../app/models/publishing/help/com/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/version_media_usage_test.rb`

[test/models/publishing/help/com/version_media_usage_test.rb](../../../test/models/publishing/help/com/version_media_usage_test.rb); SHA-256: `82d77340fc29219a96a0efed5ffd5d4423f94ddc50bff3dc3df41a832bd08425`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08519"></a>T-08519 / [9](../../../test/models/publishing/help/com/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::VersionMediaUsage)` | [Publishing::Help::Com::VersionMediaUsage](../../../app/models/publishing/help/com/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/com/vocabulary_test.rb`

[test/models/publishing/help/com/vocabulary_test.rb](../../../test/models/publishing/help/com/vocabulary_test.rb); SHA-256: `efe18720bf24ad5f14d3eb54ceb1f361b0cbfe316d0bb04504b5815288527bf7`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08520"></a>T-08520 / [9](../../../test/models/publishing/help/com/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Com::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Help::Com::Vocabulary)` | [Publishing::Help::Com::Vocabulary](../../../app/models/publishing/help/com/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/entry_revision_test.rb`

[test/models/publishing/help/org/entry_revision_test.rb](../../../test/models/publishing/help/org/entry_revision_test.rb); SHA-256: `a82a8f219b8aabfb5820d92c39484d33095a8e654993ee6f6d5bf715abe9be5c`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08521"></a>T-08521 / [9](../../../test/models/publishing/help/org/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::EntryRevision)` | [Publishing::Help::Org::EntryRevision](../../../app/models/publishing/help/org/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/entry_slug_test.rb`

[test/models/publishing/help/org/entry_slug_test.rb](../../../test/models/publishing/help/org/entry_slug_test.rb); SHA-256: `7f37d0b00a1fa6bf8366c9e4f0f9c8ea1686024c0a6f59bf1bf748e734f2ef08`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08522"></a>T-08522 / [9](../../../test/models/publishing/help/org/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::EntrySlug)` | [Publishing::Help::Org::EntrySlug](../../../app/models/publishing/help/org/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/entry_test.rb`

[test/models/publishing/help/org/entry_test.rb](../../../test/models/publishing/help/org/entry_test.rb); SHA-256: `c88fb7720bddd31d507872c6d6774148113ad2e3104b3f4bfd40a1cc2baf5b7a`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08523"></a>T-08523 / [9](../../../test/models/publishing/help/org/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::EntryTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::Entry)` | [Publishing::Help::Org::Entry](../../../app/models/publishing/help/org/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/entry_version_test.rb`

[test/models/publishing/help/org/entry_version_test.rb](../../../test/models/publishing/help/org/entry_version_test.rb); SHA-256: `27d36f2c66412c6bfe27ef51b59759cc5846cbe1cf94d9f170847f4d345e1ff6`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08524"></a>T-08524 / [9](../../../test/models/publishing/help/org/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::EntryVersion)` | [Publishing::Help::Org::EntryVersion](../../../app/models/publishing/help/org/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/publication_test.rb`

[test/models/publishing/help/org/publication_test.rb](../../../test/models/publishing/help/org/publication_test.rb); SHA-256: `a30b42068b1c835ee604df534103131c46f367c04c5caa84e4850c491a78a5ea`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08525"></a>T-08525 / [9](../../../test/models/publishing/help/org/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::Publication)` | [Publishing::Help::Org::Publication](../../../app/models/publishing/help/org/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/revision_media_usage_test.rb`

[test/models/publishing/help/org/revision_media_usage_test.rb](../../../test/models/publishing/help/org/revision_media_usage_test.rb); SHA-256: `4c40dea3678ff370db1839c4f1938125ba199cae05096e3a5f658b29513383a5`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08526"></a>T-08526 / [9](../../../test/models/publishing/help/org/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::RevisionMediaUsage)` | [Publishing::Help::Org::RevisionMediaUsage](../../../app/models/publishing/help/org/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/taxonomy_term_test.rb`

[test/models/publishing/help/org/taxonomy_term_test.rb](../../../test/models/publishing/help/org/taxonomy_term_test.rb); SHA-256: `024d120a6f0e1f79cfdd537ed8a2235db0f49b890bd90499acaad80962da0e02`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08527"></a>T-08527 / [9](../../../test/models/publishing/help/org/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::TaxonomyTerm)` | [Publishing::Help::Org::TaxonomyTerm](../../../app/models/publishing/help/org/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/version_media_usage_test.rb`

[test/models/publishing/help/org/version_media_usage_test.rb](../../../test/models/publishing/help/org/version_media_usage_test.rb); SHA-256: `ca2ddb53d074bb7a0e3adfb3b8630a190e6a7102b5bf6ee40a44bead55d9a220`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08528"></a>T-08528 / [9](../../../test/models/publishing/help/org/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::VersionMediaUsage)` | [Publishing::Help::Org::VersionMediaUsage](../../../app/models/publishing/help/org/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/help/org/vocabulary_test.rb`

[test/models/publishing/help/org/vocabulary_test.rb](../../../test/models/publishing/help/org/vocabulary_test.rb); SHA-256: `ef3814950babce529b3c788c3b3c7ca8ca5539f425c933af4365e7cfa3df7d3b`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08529"></a>T-08529 / [9](../../../test/models/publishing/help/org/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Help::Org::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Help::Org::Vocabulary)` | [Publishing::Help::Org::Vocabulary](../../../app/models/publishing/help/org/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/entry_revision_test.rb`

[test/models/publishing/info/app/entry_revision_test.rb](../../../test/models/publishing/info/app/entry_revision_test.rb); SHA-256: `f07614bbbf52c990a2df774a4f5fd95106199ebdc72e0ecb6a90f466daa8b695`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08530"></a>T-08530 / [9](../../../test/models/publishing/info/app/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Info::App::EntryRevision)` | [Publishing::Info::App::EntryRevision](../../../app/models/publishing/info/app/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/entry_slug_test.rb`

[test/models/publishing/info/app/entry_slug_test.rb](../../../test/models/publishing/info/app/entry_slug_test.rb); SHA-256: `a5ffb250547f6560511978970cbd7e7ec5ddece79e485f97998a0b7b2ed7d8b1`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08531"></a>T-08531 / [9](../../../test/models/publishing/info/app/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Info::App::EntrySlug)` | [Publishing::Info::App::EntrySlug](../../../app/models/publishing/info/app/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/entry_test.rb`

[test/models/publishing/info/app/entry_test.rb](../../../test/models/publishing/info/app/entry_test.rb); SHA-256: `b7470f0e686541a4c408f2aac49be9d307dedca4e7d9ae4144f915ad2415cd5a`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08532"></a>T-08532 / [9](../../../test/models/publishing/info/app/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::EntryTest` | `assert_public_id_fixed_length(::Publishing::Info::App::Entry)` | [Publishing::Info::App::Entry](../../../app/models/publishing/info/app/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/entry_version_test.rb`

[test/models/publishing/info/app/entry_version_test.rb](../../../test/models/publishing/info/app/entry_version_test.rb); SHA-256: `db5d9e92868430fb3b82ebeecdd3ae7ef76371b64b1d3aebc7808e941a95e2d8`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08533"></a>T-08533 / [9](../../../test/models/publishing/info/app/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Info::App::EntryVersion)` | [Publishing::Info::App::EntryVersion](../../../app/models/publishing/info/app/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/publication_test.rb`

[test/models/publishing/info/app/publication_test.rb](../../../test/models/publishing/info/app/publication_test.rb); SHA-256: `7810386786541f915f181228859317de7c1e247bdfc699c47c6b72e8b3c97614`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08534"></a>T-08534 / [9](../../../test/models/publishing/info/app/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Info::App::Publication)` | [Publishing::Info::App::Publication](../../../app/models/publishing/info/app/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/revision_media_usage_test.rb`

[test/models/publishing/info/app/revision_media_usage_test.rb](../../../test/models/publishing/info/app/revision_media_usage_test.rb); SHA-256: `125acb30c14e5222f7b21a390777c7e828351f96b9155e15b8ee707a7f8bdb4a`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08535"></a>T-08535 / [9](../../../test/models/publishing/info/app/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Info::App::RevisionMediaUsage)` | [Publishing::Info::App::RevisionMediaUsage](../../../app/models/publishing/info/app/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/taxonomy_term_test.rb`

[test/models/publishing/info/app/taxonomy_term_test.rb](../../../test/models/publishing/info/app/taxonomy_term_test.rb); SHA-256: `77222d92d83d1138d0e402492c669e669c9554eca67880ed0825d9fb84dbef7a`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08536"></a>T-08536 / [9](../../../test/models/publishing/info/app/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Info::App::TaxonomyTerm)` | [Publishing::Info::App::TaxonomyTerm](../../../app/models/publishing/info/app/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/version_media_usage_test.rb`

[test/models/publishing/info/app/version_media_usage_test.rb](../../../test/models/publishing/info/app/version_media_usage_test.rb); SHA-256: `48de9ff084141f48499d97c337208efdd3e2f862ec820127ffadaff48ee50273`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08537"></a>T-08537 / [9](../../../test/models/publishing/info/app/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Info::App::VersionMediaUsage)` | [Publishing::Info::App::VersionMediaUsage](../../../app/models/publishing/info/app/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/app/vocabulary_test.rb`

[test/models/publishing/info/app/vocabulary_test.rb](../../../test/models/publishing/info/app/vocabulary_test.rb); SHA-256: `6473b7d55f106ef58faa333a2ee8f24e8384372a0318d0afab164a2768f8af1f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08538"></a>T-08538 / [9](../../../test/models/publishing/info/app/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::App::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Info::App::Vocabulary)` | [Publishing::Info::App::Vocabulary](../../../app/models/publishing/info/app/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/entry_revision_test.rb`

[test/models/publishing/info/com/entry_revision_test.rb](../../../test/models/publishing/info/com/entry_revision_test.rb); SHA-256: `078f43041e45556bd23e687dc4d541c9a7eb20bf12a31769195fd6a3a78eb783`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08539"></a>T-08539 / [9](../../../test/models/publishing/info/com/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::EntryRevision)` | [Publishing::Info::Com::EntryRevision](../../../app/models/publishing/info/com/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/entry_slug_test.rb`

[test/models/publishing/info/com/entry_slug_test.rb](../../../test/models/publishing/info/com/entry_slug_test.rb); SHA-256: `d0b8f860bfecb1cf8b3051fc427762bc055c6a2feec87b2892c163c131ff9960`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08540"></a>T-08540 / [9](../../../test/models/publishing/info/com/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::EntrySlug)` | [Publishing::Info::Com::EntrySlug](../../../app/models/publishing/info/com/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/entry_test.rb`

[test/models/publishing/info/com/entry_test.rb](../../../test/models/publishing/info/com/entry_test.rb); SHA-256: `7c7a86755155df2d47ce1539c3474b4ae40462d79aedbe0d3029d0f3d5975dbc`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08541"></a>T-08541 / [9](../../../test/models/publishing/info/com/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::EntryTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::Entry)` | [Publishing::Info::Com::Entry](../../../app/models/publishing/info/com/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/entry_version_test.rb`

[test/models/publishing/info/com/entry_version_test.rb](../../../test/models/publishing/info/com/entry_version_test.rb); SHA-256: `bdc768a0ea6edf4e2caa92021e3d6cb42f6f3b06726da47cff10d2ba876b7cea`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08542"></a>T-08542 / [9](../../../test/models/publishing/info/com/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::EntryVersion)` | [Publishing::Info::Com::EntryVersion](../../../app/models/publishing/info/com/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/publication_test.rb`

[test/models/publishing/info/com/publication_test.rb](../../../test/models/publishing/info/com/publication_test.rb); SHA-256: `d00bcc945dfcb877fd437cdebe8cb36feb44805bf75bef3a604b130fb7000704`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08543"></a>T-08543 / [9](../../../test/models/publishing/info/com/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::Publication)` | [Publishing::Info::Com::Publication](../../../app/models/publishing/info/com/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/revision_media_usage_test.rb`

[test/models/publishing/info/com/revision_media_usage_test.rb](../../../test/models/publishing/info/com/revision_media_usage_test.rb); SHA-256: `7462ac91b73fe454cd826df789faf672ea680c3c2150c9ba6bf45ddb29d7d231`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08544"></a>T-08544 / [9](../../../test/models/publishing/info/com/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::RevisionMediaUsage)` | [Publishing::Info::Com::RevisionMediaUsage](../../../app/models/publishing/info/com/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/taxonomy_term_test.rb`

[test/models/publishing/info/com/taxonomy_term_test.rb](../../../test/models/publishing/info/com/taxonomy_term_test.rb); SHA-256: `202bb05cb367260f56284ca9894e49b1c0e746289c527e88b4bab92dc0d6caf2`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08545"></a>T-08545 / [9](../../../test/models/publishing/info/com/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::TaxonomyTerm)` | [Publishing::Info::Com::TaxonomyTerm](../../../app/models/publishing/info/com/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/version_media_usage_test.rb`

[test/models/publishing/info/com/version_media_usage_test.rb](../../../test/models/publishing/info/com/version_media_usage_test.rb); SHA-256: `de437b99d9f6b75a2b912096ca54061a267cd47faf0cc9acc43df764077fe17c`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08546"></a>T-08546 / [9](../../../test/models/publishing/info/com/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::VersionMediaUsage)` | [Publishing::Info::Com::VersionMediaUsage](../../../app/models/publishing/info/com/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/com/vocabulary_test.rb`

[test/models/publishing/info/com/vocabulary_test.rb](../../../test/models/publishing/info/com/vocabulary_test.rb); SHA-256: `32d5be4f4a128ae6517ee592b3a8c91fe5dbeca06104d2538643b09a6c94116f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08547"></a>T-08547 / [9](../../../test/models/publishing/info/com/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Com::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Info::Com::Vocabulary)` | [Publishing::Info::Com::Vocabulary](../../../app/models/publishing/info/com/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/entry_revision_test.rb`

[test/models/publishing/info/org/entry_revision_test.rb](../../../test/models/publishing/info/org/entry_revision_test.rb); SHA-256: `fb123cab02d3fee93dbd6cc88fa9eb1600c07ae3f6c8047a0d5e0a72ebf873e1`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08548"></a>T-08548 / [9](../../../test/models/publishing/info/org/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::EntryRevision)` | [Publishing::Info::Org::EntryRevision](../../../app/models/publishing/info/org/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/entry_slug_test.rb`

[test/models/publishing/info/org/entry_slug_test.rb](../../../test/models/publishing/info/org/entry_slug_test.rb); SHA-256: `e4c73a6328d7f499c688a4764324fd981e69c3e3a659f47bbef5bef5e6f249e9`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08549"></a>T-08549 / [9](../../../test/models/publishing/info/org/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::EntrySlug)` | [Publishing::Info::Org::EntrySlug](../../../app/models/publishing/info/org/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/entry_test.rb`

[test/models/publishing/info/org/entry_test.rb](../../../test/models/publishing/info/org/entry_test.rb); SHA-256: `3fc1574d0b5c2d8392073530106d1582b0eb5bec279e51343cfc6eedb6d9cab7`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08550"></a>T-08550 / [9](../../../test/models/publishing/info/org/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::EntryTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::Entry)` | [Publishing::Info::Org::Entry](../../../app/models/publishing/info/org/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/entry_version_test.rb`

[test/models/publishing/info/org/entry_version_test.rb](../../../test/models/publishing/info/org/entry_version_test.rb); SHA-256: `249470de00fc823b0b61d5c273de0ed21c76964db2b64fd4c0767df81da0ec5f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08551"></a>T-08551 / [9](../../../test/models/publishing/info/org/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::EntryVersion)` | [Publishing::Info::Org::EntryVersion](../../../app/models/publishing/info/org/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/publication_test.rb`

[test/models/publishing/info/org/publication_test.rb](../../../test/models/publishing/info/org/publication_test.rb); SHA-256: `7efb1d44cad6ca89988caa5c7242766e8eecbb43401db45bb98f6dc725c0b04c`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08552"></a>T-08552 / [9](../../../test/models/publishing/info/org/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::PublicationTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::Publication)` | [Publishing::Info::Org::Publication](../../../app/models/publishing/info/org/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/revision_media_usage_test.rb`

[test/models/publishing/info/org/revision_media_usage_test.rb](../../../test/models/publishing/info/org/revision_media_usage_test.rb); SHA-256: `bd397f510a863604d284d40b9320363b9369bc46f37f1044837a66388ff07e88`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08553"></a>T-08553 / [9](../../../test/models/publishing/info/org/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::RevisionMediaUsage)` | [Publishing::Info::Org::RevisionMediaUsage](../../../app/models/publishing/info/org/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/taxonomy_term_test.rb`

[test/models/publishing/info/org/taxonomy_term_test.rb](../../../test/models/publishing/info/org/taxonomy_term_test.rb); SHA-256: `bc7b8ad6c13c2ea23774bf88c98035a53022161a8aef3ec9bf946c3f4aad6772`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08554"></a>T-08554 / [9](../../../test/models/publishing/info/org/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::TaxonomyTerm)` | [Publishing::Info::Org::TaxonomyTerm](../../../app/models/publishing/info/org/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/version_media_usage_test.rb`

[test/models/publishing/info/org/version_media_usage_test.rb](../../../test/models/publishing/info/org/version_media_usage_test.rb); SHA-256: `1ebd1210d28340ed8552e780dd216348826d761610e3274afb37ccbe5fea0d20`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08555"></a>T-08555 / [9](../../../test/models/publishing/info/org/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::VersionMediaUsage)` | [Publishing::Info::Org::VersionMediaUsage](../../../app/models/publishing/info/org/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/info/org/vocabulary_test.rb`

[test/models/publishing/info/org/vocabulary_test.rb](../../../test/models/publishing/info/org/vocabulary_test.rb); SHA-256: `5de93113670f7705f6b0b7444093abf32bc45dcfc6763aa168ee7c5c6a7b177c`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08556"></a>T-08556 / [9](../../../test/models/publishing/info/org/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::Info::Org::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::Info::Org::Vocabulary)` | [Publishing::Info::Org::Vocabulary](../../../app/models/publishing/info/org/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/media_file_attachment_test.rb`

[test/models/publishing/media_file_attachment_test.rb](../../../test/models/publishing/media_file_attachment_test.rb); SHA-256: `f56667fe3c97a2130f8c058c895a9142e01e449b94e55a6867fafc529a01a757`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08557"></a>T-08557 / [12](../../../test/models/publishing/media_file_attachment_test.rb#L12) | "a valid png is stored on the publishing boundary and persisted in the publishing database"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_predicate media.file, :present?`; `assert_equal :publishing_store, media.file.storage_key`; `assert_equal "image/png", media.content_type`; +7 further assertion lines | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4); [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08558"></a>T-08558 / [39](../../../test/models/publishing/media_file_attachment_test.rb#L39) | "a non-image is rejected"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_not media.save`; `assert_not_empty media.errors[:file]` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08559"></a>T-08559 / [47](../../../test/models/publishing/media_file_attachment_test.rb#L47) | "an oversized file is rejected"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_not media.save`; `assert_not_empty media.errors[:file]` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4); [PublishingMediaUploader](../../../app/uploaders/publishing_media_uploader.rb#L3) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08560"></a>T-08560 / [55](../../../test/models/publishing/media_file_attachment_test.rb#L55) | "a shrine media file remains usable as a revision media usage target"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_equal media.id, usage.media_file_id`; `assert_equal media.id, copied.media_file_id` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4); [Publishing::ContentFamilies](../../../app/models/publishing/content_families.rb#L7) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08561"></a>T-08561 / [88](../../../test/models/publishing/media_file_attachment_test.rb#L88) | "deleting a media file without usages removes the shrine object"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_not previous_storage.exists?(previous_id)`; `assert_nil Publishing::MediaFile.find_by(id: media.id)` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08562"></a>T-08562 / [101](../../../test/models/publishing/media_file_attachment_test.rb#L101) | "missing and empty public identities still mint 21 characters"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_equal 21, media.reload.public_id.length`; `assert_match(/\A[A-Za-z0-9_-]{21}\z/, media.public_id)` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08563"></a>T-08563 / [112](../../../test/models/publishing/media_file_attachment_test.rb#L112) | "database currently requires exactly 21 public identity characters"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_instance_of cause, error.cause`; `assert_equal original, media.reload.public_id` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4); [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08564"></a>T-08564 / [141](../../../test/models/publishing/media_file_attachment_test.rb#L141) | "database keeps public identity uniqueness and null refusal"<br>Owner: `Publishing::MediaFileAttachmentTest` | `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_instance_of cause, error.cause`; `assert_equal original, second.reload.public_id` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4); [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/media_file_test.rb`

[test/models/publishing/media_file_test.rb](../../../test/models/publishing/media_file_test.rb); SHA-256: `07d520f5ec329ba744d50c8ea707bbaada322122c04f13eb404036ea6d31e655`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08565"></a>T-08565 / [7](../../../test/models/publishing/media_file_test.rb#L7) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::MediaFileTest` | `assert_public_id_fixed_length(::Publishing::MediaFile)` | [Publishing::MediaFile](../../../app/models/publishing/media_file.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/media_storage_key_uniqueness_test.rb`

[test/models/publishing/media_storage_key_uniqueness_test.rb](../../../test/models/publishing/media_storage_key_uniqueness_test.rb); SHA-256: `5950da8f2b08e148b0102ea2bf1cc81fec1c9559444c67fef9f3d3e73f9aaaa1`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08566"></a>T-08566 / [10](../../../test/models/publishing/media_storage_key_uniqueness_test.rb#L10) | "storage references retain raw UNIQUE and NOT NULL enforcement"<br>Owner: `Publishing::MediaStorageKeyUniquenessTest` | `assert_equal "consistency/first", first.reload.storage_key`; `assert_equal "consistency/other", other.reload.storage_key`; `assert_raises(ActiveRecord::RecordNotUnique) do`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08567"></a>T-08567 / [30](../../../test/models/publishing/media_storage_key_uniqueness_test.rb#L30) | "a duplicate storage reference is refused before model creation"<br>Owner: `Publishing::MediaStorageKeyUniquenessTest` | `assert_not candidate.valid?`; `assert candidate.errors.of_kind?(:storage_key, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08568"></a>T-08568 / [41](../../../test/models/publishing/media_storage_key_uniqueness_test.rb#L41) | "post-promotion metadata resynchronization still exposes a conflicting DB reference"<br>Owner: `Publishing::MediaStorageKeyUniquenessTest` | `assert_raises(ActiveRecord::RecordNotUnique) { media.save!(validate: false) }`; `assert_equal detached_key, media.reload.storage_key`; `assert_equal original_key, shadow.reload.storage_key`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/media_usage_ownership_test.rb`

[test/models/publishing/media_usage_ownership_test.rb](../../../test/models/publishing/media_usage_ownership_test.rb); SHA-256: `635683272652a0f99d2cb575f1b475268f29b62517395440d0f12c5ae212a47e`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08569"></a>T-08569 / [13](../../../test/models/publishing/media_usage_ownership_test.rb#L13) | "publishing_media_usages no longer exists"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_not PublishingRecord.connection.table_exists?("publishing_media_usages")`; `assert_raises(NameError) { Publishing.const_get(:MediaUsage) }` | [PublishingRecord](../../../app/models/publishing_record.rb#L6); [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08570"></a>T-08570 / [18](../../../test/models/publishing/media_usage_ownership_test.rb#L18) | "revision media usages have a required revision owner and no derived or version columns"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_includes columns, "entry_revision_id"`; `assert_not_includes columns, "entry_version_id"`; `assert_not_includes columns, "entry_id"`; +2 further assertion lines | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08571"></a>T-08571 / [32](../../../test/models/publishing/media_usage_ownership_test.rb#L32) | "version media usages have a required version owner and no derived or revision columns"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_includes columns, "entry_version_id"`; `assert_not_includes columns, "entry_revision_id"`; `assert_not_includes columns, "entry_id"`; +2 further assertion lines | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08572"></a>T-08572 / [46](../../../test/models/publishing/media_usage_ownership_test.rb#L46) | "revision media remains editable until the revision is promoted"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_equal 3, usage.reload.position`; `assert_equal "draft", usage.caption`; `assert_nothing_raised { usage.destroy! }` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08573"></a>T-08573 / [59](../../../test/models/publishing/media_usage_ownership_test.rb#L59) | "a usage that names no location in the document is refused"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_not usage.valid?`; `assert_equal ["must have a field_path or block_path"], usage.errors[:base]` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08574"></a>T-08574 / [68](../../../test/models/publishing/media_usage_ownership_test.rb#L68) | "either path alone is enough to locate the usage"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_predicate field_only, :valid?`; `assert_predicate block_only, :valid?` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08575"></a>T-08575 / [80](../../../test/models/publishing/media_usage_ownership_test.rb#L80) | "duplicate revision media positions are rejected"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_raises(ActiveRecord::RecordNotUnique) do` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08576"></a>T-08576 / [90](../../../test/models/publishing/media_usage_ownership_test.rb#L90) | "promotion copies placement and presentation fields onto the immutable version"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_equal 2, copied.size`; `assert_equal [@media_file.id, second.id], copied.map(&:media_file_id)`; `assert_equal %w(hero body), copied.map(&:role)`; +4 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08577"></a>T-08577 / [112](../../../test/models/publishing/media_usage_ownership_test.rb#L112) | "released version media is immutable through active record and postgresql"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_raises(ActiveRecord::ReadOnlyRecord) { usage.update!(caption: "changed") }`; `assert_raises(ActiveRecord::ReadOnlyRecord) { usage.destroy! }`; `assert_database_rejects do`; +1 further assertion lines | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08578"></a>T-08578 / [131](../../../test/models/publishing/media_usage_ownership_test.rb#L131) | "a promoted revision can no longer change its media usages"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_database_rejects do` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08579"></a>T-08579 / [142](../../../test/models/publishing/media_usage_ownership_test.rb#L142) | "restore copies version media onto a new editable revision"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_equal @media_file.id, copied.media_file_id`; `assert_equal "hero", copied.role`; `assert_equal "restored draft", copied.reload.caption` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08580"></a>T-08580 / [158](../../../test/models/publishing/media_usage_ownership_test.rb#L158) | "canonical schema creates owner-explicit media tables and never the union table"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_includes schema, "_revision_media_usages"`; `assert_includes schema, "_version_media_usages"`; `assert_no_match(/create_table\(?\s*:publishing_media_usages\b/, schema)`; +2 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08581"></a>T-08581 / [169](../../../test/models/publishing/media_usage_ownership_test.rb#L169) | "commit rejects version media that differs in presentation fields"<br>Owner: `Publishing::MediaUsageOwnershipTest` | `assert_raises(ActiveRecord::StatementInvalid) do` | [PublishingRecord](../../../app/models/publishing_record.rb#L6); [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/entry_revision_test.rb`

[test/models/publishing/news/app/entry_revision_test.rb](../../../test/models/publishing/news/app/entry_revision_test.rb); SHA-256: `90e773a485af3ee1414eaef2d0d194162e463e8abc3a8b9ca9ed89aabad83dc6`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08582"></a>T-08582 / [9](../../../test/models/publishing/news/app/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::News::App::EntryRevision)` | [Publishing::News::App::EntryRevision](../../../app/models/publishing/news/app/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/entry_slug_test.rb`

[test/models/publishing/news/app/entry_slug_test.rb](../../../test/models/publishing/news/app/entry_slug_test.rb); SHA-256: `39976a71161b22a72e5e59732e62958f27a3803d33d1c6ad812016537d65c333`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08583"></a>T-08583 / [9](../../../test/models/publishing/news/app/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::News::App::EntrySlug)` | [Publishing::News::App::EntrySlug](../../../app/models/publishing/news/app/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/entry_test.rb`

[test/models/publishing/news/app/entry_test.rb](../../../test/models/publishing/news/app/entry_test.rb); SHA-256: `0c5ca5cc9f777b6e6f462737e76cd10993c0a87cdaad4d2ead95003a43d58581`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08584"></a>T-08584 / [9](../../../test/models/publishing/news/app/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::EntryTest` | `assert_public_id_fixed_length(::Publishing::News::App::Entry)` | [Publishing::News::App::Entry](../../../app/models/publishing/news/app/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/entry_version_test.rb`

[test/models/publishing/news/app/entry_version_test.rb](../../../test/models/publishing/news/app/entry_version_test.rb); SHA-256: `eb98b306f753001943f32c04fb01d0bf18f7391ee7a17ea3d49ba745c16150e0`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08585"></a>T-08585 / [9](../../../test/models/publishing/news/app/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::News::App::EntryVersion)` | [Publishing::News::App::EntryVersion](../../../app/models/publishing/news/app/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/publication_test.rb`

[test/models/publishing/news/app/publication_test.rb](../../../test/models/publishing/news/app/publication_test.rb); SHA-256: `04e7916cd1d8414df5caec159872529d7c7b8b9c10c052fe98cddd874173653f`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08586"></a>T-08586 / [9](../../../test/models/publishing/news/app/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::PublicationTest` | `assert_public_id_fixed_length(::Publishing::News::App::Publication)` | [Publishing::News::App::Publication](../../../app/models/publishing/news/app/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/revision_media_usage_test.rb`

[test/models/publishing/news/app/revision_media_usage_test.rb](../../../test/models/publishing/news/app/revision_media_usage_test.rb); SHA-256: `8b9df43510e4af9bdda3c81905f6c23c3ada3a84a3a0472f9086c33b171bea13`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08587"></a>T-08587 / [9](../../../test/models/publishing/news/app/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::News::App::RevisionMediaUsage)` | [Publishing::News::App::RevisionMediaUsage](../../../app/models/publishing/news/app/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/taxonomy_term_test.rb`

[test/models/publishing/news/app/taxonomy_term_test.rb](../../../test/models/publishing/news/app/taxonomy_term_test.rb); SHA-256: `93a38c089a6dbc9ccea3a228082d6b830721b95091e44ccfb274ceed459bc69d`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08588"></a>T-08588 / [9](../../../test/models/publishing/news/app/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::News::App::TaxonomyTerm)` | [Publishing::News::App::TaxonomyTerm](../../../app/models/publishing/news/app/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/version_media_usage_test.rb`

[test/models/publishing/news/app/version_media_usage_test.rb](../../../test/models/publishing/news/app/version_media_usage_test.rb); SHA-256: `ae2e428bab3eebcec9a2508dbbdfed3acd5225edf822b97bccf01ddb31bff3dd`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08589"></a>T-08589 / [9](../../../test/models/publishing/news/app/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::News::App::VersionMediaUsage)` | [Publishing::News::App::VersionMediaUsage](../../../app/models/publishing/news/app/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/app/vocabulary_test.rb`

[test/models/publishing/news/app/vocabulary_test.rb](../../../test/models/publishing/news/app/vocabulary_test.rb); SHA-256: `043dc8789304263580ec1e4c7e76b4173cd0808b34b4e08b1a1a2d437ffbaf78`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08590"></a>T-08590 / [9](../../../test/models/publishing/news/app/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::App::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::News::App::Vocabulary)` | [Publishing::News::App::Vocabulary](../../../app/models/publishing/news/app/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/entry_revision_test.rb`

[test/models/publishing/news/com/entry_revision_test.rb](../../../test/models/publishing/news/com/entry_revision_test.rb); SHA-256: `25802247441f15cf3f6ace00d04eacd134e6601bb2a43d7682c8e1e965d736dd`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08591"></a>T-08591 / [9](../../../test/models/publishing/news/com/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::News::Com::EntryRevision)` | [Publishing::News::Com::EntryRevision](../../../app/models/publishing/news/com/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/entry_slug_test.rb`

[test/models/publishing/news/com/entry_slug_test.rb](../../../test/models/publishing/news/com/entry_slug_test.rb); SHA-256: `bdc692a03d5bfed63d3bece8a5ba1ba0d099fd86d60b7af9774fae625aaf0806`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08592"></a>T-08592 / [9](../../../test/models/publishing/news/com/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::News::Com::EntrySlug)` | [Publishing::News::Com::EntrySlug](../../../app/models/publishing/news/com/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/entry_test.rb`

[test/models/publishing/news/com/entry_test.rb](../../../test/models/publishing/news/com/entry_test.rb); SHA-256: `bea43742be67862cb53fc8985ac1834e3171c3b8e5390a1e38ba4709bb7e6bb7`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08593"></a>T-08593 / [9](../../../test/models/publishing/news/com/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::EntryTest` | `assert_public_id_fixed_length(::Publishing::News::Com::Entry)` | [Publishing::News::Com::Entry](../../../app/models/publishing/news/com/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/entry_version_test.rb`

[test/models/publishing/news/com/entry_version_test.rb](../../../test/models/publishing/news/com/entry_version_test.rb); SHA-256: `dfea3664e5db7f7f9aba386b4e537fef13d65478e2b84de77cccd59ccb7b7857`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08594"></a>T-08594 / [9](../../../test/models/publishing/news/com/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::News::Com::EntryVersion)` | [Publishing::News::Com::EntryVersion](../../../app/models/publishing/news/com/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/publication_test.rb`

[test/models/publishing/news/com/publication_test.rb](../../../test/models/publishing/news/com/publication_test.rb); SHA-256: `83037f6574929df8f79deb9023a0748fa77734447f277735ff5a298479128023`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08595"></a>T-08595 / [9](../../../test/models/publishing/news/com/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::PublicationTest` | `assert_public_id_fixed_length(::Publishing::News::Com::Publication)` | [Publishing::News::Com::Publication](../../../app/models/publishing/news/com/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/revision_media_usage_test.rb`

[test/models/publishing/news/com/revision_media_usage_test.rb](../../../test/models/publishing/news/com/revision_media_usage_test.rb); SHA-256: `06bd276836b6f53d1fa148f88557f2fabe8c3062b8043459eef74c220a23db8e`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08596"></a>T-08596 / [9](../../../test/models/publishing/news/com/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::News::Com::RevisionMediaUsage)` | [Publishing::News::Com::RevisionMediaUsage](../../../app/models/publishing/news/com/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/taxonomy_term_test.rb`

[test/models/publishing/news/com/taxonomy_term_test.rb](../../../test/models/publishing/news/com/taxonomy_term_test.rb); SHA-256: `827cbed1accf68a7d52bae0d63e4e8330e5db317fe0015cb608bbd806f3d978d`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08597"></a>T-08597 / [9](../../../test/models/publishing/news/com/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::News::Com::TaxonomyTerm)` | [Publishing::News::Com::TaxonomyTerm](../../../app/models/publishing/news/com/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/version_media_usage_test.rb`

[test/models/publishing/news/com/version_media_usage_test.rb](../../../test/models/publishing/news/com/version_media_usage_test.rb); SHA-256: `8f5f34359fec093d77267e435a987095f292c6ccde4ba4ec3df2b2700721b5ed`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08598"></a>T-08598 / [9](../../../test/models/publishing/news/com/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::News::Com::VersionMediaUsage)` | [Publishing::News::Com::VersionMediaUsage](../../../app/models/publishing/news/com/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/com/vocabulary_test.rb`

[test/models/publishing/news/com/vocabulary_test.rb](../../../test/models/publishing/news/com/vocabulary_test.rb); SHA-256: `3d0212bf0f83c02580de8c3add35c5454df8da51b5708f1405262507f9865dc1`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08599"></a>T-08599 / [9](../../../test/models/publishing/news/com/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Com::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::News::Com::Vocabulary)` | [Publishing::News::Com::Vocabulary](../../../app/models/publishing/news/com/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/entry_revision_test.rb`

[test/models/publishing/news/org/entry_revision_test.rb](../../../test/models/publishing/news/org/entry_revision_test.rb); SHA-256: `247e021c618eae3873473af1f9fcaebd7ad8d11047eb81f297a569612ff26042`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08600"></a>T-08600 / [9](../../../test/models/publishing/news/org/entry_revision_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::EntryRevisionTest` | `assert_public_id_fixed_length(::Publishing::News::Org::EntryRevision)` | [Publishing::News::Org::EntryRevision](../../../app/models/publishing/news/org/entry_revision.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/entry_slug_test.rb`

[test/models/publishing/news/org/entry_slug_test.rb](../../../test/models/publishing/news/org/entry_slug_test.rb); SHA-256: `191b76c52642dcd45397109e899cf8bc6a67cc8277ded5845f1633a78c99c979`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08601"></a>T-08601 / [9](../../../test/models/publishing/news/org/entry_slug_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::EntrySlugTest` | `assert_public_id_fixed_length(::Publishing::News::Org::EntrySlug)` | [Publishing::News::Org::EntrySlug](../../../app/models/publishing/news/org/entry_slug.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/entry_test.rb`

[test/models/publishing/news/org/entry_test.rb](../../../test/models/publishing/news/org/entry_test.rb); SHA-256: `6ca644442d2cbb083baf94df93a74297fabcb5412d3a4da387283228bde5caf5`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08602"></a>T-08602 / [9](../../../test/models/publishing/news/org/entry_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::EntryTest` | `assert_public_id_fixed_length(::Publishing::News::Org::Entry)` | [Publishing::News::Org::Entry](../../../app/models/publishing/news/org/entry.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/entry_version_test.rb`

[test/models/publishing/news/org/entry_version_test.rb](../../../test/models/publishing/news/org/entry_version_test.rb); SHA-256: `e372186ae0e1983354c46cc134c1679c9d713e8206a7b54a6e2f24be56094ceb`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08603"></a>T-08603 / [9](../../../test/models/publishing/news/org/entry_version_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::EntryVersionTest` | `assert_public_id_fixed_length(::Publishing::News::Org::EntryVersion)` | [Publishing::News::Org::EntryVersion](../../../app/models/publishing/news/org/entry_version.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/publication_test.rb`

[test/models/publishing/news/org/publication_test.rb](../../../test/models/publishing/news/org/publication_test.rb); SHA-256: `0c395cc0e162c042f49383efe3a26804adc2c1d69da5e7e81fc25578d16376e0`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08604"></a>T-08604 / [9](../../../test/models/publishing/news/org/publication_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::PublicationTest` | `assert_public_id_fixed_length(::Publishing::News::Org::Publication)` | [Publishing::News::Org::Publication](../../../app/models/publishing/news/org/publication.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/revision_media_usage_test.rb`

[test/models/publishing/news/org/revision_media_usage_test.rb](../../../test/models/publishing/news/org/revision_media_usage_test.rb); SHA-256: `7bc0693f5a3aca7e97c3930947052d61757cadd197927809a22bdb6b0af14018`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08605"></a>T-08605 / [9](../../../test/models/publishing/news/org/revision_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::RevisionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::News::Org::RevisionMediaUsage)` | [Publishing::News::Org::RevisionMediaUsage](../../../app/models/publishing/news/org/revision_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/taxonomy_term_test.rb`

[test/models/publishing/news/org/taxonomy_term_test.rb](../../../test/models/publishing/news/org/taxonomy_term_test.rb); SHA-256: `ca9cf1e29532eb69a6fad8c13b3c6590b21279f64ef9cdb01eb3a0ebab677982`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08606"></a>T-08606 / [9](../../../test/models/publishing/news/org/taxonomy_term_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::TaxonomyTermTest` | `assert_public_id_fixed_length(::Publishing::News::Org::TaxonomyTerm)` | [Publishing::News::Org::TaxonomyTerm](../../../app/models/publishing/news/org/taxonomy_term.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/version_media_usage_test.rb`

[test/models/publishing/news/org/version_media_usage_test.rb](../../../test/models/publishing/news/org/version_media_usage_test.rb); SHA-256: `60390724240ec257c31fd66b41d1e02db338df87ad3da5ebe8994c76f73e6f56`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08607"></a>T-08607 / [9](../../../test/models/publishing/news/org/version_media_usage_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::VersionMediaUsageTest` | `assert_public_id_fixed_length(::Publishing::News::Org::VersionMediaUsage)` | [Publishing::News::Org::VersionMediaUsage](../../../app/models/publishing/news/org/version_media_usage.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/news/org/vocabulary_test.rb`

[test/models/publishing/news/org/vocabulary_test.rb](../../../test/models/publishing/news/org/vocabulary_test.rb); SHA-256: `9a9bf113b6157c9f79d54128036c3805c7dc3e25f61cb779806b3a8efdb38f3a`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08608"></a>T-08608 / [9](../../../test/models/publishing/news/org/vocabulary_test.rb#L9) | "public_id is a fixed 21-character NanoID"<br>Owner: `Publishing::News::Org::VocabularyTest` | `assert_public_id_fixed_length(::Publishing::News::Org::Vocabulary)` | [Publishing::News::Org::Vocabulary](../../../app/models/publishing/news/org/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/ordered_taxonomy_position_contract_test.rb`

[test/models/publishing/ordered_taxonomy_position_contract_test.rb](../../../test/models/publishing/ordered_taxonomy_position_contract_test.rb); SHA-256: `decda8030b74130ccd9371e47ab7caf909b931f73f2268798d643f783b8d8fec`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08609"></a>T-08609 / [72](../../../test/models/publishing/ordered_taxonomy_position_contract_test.rb#L72) | "#{revision_assignment_class.name} and its version preserve bounded positions and immutable snapshots"<br>Owner: `Publishing::OrderedTaxonomyPositionContractTest` | `assert_equal expected_position, assignment.reload.position`; `assert_equal expected_position, snapshot.position`; `assert_equal expected_position, snapshot.position_snapshot`; +2 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08610"></a>T-08610 / [109](../../../test/models/publishing/ordered_taxonomy_position_contract_test.rb#L109) | "#{revision_assignment_class.name} rejects missing noninteger and out-of-range positions"<br>Owner: `Publishing::OrderedTaxonomyPositionContractTest` | `assert_not assignment.valid?, "position #{position.inspect} must be rejected"`; `assert_not_empty assignment.errors[:position]`; `assert_not_empty assignment.errors.full_messages`; +1 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08611"></a>T-08611 / [137](../../../test/models/publishing/ordered_taxonomy_position_contract_test.rb#L137) | "#{version_assignment_class.name} rejects invalid positions on creation"<br>Owner: `Publishing::OrderedTaxonomyPositionContractTest` | `assert_equal assignment.taxonomy_term_id, snapshot.taxonomy_term_id`; `assert_not candidate.valid?, "position #{position.inspect} must be rejected"`; `assert_not_empty candidate.errors[:position]`; +2 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08612"></a>T-08612 / [173](../../../test/models/publishing/ordered_taxonomy_position_contract_test.rb#L173) | "#{revision_assignment_class.name} database rejects invalid positions independently"<br>Owner: `Publishing::OrderedTaxonomyPositionContractTest` | `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_instance_of cause_class, error.cause`; `assert_equal "position", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)`; +2 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08613"></a>T-08613 / [219](../../../test/models/publishing/ordered_taxonomy_position_contract_test.rb#L219) | "#{version_assignment_class.name} database rejects invalid position inserts independently"<br>Owner: `Publishing::OrderedTaxonomyPositionContractTest` | `assert_equal assignment.taxonomy_term_id, snapshot.taxonomy_term_id`; `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_instance_of cause_class, error.cause`; +4 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/required_creation_fields_test.rb`

[test/models/publishing/required_creation_fields_test.rb](../../../test/models/publishing/required_creation_fields_test.rb); SHA-256: `4753f90e6165d82769e92b151a41421711de2f141df66ddcc23e17e2ea7f5df1`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08614"></a>T-08614 / [35](../../../test/models/publishing/required_creation_fields_test.rb#L35) | "#{entry_class.name} family preserves nonnull locale partitions and SQL null refusal"<br>Owner: `Publishing::RequiredCreationFieldsTest` | `assert_equal({ false =&gt; "f", 0 =&gt; "0" }.fetch(locale, locale), expected)`; `assert_equal expected, record.reload.locale`; `assert_raises(ActiveRecord::NotNullViolation) do`; +4 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08615"></a>T-08615 / [73](../../../test/models/publishing/required_creation_fields_test.rb#L73) | "#{entry_class.name} family rejects nil locale before creation"<br>Owner: `Publishing::RequiredCreationFieldsTest` | `assert_not record.valid?, "#{record.class.name} must reject nil locale"`; `assert_not_empty record.errors[:locale]`; `assert_raises(ActiveRecord::RecordInvalid) { record.save! }`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08616"></a>T-08616 / [99](../../../test/models/publishing/required_creation_fields_test.rb#L99) | "#{publication_class.name} requires a start while preserving nullable end and updates"<br>Owner: `Publishing::RequiredCreationFieldsTest` | `assert_not publication.valid?`; `assert_not_empty publication.errors[:effective_from]`; `assert_raises(ActiveRecord::RecordInvalid) { publication.save! }`; +6 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/revision_sequence_contract_test.rb`

[test/models/publishing/revision_sequence_contract_test.rb](../../../test/models/publishing/revision_sequence_contract_test.rb); SHA-256: `29f771360ac9caed998bae6066f6af43da4e41fef787a4e65006facec46024f9`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08617"></a>T-08617 / [23](../../../test/models/publishing/revision_sequence_contract_test.rb#L23) | "#{revision_class.name} saves positive sequences at both integer boundaries"<br>Owner: `Publishing::RevisionSequenceContractTest` | `assert_equal sequence, revision.reload.sequence` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08618"></a>T-08618 / [37](../../../test/models/publishing/revision_sequence_contract_test.rb#L37) | "#{revision_class.name} rejects missing noninteger and out-of-range sequences before persistence"<br>Owner: `Publishing::RevisionSequenceContractTest` | `assert_not revision.valid?, "sequence #{sequence.inspect} must be rejected"`; `assert_not_empty revision.errors[:sequence]`; `assert_not_empty revision.errors.full_messages`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08619"></a>T-08619 / [54](../../../test/models/publishing/revision_sequence_contract_test.rb#L54) | "#{revision_class.name} accepts the existing integer-string assignment contract"<br>Owner: `Publishing::RevisionSequenceContractTest` | `assert_equal 1, revision.reload.sequence` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08620"></a>T-08620 / [65](../../../test/models/publishing/revision_sequence_contract_test.rb#L65) | "#{revision_class.name} database rejects invalid sequences without model validation"<br>Owner: `Publishing::RevisionSequenceContractTest` | `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_instance_of cause_class, error.cause`; `assert_equal "sequence", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)`; +2 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/revision_sequence_uniqueness_test.rb`

[test/models/publishing/revision_sequence_uniqueness_test.rb](../../../test/models/publishing/revision_sequence_uniqueness_test.rb); SHA-256: `a7082ab0ae659de6079f901be30cdf46920e9f24fbe31fcda50307c334325eb3`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08621"></a>T-08621 / [23](../../../test/models/publishing/revision_sequence_uniqueness_test.rb#L23) | "#{revision_class.name} scopes sequence uniqueness to an entry and retains DB enforcement"<br>Owner: `Publishing::RevisionSequenceUniquenessTest` | `assert_equal 1, first.reload.sequence`; `assert_equal 1, second.reload.sequence`; `assert_equal 2, adjacent.reload.sequence`; +2 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08622"></a>T-08622 / [50](../../../test/models/publishing/revision_sequence_uniqueness_test.rb#L50) | "#{revision_class.name} refuses a duplicate sequence before creation"<br>Owner: `Publishing::RevisionSequenceUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:sequence, :taken)`; `assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/schema_and_models_test.rb`

[test/models/publishing/schema_and_models_test.rb](../../../test/models/publishing/schema_and_models_test.rb); SHA-256: `d29b9838fae3ba58c2825af03e85847fa30593f8acc7f8795cbd2002b56e6219`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08623"></a>T-08623 / [19](../../../test/models/publishing/schema_and_models_test.rb#L19) | "obsolete generic lifecycle tables are absent"<br>Owner: `Publishing::SchemaAndModelsTest` | `assert_not PublishingRecord.connection.table_exists?(table), "expected #{table} to be gone"` | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08624"></a>T-08624 / [25](../../../test/models/publishing/schema_and_models_test.rb#L25) | "all twelve family table sets and global media files exist"<br>Owner: `Publishing::SchemaAndModelsTest` | `assert PublishingRecord.connection.table_exists?("publishing_media_files")`; `assert PublishingRecord.connection.table_exists?(table), "expected #{table}"` | [PublishingRecord](../../../app/models/publishing_record.rb#L6); [Publishing::ContentFamilies](../../../app/models/publishing/content_families.rb#L7) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08625"></a>T-08625 / [43](../../../test/models/publishing/schema_and_models_test.rb#L43) | "family tables do not store audience or surface ownership columns"<br>Owner: `Publishing::SchemaAndModelsTest` | `assert_not_includes names, "audience"`; `assert_not_includes names, "surface"` | [PublishingRecord](../../../app/models/publishing_record.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08626"></a>T-08626 / [56](../../../test/models/publishing/schema_and_models_test.rb#L56) | "builds a docs/app lifecycle without an edition"<br>Owner: `Publishing::SchemaAndModelsTest` | `assert_not publication.cancelled?`; `assert_includes entry.publications.merge(entry.publications.klass.active), publication` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08627"></a>T-08627 / [65](../../../test/models/publishing/schema_and_models_test.rb#L65) | "entry versions are immutable after creation"<br>Owner: `Publishing::SchemaAndModelsTest` | `assert_raises(ActiveRecord::ReadOnlyRecord) { version.update!(title: "changed") }`; `assert_raises(ActiveRecord::ReadOnlyRecord) { version.destroy! }` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08628"></a>T-08628 / [73](../../../test/models/publishing/schema_and_models_test.rb#L73) | "publications reject overlapping windows for the same entry"<br>Owner: `Publishing::SchemaAndModelsTest` | `assert_raises(ActiveRecord::StatementInvalid) {` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/snapshot_public_id_capacity_contract_test.rb`

[test/models/publishing/snapshot_public_id_capacity_contract_test.rb](../../../test/models/publishing/snapshot_public_id_capacity_contract_test.rb); SHA-256: `8dbbf40ec09f7cc2c7fedf03665a03368c22d1b9932938528a7b10c8cac9ec68`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08629"></a>T-08629 / [132](../../../test/models/publishing/snapshot_public_id_capacity_contract_test.rb#L132) | "#{snapshot_class.name} preserves short supplied IDs and derives the authoritative snapshot"<br>Owner: `Publishing::SnapshotPublicIdCapacityContractTest` | `assert_equal size, snapshot.vocabulary_public_id_snapshot.length`; `assert_equal size, snapshot.term_public_id_snapshot.length`; `assert_equal vocabulary.public_id, snapshot.reload.vocabulary_public_id_snapshot`; +4 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08630"></a>T-08630 / [191](../../../test/models/publishing/snapshot_public_id_capacity_contract_test.rb#L191) | "#{snapshot_class.name} rejects references above physical capacity while keeping presence rules"<br>Owner: `Publishing::SnapshotPublicIdCapacityContractTest` | `assert_not candidate.valid?`; `assert candidate.errors.of_kind?(attribute, :too_long)`; `assert_not candidate.save`; +5 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08631"></a>T-08631 / [244](../../../test/models/publishing/snapshot_public_id_capacity_contract_test.rb#L244) | "#{snapshot_class.name} independently enforces DB capacity and keeps immutable update refusal"<br>Owner: `Publishing::SnapshotPublicIdCapacityContractTest` | `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_instance_of PG::StringDataRightTruncation, error.cause`; `assert_equal original, stored.reload.attributes`; +6 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/taxonomy_constraints_test.rb`

[test/models/publishing/taxonomy_constraints_test.rb](../../../test/models/publishing/taxonomy_constraints_test.rb); SHA-256: `a704410270662ea4781d1c879afe3299bd84332101513831c5d36b11b063d577`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08632"></a>T-08632 / [14](../../../test/models/publishing/taxonomy_constraints_test.rb#L14) | "vocabulary key is unique within a family and independent across families"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::RecordNotUnique) do`; `assert_predicate other, :persisted?` | [Publishing::Docs::App::Vocabulary](../../../app/models/publishing/docs/app/vocabulary.rb#L6); [Publishing::Docs::Com::Vocabulary](../../../app/models/publishing/docs/com/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08633"></a>T-08633 / [29](../../../test/models/publishing/taxonomy_constraints_test.rb#L29) | "vocabulary rejects an unknown kind or key format"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::CheckViolation) do`; `assert_raises(ActiveRecord::CheckViolation) do` | [Publishing::News::App::Vocabulary](../../../app/models/publishing/news/app/vocabulary.rb#L6) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08634"></a>T-08634 / [42](../../../test/models/publishing/taxonomy_constraints_test.rb#L42) | "an archive timestamp and reason must be set together"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::CheckViolation) { @category.update_column(:archived_at, Time.current) }` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08635"></a>T-08635 / [46](../../../test/models/publishing/taxonomy_constraints_test.rb#L46) | "term slug is unique per vocabulary and locale"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::RecordNotUnique) { publishing_term(vocabulary: @category, locale: "ja", slug: "guide") }`; `assert_predicate publishing_term(vocabulary: @category, locale: "en", slug: "guide"), :persisted?` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08636"></a>T-08636 / [55](../../../test/models/publishing/taxonomy_constraints_test.rb#L55) | "a term's parent must share its vocabulary and locale"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::InvalidForeignKey, ActiveRecord::StatementInvalid) do`; `assert_raises(ActiveRecord::InvalidForeignKey) do` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08637"></a>T-08637 / [81](../../../test/models/publishing/taxonomy_constraints_test.rb#L81) | "a flat vocabulary's term cannot have a parent"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::CheckViolation) do` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08638"></a>T-08638 / [92](../../../test/models/publishing/taxonomy_constraints_test.rb#L92) | "root and depth must agree"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::CheckViolation) do`; `assert_raises(ActiveRecord::StatementInvalid) do` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08639"></a>T-08639 / [111](../../../test/models/publishing/taxonomy_constraints_test.rb#L111) | "a term's depth must equal its parent's depth plus one"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::StatementInvalid) do` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08640"></a>T-08640 / [122](../../../test/models/publishing/taxonomy_constraints_test.rb#L122) | "depth beyond the limit is rejected"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_equal Docs::App::TaxonomyTerm::MAX_DEPTH, parent.depth`; `assert_raises(ActiveRecord::CheckViolation) do` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08641"></a>T-08641 / [134](../../../test/models/publishing/taxonomy_constraints_test.rb#L134) | "postgresql rejects a cycle written behind the domain operation's back"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_database_rejects { root.update_columns(parent_id: child.id, depth: 1) }`; `assert_database_rejects { root.update_columns(parent_id: root.id, depth: 1) }` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08642"></a>T-08642 / [144](../../../test/models/publishing/taxonomy_constraints_test.rb#L144) | "an assignment cannot use a vocabulary from another audience or surface"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08643"></a>T-08643 / [160](../../../test/models/publishing/taxonomy_constraints_test.rb#L160) | "an assignment cannot mix kinds or use a term from another vocabulary"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::CheckViolation) do`; `assert_raises(ActiveRecord::InvalidForeignKey) do` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08644"></a>T-08644 / [183](../../../test/models/publishing/taxonomy_constraints_test.rb#L183) | "an assignment's locale must match its revision and its term"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::InvalidForeignKey) do` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08645"></a>T-08645 / [195](../../../test/models/publishing/taxonomy_constraints_test.rb#L195) | "single assignments are capped at one term per vocabulary"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::RecordNotUnique) do` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08646"></a>T-08646 / [213](../../../test/models/publishing/taxonomy_constraints_test.rb#L213) | "multiple assignments reject duplicate terms and duplicate positions"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::RecordNotUnique) { assign.call(ruby, 1) }`; `assert_raises(ActiveRecord::RecordNotUnique) { assign.call(rails, 0) }`; `assert_predicate assign.call(rails, 1), :persisted?` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08647"></a>T-08647 / [232](../../../test/models/publishing/taxonomy_constraints_test.rb#L232) | "a negative position is rejected"<br>Owner: `Publishing::TaxonomyConstraintsTest` | `assert_raises(ActiveRecord::CheckViolation) do` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/taxonomy_retirement_test.rb`

[test/models/publishing/taxonomy_retirement_test.rb](../../../test/models/publishing/taxonomy_retirement_test.rb); SHA-256: `010c6060354df3c4bb62fcdc99e1b70ffeeeb26074b589073a8b037d40aeeb30`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08648"></a>T-08648 / [15](../../../test/models/publishing/taxonomy_retirement_test.rb#L15) | "a term cannot be physically deleted even when nothing references it"<br>Owner: `Publishing::TaxonomyRetirementTest` | `assert_database_rejects { @connection.execute("DELETE FROM #{@term_table} WHERE id = #{@term.id}") }`; `assert_database_rejects { @term.destroy! }`; `assert_predicate @term.class.find_by(id: @term.id), :present?` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08649"></a>T-08649 / [21](../../../test/models/publishing/taxonomy_retirement_test.rb#L21) | "a vocabulary cannot be physically deleted even when it has no terms"<br>Owner: `Publishing::TaxonomyRetirementTest` | `assert_database_rejects { @connection.execute("DELETE FROM #{@vocab_table} WHERE id = #{empty.id}") }`; `assert_predicate @category.class.find_by(id: empty.id), :present?` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08650"></a>T-08650 / [28](../../../test/models/publishing/taxonomy_retirement_test.rb#L28) | "a vocabulary's structural identity is frozen"<br>Owner: `Publishing::TaxonomyRetirementTest` | `assert_database_rejects do`; `assert_equal TaxonomyKind::SINGLE_HIERARCHICAL, @category.reload.kind` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08651"></a>T-08651 / [39](../../../test/models/publishing/taxonomy_retirement_test.rb#L39) | "an empty vocabulary may still be relabelled"<br>Owner: `Publishing::TaxonomyRetirementTest` | `assert_equal "Corrected", draft.reload.internal_name` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08652"></a>T-08652 / [49](../../../test/models/publishing/taxonomy_retirement_test.rb#L49) | "archiving is reversible and does not release the slug for reuse"<br>Owner: `Publishing::TaxonomyRetirementTest` | `assert_raises(ActiveRecord::RecordNotUnique) do`; `assert_not @term.reload.archived?` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/taxonomy_tree_test.rb`

[test/models/publishing/taxonomy_tree_test.rb](../../../test/models/publishing/taxonomy_tree_test.rb); SHA-256: `5305832c295e76384530bc2610ed7dec81217bc4f6beea05ad1431073196b020`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08653"></a>T-08653 / [20](../../../test/models/publishing/taxonomy_tree_test.rb#L20) | "root_terms returns the vocabulary's parentless terms only"<br>Owner: `Publishing::TaxonomyTreeTest` | `assert_equal [@root, @sibling].map(&:id).sort, root_terms.map(&:id).sort` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08654"></a>T-08654 / [26](../../../test/models/publishing/taxonomy_tree_test.rb#L26) | "root_terms is scoped to its own vocabulary"<br>Owner: `Publishing::TaxonomyTreeTest` | `assert_not_includes @category.root_terms.map(&:vocabulary_id), other.id` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08655"></a>T-08655 / [33](../../../test/models/publishing/taxonomy_tree_test.rb#L33) | "descendants walks the whole subtree and excludes the term itself and its siblings"<br>Owner: `Publishing::TaxonomyTreeTest` | `assert_equal [@child, @grandchild].map(&:id).sort, descendants.map(&:id).sort`; `assert_not_includes descendants.map(&:id), @root.id`; `assert_not_includes descendants.map(&:id), @sibling.id` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08656"></a>T-08656 / [41](../../../test/models/publishing/taxonomy_tree_test.rb#L41) | "a leaf term has no descendants"<br>Owner: `Publishing::TaxonomyTreeTest` | `assert_empty @grandchild.descendants`; `assert_empty @sibling.descendants` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/taxonomy_uniqueness_exception_contract_test.rb`

[test/models/publishing/taxonomy_uniqueness_exception_contract_test.rb](../../../test/models/publishing/taxonomy_uniqueness_exception_contract_test.rb); SHA-256: `ec479759d71fe7d4e896f9e3d108211606efcb41b788ec0651df2cc256a50651`.

File-level implementation candidates (including setup/import context): [app/models/publishing/docs/app/vocabulary.rb:6](../../../app/models/publishing/docs/app/vocabulary.rb#L6); [app/models/publishing/docs/app/taxonomy_term.rb:6](../../../app/models/publishing/docs/app/taxonomy_term.rb#L6); [app/models/publishing/docs/com/vocabulary.rb:6](../../../app/models/publishing/docs/com/vocabulary.rb#L6); [app/models/publishing/docs/com/taxonomy_term.rb:6](../../../app/models/publishing/docs/com/taxonomy_term.rb#L6); [app/models/publishing/docs/org/vocabulary.rb:6](../../../app/models/publishing/docs/org/vocabulary.rb#L6).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08657"></a>T-08657 / [22](../../../test/models/publishing/taxonomy_uniqueness_exception_contract_test.rb#L22) | "#{term_class.name} preserves the slug exception with either one or two unique conflicts"<br>Owner: `TaxonomyUniquenessExceptionContractTest` | `assert_raises(ActiveRecord::RecordNotUnique) do`; `assert_equal "first-root", first.reload.slug` | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08658"></a>T-08658 / [43](../../../test/models/publishing/taxonomy_uniqueness_exception_contract_test.rb#L43) | "#{term_class.name} database treats NULL parents as the same sibling scope"<br>Owner: `TaxonomyUniquenessExceptionContractTest` | `assert_nil first.parent_id`; `assert_raises(ActiveRecord::RecordNotUnique) do`; `assert_instance_of PG::UniqueViolation, error.cause`; +4 further assertion lines | [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind.rb#L11); [Publishing::TaxonomyKind](../../../app/values/publishing/taxonomy_kind/multiple_ordered_flat.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/version_immutability_test.rb`

[test/models/publishing/version_immutability_test.rb](../../../test/models/publishing/version_immutability_test.rb); SHA-256: `c75e0347291159e477e79237895a6c20f925dda0eaf3ed837e455915618a94a9`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08659"></a>T-08659 / [20](../../../test/models/publishing/version_immutability_test.rb#L20) | "active record refuses to update or destroy a version"<br>Owner: `Publishing::VersionImmutabilityTest` | `assert_raises(ActiveRecord::ReadOnlyRecord) { @version.update!(title: "changed") }`; `assert_raises(ActiveRecord::ReadOnlyRecord) { @version.destroy! }` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08660"></a>T-08660 / [25](../../../test/models/publishing/version_immutability_test.rb#L25) | "postgresql refuses an update that bypasses active record"<br>Owner: `Publishing::VersionImmutabilityTest` | `assert_database_rejects { @version.update_column(:title, "changed") }`; `assert_database_rejects { Docs::App::EntryVersion.where(id: @version.id).update_all(title: "changed") }` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08661"></a>T-08661 / [30](../../../test/models/publishing/version_immutability_test.rb#L30) | "postgresql refuses a delete that bypasses active record"<br>Owner: `Publishing::VersionImmutabilityTest` | `assert_database_rejects { Docs::App::EntryVersion.where(id: @version.id).delete_all }`; `assert_database_rejects do` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08662"></a>T-08662 / [37](../../../test/models/publishing/version_immutability_test.rb#L37) | "active record refuses to update or destroy a version taxonomy snapshot"<br>Owner: `Publishing::VersionImmutabilityTest` | `assert_raises(ActiveRecord::ReadOnlyRecord) { single.update!(term_name_snapshot: "changed") }`; `assert_raises(ActiveRecord::ReadOnlyRecord) { single.destroy! }`; `assert_raises(ActiveRecord::ReadOnlyRecord) { multiple.update!(term_name_snapshot: "changed") }`; +1 further assertion lines | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08663"></a>T-08663 / [47](../../../test/models/publishing/version_immutability_test.rb#L47) | "postgresql refuses raw writes to version taxonomy snapshots"<br>Owner: `Publishing::VersionImmutabilityTest` | `assert_database_rejects do`; `assert_database_rejects do`; `assert_database_rejects do`; +1 further assertion lines | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08664"></a>T-08664 / [70](../../../test/models/publishing/version_immutability_test.rb#L70) | "draft assignments stay editable"<br>Owner: `Publishing::VersionImmutabilityTest` | `assert_equal 5, assignment.reload.position`; `assert_nothing_raised { assignment.destroy! }` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/version_sequence_contract_test.rb`

[test/models/publishing/version_sequence_contract_test.rb](../../../test/models/publishing/version_sequence_contract_test.rb); SHA-256: `bee9d3f779ea0e633c02a92fab4dd83b4f1566eb10740a65931cc97a73f0bfa5`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08665"></a>T-08665 / [23](../../../test/models/publishing/version_sequence_contract_test.rb#L23) | "#{version_class.name} saves positive sequences at both integer boundaries"<br>Owner: `Publishing::VersionSequenceContractTest` | `assert_equal sequence, version.reload.sequence` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08666"></a>T-08666 / [42](../../../test/models/publishing/version_sequence_contract_test.rb#L42) | "#{version_class.name} rejects missing noninteger and out-of-range sequences on creation"<br>Owner: `Publishing::VersionSequenceContractTest` | `assert_not version.valid?, "sequence #{sequence.inspect} must be rejected"`; `assert_not_empty version.errors[:sequence]`; `assert_not_empty version.errors.full_messages`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08667"></a>T-08667 / [64](../../../test/models/publishing/version_sequence_contract_test.rb#L64) | "#{version_class.name} preserves integer-string assignment and immutable-update refusal"<br>Owner: `Publishing::VersionSequenceContractTest` | `assert_equal 1, version.reload.sequence`; `assert_raises(ActiveRecord::ReadOnlyRecord) { version.save! }`; `assert_equal 1, version.reload.sequence` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08668"></a>T-08668 / [87](../../../test/models/publishing/version_sequence_contract_test.rb#L87) | "#{version_class.name} database rejects invalid inserts without model validation"<br>Owner: `Publishing::VersionSequenceContractTest` | `assert_raises(ActiveRecord::StatementInvalid) do`; `assert_instance_of cause_class, error.cause`; `assert_equal "sequence", error.cause.result.error_field(PG::Result::PG_DIAG_COLUMN_NAME)`; +2 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/version_snapshot_integrity_test.rb`

[test/models/publishing/version_snapshot_integrity_test.rb](../../../test/models/publishing/version_snapshot_integrity_test.rb); SHA-256: `9579f3292bac381a1ae67f19d2911617194f84ed2d2d885484430adbb997e279`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08669"></a>T-08669 / [19](../../../test/models/publishing/version_snapshot_integrity_test.rb#L19) | "forged snapshot values are overwritten with the live vocabulary and term"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_equal "leaf", forged.term_slug_snapshot`; `assert_equal "Leaf", forged.term_name_snapshot`; `assert_equal "category", forged.vocabulary_key_snapshot`; +2 further assertion lines | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08670"></a>T-08670 / [32](../../../test/models/publishing/version_snapshot_integrity_test.rb#L32) | "a direct insert claiming a different term name, slug, or path is corrected"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_equal "leaf", stored.term_slug_snapshot`; `assert_equal "Leaf", stored.term_name_snapshot`; `assert_equal "category", stored.vocabulary_key_snapshot`; +2 further assertion lines | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08671"></a>T-08671 / [64](../../../test/models/publishing/version_snapshot_integrity_test.rb#L64) | "a forged ordered position snapshot is replaced by the assigned position"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_equal stored.position, stored.position_snapshot` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08672"></a>T-08672 / [71](../../../test/models/publishing/version_snapshot_integrity_test.rb#L71) | "an extra snapshot the revision never assigned is rejected at commit"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_database_rejects do`; `assert_equal 1, Docs::App::VersionMultipleTaxonomyAssignment.where(entry_version_id: version.id).count` | [PublishingRecord](../../../app/models/publishing_record.rb#L6); [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08673"></a>T-08673 / [94](../../../test/models/publishing/version_snapshot_integrity_test.rb#L94) | "a snapshot at a position the revision never used is rejected at commit"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_database_rejects do`; `assert_equal [0], positions` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08674"></a>T-08674 / [120](../../../test/models/publishing/version_snapshot_integrity_test.rb#L120) | "the breadcrumb path rejects extra keys and non-array shapes"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_not valid_path?("{}")`; `assert_not valid_path?(%q({"a": 1}))`; `assert_not valid_path?(%q([{"public_id": "x", "slug": "y"}]))`; +3 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08675"></a>T-08675 / [129](../../../test/models/publishing/version_snapshot_integrity_test.rb#L129) | "revision and version bodies must be JSON objects"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_database_rejects do` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08676"></a>T-08676 / [143](../../../test/models/publishing/version_snapshot_integrity_test.rb#L143) | "as_public_json renders the frozen term identity and no database identifiers"<br>Owner: `Publishing::VersionSnapshotIntegrityTest` | `assert_equal(`; `assert_equal(` | [Docs::App](../../../app/controllers/docs/app/api/v0/entries_controller.rb#L5); [Docs::App](../../../app/controllers/docs/app/api/v0/healths_controller.rb#L5) | S: static inventory; individual semantic review open | none detected (not a quality approval) |

## `test/models/publishing/vocabulary_key_uniqueness_test.rb`

[test/models/publishing/vocabulary_key_uniqueness_test.rb](../../../test/models/publishing/vocabulary_key_uniqueness_test.rb); SHA-256: `371b09e9bafdbce4dc4c6b7b00a338d388dc7783cfd267f224588711c828f3c0`.

File-level implementation candidates (including setup/import context): [app/errors/publishing/archived_taxonomy_assignment_error.rb:4](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [app/forms/publishing/archive_entry_form.rb:4](../../../app/forms/publishing/archive_entry_form.rb#L4); [app/forms/publishing/create_entry_form.rb:4](../../../app/forms/publishing/create_entry_form.rb#L4); [app/forms/publishing/end_publication_form.rb:4](../../../app/forms/publishing/end_publication_form.rb#L4); [app/forms/publishing/entry_content_form.rb:4](../../../app/forms/publishing/entry_content_form.rb#L4).

| ID / source | Declared protection | Oracle excerpts | Production candidates / request seam | Review disposition | Signals / duplicate |
| --- | --- | --- | --- | --- | --- |
| <a id="t-08677"></a>T-08677 / [22](../../../test/models/publishing/vocabulary_key_uniqueness_test.rb#L22) | "vocabulary keys remain independent across all twelve physical families"<br>Owner: `Publishing::VocabularyKeyUniquenessTest` | `assert_equal "consistency_key", vocabulary.reload.key` | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08678"></a>T-08678 / [34](../../../test/models/publishing/vocabulary_key_uniqueness_test.rb#L34) | "#{model.name} preserves key format sentinels and string casting"<br>Owner: `Publishing::VocabularyKeyUniquenessTest` | `assert_not vocabulary.valid?`; `assert vocabulary.errors.of_kind?(:key, :invalid)`; `assert_equal((key == false) ? "f" : key, vocabulary.reload.key)`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08679"></a>T-08679 / [58](../../../test/models/publishing/vocabulary_key_uniqueness_test.rb#L58) | "#{model.name} preserves database duplicates and immutable keys"<br>Owner: `Publishing::VocabularyKeyUniquenessTest` | `assert_raises(ActiveRecord::RecordNotUnique) do`; `assert_instance_of PG::UniqueViolation, error.cause`; `assert_predicate vocabulary, :valid?`; +4 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08680"></a>T-08680 / [87](../../../test/models/publishing/vocabulary_key_uniqueness_test.rb#L87) | "#{model.name} refuses ordinary duplicate keys independent of kind and archival"<br>Owner: `Publishing::VocabularyKeyUniquenessTest` | `assert_not duplicate.valid?`; `assert duplicate.errors.of_kind?(:key, :taken)`; `I18n.with_locale(locale) { assert_not_empty duplicate.errors.full_messages }`; +3 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
| <a id="t-08681"></a>T-08681 / [112](../../../test/models/publishing/vocabulary_key_uniqueness_test.rb#L112) | "#{model.name} adds one key probe for creation and none for an unchanged existing key"<br>Owner: `Publishing::VocabularyKeyUniquenessTest` | `assert_predicate candidate, :valid?`; `assert_predicate existing, :valid?`; `assert_equal 1, queries.size`; +1 further assertion lines | [Publishing](../../../app/errors/publishing/archived_taxonomy_assignment_error.rb#L4); [Publishing](../../../app/forms/publishing/archive_entry_form.rb#L4) | S: static inventory; individual semantic review open | none detected (not a quality approval) |
