# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"

class ClientCoverageTest < ActiveSupport::TestCase
  include ExternalIdentityTestHelper

  setup do
    ClientStatus.find_or_create_by!(id: 1)
    ClientVisibility.find_or_create_by!(id: 1)
    @user = Client.create!(status_id: 1, visibility_id: 1)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientTotpCredentialStatus.find_or_create_by!(id: ClientTotpCredentialStatus::ACTIVE)
  end

  test "totp_enabled?" do
    assert_not @user.totp_enabled?
    ClientTotpCredential.create!(
      user: @user,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )

    assert_predicate @user, :totp_enabled?

    @user.client_totp_credentials.load

    assert_predicate @user, :totp_enabled?
  end

  test "staff? and user? predicates" do
    assert_not @user.staff?
    assert_predicate @user, :user?
  end

  test "client_google_identities shim" do
    assert_empty @user.client_google_identities
    google = create_active_external_identity(client: @user, provider: "google", subject: "u")

    assert_equal [google], @user.client_google_identities
  end

  test "verified_email? and verified_telephone?" do
    assert_not @user.verified_email?
    ClientEmail.create!(user: @user, address: "v@example.com", user_email_status_id: ClientEmailStatus::VERIFIED)
      .finalize_binding!

    assert_predicate @user, :verified_email?

    assert_not @user.verified_telephone?
    ClientTelephone.create!(
      user: @user, number: "+819012345678", user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    ).finalize_binding!

    assert_predicate @user, :verified_telephone?
  end

  test "withdrawal and deactivation predicates" do
    assert_not @user.withdrawal_started?
    assert_not @user.deactivated?
    assert_not @user.withdrawal_in_progress?

    @user.update!(withdrawal_started_at: Time.current)

    assert_predicate @user, :withdrawal_started?
    assert_predicate @user, :withdrawal_in_progress?

    @user.update!(deactivated_at: Time.current)

    assert_predicate @user, :deactivated?
    assert_predicate @user, :withdrawal_in_progress?
  end

  test "active_social_provider?" do
    assert_not @user.active_social_provider?("google")
    google = create_active_external_identity(client: @user, provider: "google", subject: "g")

    assert @user.active_social_provider?("google")

    assert_not @user.active_social_provider?("apple")
    google.release!

    assert_not @user.active_social_provider?("google")
    create_active_external_identity(client: @user, provider: "apple", subject: "a")

    assert @user.active_social_provider?("apple")

    assert_not @user.active_social_provider?("unknown")
  end

  test "ClientEmail verification tokens" do
    email = ClientEmail.create!(user: @user, address: "token@example.com", user_email_status_id: 1)
    raw = email.generate_verification_token

    assert_not_nil raw
    assert email.verify_verification_token(raw)
    assert_not email.verify_verification_token("wrong")
  end
end
