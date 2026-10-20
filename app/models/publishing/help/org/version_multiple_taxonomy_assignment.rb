# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class VersionMultipleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_help_org_version_multiple_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment
        include PublishingTaxonomySnapshot

        belongs_to :entry_version, class_name: "Publishing::Help::Org::EntryVersion",
                                   inverse_of: :multiple_taxonomy_assignments
        validates :position,
                  numericality: { only_integer: true,
                                  greater_than_or_equal_to: 0,
                                  less_than_or_equal_to: 2_147_483_647, },
                  on: :create
        validates :term_path_snapshot, exclusion: { in: [nil] }

        scope :ordered, -> { order(:position) }

        def self.expected_kind = Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT

        def apply_snapshot(vocabulary:, term:)
          super
          self.position_snapshot = position
          self
        end
      end
    end
  end
end
