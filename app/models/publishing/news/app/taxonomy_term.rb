# frozen_string_literal: true

module Publishing
  module News
    module App
      class TaxonomyTerm < PublishingRecord
        self.table_name = "publishing_news_app_taxonomy_terms"
        include PublishingTaxonomyTermRecord

        validates :slug, :vocabulary_kind, exclusion: { in: [nil] }
        # Unique indexes that include the primary key back composite references; checked only for an explicit id.
        validates :id, uniqueness: { scope: %i(vocabulary_id locale) }, allow_nil: true, if: :will_save_change_to_id?
      end
    end
  end
end
