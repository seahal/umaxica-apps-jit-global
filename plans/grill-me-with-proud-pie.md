# Publishing Taxonomy Architecture Investigation (Grill-Me Report)

Inspected commit: `be230ba90` on branch `develop`. Working tree **not clean**: modified `Gemfile`,
`Gemfile.lock`, `config/initializers/mission_control_jobs.rb`,
`test/controllers/concerns/sign_out_notice_test.rb`, plus untracked coverage notes/tests — all
unrelated to CMS/taxonomy. Read-only investigation; no files outside this report were touched.

---

## 1. Executive finding

1. The repository has already completed the publishing-DB centralization (Phases 0–8,
   `plans/publishing-db-valiant-moore.md`, memo
   `memos/2026-07-16-publishing-db-migration-complete.md`): a live 8-table `publishing` schema
   (`Edition, Entry, EntrySlug, EntryRevision, EntryVersion, Publication, MediaFile, MediaUsage`)
   with models, resolver, query, serializer, 12 read-API controllers, and tests.
2. Taxonomy is **not implemented at all** in the live system.
   `db/migration_support/publishing_schema.rb:4-6` excludes it deliberately;
   `test/models/publishing/schema_and_models_test.rb:22-26` asserts
   `publishing_categories`/`publishing_tags` do NOT exist.
3. The only taxonomy that ever existed is legacy DDL in `db/migration_support/cms_schema.rb`
   (Category adjacency tree + flat ordered Tags, snapshot-carrying assignment tables attached to
   revisions and versions) — created 2026-07-11, **dropped 2026-07-16 in dev/test**
   (`db/*_zenith_migrate/2026071620060*_drop_publishing_migration_source_tables.rb`), never had Ruby
   models, and held 0 rows at drop time. Production drop is still pending approval.
4. So "taxonomy" today is Category/Tag-specific only as _historical DDL_; there is no runtime
   abstraction to preserve. The interface proposal is feasible — we are designing on a green field
   with one strong prior (DB-enforced constraints, snapshot-into-version).
5. Most serious semantic risk: labeling Revision, Version, Language, Country, and Author "taxonomy"
   collapses lifecycle entities, edition dimensions, and provenance into a vocabulary abstraction,
   inviting a generic assignment table (EAV) that would discard the repo's strongest asset — its
   PostgreSQL constraint discipline (composite locale FKs, single-category unique index, GiST
   publication windows).
6. Most important unanswered decision: whether Taxonomy is a **persistence model** (generic
   terms/assignments) or a **read-side protocol** (facets over first-class relationships).
   Everything else follows from this.

## 2. Current-state architecture

### Current storage (three generations)

```text
Gen 1 (2026-06-13, DROPPED): docs/news/help_content_entries  — lean tables in {app,com,org}_zenith. No info table. No models.
Gen 2 (2026-07-11, DROPPED): CmsSchema families — {surface}_{family}_{posts,post_slugs,post_revisions,
        post_versions,post_publications,media_files,media_usages,categories,tags,
        post_revision_categories,post_revision_tags,post_version_categories,post_version_tags}
        × 3 surfaces × 4 families. No models. 0 rows at audit. Dropped in dev/test; PRODUCTION DROP PENDING.
Gen 3 (2026-07-16, LIVE):    publishing DB — publishing_{editions,entries,entry_slugs,entry_revisions,
        entry_versions,publications,media_files,media_usages}. No taxonomy tables.
```

All `db/*_structure.sql` dumps are empty of tables (0 CREATE TABLE) — schema knowledge comes from
migration code only; applied production state is unverified.

### Current models

