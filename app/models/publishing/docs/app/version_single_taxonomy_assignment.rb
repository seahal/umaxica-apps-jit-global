# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class VersionSingleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_docs_app_version_single_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment
        include PublishingTaxonomySnapshot

        belongs_to :entry_version, class_name: "Publishing::Docs::App::EntryVersion",
                                   inverse_of: :single_taxonomy_assignments

        validates :term_path_snapshot, exclusion: { in: [nil] }

        def self.expected_kind = Publishing::TaxonomyKind::SINGLE_HIERARCHICAL
      end
    end
  end
end
