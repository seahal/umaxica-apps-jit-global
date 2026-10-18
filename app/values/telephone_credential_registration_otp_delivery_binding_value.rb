# frozen_string_literal: true

TelephoneCredentialRegistrationOtpDeliveryBindingValue =
  Data.define(:surface, :purpose, :transaction_ref, :candidate_ref, :generation) do
    class << self
      public

      def for_sms(otp_binding:)
        unless otp_binding.is_a?(Array) && otp_binding.length == 5
          raise ArgumentError, "Telephone registration requires a five-field delivery binding"
        end

        surface, purpose, transaction_ref, candidate_ref, generation = otp_binding
        unless %w(app com org).include?(surface) && purpose == "credential_registration" &&
            candidate_ref.is_a?(String) && candidate_ref.encoding.ascii_compatible? && candidate_ref.valid_encoding? &&
            candidate_ref.match?(/\A[A-Za-z0-9_-]{1,21}\z/)
          raise ArgumentError, "invalid Telephone registration delivery binding"
        end
        if surface == "org" && !candidate_ref.match?(/\A[A-Za-z0-9_-]{21}\z/)
          raise ArgumentError, "ORG Telephone registration requires an opaque candidate ID"
        end

        unless valid_reference?(
          transaction_ref,
          /\A(?:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|[A-Za-z0-9_-]{21})\z/,
        )
          raise ArgumentError, "Telephone registration delivery transaction reference required"
        end
        unless valid_reference?(generation, /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
          raise ArgumentError, "Telephone registration delivery generation UUID required"
        end

        new(
          surface: surface.dup.freeze, purpose: purpose.dup.freeze, transaction_ref: transaction_ref.dup.freeze,
          candidate_ref: candidate_ref.dup.freeze, generation: generation.dup.freeze,
        )
      end

      private

      def valid_reference?(value, pattern)
        value.is_a?(String) && value.encoding.ascii_compatible? && value.valid_encoding? && value.match?(pattern)
      end
    end

    public

    def to_a = [surface, purpose, transaction_ref, candidate_ref, generation]
  end
