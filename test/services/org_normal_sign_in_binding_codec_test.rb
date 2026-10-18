# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgNormalSignInBindingCodecTest < ActiveSupport::TestCase
  setup do
    @transaction = {
      "public_id" => "org-normal-binding-test",
      "purpose" => "org_normal_sign_in",
      "operator_id" => 42,
      "issued_at" => 1_791_777_600,
      "expires_at" => 1_791_778_200,
    }
  end

  test "round trips the provider transaction instance and phase" do
    encoded = OrgNormalSignInBindingCodec.encode(
      transaction: @transaction,
      surface: "org",
      phase: "PRIMARY_PENDING",
    )

    binding = OrgNormalSignInBindingCodec.decode(encoded)

    assert_equal "org", binding.surface
    assert_equal @transaction.fetch("public_id"), binding.transaction_public_id
    assert_equal "PRIMARY_PENDING", binding.phase
    assert_equal @transaction.fetch("issued_at").to_s, binding.generation
    assert_equal @transaction.fetch("expires_at"), binding.expires_at
  end

  test "rejects tampered, expired, and invalid provider transaction bindings" do
    encoded = OrgNormalSignInBindingCodec.encode(
      transaction: @transaction,
      surface: "org",
      phase: "PRIMARY_PENDING",
    )

    assert_nil OrgNormalSignInBindingCodec.decode("#{encoded}tampered")
    assert_nil OrgNormalSignInBindingCodec.decode(
      Rails.application.message_verifier(:org_normal_sign_in_binding).generate(
        { "k" => "org_normal_sign_in",
          "s" => "org",
          "t" => @transaction.fetch("public_id"),
          "p" => "PRIMARY_PENDING",
          "g" => @transaction.fetch("issued_at").to_s,
          "e" => @transaction.fetch("expires_at"), },
        purpose: "org_normal_sign_in_binding",
        expires_in: -1.second,
      ),
    )

    assert_nil OrgNormalSignInBindingCodec.decode("invalid")
  end
end
