# frozen_string_literal: true

EmailReentryOtpDeliveryBindingValue =
  Data.define(:email_ceremony_transaction_ref, :email_otp_generation) do
    class << self
      public

      def for(purpose:, email_ceremony_transaction_ref:, email_otp_generation:)
        unless %w(recovery withdrawal).include?(purpose.to_s)
          unless email_ceremony_transaction_ref.nil? && email_otp_generation.nil?
            raise ArgumentError, "email ceremony delivery purpose mismatch"
          end

          return nil
        end
        [email_ceremony_transaction_ref, email_otp_generation].each do |reference|
          unless reference.is_a?(String) && reference.valid_encoding? &&
              reference.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
            raise ArgumentError, "email ceremony delivery UUID references required"
          end
        end

        new(
          email_ceremony_transaction_ref: email_ceremony_transaction_ref.dup.freeze,
          email_otp_generation: email_otp_generation.dup.freeze,
        )
      end
    end
  end
