# frozen_string_literal: true

TelephoneSignUpOtpDeliveryBindingValue =
  Data.define(:surface, :purpose, :flow_ref, :transaction_ref, :generation) do
    class << self
      public

      def for_sms(otp_binding:)
        unless otp_binding.is_a?(Array) && otp_binding.length == 5
          raise ArgumentError, "Telephone signup delivery requires a five-field binding"
        end

        surface, purpose, flow_ref, transaction_ref, generation = otp_binding
        unless %w(app com).include?(surface) && purpose == "sign_up" &&
            flow_ref.is_a?(String) && flow_ref.encoding.ascii_compatible? && flow_ref.valid_encoding? &&
            flow_ref.match?(/\A[A-Za-z0-9_-]{1,21}\z/)
          raise ArgumentError, "invalid Telephone signup delivery binding"
        end

        [transaction_ref, generation].each do |reference|
          unless reference.is_a?(String) && reference.encoding.ascii_compatible? && reference.valid_encoding? &&
              reference.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
            raise ArgumentError, "Telephone signup delivery UUID references required"
          end
        end
        new(
          surface: surface.dup.freeze, purpose: purpose.dup.freeze, flow_ref: flow_ref.dup.freeze,
          transaction_ref: transaction_ref.dup.freeze, generation: generation.dup.freeze,
        )
      end
    end

    public

    def to_a = [surface, purpose, flow_ref, transaction_ref, generation]
  end
