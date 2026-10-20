# frozen_string_literal: true

module Publishing
  module Help
    module Org
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_help_org_entry_slugs"
        include PublishingEntrySlugRecord

        validates :slug, exclusion: { in: [nil] }
      end
    end
  end
end
