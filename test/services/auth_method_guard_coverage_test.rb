# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthMethodGuardCoverageTest < ActiveSupport::TestCase
  test "public removal guards preserve real sign-in and step-up capabilities with exclusions" do
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    email = actor.client_emails.create!(
      address: "removal-#{SecureRandom.hex(8)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      binding_finalized_at: ClientEmail.database_now,
    )
    telephone = actor.client_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      binding_finalized_at: ClientTelephone.database_now,
    )
    totp = actor.client_totp_credentials.create!(
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    passkey = actor.client_passkeys.create!(
      webauthn_id: SecureRandom.urlsafe_base64(32), external_id: SecureRandom.uuid,
      public_key: "public-key-fixture", sign_count: 0, description: "removal guard",
      status_id: ClientPasskeyStatus::ACTIVE, uv_verified_at: ClientPasskey.database_now,
    )

    assert AuthMethodGuard.can_remove_passkey?(actor, passkey)
    assert AuthMethodGuard.can_remove_email?(actor, email)
    assert AuthMethodGuard.can_remove_telephone?(actor, telephone)
    assert AuthMethodGuard.can_remove_totp?(actor, totp)

    email.release_binding!(at: ClientEmail.database_now)
    totp.destroy!

    assert_not AuthMethodGuard.can_remove_passkey?(actor, passkey)
    assert AuthMethodGuard.can_remove_telephone?(actor, telephone)
    assert_equal [:passkey], AuthenticationCredentialInventory.call(actor).usable_sign_in_capabilities
  end
end
