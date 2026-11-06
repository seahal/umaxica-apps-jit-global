# typed: false
# frozen_string_literal: true

require "test_helper"

# Browser-condition CSRF for the org administrative mutations. The requests are authenticated by the
# Browser RP cookies (no bearer header), and forgery protection is on. A valid CSRF token lets a
# request reach the independent Step-Up gate; it does not supply Step-Up evidence. The
# expected results follow Rails' `:header_or_legacy_token` Origin and Fetch Metadata checks plus the
# Base/Auth legacy-token requirement on every unsafe request:
#
# - `Sec-Fetch-Site: same-origin` or `same-site` still requires a valid authenticity token;
# - `cross-site` is accepted only from a trusted origin (none is trusted for these endpoints);
# - a missing `Sec-Fetch-Site` falls back to the authenticity token;
# - an `Origin` header that differs from the request's own origin is rejected;
# - `Referer` is not consulted.
class OrgAdminCsrfTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :clients

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! @host
    @operator = operators(:one)
    @granter = operators(:two)
    @token = operator_tokens(:one)
    @client = clients(:one)
    # The compliance row normally comes from migration 20260926130000 (365 days, decided 2026-09-26);
    # a schema-only load skips that insert, so the test ensures it with the same value.
    ChronicleRetentionPolicy.find_or_create_by!(code: "compliance") do |policy|
      policy.name = "Compliance"
      policy.duration_days = 365
      policy.permanent = false
    end
    OperatorCapabilityGrant.bootstrap!(
      operator: @operator, capabilities: OperatorCapabilityGrant::CAPABILITIES, ticket_id: "TEST-CSRF",
      expires_at: 1.day.from_now,
    )
    @passkey = @operator.staff_passkeys.create!(
      webauthn_id: SecureRandom.uuid, public_key: "public",
    )
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    access = AuthenticationToken.encode(
      @operator, host: @host, session_public_id: @token.public_id, resource_type: "operator",
                 jwt_issuer_id: "surface:BASE_ORG",
    )
    installed = cookies.merge(
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}",
      URI.parse("https://#{@host}/"),
    )

    assert_equal ["#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}"], installed

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
                !(rp_token.device_session_id && OpOrgGrant.exists?(
                  device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
                )))
            unless @base_browser_rp_credentials[rp_key]
              rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
              rp_now = Time.current
              rp_session = OpOrgGrant.create!(
                authentication_epoch: 0,
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
              rp_enrollment = RpCallbackCommitter.call(
                cell: RpCellBinding.for_client(rp_client.client_id), issuer: OidcIssuer.for_client(rp_client),
                subject: OidcSubject.for(@operator, resource_type: "operator"), sid: rp_session.public_id,
                absolute_expires_at: rp_session.refresh_token_expires_at,
              )
              unless rp_enrollment.success?
                raise ArgumentError, "RP-local session setup failed: #{rp_enrollment.outcome}"
              end

              @base_browser_rp_credentials[rp_key] = [
                rp_access, rp_session.issue_refresh_token!, rp_enrollment.session.public_id,
              ]
            end
            rp_access, rp_refresh, rp_local_session_id = @base_browser_rp_credentials.fetch(rp_key)
            [
              "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
              "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
              "#{OidcRpBrowserCredentialContract::SESSION_COOKIE}=#{Rack::Utils.escape(rp_local_session_id)}",
            ]
          else
            []
          end
        end
      cookies.merge(rp_cookie_pairs, URI.parse("https://#{rp_host}/"))
    end
    @session_headers = { "Host" => @host, "Client-Agent" => "Mozilla/5.0" }.freeze
    @mutations = {
      support: [
        "support_session_revoke",
        -> { base_org_support_client_revocations_url(@client.public_id, host: @host) },
        -> { { reason_code: "security_incident", operation_id: SecureRandom.uuid } },
        -> { Chronicle.where(action: "support.session.revoked").count },
      ],
      iam: [
        "operator_capability",
        -> { base_org_iam_grants_url(host: @host) },
        lambda {
          { operator_public_id: @granter.public_id,
            capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
            reason_code: "duty_assignment",
            duration_days: "30",
            operation_id: SecureRandom.uuid, }
        },
        -> { OperatorCapabilityGrant.where(operator: @granter).count },
      ],
      enforcement: [
        "enforcement_case_apply",
        -> { base_org_support_app_enforcement_cases_url(host: @host) },
        lambda {
          { enforcement_case: { kind: "cooldown",
                                duration_mode: "timed",
                                visibility: "visible",
                                release_mode: "automatic",
                                effective_at: Time.current,
                                expires_at: 1.day.from_now,
                                reason_code: "abuse",
                                principal_public_id: @client.public_id, } }
        },
        -> { AppEnforcementCase.count },
      ],
    }
  end

  test "each mutation follows the Fetch Metadata and token contract" do
    @mutations.each do |name, (_scope, url, params, count)|
      rejected = [
        { "Sec-Fetch-Site" => "cross-site", "Origin" => "https://attacker.example" },
        { "Sec-Fetch-Site" => nil },
        { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://attacker.example" },
        { "Sec-Fetch-Site" => nil, "Referer" => "https://#{@host}/support" },
        { "Sec-Fetch-Site" => nil, "X-CSRF-Token" => "forged-token-value" },
      ]
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      begin
        # csrf_meta_tags renders only while forgery protection is on.
        get(base_org_support_index_url(ri: "jp", host: @host), headers: @session_headers)

        assert_predicate css_select("meta[name='csrf-token']").first&.[]("content"), :present?,
                         "#{name}: the page carries a CSRF token"

        rejected.each do |fetch_headers|
          assert_no_difference(count, "#{name}: #{fetch_headers.inspect} must be rejected") do
            post(url.call, params: params.call, headers: @session_headers.merge(fetch_headers))

            assert_response :unprocessable_content
          end
        end
        assert_no_difference(count, "#{name}: a JSON body gets no exemption") do
          post(
            url.call, params: params.call.to_json,
                      headers: @session_headers.merge("Sec-Fetch-Site" => nil, "Content-Type" => "application/json"),
          )

          assert_response :unprocessable_content
        end

        assert_no_difference(count, "#{name}: same-origin without a token is refused") do
          post(
            url.call, params: params.call,
                      headers: @session_headers.merge(
                        "Sec-Fetch-Site" => "same-origin",
                        "Referer" => "https://attacker.example/",
                      ),
          )

          assert_response :unprocessable_content
        end
      ensure
        ActionController::Base.allow_forgery_protection = original
      end
    end
  end

  test "a valid CSRF token reaches Step-Up without performing the protected mutation" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    begin
      get(base_org_support_index_url(ri: "jp", host: @host), headers: @session_headers)
      csrf_token = css_select("meta[name='csrf-token']").first["content"]

      assert_no_difference(-> { Chronicle.where(action: "support.session.revoked").count }) do
        post(
          base_org_support_client_revocations_url(@client.public_id, host: @host),
          params: { reason_code: "security_incident", operation_id: SecureRandom.uuid },
          headers: @session_headers.merge("Sec-Fetch-Site" => nil, "X-CSRF-Token" => csrf_token),
        )
      end

      assert_response :unauthorized
    ensure
      ActionController::Base.allow_forgery_protection = original
    end
  end
end
