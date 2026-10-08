# frozen_string_literal: true

require "test_helper"

class RealmIdentifierDigestTest < ActiveSupport::TestCase
  test "malformed and NUL identifiers do not acquire lookup digests in any realm" do
    %w(app com org).each do |realm|
      [nil, "", " ", "not-an-email", "user\0@example.com", "\xFF@example.com"].each do |value|
        assert_nil IdentifierBlindIndex.bidx_for_email(value, realm: realm)
      end
      [nil, "", " ", "not-a-number", "+819012345678\0", "\xFF+819012345678"].each do |value|
        assert_nil IdentifierBlindIndex.bidx_for_telephone(value, realm: realm)
      end
      assert_raises(ArgumentError) { IdentifierBlindIndex.bidx_for_email(0, realm: realm) }
      assert_raises(ArgumentError) { IdentifierBlindIndex.bidx_for_telephone(0, realm: realm) }
    end
  end

  test "missing realm keys fail closed even when the legacy global keys exist" do
    keys = %w(
      APP_EMAIL_ADDRESS_HMAC_KEY COM_EMAIL_ADDRESS_HMAC_KEY ORG_EMAIL_ADDRESS_HMAC_KEY
      APP_TELEPHONE_NUMBER_HMAC_KEY COM_TELEPHONE_NUMBER_HMAC_KEY ORG_TELEPHONE_NUMBER_HMAC_KEY
      EMAIL_ADDRESS_HMAC_SALT TELEPHONE_NUMBER_HMAC_SALT
    )
    saved = keys.index_with { |key| ENV[key] }
    keys.each { |key| ENV.delete(key) }
    ENV["EMAIL_ADDRESS_HMAC_SALT"] = "legacy-email-key-must-not-work"
    ENV["TELEPHONE_NUMBER_HMAC_SALT"] = "legacy-telephone-key-must-not-work"

    Rails.app.creds.stub(:option, nil) do
      %w(app com org).each do |realm|
        email_error =
          assert_raises(KeyError) do
            IdentifierBlindIndex.bidx_for_email("user@example.com", realm: realm)
          end
        telephone_error =
          assert_raises(KeyError) do
            IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: realm)
          end
        assert_includes email_error.message, "#{realm.upcase}_EMAIL_ADDRESS_HMAC_KEY"
        assert_includes telephone_error.message, "#{realm.upcase}_TELEPHONE_NUMBER_HMAC_KEY"
      end
    end
  ensure
    saved.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  test "email keys cannot produce telephone lookup digests in any realm" do
    keys = {
      APP_EMAIL_ADDRESS_HMAC_KEY: "app-email-test-key",
      COM_EMAIL_ADDRESS_HMAC_KEY: "com-email-test-key",
      ORG_EMAIL_ADDRESS_HMAC_KEY: "org-email-test-key",
      APP_TELEPHONE_NUMBER_HMAC_KEY: "app-telephone-test-key",
      COM_TELEPHONE_NUMBER_HMAC_KEY: "com-telephone-test-key",
      ORG_TELEPHONE_NUMBER_HMAC_KEY: "org-telephone-test-key",
    }
    Rails.app.creds.stub(:option, ->(key) { keys.fetch(key) }) do
      %w(app com org).each do |realm|
        telephone = IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: realm)
        wrong_key = keys.fetch(IdentifierBlindIndex::EMAIL_KEYS.fetch(realm))
        wrong_digest = OpenSSL::HMAC.hexdigest("SHA256", wrong_key, "#{realm}:telephone:+819012345678")

        assert_not_equal wrong_digest, telephone
      end
    end
  end

  test "missing empty unknown zero and NUL realms are refused rather than inferred" do
    [nil, "", "unknown", 0, "app\0"].each do |realm|
      assert_raises(ArgumentError) { IdentifierBlindIndex.bidx_for_email("user@example.com", realm: realm) }
      assert_raises(ArgumentError) { IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: realm) }
    end
    assert_raises(ArgumentError) { IdentifierBlindIndex.bidx_for_email("user@example.com") }
    assert_raises(ArgumentError) { IdentifierBlindIndex.bidx_for_telephone("+819012345678") }
  end

  test "equivalent email has the same digest within a realm and different digests across all three realms" do
    keys = {
      APP_EMAIL_ADDRESS_HMAC_KEY: "app-email-test-key",
      COM_EMAIL_ADDRESS_HMAC_KEY: "com-email-test-key",
      ORG_EMAIL_ADDRESS_HMAC_KEY: "org-email-test-key",
    }
    Rails.app.creds.stub(:option, ->(key) { keys.fetch(key) }) do
      app = IdentifierBlindIndex.bidx_for_email("user@example.com", realm: :app)
      com = IdentifierBlindIndex.bidx_for_email("user@example.com", realm: :com)
      org = IdentifierBlindIndex.bidx_for_email("user@example.com", realm: :org)

      assert_equal app, IdentifierBlindIndex.bidx_for_email(" USER@EXAMPLE.COM ", realm: :app)
      assert_equal com, IdentifierBlindIndex.bidx_for_email(" USER@EXAMPLE.COM ", realm: :com)
      assert_equal org, IdentifierBlindIndex.bidx_for_email(" USER@EXAMPLE.COM ", realm: :org)
      assert_not_equal app, com
      assert_not_equal app, org
      assert_not_equal com, org
    end
  end

  test "equivalent telephone has the same digest within a realm and different digests across all three realms" do
    keys = {
      APP_TELEPHONE_NUMBER_HMAC_KEY: "app-telephone-test-key",
      COM_TELEPHONE_NUMBER_HMAC_KEY: "com-telephone-test-key",
      ORG_TELEPHONE_NUMBER_HMAC_KEY: "org-telephone-test-key",
    }
    Rails.app.creds.stub(:option, ->(key) { keys.fetch(key) }) do
      app = IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: :app)
      com = IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: :com)
      org = IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: :org)

      assert_equal app, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :app)
      assert_equal com, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :com)
      assert_equal org, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :org)
      assert_not_equal app, com
      assert_not_equal app, org
      assert_not_equal com, org
    end
  end
end
