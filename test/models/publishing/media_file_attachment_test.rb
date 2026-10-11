# frozen_string_literal: true

require "test_helper"

module Publishing
  class MediaFileAttachmentTest < ActiveSupport::TestCase
    PNG_HEX =
      "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de" \
      "0000000c4944415408d763f80f00000101000518d84e0000000049454e44ae426082"
    PNG = [PNG_HEX].pack("H*")

    test "a valid png is stored on the publishing boundary and persisted in the publishing database" do
      media = Publishing::MediaFile.new
      media.file = StringIO.new(PNG)
      media.save!

      assert_predicate media.file, :present?
      assert_equal :publishing_store, media.file.storage_key
      assert_equal "image/png", media.content_type
      assert_equal media.file.id, media.storage_key
      assert_equal "sha256", media.digest_algorithm
      assert_match(/\A[0-9a-f]{64}\z/, media.digest)
      assert_equal "publishing", Publishing::MediaFile.connection_db_config.name
      persisted = PublishingRecord.lease_connection.select_value(
        # rubocop:disable I18n/RailsI18n/DecorateString
        Publishing::MediaFile.sanitize_sql_array(
          ["SELECT file_data FROM publishing_media_files WHERE id = ?", media.id],
        ),
        # rubocop:enable I18n/RailsI18n/DecorateString
      )

      assert_not_nil persisted
      assert_not media.file_data.key?("url")
      assert_equal 0, Avatar.lease_connection.select_value(
        "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'publishing_media_files'",
      )
    end

    test "a non-image is rejected" do
      media = Publishing::MediaFile.new
      media.file = StringIO.new("not an image")

      assert_not media.save
      assert_not_empty media.errors[:file]
    end

    test "an oversized file is rejected" do
      media = Publishing::MediaFile.new
      media.file = StringIO.new(PNG + ("x" * (PublishingMediaUploader::MAX_SIZE + 1)))

      assert_not media.save
      assert_not_empty media.errors[:file]
    end

    test "a shrine media file remains usable as a revision media usage target" do
      media = Publishing::MediaFile.new
      media.file = StringIO.new(PNG)
      media.save!

      entry_class = Publishing::ContentFamilies.entry_class(surface: "docs", audience: "app")
      entry = entry_class.create!(locale: "ja")
      entry.slugs.create!(locale: "ja", slug: "media-shrine", state: "canonical", canonicalized_at: Time.current)
      revision = entry.revisions.create!(
        locale: "ja",
        title: "Shrine Media",
        summary: "summary",
        body: { "text" => "body" },
        schema_version: 1,
        content_digest: Digest::SHA256.hexdigest("shrine-media"),
        sequence: 1,
      )
      entry.update!(current_revision: revision)
      usage = revision.media_usages.create!(
        media_file: media,
        role: "body",
        field_path: "body.blocks.0",
        block_path: "blocks.0",
        position: 0,
      )

      assert_equal media.id, usage.media_file_id
      version = Publishing::PromoteRevisionOperation.call(revision: revision)
      copied = version.media_usages.first

      assert_equal media.id, copied.media_file_id
    end

    test "deleting a media file without usages removes the shrine object" do
      media = Publishing::MediaFile.new
      media.file = StringIO.new(PNG)
      media.save!
      previous_id = media.file.id
      previous_storage = media.file.storage

      media.destroy!

      assert_not previous_storage.exists?(previous_id)
      assert_nil Publishing::MediaFile.find_by(id: media.id)
    end
  end
end