```text
PublishingRecord (app/models/publishing_record.rb:9, connects_to publishing / publishing_replica)
 └─ Publishing::Edition   UNIQUE(audience,surface,locale); region_code nullable, unconstrained
 └─ Publishing::Entry     current_revision_id (unique FK), archived_at, lock_version
 └─ Publishing::EntrySlug states reserved/canonical/redirect; partial unique canonical per entry
 └─ Publishing::EntryRevision  sequence per entry; body jsonb; schema_version; content_digest;
                               restored_from_{revision,version}_id (num_nonnulls<=1); provenance
 └─ Publishing::EntryVersion   immutable (before_update/destroy raise ReadOnlyRecord); 1:1 revision
 └─ Publishing::Publication    effective_from/until; cancelled_at XOR terminated_at; GiST exclusion
                               on (entry_id, tstzrange) WHERE cancelled_at IS NULL
 └─ Publishing::MediaFile / MediaUsage  usage XOR-owned by revision OR version
```

### Current read path

```text
Host (e.g. docs.jp.umaxica.app) → config/routes/{info,docs,news,help}.rb host-constrained namespaces
 → {surface}/{audience}/api/v0/EntriesController (12×, AUTHENTICATION_MODE=:bare)
 → PublishingContentRendering concern (app/controllers/concerns/publishing_content_rendering.rb)
   locale from params/region-map (jp→ja, us→en)/I18n.locale
 → PublishingEditionResolver → PublishingPublishedEntriesQuery (active publication join, canonical slug)
 → PublishingEntrySerializer (legacy-compatible JSON: namespace=surface, surface=audience)
Nested revisions controllers exist for docs/news/help (not info) but are stubs returning []/{}.
```

### Current taxonomy path

```text
NONE at runtime. Legacy DDL only (db/migration_support/cms_schema.rb):
  categories: adjacency list (parent_id, depth 0..8 CHECK, position), locale-scoped,
              composite FK (parent_id,locale)→(id,locale), slug regex CHECK, normalized_name,
              archived_at+reason paired CHECK
  tags:       flat, same locale/slug/archive treatment
  assignments: attach to post_revisions AND post_versions (never posts/publications);
              category 0..1 via UNIQUE(owner_id); tag 0..N ordered via UNIQUE(owner_id,position)
              + UNIQUE(owner_id,tag_id); every row snapshots taxonomy_public_id/slug/name/path(jsonb)
```

## 3. Evidence inventory

