# frozen_string_literal: true

require "test_helper"

class CredentialRegistrationOtpCodeDigestTest < ActiveSupport::TestCase
  test "code digest binds every original registration fact and the delivery channel" do
    context = {
      "version" => 1,
      "surface" => "app",
      "purpose" => "credential_registration",
      "flow_ref" => SecureRandom.uuid,
      "browser_digest" => "a" * 64,
      "session_ref" => "original-root",
      "owner_ref" => "original-owner",
      "contact_ref" => "original-contact",
      "destination_digest" => "b" * 64,
      "counter" => "0",
      "issued_at" => "2026-10-07T19:00:00.000000Z",
      "expires_at" => "2026-10-07T19:10:00.000000Z",
    }
    original = CredentialRegistrationOtpCodeDigest.for(context: context, channel: :email, code: "123456")

    assert_match(/\A[0-9a-f]{64}\z/, original)
    assert_equal original, CredentialRegistrationOtpCodeDigest.for(context: context, channel: :email, code: "123456")
    context.each_key do |field|
      changed = context.merge(field => "different-original-fact")

      assert_not_equal original,
                       CredentialRegistrationOtpCodeDigest.for(context: changed, channel: :email, code: "123456"),
                       "the original #{field} must be bound"
    end
    assert_not_equal original,
                     CredentialRegistrationOtpCodeDigest.for(context: context, channel: :telephone, code: "123456")
    assert_not_equal original,
                     CredentialRegistrationOtpCodeDigest.for(context: context, channel: :email, code: "123457")
  end

  test "code length immediately below at and above six ASCII digits and reachable sentinels" do
    context = {
      "version" => 1,
      "surface" => "com",
      "purpose" => "credential_registration",
      "flow_ref" => SecureRandom.uuid,
      "browser_digest" => "a" * 64,
      "session_ref" => "root",
      "owner_ref" => "owner",
      "contact_ref" => "contact",
      "destination_digest" => "b" * 64,
      "counter" => "1",
      "issued_at" => "2026-10-07T19:00:00.000000Z",
      "expires_at" => "2026-10-07T19:10:00.000000Z",
    }

    [nil, "", " ", 0, "0", "12345", "1234567", "１２３４５６", "12345\0", [], {}].each do |code|
      assert_raises(ArgumentError) do
        CredentialRegistrationOtpCodeDigest.for(context: context, channel: :email, code: code)
      end
    end
    assert_match(
      /\A[0-9a-f]{64}\z/,
      CredentialRegistrationOtpCodeDigest.for(context: context, channel: :email, code: "000000"),
    )
  end
end
