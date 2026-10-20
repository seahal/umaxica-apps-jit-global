# frozen_string_literal: true

require "test_helper"

module Publishing
  class MediaStorageKeyUniquenessTest < ActiveSupport::TestCase
    PNG = ["89504e470d0a1a0a0000000d4948445200000001000000010802000000907753de" \
           "0000000c4944415408d763f80f00000101000518d84e0000000049454e44ae426082"].pack("H*")

    test "storage references retain raw UNIQUE and NOT NULL enforcement" do
      metadata = { content_type: "image/png", byte_size: 1, digest_algorithm: "sha256", digest: "d" * 64 }
      first = MediaFile.create!(metadata.merge(storage_key: "consistency/first"))
      other = MediaFile.create!(metadata.merge(storage_key: "consistency/other"))
      first.update!(byte_size: 2)

      assert_equal "consistency/first", first.reload.storage_key
      assert_equal "consistency/other", other.reload.storage_key
      assert_raises(ActiveRecord::RecordNotUnique) do
        MediaFile.transaction(requires_new: true) do
          MediaFile.new(metadata.merge(storage_key: first.storage_key)).save!(validate: false)
        end
      end
      assert_raises(ActiveRecord::NotNullViolation) do
        MediaFile.transaction(requires_new: true) do
          MediaFile.new(metadata.merge(storage_key: nil)).save!(validate: false)
        end
      end
    end

    test "a duplicate storage reference is refused before model creation" do
      metadata = { content_type: "image/png", byte_size: 1, digest_algorithm: "sha256", digest: "d" * 64 }
      first = MediaFile.create!(metadata.merge(storage_key: "consistency/first"))
      candidate = MediaFile.new(metadata.merge(storage_key: first.storage_key))

      assert_not candidate.valid?
      assert candidate.errors.of_kind?(:storage_key, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { candidate.save! }
      assert_predicate candidate, :new_record?
    end

    test "post-promotion metadata resynchronization still exposes a conflicting DB reference" do
      media = MediaFile.new
      media.file = StringIO.new(PNG)
      media.save!
      original_key = media.reload.storage_key
      detached_key = "detached/#{media.public_id}"
      # Deliberately simulate persisted metadata drift without invoking the synchronization callback.
      media.update_columns(storage_key: detached_key)
      shadow = MediaFile.create!(
        storage_key: original_key, content_type: media.content_type, byte_size: media.byte_size,
        digest_algorithm: media.digest_algorithm, digest: media.digest,
      )
      assert_raises(ActiveRecord::RecordNotUnique) { media.save!(validate: false) }
      assert_equal detached_key, media.reload.storage_key
      assert_equal original_key, shadow.reload.storage_key
      assert media.file.storage.exists?(media.file.id)
    end
  end
end
