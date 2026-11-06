# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsCreateTest < ActiveSupport::TestCase
  fixtures :operator_statuses, :operator_email_statuses, :operators

  setup do
    @staff = operators(:one)
    @token = OperatorToken.create!(authentication_epoch: 0, staff: @staff)
    now = OperatorToken.database_now
    @token.device_session_record!
    @token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    @token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    @step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    @step_up_grant.issue_refresh_token!(now:)
    @step_up_evidence = StepUpEvidenceValue.new(
      acr: @step_up_grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: @step_up_grant.public_id,
      sub: OidcSubject.for(@staff, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: @step_up_grant.oidc_jti,
    )
    @root_authentication_state = @token.attributes.slice(:root_login_established_at, :established_authentication_method)
    OperatorEmail.create!(
      staff: @staff,
      address: "secret_credential-test-#{SecureRandom.hex(4)}@example.com",
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
  end

  test "creates secret_credential with auto-generated raw secret_credential" do
    params = { name: "api-key-1", enabled: true }

    result = OperatorSecretCredentialsCreate.call(
      actor: @staff, staff: @staff, params: params,
      step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
    )

    assert_predicate result.secret_credential, :persisted?
    assert_predicate result.raw_secret_credential, :present?
    assert_equal "api-key-1", result.secret_credential.name
    assert_predicate result.secret_credential, :active?
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
  end

  test "creates secret_credential with enabled=false as revoked" do
    params = { name: "disabled-key", enabled: false }

    result = OperatorSecretCredentialsCreate.call(
      actor: @staff, staff: @staff, params: params,
      step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
    )

    assert_predicate result.secret_credential, :revoked?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  test-name-with-spaces  ", enabled: true }

    result = OperatorSecretCredentialsCreate.call(
      actor: @staff, staff: @staff, params: params,
      step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
    )

    assert_equal "test-name-with-spaces", result.secret_credential.name
  end

  test "a failed creation leaves the same OP event available for a valid retry" do
    assert_raises(ActiveRecord::RecordInvalid) do
      OperatorSecretCredentialsCreate.call(
        actor: @staff, staff: @staff, params: { name: "", enabled: true },
        step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
      )
    end

    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
    result = OperatorSecretCredentialsCreate.call(
      actor: @staff, staff: @staff, params: { name: "retry", enabled: true },
      step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
    )

    assert_predicate result.secret_credential, :active?
  end

  test "a reserved operator cannot create a Secret with previously valid Step-Up" do
    @staff.update!(status_id: OperatorStatus::RESERVED)
    assert_no_difference ["OperatorSecretCredential.count", "OperatorChronicle.count"] do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsCreate.call(
          actor: @staff, staff: @staff, params: { name: "blocked", enabled: true },
          step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
        )
      end
    end
  end

  test "a revoked device cannot create a Secret with previously valid Step-Up" do
    @token.device_session_record!.revoke!
    assert_no_difference ["OperatorSecretCredential.count", "OperatorChronicle.count"] do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsCreate.call(
          actor: @staff, staff: @staff, params: { name: "blocked", enabled: true },
          step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
        )
      end
    end
  end

  test "a superseded token cannot create a Secret with previously valid Step-Up" do
    device = @token.device_session_record!
    replacement = operator_tokens(:one)
    replacement.update!(device_session_id: device.id)
    device.update!(current_refresh_token_id: replacement.id)
    assert_no_difference ["OperatorSecretCredential.count", "OperatorChronicle.count"] do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsCreate.call(
          actor: @staff, staff: @staff, params: { name: "blocked", enabled: true },
          step_up_token: @token, step_up_evidence: @step_up_evidence, step_up_bootstrap: false,
        )
      end
    end
  end

  test "bootstrap creates a Secret for an eligible operator with a current session" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator)

    result = OperatorSecretCredentialsCreate.call(
      actor: operator, staff: operator, params: { name: "bootstrap", enabled: true },
      step_up_token: token, step_up_evidence: nil, step_up_bootstrap: true,
    )

    assert_predicate result.secret_credential, :active?
    assert_equal operator.id, result.secret_credential.staff_id
  end

  test "bootstrap refuses an eligible operator whose device was revoked" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(authentication_epoch: 0, staff: operator)
    token.device_session_record!.revoke!

    assert_no_difference ["OperatorSecretCredential.count", "OperatorChronicle.count"] do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsCreate.call(
          actor: operator, staff: operator, params: { name: "blocked bootstrap", enabled: true },
          step_up_token: token, step_up_evidence: nil, step_up_bootstrap: true,
        )
      end
    end
  end

  test "a standby session cannot bootstrap a Secret even without any passkeys" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    token = OperatorToken.create!(
      authentication_epoch: 0, staff: operator, authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )

    assert_no_difference ["OperatorSecretCredential.count", "OperatorChronicle.count"] do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsCreate.call(
          actor: operator, staff: operator, params: { name: "standby bootstrap", enabled: true },
          step_up_token: token, step_up_evidence: nil, step_up_bootstrap: true,
        )
      end
    end
  end
end