| Area                             | Current fact                                                                                                | Evidence                                                                                                    | Confidence                         | Conflict / uncertainty                                                   |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------ |
| Content authority                | Central publishing DB live, 8 tables, no taxonomy                                                           | `db/migration_support/publishing_schema.rb`; `adr/publishing-db-content-authority.md` (Accepted 2026-07-16) | High                               | Production legacy tables not yet dropped                                 |
| Taxonomy runtime                 | No Category/Tag/Taxonomy Ruby classes anywhere                                                              | grep of `app/models/**`                                                                                     | High                               | —                                                                        |
| Legacy taxonomy DDL              | Full DB-enforced Category/Tag design, snapshot assignments on revisions+versions                            | `cms_schema.rb:201-266, 286-292, 309-324`                                                                   | High                               | Tables dropped in dev/test; file retained in tree                        |
| Taxonomy exclusion is deliberate | Schema header + negative test                                                                               | `publishing_schema.rb:4-6`; `test/models/publishing/schema_and_models_test.rb:22-26`; ADR §6 lines 83-88    | High                               | —                                                                        |
| Edition dimensions               | audience×surface×locale unique; region_code nullable, no CHECK/FK, not in unique key                        | `publishing_schema.rb:30-45`; `app/models/publishing/edition.rb:9-18`                                       | High                               | region_code semantics undefined in code                                  |
| Region constants                 | No REGION_CODE / GLOBAL_MODE constants exist                                                                | repo-wide grep                                                                                              | High                               | Region is hostname convention (`jp` label) + ADR prose only              |
| Locale discipline                | locale NOT NULL everywhere; composite (id,locale) FKs enforce coherence                                     | `publishing_schema.rb:61,90-91,121,156`; `cms_schema.rb` locale FKs                                         | High                               | Language never stored separately from locale                             |
| Authorship                       | Only `created_by_operator_public_id` char(21), denormalized, no FK, on revisions/versions/publications      | `publishing_schema.rb:273` (provenance helper)                                                              | High                               | No editor/reviewer/approver/publisher roles; no displayed-author concept |
| Revision/Version/Publication     | Revision=edit history, Version=immutable snapshot, Publication=timed window w/ GiST exclusion               | `publishing_schema.rb:94-205`; `entry_version.rb:16-20`; `publication.rb:12-18`                             | High                               | Revisions API controllers are stubs                                      |
| Seeds                            | CMS seed path is dead: `db/seeds.rb:51-54` requires nonexistent `db/seeds/cms_samples.rb`                   | `db/seeds.rb`; `db/seeds/` absent                                                                           | High                               | Would raise LoadError if SEED_CMS_SAMPLES=1                              |
| Structure dumps                  | All relevant dumps contain 0 tables                                                                         | `db/*_structure.sql`                                                                                        | High                               | Applied DB state (esp. production) unknowable from repo                  |
| Migration status                 | 687 up / 0 down reported; Phases 0–8 complete; prod drop pending                                            | `memos/2026-07-16-publishing-db-migration-complete.md` lines 27-31                                          | Medium (memo, not verifiable here) | Dev/test vs production schema divergence until prod run                  |
| CI/config drift                  | Orphan `POSTGRESQL_PRINCIPAL_PUB/SUB` env vars; database.yml refs missing `db/{storages,searches}_migrate/` | `.github/workflows/integration.yml:229-230,359-360`; `compose.yaml:44-45`; drift memo                       | High                               | Record-only, deferred                                                    |
| cms_schema.rb tracked status     | File exists and is tracked (last touched `fc9353323`), contradicting cleanup-memo claim it was deleted      | `git log -- db/migration_support/cms_schema.rb`; `ls`                                                       | High                               | Memo/plan `immutable-wibbling-jellyfish.md` stale on this point          |

## 4. Taxonomy candidate matrix

| Candidate | Likely semantic type                                                                                                                             | Source of truth                                                                                       | Assignable?                          | Derived?                          | Cardinality                                      | Hierarchy                        | Snapshot req.                                        | Generic assignment table?                                   | Primary risk                                                                                                                    |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------- | ------------------------------------ | --------------------------------- | ------------------------------------------------ | -------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Category  | Assignable controlled vocabulary                                                                                                                 | Vocabulary master (per edition/locale scope TBD)                                                      | Yes (manual)                         | No                                | 0..1 per revision/version (legacy DB-enforced)   | Yes (legacy: adjacency, depth≤8) | Yes — legacy snapshotted slug/name/path into version | Plausible                                                   | Losing the UNIQUE(owner_id) single-category DB guarantee in a generic table                                                     |
| Tag       | Assignable controlled vocabulary                                                                                                                 | Vocabulary master                                                                                     | Yes (manual)                         | No                                | 0..N, ordered (legacy UNIQUE(owner_id,position)) | No                               | Yes (legacy)                                         | Plausible                                                   | Ordering + dedup constraints must survive genericization                                                                        |
| Author    | Provenance / first-class domain relationship, NOT vocabulary                                                                                     | Operator records (`created_by_operator_public_id`) vs. an as-yet-nonexistent displayed-author concept | Displayed-author: maybe; creator: no | Creator: derived from write       | 1 today (creator); displayed could be 0..N       | No                               | Provenance already snapshotted per row               | **No** — duplicates operator relationship, weakens FK story | Conflating "row creator" with "displayed article author"; repo has only the former                                              |
| Revision  | Lifecycle entity                                                                                                                                 | `publishing_entry_revisions`                                                                          | **No**                               | Identity                          | —                                                | No                               | It IS the snapshot mechanism                         | **Never**                                                   | Treating identity as classification; assignment row would duplicate `entry_version.entry_revision_id`                           |
| Version   | Lifecycle entity / immutable identity                                                                                                            | `publishing_entry_versions` (ReadOnlyRecord)                                                          | **No**                               | Identity                          | —                                                | No                               | It IS the snapshot                                   | **Never**                                                   | Same; also breaks immutability if assignments mutate post-promotion                                                             |
| Language  | Derived facet of Locale                                                                                                                          | `locale` column (NOT NULL everywhere, composite FKs)                                                  | No                                   | Yes (prefix of locale)            | 1 per entry                                      | No                               | Inherent in row                                      | **No** — duplicates locale, could contradict it             | Storing `language` beside `locale` creates a bypassable consistency invariant with no FK tying them                             |
| Country   | Two distinct things: content-applicability country (possible controlled facet) vs deployment region (`region_code` on Edition / `jp` host label) | Nothing today: region_code nullable+unconstrained; no country model                                   | Applicability: maybe; region: no     | Region: derived from host/edition | Applicability: 0..N; region: 0..1 per edition    | No                               | Depends                                              | Applicability only, maybe                                   | Conflating placement (which edition serves it) with subject matter ("docs about US law") — repo currently distinguishes neither |

