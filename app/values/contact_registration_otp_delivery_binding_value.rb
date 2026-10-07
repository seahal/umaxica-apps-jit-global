# frozen_string_literal: true

ContactRegistrationOtpDeliveryBindingValue =
  Data.define(:surface, :purpose, :flow_ref, :contact_ref, :counter) do
    class << self
      public

      def for_sms(otp_binding:)
        unless otp_binding.is_a?(Array) && otp_binding.length == 5
          raise ArgumentError, "registration OTP delivery requires a five-field binding"
        end

        surface, purpose, flow_ref, contact_ref, counter = otp_binding
        unless %w(app com).include?(surface) && purpose == "credential_registration" &&
            flow_ref.is_a?(String) &&
            flow_ref.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/) &&
            contact_ref.is_a?(String) && contact_ref.match?(/\A[A-Za-z0-9_-]{1,21}\z/) &&
            counter.is_a?(String) && counter.match?(/\A(?:0|[1-9][0-9]{0,19})\z/) && counter.to_i < (1 << 64)
          raise ArgumentError, "invalid registration OTP delivery binding"
        end

        new(
          surface: surface.dup.freeze, purpose: purpose.dup.freeze,
          flow_ref: flow_ref.dup.freeze, contact_ref: contact_ref.dup.freeze, counter: counter.dup.freeze,
        )
      end

      def for_email(purpose:, surface:, contact_ceremony_transaction_ref:, public_id:, contact_otp_counter:)
        unless purpose == "credential_registration"
          unless contact_ceremony_transaction_ref.nil? && contact_otp_counter.nil?
            raise ArgumentError, "registration OTP delivery purpose mismatch"
          end

          return nil
        end

        for_sms(otp_binding: [surface, purpose, contact_ceremony_transaction_ref, public_id, contact_otp_counter])
      end
    end

    public

    def to_a
      [surface, purpose, flow_ref, contact_ref, counter]
    end

    def email_params
      { contact_ceremony_transaction_ref: flow_ref, contact_otp_counter: counter }
    end
  end
