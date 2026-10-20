# frozen_string_literal: true

module Publishing
  module Docs
    module Org
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_docs_org_entry_slugs"
        include PublishingEntrySlugRecord

        validates :slug, exclusion: { in: [nil] }
      end
    end
  end
end
