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
    ClientSecretCredential.where(user: @user).delete_all
    ClientPasskey.where(user: @user).delete_all
    ClientTotpCredential.where(user: @user).delete_all
  end

  test "remaining_count returns 0 for user with no methods" do
    user = @user

    assert_equal 0, AuthMethodGuard.remaining_count(user)
  end

  test "remaining_count includes active Google identity" do
    user = @user

    create_active_external_identity(client: user, provider: "google")

    assert_equal 1, AuthMethodGuard.remaining_count(user)
  end

  test "remaining_count includes active Apple identity" do
    user = @user

    create_active_external_identity(client: user, provider: "apple")

    assert_equal 1, AuthMethodGuard.remaining_count(user)
  end

  test "remaining_count includes verified emails" do
    user = @user

    ClientEmail.create!(
      user: user,
      address: "test#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal 1, AuthMethodGuard.remaining_count(user)
  end

  test "remaining_count excludes unverified emails" do
    user = @user

    ClientEmail.create!(
      user: user,
      address: "unverified#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )

    assert_equal 0, AuthMethodGuard.remaining_count(user)
  end

  test "active legacy secret credentials do not count as AAL1 sign-in methods" do
    ClientSecretCredentialStatus.find_or_create_by!(id: ClientSecretCredentialStatus::ACTIVE)
    ClientSecretCredentialKind.find_or_create_by!(id: ClientSecretCredentialKind::LOGIN)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientEmail.create!(
      user: @user,
      address: "legacy-secret-inventory-#{SecureRandom.hex(4)}@example.test",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    ClientSecretCredential.issue!(
      name: "Legacy login secret",
      user: @user,
      user_secret_kind_id: ClientSecretCredentialKind::LOGIN,
    )

    assert_equal [:email_otp], AuthenticationCredentialInventory.call(@user).aal1_methods
  end

  test "remaining_count excludes verified telephones because telephone is not aal1" do
    user = @user

    ClientTelephone.create!(
      user: user,
      number: "+819012345678",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_equal 0, AuthMethodGuard.remaining_count(user)
    assert_equal 1, AuthenticationCredentialInventory.call(user).contact_identifier_count
  end

  test "remaining_count excludes unverified telephones" do
    user = @user

    ClientTelephone.create!(
      user: user,
      number: "+819012345678",
      user_identity_telephone_status_id: ClientTelephoneStatus::UNVERIFIED,
    )

    assert_equal 0, AuthMethodGuard.remaining_count(user)
  end

  test "remaining_count excludes specified identity" do
    user = @user

    google = create_active_external_identity(client: user, provider: "google")

    assert_equal 0, AuthMethodGuard.remaining_count(user, excluding: google)
  end

  test "last_method returns true when only one method exists" do
    user = @user

    google = create_active_external_identity(client: user, provider: "google")

    assert_equal 1, AuthMethodGuard.remaining_count(user)
    assert AuthMethodGuard.last_method?(user, excluding: google)
  end

  test "last_method returns false when multiple methods exist" do
    user = @user

    create_active_external_identity(client: user, provider: "google")

    ClientEmail.create!(
      user: user,
      address: "test#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_not AuthMethodGuard.last_method?(user)
  end

  test "remaining_count counts multiple methods correctly" do
    user = @user

    create_active_external_identity(client: user, provider: "google")
    create_active_external_identity(client: user, provider: "apple")

    ClientEmail.create!(
      user: user,
      address: "test#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert_equal 3, AuthMethodGuard.remaining_count(user)
  end

  test "remaining_count excludes inactive Google identity" do
    user = @user

    create_active_external_identity(client: user, provider: "google", state: "consent_revoked")

    assert_equal 0, AuthMethodGuard.remaining_count(user)
  end

  test "can_remove_telephone preserves at least one contact identifier" do
    telephone = ClientTelephone.create!(
      user: @user,
      number: "+819012300001",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert_not AuthMethodGuard.can_remove_telephone?(@user, telephone)

    ClientEmail.create!(
      user: @user,
      address: "telephone-removal#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )

    assert AuthMethodGuard.can_remove_telephone?(@user, telephone)
  end

  test "can_remove_email preserves contact aal1 and aal2 dimensions" do
    email = ClientEmail.create!(
      user: @user,
      address: "email-removal#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
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

    assert_not AuthMethodGuard.can_remove_email?(@user, email)

    ClientTelephone.create!(
      user: @user,
      number: "+819012300002",
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )

    assert AuthMethodGuard.can_remove_email?(@user, email)
  end

  test "can_remove_totp preserves at least one aal2 method" do
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
end
