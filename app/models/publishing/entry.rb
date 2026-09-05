# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_entries
# Database name: publishing
#
#  id                  :bigint           not null, primary key
#  archive_reason      :string
#  archived_at         :datetime
#  locale              :string           not null
#  lock_version        :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  current_revision_id :bigint
#  edition_id          :bigint           not null
#  public_id           :string(21)       not null
#
# Indexes
#
#  index_publishing_entries_on_current_revision_id  (current_revision_id) UNIQUE
#  index_publishing_entries_on_edition_id           (edition_id)
#  index_publishing_entries_on_id_and_locale        (id,locale) UNIQUE
#  index_publishing_entries_on_public_id            (public_id) UNIQUE
#
# Foreign Keys
#
#  fk_publishing_entries_current_revision  ([current_revision_id, id] => publishing_entry_revisions[id, entry_id]) ON DELETE => restrict
#  fk_publishing_entries_edition_locale    ([edition_id, locale] => publishing_editions[id, locale]) ON DELETE => restrict
#  fk_rails_...                            (edition_id => publishing_editions.id) ON DELETE => restrict
#
module Publishing
  class Entry < PublishingRecord
    self.table_name = "publishing_entries"

    include PublicId

    belongs_to :edition, class_name: "Publishing::Edition", inverse_of: :entries
    belongs_to :current_revision, class_name: "Publishing::EntryRevision", optional: true

    has_many :revisions, class_name: "Publishing::EntryRevision", inverse_of: :entry,
                         dependent: :restrict_with_exception
    has_many :versions, class_name: "Publishing::EntryVersion", inverse_of: :entry, dependent: :restrict_with_exception
    has_many :slugs, class_name: "Publishing::EntrySlug", inverse_of: :entry, dependent: :restrict_with_exception
    has_many :publications, class_name: "Publishing::Publication", inverse_of: :entry,
                            dependent: :restrict_with_exception

    has_one :canonical_slug, -> { canonical },
            class_name: "Publishing::EntrySlug", inverse_of: :entry, dependent: :restrict_with_exception
    has_one :active_publication, -> { active },
            class_name: "Publishing::Publication", inverse_of: :entry, dependent: :restrict_with_exception

    def archived? = archived_at.present?
  end
end
