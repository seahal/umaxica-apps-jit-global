# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StaffSecretCredentialsDestroyTest < ActiveSupport::TestCase
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

  test "logically deletes staff secret_credential" do
    assert_no_difference("OperatorSecretCredential.count") do
      OperatorSecretCredentialsDestroy.call(
        actor: @staff, secret_credential: @secret_credential,
        step_up_token: @token, step_up_evidence: @step_up_evidence,
      )
    end

    assert_not_equal Retainable::SENTINEL, @secret_credential.reload.discard_at
    assert_operator @secret_credential.purge_eligible_at, :>, Time.current
    assert_equal OperatorSecretCredentialStatus::DELETED, @secret_credential.staff_secret_status_id
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
  end

  test "creates OperatorChronicle audit" do
    assert_difference("OperatorChronicle.count", 2) do
      OperatorSecretCredentialsDestroy.call(
        actor: @staff, secret_credential: @secret_credential,
        step_up_token: @token, step_up_evidence: @step_up_evidence,
      )
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

  test "the same OP event can delete a second Secret" do
    OperatorSecretCredentialsDestroy.call(
      actor: @staff, secret_credential: @secret_credential,
      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )
    second = OperatorSecretCredential.create!(
      staff: @staff, name: "Second Secret", password: OperatorSecretCredential.generate_raw_secret_credential,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )

    OperatorSecretCredentialsDestroy.call(
      actor: @staff, secret_credential: second,
      step_up_token: @token, step_up_evidence: @step_up_evidence,
    )

    assert_predicate second.reload, :persisted?
    assert_predicate second.reload, :deleted?
    assert_equal @root_authentication_state, @token.reload.attributes.slice(*@root_authentication_state.keys)
  end
end
