# frozen_string_literal: true

require "test_helper"

class ClientSecretManualReattemptIssuerTest < ActiveSupport::TestCase
  setup do
    @previous_issuance_ttl = ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"]
    ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"] = "600"
    @actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    now = ClientToken.database_now
    @token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    @token.rotate_refresh_token!(now:)
    @token.device_session_record!
    oidc_client = OidcClientRegistry.find!("base-app-ww")
    @step_up_grant = OpAppGrant.create!(
      authentication_epoch: @token.authentication_epoch, client_token: @token, oidc_client_id: oidc_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(now.to_i).utc, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: now + 1.hour,
    )
    @step_up_grant.issue_refresh_token!(now:)
    @step_up_evidence = StepUpEvidenceValue.new(
      acr: @step_up_grant.oidc_acr, amr: ["passkey"], auth_time: now.to_i, sid: @step_up_grant.public_id,
      sub: OidcSubject.for(@actor, resource_type: "client"), client_id: oidc_client.client_id,
      aud: [oidc_client.aud], jti: @step_up_grant.oidc_jti,
    )
    @context = ActorValuesContext.empty.with(subject: @actor, actor_type: :client, tld: :app, surface: :base)
  end

  teardown { ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"] = @previous_issuance_ttl }

  test "a withdrawn Client cannot reattempt a payload-failed issuance" do
    predecessor = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: @step_up_evidence,
    )
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: predecessor, purge_after: 1.day,
      step_up_evidence: @step_up_evidence,
    )
    predecessor.reload
    now = Client.database_now
    @actor.update!(withdrawn_at: now, terminated_at: now)

    assert_no_difference ["ClientSecretIssuance.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretManualReattemptIssuer::Denied) do
        ClientSecretManualReattemptIssuer.call!(
          actor_context: @context, token: @token, predecessor: predecessor, purge_after: 1.day,
          step_up_evidence: @step_up_evidence,
        )
      end
    end
  end

  test "a revoked device cannot reattempt a payload-failed issuance" do
    predecessor = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: @step_up_evidence,
    )
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: predecessor, purge_after: 1.day,
      step_up_evidence: @step_up_evidence,
    )
    predecessor.reload
    @token.device_session_record!.revoke!

    assert_no_difference ["ClientSecretIssuance.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretManualReattemptIssuer::Denied) do
        ClientSecretManualReattemptIssuer.call!(
          actor_context: @context, token: @token, predecessor: predecessor, purge_after: 1.day,
          step_up_evidence: @step_up_evidence,
        )
      end
    end
  end

  test "a superseded device token cannot reattempt a payload-failed issuance" do
    predecessor = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: @step_up_evidence,
    )
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: predecessor, purge_after: 1.day,
      step_up_evidence: @step_up_evidence,
    )
    device = @token.device_session_record!
    replacement = ClientToken.create!(authentication_epoch: 0, user: @actor, device_session: device)
    device.update!(current_refresh_token_id: replacement.id)

    assert_no_difference ["ClientSecretIssuance.count", "ClientSecretAuditOutbox.count"] do
      assert_raises(ClientSecretManualReattemptIssuer::Denied) do
        ClientSecretManualReattemptIssuer.call!(
          actor_context: @context, token: @token, predecessor: predecessor, purge_after: 1.day,
          step_up_evidence: @step_up_evidence,
        )
      end
    end
  end

  test "payload-failed predecessor creates one exact successor and repeated POST returns it" do
    operation = SecureRandom.uuid
    predecessor = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: operation, expires_after: 1.minute,
      step_up_evidence: @step_up_evidence,
    )
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: predecessor, purge_after: 1.day,
      step_up_evidence: @step_up_evidence,
    )
    predecessor.reload

    assert predecessor.canceled_at
    assert ClientSecretAuditOutbox.exists?(
      client_ref: @actor.public_id, operation_ref: operation,
      event_name: "secret.issuance_canceled", reason: "payload_unavailable",
      occurred_at: predecessor.canceled_at, item_count: predecessor.planned_count,
    )

    assert_difference("ClientSecretIssuance.count", 1) do
      @successor = ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: predecessor, purge_after: 1.day,
        step_up_evidence: @step_up_evidence,
      )
    end
    assert_equal operation, @successor.origin_operation_id
    assert_equal predecessor.attempt_number + 1, @successor.attempt_number
    assert_equal predecessor.planned_count, @successor.planned_count
    assert_equal "manual", @successor.origin
    assert_equal @token.public_id, @successor.browser_session_ref
    assert_equal "reattempt", ClientSecretAuditOutbox.find_by!(
      operation_ref: operation, event_name: "secret.issuance_started", reason: "reattempt",
    ).reason

    assert_no_difference("ClientSecretIssuance.count") do
      replay = ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: predecessor, purge_after: 1.day,
        step_up_evidence: @step_up_evidence,
      )

      assert_equal @successor.id, replay.id
    end
  end

  test "a newer unrelated attempt cannot be bypassed by restarting an older predecessor" do
    operation = SecureRandom.uuid
    predecessor = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: operation, expires_after: 1.minute,
      step_up_evidence: @step_up_evidence,
    )
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: predecessor, purge_after: 1.day,
      step_up_evidence: @step_up_evidence,
    )
    ClientSecretIssuance.create!(
      client: @actor, origin_operation_id: operation, origin: "manual", attempt_number: 3,
      browser_session_ref: @token.public_id, planned_count: 1,
      expires_at: Client.database_now + 1.minute,
    )

    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: predecessor, purge_after: 1.day,
        step_up_evidence: @step_up_evidence,
      )
    end
    assert_equal 2, ClientSecretIssuance.where(origin_operation_id: operation).count
  end

  test "missing payload proof, wrong session and expired authority cannot create a successor" do
    unfailed = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
      step_up_evidence: @step_up_evidence,
    )
    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: unfailed, purge_after: 1.day,
        step_up_evidence: @step_up_evidence,
      )
    end

    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: unfailed, purge_after: 1.day,
      step_up_evidence: @step_up_evidence,
    )
    other_token = ClientToken.create!(authentication_epoch: 0, user: @actor)
    wrong_context = @context
    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: wrong_context, token: other_token, predecessor: unfailed, purge_after: 1.day,
        step_up_evidence: @step_up_evidence,
      )
    end

    @token.update!(user_token_status_id: ClientTokenStatus::REVOKED)
    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: unfailed, purge_after: 1.day,
        step_up_evidence: @step_up_evidence,
      )
    end
  end
end
