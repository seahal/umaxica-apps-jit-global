# typed: false
# frozen_string_literal: true

module Publishing
  # Immutable placement of a media file on a released entry version.
  # PostgreSQL rejects UPDATE and DELETE; the callbacks raise a readable
  # Active Record error first.
  class VersionMediaUsage < PublishingRecord
    self.table_name = "publishing_version_media_usages"

    include PublicId

    before_update { raise(ActiveRecord::ReadOnlyRecord, "Publishing::VersionMediaUsage is immutable") }
    before_destroy { raise(ActiveRecord::ReadOnlyRecord, "Publishing::VersionMediaUsage is immutable") }

    belongs_to :media_file, class_name: "Publishing::MediaFile", inverse_of: :version_media_usages
    belongs_to :entry_version, class_name: "Publishing::EntryVersion", inverse_of: :media_usages

    validates :role, presence: true
    validates :position, numericality: { greater_than_or_equal_to: 0, only_integer: true }
    validate :path_present

    private

    def path_present
      return if field_path.present? || block_path.present?

      errors.add(:base, "must have a field_path or block_path")
    end
  end
end
