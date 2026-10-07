# frozen_string_literal: true

SignUpOtpDeliveryBindingValue =
  Data.define(:surface, :purpose, :flow_ref, :contact_ref, :counter) do
    class << self
      public

      def for_sms(otp_binding:)
        unless otp_binding.is_a?(Array) && otp_binding.length == 5
          raise ArgumentError, "signup OTP delivery requires a five-field binding"
        end

        surface, purpose, flow_ref, contact_ref, counter = otp_binding
        unless %w(app com).include?(surface) && purpose == "sign_up" &&
            valid_reference?(flow_ref) && valid_reference?(contact_ref) &&
            counter.is_a?(String) && counter.match?(/\A(?:0|[1-9][0-9]{0,19})\z/) && counter.to_i < (1 << 64)
          raise ArgumentError, "invalid signup OTP delivery binding"
        end

        new(
          surface: surface.dup.freeze, purpose: purpose.dup.freeze,
          flow_ref: flow_ref.dup.freeze, contact_ref: contact_ref.dup.freeze, counter: counter.dup.freeze,
        )
      end

      def for_email(purpose:, surface:, sign_up_flow_ref:, public_id:, sign_up_otp_counter:)
        unless purpose.to_s == "sign_up"
          unless sign_up_flow_ref.nil? && sign_up_otp_counter.nil?
            raise ArgumentError, "signup OTP delivery purpose mismatch"
          end

          return nil
        end

        for_sms(otp_binding: [surface.to_s, "sign_up", sign_up_flow_ref, public_id, sign_up_otp_counter])
      end

      private

      def valid_reference?(value)
        value.is_a?(String) && value.present? && value.length <= 21
      end
    end

    public

    def to_a
      [surface, purpose, flow_ref, contact_ref, counter]
    end

    def email_params
      { sign_up_flow_ref: flow_ref, sign_up_otp_counter: counter }
    end
  end
