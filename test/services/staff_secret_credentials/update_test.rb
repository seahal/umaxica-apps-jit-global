# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsUpdateTest < ActiveSupport::TestCase
  fixtures :operator_statuses, :operator_email_statuses, :operator_secret_credential_statuses, :operators

  setup do
    @staff = operators(:one)
    @token = OperatorToken.create!(authentication_epoch: 0, staff: @staff)
    now = OperatorToken.database_now
    @token.device_session_record!
    @token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    @token.rotate_refresh_token!(now:)
    oidc_client = OidcClientRegistry.find!("base-org-ww")
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: oidc_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(now:)
    @step_up_evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: grant.public_id,
      sub: OidcSubject.for(@staff, resource_type: "operator"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: grant.oidc_jti,
    )
    @root_authentication_state = @token.attributes.slice(:root_login_established_at, :established_authentication_method)
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

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: params,

      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_equal "Updated Name", result.secret_credential.name
  end

  test "updates secret_credential status to revoked" do
    params = { enabled: false }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: params,

      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_predicate result.secret_credential, :revoked?
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
    security_transition_events = OperatorChronicle.where(
      event_id: OperatorChronicleEvent::CREDENTIAL_SECURITY_TRANSITION,
    )

    assert_predicate security_transition_events, :exists?
  end

  test "updates secret_credential status to active" do
    @secret_credential.update!(staff_secret_status_id: OperatorSecretCredentialStatus::REVOKED)
    params = { enabled: true }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: params,

      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_predicate result.secret_credential, :active?
  end

  test "strips whitespace from name parameter" do
    params = { name: "  updated-name-with-spaces  " }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: params,

      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_equal "updated-name-with-spaces", result.secret_credential.name
  end

  test "does not update name when not present in params" do
    original_name = @secret_credential.name
    params = { enabled: false }

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: params,

      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_equal original_name, result.secret_credential.name
  end

  test "does not update status when not present in params" do
    params = { name: "New Name" }
    original_status = @secret_credential.staff_secret_status_id

    result = OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: params,

      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_equal original_status, result.secret_credential.staff_secret_status_id
  end

  test "creates OperatorChronicle audit" do
    params = { name: "Audit Test" }

    assert_difference("OperatorChronicle.count", 1) do
      OperatorSecretCredentialsUpdate.call(
        actor: @staff, secret_credential: @secret_credential, params: params,
        step_up_token: @token, step_up_evidence: @step_up_evidence,
      )
    end

    activity = OperatorChronicle.last

    assert_equal OperatorChronicleEvent::STAFF_SECRET_UPDATED, activity.event_id
  end

  test "a no-op update leaves root-token state unchanged" do
    original_root = @token.reload.attributes

    OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: { name: @secret_credential.name },
      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_equal original_root, @token.reload.attributes
  end

  test "the same OP event can update a second Secret" do
    OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: @secret_credential, params: { name: "First Name" },
      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )
    second = OperatorSecretCredential.create!(
      staff: @staff, name: "Second Secret", password: OperatorSecretCredential.generate_raw_secret_credential,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )

    OperatorSecretCredentialsUpdate.call(
      actor: @staff, secret_credential: second, params: { name: "Second Name" },
      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_equal "Second Name", second.reload.name
  end

  test "a reserved operator cannot rename or delete a Secret with previously valid Step-Up" do
    @staff.update!(status_id: OperatorStatus::RESERVED)
    assert_no_difference "OperatorChronicle.count" do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsUpdate.call(
          actor: @staff, secret_credential: @secret_credential, params: { name: "blocked" },
          step_up_token: @token, step_up_evidence: @step_up_evidence,
        )
      end
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsDestroy.call(
          actor: @staff, secret_credential: @secret_credential,
          step_up_token: @token, step_up_evidence: @step_up_evidence,
        )
      end
    end
    assert_equal "Test Secret", @secret_credential.reload.name
    assert_predicate @secret_credential, :active?
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
  end

  test "a revoked device cannot rename or delete a Secret with previously valid Step-Up" do
    @token.device_session_record!.revoke!
    assert_no_difference "OperatorChronicle.count" do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsUpdate.call(
          actor: @staff, secret_credential: @secret_credential, params: { name: "blocked" },
          step_up_token: @token, step_up_evidence: @step_up_evidence,
        )
      end
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsDestroy.call(
          actor: @staff, secret_credential: @secret_credential,
          step_up_token: @token, step_up_evidence: @step_up_evidence,
        )
      end
    end
    assert_equal "Test Secret", @secret_credential.reload.name
    assert_predicate @secret_credential, :active?
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
  end

  test "a superseded token cannot rename or delete a Secret with previously valid Step-Up" do
    device = @token.device_session_record!
    replacement = operator_tokens(:one)
    replacement.update!(device_session_id: device.id)
    device.update!(current_refresh_token_id: replacement.id)
    assert_no_difference "OperatorChronicle.count" do
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsUpdate.call(
          actor: @staff, secret_credential: @secret_credential, params: { name: "blocked" },
          step_up_token: @token, step_up_evidence: @step_up_evidence,
        )
      end
      assert_raises(TokenStatusManagement::StepUpEvidenceUnavailable) do
        OperatorSecretCredentialsDestroy.call(
          actor: @staff, secret_credential: @secret_credential,
          step_up_token: @token, step_up_evidence: @step_up_evidence,
        )
      end
    end
    assert_equal "Test Secret", @secret_credential.reload.name
    assert_predicate @secret_credential, :active?
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
  end
end