## 5. Dependency inversion assessment

**Verdict: the proposal as drawn is only genuine DIP for Category/Tag-like assignable vocabularies.
For Revision/Version/Language it is abstraction inversion — wrapping concrete lifecycle/dimension
facts in an interface they don't need.**

- **High-level policy**: "published content can be filtered/navigated by named facets, and the facet
  set is open." That is a _read-side_ policy. The authoring-side policy ("a revision carries
  classifications that freeze at version promotion") applies only to assignable vocabularies.
- **Interface owner**: the publishing domain — `Publishing::Taxonomy` (or `Publishing::Facet`)
  namespace, per the ADR's model-namespace discipline (`adr/publishing-db-content-authority.md`
  lines 109-116, which also **forbids `constantize`/`const_get` model resolution** — this repo has
  already banned the hidden-service-locator route).
- **Provider responsibilities**: each facet provider exposes a fixed contract (e.g. `key`,
  `values_for(version)`, `filter(scope, value)`); assignable providers additionally own
  persistence + snapshot behavior.
- **Registry responsibilities**: an explicit, eagerly-frozen registry (constant array or
  initializer-registered), not convention-scanned. Rails autoload/reload caveat: registering class
  _objects_ in an initializer breaks on reload in development; register by name-resolved-at-boot via
  `Rails.application.config.to_prepare`, or hold provider _instances_ that reference models lazily.
  Repo precedent for explicit enumeration over dynamism: routes-declarative-no-lambda decision,
  ADR's constantize ban.
- **Forbidden dependencies**: `Publishing::Entry*` must not reference concrete facet classes;
  providers must not reach into controller/serializer internals; no central `case taxonomy_key`.
- **Runtime contract strategy**: `ActiveSupport::Concern` alone is NOT an interface — it shares
  implementation, not obligation. Ruby has no compile-time contracts; enforce with (a) a small
  required-method list checked at registration time (fail fast at boot), and (b) capability
  declarations rather than `NotImplementedError` stubs — a provider that can't do hierarchy should
  not expose `children`, and callers should branch on declared capability, not rescue.
- **Test contract strategy**: a shared Minitest module (contract test) included into each provider's
  test — the same pattern as the legacy contract tests deleted in Phase 7. This is the actual OCP
  guarantee in Ruby.
- **EAV guard**: extensibility must not mean "any string key in one assignments table." If generic
  persistence is used at all, term types are a CHECK-constrained enum extended by migration — adding
  a taxonomy type is a migration + provider + contract test, not a runtime insert.

## 6. Persistence option comparison

