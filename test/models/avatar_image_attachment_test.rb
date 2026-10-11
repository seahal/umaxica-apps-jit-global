# frozen_string_literal: true

require "test_helper"

class AvatarImageAttachmentTest < ActiveSupport::TestCase
  PNG_HEX =
    "89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de" \
    "0000000c4944415408d763f80f00000101000518d84e0000000049454e44ae426082"
  PNG = [PNG_HEX].pack("H*")

  setup do
    @capability = AvatarCapability.find(AvatarCapability::NORMAL)
    @handle = Handle.create!(
      handle: "img-#{SecureRandom.hex(4)}",
      cooldown_until: Time.current,
    )
    @avatar = Avatar.create!(
      capability: @capability,
      active_handle: @handle,
      moniker: "Image Owner",
    )
  end

  test "a valid png is stored on the avatar boundary and persisted in the avatar database" do
    @avatar.image = StringIO.new(PNG)
    @avatar.save!

    assert_predicate @avatar.image, :present?
    assert_equal :avatar_store, @avatar.image.storage_key
    assert_equal "image/png", @avatar.image.mime_type
    assert_not_nil @avatar.image_data
    assert_equal "avatar_store", @avatar.image_data["storage"]
    assert_not @avatar.image_data.key?("url")
    assert_equal "avatar", Avatar.connection_db_config.name
    persisted = Avatar.lease_connection.select_value(
      # rubocop:disable I18n/RailsI18n/DecorateString
      Avatar.sanitize_sql_array(["SELECT image_data FROM avatars WHERE id = ?", @avatar.id]),
      # rubocop:enable I18n/RailsI18n/DecorateString
    )

    assert_not_nil persisted
    assert_equal 0, PublishingRecord.lease_connection.select_value(
      "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'avatars'",
    )
  end

  test "a non-image is rejected" do
    @avatar.image = StringIO.new("not an image")

    assert_not @avatar.save
    assert_not_empty @avatar.errors[:image]
    assert_nil @avatar.reload.image_data
  end

  test "an oversized file is rejected" do
    oversized = StringIO.new(PNG + ("x" * (AvatarImageUploader::MAX_SIZE + 1)))
    @avatar.image = oversized

    assert_not @avatar.save
    assert_not_empty @avatar.errors[:image]
  end

  test "replacing an image deletes the previous shrine object" do
    @avatar.image = StringIO.new(PNG)
    @avatar.save!
    previous_id = @avatar.image.id
    previous_storage = @avatar.image.storage

    @avatar.image = StringIO.new(PNG)
    @avatar.save!

    assert_not_equal previous_id, @avatar.image.id
    assert_not previous_storage.exists?(previous_id)
  end

  test "deleting an image clears shrine metadata" do
    @avatar.image = StringIO.new(PNG)
    @avatar.save!
    previous_id = @avatar.image.id
    previous_storage = @avatar.image.storage

    @avatar.image = nil
    @avatar.save!

    assert_nil @avatar.reload.image_data
    assert_not previous_storage.exists?(previous_id)
  end
end
