# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: publishing_media_files
# Database name: publishing
#
#  id               :bigint           not null, primary key
#  archive_reason   :string
#  archived_at      :datetime
#  byte_size        :bigint           not null
#  content_type     :string           not null
#  digest           :string           not null
#  digest_algorithm :string           not null
#  height           :integer
#  metadata         :jsonb            not null
#  purged_at        :datetime
#  storage_key      :string           not null
#  width            :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  public_id        :string(21)       not null
#
# Indexes
#
#  index_publishing_media_files_on_public_id    (public_id) UNIQUE
#  index_publishing_media_files_on_storage_key  (storage_key) UNIQUE
#
module Publishing
  class MediaFile < PublishingRecord
    self.table_name = "publishing_media_files"

    include PublicId

    has_many :revision_media_usages, class_name: "Publishing::RevisionMediaUsage", inverse_of: :media_file,
                                     dependent: :restrict_with_exception
    has_many :version_media_usages, class_name: "Publishing::VersionMediaUsage", inverse_of: :media_file,
                                    dependent: :restrict_with_exception
  end
end