| Criterion                                | A: dedicated tables                                                               | B: generic terms/assignments                                                                 | C: hybrid                                                | D: provider-only (no new persistence)                  |
| ---------------------------------------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------ |
| DB integrity (FKs, uniques, cardinality) | Best — per-table UNIQUE(owner_id), typed FKs (legacy pattern)                     | Worst — cardinality per type needs partial indexes per type (defeats genericity) or triggers | Good — full constraints where they matter                | N/A — reuses existing constraints                      |
| Query complexity                         | Simple joins                                                                      | Polymorphic-ish filters, term_type discriminators everywhere                                 | Simple for vocab; derived facets are projections         | Simplest                                               |
| Snapshots / immutability                 | Explicit snapshot columns (legacy `snapshot(t)` pattern proven)                   | Snapshot columns generic but path_snapshot only means anything for hierarchical types        | Same as A for vocab                                      | Nothing to snapshot                                    |
| Localization                             | Per-table locale + composite FK (proven)                                          | Locale coherence FK still possible but uniform for all types                                 | Same as A                                                | Inherits locale discipline                             |
| Extension cost                           | New table pair + migration per type                                               | New enum value (+ per-type partial constraints anyway)                                       | Migration for new vocab; code-only for new derived facet | Code-only                                              |
| Failure modes                            | Compile/migration-time                                                            | Runtime (stringly term_type)                                                                 | Split                                                    | Compile-time                                           |
| Rails/PG ergonomics                      | High/High                                                                         | Medium/Low                                                                                   | High/High                                                | High/High                                              |
| Fit to repo evidence                     | Matches every prior (constraint discipline, no-constantize, explicit enumeration) | Contradicts repo's no-silent-fallback / constraint culture                                   | Matches; smallest schema honest to actual needs          | Matches today's needs exactly (zero vocab data exists) |

