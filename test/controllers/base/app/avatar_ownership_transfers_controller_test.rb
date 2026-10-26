# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class Base::App::AvatarOwnershipTransfersControllerTest < ActionDispatch::IntegrationTest
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
    grant_step_up!("avatar_transfer_request")
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a49"
    headers = base_browser_headers.merge("Idempotency-Key" => key)

    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params,
           headers: headers,
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal "registry transfer admission requires the verified Avatar ownership cutover", response.body
    assert_not AvatarOwnershipCutover.established?
    assert_predicate @client_token.reload.last_step_up_at, :present?
  end

  test "registry request transport replays the same operation for a stable idempotency key" do
    establish_avatar_ownership_cutover!
    grant_step_up!("avatar_transfer_request")
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a46"
    headers = base_browser_headers.merge("Idempotency-Key" => key)

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

    assert_response :unprocessable_content
    assert_equal 1, AvatarTransferReservation.where(idempotency_key: key).count

    grant_step_up!("avatar_transfer_request")
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params,
         headers: headers,
         as: :json

    assert_response :success
    second = response.parsed_body

    assert_equal first.fetch("transfer_public_id"), second.fetch("transfer_public_id")
    assert_equal 1, AvatarTransferReservation.where(idempotency_key: key).count
    assert_predicate @client_token.reload.last_step_up_at, :present?
  end

  test "registry request refuses a reused idempotency key with different input" do
    establish_avatar_ownership_cutover!
    grant_step_up!("avatar_transfer_request")
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a53"
    headers = base_browser_headers.merge("Idempotency-Key" => key)
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params, headers: headers, as: :json

    assert_response :success
    recorded = AvatarTransferReservation.find_by!(idempotency_key: key).attributes
    other_operator = Operator.create!(
      security_mode_id: SecurityModeConfigurable::ADVANCED,
      status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
    )
    other_target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: other_operator)
    grant_step_up!("avatar_transfer_request")

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
    grant_step_up!("avatar_transfer_request")
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a54"
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params, headers: base_browser_headers.merge("Idempotency-Key" => key), as: :json

    assert_response :success
    recorded = AvatarTransferReservation.find_by!(idempotency_key: key).attributes
    other_client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    BaseSelectorBootstrapAuthority.call(surface: :app, principal: other_client)
    other_token = ClientToken.create!(authentication_epoch: 0, user: other_client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :app, principal: other_client, session: other_token)
    grant_step_up!("avatar_transfer_request", token: other_token)

    assert_no_difference -> { AvatarTransferReservation.count } do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params,
           headers: base_browser_headers(principal: other_client, token: other_token).merge("Idempotency-Key" => key),
           as: :json
    end

    assert_response :unprocessable_content
    assert_equal recorded, AvatarTransferReservation.find_by!(idempotency_key: key).attributes
  end

  test "keyless legacy request is refused after the ownership cutover" do
    establish_avatar_ownership_cutover!
    grant_step_up!("avatar_transfer_request")

    assert_no_difference [-> { AvatarOwnershipTransfer.count }, -> { AvatarTransferReservation.count }] do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params, headers: base_browser_headers, as: :json
    end

    assert_response :unprocessable_content
    assert_equal "legacy Avatar transfer operations are unavailable after cutover", response.body
  end

  test "registry cancel transport is refused before the verified ownership cutover" do
    reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
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
    )

    grant_step_up!("avatar_transfer_cancel")
    post base_app_cancel_avatar_ownership_transfer_url(
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

    reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
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
    )

    grant_step_up!("avatar_transfer_accept")
    post base_app_accept_avatar_ownership_transfer_url(
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
    assert_equal "app", result.avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id, result.avatar.current_ownership_period.owner_collective_public_id
  end

  test "request requires its own Step-Up scope and preserves the selected Avatar" do
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
    begin
      fv5303 = @client_token
      fv5324 = { scope: "avatar_transfer_accept", surface: "app" }
      fv5319 = fv5324.fetch(:scope)
      fv5309 = fv5324.fetch(:surface)
      fv5304 = (fv5309 == "app") ? fv5303.user : fv5303.staff
      fv5317 = ENV.fetch((fv5309 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5315 = WebAuthn::FakeClient.new("https://#{fv5317}", encoding: :base64url)
      fv5323 = fv5315.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5322 = WebAuthn::RelyingParty.new(id: fv5317, allowed_origins: [fv5315.origin], encoding: :base64url)
      fv5320 = WebAuthn::Credential.from_create(fv5323, relying_party: fv5322)
      fv5321 = (fv5309 == "app") ? fv5304.client_passkeys : fv5304.staff_passkeys
      fv5316 = fv5321.create!(webauthn_id: fv5320.id, public_key: fv5320.public_key, sign_count: 0)
      fv5301 = StepUpRequirement.new(
        step_up_required: true, scope: fv5319, allowed_methods: [:passkey],
        phishing_resistant_required: fv5309 == "org", user_verification_required: fv5309 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5309}", session_binding: fv5303.public_id,
        token_binding: fv5303.public_id, require_session_binding: true, actor_ref: fv5304.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5318 = "/avatar_ownership_transfers"
      fv5318 += "/fixture/#{fv5319.delete_prefix("avatar_transfer_")}" unless fv5319 == "avatar_transfer_request"
      fv5308 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5304, token: fv5303, requirement: fv5301, return_to: fv5318,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5303,
      )
      fv5302 = fv5308.transaction
      fv5313 = ((fv5309 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5302.transaction_id,
      )
      fv5312 = Webauthn::RelyingPartyConfig.new(rp_id: fv5317, origin: fv5315.origin)
      fv5314 = Webauthn::AssertionVerifier.options_for(
        config: fv5312, allow_ids: [fv5316.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5311 = fv5313.issue_bound_passkey_challenge!(
        transaction: fv5302, challenge: fv5314.challenge, rp_id: fv5312.rp_id, origin: fv5312.origin,
      )
      fv5310 = fv5315.get(challenge: fv5314.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5304, transaction: fv5302, session_record: fv5313, config: fv5312,
        reference: fv5311, credential_params: fv5310,
      )
      fv5306 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5309, reference: fv5308.reference)
      fv5307, = fv5306.class.auth_admission_session_class.issue!
      fv5306.attach_auth_session!(auth_session: fv5307, confirmation_ref: SecureRandom.uuid)
      fv5306.confirm_base!(base_token: fv5303, browser_digest: fv5306.base_browser_digest)
      fv5305, = fv5306.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5302.transaction_id,
      )
      fv5300 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5302,
        ceremony_session_ref: fv5305.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5304,
        token: fv5303,
        transaction: fv5302,
        requirement: fv5301,
        result_reference: fv5300.reference,
      )
    end

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      http_headers_13 =
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
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params.merge(avatar_public_id: "attacker-selected-avatar"),
           headers: http_headers_13, as: :json

      assert_response :unprocessable_content
    end
    assert_equal selected_avatar_id, @client_token.reload.selected_avatar_public_id

    begin
      fv5278 = @client_token
      fv5299 = { scope: "avatar_transfer_request", surface: "app" }
      fv5294 = fv5299.fetch(:scope)
      fv5284 = fv5299.fetch(:surface)
      fv5279 = (fv5284 == "app") ? fv5278.user : fv5278.staff
      fv5292 = ENV.fetch((fv5284 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5290 = WebAuthn::FakeClient.new("https://#{fv5292}", encoding: :base64url)
      fv5298 = fv5290.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5297 = WebAuthn::RelyingParty.new(id: fv5292, allowed_origins: [fv5290.origin], encoding: :base64url)
      fv5295 = WebAuthn::Credential.from_create(fv5298, relying_party: fv5297)
      fv5296 = (fv5284 == "app") ? fv5279.client_passkeys : fv5279.staff_passkeys
      fv5291 = fv5296.create!(webauthn_id: fv5295.id, public_key: fv5295.public_key, sign_count: 0)
      fv5276 = StepUpRequirement.new(
        step_up_required: true, scope: fv5294, allowed_methods: [:passkey],
        phishing_resistant_required: fv5284 == "org", user_verification_required: fv5284 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5284}", session_binding: fv5278.public_id,
        token_binding: fv5278.public_id, require_session_binding: true, actor_ref: fv5279.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5293 = "/avatar_ownership_transfers"
      fv5293 += "/fixture/#{fv5294.delete_prefix("avatar_transfer_")}" unless fv5294 == "avatar_transfer_request"
      fv5283 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5279, token: fv5278, requirement: fv5276, return_to: fv5293,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5278,
      )
      fv5277 = fv5283.transaction
      fv5288 = ((fv5284 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5277.transaction_id,
      )
      fv5287 = Webauthn::RelyingPartyConfig.new(rp_id: fv5292, origin: fv5290.origin)
      fv5289 = Webauthn::AssertionVerifier.options_for(
        config: fv5287, allow_ids: [fv5291.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5286 = fv5288.issue_bound_passkey_challenge!(
        transaction: fv5277, challenge: fv5289.challenge, rp_id: fv5287.rp_id, origin: fv5287.origin,
      )
      fv5285 = fv5290.get(challenge: fv5289.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5279, transaction: fv5277, session_record: fv5288, config: fv5287,
        reference: fv5286, credential_params: fv5285,
      )
      fv5281 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5284, reference: fv5283.reference)
      fv5282, = fv5281.class.auth_admission_session_class.issue!
      fv5281.attach_auth_session!(auth_session: fv5282, confirmation_ref: SecureRandom.uuid)
      fv5281.confirm_base!(base_token: fv5278, browser_digest: fv5281.base_browser_digest)
      fv5280, = fv5281.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5277.transaction_id,
      )
      fv5275 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5277,
        ceremony_session_ref: fv5280.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5279,
        token: fv5278,
        transaction: fv5277,
        requirement: fv5276,
        result_reference: fv5275.reference,
      )
    end
    http_headers_12 =
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
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params.merge(avatar_public_id: other_surface_avatar.avatar.public_id),
         headers: http_headers_12, as: :json

    assert_response :success
    transfer = AvatarOwnershipTransfer.find_by!(public_id: response.parsed_body.fetch("transfer_public_id"))

    assert_equal "pending", transfer.state
    assert_equal @source.avatar.id, transfer.avatar_id
    assert_equal selected_avatar_id, @client_token.reload.selected_avatar_public_id
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
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: http_headers_11, as: :json

      assert_response :unprocessable_content
    end
  end

  test "request is denied when the selected persona is no longer an owner member" do
    grant_step_up!("avatar_transfer_request")
    membership = @source.account.persona_memberships.find_by!(enterprise: @source.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: base_browser_headers,
           as: :json

      assert_response :forbidden
    end
  end

  test "request is refused after the client principal enters a login-blocked status" do
    grant_step_up!("avatar_transfer_request")
    headers = base_browser_headers
    @client.update!(status_id: ClientStatus::RESERVED)

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: headers,
           as: :json

      assert_response :forbidden
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
    transfer = AvatarOwnershipTransfers::RequestOperation.call(
      actor: @client,
      surface: "app",
      subject_public_id: @source.account.public_id,
      avatar_public_id: @source.avatar.public_id,
      target_surface: "app",
      target_collective_public_id: destination.collective.public_id,
    )
    grant_step_up!("avatar_transfer_accept")

    post base_app_accept_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: base_browser_headers,
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
    source = BaseSelectorBootstrapAuthority.call(surface: :org, principal: source_operator)
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
    transfer = AvatarOwnershipTransfers::RequestOperation.call(
      actor: source_operator,
      surface: "org",
      subject_public_id: source.account.public_id,
      avatar_public_id: source_avatar_result.avatar.public_id,
      target_surface: "app",
      target_collective_public_id: @source.collective.public_id,
    )
    grant_step_up!("avatar_transfer_cancel")

    post base_app_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: base_browser_headers,
         as: :json

    assert_response :forbidden
    assert_equal "pending", transfer.reload.state
    assert_equal "org", source_avatar_result.avatar.reload.current_ownership_period.owner_surface
  end

  test "org target accepts with its operation-specific Step-Up and no AAL floor" do
    begin
      fv5253 = @client_token
      fv5274 = { scope: "avatar_transfer_request", surface: "app" }
      fv5269 = fv5274.fetch(:scope)
      fv5259 = fv5274.fetch(:surface)
      fv5254 = (fv5259 == "app") ? fv5253.user : fv5253.staff
      fv5267 = ENV.fetch((fv5259 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5265 = WebAuthn::FakeClient.new("https://#{fv5267}", encoding: :base64url)
      fv5273 = fv5265.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5272 = WebAuthn::RelyingParty.new(id: fv5267, allowed_origins: [fv5265.origin], encoding: :base64url)
      fv5270 = WebAuthn::Credential.from_create(fv5273, relying_party: fv5272)
      fv5271 = (fv5259 == "app") ? fv5254.client_passkeys : fv5254.staff_passkeys
      fv5266 = fv5271.create!(webauthn_id: fv5270.id, public_key: fv5270.public_key, sign_count: 0)
      fv5251 = StepUpRequirement.new(
        step_up_required: true, scope: fv5269, allowed_methods: [:passkey],
        phishing_resistant_required: fv5259 == "org", user_verification_required: fv5259 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5259}", session_binding: fv5253.public_id,
        token_binding: fv5253.public_id, require_session_binding: true, actor_ref: fv5254.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5268 = "/avatar_ownership_transfers"
      fv5268 += "/fixture/#{fv5269.delete_prefix("avatar_transfer_")}" unless fv5269 == "avatar_transfer_request"
      fv5258 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5254, token: fv5253, requirement: fv5251, return_to: fv5268,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5253,
      )
      fv5252 = fv5258.transaction
      fv5263 = ((fv5259 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5252.transaction_id,
      )
      fv5262 = Webauthn::RelyingPartyConfig.new(rp_id: fv5267, origin: fv5265.origin)
      fv5264 = Webauthn::AssertionVerifier.options_for(
        config: fv5262, allow_ids: [fv5266.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5261 = fv5263.issue_bound_passkey_challenge!(
        transaction: fv5252, challenge: fv5264.challenge, rp_id: fv5262.rp_id, origin: fv5262.origin,
      )
      fv5260 = fv5265.get(challenge: fv5264.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5254, transaction: fv5252, session_record: fv5263, config: fv5262,
        reference: fv5261, credential_params: fv5260,
      )
      fv5256 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5259, reference: fv5258.reference)
      fv5257, = fv5256.class.auth_admission_session_class.issue!
      fv5256.attach_auth_session!(auth_session: fv5257, confirmation_ref: SecureRandom.uuid)
      fv5256.confirm_base!(base_token: fv5253, browser_digest: fv5256.base_browser_digest)
      fv5255, = fv5256.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5252.transaction_id,
      )
      fv5250 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5252,
        ceremony_session_ref: fv5255.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5254,
        token: fv5253,
        transaction: fv5252,
        requirement: fv5251,
        result_reference: fv5250.reference,
      )
    end
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
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: http_headers_10, as: :json

    assert_response :success
    transfer_id = response.parsed_body.fetch("transfer_public_id")

    begin
      fv5228 = @operator_token
      fv5249 = { scope: "avatar_transfer_accept", surface: "org" }
      fv5244 = fv5249.fetch(:scope)
      fv5234 = fv5249.fetch(:surface)
      fv5229 = (fv5234 == "app") ? fv5228.user : fv5228.staff
      fv5242 = ENV.fetch((fv5234 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5240 = WebAuthn::FakeClient.new("https://#{fv5242}", encoding: :base64url)
      fv5248 = fv5240.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5247 = WebAuthn::RelyingParty.new(id: fv5242, allowed_origins: [fv5240.origin], encoding: :base64url)
      fv5245 = WebAuthn::Credential.from_create(fv5248, relying_party: fv5247)
      fv5246 = (fv5234 == "app") ? fv5229.client_passkeys : fv5229.staff_passkeys
      fv5241 = fv5246.create!(webauthn_id: fv5245.id, public_key: fv5245.public_key, sign_count: 0)
      fv5226 = StepUpRequirement.new(
        step_up_required: true, scope: fv5244, allowed_methods: [:passkey],
        phishing_resistant_required: fv5234 == "org", user_verification_required: fv5234 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5234}", session_binding: fv5228.public_id,
        token_binding: fv5228.public_id, require_session_binding: true, actor_ref: fv5229.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5243 = "/avatar_ownership_transfers"
      fv5243 += "/fixture/#{fv5244.delete_prefix("avatar_transfer_")}" unless fv5244 == "avatar_transfer_request"
      fv5233 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5229, token: fv5228, requirement: fv5226, return_to: fv5243,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5228,
      )
      fv5227 = fv5233.transaction
      fv5238 = ((fv5234 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5227.transaction_id,
      )
      fv5237 = Webauthn::RelyingPartyConfig.new(rp_id: fv5242, origin: fv5240.origin)
      fv5239 = Webauthn::AssertionVerifier.options_for(
        config: fv5237, allow_ids: [fv5241.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5236 = fv5238.issue_bound_passkey_challenge!(
        transaction: fv5227, challenge: fv5239.challenge, rp_id: fv5237.rp_id, origin: fv5237.origin,
      )
      fv5235 = fv5240.get(challenge: fv5239.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5229, transaction: fv5227, session_record: fv5238, config: fv5237,
        reference: fv5236, credential_params: fv5235,
      )
      fv5231 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5234, reference: fv5233.reference)
      fv5232, = fv5231.class.auth_admission_session_class.issue!
      fv5231.attach_auth_session!(auth_session: fv5232, confirmation_ref: SecureRandom.uuid)
      fv5231.confirm_base!(base_token: fv5228, browser_digest: fv5231.base_browser_digest)
      fv5230, = fv5231.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5227.transaction_id,
      )
      fv5225 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5227,
        ceremony_session_ref: fv5230.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5229,
        token: fv5228,
        transaction: fv5227,
        requirement: fv5226,
        result_reference: fv5225.reference,
      )
    end
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
    post base_org_accept_avatar_ownership_transfer_url(transfer_id, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: "jp"),
         headers: http_headers_9, as: :json

    assert_response :success
    assert_equal "accepted", response.parsed_body.fetch("status")
    assert_nil @operator_token.reload.selected_avatar_public_id
    assert_equal "org", @source.avatar.reload.current_ownership_period.owner_surface
    assert_nil @operator_token.selected_avatar_public_id
  end

  test "source cancellation requires the cancellation scope" do
    begin
      fv5203 = @client_token
      fv5224 = { scope: "avatar_transfer_request", surface: "app" }
      fv5219 = fv5224.fetch(:scope)
      fv5209 = fv5224.fetch(:surface)
      fv5204 = (fv5209 == "app") ? fv5203.user : fv5203.staff
      fv5217 = ENV.fetch((fv5209 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5215 = WebAuthn::FakeClient.new("https://#{fv5217}", encoding: :base64url)
      fv5223 = fv5215.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5222 = WebAuthn::RelyingParty.new(id: fv5217, allowed_origins: [fv5215.origin], encoding: :base64url)
      fv5220 = WebAuthn::Credential.from_create(fv5223, relying_party: fv5222)
      fv5221 = (fv5209 == "app") ? fv5204.client_passkeys : fv5204.staff_passkeys
      fv5216 = fv5221.create!(webauthn_id: fv5220.id, public_key: fv5220.public_key, sign_count: 0)
      fv5201 = StepUpRequirement.new(
        step_up_required: true, scope: fv5219, allowed_methods: [:passkey],
        phishing_resistant_required: fv5209 == "org", user_verification_required: fv5209 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5209}", session_binding: fv5203.public_id,
        token_binding: fv5203.public_id, require_session_binding: true, actor_ref: fv5204.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5218 = "/avatar_ownership_transfers"
      fv5218 += "/fixture/#{fv5219.delete_prefix("avatar_transfer_")}" unless fv5219 == "avatar_transfer_request"
      fv5208 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5204, token: fv5203, requirement: fv5201, return_to: fv5218,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5203,
      )
      fv5202 = fv5208.transaction
      fv5213 = ((fv5209 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5202.transaction_id,
      )
      fv5212 = Webauthn::RelyingPartyConfig.new(rp_id: fv5217, origin: fv5215.origin)
      fv5214 = Webauthn::AssertionVerifier.options_for(
        config: fv5212, allow_ids: [fv5216.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5211 = fv5213.issue_bound_passkey_challenge!(
        transaction: fv5202, challenge: fv5214.challenge, rp_id: fv5212.rp_id, origin: fv5212.origin,
      )
      fv5210 = fv5215.get(challenge: fv5214.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5204, transaction: fv5202, session_record: fv5213, config: fv5212,
        reference: fv5211, credential_params: fv5210,
      )
      fv5206 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5209, reference: fv5208.reference)
      fv5207, = fv5206.class.auth_admission_session_class.issue!
      fv5206.attach_auth_session!(auth_session: fv5207, confirmation_ref: SecureRandom.uuid)
      fv5206.confirm_base!(base_token: fv5203, browser_digest: fv5206.base_browser_digest)
      fv5205, = fv5206.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5202.transaction_id,
      )
      fv5200 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5202,
        ceremony_session_ref: fv5205.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5204,
        token: fv5203,
        transaction: fv5202,
        requirement: fv5201,
        result_reference: fv5200.reference,
      )
    end
    http_headers_8 =
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
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: http_headers_8, as: :json
    transfer_id = response.parsed_body.fetch("transfer_public_id")

    begin
      fv5178 = @client_token
      fv5199 = { scope: "avatar_transfer_request", surface: "app" }
      fv5194 = fv5199.fetch(:scope)
      fv5184 = fv5199.fetch(:surface)
      fv5179 = (fv5184 == "app") ? fv5178.user : fv5178.staff
      fv5192 = ENV.fetch((fv5184 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5190 = WebAuthn::FakeClient.new("https://#{fv5192}", encoding: :base64url)
      fv5198 = fv5190.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5197 = WebAuthn::RelyingParty.new(id: fv5192, allowed_origins: [fv5190.origin], encoding: :base64url)
      fv5195 = WebAuthn::Credential.from_create(fv5198, relying_party: fv5197)
      fv5196 = (fv5184 == "app") ? fv5179.client_passkeys : fv5179.staff_passkeys
      fv5191 = fv5196.create!(webauthn_id: fv5195.id, public_key: fv5195.public_key, sign_count: 0)
      fv5176 = StepUpRequirement.new(
        step_up_required: true, scope: fv5194, allowed_methods: [:passkey],
        phishing_resistant_required: fv5184 == "org", user_verification_required: fv5184 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5184}", session_binding: fv5178.public_id,
        token_binding: fv5178.public_id, require_session_binding: true, actor_ref: fv5179.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5193 = "/avatar_ownership_transfers"
      fv5193 += "/fixture/#{fv5194.delete_prefix("avatar_transfer_")}" unless fv5194 == "avatar_transfer_request"
      fv5183 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5179, token: fv5178, requirement: fv5176, return_to: fv5193,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5178,
      )
      fv5177 = fv5183.transaction
      fv5188 = ((fv5184 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5177.transaction_id,
      )
      fv5187 = Webauthn::RelyingPartyConfig.new(rp_id: fv5192, origin: fv5190.origin)
      fv5189 = Webauthn::AssertionVerifier.options_for(
        config: fv5187, allow_ids: [fv5191.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5186 = fv5188.issue_bound_passkey_challenge!(
        transaction: fv5177, challenge: fv5189.challenge, rp_id: fv5187.rp_id, origin: fv5187.origin,
      )
      fv5185 = fv5190.get(challenge: fv5189.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5179, transaction: fv5177, session_record: fv5188, config: fv5187,
        reference: fv5186, credential_params: fv5185,
      )
      fv5181 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5184, reference: fv5183.reference)
      fv5182, = fv5181.class.auth_admission_session_class.issue!
      fv5181.attach_auth_session!(auth_session: fv5182, confirmation_ref: SecureRandom.uuid)
      fv5181.confirm_base!(base_token: fv5178, browser_digest: fv5181.base_browser_digest)
      fv5180, = fv5181.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5177.transaction_id,
      )
      fv5175 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5177,
        ceremony_session_ref: fv5180.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5179,
        token: fv5178,
        transaction: fv5177,
        requirement: fv5176,
        result_reference: fv5175.reference,
      )
    end
    http_headers_7 =
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
    post base_app_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: http_headers_7, as: :json

    assert_response :unprocessable_content
    assert_equal "pending", AvatarOwnershipTransfer.find_by!(public_id: transfer_id).state

    begin
      fv5153 = @client_token
      fv5174 = { scope: "avatar_transfer_cancel", surface: "app" }
      fv5169 = fv5174.fetch(:scope)
      fv5159 = fv5174.fetch(:surface)
      fv5154 = (fv5159 == "app") ? fv5153.user : fv5153.staff
      fv5167 = ENV.fetch((fv5159 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5165 = WebAuthn::FakeClient.new("https://#{fv5167}", encoding: :base64url)
      fv5173 = fv5165.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5172 = WebAuthn::RelyingParty.new(id: fv5167, allowed_origins: [fv5165.origin], encoding: :base64url)
      fv5170 = WebAuthn::Credential.from_create(fv5173, relying_party: fv5172)
      fv5171 = (fv5159 == "app") ? fv5154.client_passkeys : fv5154.staff_passkeys
      fv5166 = fv5171.create!(webauthn_id: fv5170.id, public_key: fv5170.public_key, sign_count: 0)
      fv5151 = StepUpRequirement.new(
        step_up_required: true, scope: fv5169, allowed_methods: [:passkey],
        phishing_resistant_required: fv5159 == "org", user_verification_required: fv5159 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5159}", session_binding: fv5153.public_id,
        token_binding: fv5153.public_id, require_session_binding: true, actor_ref: fv5154.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5168 = "/avatar_ownership_transfers"
      fv5168 += "/fixture/#{fv5169.delete_prefix("avatar_transfer_")}" unless fv5169 == "avatar_transfer_request"
      fv5158 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5154, token: fv5153, requirement: fv5151, return_to: fv5168,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5153,
      )
      fv5152 = fv5158.transaction
      fv5163 = ((fv5159 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5152.transaction_id,
      )
      fv5162 = Webauthn::RelyingPartyConfig.new(rp_id: fv5167, origin: fv5165.origin)
      fv5164 = Webauthn::AssertionVerifier.options_for(
        config: fv5162, allow_ids: [fv5166.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5161 = fv5163.issue_bound_passkey_challenge!(
        transaction: fv5152, challenge: fv5164.challenge, rp_id: fv5162.rp_id, origin: fv5162.origin,
      )
      fv5160 = fv5165.get(challenge: fv5164.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5154, transaction: fv5152, session_record: fv5163, config: fv5162,
        reference: fv5161, credential_params: fv5160,
      )
      fv5156 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5159, reference: fv5158.reference)
      fv5157, = fv5156.class.auth_admission_session_class.issue!
      fv5156.attach_auth_session!(auth_session: fv5157, confirmation_ref: SecureRandom.uuid)
      fv5156.confirm_base!(base_token: fv5153, browser_digest: fv5156.base_browser_digest)
      fv5155, = fv5156.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5152.transaction_id,
      )
      fv5150 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5152,
        ceremony_session_ref: fv5155.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5154,
        token: fv5153,
        transaction: fv5152,
        requirement: fv5151,
        result_reference: fv5150.reference,
      )
    end
    http_headers_6 =
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
    post base_app_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: http_headers_6, as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
  end

  test "another authorized source persona can cancel a transfer over HTTP" do
    transfer = AvatarOwnershipTransfers::RequestOperation.call(
      actor: @client,
      surface: "app",
      subject_public_id: @source.account.public_id,
      avatar_public_id: @source.avatar.public_id,
      target_surface: "org",
      target_collective_public_id: @target.collective.public_id,
    )
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
    grant_step_up!("avatar_transfer_cancel", token: other_token)

    post base_app_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: base_browser_headers(principal: other_client, token: other_token),
         as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
    assert_equal other_persona.public_id, transfer.reload.cancel_actor_public_id
  end

  test "the source client cannot accept its own outgoing transfer and the denial is audited" do
    begin
      fv5128 = @client_token
      fv5149 = { scope: "avatar_transfer_request", surface: "app" }
      fv5144 = fv5149.fetch(:scope)
      fv5134 = fv5149.fetch(:surface)
      fv5129 = (fv5134 == "app") ? fv5128.user : fv5128.staff
      fv5142 = ENV.fetch((fv5134 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5140 = WebAuthn::FakeClient.new("https://#{fv5142}", encoding: :base64url)
      fv5148 = fv5140.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5147 = WebAuthn::RelyingParty.new(id: fv5142, allowed_origins: [fv5140.origin], encoding: :base64url)
      fv5145 = WebAuthn::Credential.from_create(fv5148, relying_party: fv5147)
      fv5146 = (fv5134 == "app") ? fv5129.client_passkeys : fv5129.staff_passkeys
      fv5141 = fv5146.create!(webauthn_id: fv5145.id, public_key: fv5145.public_key, sign_count: 0)
      fv5126 = StepUpRequirement.new(
        step_up_required: true, scope: fv5144, allowed_methods: [:passkey],
        phishing_resistant_required: fv5134 == "org", user_verification_required: fv5134 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5134}", session_binding: fv5128.public_id,
        token_binding: fv5128.public_id, require_session_binding: true, actor_ref: fv5129.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5143 = "/avatar_ownership_transfers"
      fv5143 += "/fixture/#{fv5144.delete_prefix("avatar_transfer_")}" unless fv5144 == "avatar_transfer_request"
      fv5133 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5129, token: fv5128, requirement: fv5126, return_to: fv5143,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5128,
      )
      fv5127 = fv5133.transaction
      fv5138 = ((fv5134 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5127.transaction_id,
      )
      fv5137 = Webauthn::RelyingPartyConfig.new(rp_id: fv5142, origin: fv5140.origin)
      fv5139 = Webauthn::AssertionVerifier.options_for(
        config: fv5137, allow_ids: [fv5141.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5136 = fv5138.issue_bound_passkey_challenge!(
        transaction: fv5127, challenge: fv5139.challenge, rp_id: fv5137.rp_id, origin: fv5137.origin,
      )
      fv5135 = fv5140.get(challenge: fv5139.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5129, transaction: fv5127, session_record: fv5138, config: fv5137,
        reference: fv5136, credential_params: fv5135,
      )
      fv5131 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5134, reference: fv5133.reference)
      fv5132, = fv5131.class.auth_admission_session_class.issue!
      fv5131.attach_auth_session!(auth_session: fv5132, confirmation_ref: SecureRandom.uuid)
      fv5131.confirm_base!(base_token: fv5128, browser_digest: fv5131.base_browser_digest)
      fv5130, = fv5131.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5127.transaction_id,
      )
      fv5125 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5127,
        ceremony_session_ref: fv5130.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5129,
        token: fv5128,
        transaction: fv5127,
        requirement: fv5126,
        result_reference: fv5125.reference,
      )
    end
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
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: http_headers_5, as: :json
    transfer_id = response.parsed_body.fetch("transfer_public_id")
    begin
      fv5103 = @client_token
      fv5124 = { scope: "avatar_transfer_accept", surface: "app" }
      fv5119 = fv5124.fetch(:scope)
      fv5109 = fv5124.fetch(:surface)
      fv5104 = (fv5109 == "app") ? fv5103.user : fv5103.staff
      fv5117 = ENV.fetch((fv5109 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5115 = WebAuthn::FakeClient.new("https://#{fv5117}", encoding: :base64url)
      fv5123 = fv5115.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5122 = WebAuthn::RelyingParty.new(id: fv5117, allowed_origins: [fv5115.origin], encoding: :base64url)
      fv5120 = WebAuthn::Credential.from_create(fv5123, relying_party: fv5122)
      fv5121 = (fv5109 == "app") ? fv5104.client_passkeys : fv5104.staff_passkeys
      fv5116 = fv5121.create!(webauthn_id: fv5120.id, public_key: fv5120.public_key, sign_count: 0)
      fv5101 = StepUpRequirement.new(
        step_up_required: true, scope: fv5119, allowed_methods: [:passkey],
        phishing_resistant_required: fv5109 == "org", user_verification_required: fv5109 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5109}", session_binding: fv5103.public_id,
        token_binding: fv5103.public_id, require_session_binding: true, actor_ref: fv5104.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5118 = "/avatar_ownership_transfers"
      fv5118 += "/fixture/#{fv5119.delete_prefix("avatar_transfer_")}" unless fv5119 == "avatar_transfer_request"
      fv5108 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5104, token: fv5103, requirement: fv5101, return_to: fv5118,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5103,
      )
      fv5102 = fv5108.transaction
      fv5113 = ((fv5109 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5102.transaction_id,
      )
      fv5112 = Webauthn::RelyingPartyConfig.new(rp_id: fv5117, origin: fv5115.origin)
      fv5114 = Webauthn::AssertionVerifier.options_for(
        config: fv5112, allow_ids: [fv5116.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5111 = fv5113.issue_bound_passkey_challenge!(
        transaction: fv5102, challenge: fv5114.challenge, rp_id: fv5112.rp_id, origin: fv5112.origin,
      )
      fv5110 = fv5115.get(challenge: fv5114.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5104, transaction: fv5102, session_record: fv5113, config: fv5112,
        reference: fv5111, credential_params: fv5110,
      )
      fv5106 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5109, reference: fv5108.reference)
      fv5107, = fv5106.class.auth_admission_session_class.issue!
      fv5106.attach_auth_session!(auth_session: fv5107, confirmation_ref: SecureRandom.uuid)
      fv5106.confirm_base!(base_token: fv5103, browser_digest: fv5106.base_browser_digest)
      fv5105, = fv5106.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5102.transaction_id,
      )
      fv5100 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5102,
        ceremony_session_ref: fv5105.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5104,
        token: fv5103,
        transaction: fv5102,
        requirement: fv5101,
        result_reference: fv5100.reference,
      )
    end
    before =
      ChronicleRecord.connected_to(role: :writing) do
        ClientChronicle.where(event_id: ClientChronicleEvent::AUTHORIZATION_FAILED).count
      end

    http_headers_4 =
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
    post base_app_accept_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: http_headers_4, as: :json

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
    begin
      fv5078 = @client_token
      fv5099 = { scope: "avatar_transfer_request", surface: "app" }
      fv5094 = fv5099.fetch(:scope)
      fv5084 = fv5099.fetch(:surface)
      fv5079 = (fv5084 == "app") ? fv5078.user : fv5078.staff
      fv5092 = ENV.fetch((fv5084 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5090 = WebAuthn::FakeClient.new("https://#{fv5092}", encoding: :base64url)
      fv5098 = fv5090.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5097 = WebAuthn::RelyingParty.new(id: fv5092, allowed_origins: [fv5090.origin], encoding: :base64url)
      fv5095 = WebAuthn::Credential.from_create(fv5098, relying_party: fv5097)
      fv5096 = (fv5084 == "app") ? fv5079.client_passkeys : fv5079.staff_passkeys
      fv5091 = fv5096.create!(webauthn_id: fv5095.id, public_key: fv5095.public_key, sign_count: 0)
      fv5076 = StepUpRequirement.new(
        step_up_required: true, scope: fv5094, allowed_methods: [:passkey],
        phishing_resistant_required: fv5084 == "org", user_verification_required: fv5084 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5084}", session_binding: fv5078.public_id,
        token_binding: fv5078.public_id, require_session_binding: true, actor_ref: fv5079.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5093 = "/avatar_ownership_transfers"
      fv5093 += "/fixture/#{fv5094.delete_prefix("avatar_transfer_")}" unless fv5094 == "avatar_transfer_request"
      fv5083 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5079, token: fv5078, requirement: fv5076, return_to: fv5093,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5078,
      )
      fv5077 = fv5083.transaction
      fv5088 = ((fv5084 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5077.transaction_id,
      )
      fv5087 = Webauthn::RelyingPartyConfig.new(rp_id: fv5092, origin: fv5090.origin)
      fv5089 = Webauthn::AssertionVerifier.options_for(
        config: fv5087, allow_ids: [fv5091.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5086 = fv5088.issue_bound_passkey_challenge!(
        transaction: fv5077, challenge: fv5089.challenge, rp_id: fv5087.rp_id, origin: fv5087.origin,
      )
      fv5085 = fv5090.get(challenge: fv5089.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5079, transaction: fv5077, session_record: fv5088, config: fv5087,
        reference: fv5086, credential_params: fv5085,
      )
      fv5081 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5084, reference: fv5083.reference)
      fv5082, = fv5081.class.auth_admission_session_class.issue!
      fv5081.attach_auth_session!(auth_session: fv5082, confirmation_ref: SecureRandom.uuid)
      fv5081.confirm_base!(base_token: fv5078, browser_digest: fv5081.base_browser_digest)
      fv5080, = fv5081.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5077.transaction_id,
      )
      fv5075 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5077,
        ceremony_session_ref: fv5080.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5079,
        token: fv5078,
        transaction: fv5077,
        requirement: fv5076,
        result_reference: fv5075.reference,
      )
    end
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
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: http_headers_3, as: :json
    transfer = AvatarOwnershipTransfer.find_by!(public_id: response.parsed_body.fetch("transfer_public_id"))
    # Backdate the pending transfer instead of moving the clock, which would also expire the access token.
    transfer.update_columns(
      requested_at: 2.days.ago,
      expires_at: 1.second.ago,
    )
    begin
      fv5053 = @client_token
      fv5074 = { scope: "avatar_transfer_cancel", surface: "app" }
      fv5069 = fv5074.fetch(:scope)
      fv5059 = fv5074.fetch(:surface)
      fv5054 = (fv5059 == "app") ? fv5053.user : fv5053.staff
      fv5067 = ENV.fetch((fv5059 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5065 = WebAuthn::FakeClient.new("https://#{fv5067}", encoding: :base64url)
      fv5073 = fv5065.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5072 = WebAuthn::RelyingParty.new(id: fv5067, allowed_origins: [fv5065.origin], encoding: :base64url)
      fv5070 = WebAuthn::Credential.from_create(fv5073, relying_party: fv5072)
      fv5071 = (fv5059 == "app") ? fv5054.client_passkeys : fv5054.staff_passkeys
      fv5066 = fv5071.create!(webauthn_id: fv5070.id, public_key: fv5070.public_key, sign_count: 0)
      fv5051 = StepUpRequirement.new(
        step_up_required: true, scope: fv5069, allowed_methods: [:passkey],
        phishing_resistant_required: fv5059 == "org", user_verification_required: fv5059 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5059}", session_binding: fv5053.public_id,
        token_binding: fv5053.public_id, require_session_binding: true, actor_ref: fv5054.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5068 = "/avatar_ownership_transfers"
      fv5068 += "/fixture/#{fv5069.delete_prefix("avatar_transfer_")}" unless fv5069 == "avatar_transfer_request"
      fv5058 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5054, token: fv5053, requirement: fv5051, return_to: fv5068,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5053,
      )
      fv5052 = fv5058.transaction
      fv5063 = ((fv5059 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5052.transaction_id,
      )
      fv5062 = Webauthn::RelyingPartyConfig.new(rp_id: fv5067, origin: fv5065.origin)
      fv5064 = Webauthn::AssertionVerifier.options_for(
        config: fv5062, allow_ids: [fv5066.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5061 = fv5063.issue_bound_passkey_challenge!(
        transaction: fv5052, challenge: fv5064.challenge, rp_id: fv5062.rp_id, origin: fv5062.origin,
      )
      fv5060 = fv5065.get(challenge: fv5064.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5054, transaction: fv5052, session_record: fv5063, config: fv5062,
        reference: fv5061, credential_params: fv5060,
      )
      fv5056 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5059, reference: fv5058.reference)
      fv5057, = fv5056.class.auth_admission_session_class.issue!
      fv5056.attach_auth_session!(auth_session: fv5057, confirmation_ref: SecureRandom.uuid)
      fv5056.confirm_base!(base_token: fv5053, browser_digest: fv5056.base_browser_digest)
      fv5055, = fv5056.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5052.transaction_id,
      )
      fv5050 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5052,
        ceremony_session_ref: fv5055.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5054,
        token: fv5053,
        transaction: fv5052,
        requirement: fv5051,
        result_reference: fv5050.reference,
      )
    end

    http_headers_2 =
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
    post base_app_cancel_avatar_ownership_transfer_url(transfer.public_id, host: @host),
         headers: http_headers_2, as: :json

    assert_response :gone
    assert_equal "expired", transfer.reload.state
  end

  test "a request naming an unknown target collective is rejected without creating a transfer" do
    begin
      fv5028 = @client_token
      fv5049 = { scope: "avatar_transfer_request", surface: "app" }
      fv5044 = fv5049.fetch(:scope)
      fv5034 = fv5049.fetch(:surface)
      fv5029 = (fv5034 == "app") ? fv5028.user : fv5028.staff
      fv5042 = ENV.fetch((fv5034 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5040 = WebAuthn::FakeClient.new("https://#{fv5042}", encoding: :base64url)
      fv5048 = fv5040.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5047 = WebAuthn::RelyingParty.new(id: fv5042, allowed_origins: [fv5040.origin], encoding: :base64url)
      fv5045 = WebAuthn::Credential.from_create(fv5048, relying_party: fv5047)
      fv5046 = (fv5034 == "app") ? fv5029.client_passkeys : fv5029.staff_passkeys
      fv5041 = fv5046.create!(webauthn_id: fv5045.id, public_key: fv5045.public_key, sign_count: 0)
      fv5026 = StepUpRequirement.new(
        step_up_required: true, scope: fv5044, allowed_methods: [:passkey],
        phishing_resistant_required: fv5034 == "org", user_verification_required: fv5034 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5034}", session_binding: fv5028.public_id,
        token_binding: fv5028.public_id, require_session_binding: true, actor_ref: fv5029.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5043 = "/avatar_ownership_transfers"
      fv5043 += "/fixture/#{fv5044.delete_prefix("avatar_transfer_")}" unless fv5044 == "avatar_transfer_request"
      fv5033 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5029, token: fv5028, requirement: fv5026, return_to: fv5043,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5028,
      )
      fv5027 = fv5033.transaction
      fv5038 = ((fv5034 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5027.transaction_id,
      )
      fv5037 = Webauthn::RelyingPartyConfig.new(rp_id: fv5042, origin: fv5040.origin)
      fv5039 = Webauthn::AssertionVerifier.options_for(
        config: fv5037, allow_ids: [fv5041.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5036 = fv5038.issue_bound_passkey_challenge!(
        transaction: fv5027, challenge: fv5039.challenge, rp_id: fv5037.rp_id, origin: fv5037.origin,
      )
      fv5035 = fv5040.get(challenge: fv5039.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5029, transaction: fv5027, session_record: fv5038, config: fv5037,
        reference: fv5036, credential_params: fv5035,
      )
      fv5031 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5034, reference: fv5033.reference)
      fv5032, = fv5031.class.auth_admission_session_class.issue!
      fv5031.attach_auth_session!(auth_session: fv5032, confirmation_ref: SecureRandom.uuid)
      fv5031.confirm_base!(base_token: fv5028, browser_digest: fv5031.base_browser_digest)
      fv5030, = fv5031.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5027.transaction_id,
      )
      fv5025 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5027,
        ceremony_session_ref: fv5030.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5029,
        token: fv5028,
        transaction: fv5027,
        requirement: fv5026,
        result_reference: fv5025.reference,
      )
    end

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
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params.merge(target_collective_public_id: "no-such-collective"),
           headers: http_headers_1, as: :json
    end

    assert_response :unprocessable_content
    assert_equal "target collective not found", response.body
  end

  test "an unknown transfer id is not found" do
    begin
      fv5003 = @client_token
      fv5024 = { scope: "avatar_transfer_accept", surface: "app" }
      fv5019 = fv5024.fetch(:scope)
      fv5009 = fv5024.fetch(:surface)
      fv5004 = (fv5009 == "app") ? fv5003.user : fv5003.staff
      fv5017 = ENV.fetch((fv5009 == "app") ? "PUBLIC_AUTH_SERVICE_URL" : "PUBLIC_AUTH_STAFF_URL")
      fv5015 = WebAuthn::FakeClient.new("https://#{fv5017}", encoding: :base64url)
      fv5023 = fv5015.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
      fv5022 = WebAuthn::RelyingParty.new(id: fv5017, allowed_origins: [fv5015.origin], encoding: :base64url)
      fv5020 = WebAuthn::Credential.from_create(fv5023, relying_party: fv5022)
      fv5021 = (fv5009 == "app") ? fv5004.client_passkeys : fv5004.staff_passkeys
      fv5016 = fv5021.create!(webauthn_id: fv5020.id, public_key: fv5020.public_key, sign_count: 0)
      fv5001 = StepUpRequirement.new(
        step_up_required: true, scope: fv5019, allowed_methods: [:passkey],
        phishing_resistant_required: fv5009 == "org", user_verification_required: fv5009 == "org",
        full_reauthentication_required: false, ttl: StepUpRequirement::DEFAULT_TTL,
        purpose: "step_up", audience: "step_up:#{fv5009}", session_binding: fv5003.public_id,
        token_binding: fv5003.public_id, require_session_binding: true, actor_ref: fv5004.public_id,
        resource_ref: nil, tenant_ref: nil,
      )
      fv5018 = "/avatar_ownership_transfers"
      fv5018 += "/fixture/#{fv5019.delete_prefix("avatar_transfer_")}" unless fv5019 == "avatar_transfer_request"
      fv5008 = BaseStepUpAdmissionIssuer.call!(
        actor: fv5004, token: fv5003, requirement: fv5001, return_to: fv5018,
        base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: fv5003,
      )
      fv5002 = fv5008.transaction
      fv5013 = ((fv5009 == "app") ? ClientStepUpSession : OperatorStepUpSession).find_by!(
        step_up_ceremony_transaction_ref: fv5002.transaction_id,
      )
      fv5012 = Webauthn::RelyingPartyConfig.new(rp_id: fv5017, origin: fv5015.origin)
      fv5014 = Webauthn::AssertionVerifier.options_for(
        config: fv5012, allow_ids: [fv5016.webauthn_id], purpose: :ordinary_step_up,
      )
      fv5011 = fv5013.issue_bound_passkey_challenge!(
        transaction: fv5002, challenge: fv5014.challenge, rp_id: fv5012.rp_id, origin: fv5012.origin,
      )
      fv5010 = fv5015.get(challenge: fv5014.challenge, user_verified: true, sign_count: 1)
      IdentityStepUpPasskeyVerificationCommitter.call!(
        actor: fv5004, transaction: fv5002, session_record: fv5013, config: fv5012,
        reference: fv5011, credential_params: fv5010,
      )
      fv5006 = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: fv5009, reference: fv5008.reference)
      fv5007, = fv5006.class.auth_admission_session_class.issue!
      fv5006.attach_auth_session!(auth_session: fv5007, confirmation_ref: SecureRandom.uuid)
      fv5006.confirm_base!(base_token: fv5003, browser_digest: fv5006.base_browser_digest)
      fv5005, = fv5006.class.auth_admission_session_class.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: fv5002.transaction_id,
      )
      fv5000 = BaseAuthAdmissionCoordinator.issue_result!(
        transaction: fv5002,
        ceremony_session_ref: fv5005.id.to_s,
      )
      IdentityStepUpCeremonyFreshnessCommitter.call!(
        actor: fv5004,
        token: fv5003,
        transaction: fv5002,
        requirement: fv5001,
        result_reference: fv5000.reference,
      )
    end

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
    post base_app_accept_avatar_ownership_transfer_url("no-such-transfer", host: @host),
         headers: http_headers_0, as: :json

    assert_response :not_found
  end

  private

  def grant_step_up!(scope, token: @client_token)
    token.reload.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: scope,
      last_step_up_aal: nil,
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential",
      last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:app",
    )
  end

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
