# frozen_string_literal: true

module Publishing
  module Docs
    module App
      class Vocabulary < PublishingRecord
        self.table_name = "publishing_docs_app_vocabularies"
        include PublishingVocabularyRecord

        validates :key, exclusion: { in: [nil] }
        # Unique indexes that include the primary key back composite references; checked only for an explicit id.
        validates :id, uniqueness: { scope: %i(kind) }, allow_nil: true, if: :will_save_change_to_id?
      end
    end
  end
end
