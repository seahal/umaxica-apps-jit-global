# frozen_string_literal: true

require "test_helper"

class ClientSecretManualReattemptIssuerTest < ActiveSupport::TestCase
  setup do
    @previous_issuance_ttl = ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"]
    ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"] = "600"
    @actor = Client.create!(status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(user: @actor)
    now = Client.database_now
    @token.update!(
      last_step_up_at: now, last_step_up_scope: "settings_secret_credential",
      last_step_up_method: "passkey", last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up", last_step_up_audience: "step_up:app",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up", last_step_up_full_reauthentication: false,
    )
    @context = ActorValuesContext.empty.with(subject: @actor, actor_type: :client, tld: :app, surface: :base)
  end

  teardown { ENV["APP_SECRET_ISSUANCE_TTL_SECONDS"] = @previous_issuance_ttl }

  test "payload-failed predecessor creates one exact successor and repeated POST returns it" do
    operation = SecureRandom.uuid
    predecessor = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: operation, expires_after: 1.minute,
    )
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: predecessor, purge_after: 1.day,
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
      )

      assert_equal @successor.id, replay.id
    end
  end

  test "a newer unrelated attempt cannot be bypassed by restarting an older predecessor" do
    operation = SecureRandom.uuid
    predecessor = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: operation, expires_after: 1.minute,
    )
    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: predecessor, purge_after: 1.day,
    )
    ClientSecretIssuance.create!(
      client: @actor, origin_operation_id: operation, origin: "manual", attempt_number: 3,
      browser_session_ref: @token.public_id, planned_count: 1,
      expires_at: Client.database_now + 1.minute,
    )

    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: predecessor, purge_after: 1.day,
      )
    end
    assert_equal 2, ClientSecretIssuance.where(origin_operation_id: operation).count
  end

  test "missing payload proof, wrong session and expired authority cannot create a successor" do
    unfailed = ClientSecretManualReservationIssuer.call!(
      actor_context: @context, token: @token, operation_id: SecureRandom.uuid, expires_after: 1.minute,
    )
    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: unfailed, purge_after: 1.day,
      )
    end

    ClientSecretManualIssuanceInvalidator.call_for_payload_failure!(
      actor_context: @context, token: @token, issuance: unfailed, purge_after: 1.day,
    )
    other_token = ClientToken.create!(user: @actor)
    wrong_context = @context
    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: wrong_context, token: other_token, predecessor: unfailed, purge_after: 1.day,
      )
    end

    @token.update!(user_token_status_id: ClientTokenStatus::REVOKED)
    assert_raises(ClientSecretManualReattemptIssuer::Denied) do
      ClientSecretManualReattemptIssuer.call!(
        actor_context: @context, token: @token, predecessor: unfailed, purge_after: 1.day,
      )
    end
  end
end
