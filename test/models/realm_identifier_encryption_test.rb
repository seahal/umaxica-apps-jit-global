# frozen_string_literal: true

require "test_helper"

class RealmIdentifierEncryptionTest < ActiveSupport::TestCase
  test "realm derivation keeps ciphertext isolated even if configured key and salt values accidentally coincide" do
    names =
      %w(APP COM ORG).flat_map do |prefix|
        ["#{prefix}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", "#{prefix}_ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
      end
    original = names.index_with { |name| ENV.fetch(name) }
    names.each { |name| ENV[name] = "same-local-test-secret-value" }
    providers = %w(app com org).index_with { |realm| RealmIdentifierEncryptionKeyProvider.key_provider(realm: realm) }
    providers.each do |realm, provider|
      ciphertext = ActiveRecord::Encryption.encryptor.encrypt("realm@example.com", key_provider: provider)

      assert_equal "realm@example.com", ActiveRecord::Encryption.encryptor.decrypt(ciphertext, key_provider: provider)
      providers.except(realm).each_value do |other_provider|
        assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
          ActiveRecord::Encryption.encryptor.decrypt(ciphertext, key_provider: other_provider)
        end
      end
    end
  ensure
    original&.each { |name, value| ENV[name] = value }
  end

  test "identifier models reject ciphertext encrypted under the non-identifier global keyring" do
    email = ActiveRecord::Encryption.encryptor.encrypt("global@example.com")
    telephone = ActiveRecord::Encryption.encryptor.encrypt("+819012345678")

    [ClientEmail, VisitorEmail, OperatorEmail].each do |model|
      assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
        model.type_for_attribute("address").deserialize(email)
      end
    end
    [ClientTelephone, VisitorTelephone, OperatorTelephone].each do |model|
      assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
        model.type_for_attribute("number").deserialize(telephone)
      end
    end
  end

  test "each realm keyring reads previous ciphertext and encrypts with only the current key" do
    %w(app com org).each do |realm|
      prefix = realm.upcase
      current_name = "#{prefix}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"
      previous_name = "#{prefix}_ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY_PREVIOUS"
      old_current = ENV.fetch(current_name)
      old_previous = ENV[previous_name]
      begin
        previous_provider = RealmIdentifierEncryptionKeyProvider.key_provider(realm: realm)
        previous_ciphertext = ActiveRecord::Encryption.encryptor.encrypt(
          "previous@example.com",
          key_provider: previous_provider,
        )
        ENV[current_name] = "new-test-#{realm}-encryption-key"
        ENV[previous_name] = JSON.generate([old_current])
        rotated = RealmIdentifierEncryptionKeyProvider.key_provider(realm: realm)

        assert_equal "previous@example.com",
                     ActiveRecord::Encryption.encryptor.decrypt(previous_ciphertext, key_provider: rotated)
        current_ciphertext = ActiveRecord::Encryption.encryptor.encrypt("current@example.com", key_provider: rotated)
        assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
          ActiveRecord::Encryption.encryptor.decrypt(current_ciphertext, key_provider: previous_provider)
        end
      ensure
        ENV[current_name] = old_current
        old_previous.nil? ? ENV.delete(previous_name) : ENV[previous_name] = old_previous
      end
    end
  end

  test "APP COM and ORG email ciphertext is readable only by its owning realm" do
    app = ClientEmail.new(address: "realm-encryption@example.com").ciphertext_for("address")
    com = VisitorEmail.new(address: "realm-encryption@example.com").ciphertext_for("address")
    org = OperatorEmail.new(address: "realm-encryption@example.com").ciphertext_for("address")

    assert_equal "realm-encryption@example.com", ClientEmail.type_for_attribute("address").deserialize(app)
    assert_equal "realm-encryption@example.com", VisitorEmail.type_for_attribute("address").deserialize(com)
    assert_equal "realm-encryption@example.com", OperatorEmail.type_for_attribute("address").deserialize(org)
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      VisitorEmail.type_for_attribute("address").deserialize(app)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      OperatorEmail.type_for_attribute("address").deserialize(app)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      ClientEmail.type_for_attribute("address").deserialize(com)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      OperatorEmail.type_for_attribute("address").deserialize(com)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      ClientEmail.type_for_attribute("address").deserialize(org)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      VisitorEmail.type_for_attribute("address").deserialize(org)
    end
  end

  test "APP COM and ORG telephone ciphertext is readable only by its owning realm" do
    app = ClientTelephone.new(number: "+819012345678").ciphertext_for("number")
    com = VisitorTelephone.new(number: "+819012345678").ciphertext_for("number")
    org = OperatorTelephone.new(number: "+819012345678").ciphertext_for("number")

    assert_equal "+819012345678", ClientTelephone.type_for_attribute("number").deserialize(app)
    assert_equal "+819012345678", VisitorTelephone.type_for_attribute("number").deserialize(com)
    assert_equal "+819012345678", OperatorTelephone.type_for_attribute("number").deserialize(org)
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      VisitorTelephone.type_for_attribute("number").deserialize(app)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      OperatorTelephone.type_for_attribute("number").deserialize(app)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      ClientTelephone.type_for_attribute("number").deserialize(com)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      OperatorTelephone.type_for_attribute("number").deserialize(com)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      ClientTelephone.type_for_attribute("number").deserialize(org)
    end
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      VisitorTelephone.type_for_attribute("number").deserialize(org)
    end
  end
end
