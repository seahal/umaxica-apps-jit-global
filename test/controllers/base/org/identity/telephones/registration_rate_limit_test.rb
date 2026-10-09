# typed: false
# frozen_string_literal: true

require "test_helper"

# Starting a telephone verification sends an SMS, so the start step is throttled per client
# address: SignOperatorTelephoneRegistrable allows TELEPHONE_VERIFICATION_RATE_LIMIT starts per
# window and answers the next one 429 without creating another pending telephone.
class Base::Org::Identity::Telephones::RegistrationRateLimitTest < ActionDispatch::IntegrationTest
  rate_limit_counters!

  fixtures :operators, :operator_statuses, :operator_telephone_statuses,
           :operator_token_kinds, :operator_token_statuses, :operator_token_binding_methods,
           :operator_token_dbsc_statuses, :operator_passkeys

  setup do
    https!
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @token = OperatorToken.create!(
      staff: @operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discard_at: 1.day.from_now,
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    client = OidcClientRegistry.find!("base-org-ww")
    @token.rotate_refresh_token!
    now = Time.current
    rp_session = OperatorRpSession.create!(
      operator_token: @token, oidc_client_id: client.client_id, oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: now,
      refresh_token_expires_at: now + 10.minutes,
    )
    rp_access = AuthenticationTokenService.encode(
      @operator, host: @host, resource_type: "operator", session_public_id: @token.public_id,
                 base_session_public_id: @token.public_id, oidc_sid: rp_session.public_id,
                 oidc_jti: rp_session.oidc_jti, expires_at: now + 10.minutes, scopes: %w(openid profile),
                 issuer: OidcIssuer.for_client(client), audiences: [client.aud],
                 jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
                 subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: client.client_id,
    )
    # Rack::Test's cookie jar merge mutates the jar; Hash#merge would not.
    store_raw_cookies(
      cookies,
      [
        "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
        "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_session.issue_refresh_token!)}",
      ], URI.parse("https://#{@host}/"),
    )
    passkey = @operator.operator_passkeys.first!
    passkey.update!(uv_verified_at: now)
    _verification, raw_verification = OperatorVerification.issue_for_token!(token: @token)
    cookies[OperatorVerification.cookie_name] = raw_verification
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: "settings_telephone",
      last_step_up_aal: "aal2",
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
      last_step_up_credential_ref: passkey.external_id,
      last_step_up_phishing_resistant: true,
      last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false,
    )
    access_token = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id,
                 resource_type: "operator", jwt_issuer_id: "surface:BASE_ORG",
    )
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = access_token
    # Base pages authenticate by the Browser RP credential; the root cookie alone does not.
    begin
      rp_cookie_pairs =
        begin
          rp_host = @host
          rp_token = @token
          rp_client = OidcClientRegistry.find!("base-org-ww")
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if @base_browser_rp_credentials[rp_key] ||
              (rp_token.currently_usable? &&
                !(rp_token.device_session_id && OperatorRpSession.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
              rp_now = Time.current
              rp_session = OperatorRpSession.create!(
                operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                refresh_token_expires_at: rp_now + 10.minutes,
              )
              rp_access = AuthenticationTokenService.encode(
                @operator, host: rp_host, resource_type: "operator",
                           session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                           oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                           expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                           issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                           jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                           subject: OidcSubject.for(
                             @operator,
                             resource_type: "operator",
                           ), client_id: rp_client.client_id,
              )
              @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
            end
            rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    @headers = {
      "Authorization" => "Bearer #{access_token}",
      "Client-Agent" => "Mozilla/5.0",
      "Host" => @host,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }.freeze

    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "the start step is refused once the per-address window limit is passed" do
    Rails.configuration.x.rate_limit.fetch(:store).clear
    limit = SignOperatorTelephoneRegistrable::TELEPHONE_VERIFICATION_RATE_LIMIT

    limit.times do |index|
      post(
        base_org_identity_telephones_registration_url(ri: "jp", host: @host),
        params: { staff_telephone: { raw_number: "+1555867#{format("%04d", 5400 + index)}" } }, headers: @headers,
      )

      if response.status == 422
        assert_response :unprocessable_content
        assert_includes response.body, "maximum telephones"
        assert_operator @operator.staff_telephones.count, :<=, OperatorTelephone::MAX_TELEPHONES_PER_STAFF
      else
        assert_redirected_to edit_base_org_identity_telephones_registration_path(ri: "jp")
      end
    end

    assert_no_difference("OperatorTelephone.count") do
      post(
        base_org_identity_telephones_registration_url(ri: "jp", host: @host),
        params: { staff_telephone: { raw_number: "+15558675499" } }, headers: @headers,
      )
    end

    assert_response :too_many_requests
  ensure
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end
end
