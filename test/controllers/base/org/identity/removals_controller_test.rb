# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = configured_host(:base_staff)
    ensure_operator_reference_records!
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
  end

  test "removes the secret credential when another sign-in method still remains" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)

    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: step_up_staff_headers(@operator, host: @host)

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_not_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "refuses to remove the credential that carries the only remaining sign-in method" do
    only = create_active_secret_credential(@operator)

    post base_org_identity_secret_removal_url(only.public_id, ri: "jp", host: @host),
         headers: step_up_staff_headers(@operator, host: @host)

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_equal OperatorSecretCredentialStatus::ACTIVE, only.reload.staff_secret_status_id
  end

  test "a credential owned by another operator is not found" do
    other = Operator.create!(status_id: OperatorStatus::ACTIVE)
    other_secret = create_active_secret_credential(other)
    create_active_secret_credential(other)

    post base_org_identity_secret_removal_url(other_secret.public_id, ri: "jp", host: @host),
         headers: step_up_staff_headers(@operator, host: @host)

    assert_response :not_found
    assert_equal OperatorSecretCredentialStatus::ACTIVE, other_secret.reload.staff_secret_status_id
  end

  test "removal without fresh step-up is refused and keeps the credential" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)

    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@operator, host: @host)

    assert_not response.location.to_s.end_with?(base_org_identity_secrets_path(ri: "jp"))
    assert_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "an Emergency session cannot remove a credential" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)
    emergency_token = OperatorToken.create!(
      staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discarded_at: 30.days.from_now,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      authentication_context: AuthenticationContextValue::EMERGENCY_KEY,
    )

    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@operator, host: @host, session_public_id: emergency_token.public_id)

    assert_not response.location.to_s.end_with?(base_org_identity_secrets_path(ri: "jp"))
    assert_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  private

  def step_up_staff_headers(actor, host:)
    headers = as_staff_headers(actor, host: host)
    OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID")).update_columns(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_secret_credential",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"),
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
    headers
  end

  def create_active_secret_credential(operator)
    OperatorSecretCredential.create!(
      staff: operator,
      name: "Removal test secret credential #{SecureRandom.hex(4)}",
      password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
  end

  def ensure_operator_reference_records!
    OperatorStatus.find_or_create_by!(id: OperatorStatus::ACTIVE)
    [
      OperatorSecretCredentialStatus::ACTIVE,
      OperatorSecretCredentialStatus::DELETED,
      OperatorSecretCredentialStatus::REVOKED,
    ].each { |id| OperatorSecretCredentialStatus.find_or_create_by!(id: id) }
    OperatorSecretCredentialKind.find_or_create_by!(id: OperatorSecretCredentialKind::LOGIN)
  end

  # DAMP local helper copy for former shared test support.
  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end
end
