# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class EntryRevision < PublishingRecord
        self.table_name = "publishing_docs_app_entry_revisions"
        include PublishingEntryRevisionRecord

        validates :sequence, uniqueness: { scope: :entry_id }, on: :create
        validates :created_by_operator_public_id, length: { maximum: 21 }
        # Unique indexes that include the primary key back composite references; checked only for an explicit id.
        validates :id, uniqueness: { scope: %i(entry_id) }, allow_nil: true, if: :will_save_change_to_id?
        validates :id, uniqueness: { scope: %i(locale) }, allow_nil: true, if: :will_save_change_to_id?
      end
    end
  end
end
