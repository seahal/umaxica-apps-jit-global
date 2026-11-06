# frozen_string_literal: true

require "test_helper"

class StepUpEvidenceVerifierTest < ActiveSupport::TestCase
  fixtures :clients, :operators
  self.fixture_table_names = %w(clients operators)

  setup do
    @actor = clients(:one)
    now = OpBaseAppRecord.database_now
    @root_token = ClientToken.create!(
      authentication_epoch: @actor.authentication_epoch,
      user: @actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: now + 1.hour,
    )
    @root_token.update!(root_login_established_at: now, established_authentication_method: "passkey")
    @root_token.rotate_refresh_token!(now:)
    @device = @root_token.device_session_record!
    client = OidcClientRegistry.find!("base-app-ww")
    auth_time = now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS + 1
    @grant = OpAppGrant.create!(
      authentication_epoch: @root_token.authentication_epoch,
      client_token: @root_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 10.minutes,
    )
    @grant.issue_refresh_token!(now:)
    @evidence = StepUpEvidenceValue.new(
      acr: @grant.oidc_acr,
      amr: ["passkey"],
      auth_time:,
      sid: @grant.public_id,
      sub: OidcSubject.for(@actor, resource_type: "client"),
      client_id: client.client_id,
      aud: [client.aud],
      jti: @grant.oidc_jti,
    )
  end

  test "accepts the current event for the same active actor root and grant" do
    result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: @evidence, actor: @actor, token: @root_token)
      end

    assert result
  end

  test "rejects evidence for a different actor or another root session" do
    other_actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    other_root = ClientToken.create!(
      authentication_epoch: other_actor.authentication_epoch,
      user: other_actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    other_root.update!(
      root_login_established_at: OpBaseAppRecord.database_now,
      established_authentication_method: "passkey",
    )
    other_root.rotate_refresh_token!(now: OpBaseAppRecord.database_now)
    other_root.device_session_record!
    current_root = ClientToken.create!(
      authentication_epoch: @actor.authentication_epoch,
      user: @actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    current_root.update!(
      root_login_established_at: OpBaseAppRecord.database_now,
      established_authentication_method: "passkey",
    )
    current_root.rotate_refresh_token!(now: OpBaseAppRecord.database_now)
    current_root.device_session_record!

    other_actor_result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: @evidence, actor: other_actor, token: @root_token)
      end
    other_root_result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: @evidence, actor: @actor, token: current_root)
      end

    assert_not other_actor_result
    assert_not other_root_result
  end

  test "rejects events at and beyond the five-minute deadline and future-dated evidence" do
    now = OpBaseAppRecord.database_now
    boundary_auth_time = now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS
    @grant.update!(oidc_auth_time: Time.at(boundary_auth_time).utc)
    boundary_evidence = StepUpEvidenceValue.new(**@evidence.to_h.merge(auth_time: boundary_auth_time))
    boundary_result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: boundary_evidence, actor: @actor, token: @root_token)
      end

    older_auth_time = now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS - 1
    @grant.update!(oidc_auth_time: Time.at(older_auth_time).utc)
    older_evidence = StepUpEvidenceValue.new(**@evidence.to_h.merge(auth_time: older_auth_time))
    older_result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: older_evidence, actor: @actor, token: @root_token)
      end

    future_auth_time = now.to_i + 1
    @grant.update!(oidc_auth_time: Time.at(future_auth_time).utc)
    future_evidence = StepUpEvidenceValue.new(**@evidence.to_h.merge(auth_time: future_auth_time))
    future_result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: future_evidence, actor: @actor, token: @root_token)
      end

    assert_not boundary_result
    assert_not older_result
    assert_not future_result
  end

  test "rejects an event exactly at the deadline using the database time at the write boundary" do
    deadline = Time.at(@evidence.auth_time + StepUpEvidenceValue::MAX_AGE_SECONDS).utc
    result =
      ClientToken.transaction do
        OpBaseAppRecord.stub(:database_now, deadline) do
          StepUpEvidenceVerifier.call(evidence: @evidence, actor: @actor, token: @root_token)
        end
      end

    assert_not result
  end

  test "rejects evidence superseded by a newer grant event" do
    @grant.update!(oidc_jti: SecureRandom.uuid)
    result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: @evidence, actor: @actor, token: @root_token)
      end

    assert_not result
  end

  test "rejects an otherwise current event after its root session is revoked" do
    @root_token.revoke!
    result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: @evidence, actor: @actor, token: @root_token)
      end

    assert_not result
  end

  test "rejects a grant and root session bound to DPoP" do
    thumbprint = SecureRandom.hex(32)
    @root_token.update!(dpop_jkt: thumbprint)
    @device.update!(dpop_jkt: thumbprint)
    @grant.update!(dpop_jkt: thumbprint)
    result =
      ClientToken.transaction do
        StepUpEvidenceVerifier.call(evidence: @evidence, actor: @actor, token: @root_token)
      end

    assert_not result
  end

  test "requires the writer transaction to hold the verifier locks through commit" do
    ClientToken.connection_pool.with_connection do |connection|
      connection.stub(:open_transactions, 0) do
        assert_raises(ArgumentError) do
          StepUpEvidenceVerifier.call(evidence: @evidence, actor: @actor, token: @root_token)
        end
      end
    end
  end
end
