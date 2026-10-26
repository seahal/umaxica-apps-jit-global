# typed: false
# frozen_string_literal: true

module Webauthn
  # Creates authentication options and verifies assertions for one surface's
  # relying party against a stored credential. The user-verification
  # requirement per ceremony purpose comes from Webauthn::UvPolicy.
  #
  # Server-side guarantees, independent of what the client requested:
  # - the signature verifies against the stored public key (gem)
  # - RP ID hash, clientData type, and origin match the surface config (gem)
  # - under a required UV policy the assertion is user-present AND
  #   user-verified - UV=false is rejected, so a successful verification
  #   captures user-verification evidence without assigning an AAL
  # - a sign-count regression (cloned-authenticator signal) is rejected by the
  #   gem via WebAuthn::SignCountVerificationError
  class AssertionVerifier
    class VerificationError < StandardError; end

    class UserVerificationRequiredError < VerificationError; end

    class UserPresenceRequiredError < VerificationError; end

    def self.options_for(config:, allow_ids:, purpose:)
      config.relying_party.options_for_authentication(
        allow: allow_ids,
        user_verification: UvPolicy.for(purpose).client_value,
      )
    end

    def self.verify!(credential_params:, challenge:, config:, public_key:, sign_count:, purpose:,
                     expected_user_handle: nil)
      policy = UvPolicy.for(purpose)
      credential =
        begin
          WebAuthn::Credential.from_get(credential_params, relying_party: config.relying_party)
        rescue ArgumentError
          raise VerificationError, "assertion encoding is invalid"
        end
      credential.verify(
        challenge,
        public_key: public_key,
        sign_count: sign_count,
        user_verification: policy.enforce_server_side?,
      )

      verify_user_handle!(credential, expected_user_handle) if expected_user_handle

      authenticator_data = credential.response.authenticator_data
      if policy.enforce_server_side? && !authenticator_data.user_verified?
        raise UserVerificationRequiredError, "assertion is not user-verified"
      end
      raise UserPresenceRequiredError, "assertion is not user-present" unless authenticator_data.user_present?

      AuthenticationContext.from_credential(credential)
    rescue OpenSSL::PKey::PKeyError
      raise VerificationError, "assertion signature verification failed"
    end

    def self.verify_user_handle!(credential, expected_user_handle)
      user_handle = credential.response.user_handle
      return if user_handle.nil?

      expected = expected_user_handle.to_s.b
      actual = user_handle.to_s.b
      matches = expected.bytesize == actual.bytesize && ActiveSupport::SecurityUtils.secure_compare(expected, actual)
      raise VerificationError, "returned user handle does not match the credential owner" unless matches
    end
    private_class_method :verify_user_handle!
  end
end
