# typed: false
# frozen_string_literal: true

require "test_helper"

class SignInFlowBindingCodecTest < ActiveSupport::TestCase
  setup do
    @flow = ClientSignInFlow.new(
      public_id: "signin-flow-binding-test",
      state_id: ClientSignInFlow.state_id_for("CHECKPOINT_PENDING"),
      issued_at: Time.utc(2026, 10, 10, 11, 0, 0, 123_456),
      updated_at: Time.utc(2026, 10, 10, 12, 0, 0, 123_456),
    )
  end

  test "round trips the signed sign-in instance phase and generation" do
    encoded = SignInFlowBindingCodec.encode(
      flow: @flow,
      surface: :app,
      phase: "CHECKPOINT_PENDING",
    )

    binding = SignInFlowBindingCodec.decode(encoded)

    assert_equal "app", binding.surface
    assert_equal @flow.public_id, binding.flow_public_id
    assert_equal "CHECKPOINT_PENDING", binding.phase
    assert_equal @flow.issued_at.utc.iso8601(6), binding.generation
  end

  test "does not decode a tampered, expired, or wrong-surface binding" do
    encoded = SignInFlowBindingCodec.encode(
      flow: @flow,
      surface: :app,
      phase: "CHECKPOINT_PENDING",
    )

    assert_nil SignInFlowBindingCodec.decode("#{encoded}tampered")
    assert_nil SignInFlowBindingCodec.decode(
      Rails.application.message_verifier(:sign_in_flow_binding).generate(
        { "k" => "sign_in",
          "s" => "org",
          "f" => @flow.public_id,
          "p" => "CHECKPOINT_PENDING",
          "g" => @flow.issued_at.utc.iso8601(6), },
        purpose: "sign_in_flow_binding",
        expires_in: -1.second,
      ),
    )

    wrong_surface = SignInFlowBindingCodec.encode(
      flow: @flow,
      surface: :com,
      phase: "CHECKPOINT_PENDING",
    )

    assert_equal "com", SignInFlowBindingCodec.decode(wrong_surface).surface
    assert_not_equal "app", SignInFlowBindingCodec.decode(wrong_surface).surface
  end
end
