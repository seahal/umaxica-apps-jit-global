# frozen_string_literal: true

require "test_helper"

module Publishing
  # The twelve families are generated: each carries its own copy of the same model bodies against
  # its own tables, including its own `apply_snapshot` override. Exercising promotion on docs/app
  # alone proves nothing about the other eleven, and the snapshot columns are what a published page
  # renders after a term is later renamed or archived. Promote once per family, through the real
  # operation, and read back what the version froze.
  class FamilyPromotionMatrixTest < ActiveSupport::TestCase
    test "every family freezes its taxonomy assignments into the version it promotes" do
      ContentFamilies::ENTRY_CLASSES.each do |entry_class|
        surface = entry_class::SURFACE
        audience = entry_class::AUDIENCE
        cell = "#{surface}/#{audience}"

        category = publishing_category_vocabulary(audience:, surface:)
        tag = publishing_tag_vocabulary(audience:, surface:)
        guide = publishing_term(vocabulary: category, locale: "ja", slug: "guide", name: "ガイド")
        ruby = publishing_term(vocabulary: tag, locale: "ja", slug: "ruby", name: "Ruby")

        entry = publishing_draft(audience:, surface:, slug: "promoted", title: "Promoted")
        revision = entry.current_revision
        create_single_assignment(
          entry_revision: revision, vocabulary: category, taxonomy_term: guide, locale: "ja",
        )
        create_multiple_assignment(
          entry_revision: revision, vocabulary: tag, taxonomy_term: ruby, locale: "ja", position: 0,
        )

        version = PromoteRevisionOperation.call(revision: revision)

        cell_models = ContentFamilies.cell_for_entry(entry)
        single = cell_models.fetch(:version_single).find_by!(entry_version_id: version.id)

        assert_equal "guide", single.term_slug_snapshot, cell
        assert_equal "category", single.vocabulary_key_snapshot, cell

        multiple = cell_models.fetch(:version_multiple).find_by!(entry_version_id: version.id)

        assert_equal "ruby", multiple.term_slug_snapshot, cell
        assert_equal "tag", multiple.vocabulary_key_snapshot, cell
        # The ordered override copies the live position; a rendered list keeps its published order
        # even after the revision is reordered.
        assert_equal 0, multiple.position_snapshot, cell
        assert_equal(
          { "public_id" => ruby.public_id, "slug" => "ruby", "name" => "Ruby" },
          multiple.as_public_json,
          cell,
        )
      end
    end
  end
end
