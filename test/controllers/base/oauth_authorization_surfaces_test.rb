# typed: false
# frozen_string_literal: true

require "test_helper"

# The OAuth authorization endpoint exists on the app and staff Visa surfaces and
# each one owns its own realm, validator resource type, and error mapping. The app
# surface is covered by BaseOauthOidcAuthorityTest; these pin the spec-defined
# error responses of the staff surface.
class BaseOauthAuthorizationSurfacesTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  include OidcAuthorizationResponseHelper

  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }

  test "org authorize returns a scope that omits openid to the RP as invalid_request" do
    host = visa_host_for_test_surface(:org)
    params = authorize_params(realm: "operator").merge(scope: "profile")

    get visa_org_oauth_authorization_url(host: host, **params), headers: { "Host" => host }

    assert_oidc_error_redirect(error: "invalid_request", redirect_uri: params[:redirect_uri])
  end

  test "org authorize returns a request with no state to the RP without a state" do
    host = visa_host_for_test_surface(:org)
    params = authorize_params(realm: "operator").except(:state)

    get visa_org_oauth_authorization_url(host: host, **params), headers: { "Host" => host }

    assert_oidc_error_redirect(error: "invalid_request", redirect_uri: params[:redirect_uri], state: nil)
  end

  test "org authorize rejects an unregistered client" do
    host = visa_host_for_test_surface(:org)

    get visa_org_oauth_authorization_url(
      host: host, **authorize_params(realm: "operator").merge(client_id: "not-registered"),
    ), headers: { "Host" => host }

    assert_response :bad_request
    assert_equal "invalid_request", response.parsed_body.fetch("error")
  end

  test "org authorize returns login_required for prompt none without a session" do
    [
      {
        host: visa_host_for_test_surface(:org),
        route: :visa_org_oauth_authorization_url,
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

  test "authorize accepts a 2048-byte parameter and refuses 2049 bytes before allocating state" do
    host = visa_host_for_test_surface(:app)
    base = authorize_params(realm: "client").except(:state).to_query

    { 2047 => true, 2048 => true, 2049 => false }.each do |bytes, accepted|
      count = ClientOidcAuthorizationTransaction.count
      get "/oauth/authorize?#{base}&state=#{"a" * bytes}", headers: { "Host" => host }

      if accepted
        assert_response :see_other, "#{bytes} bytes"
        assert_equal count + 1, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)

        assert_equal "a" * bytes,
                     ClientOidcAuthorizationTransaction.find(binding.authorization_transaction_id).state
      else
        assert_response :bad_request, "#{bytes} bytes"
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      end
    end
  end

  test "authorize accepts an 8192-byte query and refuses 8193 bytes before allocating state" do
    host = visa_host_for_test_surface(:app)
    padding = (1..3).map { |index| "pad#{index}=#{"b" * 2000}" }.join("&")
    base = "#{authorize_params(realm: "client").to_query}&#{padding}&pad4="

    { 8191 => true, 8192 => true, 8193 => false }.each do |bytes, accepted|
      query = "#{base}#{"c" * (bytes - base.bytesize)}"
      count = ClientOidcAuthorizationTransaction.count

      assert_equal bytes, query.bytesize
      get "/oauth/authorize?#{query}", headers: { "Host" => host }

      if accepted
        assert_response :see_other, "#{bytes} bytes"
        assert_equal count + 1, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
        target = URI.parse(jump_target_url(response.location))
        entry_ref = Rack::Utils.parse_query(target.query).fetch("entry_ref")

        assert BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: entry_ref)
      else
        assert_response :bad_request, "#{bytes} bytes"
        assert_equal count, ClientOidcAuthorizationTransaction.count, "#{bytes} bytes"
      end
    end
  end

  test "authorize refuses array and hash parameter values before allocating state" do
    host = visa_host_for_test_surface(:app)
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
  test "org authorize stages session-limit resolution without issuing a second root login" do
    host = visa_host_for_test_surface(:org)
    operator = operators(:one)
    OperatorToken.where(staff_id: operator.id).delete_all
    OperatorToken.create!(authentication_epoch: 0, staff_id: operator.id, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "operator").merge(ri: "jp"), headers: start_headers)

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
            **NAVIGATION_HEADERS,
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
                      visa_host_for_test_surface(:app) => "app",
                      visa_host_for_test_surface(:org) => "org",
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                      ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
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
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_equal "/ceremony_bindings", URI.parse(auth.response.location).path
        auth.get(auth.response.location, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_predicate binding.reload, :redeemed?
        binding.class.includes(:authorization_transaction).find(binding.id).authorization_transaction
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: transaction.login_challenge,
      actor: operator, session_ref: "org-limit-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )

    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      get "/oidc/result",
          params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id, ri: "jp" },
          headers: {
            "Sec-Fetch-Mode" => "navigate",
            "Sec-Fetch-Dest" => "document",
            "Sec-Fetch-Site" => "cross-site",
          }
    end

    assert_response :see_other
    assert_redirected_to visa_org_sign_in_limitation_path(ri: "jp")
    assert_not_predicate transaction.reload, :consumed?
    assert_nil transaction.browser_session_ref
  end

  test "org authorize refuses a finalized result without creating another root session" do
    host = visa_host_for_test_surface(:org)
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
            **NAVIGATION_HEADERS,
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
                      visa_host_for_test_surface(:app) => "app",
                      visa_host_for_test_surface(:org) => "org",
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                      ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
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
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_equal "/ceremony_bindings", URI.parse(auth.response.location).path
        auth.get(auth.response.location, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_predicate binding.reload, :redeemed?
        binding.class.includes(:authorization_transaction).find(binding.id).authorization_transaction
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: transaction.login_challenge,
      actor: operator, session_ref: "org-resume-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )

    get "/oidc/result",
        params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id, ri: "jp" },
        headers: {
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
          "Sec-Fetch-Site" => "cross-site",
        }

    assert_response :redirect
    assert_predicate transaction.reload, :consumed?
    browser_session_ref = transaction.browser_session_ref

    assert_predicate browser_session_ref, :present?
    assert_equal token_count_before + 1, OperatorToken.where(staff_id: operator.id).count

    get "/oidc/result",
        params: { result_ref: result.reference, transaction_ref: result.transaction.transaction_id, ri: "jp" },
        headers: {
          "Sec-Fetch-Mode" => "navigate",
          "Sec-Fetch-Dest" => "document",
          "Sec-Fetch-Site" => "cross-site",
        }

    # WU-27/D-104: a finalized result is terminal. SSO recovery starts from the RP;
    # the result itself is never reissued.
    assert_response :bad_request
    assert_equal browser_session_ref, transaction.reload.browser_session_ref
    assert_equal token_count_before + 1, OperatorToken.where(staff_id: operator.id).count
  end

  test "org authorize refuses a result whose ceremony is not ready" do
    host = visa_host_for_test_surface(:org)
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "operator").merge(ri: "jp"), headers: start_headers)

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
            **NAVIGATION_HEADERS,
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
                      visa_host_for_test_surface(:app) => "app",
                      visa_host_for_test_surface(:org) => "org",
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                      ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
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
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_equal "/ceremony_bindings", URI.parse(auth.response.location).path
        auth.get(auth.response.location, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_predicate binding.reload, :redeemed?
        binding.class.includes(:authorization_transaction).find(binding.id).authorization_transaction
      end
    result_code = Valkey::AuthState::OpaqueAdmissionStore.new.issue!(
      purpose: "authentication_result",
      actor_type: "operator",
      surface: "org",
      subject_ref: transaction.transaction_id,
    )

    post visa_org_oauth_authorization_url(host: host),
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

  test "org authorize refuses an expired result ceremony" do
    host = visa_host_for_test_surface(:org)
    transaction =
      begin
        https!
        host!(host)
        start_headers = { "Host" => host, "Origin" => "https://#{host}", "Sec-Fetch-Site" => "same-origin" }
        get("/oauth/authorize", params: authorize_params(realm: "operator").merge(ri: "jp"), headers: start_headers)

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
            **NAVIGATION_HEADERS,
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
                      visa_host_for_test_surface(:app) => "app",
                      visa_host_for_test_surface(:org) => "org",
                      ENV.fetch("PUBLIC_BASE_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_BASE_STAFF_URL") => "org",
                      ENV.fetch("PUBLIC_VISA_SERVICE_URL") => "app",
                      ENV.fetch("PUBLIC_VISA_STAFF_URL") => "org",
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
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_equal "/ceremony_bindings", URI.parse(auth.response.location).path
        auth.get(auth.response.location, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        binding.reload.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        auth.get("/sign/in", params: { entry_ref: binding.entry_ref, ri: "jp" }, headers: NAVIGATION_HEADERS)

        assert_equal 303, auth.response.status
        assert_predicate binding.reload, :redeemed?
        binding.class.includes(:authorization_transaction).find(binding.id).authorization_transaction
      end
    result = BaseAuthAdmissionCoordinator.register_result_and_issue!(
      surface: "org", login_challenge: transaction.login_challenge,
      actor: operators(:one), session_ref: "org-expired-session", auth_method: "passkey",
      authentication_event_at: Time.current,
      ceremony_session_ref: binding.admitted_auth_ceremony_session_id.to_s,
    )
    decision_time = transaction.class.database_now
    transaction.update!(login_challenge_expires_at: decision_time - 1.second)

    post visa_org_oauth_authorization_url(host: host),
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
        "client" => "core-app-jp",
        "operator" => "core-org-jp",
      }.fetch(realm)

    {
      response_type: "code",
      client_id: client_id,
      redirect_uri: OidcClientRegistry.find!(client_id).redirect_uris_by_realm.fetch(realm).first,
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid",
    }
  end
end
