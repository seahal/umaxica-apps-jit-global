# frozen_string_literal: true

require "test_helper"

class StepUpEvidenceResolverTest < ActiveSupport::TestCase
  fixtures :clients, :operators
  self.fixture_table_names = %w(clients operators)

  setup do
    @actor = clients(:one)
    @cell = RpCellBinding.fetch("rp_base_app")
    @issuer = OidcIssuer.for_resource_type("client")
    @subject = OidcSubject.for(@actor, resource_type: "client")
    @sid = SecureRandom.alphanumeric(21)
    @now = RpBaseAppRecord.database_now
    @rp_session = RpCallbackCommitter.call(
      cell: @cell,
      issuer: @issuer,
      subject: @subject,
      sid: @sid,
      absolute_expires_at: @now + 1.hour,
    ).session
    binding = RpBaseAppOpSessionBinding.includes(identity_binding: :principal).find(@rp_session.op_session_binding_id)
    @principal = binding.identity_binding.principal
    @payload = {
      "iss" => @issuer,
      "aud" => [OidcClientRegistry.find!(@cell.client_id).aud],
      "sid" => @sid,
      "sub" => @subject,
      "client_id" => @cell.client_id,
      AuthenticationContextValue::CLAIM => AuthenticationContextValue::NORMAL_KEY,
      "acr" => StepUpEvidenceResolver::STEP_UP_ACR,
      "amr" => ["passkey"],
      "auth_time" => @now.to_i - 1,
      "exp" => @now.to_i + 60,
      "jti" => SecureRandom.hex(16),
    }
    @access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: @principal,
      rp_session: @rp_session,
      payload: @payload,
      security_context: nil,
    )

    op_now = OpBaseAppRecord.database_now
    @op_token = ClientToken.create!(
      authentication_epoch: @actor.authentication_epoch,
      user: @actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discard_at: op_now + 1.hour,
    )
    @op_token.update!(root_login_established_at: op_now, established_authentication_method: "passkey")
    @op_token.rotate_refresh_token!(now: op_now)
    @op_device = @op_token.device_session_record!
    client = OidcClientRegistry.find!(@cell.client_id)
    op_auth_time = op_now.to_i - 10
    @op_grant = OpAppGrant.create!(
      authentication_epoch: @op_token.authentication_epoch,
      client_token: @op_token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: Time.at(op_auth_time).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: op_now + 10.minutes,
    )
    @op_grant.issue_refresh_token!(now: op_now)
    @op_access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: @actor,
      rp_session: @op_grant,
      payload: {
        "iss" => @issuer,
        "aud" => [client.aud],
        "sid" => @op_grant.public_id,
        "sub" => @subject,
        "client_id" => client.client_id,
        AuthenticationContextValue::CLAIM => @op_token.strict_authentication_context_value.to_s,
        "acr" => StepUpEvidenceResolver::STEP_UP_ACR,
        "amr" => ["passkey"],
        "auth_time" => op_auth_time,
        "exp" => op_now.to_i + 60,
        "jti" => @op_grant.oidc_jti,
      },
      security_context: nil,
    )
  end

  test "accepts a verified local RP event immediately inside the five-minute window" do
    access_state = @access_state.with(
      payload: @payload.merge("auth_time" => @now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS + 1),
    )

    RpBaseAppRecord.stub(:database_now, @now) do
      evidence = StepUpEvidenceResolver.call(access_state:, actor: @actor, cell: @cell)

      assert_instance_of StepUpEvidenceValue, evidence
      assert_equal @sid, evidence.sid
      assert_equal @subject, evidence.sub
    end
  end

  test "rejects a local event at the five-minute boundary, in the future, or after token expiry" do
    boundary = @access_state.with(
      payload: @payload.merge("auth_time" => @now.to_i - StepUpEvidenceValue::MAX_AGE_SECONDS),
    )
    future = @access_state.with(payload: @payload.merge("auth_time" => @now.to_i + 1))
    expired = @access_state.with(payload: @payload.merge("exp" => @now.to_i))

    RpBaseAppRecord.stub(:database_now, @now) do
      assert_nil StepUpEvidenceResolver.call(access_state: boundary, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: future, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: expired, actor: @actor, cell: @cell)
    end
  end

  test "rejects a local event for another grant, subject, audience, or malformed method attribution" do
    wrong_sid = @access_state.with(payload: @payload.merge("sid" => SecureRandom.alphanumeric(21)))
    wrong_subject = @access_state.with(payload: @payload.merge("sub" => "another-subject"))
    wrong_audience = @access_state.with(payload: @payload.merge("aud" => ["another-client"]))
    malformed_amr = @access_state.with(payload: @payload.merge("amr" => "passkey"))

    RpBaseAppRecord.stub(:database_now, @now) do
      assert_nil StepUpEvidenceResolver.call(access_state: wrong_sid, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: wrong_subject, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: wrong_audience, actor: @actor, cell: @cell)
      assert_nil StepUpEvidenceResolver.call(access_state: malformed_amr, actor: @actor, cell: @cell)
    end
  end

  test "accepts a current event from the authorized Base OP-chain grant" do
    now = OpBaseAppRecord.database_now

    OpBaseAppRecord.stub(:database_now, now) do
      evidence = StepUpEvidenceResolver.call(access_state: @op_access_state, actor: @actor, cell: @cell)

      assert_instance_of StepUpEvidenceValue, evidence
      assert_equal @op_access_state.payload.fetch("sid"), evidence.sid
      assert_equal @op_access_state.payload.fetch("jti"), evidence.jti
    end
  end

  test "rejects an OP-chain access token whose committed event no longer matches its grant" do
    changed_state = @op_access_state.with(payload: @op_access_state.payload.merge("auth_time" => @now.to_i - 2))
    now = OpBaseAppRecord.database_now

    OpBaseAppRecord.stub(:database_now, now) do
      assert_nil StepUpEvidenceResolver.call(access_state: changed_state, actor: @actor, cell: @cell)
    end
  end

  test "rejects step-up evidence for a DPoP-bound OP-chain grant" do
    thumbprint = SecureRandom.hex(32)
    @op_token.update!(dpop_jkt: thumbprint)
    @op_device.update!(dpop_jkt: thumbprint)
    @op_grant.update!(dpop_jkt: thumbprint)
    now = OpBaseAppRecord.database_now

    OpBaseAppRecord.stub(:database_now, now) do
      assert_nil StepUpEvidenceResolver.call(access_state: @op_access_state, actor: @actor, cell: @cell)
    end
  end

  test "rejects step-up evidence in an ORG standby authentication context" do
    actor = operators(:one)
    cell = RpCellBinding.fetch("rp_base_org")
    issuer = OidcIssuer.for_resource_type("operator")
    subject = OidcSubject.for(actor, resource_type: "operator")
    sid = SecureRandom.alphanumeric(21)
    now = RpBaseOrgRecord.database_now
    session = RpCallbackCommitter.call(
      cell:, issuer:, subject:, sid:, absolute_expires_at: now + 1.hour,
    ).session
    binding = RpBaseOrgOpSessionBinding.includes(identity_binding: :principal).find(session.op_session_binding_id)
    client = OidcClientRegistry.find!(cell.client_id)
    access_state = BrowserRpAuthentication::AccessState.new(
      status: :valid,
      resource: binding.identity_binding.principal,
      rp_session: session,
      payload: {
        "iss" => issuer,
        "aud" => [client.aud],
        "sid" => sid,
        "sub" => subject,
        "client_id" => cell.client_id,
        AuthenticationContextValue::CLAIM => AuthenticationContextValue::STANDBY_KEY,
        "acr" => StepUpEvidenceResolver::STEP_UP_ACR,
        "amr" => ["passkey"],
        "auth_time" => now.to_i - 1,
        "exp" => now.to_i + 60,
        "jti" => SecureRandom.hex(16),
      },
      security_context: nil,
    )

    RpBaseOrgRecord.stub(:database_now, now) do
      assert_nil StepUpEvidenceResolver.call(access_state:, actor:, cell:)
    end
  end
end
