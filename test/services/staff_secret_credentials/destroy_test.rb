# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsDestroyTest < ActiveSupport::TestCase
  fixtures :operator_statuses, :operator_email_statuses, :operator_secret_credential_statuses, :operators

  setup do
    @staff = operators(:one)
    @token = OperatorToken.create!(authentication_epoch: 0, staff: @staff)
    grant_step_up!
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
      destroy_secret(@secret_credential)
    end

    assert_not_equal Retainable::SENTINEL, @secret_credential.reload.discard_at
    assert_operator @secret_credential.purge_eligible_at, :>, Time.current
    assert_equal OperatorSecretCredentialStatus::DELETED, @secret_credential.staff_secret_status_id
    assert_nil @token.reload.last_step_up_at
  end

  test "creates OperatorChronicle audit" do
    assert_difference("OperatorChronicle.count", 2) do
      destroy_secret(@secret_credential)
    end

    activity = OperatorChronicle.last

    assert_equal OperatorChronicleEvent::STAFF_SECRET_REMOVED, activity.event_id
    assert_equal @staff.id, activity.actor_id
    assert_equal @secret_credential.id, activity.subject_id
    security_transition_events = OperatorChronicle.where(
      event_id: OperatorChronicleEvent::CREDENTIAL_SECURITY_TRANSITION,
    )

    assert_predicate security_transition_events, :exists?
  end

  test "the same Step-Up cannot delete a second Secret" do
    destroy_secret(@secret_credential)
    second = OperatorSecretCredential.create!(
      staff: @staff, name: "Second Secret", password: OperatorSecretCredential.generate_raw_secret_credential,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )

    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) { destroy_secret(second) }
    assert_predicate second.reload, :persisted?
    assert_not second.deleted?
  end

  private

  def destroy_secret(secret)
    OperatorSecretCredentialsDestroy.call(
      actor: @staff, secret_credential: secret,
      step_up_token: @token, step_up_requirement: step_up_requirement,
    )
  end

  def grant_step_up!
    @token.update!(
      last_step_up_at: OperatorToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:org",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
  end

  def step_up_requirement
    StepUpRequirement.new(
      scope: "settings_secret_credential", step_up_required: true, allowed_methods: [:passkey],
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, purpose: "step_up", audience: "step_up:org",
      session_binding: @token.public_id, token_binding: @token.public_id, require_session_binding: true,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: @staff.public_id, resource_ref: nil, tenant_ref: nil,
    )
  end
end
