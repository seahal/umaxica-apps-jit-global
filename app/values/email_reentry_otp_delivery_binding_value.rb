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
        unless transaction_reference?(email_ceremony_transaction_ref)
          raise ArgumentError, "email ceremony delivery transaction reference required"
        end
        unless generation_reference?(email_otp_generation)
          raise ArgumentError, "email ceremony delivery generation UUID required"
        end

        new(
          email_ceremony_transaction_ref: email_ceremony_transaction_ref.dup.freeze,
          email_otp_generation: email_otp_generation.dup.freeze,
        )
      end

      private

      def transaction_reference?(reference)
        valid_reference?(
          reference,
          /\A(?:[A-Za-z0-9_-]{21}|[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\z/,
        )
      end

      def generation_reference?(reference)
        valid_reference?(reference, /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
      end

      def valid_reference?(reference, pattern)
        reference.is_a?(String) && reference.encoding.ascii_compatible? && reference.valid_encoding? &&
          reference.match?(pattern)
      end
    end
  end
