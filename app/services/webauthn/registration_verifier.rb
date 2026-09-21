# typed: false
# frozen_string_literal: true

module Webauthn
  # Creates registration options and verifies attestation responses for one
  # surface's relying party. The user-verification requirement comes from
  # Webauthn::UvPolicy (registration is "required"): every credential this
  # application registers must satisfy the server UV policy, and a
  # UV=false attestation is rejected even if the authenticator claims success.
  class RegistrationVerifier
    class VerificationError < StandardError; end

    class UserVerificationRequiredError < VerificationError; end

    class UserPresenceRequiredError < VerificationError; end

    RESIDENT_KEY_BY_SURFACE = {
      app: "required",
      com: "required",
      org: "discouraged",
    }.freeze
    ATTESTATION = "none"

    def self.options_for(config:, user_id:, user_name:, exclude_ids: [], surface: :org)
      config.relying_party.options_for_registration(
        user: { id: user_id, name: user_name, display_name: user_name },
        exclude: exclude_ids,
        authenticator_selection: {
          resident_key: resident_key_for(surface),
          user_verification: UvPolicy.for(:registration).client_value,
        },
        attestation: ATTESTATION,
      )
    end

    def self.resident_key_for(surface)
      RESIDENT_KEY_BY_SURFACE.fetch(Webauthn::Surface.for(surface).key)
    end
    private_class_method :resident_key_for

    def self.verify!(credential_params:, challenge:, config:)
      policy = UvPolicy.for(:registration)
      credential = WebAuthn::Credential.from_create(credential_params, relying_party: config.relying_party)
      credential.verify(challenge, user_verification: policy.enforce_server_side?)

      authenticator_data = credential.response.authenticator_data
      if policy.enforce_server_side? && !authenticator_data.user_verified?
        raise UserVerificationRequiredError, "attestation is not user-verified"
      end
      raise UserPresenceRequiredError, "attestation is not user-present" unless authenticator_data.user_present?

      AuthenticationContext.from_credential(
        credential,
        transports: credential_transports(credential),
        authenticator_attachment: credential.authenticator_attachment,
      )
    end

    # transports is an optional client-reported hint (WebAuthn L3
    # getTransports()); absence is normal and never fails the ceremony.
    def self.credential_transports(credential)
      transports = credential.response.transports
      transports.presence && Array(transports).map(&:to_s)
    end
    private_class_method :credential_transports
  end
end
