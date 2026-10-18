# frozen_string_literal: true

# Server-issued delivery references, never browser authentication authority.
AuthEmailOtpDeliveryBindingValue =
  Data.define(:auth_ceremony_session_ref, :auth_email_otp_generation) do
    class << self
      public

      def for(purpose:, auth_ceremony_session_ref:, auth_email_otp_generation:)
        unless purpose.to_s == "sign_in"
          unless auth_ceremony_session_ref.nil? && auth_email_otp_generation.nil?
            raise ArgumentError, "Auth email delivery purpose mismatch"
          end

          return nil
        end
        reference = auth_ceremony_session_ref
        generation = auth_email_otp_generation
        unless reference.is_a?(String) && reference.match?(/\A[1-9][0-9]{0,18}\z/) &&
            reference.to_i <= (1 << 63) - 1 && generation.is_a?(String) &&
            generation.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
          raise ArgumentError, "Auth email delivery reference and generation required"
        end

        new(auth_ceremony_session_ref: reference.dup.freeze, auth_email_otp_generation: generation.dup.freeze)
      end
    end
  end
