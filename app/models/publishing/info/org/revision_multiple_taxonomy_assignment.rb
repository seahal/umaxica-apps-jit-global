# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class RevisionMultipleTaxonomyAssignment < PublishingRecord
        self.table_name = "publishing_info_org_revision_multiple_taxonomy_assignments"
        include PublishingFamilyTaxonomyAssignment

        belongs_to :entry_revision, class_name: "Publishing::Info::Org::EntryRevision",
                                    inverse_of: :multiple_taxonomy_assignments
        validates :position,
                  numericality: { only_integer: true,
                                  greater_than_or_equal_to: 0,
                                  less_than_or_equal_to: 2_147_483_647, }

        scope :ordered, -> { order(:position) }

        def self.expected_kind = Publishing::TaxonomyKind::MULTIPLE_ORDERED_FLAT
      end
    end
  end
end
