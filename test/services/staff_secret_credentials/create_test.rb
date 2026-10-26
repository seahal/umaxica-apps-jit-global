# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsCreateTest < ActiveSupport::TestCase
  fixtures :operator_statuses, :operator_email_statuses, :operators

  setup do
    @staff = operators(:one)
    @token = OperatorToken.create!(authentication_epoch: 0, staff: @staff)
    grant_step_up!
    OperatorEmail.create!(
      staff: @staff,
      address: "secret_credential-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
  end

  test "creates secret_credential with auto-generated raw secret_credential" do
    params = { name: "api-key-1", enabled: true }

    result = create_secret(params)

    assert_predicate result.secret_credential, :persisted?
    assert_predicate result.raw_secret_credential, :present?
    assert_equal "api-key-1", result.secret_credential.name
    assert_predicate result.secret_credential, :active?
    assert_nil @token.reload.last_step_up_at
  end

  test "creates secret_credential with enabled=false as revoked" do
    params = { name: "disabled-key", enabled: false }

    result = create_secret(params)

    assert_predicate result.secret_credential, :revoked?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  test-name-with-spaces  ", enabled: true }

    result = create_secret(params)

    assert_equal "test-name-with-spaces", result.secret_credential.name
  end

  test "a failed creation retains Step-Up" do
    assert_raises(ActiveRecord::RecordInvalid) { create_secret({ name: "", enabled: true }) }
    assert_equal "settings_secret_credential", @token.reload.last_step_up_scope
  end

  private

  def create_secret(params)
    OperatorSecretCredentialsCreate.call(
      actor: @staff, staff: @staff, params: params,
      step_up_token: @token, step_up_requirement: step_up_requirement, step_up_bootstrap: false,
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
