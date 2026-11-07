# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::AvatarOwnershipTransfersControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @source = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    @token = OperatorToken.create!(authentication_epoch: 0, staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    OpOrgGrant.where(
      device_session_id: @token.device_session_id,
      oidc_client_id: "base-org-ww",
      revoked_at: nil,
    ).update_all(revoked_at: OpOrgGrant.database_now)
    @avatar_result = AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: @source.account,
      avatar_params: { moniker: "Bureau Avatar" },
      handle_params: { handle: "bureau-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @source.collective.public_id,
    )

    assert_predicate @avatar_result, :success?, @avatar_result.errors.inspect
    select_source_avatar!

    @target_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    @target = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @target_client)
  end

  teardown do
    if @token&.device_session_id
      OpOrgGrant.where(
        device_session_id: @token.device_session_id,
        oidc_client_id: "base-org-ww",
        revoked_at: nil,
      ).update_all(revoked_at: OpOrgGrant.database_now)
    end
  end

  test "registry request transport is refused before the verified ownership cutover" do
    client = OidcClientRegistry.find!("base-org-ww")
    now = OpBaseOrgRecord.database_now
    auth_time = Time.at(now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: now + 10.minutes,
    )
    access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator", session_public_id: @token.public_id,
                 base_session_public_id: @token.public_id, oidc_sid: grant.public_id, oidc_jti: grant.oidc_jti,
                 expires_at: now + 10.minutes, scopes: %w(openid profile), acr: grant.oidc_acr, amr: ["passkey"],
                 issuer: OidcIssuer.for_client(client), audiences: [client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: client.client_id,
                 auth_time: auth_time, authentication_context: @token.strict_authentication_context_value.to_s,
    )
    @base_browser_rp_credentials = { [client.client_id, @token.public_id] => [access, grant.issue_refresh_token!] }
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a50"

    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: {
             avatar_public_id: @avatar_result.avatar.public_id,
             target_surface: "app",
             target_collective_public_id: @target.collective.public_id,
           },
           headers: base_browser_headers.merge("Idempotency-Key" => key),
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal "registry transfer admission requires the verified Avatar ownership cutover", response.body
    assert_not AvatarOwnershipCutover.established?
    assert_nil @token.reload.last_step_up_at
  end

  test "a Standby session cannot request, accept or cancel ownership transfers with fresh Step-Up proof" do
    accept_transfer_now = OpBaseAppRecord.database_now
    accept_transfer_token = ClientToken.create!(
      authentication_epoch: @target_client.authentication_epoch, user: @target_client,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: accept_transfer_now + 1.hour,
    )
    accept_transfer_token.update!(
      root_login_established_at: accept_transfer_now,
      established_authentication_method: "passkey",
    )
    accept_transfer_token.rotate_refresh_token!(now: accept_transfer_now)
    accept_transfer_token.device_session_record!
    accept_transfer_client = OidcClientRegistry.find!("base-app-ww")
    accept_transfer_grant = OpAppGrant.create!(
      authentication_epoch: accept_transfer_token.authentication_epoch, client_token: accept_transfer_token,
      oidc_client_id: accept_transfer_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(accept_transfer_now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: accept_transfer_now + 1.hour,
    )
    accept_transfer_grant.issue_refresh_token!(now: accept_transfer_now)
    accept_transfer_evidence = StepUpEvidenceValue.new(
      acr: accept_transfer_grant.oidc_acr, amr: ["passkey"], auth_time: accept_transfer_now.to_i,
      sid: accept_transfer_grant.public_id, sub: OidcSubject.for(@target_client, resource_type: "client"),
      client_id: accept_transfer_client.client_id, aud: [accept_transfer_client.aud],
      jti: accept_transfer_grant.oidc_jti,
    )
    accept_transfer =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @target_client,
            surface: "app",
            subject_public_id: @target.account.public_id,
            avatar_public_id: @target.avatar.public_id,
            target_surface: "org",
            target_collective_public_id: @source.collective.public_id,
            step_up_token: accept_transfer_token, step_up_evidence: accept_transfer_evidence,
          )
        end
      end
    cancel_transfer_now = OpBaseOrgRecord.database_now
    cancel_transfer_token = OperatorToken.create!(
      authentication_epoch: @operator.authentication_epoch, staff: @operator,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      discard_at: cancel_transfer_now + 1.hour,
    )
    cancel_transfer_token.update!(
      root_login_established_at: cancel_transfer_now,
      established_authentication_method: "passkey",
    )
    cancel_transfer_token.rotate_refresh_token!(now: cancel_transfer_now)
    cancel_transfer_token.device_session_record!
    cancel_transfer_client = OidcClientRegistry.find!("base-org-ww")
    cancel_transfer_grant = OpOrgGrant.create!(
      authentication_epoch: cancel_transfer_token.authentication_epoch, operator_token: cancel_transfer_token,
      oidc_client_id: cancel_transfer_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(cancel_transfer_now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: cancel_transfer_now + 1.hour,
    )
    cancel_transfer_grant.issue_refresh_token!(now: cancel_transfer_now)
    cancel_transfer_evidence = StepUpEvidenceValue.new(
      acr: cancel_transfer_grant.oidc_acr, amr: ["passkey"], auth_time: cancel_transfer_now.to_i,
      sid: cancel_transfer_grant.public_id, sub: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: cancel_transfer_client.client_id, aud: [cancel_transfer_client.aud],
      jti: cancel_transfer_grant.oidc_jti,
    )
    cancel_transfer =
      OpBaseOrgRecord.connected_to(role: :writing) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @operator,
            surface: "org",
            subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar_result.avatar.public_id,
            target_surface: "app",
            target_collective_public_id: @target.collective.public_id,
            step_up_token: cancel_transfer_token, step_up_evidence: cancel_transfer_evidence,
          )
        end
      end

    assert_equal "pending", accept_transfer.state
    assert_equal "pending", cancel_transfer.state

    @token.update!(authentication_context: AuthenticationContextValue::STANDBY_KEY)
    transaction_count = OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count
    reservation_count = AvatarTransferReservation.count
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_token = @token.reload
    rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
    freshness_at = Time.at(OpBaseOrgRecord.database_now.to_i).utc
    rp_grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_token,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: freshness_at,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: 10.minutes.from_now,
    )
    rp_access_token = AuthenticationTokenService.encode(
      @operator,
      host: @host,
      resource_type: "operator",
      session_public_id: rp_token.public_id,
      base_session_public_id: rp_token.public_id,
      oidc_sid: rp_grant.public_id,
      oidc_jti: rp_grant.oidc_jti,
      expires_at: 10.minutes.from_now,
      scopes: %w(openid profile),
      acr: rp_grant.oidc_acr, amr: ["passkey"], auth_time: freshness_at,
      issuer: OidcIssuer.for_client(rp_client),
      audiences: [rp_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: rp_client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[[rp_client.client_id, rp_token.public_id]] = [
      rp_access_token,
      rp_grant.issue_refresh_token!,
    ]
    headers = base_browser_headers.merge("Idempotency-Key" => "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a80")

    post base_org_avatar_ownership_transfers_url(host: @host),
         params: {
           avatar_public_id: @avatar_result.avatar.public_id,
           target_surface: "app",
           target_collective_public_id: @target.collective.public_id,
         }, headers: headers, as: :json

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.parsed_body.fetch("error")
    assert_equal reservation_count, AvatarTransferReservation.count
    assert_equal freshness_at, rp_grant.reload.oidc_auth_time
    assert_equal AuthenticationContextValue::STANDBY_KEY, @token.authentication_context
    assert_equal transaction_count, OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count

    post base_org_accept_avatar_ownership_transfer_url(accept_transfer.public_id, host: @host),
         params: { transfer_kind: "legacy" }, headers: headers, as: :json

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.parsed_body.fetch("error")
    assert_equal "pending", accept_transfer.reload.state
    assert_equal freshness_at, rp_grant.reload.oidc_auth_time
    assert_equal AuthenticationContextValue::STANDBY_KEY, @token.authentication_context
    assert_equal transaction_count, OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count

    post base_org_cancel_avatar_ownership_transfer_url(cancel_transfer.public_id, host: @host),
         params: { transfer_kind: "legacy" }, headers: headers, as: :json

    assert_response :forbidden
    assert_equal I18n.t("auth.step_up.emergency_unavailable"), response.parsed_body.fetch("error")
    assert_equal "pending", cancel_transfer.reload.state
    assert_equal freshness_at, rp_grant.reload.oidc_auth_time
    assert_equal AuthenticationContextValue::STANDBY_KEY, @token.authentication_context
    assert_equal transaction_count, OperatorStepUpCeremonyTransaction.where(actor_ref: @operator.public_id).count
  end

  # A client whose first response was lost retries with the same key and discovers the committed result.
  test "registry request replays the committed result for a stable idempotency key" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    establish_avatar_ownership_cutover!
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a55"
    headers = base_browser_headers.merge("Idempotency-Key" => key)
    post(
      base_org_avatar_ownership_transfers_url(host: @host),
      params: org_request_params, headers: headers, as: :json,
    )

    assert_response :success
    first = response.parsed_body

    assert_equal "registry", first.fetch("transfer_kind")
    assert_nil @token.reload.last_step_up_at

    post(
      base_org_avatar_ownership_transfers_url(host: @host),
      params: org_request_params, headers: headers, as: :json,
    )

    assert_response :success
    assert_equal first.fetch("transfer_public_id"), response.parsed_body.fetch("transfer_public_id")
    assert_equal 1, AvatarTransferReservation.where(idempotency_key: key).count
  end

  test "registry request refuses a reused idempotency key with different input" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    establish_avatar_ownership_cutover!
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a56"
    headers = base_browser_headers.merge("Idempotency-Key" => key)
    post base_org_avatar_ownership_transfers_url(host: @host),
         params: org_request_params, headers: headers, as: :json

    assert_response :success
    recorded = AvatarTransferReservation.find_by!(idempotency_key: key).attributes
    other_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    other_target = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other_client)

    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: { target_surface: "app", target_collective_public_id: other_target.collective.public_id },
           headers: headers,
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal recorded, AvatarTransferReservation.find_by!(idempotency_key: key).attributes
  end

  test "registry request refuses a reused idempotency key from a different initiator" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    establish_avatar_ownership_cutover!
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a57"
    post base_org_avatar_ownership_transfers_url(host: @host),
         params: org_request_params, headers: base_browser_headers.merge("Idempotency-Key" => key), as: :json

    assert_response :success
    recorded = AvatarTransferReservation.find_by!(idempotency_key: key).attributes
    other_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(other_operator)
    other = BaseSelectorBootstrapAuthority.call(surface: :org, principal: other_operator)
    other_avatar_result = AvatarProvisioning::Create.call(
      actor: other_operator,
      subject_type: :agent,
      subject: other.account,
      avatar_params: { moniker: "Other initiator" },
      handle_params: { handle: "avatar-replay-agent-#{SecureRandom.hex(5)}" },
      owner_surface: "org",
      owner_collective_public_id: other.collective.public_id,
    )

    assert_predicate other_avatar_result, :success?, other_avatar_result.errors.inspect
    other_token = OperatorToken.create!(authentication_epoch: 0, staff: other_operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSwitcherAuthority.switch(
      surface: :org,
      principal: other_operator,
      session: other_token,
      params: {
        account_public_id: other.account.public_id,
        organization_public_id: other.collective.public_id,
        organization_unit_public_id: other.unit.public_id,
        avatar_public_id: other_avatar_result.avatar.public_id,
      },
    )
    other_client = OidcClientRegistry.find!("base-org-ww")
    other_now = OpBaseOrgRecord.database_now
    other_auth_time = Time.at(other_now.to_i).utc
    other_token.rotate_refresh_token! unless other_token.device_session_record.current_refresh_token_id
    other_grant = OpOrgGrant.create!(
      authentication_epoch: other_token.authentication_epoch, operator_token: other_token,
      oidc_client_id: other_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: other_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: other_now + 10.minutes,
    )
    other_access = AuthenticationTokenService.encode(
      other_operator, host: @host, resource_type: "operator", session_public_id: other_token.public_id,
                      base_session_public_id: other_token.public_id, oidc_sid: other_grant.public_id,
                      oidc_jti: other_grant.oidc_jti, expires_at: other_now + 10.minutes,
                      scopes: %w(openid profile), acr: other_grant.oidc_acr, amr: ["passkey"],
                      auth_time: other_auth_time, issuer: OidcIssuer.for_client(other_client),
                      audiences: [other_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(other_client),
                      subject: OidcSubject.for(other_operator, resource_type: "operator"),
                      client_id: other_client.client_id,
                      authentication_context: other_token.strict_authentication_context_value.to_s,
    )
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[[other_client.client_id, other_token.public_id]] =
      [other_access, other_grant.issue_refresh_token!]

    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: org_request_params,
           headers: base_browser_headers(operator: other_operator, token: other_token).merge("Idempotency-Key" => key),
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal recorded, AvatarTransferReservation.find_by!(idempotency_key: key).attributes
  end

  test "keyless legacy request is refused after the ownership cutover" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    establish_avatar_ownership_cutover!

    assert_no_difference [-> { AvatarOwnershipTransfer.count }, -> { AvatarTransferReservation.count }] do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: { target_surface: "app", target_collective_public_id: @target.collective.public_id },
           headers: base_browser_headers,
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal "legacy Avatar transfer operations are unavailable after cutover", response.body
  end

  test "registry accept transport is refused before the verified ownership cutover" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    source_now = OpBaseAppRecord.database_now
    source_token = ClientToken.create!(
      authentication_epoch: @target_client.authentication_epoch, user: @target_client,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_now + 1.hour,
    )
    source_token.update!(root_login_established_at: source_now, established_authentication_method: "passkey")
    source_token.rotate_refresh_token!(now: source_now)
    source_token.device_session_record!
    source_client_config = OidcClientRegistry.find!("base-app-ww")
    source_grant = OpAppGrant.create!(
      authentication_epoch: source_token.authentication_epoch, client_token: source_token,
      oidc_client_id: source_client_config.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(source_now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_now + 1.hour,
    )
    source_grant.issue_refresh_token!(now: source_now)
    source_evidence = StepUpEvidenceValue.new(
      acr: source_grant.oidc_acr, amr: ["passkey"], auth_time: source_now.to_i, sid: source_grant.public_id,
      sub: OidcSubject.for(@target_client, resource_type: "client"), client_id: source_client_config.client_id,
      aud: [source_client_config.aud], jti: source_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: @target_client,
            surface: "app",
            subject_public_id: @target.account.public_id,
            avatar_public_id: @target.avatar.public_id,
            target_surface: "org",
            target_collective_public_id: @source.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a52",
            request_fingerprint: registry_request_fingerprint(
              actor: @target_client,
              surface: "app",
              subject_public_id: @target.account.public_id,
              avatar_public_id: @target.avatar.public_id,
              target_surface: "org",
              target_collective_public_id: @source.collective.public_id,
            ),
            step_up_token: source_token, step_up_evidence: source_evidence,
          )
        end
      end

    post base_org_accept_avatar_ownership_transfer_url(
      reservation.public_id,
      host: @host,
      ri: "jp",
    ),
         params: { transfer_kind: "registry" },
         headers: base_browser_headers,
         as: :json

    assert_response :unprocessable_content
    assert_equal "registry transfer admission requires the verified Avatar ownership cutover", response.body
    assert_equal "pending", reservation.reload.state
    assert_not AvatarOwnershipCutover.established?
  end

  test "org owner can request app transfer and cancel only with cancel scope" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    http_headers_2 = base_browser_headers
    post base_org_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: {
           target_surface: "app",
           target_collective_public_id: @target.collective.public_id,
         },
         headers: http_headers_2, as: :json

    assert_response :success
    transfer_id = response.parsed_body.fetch("transfer_public_id")
    transfer = AvatarOwnershipTransfer.find_by!(public_id: transfer_id)

    assert_equal "org", transfer.from_owner_surface
    assert_equal "app", transfer.to_owner_surface
    assert_equal @avatar_result.avatar.id, transfer.avatar_id

    http_headers_1 = base_browser_headers
    post base_org_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: http_headers_1, as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
    assert_equal "org", @avatar_result.avatar.reload.current_ownership_period.owner_surface
  end

  test "another authorized source agent can cancel a transfer over HTTP" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    source_token = @token
    source_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time.to_i,
      sid: step_up_grant.public_id, sub: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: step_up_client.client_id, aud: [step_up_client.aud], jti: step_up_grant.oidc_jti,
    )
    transfer =
      OpBaseOrgRecord.connected_to(role: :writing) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @operator,
            surface: "org",
            subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar_result.avatar.public_id,
            target_surface: "app",
            target_collective_public_id: @target.collective.public_id,
            step_up_token: source_token, step_up_evidence: source_evidence,
          )
        end
      end
    other_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(other_operator)
    other = BaseSelectorBootstrapAuthority.call(surface: :org, principal: other_operator)
    AgentMembership.create!(
      agent: other.account,
      bureau: @source.collective,
      bureau_unit: @source.unit,
      membership_kind_id: AgentMembershipKind::OWNER,
      membership_state_id: AgentMembershipState::ACTIVE,
      primary: false,
      metadata: {},
    )
    other_avatar_result = AvatarProvisioning::Create.call(
      actor: other_operator,
      subject_type: :agent,
      subject: other.account,
      avatar_params: { moniker: "Second agent" },
      handle_params: { handle: "avatar-transfer-agent-#{SecureRandom.hex(5)}" },
      owner_surface: "org",
      owner_collective_public_id: other.collective.public_id,
    )

    assert_predicate other_avatar_result, :success?, other_avatar_result.errors.inspect
    other_token = OperatorToken.create!(authentication_epoch: 0, staff: other_operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSwitcherAuthority.switch(
      surface: :org,
      principal: other_operator,
      session: other_token,
      params: {
        account_public_id: other.account.public_id,
        organization_public_id: other.collective.public_id,
        organization_unit_public_id: other.unit.public_id,
        avatar_public_id: other_avatar_result.avatar.public_id,
      },
    )
    other_client = OidcClientRegistry.find!("base-org-ww")
    other_now = OpBaseOrgRecord.database_now
    other_auth_time = Time.at(other_now.to_i).utc
    other_token.rotate_refresh_token! unless other_token.device_session_record.current_refresh_token_id
    other_grant = OpOrgGrant.create!(
      authentication_epoch: other_token.authentication_epoch, operator_token: other_token,
      oidc_client_id: other_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: other_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: other_now + 10.minutes,
    )
    other_access = AuthenticationTokenService.encode(
      other_operator, host: @host, resource_type: "operator", session_public_id: other_token.public_id,
                      base_session_public_id: other_token.public_id, oidc_sid: other_grant.public_id,
                      oidc_jti: other_grant.oidc_jti, expires_at: other_now + 10.minutes,
                      scopes: %w(openid profile), acr: other_grant.oidc_acr, amr: ["passkey"],
                      auth_time: other_auth_time, issuer: OidcIssuer.for_client(other_client),
                      audiences: [other_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(other_client),
                      subject: OidcSubject.for(other_operator, resource_type: "operator"),
                      client_id: other_client.client_id,
                      authentication_context: other_token.strict_authentication_context_value.to_s,
    )
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[[other_client.client_id, other_token.public_id]] =
      [other_access, other_grant.issue_refresh_token!]

    post base_org_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: base_browser_headers(operator: other_operator, token: other_token),
         as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
    assert_equal other.account.public_id, transfer.reload.cancel_actor_public_id
  end

  test "URL-provided Avatar cannot replace a nil selected Avatar" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    @base_browser_rp_sessions ||= {}
    step_up_enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(step_up_client.client_id),
      issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"),
      sid: step_up_grant.public_id,
      absolute_expires_at: step_up_grant.refresh_token_expires_at,
    )

    assert_predicate step_up_enrollment, :success?
    @base_browser_rp_sessions[step_up_key] = step_up_enrollment.session

    assert_nil @source.avatar
    @token.update!(selected_avatar_public_id: nil)

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      http_headers_0 = base_browser_headers
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: {
             avatar_public_id: @target.avatar.public_id,
             target_surface: "app",
             target_collective_public_id: @target.collective.public_id,
           },
           headers: http_headers_0, as: :json

      assert_response :forbidden
    end
  end

  test "request is denied when the selected agent is no longer an owner member" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    headers = base_browser_headers
    membership = @source.account.agent_memberships.find_by!(bureau: @source.collective)
    membership.update!(membership_kind_id: AgentMembershipKind::MEMBER)

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: {
             target_surface: "app",
             target_collective_public_id: @target.collective.public_id,
           },
           headers: headers,
           as: :json

      assert_response :forbidden
    end
  end

  test "request is refused after the operator principal enters a login-blocked status" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    headers = base_browser_headers
    @operator.update!(status_id: OperatorStatus::RESERVED)

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: {
             target_surface: "app",
             target_collective_public_id: @target.collective.public_id,
           },
           headers: headers,
           as: :json

      assert_response :unauthorized
    end
  end

  test "an app principal cannot use the org transfer endpoint" do
    token = ClientToken.create!(authentication_epoch: 0, user: @target_client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    headers = as_user_headers(@target_client, host: @host, session_public_id: token.public_id)

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: {
             target_surface: "app",
             target_collective_public_id: @target.collective.public_id,
           },
           headers: headers,
           as: :json

      assert_response :unauthorized
    end
  end

  test "an operator cannot accept a transfer addressed to another bureau" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    destination_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    OperatorPasskeyTestSupport.give_two_active_passkeys!(destination_operator)
    destination = BaseSelectorBootstrapAuthority.call(surface: :org, principal: destination_operator)
    source_token = @token
    source_evidence = StepUpEvidenceValue.new(
      acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time.to_i,
      sid: step_up_grant.public_id, sub: OidcSubject.for(@operator, resource_type: "operator"),
      client_id: step_up_client.client_id, aud: [step_up_client.aud], jti: step_up_grant.oidc_jti,
    )
    transfer =
      OpBaseOrgRecord.connected_to(role: :writing) do
        OperatorToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @operator,
            surface: "org",
            subject_public_id: @source.account.public_id,
            avatar_public_id: @avatar_result.avatar.public_id,
            target_surface: "org",
            target_collective_public_id: destination.collective.public_id,
            step_up_token: source_token, step_up_evidence: source_evidence,
          )
        end
      end

    post base_org_accept_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: base_browser_headers,
         as: :json

    assert_response :forbidden
    assert_equal "pending", transfer.reload.state
    assert_equal "org", @avatar_result.avatar.reload.current_ownership_period.owner_surface
  end

  test "destination-side org authority cannot cancel an app-originated transfer" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    source_now = OpBaseAppRecord.database_now
    source_token = ClientToken.create!(
      authentication_epoch: @target_client.authentication_epoch, user: @target_client,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_now + 1.hour,
    )
    source_token.update!(root_login_established_at: source_now, established_authentication_method: "passkey")
    source_token.rotate_refresh_token!(now: source_now)
    source_token.device_session_record!
    source_client_config = OidcClientRegistry.find!("base-app-ww")
    source_grant = OpAppGrant.create!(
      authentication_epoch: source_token.authentication_epoch, client_token: source_token,
      oidc_client_id: source_client_config.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(source_now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_now + 1.hour,
    )
    source_grant.issue_refresh_token!(now: source_now)
    source_evidence = StepUpEvidenceValue.new(
      acr: source_grant.oidc_acr, amr: ["passkey"], auth_time: source_now.to_i, sid: source_grant.public_id,
      sub: OidcSubject.for(@target_client, resource_type: "client"), client_id: source_client_config.client_id,
      aud: [source_client_config.aud], jti: source_grant.oidc_jti,
    )
    transfer =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RequestOperation.call(
            actor: @target_client,
            surface: "app",
            subject_public_id: @target.account.public_id,
            avatar_public_id: @target.avatar.public_id,
            target_surface: "org",
            target_collective_public_id: @source.collective.public_id,
            step_up_token: source_token, step_up_evidence: source_evidence,
          )
        end
      end

    post base_org_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: base_browser_headers,
         as: :json

    assert_response :forbidden
    assert_equal "pending", transfer.reload.state
    assert_equal "app", @target.avatar.reload.current_ownership_period.owner_surface
  end

  test "registry accept transport completes an explicit registry reservation" do
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    @token.rotate_refresh_token! unless @token.device_session_record.current_refresh_token_id
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @token.authentication_epoch, operator_token: @token,
      oidc_client_id: step_up_client.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator",
                 session_public_id: @token.public_id, base_session_public_id: @token.public_id,
                 oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                 expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                 acr: step_up_grant.oidc_acr, amr: ["passkey"], auth_time: step_up_auth_time,
                 issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: step_up_client.client_id,
                 authentication_context: @token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, @token.public_id]
    step_up_refresh = step_up_grant.issue_refresh_token!
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    establish_avatar_ownership_cutover!
    source_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: source_client)
    source.avatar.current_avatar_persona_binding.revoke!(force: true)
    source_avatar_result = AvatarProvisioning::Create.call(
      actor: source_client,
      subject_type: :persona,
      subject: source.account,
      avatar_params: { moniker: "Enterprise src" },
      handle_params: { handle: "registry-org-http-#{SecureRandom.hex(4)}" },
      owner_surface: "app",
      owner_collective_public_id: source.collective.public_id,
    )

    assert_predicate source_avatar_result, :success?, source_avatar_result.errors.inspect
    source_now = OpBaseAppRecord.database_now
    source_token = ClientToken.create!(
      authentication_epoch: source_client.authentication_epoch, user: source_client,
      user_token_status_id: ClientTokenStatus::ACTIVE, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      discard_at: source_now + 1.hour,
    )
    source_token.update!(root_login_established_at: source_now, established_authentication_method: "passkey")
    source_token.rotate_refresh_token!(now: source_now)
    source_token.device_session_record!
    source_client_config = OidcClientRegistry.find!("base-app-ww")
    source_grant = OpAppGrant.create!(
      authentication_epoch: source_token.authentication_epoch, client_token: source_token,
      oidc_client_id: source_client_config.client_id, oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16), oidc_auth_time: Time.at(source_now.to_i).utc,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR, oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: source_now + 1.hour,
    )
    source_grant.issue_refresh_token!(now: source_now)
    source_evidence = StepUpEvidenceValue.new(
      acr: source_grant.oidc_acr, amr: ["passkey"], auth_time: source_now.to_i, sid: source_grant.public_id,
      sub: OidcSubject.for(source_client, resource_type: "client"), client_id: source_client_config.client_id,
      aud: [source_client_config.aud], jti: source_grant.oidc_jti,
    )
    reservation =
      OpBaseAppRecord.connected_to(role: :writing) do
        ClientToken.transaction do
          AvatarOwnershipTransfers::RegistryRequestOperation.call(
            actor: source_client,
            surface: "app",
            subject_public_id: source.account.public_id,
            avatar_public_id: source_avatar_result.avatar.public_id,
            target_surface: "org",
            target_collective_public_id: @source.collective.public_id,
            idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a48",
            request_fingerprint: registry_request_fingerprint(
              actor: source_client,
              surface: "app",
              subject_public_id: source.account.public_id,
              avatar_public_id: source_avatar_result.avatar.public_id,
              target_surface: "org",
              target_collective_public_id: @source.collective.public_id,
            ),
            step_up_token: source_token, step_up_evidence: source_evidence,
          )
        end
      end

    post base_org_accept_avatar_ownership_transfer_url(
      reservation.public_id,
      host: @host,
      ri: "jp",
    ),
         params: { transfer_kind: "registry" },
         headers: base_browser_headers,
         as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal "registry", body.fetch("transfer_kind")
    assert_equal "accepted", body.fetch("status")
    assert_equal "org", source_avatar_result.avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id,
                 source_avatar_result.avatar.current_ownership_period.owner_collective_public_id
  end

  private

  def select_source_avatar!
    BaseSwitcherAuthority.switch(
      surface: :org,
      principal: @operator,
      session: @token,
      params: {
        account_public_id: @source.account.public_id,
        organization_public_id: @source.collective.public_id,
        organization_unit_public_id: @source.unit.public_id,
        avatar_public_id: @avatar_result.avatar.public_id,
      },
    )
  end

  def base_browser_headers(operator: @operator, token: @token)
    rp_headers = as_staff_headers(operator, host: @host, session_public_id: token.public_id)
    rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    rp_client = OidcClientRegistry.find!("base-org-ww")
    rp_key = [rp_client.client_id, rp_token.public_id]
    @base_browser_rp_credentials ||= {}
    issue_base_browser_credentials!(rp_headers, rp_token, rp_client, rp_key)
    access, refresh = @base_browser_rp_credentials.fetch(rp_key)
    rp_local_session = enroll_base_browser_session!(access, rp_client)
    select_base_browser_persona!(operator, token, rp_local_session)

    cookie = [
      rp_headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh)}",
      "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{rp_local_session.public_id}",
    ].join("; ")
    rp_headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)
  end

  def enroll_base_browser_session!(access, client)
    payload, = JWT.decode(access, nil, false)
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client(client.client_id),
      issuer: payload.fetch("iss"),
      subject: payload.fetch("sub"),
      sid: payload.fetch("sid"),
      absolute_expires_at: Time.at(payload.fetch("exp")).utc,
    )
    return enrollment.session if enrollment.success?

    if enrollment.outcome == :already_enrolled
      session = existing_base_browser_session(payload, client)
      return session if session
    end

    raise ArgumentError, "RP session enrollment failed: #{enrollment.outcome}"
  end

  def existing_base_browser_session(payload, client)
    binding = RpBaseOrgOpSessionBinding.includes(:identity_binding).find_by(
      issuer: payload.fetch("iss"), realm: RpBaseOrgSession::REALM,
      client_id: client.client_id, sid: payload.fetch("sid"), revoked_at: nil,
    )
    return unless binding&.identity_binding&.subject == payload.fetch("sub")

    RpBaseOrgSession.includes(:op_session_binding).find_by(
      op_session_binding_id: binding.id, revoked_at: nil,
    )
  end

  def select_base_browser_persona!(operator, token, rp_session)
    return if rp_session.selected_actor_context?

    context = {
      account_public_id: token.selected_account_public_id,
      organization_public_id: token.selected_collective_public_id,
      organization_unit_public_id: token.selected_collective_unit_public_id,
      avatar_public_id: token.selected_avatar_public_id,
    }
    actor_context = context.except(:avatar_public_id)
    BaseSelectorAuthority.select!(
      surface: :org, principal: operator, session: rp_session, params: actor_context,
    )
    BaseSwitcherAuthority.switch(
      surface: :org, principal: operator, session: rp_session, params: context,
    ) if context[:avatar_public_id].present?
  end

  def issue_base_browser_credentials!(rp_headers, rp_token, rp_client, rp_key)
    return if @base_browser_rp_credentials[rp_key] || !rp_token.currently_usable?
    return if rp_token.device_session_id && OpOrgGrant.exists?(
      device_session_id: rp_token.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )

    rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
    rp_now = Time.current
    rp_session = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: rp_token,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: rp_now,
      refresh_token_expires_at: rp_now + 10.minutes,
    )
    rp_access = AuthenticationTokenService.encode(
      rp_token.actor_record,
      host: rp_headers.fetch("Host"),
      resource_type: "operator",
      session_public_id: rp_token.public_id,
      base_session_public_id: rp_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: rp_now + 10.minutes,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(rp_client),
      audiences: [rp_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
      subject: OidcSubject.for(rp_token.actor_record, resource_type: "operator"),
      client_id: rp_client.client_id,
      authentication_context: rp_token.strict_authentication_context_value.to_s,
    )
    @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
  end

  def registry_request_fingerprint(actor:, surface:, subject_public_id:, avatar_public_id:, target_surface:,
                                   target_collective_public_id:)
    Digest::SHA256.hexdigest(
      [
        "avatar_transfer", surface, actor.public_id, subject_public_id, avatar_public_id,
        target_surface, target_collective_public_id,
      ].join("\0"),
    )
  end

  def org_request_params
    { target_surface: "app", target_collective_public_id: @target.collective.public_id }
  end

  def establish_avatar_ownership_cutover!
    AvatarOwnershipCutover.create!(
      id: AvatarOwnershipCutover::CUTOVER_ID,
      cutover_at: Time.utc(2030, 1, 1),
    )
  end
end
