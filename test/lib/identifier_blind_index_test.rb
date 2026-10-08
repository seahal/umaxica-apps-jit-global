# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentifierBlindIndexTest < ActiveSupport::TestCase
  test "bidx_for_email returns nil for blank email" do
    assert_nil IdentifierBlindIndex.bidx_for_email("", realm: :app)
    assert_nil IdentifierBlindIndex.bidx_for_email("   ", realm: :app)
    assert_nil IdentifierBlindIndex.bidx_for_email(nil, realm: :app)
  end

  test "bidx_for_email returns consistent digest for normalized email" do
    Rails.app.creds.stub(:option, "email-address-secret_credential") do
      result1 = IdentifierBlindIndex.bidx_for_email("user@example.com", realm: :app)
      result2 = IdentifierBlindIndex.bidx_for_email("  USER@Example.COM  ", realm: :app)

      assert_not_nil result1
      assert_equal result1, result2
    end
  end

  test "bidx_for_email prefers email address HMAC key" do
    option =
      ->(key, default: nil) do
        (key == :APP_EMAIL_ADDRESS_HMAC_KEY) ? "email-address-secret_credential" : default
      end

    Rails.app.creds.stub(:option, option) do
      expected = OpenSSL::HMAC.hexdigest("SHA256", "email-address-secret_credential", "app:email:user@example.com")

      assert_equal expected, IdentifierBlindIndex.bidx_for_email("USER@example.com", realm: :app)
    end
  end

  test "bidx_for_email raises when email address HMAC key is missing" do
    saved = ENV["APP_EMAIL_ADDRESS_HMAC_KEY"]
    ENV.delete("APP_EMAIL_ADDRESS_HMAC_KEY")
    Rails.app.creds.stub(:option, nil) do
      error =
        assert_raises(KeyError) do
          IdentifierBlindIndex.bidx_for_email("USER@example.com", realm: :app)
        end

      assert_equal "Missing key: [:APP_EMAIL_ADDRESS_HMAC_KEY]", error.message
    end
  ensure
    if saved.nil?
      ENV.delete("APP_EMAIL_ADDRESS_HMAC_KEY")
    else
      ENV["APP_EMAIL_ADDRESS_HMAC_KEY"] = saved
    end
  end

  test "bidx_for_email raises when email address HMAC key is blank" do
    saved = ENV["APP_EMAIL_ADDRESS_HMAC_KEY"]
    ENV.delete("APP_EMAIL_ADDRESS_HMAC_KEY")
    Rails.app.creds.stub(:option, "") do
      error =
        assert_raises(KeyError) do
          IdentifierBlindIndex.bidx_for_email("USER@example.com", realm: :app)
        end

      assert_equal "Missing key: [:APP_EMAIL_ADDRESS_HMAC_KEY]", error.message
    end
  ensure
    if saved.nil?
      ENV.delete("APP_EMAIL_ADDRESS_HMAC_KEY")
    else
      ENV["APP_EMAIL_ADDRESS_HMAC_KEY"] = saved
    end
  end

  test "bidx_for_email falls back to configured environment key when credentials are missing" do
    saved = ENV["APP_EMAIL_ADDRESS_HMAC_KEY"]
    ENV["APP_EMAIL_ADDRESS_HMAC_KEY"] = "env-email-secret_credential"
    Rails.app.creds.stub(:option, nil) do
      expected = OpenSSL::HMAC.hexdigest("SHA256", "env-email-secret_credential", "app:email:user@example.com")

      assert_equal expected, IdentifierBlindIndex.bidx_for_email("USER@example.com", realm: :app)
    end
  ensure
    if saved.nil?
      ENV.delete("APP_EMAIL_ADDRESS_HMAC_KEY")
    else
      ENV["APP_EMAIL_ADDRESS_HMAC_KEY"] = saved
    end
  end

  test "bidx_for_telephone returns nil for blank telephone" do
    assert_nil IdentifierBlindIndex.bidx_for_telephone("", realm: :app)
    assert_nil IdentifierBlindIndex.bidx_for_telephone("   ", realm: :app)
    assert_nil IdentifierBlindIndex.bidx_for_telephone(nil, realm: :app)
  end

  test "bidx_for_telephone returns consistent digest for normalized telephone" do
    Rails.app.creds.stub(:option, "telephone-number-secret_credential") do
      result1 = IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: :app)
      result2 = IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :app)

      assert_not_nil result1
      assert_equal result1, result2
    end
  end

  test "bidx_for_telephone prefers telephone number HMAC key" do
    option =
      ->(key, default: nil) do
        (key == :APP_TELEPHONE_NUMBER_HMAC_KEY) ? "telephone-number-secret_credential" : default
      end

    Rails.app.creds.stub(:option, option) do
      expected = OpenSSL::HMAC.hexdigest("SHA256", "telephone-number-secret_credential", "app:telephone:+819012345678")

      assert_equal expected, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :app)
    end
  end

  test "bidx_for_telephone raises when telephone number HMAC key is missing" do
    saved = ENV["APP_TELEPHONE_NUMBER_HMAC_KEY"]
    ENV.delete("APP_TELEPHONE_NUMBER_HMAC_KEY")
    Rails.app.creds.stub(:option, nil) do
      error =
        assert_raises(KeyError) do
          IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :app)
        end

      assert_equal "Missing key: [:APP_TELEPHONE_NUMBER_HMAC_KEY]", error.message
    end
  ensure
    if saved.nil?
      ENV.delete("APP_TELEPHONE_NUMBER_HMAC_KEY")
    else
      ENV["APP_TELEPHONE_NUMBER_HMAC_KEY"] = saved
    end
  end

  test "bidx_for_telephone raises when telephone number HMAC key is blank" do
    saved = ENV["APP_TELEPHONE_NUMBER_HMAC_KEY"]
    ENV.delete("APP_TELEPHONE_NUMBER_HMAC_KEY")
    Rails.app.creds.stub(:option, "") do
      error =
        assert_raises(KeyError) do
          IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :app)
        end

      assert_equal "Missing key: [:APP_TELEPHONE_NUMBER_HMAC_KEY]", error.message
    end
  ensure
    if saved.nil?
      ENV.delete("APP_TELEPHONE_NUMBER_HMAC_KEY")
    else
      ENV["APP_TELEPHONE_NUMBER_HMAC_KEY"] = saved
    end
  end

  test "bidx_for_telephone falls back to configured environment key when credentials are missing" do
    saved = ENV["APP_TELEPHONE_NUMBER_HMAC_KEY"]
    ENV["APP_TELEPHONE_NUMBER_HMAC_KEY"] = "env-telephone-secret_credential"
    Rails.app.creds.stub(:option, nil) do
      expected = OpenSSL::HMAC.hexdigest("SHA256", "env-telephone-secret_credential", "app:telephone:+819012345678")

      assert_equal expected, IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :app)
    end
  ensure
    if saved.nil?
      ENV.delete("APP_TELEPHONE_NUMBER_HMAC_KEY")
    else
      ENV["APP_TELEPHONE_NUMBER_HMAC_KEY"] = saved
    end
  end
end
