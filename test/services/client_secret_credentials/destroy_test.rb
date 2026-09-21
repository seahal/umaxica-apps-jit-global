# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ClientSecretCredentialsDestroyTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_email_statuses, :client_secret_credential_statuses

  setup do
    @user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "scu_#{SecureRandom.hex(4)}",
    )
    ClientEmail.create!(
      user: @user,
      address: "secret_credential-test-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @secret_credential = ClientSecretCredential.create!(
      user: @user,
      name: "Test Secret",
      password: ClientSecretCredential.generate_raw_secret_credential,
      user_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
    )
  end

  test "logically deletes user secret_credential" do
    assert_no_difference("ClientSecretCredential.count") do
      ClientSecretCredentialsDestroy.call(actor: @user, secret_credential: @secret_credential)
    end

    assert_not_equal Retainable::SENTINEL, @secret_credential.reload.discard_at
    assert_operator @secret_credential.purge_eligible_at, :>, Time.current
    assert_equal ClientSecretCredentialStatus::DELETED, @secret_credential.user_identity_secret_status_id
  end

  test "creates ClientChronicle audit when actor is Client" do
    assert_difference("ClientChronicle.count", 2) do
      ClientSecretCredentialsDestroy.call(actor: @user, secret_credential: @secret_credential)
    end

    activity = ClientChronicle.where(event_id: ClientChronicleEvent::USER_SECRET_REMOVED).last
    transition = ClientChronicle.where(event_id: ClientChronicleEvent::CREDENTIAL_SECURITY_TRANSITION).last

    assert_equal ClientChronicleEvent::USER_SECRET_REMOVED, activity.event_id
    assert_equal @user, activity.actor
    assert_equal @secret_credential.id.to_s, activity.subject_id
    assert_equal "credential_security_transition.secret_credential_changed", transition.context.fetch("action")
    assert_equal "secret_credential_changed", transition.context.fetch("reason")
  end
end
