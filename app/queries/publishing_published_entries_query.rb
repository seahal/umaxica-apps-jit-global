# typed: false
# frozen_string_literal: true

class PublishingPublishedEntriesQuery
  PAGE_SIZE = 20

  def self.call(...)
    new(...).call
  end

  def initialize(entry_class:, locale:, category: nil, tag: nil)
    @entry_class = entry_class
    @locale = locale
    @category = category.presence
    @tag = tag.presence
  end

  def call
    return entry_class.none if entry_class.nil? || locale.blank?

    scope = published_scope
    scope = filter_by(scope, key: "category", slug: category) if category
    scope = filter_by(scope, key: "tag", slug: tag) if tag
    publication_class = entry_class.reflect_on_association(:publications).klass
    scope
      .preload(
        :canonical_slug,
        active_publication: { entry_version: %i(single_taxonomy_assignments multiple_taxonomy_assignments) },
      )
      .strict_loading
      .order(publication_class.arel_table[:effective_from].desc, entry_class.arel_table[:public_id].desc)
  end

  def find_published(public_id:)
    return if entry_class.nil? || locale.blank?

    entry =
      entry_class
        .where(locale:)
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

  attr_reader :entry_class, :locale, :category, :tag

  def published_scope
    publication_class = entry_class.reflect_on_association(:publications).klass
    entry_class
      .where(locale:, archived_at: nil)
      .joins(:publications)
      .merge(publication_class.active)
  end

  def filter_by(scope, key:, slug:)
    vocabulary = filterable_vocabularies[key]
    return scope.none unless vocabulary

    kind = vocabulary.structural_kind
    version_class = entry_class.reflect_on_association(:versions).klass
    publication_class = entry_class.reflect_on_association(:publications).klass
    association = kind.ordered? ? :multiple_taxonomy_assignments : :single_taxonomy_assignments
    assignment_class = version_class.reflect_on_association(association).klass

    scope.where(
      version_class
        .where(version_class.arel_table[:id].eq(publication_class.arel_table[:entry_version_id]))
        .joins(association)
        .merge(matching_snapshots(assignment_class, key:, slug:))
        .arel.exists,
    )
  end

  def filterable_vocabularies
    @filterable_vocabularies ||=
      vocabulary_class.available.order(:key).index_by(&:key)
  end

  def vocabulary_class
    entry_class.module_parent::Vocabulary
  end

  def matching_snapshots(assignment_class, key:, slug:)
    assignment_class.where(vocabulary_key_snapshot: key, term_slug_snapshot: slug, locale_snapshot: locale)
  end
end
