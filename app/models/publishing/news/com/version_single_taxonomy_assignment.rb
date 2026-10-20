# frozen_string_literal: true

module Publishing
  module News
    module Com
      class VersionSingleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_news_com_version_single_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment
        include PublishingTaxonomySnapshot

        belongs_to :entry_version, class_name: "Publishing::News::Com::EntryVersion",
                                   inverse_of: :single_taxonomy_assignments

        validates :term_path_snapshot, exclusion: { in: [nil] }

        def self.expected_kind = Publishing::TaxonomyKind::SINGLE_HIERARCHICAL
      end
    end
  end
end
