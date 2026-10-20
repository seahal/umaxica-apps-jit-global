# frozen_string_literal: true

module Publishing
  module News
    module Com
      class EntrySlug < PublishingRecord
        self.table_name = "publishing_news_com_entry_slugs"
        include PublishingEntrySlugRecord

        validates :slug, exclusion: { in: [nil] }
      end
    end
  end
end
