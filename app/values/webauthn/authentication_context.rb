# typed: false
# frozen_string_literal: true

module Webauthn
  # Immutable record of what a verified WebAuthn ceremony actually proved.
  # Consumers must branch on these fields -- never on "a passkey was used" --
  # because only a user-verified assertion supports the AAL2-aligned claim
  # (docs/security/authentication-assurance-levels.md).
  AuthenticationContext =
    Data.define(
      :webauthn_id,
      :user_verified,
      :user_present,
      :sign_count,
      :backup_eligible,
      :backup_state,
      :aaguid,
      :transports,
      :authenticator_attachment,
      :verified_at,
    ) do
      def self.from_credential(credential, transports: nil, authenticator_attachment: nil, verified_at: Time.current)
        authenticator_data = credential.response.authenticator_data

        new(
          webauthn_id: credential.id,
          user_verified: authenticator_data.user_verified?,
          user_present: authenticator_data.user_present?,
          sign_count: credential.sign_count.to_i,
          backup_eligible: authenticator_data.credential_backup_eligible?,
          backup_state: authenticator_data.credential_backed_up?,
          aaguid: extract_aaguid(authenticator_data),
          transports: transports,
          authenticator_attachment: authenticator_attachment,
          verified_at: verified_at,
        )
      end

      def self.extract_aaguid(authenticator_data)
        return nil unless authenticator_data.attested_credential_data_included?

        aaguid = authenticator_data.attested_credential_data.aaguid
        (aaguid == "00000000-0000-0000-0000-000000000000") ? nil : aaguid
      end

      def phishing_resistant? = true

      # AAL2-aligned requires a user-verified, user-present assertion; anything
      # else is single-factor possession proof at best.
      def aal2_aligned? = user_verified && user_present

      private_class_method :extract_aaguid
    end
end
