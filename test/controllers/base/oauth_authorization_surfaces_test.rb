# typed: false
# frozen_string_literal: true

require "test_helper"

# The OAuth authorization endpoint exists on all three base surfaces and each
# one owns its own realm, validator resource type, and error mapping. The app
# surface is covered by BaseOauthOidcAuthorityTest; these pin the spec-defined
# error responses of the corporate and staff surfaces.
class BaseOauthAuthorizationSurfacesTest < ActionDispatch::IntegrationTest
  include OidcAuthorizationResponseHelper

  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }

  test "com authorize rejects a scope that omits openid" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").merge(scope: "profile"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_match(/openid/, response.parsed_body.fetch("error_description"))
  end

  test "org authorize rejects a scope that omits openid" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").merge(scope: "profile"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects a request with no state" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").except(:state),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "org authorize rejects a request with no state" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").except(:state),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com authorize rejects an unregistered client" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host, **authorize_params(realm: "visitor").merge(client_id: "not-registered"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "org authorize rejects an unregistered client" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")

    get base_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").merge(client_id: "not-registered"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "com and org authorize return login_required for prompt none without a session" do
    [
      {
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
        route: :base_com_oauth_authorization_url,
        realm: "visitor",
        transaction_class: VisitorOidcAuthorizationTransaction,
      },
      {
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
        route: :base_org_oauth_authorization_url,
        realm: "operator",
        transaction_class: OperatorOidcAuthorizationTransaction,
      },
    ].each do |surface|
      host!(surface.fetch(:host))

      assert_no_difference -> { surface.fetch(:transaction_class).count } do
        get public_send(
          surface.fetch(:route),
          host: surface.fetch(:host),
          **authorize_params(realm: surface.fetch(:realm)).merge(prompt: "none"),
        ),
            headers: { "Host" => surface.fetch(:host) }
      end

      assert_oidc_error_redirect(
        error: "login_required",
        redirect_uri: authorize_params(realm: surface.fetch(:realm)).fetch(:redirect_uri),
      )
    end
  end

  test "com authorize rejects a redirect_uri that is not registered for the corporate realm" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    get base_com_oauth_authorization_url(
      host: host,
      **authorize_params(realm: "visitor").merge(redirect_uri: "https://attacker.example/callback"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  # Capacity (specs/sign-fqdn-integrated-plan/plan.md section 5): 2048 bytes per parameter and
  # 8192 bytes per query, refused with 400 before any transaction is allocated. Values use only
  # unreserved characters so the byte counts are exact on the wire.
  test "authorize accepts a 2048-byte parameter and refuses 2049 bytes before allocating state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    base = authorize_params(realm: "client").except(:state).to_query

    { 2047 => true, 2048 => true, 2049 => false }.each do |bytes, accepted|
      count = ClientOidcAuthorizationTransaction.count
      get "/oauth/authorize?#{base}&state=#{"a" * bytes}", headers: { "Host" => host }

      if accepted
        assert_response :success, "#{bytes} bytes"
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      else
        assert_response :bad_request, "#{bytes} bytes"
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      end
    end
  end

  test "authorize accepts an 8192-byte query and refuses 8193 bytes before allocating state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    padding = (1..3).map { |index| "pad#{index}=#{"b" * 2000}" }.join("&")
    base = "#{authorize_params(realm: "client").to_query}&#{padding}&pad4="

    { 8191 => true, 8192 => true, 8193 => false }.each do |bytes, accepted|
      query = "#{base}#{"c" * (bytes - base.bytesize)}"
      count = ClientOidcAuthorizationTransaction.count

      assert_equal bytes, query.bytesize
      get "/oauth/authorize?#{query}", headers: { "Host" => host }

      if accepted
        assert_response :success, "#{bytes} bytes"
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      else
        assert_response :bad_request, "#{bytes} bytes"
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      end
    end
  end

  test "authorize refuses array and hash parameter values before allocating state" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    base = authorize_params(realm: "client").except(:state).to_query

    ["state[]=a", "state[k]=a"].each do |shaped|
      count = ClientOidcAuthorizationTransaction.count
      get "/oauth/authorize?#{base}&#{shaped}", headers: { "Host" => host }

      assert_response :bad_request, shaped
      assert_equal count, ClientOidcAuthorizationTransaction.count, shaped
    end
  end

  # E02: a browser already authenticated at Base starting a new Sign is refused, even when the RP has
  # no session yet. This is the intended product constraint, not an SSO success path.
  test "E02 app neutral Sign refuses an authenticated browser with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    transaction_count = ClientOidcAuthorizationTransaction.count

    http_headers_2 =
      begin
        rp_headers = as_user_headers(clients(:one), host: host)
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
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = ClientToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && ClientRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = ClientRpSession.create!(
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
    post base_app_sign_show_url(host: host, ri: "jp"), headers: http_headers_2

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal transaction_count, ClientOidcAuthorizationTransaction.count
  end

  # E02: a browser already authenticated at Base starting a new Sign is refused, even when the RP has
  # no session yet. This is the intended product constraint, not an SSO success path.
  test "E02 com neutral Sign refuses an authenticated browser with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    transaction_count = VisitorOidcAuthorizationTransaction.count

    http_headers_1 =
      begin
        rp_headers = as_visitor_headers(visitors(:reserved_visitor), host: host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        if %w(base warp core edit).include?(rp_family) && rp_surface == "com"
          rp_client_id =
            case rp_family
            when "base" then "base-#{rp_surface}-ww"
            when "edit" then "edit-org"
            else "#{rp_family}-#{rp_surface}"
            end
          rp_token = VisitorToken.find_by!(public_id: rp_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
          rp_client = OidcClientRegistry.find!(rp_client_id)
          rp_key = [rp_client.client_id, rp_token.public_id]
          @base_browser_rp_credentials ||= {}
          if !@base_browser_rp_credentials[rp_key] && rp_token.currently_usable? &&
              !(rp_token.device_session_id && VisitorRpSession.exists?(
                device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
              ))
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = VisitorRpSession.create!(
              visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
              oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
              refresh_token_expires_at: rp_now + 10.minutes,
            )
            rp_access = AuthenticationTokenService.encode(
              rp_token.actor_record, host: rp_host, resource_type: "visitor",
                                     session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                                     oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                                     expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                                     issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                                     jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                                     subject: OidcSubject.for(
                                       rp_token.actor_record,
                                       resource_type: "visitor",
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
    post base_com_sign_show_url(host: host, ri: "jp"), headers: http_headers_1

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal transaction_count, VisitorOidcAuthorizationTransaction.count
  end

  # E02: a browser already authenticated at Base starting a new Sign is refused, even when the RP has
  # no session yet. This is the intended product constraint, not an SSO success path.
  test "E02 org neutral Sign refuses an authenticated browser with a plain 403 and issues nothing" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    transaction_count = OperatorOidcAuthorizationTransaction.count

    http_headers_0 =
      begin
        rp_headers = as_staff_headers(operators(:one), host: host)
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
            rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
            rp_now = Time.current
            rp_session = OperatorRpSession.create!(
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
    post base_org_sign_show_url(host: host, ri: "jp"), headers: http_headers_0

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_equal "text/plain", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
    assert_equal transaction_count, OperatorOidcAuthorizationTransaction.count
  end

  # E03: a Valkey outage while reading the result is a dependency failure, not a rejected request.
  # Only the Valkey store is replaced; transaction lookup, readiness checks, and the route are real.
  test "E03 com authorize answers 503 without consuming the transaction when Valkey is unavailable" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = visitors(:reserved_visitor)
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "visitor").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5767 = auth
          fv5766 = "/sign/in"
          fv5765 = entry_ref
          fv5764 = :entry_ref
          fv5763 = { ri: "jp" }
          fv5762 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5761 = true
          fv5760 = self
          begin
            fv5708 = fv5767
            fv5715 = fv5766
            fv5758 = fv5765
            fv5759 = fv5764
            fv5724 = fv5763
            fv5717 = fv5762
            fv5746 = fv5761
            fv5745 = fv5760
            fv5720 = nil
            fv5714 = fv5724.merge(fv5759 => fv5758)
            fv5708.get(fv5715, params: fv5714, headers: fv5717)
            fv5752 =
              begin
                fv5757 = fv5708.response.body
                fv5756 = true
                fv5755 = Nokogiri::HTML(fv5757).at_css("form")
                if fv5755.nil? && fv5756
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5755

                  fv5754 = fv5755.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5754.blank?

                  fv5753 = fv5755.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5755["action"], fv5754, fv5753]
                end
              end
            if fv5752

              fv5751, fv5749, fv5750 = fv5752

              fv5708.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5708.post(
                fv5751,
                params: fv5750.merge(authenticity_token: fv5749),
                headers: fv5717,
              )
              fv5748 = fv5708.response.location
              if fv5748.present?

                fv5744 = URI.parse(fv5748)
                fv5743 = fv5744.host
                fv5719 =
                  begin
                    fv5747 = fv5743
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5747)
                  end
                fv5718 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5719, reference: fv5744.path.split("/").fetch(-2),
                )

                if fv5746
                  fv5726 = fv5745 || fv5708
                  fv5726.host!(fv5743)
                  fv5726.https!
                  fv5726.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5742 = fv5744.request_uri
                  fv5733 = fv5717.merge(
                    "Host" => fv5743,
                    "Origin" => "https://#{fv5743}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5726.get(fv5742, headers: fv5733)
                  fv5736, fv5734, fv5735 =
                    begin
                      fv5741 = fv5726.response.body
                      fv5740 = false
                      fv5739 = Nokogiri::HTML(fv5741).at_css("form")
                      if fv5739.nil? && fv5740
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5739

                        fv5738 = fv5739.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5738.blank?

                        fv5737 = fv5739.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5739["action"], fv5738, fv5737]
                      end
                    end
                  fv5726.post(
                    fv5736,
                    params: fv5735.merge(authenticity_token: fv5734),
                    headers: fv5733,
                  )
                  begin
                    fv5727 = fv5726
                    fv5729 = "session"
                    fv5728 = fv5727.response.cookies[fv5729]
                    if fv5728.nil?
                      fv5732 = fv5727.response.headers["Set-Cookie"] || fv5727.response.headers["set-cookie"]
                      fv5731 =
                        if fv5732.is_a?(String) && fv5732.start_with?("[")
                          JSON.parse(fv5732)
                        else
                          Array(fv5732)
                        end
                      fv5730 =
                        fv5731.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5729}=")
                        end
                      if fv5730

                        _, fv5728 = fv5730.split(";", 2).first.to_s.split("=", 2)
                        fv5728 = Rack::Utils.unescape(fv5728.to_s)
                      end
                    end

                    unless fv5728.nil?
                      fv5727.cookies.delete(fv5729)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5727.cookies.merge(
                        "#{fv5729}=#{Rack::Utils.escape(fv5728)}",
                        URI.parse("https://#{fv5727.host}/"),
                      )
                    end
                  end
                  fv5725 = fv5726.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5725.blank?

                  fv5722 = URI.parse(fv5725)
                  if fv5724[:ri].present?
                    fv5723 = Rack::Utils.parse_nested_query(fv5722.query.to_s)
                    fv5723["ri"] ||= fv5724[:ri].to_s
                    fv5722.query = URI.encode_www_form(fv5723)
                  end
                  fv5708.host!(fv5722.host)
                  fv5708.https!
                  fv5721 = fv5722.request_uri
                  fv5704 = fv5717.merge("Host" => fv5722.host)
                  fv5708.get(fv5721, headers: fv5704)
                else
                  fv5718.confirm_base!(
                    base_token: fv5720,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5719,
                      entry_ref: fv5718.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5716 = fv5708.host
                  fv5708.host!(fv5716)
                  fv5708.https!
                  fv5704 = fv5717.merge("Host" => fv5716)
                  fv5708.get(fv5715, params: fv5714, headers: fv5704)
                end
                fv5707, fv5705, fv5706 =
                  begin
                    fv5713 = fv5708.response.body
                    fv5712 = false
                    fv5711 = Nokogiri::HTML(fv5713).at_css("form")
                    if fv5711.nil? && fv5712
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5711

                      fv5710 = fv5711.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5710.blank?

                      fv5709 = fv5711.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5711["action"], fv5710, fv5709]
                    end
                  end
                fv5708.post(
                  fv5707,
                  params: fv5706.merge(authenticity_token: fv5705),
                  headers: fv5704,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: transaction.login_challenge,
      actor: visitor, session_ref: "com-e03-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )
    unavailable_store = Valkey::AuthState::OpaqueAdmissionStore.new
    unavailable = ->(*) { raise Umaxica::Valkey::Unavailable, "Valkey admission read unavailable" }

    Valkey::AuthState::OpaqueAdmissionStore.stub(:new, unavailable_store) do
      unavailable_store.stub(:read_reference!, unavailable) do
        post base_com_oauth_authorization_url(host: host),
             params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
             headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")
      end
    end

    assert_response :service_unavailable
    assert_equal "temporarily_unavailable", response.parsed_body.fetch("error")
    assert_not_predicate transaction.reload, :consumed?
  end

  test "com authorize rejects an unknown result code as an invalid request" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")

    post base_com_oauth_authorization_url(host: host),
         params: { result: "no-such-challenge", transaction_ref: "unknown" },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
  end

  test "com authorize reuses a finalized browser session without creating another root session" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    visitor = visitors(:reserved_visitor)
    token_count_before = VisitorToken.where(visitor_id: visitor.id).count
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "visitor").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5703 = auth
          fv5702 = "/sign/in"
          fv5701 = entry_ref
          fv5700 = :entry_ref
          fv5699 = { ri: "jp" }
          fv5698 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5697 = true
          fv5696 = self
          begin
            fv5644 = fv5703
            fv5651 = fv5702
            fv5694 = fv5701
            fv5695 = fv5700
            fv5660 = fv5699
            fv5653 = fv5698
            fv5682 = fv5697
            fv5681 = fv5696
            fv5656 = nil
            fv5650 = fv5660.merge(fv5695 => fv5694)
            fv5644.get(fv5651, params: fv5650, headers: fv5653)
            fv5688 =
              begin
                fv5693 = fv5644.response.body
                fv5692 = true
                fv5691 = Nokogiri::HTML(fv5693).at_css("form")
                if fv5691.nil? && fv5692
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5691

                  fv5690 = fv5691.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5690.blank?

                  fv5689 = fv5691.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5691["action"], fv5690, fv5689]
                end
              end
            if fv5688

              fv5687, fv5685, fv5686 = fv5688

              fv5644.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5644.post(
                fv5687,
                params: fv5686.merge(authenticity_token: fv5685),
                headers: fv5653,
              )
              fv5684 = fv5644.response.location
              if fv5684.present?

                fv5680 = URI.parse(fv5684)
                fv5679 = fv5680.host
                fv5655 =
                  begin
                    fv5683 = fv5679
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5683)
                  end
                fv5654 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5655, reference: fv5680.path.split("/").fetch(-2),
                )

                if fv5682
                  fv5662 = fv5681 || fv5644
                  fv5662.host!(fv5679)
                  fv5662.https!
                  fv5662.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5678 = fv5680.request_uri
                  fv5669 = fv5653.merge(
                    "Host" => fv5679,
                    "Origin" => "https://#{fv5679}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5662.get(fv5678, headers: fv5669)
                  fv5672, fv5670, fv5671 =
                    begin
                      fv5677 = fv5662.response.body
                      fv5676 = false
                      fv5675 = Nokogiri::HTML(fv5677).at_css("form")
                      if fv5675.nil? && fv5676
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5675

                        fv5674 = fv5675.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5674.blank?

                        fv5673 = fv5675.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5675["action"], fv5674, fv5673]
                      end
                    end
                  fv5662.post(
                    fv5672,
                    params: fv5671.merge(authenticity_token: fv5670),
                    headers: fv5669,
                  )
                  begin
                    fv5663 = fv5662
                    fv5665 = "session"
                    fv5664 = fv5663.response.cookies[fv5665]
                    if fv5664.nil?
                      fv5668 = fv5663.response.headers["Set-Cookie"] || fv5663.response.headers["set-cookie"]
                      fv5667 =
                        if fv5668.is_a?(String) && fv5668.start_with?("[")
                          JSON.parse(fv5668)
                        else
                          Array(fv5668)
                        end
                      fv5666 =
                        fv5667.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5665}=")
                        end
                      if fv5666

                        _, fv5664 = fv5666.split(";", 2).first.to_s.split("=", 2)
                        fv5664 = Rack::Utils.unescape(fv5664.to_s)
                      end
                    end

                    unless fv5664.nil?
                      fv5663.cookies.delete(fv5665)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5663.cookies.merge(
                        "#{fv5665}=#{Rack::Utils.escape(fv5664)}",
                        URI.parse("https://#{fv5663.host}/"),
                      )
                    end
                  end
                  fv5661 = fv5662.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5661.blank?

                  fv5658 = URI.parse(fv5661)
                  if fv5660[:ri].present?
                    fv5659 = Rack::Utils.parse_nested_query(fv5658.query.to_s)
                    fv5659["ri"] ||= fv5660[:ri].to_s
                    fv5658.query = URI.encode_www_form(fv5659)
                  end
                  fv5644.host!(fv5658.host)
                  fv5644.https!
                  fv5657 = fv5658.request_uri
                  fv5640 = fv5653.merge("Host" => fv5658.host)
                  fv5644.get(fv5657, headers: fv5640)
                else
                  fv5654.confirm_base!(
                    base_token: fv5656,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5655,
                      entry_ref: fv5654.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5652 = fv5644.host
                  fv5644.host!(fv5652)
                  fv5644.https!
                  fv5640 = fv5653.merge("Host" => fv5652)
                  fv5644.get(fv5651, params: fv5650, headers: fv5640)
                end
                fv5643, fv5641, fv5642 =
                  begin
                    fv5649 = fv5644.response.body
                    fv5648 = false
                    fv5647 = Nokogiri::HTML(fv5649).at_css("form")
                    if fv5647.nil? && fv5648
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5647

                      fv5646 = fv5647.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5646.blank?

                      fv5645 = fv5647.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5647["action"], fv5646, fv5645]
                    end
                  end
                fv5644.post(
                  fv5643,
                  params: fv5642.merge(authenticity_token: fv5641),
                  headers: fv5640,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: transaction.login_challenge,
      actor: visitor, session_ref: "com-resume-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :redirect
    assert_predicate transaction.reload, :consumed?
    browser_session_ref = transaction.browser_session_ref

    assert_predicate browser_session_ref, :present?
    assert_equal token_count_before + 1, VisitorToken.where(visitor_id: visitor.id).count

    post base_com_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :redirect
    assert_equal browser_session_ref, transaction.reload.browser_session_ref
    assert_equal token_count_before + 1, VisitorToken.where(visitor_id: visitor.id).count
  end

  test "org authorize stages session-limit resolution without issuing a second root login" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    OperatorToken.where(staff_id: operator.id).delete_all
    OperatorToken.create!(staff_id: operator.id, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "operator").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5639 = auth
          fv5638 = "/sign/in"
          fv5637 = entry_ref
          fv5636 = :entry_ref
          fv5635 = { ri: "jp" }
          fv5634 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5633 = true
          fv5632 = self
          begin
            fv5580 = fv5639
            fv5587 = fv5638
            fv5630 = fv5637
            fv5631 = fv5636
            fv5596 = fv5635
            fv5589 = fv5634
            fv5618 = fv5633
            fv5617 = fv5632
            fv5592 = nil
            fv5586 = fv5596.merge(fv5631 => fv5630)
            fv5580.get(fv5587, params: fv5586, headers: fv5589)
            fv5624 =
              begin
                fv5629 = fv5580.response.body
                fv5628 = true
                fv5627 = Nokogiri::HTML(fv5629).at_css("form")
                if fv5627.nil? && fv5628
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5627

                  fv5626 = fv5627.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5626.blank?

                  fv5625 = fv5627.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5627["action"], fv5626, fv5625]
                end
              end
            if fv5624

              fv5623, fv5621, fv5622 = fv5624

              fv5580.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5580.post(
                fv5623,
                params: fv5622.merge(authenticity_token: fv5621),
                headers: fv5589,
              )
              fv5620 = fv5580.response.location
              if fv5620.present?

                fv5616 = URI.parse(fv5620)
                fv5615 = fv5616.host
                fv5591 =
                  begin
                    fv5619 = fv5615
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5619)
                  end
                fv5590 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5591, reference: fv5616.path.split("/").fetch(-2),
                )

                if fv5618
                  fv5598 = fv5617 || fv5580
                  fv5598.host!(fv5615)
                  fv5598.https!
                  fv5598.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5614 = fv5616.request_uri
                  fv5605 = fv5589.merge(
                    "Host" => fv5615,
                    "Origin" => "https://#{fv5615}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5598.get(fv5614, headers: fv5605)
                  fv5608, fv5606, fv5607 =
                    begin
                      fv5613 = fv5598.response.body
                      fv5612 = false
                      fv5611 = Nokogiri::HTML(fv5613).at_css("form")
                      if fv5611.nil? && fv5612
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5611

                        fv5610 = fv5611.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5610.blank?

                        fv5609 = fv5611.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5611["action"], fv5610, fv5609]
                      end
                    end
                  fv5598.post(
                    fv5608,
                    params: fv5607.merge(authenticity_token: fv5606),
                    headers: fv5605,
                  )
                  begin
                    fv5599 = fv5598
                    fv5601 = "session"
                    fv5600 = fv5599.response.cookies[fv5601]
                    if fv5600.nil?
                      fv5604 = fv5599.response.headers["Set-Cookie"] || fv5599.response.headers["set-cookie"]
                      fv5603 =
                        if fv5604.is_a?(String) && fv5604.start_with?("[")
                          JSON.parse(fv5604)
                        else
                          Array(fv5604)
                        end
                      fv5602 =
                        fv5603.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5601}=")
                        end
                      if fv5602

                        _, fv5600 = fv5602.split(";", 2).first.to_s.split("=", 2)
                        fv5600 = Rack::Utils.unescape(fv5600.to_s)
                      end
                    end

                    unless fv5600.nil?
                      fv5599.cookies.delete(fv5601)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5599.cookies.merge(
                        "#{fv5601}=#{Rack::Utils.escape(fv5600)}",
                        URI.parse("https://#{fv5599.host}/"),
                      )
                    end
                  end
                  fv5597 = fv5598.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5597.blank?

                  fv5594 = URI.parse(fv5597)
                  if fv5596[:ri].present?
                    fv5595 = Rack::Utils.parse_nested_query(fv5594.query.to_s)
                    fv5595["ri"] ||= fv5596[:ri].to_s
                    fv5594.query = URI.encode_www_form(fv5595)
                  end
                  fv5580.host!(fv5594.host)
                  fv5580.https!
                  fv5593 = fv5594.request_uri
                  fv5576 = fv5589.merge("Host" => fv5594.host)
                  fv5580.get(fv5593, headers: fv5576)
                else
                  fv5590.confirm_base!(
                    base_token: fv5592,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5591,
                      entry_ref: fv5590.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5588 = fv5580.host
                  fv5580.host!(fv5588)
                  fv5580.https!
                  fv5576 = fv5589.merge("Host" => fv5588)
                  fv5580.get(fv5587, params: fv5586, headers: fv5576)
                end
                fv5579, fv5577, fv5578 =
                  begin
                    fv5585 = fv5580.response.body
                    fv5584 = false
                    fv5583 = Nokogiri::HTML(fv5585).at_css("form")
                    if fv5583.nil? && fv5584
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5583

                      fv5582 = fv5583.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5582.blank?

                      fv5581 = fv5583.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5583["action"], fv5582, fv5581]
                    end
                  end
                fv5580.post(
                  fv5579,
                  params: fv5578.merge(authenticity_token: fv5577),
                  headers: fv5576,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: transaction.login_challenge,
      actor: operator, session_ref: "org-limit-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )

    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      post base_org_oauth_authorization_url(host: host),
           params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
           headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")
    end

    assert_response :see_other
    assert_redirected_to base_org_sign_in_limitation_path(ri: "jp")
    assert_not_predicate transaction.reload, :consumed?
    assert_nil transaction.browser_session_ref
  end

  test "org authorize reuses a finalized browser session without creating another root session" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    operator = operators(:one)
    # The org limit is one session; start from none so the first resume can establish one.
    OperatorToken.where(staff_id: operator.id).delete_all
    token_count_before = OperatorToken.where(staff_id: operator.id).count
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "operator").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5575 = auth
          fv5574 = "/sign/in"
          fv5573 = entry_ref
          fv5572 = :entry_ref
          fv5571 = { ri: "jp" }
          fv5570 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5569 = true
          fv5568 = self
          begin
            fv5516 = fv5575
            fv5523 = fv5574
            fv5566 = fv5573
            fv5567 = fv5572
            fv5532 = fv5571
            fv5525 = fv5570
            fv5554 = fv5569
            fv5553 = fv5568
            fv5528 = nil
            fv5522 = fv5532.merge(fv5567 => fv5566)
            fv5516.get(fv5523, params: fv5522, headers: fv5525)
            fv5560 =
              begin
                fv5565 = fv5516.response.body
                fv5564 = true
                fv5563 = Nokogiri::HTML(fv5565).at_css("form")
                if fv5563.nil? && fv5564
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5563

                  fv5562 = fv5563.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5562.blank?

                  fv5561 = fv5563.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5563["action"], fv5562, fv5561]
                end
              end
            if fv5560

              fv5559, fv5557, fv5558 = fv5560

              fv5516.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5516.post(
                fv5559,
                params: fv5558.merge(authenticity_token: fv5557),
                headers: fv5525,
              )
              fv5556 = fv5516.response.location
              if fv5556.present?

                fv5552 = URI.parse(fv5556)
                fv5551 = fv5552.host
                fv5527 =
                  begin
                    fv5555 = fv5551
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5555)
                  end
                fv5526 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5527, reference: fv5552.path.split("/").fetch(-2),
                )

                if fv5554
                  fv5534 = fv5553 || fv5516
                  fv5534.host!(fv5551)
                  fv5534.https!
                  fv5534.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5550 = fv5552.request_uri
                  fv5541 = fv5525.merge(
                    "Host" => fv5551,
                    "Origin" => "https://#{fv5551}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5534.get(fv5550, headers: fv5541)
                  fv5544, fv5542, fv5543 =
                    begin
                      fv5549 = fv5534.response.body
                      fv5548 = false
                      fv5547 = Nokogiri::HTML(fv5549).at_css("form")
                      if fv5547.nil? && fv5548
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5547

                        fv5546 = fv5547.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5546.blank?

                        fv5545 = fv5547.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5547["action"], fv5546, fv5545]
                      end
                    end
                  fv5534.post(
                    fv5544,
                    params: fv5543.merge(authenticity_token: fv5542),
                    headers: fv5541,
                  )
                  begin
                    fv5535 = fv5534
                    fv5537 = "session"
                    fv5536 = fv5535.response.cookies[fv5537]
                    if fv5536.nil?
                      fv5540 = fv5535.response.headers["Set-Cookie"] || fv5535.response.headers["set-cookie"]
                      fv5539 =
                        if fv5540.is_a?(String) && fv5540.start_with?("[")
                          JSON.parse(fv5540)
                        else
                          Array(fv5540)
                        end
                      fv5538 =
                        fv5539.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5537}=")
                        end
                      if fv5538

                        _, fv5536 = fv5538.split(";", 2).first.to_s.split("=", 2)
                        fv5536 = Rack::Utils.unescape(fv5536.to_s)
                      end
                    end

                    unless fv5536.nil?
                      fv5535.cookies.delete(fv5537)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5535.cookies.merge(
                        "#{fv5537}=#{Rack::Utils.escape(fv5536)}",
                        URI.parse("https://#{fv5535.host}/"),
                      )
                    end
                  end
                  fv5533 = fv5534.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5533.blank?

                  fv5530 = URI.parse(fv5533)
                  if fv5532[:ri].present?
                    fv5531 = Rack::Utils.parse_nested_query(fv5530.query.to_s)
                    fv5531["ri"] ||= fv5532[:ri].to_s
                    fv5530.query = URI.encode_www_form(fv5531)
                  end
                  fv5516.host!(fv5530.host)
                  fv5516.https!
                  fv5529 = fv5530.request_uri
                  fv5512 = fv5525.merge("Host" => fv5530.host)
                  fv5516.get(fv5529, headers: fv5512)
                else
                  fv5526.confirm_base!(
                    base_token: fv5528,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5527,
                      entry_ref: fv5526.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5524 = fv5516.host
                  fv5516.host!(fv5524)
                  fv5516.https!
                  fv5512 = fv5525.merge("Host" => fv5524)
                  fv5516.get(fv5523, params: fv5522, headers: fv5512)
                end
                fv5515, fv5513, fv5514 =
                  begin
                    fv5521 = fv5516.response.body
                    fv5520 = false
                    fv5519 = Nokogiri::HTML(fv5521).at_css("form")
                    if fv5519.nil? && fv5520
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5519

                      fv5518 = fv5519.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5518.blank?

                      fv5517 = fv5519.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5519["action"], fv5518, fv5517]
                    end
                  end
                fv5516.post(
                  fv5515,
                  params: fv5514.merge(authenticity_token: fv5513),
                  headers: fv5512,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: transaction.login_challenge,
      actor: operator, session_ref: "org-resume-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )

    post base_org_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :redirect
    assert_predicate transaction.reload, :consumed?
    browser_session_ref = transaction.browser_session_ref

    assert_predicate browser_session_ref, :present?
    assert_equal token_count_before + 1, OperatorToken.where(staff_id: operator.id).count

    post base_org_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :redirect
    assert_equal browser_session_ref, transaction.reload.browser_session_ref
    assert_equal token_count_before + 1, OperatorToken.where(staff_id: operator.id).count
  end

  test "com authorize refuses a result whose ceremony is not ready" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "visitor").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5511 = auth
          fv5510 = "/sign/in"
          fv5509 = entry_ref
          fv5508 = :entry_ref
          fv5507 = { ri: "jp" }
          fv5506 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5505 = true
          fv5504 = self
          begin
            fv5452 = fv5511
            fv5459 = fv5510
            fv5502 = fv5509
            fv5503 = fv5508
            fv5468 = fv5507
            fv5461 = fv5506
            fv5490 = fv5505
            fv5489 = fv5504
            fv5464 = nil
            fv5458 = fv5468.merge(fv5503 => fv5502)
            fv5452.get(fv5459, params: fv5458, headers: fv5461)
            fv5496 =
              begin
                fv5501 = fv5452.response.body
                fv5500 = true
                fv5499 = Nokogiri::HTML(fv5501).at_css("form")
                if fv5499.nil? && fv5500
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5499

                  fv5498 = fv5499.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5498.blank?

                  fv5497 = fv5499.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5499["action"], fv5498, fv5497]
                end
              end
            if fv5496

              fv5495, fv5493, fv5494 = fv5496

              fv5452.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5452.post(
                fv5495,
                params: fv5494.merge(authenticity_token: fv5493),
                headers: fv5461,
              )
              fv5492 = fv5452.response.location
              if fv5492.present?

                fv5488 = URI.parse(fv5492)
                fv5487 = fv5488.host
                fv5463 =
                  begin
                    fv5491 = fv5487
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5491)
                  end
                fv5462 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5463, reference: fv5488.path.split("/").fetch(-2),
                )

                if fv5490
                  fv5470 = fv5489 || fv5452
                  fv5470.host!(fv5487)
                  fv5470.https!
                  fv5470.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5486 = fv5488.request_uri
                  fv5477 = fv5461.merge(
                    "Host" => fv5487,
                    "Origin" => "https://#{fv5487}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5470.get(fv5486, headers: fv5477)
                  fv5480, fv5478, fv5479 =
                    begin
                      fv5485 = fv5470.response.body
                      fv5484 = false
                      fv5483 = Nokogiri::HTML(fv5485).at_css("form")
                      if fv5483.nil? && fv5484
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5483

                        fv5482 = fv5483.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5482.blank?

                        fv5481 = fv5483.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5483["action"], fv5482, fv5481]
                      end
                    end
                  fv5470.post(
                    fv5480,
                    params: fv5479.merge(authenticity_token: fv5478),
                    headers: fv5477,
                  )
                  begin
                    fv5471 = fv5470
                    fv5473 = "session"
                    fv5472 = fv5471.response.cookies[fv5473]
                    if fv5472.nil?
                      fv5476 = fv5471.response.headers["Set-Cookie"] || fv5471.response.headers["set-cookie"]
                      fv5475 =
                        if fv5476.is_a?(String) && fv5476.start_with?("[")
                          JSON.parse(fv5476)
                        else
                          Array(fv5476)
                        end
                      fv5474 =
                        fv5475.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5473}=")
                        end
                      if fv5474

                        _, fv5472 = fv5474.split(";", 2).first.to_s.split("=", 2)
                        fv5472 = Rack::Utils.unescape(fv5472.to_s)
                      end
                    end

                    unless fv5472.nil?
                      fv5471.cookies.delete(fv5473)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5471.cookies.merge(
                        "#{fv5473}=#{Rack::Utils.escape(fv5472)}",
                        URI.parse("https://#{fv5471.host}/"),
                      )
                    end
                  end
                  fv5469 = fv5470.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5469.blank?

                  fv5466 = URI.parse(fv5469)
                  if fv5468[:ri].present?
                    fv5467 = Rack::Utils.parse_nested_query(fv5466.query.to_s)
                    fv5467["ri"] ||= fv5468[:ri].to_s
                    fv5466.query = URI.encode_www_form(fv5467)
                  end
                  fv5452.host!(fv5466.host)
                  fv5452.https!
                  fv5465 = fv5466.request_uri
                  fv5448 = fv5461.merge("Host" => fv5466.host)
                  fv5452.get(fv5465, headers: fv5448)
                else
                  fv5462.confirm_base!(
                    base_token: fv5464,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5463,
                      entry_ref: fv5462.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5460 = fv5452.host
                  fv5452.host!(fv5460)
                  fv5452.https!
                  fv5448 = fv5461.merge("Host" => fv5460)
                  fv5452.get(fv5459, params: fv5458, headers: fv5448)
                end
                fv5451, fv5449, fv5450 =
                  begin
                    fv5457 = fv5452.response.body
                    fv5456 = false
                    fv5455 = Nokogiri::HTML(fv5457).at_css("form")
                    if fv5455.nil? && fv5456
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5455

                      fv5454 = fv5455.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5454.blank?

                      fv5453 = fv5455.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5455["action"], fv5454, fv5453]
                    end
                  end
                fv5452.post(
                  fv5451,
                  params: fv5450.merge(authenticity_token: fv5449),
                  headers: fv5448,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result_code = Valkey::AuthState::OpaqueAdmissionStore.new.issue!(
      purpose: "authentication_result",
      actor_type: "visitor",
      surface: "com",
      subject_ref: transaction.transaction_id,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result: result_code, transaction_ref: transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
    assert_not transaction.reload.consumed?

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result_code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "org authorize refuses a result whose ceremony is not ready" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "operator").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5447 = auth
          fv5446 = "/sign/in"
          fv5445 = entry_ref
          fv5444 = :entry_ref
          fv5443 = { ri: "jp" }
          fv5442 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5441 = true
          fv5440 = self
          begin
            fv5388 = fv5447
            fv5395 = fv5446
            fv5438 = fv5445
            fv5439 = fv5444
            fv5404 = fv5443
            fv5397 = fv5442
            fv5426 = fv5441
            fv5425 = fv5440
            fv5400 = nil
            fv5394 = fv5404.merge(fv5439 => fv5438)
            fv5388.get(fv5395, params: fv5394, headers: fv5397)
            fv5432 =
              begin
                fv5437 = fv5388.response.body
                fv5436 = true
                fv5435 = Nokogiri::HTML(fv5437).at_css("form")
                if fv5435.nil? && fv5436
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5435

                  fv5434 = fv5435.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5434.blank?

                  fv5433 = fv5435.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5435["action"], fv5434, fv5433]
                end
              end
            if fv5432

              fv5431, fv5429, fv5430 = fv5432

              fv5388.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5388.post(
                fv5431,
                params: fv5430.merge(authenticity_token: fv5429),
                headers: fv5397,
              )
              fv5428 = fv5388.response.location
              if fv5428.present?

                fv5424 = URI.parse(fv5428)
                fv5423 = fv5424.host
                fv5399 =
                  begin
                    fv5427 = fv5423
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5427)
                  end
                fv5398 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5399, reference: fv5424.path.split("/").fetch(-2),
                )

                if fv5426
                  fv5406 = fv5425 || fv5388
                  fv5406.host!(fv5423)
                  fv5406.https!
                  fv5406.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5422 = fv5424.request_uri
                  fv5413 = fv5397.merge(
                    "Host" => fv5423,
                    "Origin" => "https://#{fv5423}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5406.get(fv5422, headers: fv5413)
                  fv5416, fv5414, fv5415 =
                    begin
                      fv5421 = fv5406.response.body
                      fv5420 = false
                      fv5419 = Nokogiri::HTML(fv5421).at_css("form")
                      if fv5419.nil? && fv5420
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5419

                        fv5418 = fv5419.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5418.blank?

                        fv5417 = fv5419.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5419["action"], fv5418, fv5417]
                      end
                    end
                  fv5406.post(
                    fv5416,
                    params: fv5415.merge(authenticity_token: fv5414),
                    headers: fv5413,
                  )
                  begin
                    fv5407 = fv5406
                    fv5409 = "session"
                    fv5408 = fv5407.response.cookies[fv5409]
                    if fv5408.nil?
                      fv5412 = fv5407.response.headers["Set-Cookie"] || fv5407.response.headers["set-cookie"]
                      fv5411 =
                        if fv5412.is_a?(String) && fv5412.start_with?("[")
                          JSON.parse(fv5412)
                        else
                          Array(fv5412)
                        end
                      fv5410 =
                        fv5411.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5409}=")
                        end
                      if fv5410

                        _, fv5408 = fv5410.split(";", 2).first.to_s.split("=", 2)
                        fv5408 = Rack::Utils.unescape(fv5408.to_s)
                      end
                    end

                    unless fv5408.nil?
                      fv5407.cookies.delete(fv5409)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5407.cookies.merge(
                        "#{fv5409}=#{Rack::Utils.escape(fv5408)}",
                        URI.parse("https://#{fv5407.host}/"),
                      )
                    end
                  end
                  fv5405 = fv5406.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5405.blank?

                  fv5402 = URI.parse(fv5405)
                  if fv5404[:ri].present?
                    fv5403 = Rack::Utils.parse_nested_query(fv5402.query.to_s)
                    fv5403["ri"] ||= fv5404[:ri].to_s
                    fv5402.query = URI.encode_www_form(fv5403)
                  end
                  fv5388.host!(fv5402.host)
                  fv5388.https!
                  fv5401 = fv5402.request_uri
                  fv5384 = fv5397.merge("Host" => fv5402.host)
                  fv5388.get(fv5401, headers: fv5384)
                else
                  fv5398.confirm_base!(
                    base_token: fv5400,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5399,
                      entry_ref: fv5398.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5396 = fv5388.host
                  fv5388.host!(fv5396)
                  fv5388.https!
                  fv5384 = fv5397.merge("Host" => fv5396)
                  fv5388.get(fv5395, params: fv5394, headers: fv5384)
                end
                fv5387, fv5385, fv5386 =
                  begin
                    fv5393 = fv5388.response.body
                    fv5392 = false
                    fv5391 = Nokogiri::HTML(fv5393).at_css("form")
                    if fv5391.nil? && fv5392
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5391

                      fv5390 = fv5391.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5390.blank?

                      fv5389 = fv5391.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5391["action"], fv5390, fv5389]
                    end
                  end
                fv5388.post(
                  fv5387,
                  params: fv5386.merge(authenticity_token: fv5385),
                  headers: fv5384,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result_code = Valkey::AuthState::OpaqueAdmissionStore.new.issue!(
      purpose: "authentication_result",
      actor_type: "operator",
      surface: "org",
      subject_ref: transaction.transaction_id,
    )

    post base_org_oauth_authorization_url(host: host),
         params: { result: result_code, transaction_ref: transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
    assert_not transaction.reload.consumed?

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result_code,
      expected: {
        actor_type: "operator",
        surface: "org",
        subject_ref: transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "com authorize refuses an expired result ceremony" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "visitor").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5383 = auth
          fv5382 = "/sign/in"
          fv5381 = entry_ref
          fv5380 = :entry_ref
          fv5379 = { ri: "jp" }
          fv5378 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5377 = true
          fv5376 = self
          begin
            fv5324 = fv5383
            fv5331 = fv5382
            fv5374 = fv5381
            fv5375 = fv5380
            fv5340 = fv5379
            fv5333 = fv5378
            fv5362 = fv5377
            fv5361 = fv5376
            fv5336 = nil
            fv5330 = fv5340.merge(fv5375 => fv5374)
            fv5324.get(fv5331, params: fv5330, headers: fv5333)
            fv5368 =
              begin
                fv5373 = fv5324.response.body
                fv5372 = true
                fv5371 = Nokogiri::HTML(fv5373).at_css("form")
                if fv5371.nil? && fv5372
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5371

                  fv5370 = fv5371.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5370.blank?

                  fv5369 = fv5371.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5371["action"], fv5370, fv5369]
                end
              end
            if fv5368

              fv5367, fv5365, fv5366 = fv5368

              fv5324.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5324.post(
                fv5367,
                params: fv5366.merge(authenticity_token: fv5365),
                headers: fv5333,
              )
              fv5364 = fv5324.response.location
              if fv5364.present?

                fv5360 = URI.parse(fv5364)
                fv5359 = fv5360.host
                fv5335 =
                  begin
                    fv5363 = fv5359
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5363)
                  end
                fv5334 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5335, reference: fv5360.path.split("/").fetch(-2),
                )

                if fv5362
                  fv5342 = fv5361 || fv5324
                  fv5342.host!(fv5359)
                  fv5342.https!
                  fv5342.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5358 = fv5360.request_uri
                  fv5349 = fv5333.merge(
                    "Host" => fv5359,
                    "Origin" => "https://#{fv5359}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5342.get(fv5358, headers: fv5349)
                  fv5352, fv5350, fv5351 =
                    begin
                      fv5357 = fv5342.response.body
                      fv5356 = false
                      fv5355 = Nokogiri::HTML(fv5357).at_css("form")
                      if fv5355.nil? && fv5356
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5355

                        fv5354 = fv5355.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5354.blank?

                        fv5353 = fv5355.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5355["action"], fv5354, fv5353]
                      end
                    end
                  fv5342.post(
                    fv5352,
                    params: fv5351.merge(authenticity_token: fv5350),
                    headers: fv5349,
                  )
                  begin
                    fv5343 = fv5342
                    fv5345 = "session"
                    fv5344 = fv5343.response.cookies[fv5345]
                    if fv5344.nil?
                      fv5348 = fv5343.response.headers["Set-Cookie"] || fv5343.response.headers["set-cookie"]
                      fv5347 =
                        if fv5348.is_a?(String) && fv5348.start_with?("[")
                          JSON.parse(fv5348)
                        else
                          Array(fv5348)
                        end
                      fv5346 =
                        fv5347.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5345}=")
                        end
                      if fv5346

                        _, fv5344 = fv5346.split(";", 2).first.to_s.split("=", 2)
                        fv5344 = Rack::Utils.unescape(fv5344.to_s)
                      end
                    end

                    unless fv5344.nil?
                      fv5343.cookies.delete(fv5345)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5343.cookies.merge(
                        "#{fv5345}=#{Rack::Utils.escape(fv5344)}",
                        URI.parse("https://#{fv5343.host}/"),
                      )
                    end
                  end
                  fv5341 = fv5342.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5341.blank?

                  fv5338 = URI.parse(fv5341)
                  if fv5340[:ri].present?
                    fv5339 = Rack::Utils.parse_nested_query(fv5338.query.to_s)
                    fv5339["ri"] ||= fv5340[:ri].to_s
                    fv5338.query = URI.encode_www_form(fv5339)
                  end
                  fv5324.host!(fv5338.host)
                  fv5324.https!
                  fv5337 = fv5338.request_uri
                  fv5320 = fv5333.merge("Host" => fv5338.host)
                  fv5324.get(fv5337, headers: fv5320)
                else
                  fv5334.confirm_base!(
                    base_token: fv5336,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5335,
                      entry_ref: fv5334.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5332 = fv5324.host
                  fv5324.host!(fv5332)
                  fv5324.https!
                  fv5320 = fv5333.merge("Host" => fv5332)
                  fv5324.get(fv5331, params: fv5330, headers: fv5320)
                end
                fv5323, fv5321, fv5322 =
                  begin
                    fv5329 = fv5324.response.body
                    fv5328 = false
                    fv5327 = Nokogiri::HTML(fv5329).at_css("form")
                    if fv5327.nil? && fv5328
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5327

                      fv5326 = fv5327.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5326.blank?

                      fv5325 = fv5327.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5327["action"], fv5326, fv5325]
                    end
                  end
                fv5324.post(
                  fv5323,
                  params: fv5322.merge(authenticity_token: fv5321),
                  headers: fv5320,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: transaction.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-expired-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )
    decision_time = transaction.class.database_now
    transaction.update!(login_challenge_expires_at: decision_time - 1.second)

    post base_com_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result.code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: result.transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "org authorize refuses an expired result ceremony" do
    host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "operator").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5319 = auth
          fv5318 = "/sign/in"
          fv5317 = entry_ref
          fv5316 = :entry_ref
          fv5315 = { ri: "jp" }
          fv5314 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5313 = true
          fv5312 = self
          begin
            fv5260 = fv5319
            fv5267 = fv5318
            fv5310 = fv5317
            fv5311 = fv5316
            fv5276 = fv5315
            fv5269 = fv5314
            fv5298 = fv5313
            fv5297 = fv5312
            fv5272 = nil
            fv5266 = fv5276.merge(fv5311 => fv5310)
            fv5260.get(fv5267, params: fv5266, headers: fv5269)
            fv5304 =
              begin
                fv5309 = fv5260.response.body
                fv5308 = true
                fv5307 = Nokogiri::HTML(fv5309).at_css("form")
                if fv5307.nil? && fv5308
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5307

                  fv5306 = fv5307.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5306.blank?

                  fv5305 = fv5307.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5307["action"], fv5306, fv5305]
                end
              end
            if fv5304

              fv5303, fv5301, fv5302 = fv5304

              fv5260.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5260.post(
                fv5303,
                params: fv5302.merge(authenticity_token: fv5301),
                headers: fv5269,
              )
              fv5300 = fv5260.response.location
              if fv5300.present?

                fv5296 = URI.parse(fv5300)
                fv5295 = fv5296.host
                fv5271 =
                  begin
                    fv5299 = fv5295
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5299)
                  end
                fv5270 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5271, reference: fv5296.path.split("/").fetch(-2),
                )

                if fv5298
                  fv5278 = fv5297 || fv5260
                  fv5278.host!(fv5295)
                  fv5278.https!
                  fv5278.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5294 = fv5296.request_uri
                  fv5285 = fv5269.merge(
                    "Host" => fv5295,
                    "Origin" => "https://#{fv5295}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5278.get(fv5294, headers: fv5285)
                  fv5288, fv5286, fv5287 =
                    begin
                      fv5293 = fv5278.response.body
                      fv5292 = false
                      fv5291 = Nokogiri::HTML(fv5293).at_css("form")
                      if fv5291.nil? && fv5292
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5291

                        fv5290 = fv5291.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5290.blank?

                        fv5289 = fv5291.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5291["action"], fv5290, fv5289]
                      end
                    end
                  fv5278.post(
                    fv5288,
                    params: fv5287.merge(authenticity_token: fv5286),
                    headers: fv5285,
                  )
                  begin
                    fv5279 = fv5278
                    fv5281 = "session"
                    fv5280 = fv5279.response.cookies[fv5281]
                    if fv5280.nil?
                      fv5284 = fv5279.response.headers["Set-Cookie"] || fv5279.response.headers["set-cookie"]
                      fv5283 =
                        if fv5284.is_a?(String) && fv5284.start_with?("[")
                          JSON.parse(fv5284)
                        else
                          Array(fv5284)
                        end
                      fv5282 =
                        fv5283.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5281}=")
                        end
                      if fv5282

                        _, fv5280 = fv5282.split(";", 2).first.to_s.split("=", 2)
                        fv5280 = Rack::Utils.unescape(fv5280.to_s)
                      end
                    end

                    unless fv5280.nil?
                      fv5279.cookies.delete(fv5281)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5279.cookies.merge(
                        "#{fv5281}=#{Rack::Utils.escape(fv5280)}",
                        URI.parse("https://#{fv5279.host}/"),
                      )
                    end
                  end
                  fv5277 = fv5278.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5277.blank?

                  fv5274 = URI.parse(fv5277)
                  if fv5276[:ri].present?
                    fv5275 = Rack::Utils.parse_nested_query(fv5274.query.to_s)
                    fv5275["ri"] ||= fv5276[:ri].to_s
                    fv5274.query = URI.encode_www_form(fv5275)
                  end
                  fv5260.host!(fv5274.host)
                  fv5260.https!
                  fv5273 = fv5274.request_uri
                  fv5256 = fv5269.merge("Host" => fv5274.host)
                  fv5260.get(fv5273, headers: fv5256)
                else
                  fv5270.confirm_base!(
                    base_token: fv5272,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5271,
                      entry_ref: fv5270.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5268 = fv5260.host
                  fv5260.host!(fv5268)
                  fv5260.https!
                  fv5256 = fv5269.merge("Host" => fv5268)
                  fv5260.get(fv5267, params: fv5266, headers: fv5256)
                end
                fv5259, fv5257, fv5258 =
                  begin
                    fv5265 = fv5260.response.body
                    fv5264 = false
                    fv5263 = Nokogiri::HTML(fv5265).at_css("form")
                    if fv5263.nil? && fv5264
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5263

                      fv5262 = fv5263.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5262.blank?

                      fv5261 = fv5263.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5263["action"], fv5262, fv5261]
                    end
                  end
                fv5260.post(
                  fv5259,
                  params: fv5258.merge(authenticity_token: fv5257),
                  headers: fv5256,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: transaction.login_challenge,
      actor: operators(:one), session_ref: "org-expired-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )
    decision_time = transaction.class.database_now
    transaction.update!(login_challenge_expires_at: decision_time - 1.second)

    post base_org_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_STAFF_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")

    still_available = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result.code,
      expected: {
        actor_type: "operator",
        surface: "org",
        subject_ref: result.transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  test "com result binding mismatch does not consume the result" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    first =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "visitor").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5255 = auth
          fv5254 = "/sign/in"
          fv5253 = entry_ref
          fv5252 = :entry_ref
          fv5251 = { ri: "jp" }
          fv5250 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5249 = true
          fv5248 = self
          begin
            fv5196 = fv5255
            fv5203 = fv5254
            fv5246 = fv5253
            fv5247 = fv5252
            fv5212 = fv5251
            fv5205 = fv5250
            fv5234 = fv5249
            fv5233 = fv5248
            fv5208 = nil
            fv5202 = fv5212.merge(fv5247 => fv5246)
            fv5196.get(fv5203, params: fv5202, headers: fv5205)
            fv5240 =
              begin
                fv5245 = fv5196.response.body
                fv5244 = true
                fv5243 = Nokogiri::HTML(fv5245).at_css("form")
                if fv5243.nil? && fv5244
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5243

                  fv5242 = fv5243.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5242.blank?

                  fv5241 = fv5243.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5243["action"], fv5242, fv5241]
                end
              end
            if fv5240

              fv5239, fv5237, fv5238 = fv5240

              fv5196.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5196.post(
                fv5239,
                params: fv5238.merge(authenticity_token: fv5237),
                headers: fv5205,
              )
              fv5236 = fv5196.response.location
              if fv5236.present?

                fv5232 = URI.parse(fv5236)
                fv5231 = fv5232.host
                fv5207 =
                  begin
                    fv5235 = fv5231
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5235)
                  end
                fv5206 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5207, reference: fv5232.path.split("/").fetch(-2),
                )

                if fv5234
                  fv5214 = fv5233 || fv5196
                  fv5214.host!(fv5231)
                  fv5214.https!
                  fv5214.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5230 = fv5232.request_uri
                  fv5221 = fv5205.merge(
                    "Host" => fv5231,
                    "Origin" => "https://#{fv5231}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5214.get(fv5230, headers: fv5221)
                  fv5224, fv5222, fv5223 =
                    begin
                      fv5229 = fv5214.response.body
                      fv5228 = false
                      fv5227 = Nokogiri::HTML(fv5229).at_css("form")
                      if fv5227.nil? && fv5228
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5227

                        fv5226 = fv5227.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5226.blank?

                        fv5225 = fv5227.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5227["action"], fv5226, fv5225]
                      end
                    end
                  fv5214.post(
                    fv5224,
                    params: fv5223.merge(authenticity_token: fv5222),
                    headers: fv5221,
                  )
                  begin
                    fv5215 = fv5214
                    fv5217 = "session"
                    fv5216 = fv5215.response.cookies[fv5217]
                    if fv5216.nil?
                      fv5220 = fv5215.response.headers["Set-Cookie"] || fv5215.response.headers["set-cookie"]
                      fv5219 =
                        if fv5220.is_a?(String) && fv5220.start_with?("[")
                          JSON.parse(fv5220)
                        else
                          Array(fv5220)
                        end
                      fv5218 =
                        fv5219.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5217}=")
                        end
                      if fv5218

                        _, fv5216 = fv5218.split(";", 2).first.to_s.split("=", 2)
                        fv5216 = Rack::Utils.unescape(fv5216.to_s)
                      end
                    end

                    unless fv5216.nil?
                      fv5215.cookies.delete(fv5217)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5215.cookies.merge(
                        "#{fv5217}=#{Rack::Utils.escape(fv5216)}",
                        URI.parse("https://#{fv5215.host}/"),
                      )
                    end
                  end
                  fv5213 = fv5214.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5213.blank?

                  fv5210 = URI.parse(fv5213)
                  if fv5212[:ri].present?
                    fv5211 = Rack::Utils.parse_nested_query(fv5210.query.to_s)
                    fv5211["ri"] ||= fv5212[:ri].to_s
                    fv5210.query = URI.encode_www_form(fv5211)
                  end
                  fv5196.host!(fv5210.host)
                  fv5196.https!
                  fv5209 = fv5210.request_uri
                  fv5192 = fv5205.merge("Host" => fv5210.host)
                  fv5196.get(fv5209, headers: fv5192)
                else
                  fv5206.confirm_base!(
                    base_token: fv5208,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5207,
                      entry_ref: fv5206.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5204 = fv5196.host
                  fv5196.host!(fv5204)
                  fv5196.https!
                  fv5192 = fv5205.merge("Host" => fv5204)
                  fv5196.get(fv5203, params: fv5202, headers: fv5192)
                end
                fv5195, fv5193, fv5194 =
                  begin
                    fv5201 = fv5196.response.body
                    fv5200 = false
                    fv5199 = Nokogiri::HTML(fv5201).at_css("form")
                    if fv5199.nil? && fv5200
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5199

                      fv5198 = fv5199.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5198.blank?

                      fv5197 = fv5199.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5199["action"], fv5198, fv5197]
                    end
                  end
                fv5196.post(
                  fv5195,
                  params: fv5194.merge(authenticity_token: fv5193),
                  headers: fv5192,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    first_binding = binding
    second =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get(
          "/oauth/authorize", params: authorize_params(realm: "visitor").merge(state: "second").merge(ri: "jp"),
                              headers: start_headers,
        )

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5191 = auth
          fv5190 = "/sign/in"
          fv5189 = entry_ref
          fv5188 = :entry_ref
          fv5187 = { ri: "jp" }
          fv5186 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5185 = true
          fv5184 = self
          begin
            fv5132 = fv5191
            fv5139 = fv5190
            fv5182 = fv5189
            fv5183 = fv5188
            fv5148 = fv5187
            fv5141 = fv5186
            fv5170 = fv5185
            fv5169 = fv5184
            fv5144 = nil
            fv5138 = fv5148.merge(fv5183 => fv5182)
            fv5132.get(fv5139, params: fv5138, headers: fv5141)
            fv5176 =
              begin
                fv5181 = fv5132.response.body
                fv5180 = true
                fv5179 = Nokogiri::HTML(fv5181).at_css("form")
                if fv5179.nil? && fv5180
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5179

                  fv5178 = fv5179.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5178.blank?

                  fv5177 = fv5179.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5179["action"], fv5178, fv5177]
                end
              end
            if fv5176

              fv5175, fv5173, fv5174 = fv5176

              fv5132.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5132.post(
                fv5175,
                params: fv5174.merge(authenticity_token: fv5173),
                headers: fv5141,
              )
              fv5172 = fv5132.response.location
              if fv5172.present?

                fv5168 = URI.parse(fv5172)
                fv5167 = fv5168.host
                fv5143 =
                  begin
                    fv5171 = fv5167
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5171)
                  end
                fv5142 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5143, reference: fv5168.path.split("/").fetch(-2),
                )

                if fv5170
                  fv5150 = fv5169 || fv5132
                  fv5150.host!(fv5167)
                  fv5150.https!
                  fv5150.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5166 = fv5168.request_uri
                  fv5157 = fv5141.merge(
                    "Host" => fv5167,
                    "Origin" => "https://#{fv5167}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5150.get(fv5166, headers: fv5157)
                  fv5160, fv5158, fv5159 =
                    begin
                      fv5165 = fv5150.response.body
                      fv5164 = false
                      fv5163 = Nokogiri::HTML(fv5165).at_css("form")
                      if fv5163.nil? && fv5164
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5163

                        fv5162 = fv5163.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5162.blank?

                        fv5161 = fv5163.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5163["action"], fv5162, fv5161]
                      end
                    end
                  fv5150.post(
                    fv5160,
                    params: fv5159.merge(authenticity_token: fv5158),
                    headers: fv5157,
                  )
                  begin
                    fv5151 = fv5150
                    fv5153 = "session"
                    fv5152 = fv5151.response.cookies[fv5153]
                    if fv5152.nil?
                      fv5156 = fv5151.response.headers["Set-Cookie"] || fv5151.response.headers["set-cookie"]
                      fv5155 =
                        if fv5156.is_a?(String) && fv5156.start_with?("[")
                          JSON.parse(fv5156)
                        else
                          Array(fv5156)
                        end
                      fv5154 =
                        fv5155.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5153}=")
                        end
                      if fv5154

                        _, fv5152 = fv5154.split(";", 2).first.to_s.split("=", 2)
                        fv5152 = Rack::Utils.unescape(fv5152.to_s)
                      end
                    end

                    unless fv5152.nil?
                      fv5151.cookies.delete(fv5153)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5151.cookies.merge(
                        "#{fv5153}=#{Rack::Utils.escape(fv5152)}",
                        URI.parse("https://#{fv5151.host}/"),
                      )
                    end
                  end
                  fv5149 = fv5150.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5149.blank?

                  fv5146 = URI.parse(fv5149)
                  if fv5148[:ri].present?
                    fv5147 = Rack::Utils.parse_nested_query(fv5146.query.to_s)
                    fv5147["ri"] ||= fv5148[:ri].to_s
                    fv5146.query = URI.encode_www_form(fv5147)
                  end
                  fv5132.host!(fv5146.host)
                  fv5132.https!
                  fv5145 = fv5146.request_uri
                  fv5128 = fv5141.merge("Host" => fv5146.host)
                  fv5132.get(fv5145, headers: fv5128)
                else
                  fv5142.confirm_base!(
                    base_token: fv5144,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5143,
                      entry_ref: fv5142.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5140 = fv5132.host
                  fv5132.host!(fv5140)
                  fv5132.https!
                  fv5128 = fv5141.merge("Host" => fv5140)
                  fv5132.get(fv5139, params: fv5138, headers: fv5128)
                end
                fv5131, fv5129, fv5130 =
                  begin
                    fv5137 = fv5132.response.body
                    fv5136 = false
                    fv5135 = Nokogiri::HTML(fv5137).at_css("form")
                    if fv5135.nil? && fv5136
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5135

                      fv5134 = fv5135.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5134.blank?

                      fv5133 = fv5135.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5135["action"], fv5134, fv5133]
                    end
                  end
                fv5132.post(
                  fv5131,
                  params: fv5130.merge(authenticity_token: fv5129),
                  headers: fv5128,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: first.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-binding-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: first_binding.admitted_auth_ceremony_session_id.to_s,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: second.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_not_predicate first.reload, :consumed?

    post base_com_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: first.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :redirect
    assert_predicate first.reload, :consumed?
  end

  test "com invalid authorization parameters do not consume a valid result" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get(
          "/oauth/authorize", params: authorize_params(realm: "visitor").merge(ri: "jp"), headers: start_headers,
        )

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5127 = auth
          fv5126 = "/sign/in"
          fv5125 = entry_ref
          fv5124 = :entry_ref
          fv5123 = { ri: "jp" }
          fv5122 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5121 = true
          fv5120 = self
          begin
            fv5068 = fv5127
            fv5075 = fv5126
            fv5118 = fv5125
            fv5119 = fv5124
            fv5084 = fv5123
            fv5077 = fv5122
            fv5106 = fv5121
            fv5105 = fv5120
            fv5080 = nil
            fv5074 = fv5084.merge(fv5119 => fv5118)
            fv5068.get(fv5075, params: fv5074, headers: fv5077)
            fv5112 =
              begin
                fv5117 = fv5068.response.body
                fv5116 = true
                fv5115 = Nokogiri::HTML(fv5117).at_css("form")
                if fv5115.nil? && fv5116
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5115

                  fv5114 = fv5115.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5114.blank?

                  fv5113 = fv5115.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5115["action"], fv5114, fv5113]
                end
              end
            if fv5112

              fv5111, fv5109, fv5110 = fv5112

              fv5068.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5068.post(
                fv5111,
                params: fv5110.merge(authenticity_token: fv5109),
                headers: fv5077,
              )
              fv5108 = fv5068.response.location
              if fv5108.present?

                fv5104 = URI.parse(fv5108)
                fv5103 = fv5104.host
                fv5079 =
                  begin
                    fv5107 = fv5103
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5107)
                  end
                fv5078 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5079, reference: fv5104.path.split("/").fetch(-2),
                )

                if fv5106
                  fv5086 = fv5105 || fv5068
                  fv5086.host!(fv5103)
                  fv5086.https!
                  fv5086.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5102 = fv5104.request_uri
                  fv5093 = fv5077.merge(
                    "Host" => fv5103,
                    "Origin" => "https://#{fv5103}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5086.get(fv5102, headers: fv5093)
                  fv5096, fv5094, fv5095 =
                    begin
                      fv5101 = fv5086.response.body
                      fv5100 = false
                      fv5099 = Nokogiri::HTML(fv5101).at_css("form")
                      if fv5099.nil? && fv5100
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5099

                        fv5098 = fv5099.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5098.blank?

                        fv5097 = fv5099.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5099["action"], fv5098, fv5097]
                      end
                    end
                  fv5086.post(
                    fv5096,
                    params: fv5095.merge(authenticity_token: fv5094),
                    headers: fv5093,
                  )
                  begin
                    fv5087 = fv5086
                    fv5089 = "session"
                    fv5088 = fv5087.response.cookies[fv5089]
                    if fv5088.nil?
                      fv5092 = fv5087.response.headers["Set-Cookie"] || fv5087.response.headers["set-cookie"]
                      fv5091 =
                        if fv5092.is_a?(String) && fv5092.start_with?("[")
                          JSON.parse(fv5092)
                        else
                          Array(fv5092)
                        end
                      fv5090 =
                        fv5091.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5089}=")
                        end
                      if fv5090

                        _, fv5088 = fv5090.split(";", 2).first.to_s.split("=", 2)
                        fv5088 = Rack::Utils.unescape(fv5088.to_s)
                      end
                    end

                    unless fv5088.nil?
                      fv5087.cookies.delete(fv5089)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5087.cookies.merge(
                        "#{fv5089}=#{Rack::Utils.escape(fv5088)}",
                        URI.parse("https://#{fv5087.host}/"),
                      )
                    end
                  end
                  fv5085 = fv5086.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5085.blank?

                  fv5082 = URI.parse(fv5085)
                  if fv5084[:ri].present?
                    fv5083 = Rack::Utils.parse_nested_query(fv5082.query.to_s)
                    fv5083["ri"] ||= fv5084[:ri].to_s
                    fv5082.query = URI.encode_www_form(fv5083)
                  end
                  fv5068.host!(fv5082.host)
                  fv5068.https!
                  fv5081 = fv5082.request_uri
                  fv5064 = fv5077.merge("Host" => fv5082.host)
                  fv5068.get(fv5081, headers: fv5064)
                else
                  fv5078.confirm_base!(
                    base_token: fv5080,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5079,
                      entry_ref: fv5078.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5076 = fv5068.host
                  fv5068.host!(fv5076)
                  fv5068.https!
                  fv5064 = fv5077.merge("Host" => fv5076)
                  fv5068.get(fv5075, params: fv5074, headers: fv5064)
                end
                fv5067, fv5065, fv5066 =
                  begin
                    fv5073 = fv5068.response.body
                    fv5072 = false
                    fv5071 = Nokogiri::HTML(fv5073).at_css("form")
                    if fv5071.nil? && fv5072
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5071

                      fv5070 = fv5071.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5070.blank?

                      fv5069 = fv5071.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5071["action"], fv5070, fv5069]
                    end
                  end
                fv5068.post(
                  fv5067,
                  params: fv5066.merge(authenticity_token: fv5065),
                  headers: fv5064,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    # A valid start cannot stand in for receiver-time registry validation.
    transaction.update!(redirect_uri: "https://attacker.example/callback")
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "com", login_challenge: transaction.login_challenge,
      actor: visitors(:reserved_visitor), session_ref: "com-invalid-params-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")
    assert_predicate transaction.reload, :authenticated?

    replay = Valkey::AuthState::OpaqueAdmissionStore.new.consume!(
      purpose: "authentication_result",
      raw_code: result.code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: result.transaction.transaction_id,
      },
    )

    assert_predicate replay, :success?
  end

  test "com authorize does not consume a result with a different purpose" do
    host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "visitor").merge(ri: "jp"), headers: start_headers)

        assert_response :success
        start_form = response.parsed_body.at_css("form")
        start_fields = start_form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        post(start_form["action"], params: start_fields, headers: start_headers)

        assert_response :see_other
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "com", reference: entry_ref)
        auth = open_session
        auth_host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        auth.host!(auth_host)
        auth.https!
        begin
          fv5063 = auth
          fv5062 = "/sign/in"
          fv5061 = entry_ref
          fv5060 = :entry_ref
          fv5059 = { ri: "jp" }
          fv5058 = {
            "Host" => auth_host,
            "Origin" => "https://#{auth_host}",
            "Sec-Fetch-Site" => "same-origin",
          }
          fv5057 = true
          fv5056 = self
          begin
            fv5004 = fv5063
            fv5011 = fv5062
            fv5054 = fv5061
            fv5055 = fv5060
            fv5020 = fv5059
            fv5013 = fv5058
            fv5042 = fv5057
            fv5041 = fv5056
            fv5016 = nil
            fv5010 = fv5020.merge(fv5055 => fv5054)
            fv5004.get(fv5011, params: fv5010, headers: fv5013)
            fv5048 =
              begin
                fv5053 = fv5004.response.body
                fv5052 = true
                fv5051 = Nokogiri::HTML(fv5053).at_css("form")
                if fv5051.nil? && fv5052
                  nil
                else
                  raise RuntimeError, "Auth continuation form is missing" unless fv5051

                  fv5050 = fv5051.at_css("input[name='authenticity_token']")&.[]("value")
                  raise RuntimeError,
                        "Auth continuation is missing its CSRF token" if fv5050.blank?

                  fv5049 = fv5051.css("input[type='hidden']").to_h do |input|
                    [input["name"], input["value"]]
                  end.except("authenticity_token")
                  [fv5051["action"], fv5050, fv5049]
                end
              end
            if fv5048

              fv5047, fv5045, fv5046 = fv5048

              fv5004.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
              fv5004.post(
                fv5047,
                params: fv5046.merge(authenticity_token: fv5045),
                headers: fv5013,
              )
              fv5044 = fv5004.response.location
              if fv5044.present?

                fv5040 = URI.parse(fv5044)
                fv5039 = fv5040.host
                fv5015 =
                  begin
                    fv5043 = fv5039
                    {
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_CORPORATE_URL") => "com",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                    }.fetch(fv5043)
                  end
                fv5014 = BaseAuthAdmissionCoordinator.find_admission_binding_by_confirmation!(
                  surface: fv5015, reference: fv5040.path.split("/").fetch(-2),
                )

                if fv5042
                  fv5022 = fv5041 || fv5004
                  fv5022.host!(fv5039)
                  fv5022.https!
                  fv5022.session[BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY] ||=
                    "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn"
                  fv5038 = fv5040.request_uri
                  fv5029 = fv5013.merge(
                    "Host" => fv5039,
                    "Origin" => "https://#{fv5039}",
                    "Sec-Fetch-Site" => "same-origin",
                  )
                  fv5022.get(fv5038, headers: fv5029)
                  fv5032, fv5030, fv5031 =
                    begin
                      fv5037 = fv5022.response.body
                      fv5036 = false
                      fv5035 = Nokogiri::HTML(fv5037).at_css("form")
                      if fv5035.nil? && fv5036
                        nil
                      else
                        raise RuntimeError, "Auth continuation form is missing" unless fv5035

                        fv5034 = fv5035.at_css("input[name='authenticity_token']")&.[]("value")
                        raise RuntimeError,
                              "Auth continuation is missing its CSRF token" if fv5034.blank?

                        fv5033 = fv5035.css("input[type='hidden']").to_h do |input|
                          [input["name"], input["value"]]
                        end.except("authenticity_token")
                        [fv5035["action"], fv5034, fv5033]
                      end
                    end
                  fv5022.post(
                    fv5032,
                    params: fv5031.merge(authenticity_token: fv5030),
                    headers: fv5029,
                  )
                  begin
                    fv5023 = fv5022
                    fv5025 = "session"
                    fv5024 = fv5023.response.cookies[fv5025]
                    if fv5024.nil?
                      fv5028 = fv5023.response.headers["Set-Cookie"] || fv5023.response.headers["set-cookie"]
                      fv5027 =
                        if fv5028.is_a?(String) && fv5028.start_with?("[")
                          JSON.parse(fv5028)
                        else
                          Array(fv5028)
                        end
                      fv5026 =
                        fv5027.flat_map { |entry| entry.to_s.split("\n") }.find do |entry|
                          entry.split(";", 2).first.to_s.start_with?("#{fv5025}=")
                        end
                      if fv5026

                        _, fv5024 = fv5026.split(";", 2).first.to_s.split("=", 2)
                        fv5024 = Rack::Utils.unescape(fv5024.to_s)
                      end
                    end

                    unless fv5024.nil?
                      fv5023.cookies.delete(fv5025)
                      # Rack::Test's []= uses its default host. The current request may target a
                      # different surface, so install the cookie against the browser's active host.
                      fv5023.cookies.merge(
                        "#{fv5025}=#{Rack::Utils.escape(fv5024)}",
                        URI.parse("https://#{fv5023.host}/"),
                      )
                    end
                  end
                  fv5021 = fv5022.response.location
                  raise RuntimeError, "Base confirmation did not return to Auth" if fv5021.blank?

                  fv5018 = URI.parse(fv5021)
                  if fv5020[:ri].present?
                    fv5019 = Rack::Utils.parse_nested_query(fv5018.query.to_s)
                    fv5019["ri"] ||= fv5020[:ri].to_s
                    fv5018.query = URI.encode_www_form(fv5019)
                  end
                  fv5004.host!(fv5018.host)
                  fv5004.https!
                  fv5017 = fv5018.request_uri
                  fv5000 = fv5013.merge("Host" => fv5018.host)
                  fv5004.get(fv5017, headers: fv5000)
                else
                  fv5014.confirm_base!(
                    base_token: fv5016,
                    browser_digest: AuthAdmissionBinding.browser_digest(
                      surface: fv5015,
                      entry_ref: fv5014.entry_ref,
                      nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
                    ),
                  )
                  fv5012 = fv5004.host
                  fv5004.host!(fv5012)
                  fv5004.https!
                  fv5000 = fv5013.merge("Host" => fv5012)
                  fv5004.get(fv5011, params: fv5010, headers: fv5000)
                end
                fv5003, fv5001, fv5002 =
                  begin
                    fv5009 = fv5004.response.body
                    fv5008 = false
                    fv5007 = Nokogiri::HTML(fv5009).at_css("form")
                    if fv5007.nil? && fv5008
                      nil
                    else
                      raise RuntimeError, "Auth continuation form is missing" unless fv5007

                      fv5006 = fv5007.at_css("input[name='authenticity_token']")&.[]("value")
                      raise RuntimeError,
                            "Auth continuation is missing its CSRF token" if fv5006.blank?

                      fv5005 = fv5007.css("input[type='hidden']").to_h do |input|
                        [input["name"], input["value"]]
                      end.except("authenticity_token")
                      [fv5007["action"], fv5006, fv5005]
                    end
                  end
                fv5004.post(
                  fv5003,
                  params: fv5002.merge(authenticity_token: fv5001),
                  headers: fv5000,
                )
              end
            end
          end
        end

        assert_equal 303, auth.response.status
        authorization_transaction_for_test(binding.reload)
      end
    store = Valkey::AuthState::OpaqueAdmissionStore.new
    result_code = store.issue!(
      purpose: "invitation_result",
      actor_type: "visitor",
      surface: "com",
      subject_ref: transaction.transaction_id,
      reference: SecureRandom.uuid,
    )

    post base_com_oauth_authorization_url(host: host),
         params: { result: result_code, transaction_ref: transaction.transaction_id },
         headers: cross_surface_result_headers(host, "PUBLIC_AUTH_CORPORATE_URL")

    assert_response :bad_request
    assert_equal "invalid authorization request", response.parsed_body.fetch("error_description")

    still_available = store.consume!(
      purpose: "invitation_result",
      raw_code: result_code,
      expected: {
        actor_type: "visitor",
        surface: "com",
        subject_ref: transaction.transaction_id,
      },
    )

    assert_predicate still_available, :success?
  end

  private

  def cross_surface_result_headers(base_host, _auth_host_env)
    {
      "Host" => base_host,
      "Origin" => "https://#{base_host}",
      "Sec-Fetch-Site" => "same-origin",
    }
  end

  def authorize_params(realm:)
    client_id =
      {
        "client" => "core-app",
        "visitor" => "core-com",
        "operator" => "core-org",
      }.fetch(realm)

    {
      response_type: "code",
      client_id: client_id,
      redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "a" * 43,
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid",
    }
  end
end
