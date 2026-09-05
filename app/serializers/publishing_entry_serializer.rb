# typed: false
# frozen_string_literal: true

# Renders a Publishing::Entry's currently published version as public JSON.
#
# Taxonomy is rendered from the published version's frozen snapshots, never
# from the draft revision or from current term names, so renaming or moving a
# term never rewrites an already-published entry.
#
# The taxonomy object is assembled from the vocabularies that exist for this
# edition's audience and surface, keyed by vocabulary key and shaped by
# structural kind. Adding a vocabulary row adds a key here; no branch in this
# class knows the names "category" or "tag".
class PublishingEntrySerializer
  def self.call(...)
    new(...).call
  end

  def initialize(entry:, namespace:, surface:, vocabularies: nil)
    @entry = entry
    @namespace = namespace
    @surface = surface
    @vocabularies = vocabularies
  end

  def call
    version = published_version
    return nil unless version

    {
      public_id: entry.public_id,
      namespace: namespace.to_s,
      surface: surface.to_s,
      slug: canonical_slug,
      locale: version.locale,
      title: version.title,
      summary: version.summary,
      # Always the complete structured body object. It previously collapsed to a
      # bare String whenever the body carried a "text" key, which left consumers
      # unable to rely on the field's type.
      body: version.body,
      published_at: current_publication&.effective_from&.iso8601,
      updated_at: version.updated_at&.iso8601,
      snapshot_public_id: version.public_id,
      taxonomy: taxonomy(version),
    }
  end

  private

  attr_reader :entry, :namespace, :surface

  def taxonomy(version)
    snapshots = version.single_taxonomy_assignments.to_a + version.multiple_taxonomy_assignments.to_a
    by_key = snapshots.group_by(&:vocabulary_key_snapshot)

    vocabularies.each_with_object({}) do |vocabulary, payload|
      payload[vocabulary.key] = vocabulary.structural_kind.serialize(by_key.fetch(vocabulary.key, []))
    end
  end

  # Sorted by key so the JSON key order is stable across requests and
  # deployments rather than following insertion order.
  def vocabularies
    @vocabularies ||=
      Publishing::Vocabulary
        .available
        .for_scope(audience: entry.edition.audience, surface: entry.edition.surface)
        .order(:key)
        .to_a
  end

  def published_version
    current_publication&.entry_version
  end

  def current_publication
    @current_publication ||= entry.active_publication
  end

  def canonical_slug
    entry.canonical_slug&.slug
  end
end
