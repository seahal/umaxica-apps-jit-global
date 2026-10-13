# frozen_string_literal: true

require "test_helper"

class EmailSignUpOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "Email signup transport accepts legacy UUID or new NanoID transaction references" do
    valid = {
      purpose: "sign_up",
      sign_up_flow_ref: "signup-flow",
      sign_up_email_transaction_ref: SecureRandom.uuid,
      sign_up_email_otp_generation: SecureRandom.uuid,
    }
    binding = EmailSignUpOtpDeliveryBindingValue.for(**valid)
    nanoid_binding = EmailSignUpOtpDeliveryBindingValue.for(
      **valid.merge(sign_up_email_transaction_ref: "a" * 21),
    )

    assert_equal valid.except(:purpose), binding.to_h
    assert_equal "a" * 21, nanoid_binding.sign_up_email_transaction_ref
    [nil, "", false, 0, "\xFF", "a\0b", "a" * 22].each do |bad|
      assert_raises(ArgumentError) { EmailSignUpOtpDeliveryBindingValue.for(**valid.merge(sign_up_flow_ref: bad)) }
    end
    ["a", "a" * 21].each do |accepted|
      assert_equal accepted,
                   EmailSignUpOtpDeliveryBindingValue.for(**valid.merge(sign_up_flow_ref: accepted)).sign_up_flow_ref
    end
    %i(sign_up_email_transaction_ref sign_up_email_otp_generation).each do |key|
      reference = valid.fetch(key)

      [nil, "", false, 0, "\xFF", "123456".encode(Encoding::UTF_16LE),
       reference[0...-1], "#{reference}x", "#{reference}\0",].each do |bad|
        assert_raises(ArgumentError) { EmailSignUpOtpDeliveryBindingValue.for(**valid.merge(key => bad)) }
      end
    end
    assert_raises(ArgumentError) { EmailSignUpOtpDeliveryBindingValue.for(**valid.merge(purpose: "recovery")) }
    assert_nil EmailSignUpOtpDeliveryBindingValue.for(
      purpose: "recovery", sign_up_flow_ref: nil,
      sign_up_email_transaction_ref: nil, sign_up_email_otp_generation: nil,
    )
  end
end
