# frozen_string_literal: true

CredentialRegistrationOtpSessionValue =
  Data.define(:root_ref, :browser_digest) do
    class << self
      public

      def for(surface:, channel:, transaction_ref:, root_ref:, browser_nonce:)
        unless %w(app com org).include?(surface) && %i(email telephone).include?(channel)
          raise ArgumentError, "unsupported registration session realm or channel"
        end
        unless ascii_match?(
          transaction_ref,
          /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/,
        )
          raise ArgumentError, "registration transaction UUID required"
        end
        raise ArgumentError, "registration Root reference required" unless ascii_match?(
          root_ref,
          /\A[A-Za-z0-9_-]{1,21}\z/,
        )
        unless ascii_match?(browser_nonce, /\A[A-Za-z0-9_-]{43}\z/)
          raise ArgumentError, "registration browser nonce required"
        end

        digest = Digest::SHA256.hexdigest(
          JSON.generate(["credential_registration", surface, channel, transaction_ref, root_ref, browser_nonce]),
        )
        new(root_ref: root_ref.dup.freeze, browser_digest: digest.freeze)
      end

      def load(session_ref:)
        unless session_ref.is_a?(String) && session_ref.encoding.ascii_compatible? && session_ref.valid_encoding?
          raise ArgumentError, "registration session tuple required"
        end

        tuple = JSON.parse(session_ref)
        unless tuple.is_a?(Array) && tuple.length == 3 && tuple[0].is_a?(Integer) && tuple[0] == 1 &&
            ascii_match?(tuple[1], /\A[A-Za-z0-9_-]{1,21}\z/) && ascii_match?(tuple[2], /\A[0-9a-f]{64}\z/)
          raise ArgumentError, "invalid registration session tuple"
        end

        new(root_ref: tuple[1].freeze, browser_digest: tuple[2].freeze)
      rescue JSON::ParserError
        raise ArgumentError, "malformed registration session tuple"
      end

      private

      def ascii_match?(value, pattern)
        value.is_a?(String) && value.encoding.ascii_compatible? && value.valid_encoding? && value.match?(pattern)
      end
    end

    public

    def dump = JSON.generate([1, root_ref, browser_digest])

    def inspect = "#<CredentialRegistrationOtpSessionValue root_ref=[FILTERED] browser_digest=[FILTERED]>"
  end
