# typed: false
# frozen_string_literal: true

module Publishing
  # Editable draft placement of a media file on an entry revision.
  class RevisionMediaUsage < PublishingRecord
    self.table_name = "publishing_revision_media_usages"

    include PublicId

    belongs_to :media_file, class_name: "Publishing::MediaFile", inverse_of: :revision_media_usages
    belongs_to :entry_revision, class_name: "Publishing::EntryRevision", inverse_of: :media_usages

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
