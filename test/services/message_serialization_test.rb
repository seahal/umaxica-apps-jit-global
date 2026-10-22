# frozen_string_literal: true

require "test_helper"

class MessageSerializationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "sign-in resend state round-trips JSON and rejects authenticated Marshal" do
    binding = "b" * 64
    token = SignInOtpResendState.issue(
      kind: "email", target: "serialization@example.test", surface: "app",
      browser_binding: binding, contact: nil,
    )

    assert_equal "serialization@example.test",
                 SignInOtpResendState.parse(token, browser_binding: binding).fetch(:target)

    key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
      "sign-in-otp-resend", ActiveSupport::MessageEncryptor.key_len,
    )
    legacy = ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: Marshal)
    payload = {
      "version" => "2",
      "kind" => "email",
      "target" => "serialization@example.test",
      "surface" => "app",
      "contact_mode" => "fake",
      "contact_ref" => "0" * 21,
      "owner_ref" => "0" * 20,
      "binding_fact" => "0000-00-00T00:00:00.000000Z",
    }
    token = legacy.encrypt_and_sign(payload, purpose: "sign-in-otp-resend:#{binding}", expires_in: 30.minutes)

    assert_nil SignInOtpResendState.parse(token, browser_binding: binding)
  end

  test "outbound payload rejects authenticated Marshal for each delivery purpose" do
    ["outbound.email.otp", "outbound.email.verification_token", "outbound.sms.delivery.v1"].each do |purpose|
      key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
        purpose, ActiveSupport::MessageEncryptor.key_len,
      )
      legacy = ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: Marshal)
      token = legacy.encrypt_and_sign("legacy payload", purpose: purpose)
      assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
        OutboundSensitivePayload.decrypt(token, purpose: purpose)
      end
    end
  end

  test "sign-in flow binding accepts JSON and rejects a valid Marshal signature" do
    payload = {
      "k" => "sign_in",
      "s" => "app",
      "f" => "serialization-flow",
      "p" => "pending",
      "g" => "serialization-generation",
      "e" => 15.minutes.from_now.to_i,
    }
    token = Rails.application.message_verifier(:sign_in_flow_binding).generate(payload, purpose: "sign_in_flow_binding")

    assert_equal "serialization-flow", SignInFlowBindingCodec.decode(token).flow_public_id

    key = Rails.application.key_generator.generate_key("sign_in_flow_binding")
    legacy = ActiveSupport::MessageVerifier.new(key, serializer: Marshal)
    token = legacy.generate(payload, purpose: "sign_in_flow_binding")

    assert legacy.verified(token, purpose: "sign_in_flow_binding")
    assert_nil SignInFlowBindingCodec.decode(token)
  end

  test "sign-up and org flow bindings refuse authenticated Marshal" do
    key = Rails.application.key_generator.generate_key("sign_flow_binding")
    payload = { "k" => "sign_up",
                "s" => "app",
                "f" => "serialization-flow",
                "p" => "pending",
                "g" => 0,
                "e" => 15.minutes.from_now.to_i, }
    token = ActiveSupport::MessageVerifier.new(key, serializer: Marshal).generate(payload, purpose: "sign_flow_binding")

    assert_nil SignFlowBindingCodec.decode(token)

    key = Rails.application.key_generator.generate_key("org_normal_sign_in_binding")
    token = ActiveSupport::MessageVerifier.new(key, serializer: Marshal).generate(
      { "k" => "org_normal_sign_in",
        "s" => "org",
        "t" => "serialization-transaction",
        "p" => "PRIMARY_PENDING",
        "g" => "1",
        "e" => 15.minutes.from_now.to_i, }, purpose: "org_normal_sign_in_binding",
    )

    assert_nil OrgNormalSignInBindingCodec.decode(token)
  end

  test "session reference lookups refuse authenticated Marshal before accessing records" do
    key = Rails.application.key_generator.generate_key("session_limit_resolution_token_ref")
    token = ActiveSupport::MessageVerifier.new(key, serializer: Marshal).generate({ pid: "legacy" })

    assert_nil SessionLimitResolutionTokenRef.find_client_token(token)
    assert_nil SessionLimitResolutionTokenRef.find_visitor_token(token)
    assert_nil SessionLimitResolutionTokenRef.find_operator_token(token)

    key = Rails.application.key_generator.generate_key("session_ref")
    token = ActiveSupport::MessageVerifier.new(key, serializer: Marshal).generate({ id: 1, pid: "legacy" })

    assert_nil ClientToken.find_from_signed_ref(token)
    assert_empty ClientToken.find_from_signed_refs([token])
  end

  test "logout request refuses authenticated Marshal before consuming a replay identifier" do
    key = Rails.application.key_generator.generate_key("oidc_logout_request")
    token = ActiveSupport::MessageVerifier.new(key, serializer: Marshal).generate(
      { "client_id" => "serialization-client", "ri" => "jp", "jti" => "a" * 32 }, purpose: "oidc_logout_request",
    )

    assert_nil OidcLogoutRequest.verify(token)
  end
end
