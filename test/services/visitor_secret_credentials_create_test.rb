# typed: false
# frozen_string_literal: true

require "test_helper"

class VisitorSecretCredentialsCreateTest < ActiveSupport::TestCase
  setup do
    ensure_visitor_reference_records!
    @visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
    )
    @token = VisitorToken.create!(authentication_epoch: 0, visitor: @visitor)
    grant_step_up!
    VisitorEmail.create!(
      visitor: @visitor,
      address: "visitor-#{SecureRandom.hex(4)}@example.com",
      confirm_policy: "1",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
    ).tap(&:finalize_binding!)
  end

  test "creates an active secret credential with a generated raw secret" do
    result = create_secret({ name: "api-key-1", enabled: true })

    assert_predicate result.secret_credential, :persisted?
    assert_predicate result.raw_secret_credential, :present?
    assert_equal "api-key-1", result.secret_credential.name
    assert_equal VisitorSecretCredential.status_id_for(:active),
                 result.secret_credential.visitor_secret_credential_status_id
    assert_nil @token.reload.last_step_up_at
  end

  test "creates a revoked secret credential when enabled is false" do
    result = create_secret({ name: "disabled-key", enabled: false })

    assert_equal VisitorSecretCredential.status_id_for(:revoked),
                 result.secret_credential.visitor_secret_credential_status_id
  end

  test "uses the provided raw secret credential and strips the name" do
    provided = VisitorSecretCredential.generate_raw_secret_credential

    result = create_secret({ name: "  spaced-name  ", enabled: "1" }, raw_secret_credential: provided)

    assert_equal provided, result.raw_secret_credential
    assert_equal "spaced-name", result.secret_credential.name
    assert_equal VisitorSecretCredential.status_id_for(:active),
                 result.secret_credential.visitor_secret_credential_status_id
  end

  test "the same Step-Up cannot create a second Secret" do
    create_secret({ name: "first", enabled: true })

    assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
      create_secret({ name: "second", enabled: true })
    end
    assert_equal 1, @visitor.visitor_secret_credentials.count
  end

  private

  def create_secret(params, raw_secret_credential: nil)
    VisitorSecretCredentialsCreate.call(
      actor: @visitor, visitor: @visitor, params: params, raw_secret_credential: raw_secret_credential,
      step_up_token: @token, step_up_requirement: step_up_requirement, step_up_bootstrap: false,
    )
  end

  def grant_step_up!
    @token.update!(
      last_step_up_at: VisitorToken.database_now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:com",
      last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
  end

  def step_up_requirement
    StepUpRequirement.new(
      scope: "settings_secret_credential", step_up_required: true, allowed_methods: %i(email_otp passkey),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, purpose: "step_up", audience: "step_up:com",
      session_binding: @token.public_id, token_binding: @token.public_id, require_session_binding: true,
      ttl: StepUpRequirement::DEFAULT_TTL, actor_ref: @visitor.public_id, resource_ref: nil, tenant_ref: nil,
    )
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
    VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::REVOKED)
    VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
  end
end
