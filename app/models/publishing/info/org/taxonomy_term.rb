# frozen_string_literal: true

module Publishing
  module Info
    module Org
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_info_org_taxonomy_terms"
        include PublishingTaxonomyTermRecord

        validates :slug, :vocabulary_kind, exclusion: { in: [nil] }
        # Unique indexes that include the primary key back composite references; checked only for an explicit id.
        validates :id, uniqueness: { scope: %i(vocabulary_id locale) }, allow_nil: true, if: :will_save_change_to_id?
      end
    end
  end
end
