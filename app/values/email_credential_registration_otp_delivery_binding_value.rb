# frozen_string_literal: true

EmailCredentialRegistrationOtpDeliveryBindingValue =
  Data.define(:contact_ceremony_transaction_ref, :contact_otp_generation) do
    class << self
      public

      def for(purpose:, contact_ceremony_transaction_ref:, contact_otp_generation:)
        unless purpose.to_s == "credential_registration"
          unless contact_ceremony_transaction_ref.nil? && contact_otp_generation.nil?
            raise ArgumentError, "Email registration delivery purpose mismatch"
          end

          return nil
        end
        [contact_ceremony_transaction_ref, contact_otp_generation].each do |reference|
          unless reference.is_a?(String) && reference.encoding.ascii_compatible? && reference.valid_encoding? &&
              reference.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
            raise ArgumentError, "Email registration delivery UUID references required"
          end
        end

        new(
          contact_ceremony_transaction_ref: contact_ceremony_transaction_ref.dup.freeze,
          contact_otp_generation: contact_otp_generation.dup.freeze,
        )
      end
    end
  end
