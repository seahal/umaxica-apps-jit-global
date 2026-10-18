# frozen_string_literal: true

require "test_helper"

class AuthEmailOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "positive reference lower boundary is zero one and two" do
    generation = SecureRandom.uuid
    assert_raises(ArgumentError) do
      AuthEmailOtpDeliveryBindingValue.for(
        purpose: :sign_in, auth_ceremony_session_ref: "0", auth_email_otp_generation: generation,
      )
    end
    %w(1 2).each do |reference|
      value = AuthEmailOtpDeliveryBindingValue.for(
        purpose: :sign_in, auth_ceremony_session_ref: reference, auth_email_otp_generation: generation,
      )

      assert_equal reference, value.auth_ceremony_session_ref
    end
  end

  test "reference width boundaries are eighteen nineteen and twenty decimal characters" do
    generation = SecureRandom.uuid
    [18, 19, 20].each do |width|
      reference = "1" * width
      if width <= 19
        value = AuthEmailOtpDeliveryBindingValue.for(
          purpose: "sign_in", auth_ceremony_session_ref: reference, auth_email_otp_generation: generation,
        )

        assert_equal reference, value.auth_ceremony_session_ref
      else
        assert_raises(ArgumentError) do
          AuthEmailOtpDeliveryBindingValue.for(
            purpose: "sign_in", auth_ceremony_session_ref: reference, auth_email_otp_generation: generation,
          )
        end
      end
    end
  end

  test "database bigint upper boundary is maximum minus one maximum and maximum plus one" do
    maximum = (1 << 63) - 1
    generation = SecureRandom.uuid
    [-1, 0, 1].each do |offset|
      reference = (maximum + offset).to_s
      if offset <= 0
        value = AuthEmailOtpDeliveryBindingValue.for(
          purpose: :sign_in, auth_ceremony_session_ref: reference, auth_email_otp_generation: generation,
        )

        assert_equal reference, value.auth_ceremony_session_ref
      else
        assert_raises(ArgumentError) do
          AuthEmailOtpDeliveryBindingValue.for(
            purpose: :sign_in, auth_ceremony_session_ref: reference, auth_email_otp_generation: generation,
          )
        end
      end
    end
  end

  test "generation width boundaries reject thirty five and thirty seven while accepting thirty six" do
    generation = SecureRandom.uuid

    [generation[0...-1], generation + "0"].each do |invalid|
      assert_raises(ArgumentError) do
        AuthEmailOtpDeliveryBindingValue.for(
          purpose: :sign_in, auth_ceremony_session_ref: "1", auth_email_otp_generation: invalid,
        )
      end
    end
    value = AuthEmailOtpDeliveryBindingValue.for(
      purpose: :sign_in, auth_ceremony_session_ref: "1", auth_email_otp_generation: generation,
    )

    assert_equal generation, value.auth_email_otp_generation
  end

  test "reference and generation refuse missing empty malformed and typed sentinel inputs" do
    [nil, "", 0, false, [], {}, " ", "-1", "01", "1x"].each do |invalid|
      assert_raises(ArgumentError) do
        AuthEmailOtpDeliveryBindingValue.for(
          purpose: :sign_in, auth_ceremony_session_ref: invalid, auth_email_otp_generation: SecureRandom.uuid,
        )
      end
      assert_raises(ArgumentError) do
        AuthEmailOtpDeliveryBindingValue.for(
          purpose: :sign_in, auth_ceremony_session_ref: "1", auth_email_otp_generation: invalid,
        )
      end
    end
  end

  test "other purposes have no Auth binding and cannot carry sign-in references" do
    assert_nil AuthEmailOtpDeliveryBindingValue.for(
      purpose: :sign_up, auth_ceremony_session_ref: nil, auth_email_otp_generation: nil,
    )
    assert_raises(ArgumentError) do
      AuthEmailOtpDeliveryBindingValue.for(
        purpose: :sign_up, auth_ceremony_session_ref: "1", auth_email_otp_generation: SecureRandom.uuid,
      )
    end
  end

  test "binding snapshots are immutable without freezing caller strings" do
    reference = +"123"
    generation = SecureRandom.uuid
    original = generation.dup
    value = AuthEmailOtpDeliveryBindingValue.for(
      purpose: :sign_in, auth_ceremony_session_ref: reference, auth_email_otp_generation: generation,
    )
    reference.replace("456")
    generation.replace("changed")

    assert_equal "123", value.auth_ceremony_session_ref
    assert_equal original, value.auth_email_otp_generation
    assert_predicate value.auth_ceremony_session_ref, :frozen?
    assert_predicate value.auth_email_otp_generation, :frozen?
  end
end
