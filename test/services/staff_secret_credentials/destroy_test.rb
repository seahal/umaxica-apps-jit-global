# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsDestroyTest < ActiveSupport::TestCase
  fixtures :operator_statuses, :operator_email_statuses, :operator_secret_credential_statuses, :operators

  setup do
    @staff = operators(:one)
    OperatorEmail.create!(
      staff: @staff,
      address: "secret_credential-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
    @secret_credential = OperatorSecretCredential.create!(
      staff: @staff,
      name: "Test Secret",
      password: OperatorSecretCredential.generate_raw_secret_credential,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
  end

  test "logically deletes staff secret_credential" do
    assert_no_difference("OperatorSecretCredential.count") do
      OperatorSecretCredentialsDestroy.call(actor: @staff, secret_credential: @secret_credential)
    end

    assert_not_equal Retainable::SENTINEL, @secret_credential.reload.discard_at
    assert_operator @secret_credential.purge_eligible_at, :>, Time.current
    assert_equal OperatorSecretCredentialStatus::DELETED, @secret_credential.staff_secret_status_id
  end

  test "creates OperatorChronicle audit" do
    assert_difference("OperatorChronicle.count", 1) do
      OperatorSecretCredentialsDestroy.call(actor: @staff, secret_credential: @secret_credential)
    end

    activity = OperatorChronicle.last

    assert_equal OperatorChronicleEvent::STAFF_SECRET_REMOVED, activity.event_id
    assert_equal @staff, activity.actor
    assert_equal @secret_credential.id, activity.subject_id
  end
end
