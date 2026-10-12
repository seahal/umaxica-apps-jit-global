# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::AvatarOwnershipTransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @source = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
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

    @target_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @target = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @target_client)
  end

  test "registry request transport is refused before the verified ownership cutover" do
    grant_step_up!("avatar_transfer_request")
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
  end

  test "registry accept transport is refused before the verified ownership cutover" do
    reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
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
    )

    grant_step_up!("avatar_transfer_accept")
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
    grant_step_up!("avatar_transfer_request")
    http_headers_2 =
      begin
        rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
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

    grant_step_up!("avatar_transfer_cancel")
    http_headers_1 =
      begin
        rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && OperatorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
              operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.staff, host: rp_host, resource_type: "operator",
                              session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                              oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                              expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                              issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                              subject: OidcSubject.for(
                                rp_token.staff,
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
    post base_org_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: http_headers_1, as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
    assert_equal "org", @avatar_result.avatar.reload.current_ownership_period.owner_surface
  end

  test "URL-provided Avatar cannot replace a nil selected Avatar" do
    assert_nil @source.avatar
    @token.update!(selected_avatar_public_id: nil)
    grant_step_up!("avatar_transfer_request")

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      http_headers_0 =
        begin
          rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
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
              when "edit" then "edit-org"
              else "#{rp_family}-#{rp_surface}"
              end
            rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            rp_client = OidcClientRegistry.find!(rp_client_id)
            rp_key = [rp_client.client_id, rp_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
                !(rp_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: rp_token.device_session_id,
                  oidc_client_id: rp_client.client_id,
                  revoked_at: nil,
                ))
              rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
              rp_now = Time.current
              rp_session = OperatorRpSession.create!(
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                rp_token.staff, host: rp_host, resource_type: "operator",
                                session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                subject: OidcSubject.for(
                                  rp_token.staff,
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
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: {
             avatar_public_id: @avatar_result.avatar.public_id,
             target_surface: "app",
             target_collective_public_id: @target.collective.public_id,
           },
           headers: http_headers_0, as: :json

      assert_response :forbidden
    end
  end

  test "registry accept transport completes an explicit registry reservation" do
    establish_avatar_ownership_cutover!
    source_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
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
    reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
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
    )

    grant_step_up!("avatar_transfer_accept")
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

  def grant_step_up!(scope)
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: scope,
      last_step_up_aal: nil,
      last_step_up_method: "passkey",
      last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
      last_step_up_credential_ref: "test-step-up-credential", last_step_up_full_reauthentication: false,
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
  end

  def base_browser_headers
    rp_headers = as_staff_headers(@operator, host: @host, session_public_id: @token.public_id)
    rp_token = OperatorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
    rp_client = OidcClientRegistry.find!("base-org-ww")
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
    return if rp_token.device_session_id && OperatorRpSession.exists?(
      device_session_id: rp_token.device_session_id,
      oidc_client_id: rp_client.client_id,
      revoked_at: nil,
    )

    rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
    rp_now = Time.current
    rp_session = OperatorRpSession.create!(
      operator_token: rp_token,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: rp_now,
      refresh_token_expires_at: rp_now + 10.minutes,
    )
    rp_access = AuthenticationTokenService.encode(
      rp_token.staff,
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
      subject: OidcSubject.for(rp_token.staff, resource_type: "operator"),
      client_id: rp_client.client_id,
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

  def establish_avatar_ownership_cutover!
    AvatarOwnershipCutover.create!(
      id: AvatarOwnershipCutover::CUTOVER_ID,
      cutover_at: Time.utc(2030, 1, 1),
    )
  end
end
