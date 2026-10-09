# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"
# require "helpers/global_test_support"

class AuthMethodGuardTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  fixtures :clients

  setup do
    @user = clients(:one)
    @user.client_external_identities.delete_all
    ClientEmail.where(user: @user).delete_all
    ClientTelephone.where(user: @user).delete_all
    ClientSecretCredential.where(client: @user).delete_all
    ClientPasskey.where(user: @user).delete_all
    ClientTotpCredential.where(user: @user).delete_all
  end

  test "inventory exposes explicit sign-in and step-up capabilities for representative partitions" do
    assert_empty AuthenticationCredentialInventory.call(@user).usable_sign_in_capabilities

    create_active_external_identity(client: @user, provider: "google")

    assert_equal [:google], AuthenticationCredentialInventory.call(@user).usable_sign_in_capabilities

    begin
      fv5017 = @user
      fv5016 = "test#{SecureRandom.hex(4)}@example.com"
      ClientEmail.create!(
        user: fv5017,
        address: fv5016,
        user_email_status_id: ClientEmailStatus::VERIFIED,
        binding_finalized_at: ClientEmail.database_now,
      )
    end
    inventory = AuthenticationCredentialInventory.call(@user)

    assert_equal %i(google email_otp).sort, inventory.usable_sign_in_capabilities.sort
    assert_includes inventory.usable_step_up_capabilities, :email_otp
  end

  test "unverified email is not an explicit capability" do
    ClientEmail.create!(
      user: @user,
      address: "unverified#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    inventory = AuthenticationCredentialInventory.call(@user)

    assert_empty inventory.usable_sign_in_capabilities
    assert_empty inventory.contact_identifiers
  end

  test "confirmed app Secret without a bound contact is not a sign-in capability" do
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: @user, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "synthetic-browser", planned_count: 1, expires_at: now + 1.minute,
      presented_at: now, confirmed_at: now,
    )
    raw = SecureRandom.base58(32)
    credential = ClientSecretCredential.create!(
      client: @user, issuance: issuance, name: "Secret", password: raw,
      confirmed_at: now,
    )
    inventory = AuthenticationCredentialInventory.call(@user)

    assert_empty inventory.sign_in_methods
    assert_empty inventory.step_up_methods
    assert_empty inventory.contact_identifiers
    assert_empty inventory.usable_sign_in_capabilities
    assert_empty inventory.usable_step_up_capabilities
    assert AuthMethodGuard.can_remove_secret_credential?(@user, credential)
  end

  test "verified telephone is a contact and step-up selector but not sign-in" do
    user = @user

    begin
      fv5015 = user
      fv5014 = "+819012345678"
      ClientTelephone.create!(
        user: fv5015,
        number: fv5014,
        user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
        binding_finalized_at: ClientTelephone.database_now,
      )
    end
    inventory = AuthenticationCredentialInventory.call(user)

    assert_empty inventory.usable_sign_in_capabilities
    assert_equal [:telephone], inventory.contact_identifiers
  end

  test "unverified telephone is not an explicit capability" do
    user = @user

    ClientTelephone.create!(
      user: user,
      number: "+819012345678",
      user_identity_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
    )

    inventory = AuthenticationCredentialInventory.call(user)

    assert_empty inventory.usable_sign_in_capabilities
    assert_empty inventory.contact_identifiers
  end

  test "inventory exclusion removes only the excluded effective identity" do
    google = create_active_external_identity(client: @user, provider: "google")
    begin
      fv5013 = @user
      fv5012 = "test#{SecureRandom.hex(4)}@example.com"
      ClientEmail.create!(
        user: fv5013,
        address: fv5012,
        user_email_status_id: ClientEmailStatus::VERIFIED,
        binding_finalized_at: ClientEmail.database_now,
      )
    end

    inventory = AuthenticationCredentialInventory.call(@user, excluding: google)

    assert_equal [:email_otp], inventory.usable_sign_in_capabilities
  end

  test "inactive Google identity is not an explicit capability" do
    user = @user

    create_active_external_identity(client: user, provider: "google", state: "consent_revoked")

    assert_empty AuthenticationCredentialInventory.call(user).usable_sign_in_capabilities
  end

  test "can_remove_telephone does not require a second contact when no sign-in path depends on it" do
    telephone =
      begin
        fv5011 = @user
        fv5010 = "+819012300001"
        ClientTelephone.create!(
          user: fv5011,
          number: fv5010,
          user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
          binding_finalized_at: ClientTelephone.database_now,
        )
      end

    assert AuthMethodGuard.can_remove_telephone?(@user, telephone)

    begin
      fv5009 = @user
      fv5008 = "telephone-removal#{SecureRandom.hex(4)}@example.com"
      ClientEmail.create!(
        user: fv5009,
        address: fv5008,
        user_email_status_id: ClientEmailStatus::VERIFIED,
        binding_finalized_at: ClientEmail.database_now,
      )
    end

    assert AuthMethodGuard.can_remove_telephone?(@user, telephone)
  end

  test "can_remove_passkey preserves the last usable sign-in path with zero contacts" do
    passkey =
      begin
        fv5007 = @user
        fv5006 = fv5007.client_passkeys.new(
          webauthn_id: "auth_guard_passkey_#{SecureRandom.hex(4)}",
          external_id: SecureRandom.uuid,
          public_key: "public_key",
          sign_count: 0,
          description: "auth guard passkey",
          status_id: ClientPasskeyStatus::ACTIVE,
          uv_verified_at: Time.current,
        )
        fv5006.save!(validate: false)
        fv5006
      end

    assert_not AuthMethodGuard.can_remove_passkey?(@user, passkey)
  end

  test "can_remove_external_identity preserves a social-only sign-in path" do
    identity = create_active_external_identity(client: @user, provider: "google")

    assert_not AuthMethodGuard.can_remove_external_identity?(@user, identity)
  end

  test "can_remove_email preserves sign-in and UV step-up capabilities" do
    email =
      begin
        fv5005 = @user
        fv5004 = "email-removal#{SecureRandom.hex(4)}@example.com"
        ClientEmail.create!(
          user: fv5005,
          address: fv5004,
          user_email_status_id: ClientEmailStatus::VERIFIED,
          binding_finalized_at: ClientEmail.database_now,
        )
      end
    passkey = @user.client_passkeys.new(
      webauthn_id: "auth_guard_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "auth guard passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
      uv_verified_at: Time.current,
    )
    passkey.save!(validate: false)

    assert AuthMethodGuard.can_remove_email?(@user, email)
  end

  test "can_remove_totp preserves the last usable step-up capability" do
    totp = ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )

    assert_not AuthMethodGuard.can_remove_totp?(@user, totp)

    passkey = @user.client_passkeys.new(
      webauthn_id: "auth_guard_totp_passkey_#{SecureRandom.hex(4)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key",
      sign_count: 0,
      description: "auth guard totp passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
      uv_verified_at: Time.current,
    )
    passkey.save!(validate: false)

    assert AuthMethodGuard.can_remove_totp?(@user, totp)
  end

  test "T15 table keeps explicit sign-in and step-up capabilities across removal partitions" do
    expected = {
      passkey_with_zero_contacts: false,
      secret_with_zero_identifiers: true,
      social_only: false,
      no_step_up_method: false,
      last_method: false,
    }

    actual = {}
    expected.each_key do |partition|
      @user.client_external_identities.delete_all
      ClientEmail.where(user: @user).delete_all
      ClientTelephone.where(user: @user).delete_all
      ClientSecretCredential.where(client: @user).delete_all
      ClientSecretIssuance.where(client: @user).delete_all
      ClientPasskey.where(user: @user).delete_all
      ClientTotpCredential.where(user: @user).delete_all

      actual[partition] =
        case partition
        when :passkey_with_zero_contacts
          passkey =
            begin
              fv5003 = @user
              fv5002 = fv5003.client_passkeys.new(
                webauthn_id: "auth_guard_passkey_#{SecureRandom.hex(4)}",
                external_id: SecureRandom.uuid,
                public_key: "public_key",
                sign_count: 0,
                description: "auth guard passkey",
                status_id: ClientPasskeyStatus::ACTIVE,
                uv_verified_at: Time.current,
              )
              fv5002.save!(validate: false)
              fv5002
            end
          inventory = AuthenticationCredentialInventory.call(@user)

          assert_equal [:passkey], inventory.usable_sign_in_capabilities, partition
          assert_empty inventory.contact_identifiers, partition
          AuthMethodGuard.can_remove_passkey?(@user, passkey)
        when :secret_with_zero_identifiers
          now = Client.database_now
          issuance = ClientSecretIssuance.create!(
            client: @user, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
            browser_session_ref: "synthetic-browser", planned_count: 1, expires_at: now + 1.minute,
            presented_at: now, confirmed_at: now,
          )
          secret = ClientSecretCredential.create!(
            client: @user, issuance: issuance, name: "Secret", password: SecureRandom.base58(32),
            confirmed_at: now,
          )
          inventory = AuthenticationCredentialInventory.call(@user)

          assert_empty inventory.usable_sign_in_capabilities, partition
          assert_empty inventory.usable_step_up_capabilities, partition
          AuthMethodGuard.can_remove_secret_credential?(@user, secret)
        when :social_only
          identity = create_active_external_identity(client: @user, provider: "google")
          inventory = AuthenticationCredentialInventory.call(@user)

          assert_equal [:google], inventory.usable_sign_in_capabilities, partition
          assert_empty inventory.usable_step_up_capabilities, partition
          AuthMethodGuard.can_remove_external_identity?(@user, identity)
        when :no_step_up_method
          email =
            begin
              fv5001 = @user
              fv5000 = "test#{SecureRandom.hex(4)}@example.com"
              ClientEmail.create!(
                user: fv5001,
                address: fv5000,
                user_email_status_id: ClientEmailStatus::VERIFIED,
                binding_finalized_at: ClientEmail.database_now,
              )
            end
          email.update!(step_up_otp_locked_until: 1.hour.from_now)
          inventory = AuthenticationCredentialInventory.call(@user)

          assert_equal [:email_otp], inventory.usable_sign_in_capabilities, partition
          assert_empty inventory.usable_step_up_capabilities, partition
          AuthMethodGuard.can_remove_email?(@user, email)
        when :last_method
          totp = ClientTotpCredential.create!(
            user: @user, private_key: ROTP::Base32.random_base32,
            user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
            last_otp_at: Time.zone.at(0),
          )
          inventory = AuthenticationCredentialInventory.call(@user)

          assert_empty inventory.usable_sign_in_capabilities, partition
          assert_equal [:totp], inventory.usable_step_up_capabilities, partition
          AuthMethodGuard.can_remove_totp?(@user, totp)
        else
          raise RuntimeError, "unhandled T15 partition: #{partition}"
        end
    end

    assert_equal expected, actual
  end

  private
end
