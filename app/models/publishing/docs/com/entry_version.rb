# frozen_string_literal: true

module Publishing
  module Docs
    module Com
      class EntryVersion < PublishingRecord
        self.table_name = "publishing_docs_com_entry_versions"
        include PublishingEntryVersionRecord

        validates :created_by_operator_public_id, length: { maximum: 21 }
        # Unique indexes that include the primary key back composite references; checked only for an explicit id.
        validates :id, uniqueness: { scope: %i(entry_id) }, allow_nil: true, if: :will_save_change_to_id?
        validates :id, uniqueness: { scope: %i(locale) }, allow_nil: true, if: :will_save_change_to_id?
      end
    end
  end
end