**Provisional ranking: C > D > A > B.** B is effectively disqualified by repository culture
(DB-enforced invariants, EAV prohibition in this task, no-stringly-typed). D is the honest minimum
_today_ (there is no taxonomy data anywhere; the read API doesn't filter). C becomes right the
moment authoring UI needs Category/Tag. A is C without the discipline of asking whether a facet
needs a table. Not final — depends on answers in §8.

## 7. Contradictions and obsolete decisions

**Must resolve before design**

1. Production zenith DBs still contain (per plan) the legacy CMS+taxonomy tables while dev/test
   dropped them; ADR §6 explicitly holds the legacy taxonomy DROP until a taxonomy migration plan
   exists. The new design must state what happens to those (empty) production tables. Evidence: drop
   migrations `20260716200600-2`; memo lines 27-31.
2. `region_code` on `publishing_editions` is nullable, unconstrained, and outside the unique key
   (`publishing_schema.rb:37,43`) — its meaning (deployment region? applicability? both?) is
   undefined and collides with the Country candidate. Must be pinned before Country/placement
   design.
3. Revisions API controllers are stubs (`[]`/`{}`) for docs/news/help but absent for info, while
   `docs/architecture/docs-help-news-content-boundary.md:92-98` forbids revision/version routes on
   read surfaces. Decide whether revision metadata is ever public before deciding if
   Revision/Version are facets.

**Can resolve during migration** 4. Orphan `POSTGRESQL_PRINCIPAL_PUB/SUB` env vars in
`integration.yml:229-230,359-360` and `compose.yaml:44-45`. 5. Dead seed hook: `db/seeds.rb:51-54`
requires nonexistent `db/seeds/cms_samples.rb`. 6. `database.yml` references missing
`db/storages_migrate/` and `db/searches_migrate/` (acknowledged record-only in drift memo). 7.
Cleanup memo/plan claims `cms_schema.rb` was deleted as untracked; it is present and tracked at
HEAD.

**Historical only** 8. Superseded ADRs (`read-only-content-surfaces-in-rails.md`,
`regional-docs-news-content-model.md`, `regional-help-surface-direction.md`) and
`plans/backlog/post-publication-implementation-plan.md:106` ("single category and many tags") — all
banner-marked.

## 8. Questions for me (asked one at a time in conversation)

Q1 Taxonomy meaning: persistence model vs read-side facet protocol (determines Option A–D). Q2
Revision/Version: confirm they are excluded from taxonomy and remain lifecycle entities; are they
ever public? Q3 Author: is a _displayed_ author concept required, or is operator provenance
sufficient for now? Q4 Language vs Locale: may `language` ever be stored independently of `locale`?
(Evidence says no independent storage exists.) Q5 Country vs Region: define `region_code` semantics
and whether content-applicability country is in scope. Q6 Snapshot rule: do vocab assignments
snapshot into Version at promotion (legacy pattern) — copied rows vs frozen columns? Q7 Extension
governance: is "add a taxonomy type" a migration+ADR event or a runtime/authoring event? (Each asked
with options, evidence, consequences, recommendation — see conversation.)

## 8b. Decisions recorded (interrogation outcome, 2026-07-19)

1. **Taxonomy = Hybrid**: persisted, DB-constrained storage only for assignable vocabularies;
   everything else is derived facets behind a shared read-side protocol. Two provider contracts
   (assignable vs derived) — the asymmetry is explicit, not papered over.
2. **Revision/Version**: lifecycle entities only, never taxonomy, never public. Delete the 9 stub
   `RevisionsController`s and their nested `resources :revisions` routes in
   `config/routes/{docs,news,help}.rb`. Restore-from-version must reconstitute draft assignments
   from version snapshots.
3. **Author**: operator provenance only; not a facet; no displayed-author entity until a byline
   requirement exists.
4. **Language**: never stored; derived from `locale`. Translation-group linkage noted as unmodeled,
   deferred, and not taxonomy.
5. **Country/Region**: `region_code` becomes a constrained Edition dimension (CHECK list;
   unique-key/NULL-vs-sentinel treatment to be settled in ADR; resolver gains region input from
   host). Content-applicability country deferred.
6. **Snapshots**: legacy dual-row pattern — draft assignments on revisions copied to version
   assignment rows at promotion, with slug/name/path snapshot columns + restrictive live FKs.
   Archive is the only term-retirement path; ADR must state snapshots are authoritative for history,
   masters for the live tree.
7. **Extension governance**: structural **kinds** fixed in schema/code (initially:
   single-valued-hierarchical, multi-valued-ordered-flat); **vocabularies** are runtime rows
   (`publishing_vocabularies` declaring kind); terms carry `vocabulary_id`; cardinality DB-enforced
   via `UNIQUE(owner_id, vocabulary_id)` on the single-valued assignment table. Category/Tag become
   the first two vocabulary rows. New kind = migration + provider + contract test; new vocabulary =
   staff action.

Consequence for §6: the chosen design is Hybrid refined into "fixed kinds, runtime vocabularies" —
between C and B, keeping C's constraint integrity while granting B's authoring-side extensibility
for vocabularies only.

## 9. Deferred migration implications

- **Option C (hybrid)**: adds `publishing_categories`, `publishing_tags`, and revision/version
  assignment tables to the publishing DB via a new `PublishingSchema`-style module; legacy zenith
  taxonomy tables (0 rows) can then be dropped in production together with the pending prod drop —
  no data migration needed. Derived facets (language, region) require no migration.
- **Option D (provider-only)**: zero schema change; the pending production drop can proceed
  immediately; taxonomy ADR becomes a code-and-contract document only.
- **Option A**: same as C plus additional table pairs (authors, entry_languages, entry_countries) —
  the language/country tables would duplicate locale/edition data and complicate the composite-FK
  locale discipline; would enlarge the prod migration for no data.
- **Option B**: introduces a term_type-discriminated schema that cannot express per-type cardinality
  without per-type partial indexes; would force reworking the snapshot columns and weaken the
  constraint story the publishing migration just established. Highest migration cost, lowest
  integrity.
- In all options, ADR §6's hold on dropping legacy taxonomy tables is satisfiable now (audit showed
  0 rows), so the taxonomy ADR should explicitly release that hold.
