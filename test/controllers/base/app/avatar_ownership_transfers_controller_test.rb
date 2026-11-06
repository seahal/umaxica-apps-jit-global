# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class Base::App::AvatarOwnershipTransfersControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    @client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @client_token = ClientToken.create!(authentication_epoch: 0, user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: @client_token)

    @operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    @operator = OperatorPasskeyTestSupport.give_two_active_passkeys!(@operator)
    @target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    @operator_token = OperatorToken.create!(authentication_epoch: 0, staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @operator_token)
  end

  test "registry request transport is refused before the verified ownership cutover" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a49"
    headers = base_browser_headers.merge("Idempotency-Key" => key)
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params,
           headers: headers,
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal "registry transfer admission requires the verified Avatar ownership cutover", response.body
    assert_not AvatarOwnershipCutover.established?
    assert_nil @client_token.reload.last_step_up_at
  end

  test "registry request transport replays the same operation for a stable idempotency key" do
    establish_avatar_ownership_cutover!
    headers = base_browser_headers
    grant = OpAppGrant.find_by!(client_token: @client_token, oidc_client_id: "base-app-ww")
    now = OpBaseAppRecord.database_now
    auth_time = Time.at(now.to_i).utc
    amr = ["passkey"]
    grant.update!(
      oidc_auth_time: auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(amr),
      oidc_jti: SecureRandom.uuid,
    )
    client = OidcClientRegistry.find!("base-app-ww")
    access = AuthenticationTokenService.encode(
      @client,
      host: headers.fetch("Host"),
      resource_type: "client",
      expires_at: now + 10.minutes,
      session_public_id: @client_token.public_id,
      base_session_public_id: @client_token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      scopes: %w(openid profile),
      acr: grant.oidc_acr,
      amr: amr,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      subject: OidcSubject.for(@client, resource_type: "client"),
      auth_time: auth_time,
      client_id: client.client_id,
      authentication_context: @client_token.strict_authentication_context_value.to_s,
    )
    cookie =
      headers.fetch("Cookie").split("; ").reject do |pair|
        pair.start_with?("#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=")
      end
    cookie << "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}"
    cookie_header = cookie.join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a46"
    headers = headers.merge("Idempotency-Key" => key)
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params,
         headers: headers,
         as: :json

    assert_response :success
    first = response.parsed_body

    assert_equal "registry", first.fetch("transfer_kind")
    assert_equal "pending", first.fetch("status")
    assert_nil @client_token.reload.last_step_up_at

    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params,
         headers: headers,
         as: :json

    assert_response :success
    replay = response.parsed_body

    assert_equal first.fetch("transfer_public_id"), replay.fetch("transfer_public_id")
    assert_equal 1, AvatarTransferReservation.where(idempotency_key: key).count
    assert_nil @client_token.reload.last_step_up_at
  end

  test "registry request refuses a reused idempotency key with different input" do
    establish_avatar_ownership_cutover!
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a53"
    headers = base_browser_headers.merge("Idempotency-Key" => key)
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params, headers: headers, as: :json

    assert_response :success
    recorded = AvatarTransferReservation.find_by!(idempotency_key: key).attributes
    other_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    other_target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: other_operator)

    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: { target_surface: "org", target_collective_public_id: other_target.collective.public_id },
           headers: headers,
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal recorded, AvatarTransferReservation.find_by!(idempotency_key: key).attributes
  end

  test "registry request refuses a reused idempotency key from a different initiator" do
    establish_avatar_ownership_cutover!
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a54"
    headers = base_browser_headers.merge("Idempotency-Key" => key)
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    first_local_session = enrollment.session
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params, headers: headers, as: :json

    assert_response :success
    recorded = AvatarTransferReservation.find_by!(idempotency_key: key).attributes
    other_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    other_source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other_client)
    other_token = ClientToken.create!(authentication_epoch: 0, user: other_client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :app, principal: other_client, session: other_token)
    step_up_headers = base_browser_headers(principal: other_client, token: other_token)
    step_up_actor = other_client
    step_up_token = other_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]

    headers = base_browser_headers(principal: other_client, token: other_token).merge("Idempotency-Key" => key)
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    assert_not_equal first_local_session.id, enrollment.session.id
    assert_not_equal first_local_session.op_session_binding_id, enrollment.session.op_session_binding_id
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: other_source.account.public_id,
          organization_public_id: other_source.collective.public_id,
          organization_unit_public_id: other_source.unit.public_id,
          avatar_public_id: other_source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params,
           headers: headers,
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal recorded, AvatarTransferReservation.find_by!(idempotency_key: key).attributes
  end

  test "keyless legacy request is refused after the ownership cutover" do
    establish_avatar_ownership_cutover!
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]

    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    assert_no_difference [-> { AvatarOwnershipTransfer.count }, -> { AvatarTransferReservation.count }] do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params, headers: headers, as: :json
    end

    assert_response :unprocessable_content
    assert_equal "legacy Avatar transfer operations are unavailable after cutover", response.body
  end

  test "registry cancel transport is refused before the verified ownership cutover" do
    base_browser_headers(principal: @client, token: @client_token)
    direct_step_up_client = OidcClientRegistry.find!("base-app-ww")
    direct_step_up_now = OpBaseAppRecord.database_now
    direct_step_up_auth_time = Time.at(direct_step_up_now.to_i).utc
    direct_step_up_grant = OpAppGrant.find_by!(
      client_token: @client_token, oidc_client_id: direct_step_up_client.client_id,
    )
    direct_step_up_grant.update!(
      oidc_auth_time: direct_step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), oidc_jti: SecureRandom.uuid,
    )
    direct_step_up_evidence = StepUpEvidenceValue.new(
      acr: direct_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: direct_step_up_auth_time.to_i,
      sid: direct_step_up_grant.public_id,
      sub: OidcSubject.for(@client, resource_type: "client"), client_id: direct_step_up_client.client_id,
      aud: [direct_step_up_client.aud], jti: direct_step_up_grant.oidc_jti,
    )
    reservation =
      @client_token.class.transaction do
        AvatarOwnershipTransfers::RegistryRequestOperation.call(
          actor: @client,
          surface: "app",
          subject_public_id: @source.account.public_id,
          avatar_public_id: @source.avatar.public_id,
          target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a51",
          request_fingerprint: registry_request_fingerprint(
            actor: @client,
            surface: "app",
            subject_public_id: @source.account.public_id,
            avatar_public_id: @source.avatar.public_id,
            target_surface: "org",
            target_collective_public_id: @target.collective.public_id,
          ),
          step_up_token: @client_token, step_up_evidence: direct_step_up_evidence,
        )
      end

    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_cancel_avatar_ownership_transfer_url(
      reservation.public_id,
      host: @host,
      ri: "jp",
    ),
         params: { transfer_kind: "registry" },
         headers: headers,
         as: :json

    assert_response :unprocessable_content
    assert_equal "registry transfer admission requires the verified Avatar ownership cutover", response.body
    assert_equal "pending", reservation.reload.state
    assert_not AvatarOwnershipCutover.established?
  end

  test "registry accept transport completes an explicit registry reservation" do
    establish_avatar_ownership_cutover!
    result = AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Bureau source" },
      handle_params: { handle: "registry-http-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )

    assert_predicate result, :success?, result.errors.inspect

    @operator_token.device_session_record!
    @operator_token.rotate_refresh_token! unless @operator_token.device_session_record.current_refresh_token_id
    direct_step_up_client = OidcClientRegistry.find!("base-org-ww")
    direct_step_up_now = OpBaseOrgRecord.database_now
    direct_step_up_auth_time = Time.at(direct_step_up_now.to_i).utc
    direct_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: @operator_token.authentication_epoch, operator_token: @operator_token,
      device_session_id: @operator_token.device_session_id, oidc_client_id: direct_step_up_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: direct_step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: direct_step_up_now + 10.minutes,
    )
    direct_step_up_grant.issue_refresh_token!(now: direct_step_up_now)
    direct_step_up_evidence = StepUpEvidenceValue.new(
      acr: direct_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: direct_step_up_auth_time.to_i,
      sid: direct_step_up_grant.public_id,
      sub: OidcSubject.for(@operator, resource_type: "operator"), client_id: direct_step_up_client.client_id,
      aud: [direct_step_up_client.aud], jti: direct_step_up_grant.oidc_jti,
    )

    reservation =
      @operator_token.class.transaction do
        AvatarOwnershipTransfers::RegistryRequestOperation.call(
          actor: @operator,
          surface: "org",
          subject_public_id: @target.account.public_id,
          avatar_public_id: result.avatar.public_id,
          target_surface: "app",
          target_collective_public_id: @source.collective.public_id,
          idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a47",
          request_fingerprint: registry_request_fingerprint(
            actor: @operator,
            surface: "org",
            subject_public_id: @target.account.public_id,
            avatar_public_id: result.avatar.public_id,
            target_surface: "app",
            target_collective_public_id: @source.collective.public_id,
          ),
          step_up_token: @operator_token, step_up_evidence: direct_step_up_evidence,
        )
      end

    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_accept_avatar_ownership_transfer_url(
      reservation.public_id,
      host: @host,
      ri: "jp",
    ),
         params: { transfer_kind: "registry" },
         headers: headers,
         as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal "registry", body.fetch("transfer_kind")
    assert_equal "accepted", body.fetch("status")
    assert_equal "app", result.avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id, result.avatar.current_ownership_period.owner_collective_public_id
  end

  test "request binds the selected Avatar despite a submitted Avatar id" do
    selected_avatar_id = @client_token.reload.selected_avatar_public_id
    other_surface_avatar = AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Other surface" },
      handle_params: { handle: "avatar-transfer-other-surface-#{SecureRandom.hex(5)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )

    assert_predicate other_surface_avatar, :success?, other_surface_avatar.errors.inspect
    headers = base_browser_headers(principal: @client, token: @client_token)
    client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.find_by!(client_token: @client_token, oidc_client_id: client.client_id)
    now = OpBaseAppRecord.database_now
    auth_time = Time.at(now.to_i).utc
    amr = ["passkey"]
    grant.update!(
      oidc_auth_time: auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(amr),
      oidc_jti: SecureRandom.uuid,
    )
    access = AuthenticationTokenService.encode(
      @client,
      host: headers.fetch("Host"),
      resource_type: "client",
      expires_at: now + 10.minutes,
      session_public_id: @client_token.public_id,
      base_session_public_id: @client_token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      scopes: %w(openid profile),
      acr: grant.oidc_acr,
      amr: amr,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      subject: OidcSubject.for(@client, resource_type: "client"),
      auth_time: auth_time,
      client_id: client.client_id,
      authentication_context: @client_token.strict_authentication_context_value.to_s,
    )
    key = [client.client_id, @client_token.public_id]
    refresh = @base_browser_rp_credentials.fetch(key).last
    @base_browser_rp_credentials[key] = [access, refresh]

    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params.merge(avatar_public_id: other_surface_avatar.avatar.public_id),
         headers: headers,
         as: :json

    assert_response :success
    transfer = AvatarOwnershipTransfer.find_by!(public_id: response.parsed_body.fetch("transfer_public_id"))

    assert_equal "pending", transfer.state
    assert_equal @source.avatar.id, transfer.avatar_id
    assert_equal selected_avatar_id, @client_token.reload.selected_avatar_public_id
    assert_nil @client_token.last_step_up_at
  end

  test "request is denied without Step-Up" do
    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      http_headers_11 =
        begin
          rp_headers = as_user_headers(@client, host: @host, session_public_id: @client_token.public_id)
          rp_host = rp_headers["Host"]
          rp_route =
            begin
              Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
            rescue ActionController::RoutingError
              nil
            end
          rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
            rp_client_id =
              case rp_family
              when "base" then "base-#{rp_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{rp_family}-#{rp_surface}-jp"
              end
            rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            rp_client = OidcClientRegistry.find!(rp_client_id)
            rp_key = [rp_client.client_id, rp_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id,
                  oidc_client_id: rp_client.client_id,
                  revoked_at: nil,
                ))
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                rp_token.actor_record, host: rp_host, resource_type: "client",
                                       session_public_id: rp_token.public_id,
                                       base_session_public_id: rp_token.public_id,
                                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                       subject: OidcSubject.for(
                                         rp_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[rp_key]
              rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
              rp_cookie = [
                rp_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              ].join("; ")
              rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
            end
          end
          rp_headers
        end
      headers = http_headers_11
      step_up_client = OidcClientRegistry.find!("base-app-ww")
      step_up_grant = OpAppGrant.find_by!(client_token: @client_token, oidc_client_id: step_up_client.client_id)
      enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
        subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
        absolute_expires_at: 1.hour.from_now,
      )

      assert_predicate enrollment, :success?
      local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
      cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
      headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
      if enrollment.session.instance_of?(RpBaseAppSession)
        RpBaseAppRecord.connected_to(role: :writing) do
          RpBaseAppSessionSelection.create!(
            rp_session_id: enrollment.session.id,
            account_public_id: @source.account.public_id,
            organization_public_id: @source.collective.public_id,
            organization_unit_public_id: @source.unit.public_id,
            avatar_public_id: @source.avatar.public_id,
            selected_at: Time.current,
          )
        end
      end
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: headers, as: :json

      assert_response :unprocessable_content
    end
  end

  test "request is denied when the selected persona is no longer an owner member" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    membership = @source.account.persona_memberships.find_by!(enterprise: @source.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: headers,
           as: :json

      assert_response :forbidden
    end
  end

  test "request is refused after the client principal enters a login-blocked status" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    @client.update!(status_id: ClientStatus::RESERVED)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: headers,
           as: :json

      # The Avatar owner rechecks the verified RP actor and rejects a login-blocked identity.
      assert_response :unauthorized
      assert_not_includes response.headers["WWW-Authenticate"].to_s, "insufficient_user_authentication"
    end
  end

  test "an org principal cannot use the app transfer endpoint" do
    headers = as_staff_headers(@operator, host: @host, session_public_id: @operator_token.public_id)

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: headers,
           as: :json

      assert_response :unauthorized
    end
  end

  test "a client cannot accept a transfer addressed to another enterprise" do
    destination_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
    )
    destination = BaseSelectorBootstrapAuthority.call(surface: :app, principal: destination_client)
    headers = base_browser_headers(principal: @client, token: @client_token)
    client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.find_by!(client_token: @client_token, oidc_client_id: client.client_id)
    now = OpBaseAppRecord.database_now
    auth_time = Time.at(now.to_i).utc
    amr = ["passkey"]
    grant.update!(
      oidc_auth_time: auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(amr),
      oidc_jti: SecureRandom.uuid,
    )
    evidence = StepUpEvidenceValue.new(
      acr: grant.oidc_acr,
      amr: amr,
      auth_time: auth_time.to_i,
      sid: grant.public_id,
      sub: OidcSubject.for(@client, resource_type: "client"),
      client_id: client.client_id,
      aud: [client.aud],
      jti: grant.oidc_jti,
    )
    access = AuthenticationTokenService.encode(
      @client,
      host: headers.fetch("Host"),
      resource_type: "client",
      expires_at: now + 10.minutes,
      session_public_id: @client_token.public_id,
      base_session_public_id: @client_token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      scopes: %w(openid profile),
      acr: grant.oidc_acr,
      amr: amr,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      subject: OidcSubject.for(@client, resource_type: "client"),
      auth_time: auth_time,
      client_id: client.client_id,
      authentication_context: @client_token.strict_authentication_context_value.to_s,
    )
    key = [client.client_id, @client_token.public_id]
    refresh = @base_browser_rp_credentials.fetch(key).last
    @base_browser_rp_credentials[key] = [access, refresh]
    transfer =
      @client_token.class.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @client,
          surface: "app",
          subject_public_id: @source.account.public_id,
          avatar_public_id: @source.avatar.public_id,
          target_surface: "app",
          target_collective_public_id: destination.collective.public_id,
          step_up_token: @client_token,
          step_up_evidence: evidence,
        )
      end

    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_accept_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: headers,
         as: :json

    assert_response :forbidden
    assert_equal "pending", transfer.reload.state
    assert_equal "app", @source.avatar.reload.current_ownership_period.owner_surface
  end

  test "destination-side app authority cannot cancel an org-originated transfer" do
    source_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE,
      visibility_id: OperatorVisibility::STAFF,
    )
    source_operator = OperatorPasskeyTestSupport.give_two_active_passkeys!(source_operator)
    source = BaseSelectorBootstrapAuthority.call(surface: :org, principal: source_operator)
    source_token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: source_operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    BaseSelectorAuthority.prepare(surface: :org, principal: source_operator, session: source_token)
    source_token.device_session_record!
    source_token.rotate_refresh_token! unless source_token.device_session_record.current_refresh_token_id
    direct_step_up_client = OidcClientRegistry.find!("base-org-ww")
    direct_step_up_now = OpBaseOrgRecord.database_now
    direct_step_up_auth_time = Time.at(direct_step_up_now.to_i).utc
    direct_step_up_grant = OpOrgGrant.create!(
      authentication_epoch: source_token.authentication_epoch,
      operator_token: source_token,
      device_session_id: source_token.device_session_id,
      oidc_client_id: direct_step_up_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: direct_step_up_auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]),
      refresh_token_expires_at: direct_step_up_now + 10.minutes,
    )
    direct_step_up_grant.issue_refresh_token!(now: direct_step_up_now)
    direct_step_up_evidence = StepUpEvidenceValue.new(
      acr: direct_step_up_grant.oidc_acr,
      amr: ["passkey"],
      auth_time: direct_step_up_auth_time.to_i,
      sid: direct_step_up_grant.public_id,
      sub: OidcSubject.for(source_operator, resource_type: "operator"),
      client_id: direct_step_up_client.client_id,
      aud: [direct_step_up_client.aud],
      jti: direct_step_up_grant.oidc_jti,
    )
    source_avatar_result = AvatarProvisioning::Create.call(
      actor: source_operator,
      subject_type: :agent,
      subject: source.account,
      avatar_params: { moniker: "Org source" },
      handle_params: { handle: "avatar-transfer-org-source-#{SecureRandom.hex(5)}" },
      owner_surface: "org",
      owner_collective_public_id: source.collective.public_id,
    )

    assert_predicate source_avatar_result, :success?, source_avatar_result.errors.inspect
    transfer =
      source_token.class.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: source_operator,
          surface: "org",
          subject_public_id: source.account.public_id,
          avatar_public_id: source_avatar_result.avatar.public_id,
          target_surface: "app",
          target_collective_public_id: @source.collective.public_id,
          step_up_token: source_token,
          step_up_evidence: direct_step_up_evidence,
        )
      end
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]

    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: headers,
         as: :json

    assert_response :forbidden
    assert_equal "pending", transfer.reload.state
    assert_equal "org", source_avatar_result.avatar.reload.current_ownership_period.owner_surface
  end

  test "org target accepts with phishing-resistant Step-Up and no AAL floor" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    http_headers_10 =
      begin
        rp_headers = as_user_headers(@client, host: @host, session_public_id: @client_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpAppGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "client",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    headers = http_headers_10
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params, headers: headers, as: :json

    assert_response :success
    transfer_id = response.parsed_body.fetch("transfer_public_id")

    step_up_headers = as_staff_headers(
      @operator, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), session_public_id: @operator_token.public_id,
    )
    step_up_actor = @operator
    step_up_token = @operator_token
    step_up_token.device_session_record!
    step_up_token.rotate_refresh_token! unless step_up_token.device_session_record.current_refresh_token_id
    step_up_client = OidcClientRegistry.find!("base-org-ww")
    step_up_now = OpBaseOrgRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant = OpOrgGrant.create!(
      authentication_epoch: step_up_token.authentication_epoch, operator_token: step_up_token,
      device_session_id: step_up_token.device_session_id, oidc_client_id: step_up_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), refresh_token_expires_at: step_up_now + 10.minutes,
    )
    step_up_refresh = step_up_grant.issue_refresh_token!(now: step_up_now)
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "operator",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "operator"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    @base_browser_rp_credentials ||= {}
    @base_browser_rp_credentials[[step_up_client.client_id, step_up_token.public_id]] =
      [step_up_access, step_up_refresh]
    http_headers_9 =
      begin
        rp_headers = as_staff_headers(
          @operator, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
                     session_public_id: @operator_token.public_id,
        )
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "org"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpOrgGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpOrgGrant.create!(
              authentication_epoch: 0,
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "operator",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "operator",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    headers = http_headers_9
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-org-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@operator, resource_type: "operator"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    post base_org_accept_avatar_ownership_transfer_url(
      transfer_id, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: "jp",
    ),
         headers: headers, as: :json

    assert_response :success
    assert_equal "accepted", response.parsed_body.fetch("status")
    assert_nil @operator_token.reload.selected_avatar_public_id
    assert_equal "org", @source.avatar.reload.current_ownership_period.owner_surface
    assert_nil @operator_token.selected_avatar_public_id
  end

  test "source cancellation reuses recent Step-Up evidence" do
    headers = base_browser_headers(principal: @client, token: @client_token)
    client = OidcClientRegistry.find!("base-app-ww")
    grant = OpAppGrant.find_by!(client_token: @client_token, oidc_client_id: client.client_id)
    now = OpBaseAppRecord.database_now
    auth_time = Time.at(now.to_i).utc
    amr = ["passkey"]
    grant.update!(
      oidc_auth_time: auth_time,
      oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(amr),
      oidc_jti: SecureRandom.uuid,
    )
    access = AuthenticationTokenService.encode(
      @client,
      host: headers.fetch("Host"),
      resource_type: "client",
      expires_at: now + 10.minutes,
      session_public_id: @client_token.public_id,
      base_session_public_id: @client_token.public_id,
      oidc_sid: grant.public_id,
      oidc_jti: grant.oidc_jti,
      scopes: %w(openid profile),
      acr: grant.oidc_acr,
      amr: amr,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      subject: OidcSubject.for(@client, resource_type: "client"),
      auth_time: auth_time,
      client_id: client.client_id,
      authentication_context: @client_token.strict_authentication_context_value.to_s,
    )
    key = [client.client_id, @client_token.public_id]
    refresh = @base_browser_rp_credentials.fetch(key).last
    @base_browser_rp_credentials[key] = [access, refresh]

    headers = base_browser_headers
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: headers,
         as: :json

    assert_response :success
    transfer_id = response.parsed_body.fetch("transfer_public_id")

    post base_app_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: headers,
         as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
    assert_nil @client_token.reload.last_step_up_at
  end

  test "another authorized source persona can cancel a transfer over HTTP" do
    @client_token.device_session_record!
    @client_token.rotate_refresh_token! unless @client_token.device_session_record.current_refresh_token_id
    direct_step_up_client = OidcClientRegistry.find!("base-app-ww")
    direct_step_up_now = OpBaseAppRecord.database_now
    direct_step_up_auth_time = Time.at(direct_step_up_now.to_i).utc
    direct_step_up_grant = OpAppGrant.create!(
      authentication_epoch: @client_token.authentication_epoch, client_token: @client_token,
      device_session_id: @client_token.device_session_id, oidc_client_id: direct_step_up_client.client_id,
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: direct_step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(["passkey"]), refresh_token_expires_at: direct_step_up_now + 10.minutes,
    )
    direct_step_up_grant.issue_refresh_token!(now: direct_step_up_now)
    direct_step_up_evidence = StepUpEvidenceValue.new(
      acr: direct_step_up_grant.oidc_acr, amr: ["passkey"], auth_time: direct_step_up_auth_time.to_i,
      sid: direct_step_up_grant.public_id,
      sub: OidcSubject.for(@client, resource_type: "client"), client_id: direct_step_up_client.client_id,
      aud: [direct_step_up_client.aud], jti: direct_step_up_grant.oidc_jti,
    )
    transfer =
      @client_token.class.transaction do
        AvatarOwnershipTransfers::RequestOperation.call(
          actor: @client,
          surface: "app",
          subject_public_id: @source.account.public_id,
          avatar_public_id: @source.avatar.public_id,
          target_surface: "org",
          target_collective_public_id: @target.collective.public_id,
          step_up_token: @client_token, step_up_evidence: direct_step_up_evidence,
        )
      end
    other_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    other = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other_client)
    other_persona = other.account
    PersonaMembership.create!(
      persona: other_persona,
      enterprise: @source.collective,
      enterprise_unit: @source.unit,
      membership_kind_id: PersonaMembershipKind::OWNER,
      membership_state_id: PersonaMembershipState::ACTIVE,
      primary: false,
      metadata: {},
    )
    other_token = ClientToken.create!(authentication_epoch: 0, user: other_client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSwitcherAuthority.switch(
      surface: :app,
      principal: other_client,
      session: other_token,
      params: {
        account_public_id: other_persona.public_id,
        organization_public_id: other.collective.public_id,
        organization_unit_public_id: other.unit.public_id,
        avatar_public_id: other.avatar.public_id,
      },
    )
    step_up_headers = base_browser_headers(principal: other_client, token: other_token)
    step_up_actor = other_client
    step_up_token = other_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]

    headers = base_browser_headers(principal: other_client, token: other_token)
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(step_up_actor, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: other.account.public_id,
          organization_public_id: other.collective.public_id,
          organization_unit_public_id: other.unit.public_id,
          avatar_public_id: other.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: headers,
         as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
    assert_equal other_persona.public_id, transfer.reload.cancel_actor_public_id
  end

  test "the source client cannot accept its own outgoing transfer and the denial is audited" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    http_headers_5 =
      begin
        rp_headers = as_user_headers(@client, host: @host, session_public_id: @client_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpAppGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "client",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    headers = http_headers_5
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: headers, as: :json
    transfer_id = response.parsed_body.fetch("transfer_public_id")
    before =
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicle.where(event_id: ClientChronicleEvent::AUTHORIZATION_FAILED).count
      end

    post base_app_accept_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: headers, as: :json

    assert_response :forbidden
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
    assert_equal "pending", AvatarOwnershipTransfer.find_by!(public_id: transfer_id).state
    after =
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicle.where(event_id: ClientChronicleEvent::AUTHORIZATION_FAILED).count
      end

    assert_equal before + 1, after
  end

  test "cancelling a transfer past its expiry marks it expired and answers 410" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]
    http_headers_3 =
      begin
        rp_headers = as_user_headers(@client, host: @host, session_public_id: @client_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpAppGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "client",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    headers = http_headers_3
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: headers, as: :json
    transfer = AvatarOwnershipTransfer.find_by!(public_id: response.parsed_body.fetch("transfer_public_id"))
    # Backdate the pending transfer instead of moving the clock, which would also expire the access token.
    transfer.update_columns(
      requested_at: 2.days.ago,
      expires_at: 1.second.ago,
    )

    post base_app_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: headers, as: :json

    assert_response :gone
    assert_equal "expired", transfer.reload.state
  end

  test "a request naming an unknown target collective is rejected without creating a transfer" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      http_headers_1 =
        begin
          rp_headers = as_user_headers(@client, host: @host, session_public_id: @client_token.public_id)
          rp_host = rp_headers["Host"]
          rp_route =
            begin
              Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
            rescue ActionController::RoutingError
              nil
            end
          rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
            rp_client_id =
              case rp_family
              when "base" then "base-#{rp_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{rp_family}-#{rp_surface}-jp"
              end
            rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            rp_client = OidcClientRegistry.find!(rp_client_id)
            rp_key = [rp_client.client_id, rp_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                !(rp_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: rp_token.device_session_id,
                  oidc_client_id: rp_client.client_id,
                  revoked_at: nil,
                ))
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                rp_token.actor_record, host: rp_host, resource_type: "client",
                                       session_public_id: rp_token.public_id,
                                       base_session_public_id: rp_token.public_id,
                                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                       subject: OidcSubject.for(
                                         rp_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[rp_key]
              rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
              rp_cookie = [
                rp_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              ].join("; ")
              rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
            end
          end
          rp_headers
        end
      headers = http_headers_1
      enrollment = RpCallbackCommitter.call(
        cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
        subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
        absolute_expires_at: 1.hour.from_now,
      )

      assert_predicate enrollment, :success?
      local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
      cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
      headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
      if enrollment.session.instance_of?(RpBaseAppSession)
        RpBaseAppRecord.connected_to(role: :writing) do
          RpBaseAppSessionSelection.create!(
            rp_session_id: enrollment.session.id,
            account_public_id: @source.account.public_id,
            organization_public_id: @source.collective.public_id,
            organization_unit_public_id: @source.unit.public_id,
            avatar_public_id: @source.avatar.public_id,
            selected_at: Time.current,
          )
        end
      end
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params.merge(target_collective_public_id: "no-such-collective"),
           headers: headers, as: :json
    end

    assert_response :unprocessable_content
    assert_equal "target collective not found", response.body
  end

  test "an unknown transfer id is not found" do
    step_up_headers = base_browser_headers(principal: @client, token: @client_token)
    step_up_actor = @client
    step_up_token = @client_token
    step_up_client = OidcClientRegistry.find!("base-app-ww")
    step_up_grant = OpAppGrant.find_by!(client_token: step_up_token, oidc_client_id: step_up_client.client_id)
    step_up_now = OpBaseAppRecord.database_now
    step_up_auth_time = Time.at(step_up_now.to_i).utc
    step_up_amr = ["passkey"]
    step_up_grant.update!(
      oidc_auth_time: step_up_auth_time, oidc_acr: StepUpEvidenceResolver::STEP_UP_ACR,
      oidc_amr: JSON.generate(step_up_amr), oidc_jti: SecureRandom.uuid,
    )
    step_up_access = AuthenticationTokenService.encode(
      step_up_actor, host: step_up_headers.fetch("Host"), resource_type: "client",
                     session_public_id: step_up_token.public_id, base_session_public_id: step_up_token.public_id,
                     oidc_sid: step_up_grant.public_id, oidc_jti: step_up_grant.oidc_jti,
                     expires_at: step_up_now + 10.minutes, scopes: %w(openid profile),
                     acr: step_up_grant.oidc_acr, amr: step_up_amr,
                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(step_up_client),
                     issuer: OidcIssuer.for_client(step_up_client), audiences: [step_up_client.aud],
                     subject: OidcSubject.for(step_up_actor, resource_type: "client"),
                     auth_time: step_up_auth_time, client_id: step_up_client.client_id,
                     authentication_context: step_up_token.strict_authentication_context_value.to_s,
    )
    step_up_key = [step_up_client.client_id, step_up_token.public_id]
    step_up_refresh = @base_browser_rp_credentials.fetch(step_up_key).last
    @base_browser_rp_credentials[step_up_key] = [step_up_access, step_up_refresh]

    http_headers_0 =
      begin
        rp_headers = as_user_headers(@client, host: @host, session_public_id: @client_token.public_id)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "app"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org-ww"
            when "tech" then "tech-org-ww"
            else "#{rp_family}-#{rp_surface}-jp"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OpAppGrant.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OpAppGrant.create!(
              authentication_epoch: 0,
              client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "client",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "client",
                                     ), client_id: rp_client.client_id,
            )
            @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
          end
          if @base_browser_rp_credentials[rp_key]
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            rp_cookie = [
              rp_headers.fetch("Cookie"),
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ].join("; ")
            rp_headers = rp_headers.merge("Cookie" => rp_cookie, "HTTP_COOKIE" => rp_cookie)
          end
        end
        rp_headers
      end
    headers = http_headers_0
    enrollment = RpCallbackCommitter.call(
      cell: RpCellBinding.for_client("base-app-ww"), issuer: OidcIssuer.for_client(step_up_client),
      subject: OidcSubject.for(@client, resource_type: "client"), sid: step_up_grant.public_id,
      absolute_expires_at: 1.hour.from_now,
    )

    assert_predicate enrollment, :success?
    local_cookie = "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{enrollment.session.public_id}"
    cookie_header = [headers.fetch("Cookie"), local_cookie].join("; ")
    headers = headers.merge("Cookie" => cookie_header, "HTTP_COOKIE" => cookie_header)
    if enrollment.session.instance_of?(RpBaseAppSession)
      RpBaseAppRecord.connected_to(role: :writing) do
        RpBaseAppSessionSelection.create!(
          rp_session_id: enrollment.session.id,
          account_public_id: @source.account.public_id,
          organization_public_id: @source.collective.public_id,
          organization_unit_public_id: @source.unit.public_id,
          avatar_public_id: @source.avatar.public_id,
          selected_at: Time.current,
        )
      end
    end
    post base_app_accept_avatar_ownership_transfer_url("no-such-transfer", host: @host),
         headers: headers, as: :json

    assert_response :not_found
  end

  private

  def base_browser_headers(principal: @client, token: @client_token)
    rp_headers = as_user_headers(principal, host: @host, session_public_id: token.public_id)
    rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    rp_client = OidcClientRegistry.find!("base-app-ww")
    rp_key = [rp_client.client_id, rp_token.public_id]
    @base_browser_rp_credentials ||= {}
    issue_base_browser_credentials!(rp_headers, rp_token, rp_client, rp_key)
    access, refresh = @base_browser_rp_credentials.fetch(rp_key)
    cookie = [
      rp_headers.fetch("Cookie"),
      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(refresh)}",
    ].join("; ")
    rp_headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)
  end

  def issue_base_browser_credentials!(rp_headers, rp_token, rp_client, rp_key)
    return if @base_browser_rp_credentials[rp_key] || !rp_token.currently_usable?
    return if rp_token.device_session_id && OpAppGrant.exists?(
      device_session_id: rp_token.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )

    rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
    rp_now = Time.current
    rp_session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: rp_token,
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
      resource_type: "client",
      session_public_id: rp_token.public_id,
      base_session_public_id: rp_token.public_id,
      oidc_sid: rp_session.public_id,
      oidc_jti: rp_session.oidc_jti,
      expires_at: rp_now + 10.minutes,
      scopes: %w(openid profile),
      issuer: OidcIssuer.for_client(rp_client),
      audiences: [rp_client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
      subject: OidcSubject.for(rp_token.actor_record, resource_type: "client"),
      client_id: rp_client.client_id,
    )
    @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
  end

  def request_params
    {
      target_surface: "org",
      target_collective_public_id: @target.collective.public_id,
    }
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

  def establish_avatar_ownership_cutover!
    AvatarOwnershipCutover.create!(
      id: AvatarOwnershipCutover::CUTOVER_ID,
      cutover_at: Time.utc(2030, 1, 1),
    )
  end
end
