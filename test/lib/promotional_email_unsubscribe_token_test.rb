# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PromotionalEmailUnsubscribeTokenTest < ActiveSupport::TestCase
  def with_env(overrides)
    saved = overrides.to_h { |key, _value| [key, ENV[key]] }
    overrides.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    saved.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  test "generates stable client token for an email public id" do
    email = ClientEmail.new(public_id: "email_public_id")

    Rails.app.creds.stub(:option, "unsubscribe-secret_credential") do
      expected = OpenSSL::HMAC.hexdigest(
        "SHA256",
        "unsubscribe-secret_credential",
        "client:email_public_id:promotional:v1",
      )

      assert_equal expected, PromotionalEmailUnsubscribeToken.generate(email, scope: :client)
      assert PromotionalEmailUnsubscribeToken.valid?(email, expected, scope: :client)
    end
  end

  test "rejects tokens generated for another scope" do
    email = ClientEmail.new(public_id: "email_public_id")

    Rails.app.creds.stub(:option, "unsubscribe-secret_credential") do
      operator_token = PromotionalEmailUnsubscribeToken.generate(email, scope: :operator)

      assert_not PromotionalEmailUnsubscribeToken.valid?(email, operator_token, scope: :client)
    end
  end

  test "raises when unsubscribe hmac salt is missing" do
    with_env("PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT" => nil) do
      Rails.app.creds.stub(:option, nil) do
        error =
          assert_raises(KeyError) do
            PromotionalEmailUnsubscribeToken.generate(ClientEmail.new(public_id: "email_public_id"), scope: :client)
          end

        assert_equal "Missing key: [:PROMOTIONAL_UNSUBSCRIBE_HMAC_SALT]", error.message
      end
    end
  end
end
