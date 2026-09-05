# typed: false
# frozen_string_literal: true

# Read-only query for currently published entries within an edition, ordered
# newest-published-first.
#
# Taxonomy filters match the published version's snapshots, never a draft
# revision's assignments, so an entry is only findable by what it actually
# published. An unknown or archived filter term yields no entries rather than
# quietly falling back to the unfiltered list.
class PublishingPublishedEntriesQuery
  def self.call(...)
    new(...).call
  end

  # adr/api-collection-contract.md: every collection endpoint is bounded, a client that omits
  # `limit` still gets a bounded response, and a `limit` above the maximum is clamped rather than
  # rejected so a tuning mistake cannot become an error.
  DEFAULT_LIMIT = 20
  MIN_LIMIT = 1
  MAX_LIMIT = 100

  # `has_more` is authoritative; `next_cursor` is nil whenever it is false.
  Page = Data.define(:entries, :next_cursor, :has_more)

  def self.clamp_limit(value)
    value.clamp(MIN_LIMIT, MAX_LIMIT)
  end

  def initialize(edition:, category: nil, tag: nil)
    @edition = edition
    @category = category.presence
    @tag = tag.presence
  end

  def call
    return Publishing::Entry.none unless edition

    scope = published_scope
    # `category` and `tag` are the deliberately narrow public filter allowlist,
    # but the query shape comes from each vocabulary's structural kind, not from
    # its name, so a future vocabulary of either kind needs no new branch here.
    scope = filter_by(scope, key: "category", slug: category) if category
    scope = filter_by(scope, key: "tag", slug: tag) if tag
    scope
      .preload(
        :canonical_slug,
        active_publication: { entry_version: %i(single_taxonomy_assignments multiple_taxonomy_assignments) },
      )
      .strict_loading
      .order(ORDER)
  end

  # One page of the same ordered set, plus the cursor that continues it.
  #
  # Reads one row beyond the page to decide `has_more` rather than issuing a second COUNT: the extra
  # row is discarded, and the count would be both an additional query and a different snapshot of a
  # set that other writers may have changed.
  def page(limit: DEFAULT_LIMIT, cursor: nil)
    limit = self.class.clamp_limit(limit)
    scope = call
    scope = scope.where(AFTER_CURSOR, cursor.effective_from, cursor.entry_public_id) if cursor

    rows = scope.limit(limit + 1).to_a
    has_more = rows.length > limit
    entries = rows.first(limit)

    Page.new(
      entries:,
      next_cursor: has_more ? PublishingEntriesCursor.encode(entries.last) : nil,
      has_more:,
    )
  end

  # Resolves a single published entry by its opaque `public_id`, scoped to this
  # edition. `edition.entries` keeps the lookup inside the request's
  # audience/surface/locale cell -- a `public_id` belonging to another edition
  # returns nil, never another cell's row. Drafts, archived entries, and entries
  # with no active publication return nil so a known id cannot surface unpublished
  # content. The database primary key and the presentation slug are different
  # columns, so neither matches here.
  def find_published(public_id:)
    return unless edition

    entry =
      edition.entries
        .includes(
          :canonical_slug,
          active_publication: { entry_version: %i(single_taxonomy_assignments multiple_taxonomy_assignments) },
        )
        .find_by(public_id:)
    return unless entry
    return if entry.archived?
    return unless entry.active_publication

    entry
  end

  private

  # Newest published first. The tiebreaker is `public_id` rather than the primary key so that the
  # cursor, which has to encode the same sort key, carries no internal identifier
  # (docs/reference/api-design-standards.md). Ordering within a single instant is otherwise
  # unspecified, so the change of tiebreaker alters no promised behaviour.
  ORDER = Arel.sql("publishing_publications.effective_from DESC, publishing_entries.public_id DESC")

  # Keyset predicate, written as a row comparison so it matches ORDER exactly. A predicate that did
  # not mirror the ordering would skip or repeat rows at every page boundary.
  AFTER_CURSOR = Arel.sql(
    "(publishing_publications.effective_from, publishing_entries.public_id) < (?, ?)",
  )

  attr_reader :edition, :category, :tag

  # The publication-window exclusion constraint guarantees at most one active
  # publication per entry, so this join cannot duplicate rows and needs no
  # distinct. Archived entries stay unpublished even while a publication window
  # is still open.
  def published_scope
    edition.entries
      .where(archived_at: nil)
      .joins(:publications)
      .merge(Publishing::Publication.active)
  end

  def filter_by(scope, key:, slug:)
    vocabulary = filterable_vocabularies[key]
    # A filter naming a vocabulary this surface does not have matches nothing,
    # rather than being ignored.
    return scope.none unless vocabulary

    kind = vocabulary.structural_kind
    association = kind.ordered? ? :multiple_taxonomy_assignments : :single_taxonomy_assignments

    scope.where(
      Publishing::EntryVersion
        .where("publishing_entry_versions.id = publishing_publications.entry_version_id")
        .joins(association)
        .merge(matching_snapshots(kind.version_assignment_class, key:, slug:))
        .arel.exists,
    )
  end

  def filterable_vocabularies
    @filterable_vocabularies ||=
      Publishing::Vocabulary
        .available
        .for_scope(audience: edition.audience, surface: edition.surface)
        .index_by(&:key)
  end

  # Filters match the same frozen snapshots the response renders. A URL built
  # from published JSON therefore keeps working after the live term is renamed,
  # moved, or archived, and a term's new name never retroactively matches
  # content published under its old one. Matching is exact: a parent category
  # does not select its descendants.
  def matching_snapshots(assignment_class, key:, slug:)
    assignment_class.where(vocabulary_key_snapshot: key, term_slug_snapshot: slug, locale_snapshot: edition.locale)
  end
end
