# typed: false
# frozen_string_literal: true

require "test_helper"

class ClientTotpCredentialPublicIdCollisionTest < ActiveSupport::TestCase
  setup do
    @user = Client.create!(status_id: ClientStatus::NOTHING)
    ClientTotpCredentialStatus.find_or_create_by!(id: ClientTotpCredentialStatus::NOTHING)
    @existing = ClientTotpCredential.create!(user: @user, public_id: "existingtotpid1234567")
  end

  test "generated public_id retries after the model validation sees a duplicate" do
    generated = [@existing.public_id, "replacementtotpid1234"]

    PublicId.stub(:generate, -> { generated.shift }) do
      credential = ClientTotpCredential.create!(user: @user)

      assert_equal "replacementtotpid1234", credential.public_id
    end
  end

  test "caller supplied public_id is not regenerated after a duplicate" do
    duplicate = ClientTotpCredential.new(user: @user, public_id: @existing.public_id)

    error = assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }

    assert_includes error.record.errors[:public_id], "はすでに存在します"
    assert_equal @existing.public_id, duplicate.public_id
  end

  test "validation-disabled creation retries a real unique-index collision" do
    generated = [@existing.public_id, "replacementtotpid1234"]

    PublicId.stub(:generate, -> { generated.shift }) do
      credential = ClientTotpCredential.new(user: @user)
      credential.save!(validate: false)

      assert_equal "replacementtotpid1234", credential.public_id
    end
  end

  test "persisted public_id rejects ordinary model mutation" do
    replacement = "replacementtotpid1234"
    @existing.public_id = replacement

    error = assert_raises(ActiveRecord::RecordInvalid) { @existing.save! }

    assert_includes error.record.errors[:public_id], "cannot be changed after creation"
    assert_equal "existingtotpid1234567", @existing.reload.public_id
  end
end
