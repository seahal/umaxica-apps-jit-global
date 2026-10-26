# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsUpdateTest < ActiveSupport::TestCase
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

  test "updates secret_credential name" do
    params = { name: "Updated Name" }

    result = update_secret(params)

    assert_equal "Updated Name", result.secret_credential.name
  end

  test "updates secret_credential status to revoked" do
    params = { enabled: false }

    result = update_secret(params)

    assert_predicate result.secret_credential, :revoked?
    assert_nil @token.reload.last_step_up_at
    security_transition_events = OperatorChronicle.where(
      event_id: OperatorChronicleEvent::CREDENTIAL_SECURITY_TRANSITION,
    )

    assert_predicate security_transition_events, :exists?
  end

  test "updates secret_credential status to active" do
    @secret_credential.update!(staff_secret_status_id: OperatorSecretCredentialStatus::REVOKED)
    params = { enabled: true }

    result = update_secret(params)

    assert_predicate result.secret_credential, :active?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  updated-name-with-spaces  " }

    result = update_secret(params)

    assert_equal "updated-name-with-spaces", result.secret_credential.name
  end

  test "does not update name when not present in params" do
    original_name = @secret_credential.name
    params = { enabled: false }

    result = update_secret(params)

    assert_equal original_name, result.secret_credential.name
  end

  test "does not update status when not present in params" do
    params = { name: "New Name" }
    original_status = @secret_credential.staff_secret_status_id

    result = update_secret(params)

    assert_equal original_status, result.secret_credential.staff_secret_status_id
  end

  test "creates OperatorChronicle audit" do
    params = { name: "Audit Test" }

    assert_difference("OperatorChronicle.count", 1) do
      update_secret(params)
    end

    activity = OperatorChronicle.last

    assert_equal OperatorChronicleEvent::STAFF_SECRET_UPDATED, activity.event_id
  end

  test "a no-op update retains Step-Up" do
    evidence = @token.reload.attributes

    update_secret({ name: @secret_credential.name })

    assert_equal evidence, @token.reload.attributes
  end

  test "the same Step-Up cannot update a second Secret" do
    update_secret({ name: "First Name" })
    second = OperatorSecretCredential.create!(
      staff: @staff, name: "Second Secret", password: OperatorSecretCredential.generate_raw_secret_credential,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )

    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
      OperatorSecretCredentialsUpdate.call(
        actor: @staff, secret_credential: second, params: { name: "Second Name" },
        step_up_token: @token, step_up_requirement: step_up_requirement,
      )
    end
    assert_equal "Second Secret", second.reload.name
  end

  private

  def update_secret(params)
    OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: params,
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
