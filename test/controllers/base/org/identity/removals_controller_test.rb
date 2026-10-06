# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Identity::RemovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    https!
    @host = configured_host(:base_staff)
    ensure_operator_reference_records!
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @step_up_passkey = @operator.operator_passkeys.create!(
      webauthn_id: "org-removal-step-up-#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid, public_key: "public_key_#{SecureRandom.hex(8)}",
      description: "Removal test step-up passkey", status_id: OperatorPasskeyStatus::ACTIVE,
      uv_verified_at: Time.current,
    )
    headers = as_staff_headers(@operator, host: @host)
    token = OperatorToken.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    token.update!(root_login_established_at: Time.current, established_authentication_method: "passkey")
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: token)
    install_base_browser_rp_credentials!(surface: "org", host: @host, actor: @operator, token: token)
  end

  test "removes the secret credential when another sign-in method still remains" do
    target = create_active_secret_credential(@operator)
    OperatorPasskeyStatus.find_or_create_by!(id: OperatorPasskeyStatus::ACTIVE)
    OperatorPasskey.create!(
      staff: @operator,
      webauthn_id: "org-removal-alternative-#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key_#{SecureRandom.hex(8)}",
      description: "Alternative sign-in passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    assert_equal [:passkey],
                 AuthenticationCredentialInventory.call(@operator, excluding: target).sign_in_methods

    post base_org_identity_secret_removal_url(target.public_id, ri: "jp", host: @host),
         headers: step_up_staff_headers(@operator, host: @host)

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_not_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "direct secret credential deletion without fresh step-up is refused" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)

    delete base_org_identity_secret_url(target.public_id, ri: "jp", host: @host),
           headers: as_staff_headers(@operator, host: @host).except("Cookie", "HTTP_COOKIE")

    assert_not response.location.to_s.end_with?(base_org_identity_secrets_path(ri: "jp"))
    assert_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "removes a Secret when the registered Passkey remains as the sign-in method" do
    only = create_active_secret_credential(@operator)

    post base_org_identity_secret_removal_url(only.public_id, ri: "jp", host: @host),
         headers: step_up_staff_headers(@operator, host: @host)

    assert_response :see_other
    assert_redirected_to base_org_identity_secrets_path(ri: "jp")
    assert_not_equal OperatorSecretCredentialStatus::ACTIVE, only.reload.staff_secret_status_id
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
         headers: as_staff_headers(@operator, host: @host).except("Cookie", "HTTP_COOKIE")

    assert_not response.location.to_s.end_with?(base_org_identity_secrets_path(ri: "jp"))
    assert_equal OperatorSecretCredentialStatus::ACTIVE, target.reload.staff_secret_status_id
  end

  test "an Emergency session cannot remove a credential" do
    target = create_active_secret_credential(@operator)
    create_active_secret_credential(@operator)
    emergency_token = OperatorToken.create!(
      staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 30.days.from_now,
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
      last_step_up_credential_ref: @step_up_passkey.external_id,
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    headers.except("Cookie", "HTTP_COOKIE")
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
    OperatorEmailStatus.ensure_defaults!
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
