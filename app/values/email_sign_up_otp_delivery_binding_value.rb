# frozen_string_literal: true

EmailSignUpOtpDeliveryBindingValue =
  Data.define(:sign_up_flow_ref, :sign_up_email_transaction_ref, :sign_up_email_otp_generation) do
    class << self
      public

      def for(purpose:, sign_up_flow_ref:, sign_up_email_transaction_ref:, sign_up_email_otp_generation:)
        unless purpose.to_s == "sign_up"
          unless sign_up_flow_ref.nil? && sign_up_email_transaction_ref.nil? && sign_up_email_otp_generation.nil?
            raise ArgumentError, "Email signup delivery purpose mismatch"
          end

          return nil
        end
        unless sign_up_flow_ref.is_a?(String) && sign_up_flow_ref.encoding.ascii_compatible? &&
            sign_up_flow_ref.valid_encoding? && sign_up_flow_ref.match?(/\A[A-Za-z0-9_-]{1,21}\z/)
          raise ArgumentError, "Email signup delivery flow reference required"
        end

        [sign_up_email_transaction_ref, sign_up_email_otp_generation].each do |reference|
          unless reference.is_a?(String) && reference.encoding.ascii_compatible? && reference.valid_encoding? &&
              reference.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
            raise ArgumentError, "Email signup delivery UUID references required"
          end
        end

        new(
          sign_up_flow_ref: sign_up_flow_ref.dup.freeze,
          sign_up_email_transaction_ref: sign_up_email_transaction_ref.dup.freeze,
          sign_up_email_otp_generation: sign_up_email_otp_generation.dup.freeze,
        )
      end
    end
  end
