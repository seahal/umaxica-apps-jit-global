# frozen_string_literal: true

module Publishing
  class MediaFile < PublishingRecord
    self.table_name = "publishing_media_files"

    include PublicId
    include PublishingMediaUploader::Attachment[:file]

    before_validation :assign_shrine_file_metadata, if: -> { file.present? }
    after_save :sync_store_key_after_promote, if: -> { file.present? }

    private

    def shrine_file_column_values
      {
        storage_key: file.id,
        content_type: file.mime_type,
        byte_size: file.size,
        digest_algorithm: "sha256",
        digest: file.metadata["sha256"],
      }
    end

    def assign_shrine_file_metadata
      assign_attributes(shrine_file_column_values)
    end

    def sync_store_key_after_promote
      values = shrine_file_column_values
      return if storage_key == values.fetch(:storage_key)

      update(values)
    end
  end
end
