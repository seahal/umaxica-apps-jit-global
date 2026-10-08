# frozen_string_literal: true

require "test_helper"

class EmailReentryOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "email delivery requires both UUID fields with length neighbors and typed malformed partitions" do
    reference = SecureRandom.uuid
    generation = SecureRandom.uuid
    invalid_values = [nil, "", 0, false, reference[0...-1], "#{reference}x", " #{reference}",
                      "#{reference}\0", "\xFF", "not-a-uuid",]
    invalid_values.each do |invalid|
      assert_raises(ArgumentError) do
        EmailReentryOtpDeliveryBindingValue.for(
          purpose: "recovery", email_ceremony_transaction_ref: invalid, email_otp_generation: generation,
        )
      end
      assert_raises(ArgumentError) do
        EmailReentryOtpDeliveryBindingValue.for(
          purpose: "recovery", email_ceremony_transaction_ref: reference, email_otp_generation: invalid,
        )
      end
    end
    binding = EmailReentryOtpDeliveryBindingValue.for(
      purpose: "withdrawal", email_ceremony_transaction_ref: reference, email_otp_generation: generation,
    )

    assert_equal reference, binding.email_ceremony_transaction_ref
    assert_equal generation, binding.email_otp_generation
    assert_predicate binding.email_ceremony_transaction_ref, :frozen?
    assert_predicate binding.email_otp_generation, :frozen?
  end

  test "other purposes have no reentry binding and reject either stray reference rather than reuse proof" do
    [nil, "", "sign_up", "sign_in", "credential_registration"].each do |purpose|
      assert_nil EmailReentryOtpDeliveryBindingValue.for(
        purpose: purpose, email_ceremony_transaction_ref: nil, email_otp_generation: nil,
      )
      assert_raises(ArgumentError) do
        EmailReentryOtpDeliveryBindingValue.for(
          purpose: purpose, email_ceremony_transaction_ref: SecureRandom.uuid, email_otp_generation: nil,
        )
      end
      assert_raises(ArgumentError) do
        EmailReentryOtpDeliveryBindingValue.for(
          purpose: purpose, email_ceremony_transaction_ref: nil, email_otp_generation: SecureRandom.uuid,
        )
      end
    end
  end
end
