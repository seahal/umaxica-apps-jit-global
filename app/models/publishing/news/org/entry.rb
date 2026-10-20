# frozen_string_literal: true

module Publishing
  module News
    module Org
      class Entry < PublishingRecord
        self.table_name = "publishing_news_org_entries"
        include PublishingEntryRecord

        SURFACE = "news"
        AUDIENCE = "org"
        REGION_CODE = "jp"

        validates :archived_by_operator_public_id, length: { maximum: 21 }
        # Unique indexes that include the primary key back composite references; checked only for an explicit id.
        validates :id, uniqueness: { scope: %i(locale) }, allow_nil: true, if: :will_save_change_to_id?
      end
    end
  end
end
