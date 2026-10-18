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
        unless valid_reference?(
          contact_ceremony_transaction_ref,
          /\A(?:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|[A-Za-z0-9_-]{21})\z/,
        )
          raise ArgumentError, "Email registration delivery transaction reference required"
        end
        unless valid_reference?(
          contact_otp_generation,
          /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/,
        )
          raise ArgumentError, "Email registration delivery generation UUID required"
        end

        new(
          contact_ceremony_transaction_ref: contact_ceremony_transaction_ref.dup.freeze,
          contact_otp_generation: contact_otp_generation.dup.freeze,
        )
      end

      private

      def valid_reference?(value, pattern)
        value.is_a?(String) && value.encoding.ascii_compatible? && value.valid_encoding? && value.match?(pattern)
      end
    end
  end
