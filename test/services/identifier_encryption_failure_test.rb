# frozen_string_literal: true

require "test_helper"

class IdentifierEncryptionFailureTest < ActiveSupport::TestCase
  test "unreadable persisted email fails re-encryption instead of reporting partial success" do
    record = OperatorEmail.create!(
      staff: operators(:one), raw_address: "reencrypt-corrupt@example.com", confirm_policy: true,
    )
    ciphertext = ActiveRecord::Encryption.encryptor.encrypt("reencrypt-corrupt@example.com")
    ActiveRecord::Encryption.without_encryption { record.update_columns(address: ciphertext) }

    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      IdentifierEncryptionReencrypt.new(models: [OperatorEmail]).call
    end
  end

  test "unreadable persisted telephone fails re-encryption instead of reporting partial success" do
    record = OperatorTelephone.create!(
      staff: operators(:one), raw_number: "+819012399906", confirm_policy: true, confirm_using_mfa: true,
    )
    ciphertext = ActiveRecord::Encryption.encryptor.encrypt("+819012399906")
    ActiveRecord::Encryption.without_encryption { record.update_columns(number: ciphertext) }

    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      IdentifierEncryptionReencrypt.new(models: [OperatorTelephone]).call
    end
  end

  test "re-encryption targets reject nil empty unknown and non identifier models" do
    [nil, [], [nil], [0], [Client], [Operator], [Visitor], ["ClientEmail"]].each do |models|
      assert_raises(ArgumentError) { IdentifierEncryptionReencrypt.new(models: models) }
    end
  end
end
