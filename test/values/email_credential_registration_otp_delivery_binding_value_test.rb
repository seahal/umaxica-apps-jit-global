# frozen_string_literal: true

require "test_helper"

class EmailCredentialRegistrationOtpDeliveryBindingValueTest < ActiveSupport::TestCase
  test "Email registration delivery requires transaction and generation UUIDs instead of a source counter" do
    arguments = {
      purpose: "credential_registration",
      contact_ceremony_transaction_ref: SecureRandom.uuid,
      contact_otp_generation: SecureRandom.uuid,
    }
    binding = EmailCredentialRegistrationOtpDeliveryBindingValue.for(**arguments)

    assert_equal arguments.except(:purpose), binding.to_h
    assert_predicate binding, :frozen?
    arguments.except(:purpose).each_key do |key|
      [nil, false, 0, "", "0", arguments.fetch(key)[0...-1], "#{arguments.fetch(key)}x",
       "bad\0ref", "\xFF", arguments.fetch(key).encode(Encoding::UTF_16LE),].each do |invalid|
        assert_raises(ArgumentError) do
          EmailCredentialRegistrationOtpDeliveryBindingValue.for(**arguments.merge(key => invalid))
        end
      end
    end
    assert_raises(ArgumentError) do
      EmailCredentialRegistrationOtpDeliveryBindingValue.for(**arguments.merge(purpose: "sign_up"))
    end
    assert_nil EmailCredentialRegistrationOtpDeliveryBindingValue.for(
      purpose: "sign_up", contact_ceremony_transaction_ref: nil, contact_otp_generation: nil,
    )
  end
end
