# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Integration tests for social auth login intent
#
# These tests verify:
# - OPTIONAL: Login with existing identity doesn't create new Client
# - New user creation via social login
# - JWT/session tokens are issued on success
class SocialAuthLoginTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.enabled = true
    @original_login_cooldown = login_cooldown
    self.login_cooldown = 0.seconds
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @callback_headers = social_callback_headers(@host)
    @base_browser = open_session
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_browser.host!(base_host)
    @base_browser.https!
    @base_browser.get("/sign", params: { ri: "jp", pt: "/dashboard?ri=jp" })
    form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    @base_browser.post(
      form["action"], params: fields, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      },
    )
    issuer = JitSecurityJwtRegistry.surface("BASE_APP")
    2.times do |index|
      target = URI.parse(@base_browser.response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless target.host == base_host
        rt = Rack::Utils.parse_query(target.query).fetch("rt")
        payload, = JWT.decode(
          rt, JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        target = URI.parse(payload.fetch("url"))
      end
      if index.zero?
        raise RuntimeError, "Base authorization host mismatch" unless target.host == base_host

        @base_browser.get(target.request_uri)
        form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
        fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
        @base_browser.post(
          form["action"], params: fields, headers: {
            "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
          },
        )
      else
        raise RuntimeError, "Auth admission host mismatch" unless target.host == auth_host

        host!(auth_host)
        https!
        get(target.request_uri)
      end
    end
    3.times do |index|
      sender = (index == 1) ? @base_browser : self
      form = Nokogiri::HTML(sender.response.body).at_css("form")
      fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
      sender.post(
        form["action"], params: fields, headers: {
          "Origin" => "https://#{(index == 1) ? base_host : auth_host}", "Sec-Fetch-Site" => "same-origin",
        },
      )
      raise RuntimeError, "Social admission failed at step #{index}" unless sender.response.status == 303
      next if index == 2

      receiver = index.zero? ? @base_browser : self
      receiver.get(URI.parse(sender.response.location).request_uri)
    end
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.enabled = false
    self.login_cooldown = @original_login_cooldown
  end

  # ============================================================================
  # OPTIONAL: Login with existing identity doesn't create new user
  # ============================================================================
  test "Google login with existing identity does not create new user" do
    existing_uid = "existing_google_user_#{SecureRandom.hex(4)}"

    # Create existing user with Google identity
    existing_user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "ex_#{SecureRandom.hex(4)}")
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    setup_google_mock_auth(uid: existing_uid)

    user_count_before = Client.count

    state =
      begin
        fv5061 = "google"
        fv5060 = "login"
        fv5059 = nil
        begin
          lf0_provider = fv5061
          lf0_intent = fv5060
          lf0_user = nil
          lf0_entry = fv5059
          lf0_ri = "jp"
          lf0_rt = nil
          lf0_referer = nil
          lf0_host = @host.presence || configured_host(:sign_service)
          host!(lf0_host) if respond_to?(:host!)
          lf0_normalized_provider = SocialIdentifiable.normalize_provider(lf0_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf0_continue_path =
            if lf0_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf0_normalized_provider}_path",
                ri: lf0_ri,
              )
            elsif lf0_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf0_normalized_provider}_registration_path",
                ri: lf0_ri,
                rt: lf0_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf0_normalized_provider}_session_path",
                ri: lf0_ri,
                rt: lf0_rt,
              )
            end
          lf0_headers = social_callback_headers(lf0_host)
          lf0_headers["Referer"] = lf0_referer if lf0_referer.present?
          if lf0_user
            lf0_user_headers =
              begin
                rr0_headers =
                  begin
                    rp_headers = as_user_headers(lf0_user, host: lf0_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr0_host = rr0_headers["Host"]
                rr0_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr0_host}/") if rr0_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr0_family, rr0_surface = rr0_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr0_family) && rr0_surface == "app"
                  rr0_client_id =
                    case rr0_family
                    when "base" then "base-#{rr0_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr0_family}-#{rr0_surface}"
                    end
                  rr0_token = ClientToken.find_by!(public_id: rr0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr0_client = OidcClientRegistry.find!(rr0_client_id)
                  rr0_key = [rr0_client.client_id, rr0_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr0_key] && rr0_token.currently_usable? &&
                      !(rr0_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr0_token.device_session_id,
                        oidc_client_id: rr0_client.client_id,
                        revoked_at: nil,
                      ))
                    rr0_token.rotate_refresh_token! unless rr0_token.device_session_record.current_refresh_token_id
                    rr0_now = Time.current
                    rr0_session = ClientRpSession.create!(
                      client_token: rr0_token,
                      oidc_client_id: rr0_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr0_now,
                      refresh_token_expires_at: rr0_now + 10.minutes,
                    )
                    rr0_access = AuthenticationTokenService.encode(
                      rr0_token.actor_record,
                      host: rr0_host,
                      resource_type: "client",
                      session_public_id: rr0_token.public_id,
                      base_session_public_id: rr0_token.public_id,
                      oidc_sid: rr0_session.public_id,
                      oidc_jti: rr0_session.oidc_jti,
                      expires_at: rr0_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr0_client),
                      audiences: [rr0_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr0_client),
                      subject: OidcSubject.for(
                        rr0_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr0_client.client_id,
                    )
                    @base_browser_rp_credentials[rr0_key] =
                      [rr0_access, rr0_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr0_key]
                    rr0_access, rr0_refresh = @base_browser_rp_credentials.fetch(rr0_key)
                    rr0_cookie = [
                      rr0_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr0_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr0_refresh)}",
                    ].join("; ")
                    rr0_headers = rr0_headers.merge(
                      "Cookie" => rr0_cookie,
                      "HTTP_COOKIE" => rr0_cookie,
                    )
                  end
                end
                rr0_headers
              end
            lf0_token = ClientToken.find_by(public_id: lf0_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf0_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf0_intent.to_s == "link" && lf0_token
            lf0_headers = lf0_headers.merge(lf0_user_headers)
          end
          post(lf0_continue_path, headers: lf0_headers)
          social_auth_state_from_response
        end
      end

    # Callback
    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow0_form = response.parsed_body.at_css("form#social-completion-form")
        flow0_fields =
          flow0_form.css("input[name]").to_h { |flow0_input|
            [
              flow0_input["name"],
              flow0_input["value"],
            ]
          }
        flow0_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow0_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow0_pair| flow0_pair.start_with?("#{flow0_rails_cookie}=") }
        flow0_owner_cookie << "#{flow0_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow0_rails_cookie))}"
        post(
          flow0_form["action"], params: flow0_fields, headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow0_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow0_target = URI.parse(response.location)
      if flow0_target.path == "/sign/in/check"
        flow0_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow0_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow0_sid_cookie])
        flow0_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app", transaction_id: flow0_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow0_form = response.parsed_body.at_css("form")
        flow0_fields =
          flow0_form.css("input[name]").to_h { |flow0_input|
            [
              flow0_input["name"],
              flow0_input["value"],
            ]
          }
        post(
          flow0_form["action"], params: flow0_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow0_target = URI.parse(response.location)
        flow0_principal = Client.find_by!(public_id: flow0_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow0_principal)
      end
      break unless flow0_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion /oauth/authorize).include?(flow0_target.path)

      flow0_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow0_base_cookie = @base_browser.cookies.to_hash.map { |flow0_name, flow0_value|
        "#{flow0_name}=#{Rack::Utils.escape(flow0_value)}"
      }.join("; ")
      flow0_base_headers = { "Origin" => "https://#{flow0_base_host}",
                             "Sec-Fetch-Site" => "same-origin",
                             "Cookie" => flow0_base_cookie,
                             "HTTP_COOKIE" => flow0_base_cookie, }
      host!(flow0_base_host)
      https!
      get(flow0_target.request_uri, headers: flow0_base_headers)
      flow0_form = response.parsed_body.at_css("form")
      flow0_fields =
        flow0_form.css("input[name]").to_h { |flow0_input|
          [
            flow0_input["name"],
            flow0_input["value"],
          ]
        }
      post(flow0_form["action"], params: flow0_fields, headers: flow0_base_headers)
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(URI.parse(response.location).request_uri, headers: flow0_base_headers)
        flow0_form = response.parsed_body.at_css("form")
        flow0_fields =
          flow0_form.css("input[name]").to_h { |flow0_input|
            [
              flow0_input["name"],
              flow0_input["value"],
            ]
          }
        post(flow0_form["action"], params: flow0_fields, headers: flow0_base_headers)
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow0_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow0_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow0_callback_uri.host == flow0_base_host
        flow0_rt = Rack::Utils.parse_query(flow0_callback_uri.query).fetch("rt")
        flow0_payload, = JWT.decode(
          flow0_rt, JitSecurityJwtRegistry.public_key_for(flow0_issuer.id, flow0_issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow0_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow0_callback_uri = URI.parse(flow0_payload.fetch("url"))
      end
      flow0_protocol_browser = open_session
      flow0_protocol_browser.host!(flow0_base_host)
      flow0_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow0_transport =
        Faraday::Adapter::Test::Stubs.new do |flow0_stub|
          flow0_stub.post(/.*/) do |flow0_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow0_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow0_outer_actor = Actor.context
            flow0_executor_key = Rails.application.executor.active_key
            flow0_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow0_executor_key)
            begin
              flow0_protocol_browser.host!(flow0_env.url.authority)
              flow0_protocol_browser.https!(flow0_env.url.scheme == "https")
              flow0_protocol_browser.post(
                flow0_env.url.request_uri, params: Rack::Utils.parse_query(flow0_env.body),
                                           headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow0_executor_key] = flow0_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow0_outer_controller),
                          Actor.context.equal?(flow0_outer_actor), flow0_protocol_browser.response.status,]
            [flow0_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow0_protocol_browser.response.body,]
          end
          flow0_stub.get(/.*/) do |flow0_env|
            flow0_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow0_outer_actor = Actor.context
            flow0_executor_key = Rails.application.executor.active_key
            flow0_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow0_executor_key)
            begin
              flow0_protocol_browser.host!(flow0_env.url.authority)
              flow0_protocol_browser.https!(flow0_env.url.scheme == "https")
              flow0_protocol_browser.get(
                flow0_env.url.request_uri, headers: {
                  "Authorization" => flow0_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow0_executor_key] = flow0_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow0_outer_controller),
                          Actor.context.equal?(flow0_outer_actor), flow0_protocol_browser.response.status,]
            [flow0_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow0_protocol_browser.response.body,]
          end
        end
      flow0_connection =
        Faraday.new do |flow0_builder|
          flow0_builder.request(:url_encoded)
          flow0_builder.adapter(:test, flow0_transport)
        end
      OutboundHttp::Connection.stub(
        :build, ->(**flow0_args) {
          assert_equal flow0_base_host, flow0_args.fetch(:url).host
          flow0_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow0_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow0_transport.verify_stubbed_calls
    end

    assert_response :redirect

    # Client count should NOT increase
    assert_equal user_count_before, Client.count, "Existing user login should NOT create new user"

    assert_equal "/dashboard?ri=jp", URI.parse(response.location).request_uri
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    assert_predicate cookies[AuthenticationBase::REFRESH_COOKIE_KEY].to_s, :present?
    assert_equal 1, ClientToken.where(user_id: existing_user.id).count

    existing_user.reload

    assert_equal ClientStatus::NOTHING, existing_user.status_id
  end

  test "a duplicate provider subject loses the unique index and the callback uses the winning identity" do
    subject = "race_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: subject)
    winner = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    loser = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    identity = ClientGoogleIdentity.create!(
      user: winner,
      uid: subject,
      provider: "google",
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientGoogleIdentity.create!(
        user: loser,
        uid: subject,
        provider: "google",
        status_id: ClientGoogleIdentityStatus::ACTIVE,
      )
    end
    post auth_app_social_google_session_path(ri: "jp"), headers: @callback_headers
    state = social_auth_state_from_response
    assert_no_difference(["Client.count", "ClientExternalIdentity.count", "ClientToken.count"]) do
      get auth_app_social_google_callback_path(ri: "jp"), params: { state: state }, headers: @callback_headers
    end
    assert_equal URI.parse(auth_app_sign_in_check_url(ri: "jp")).path, URI.parse(response.location).path
    assert_equal winner.id, identity.reload.user_id
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flash, :empty?
  end

  test "Google login with existing identity completes on the app Dashboard, never Home" do
    existing_uid = "existing_google_welcome_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "wel_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    setup_google_mock_auth(uid: existing_uid)

    state =
      begin
        fv5055 = "google"
        fv5054 = "login"
        fv5053 = nil
        begin
          lf2_provider = fv5055
          lf2_intent = fv5054
          lf2_user = nil
          lf2_entry = fv5053
          lf2_ri = "jp"
          lf2_rt = nil
          lf2_referer = nil
          lf2_host = @host.presence || configured_host(:sign_service)
          host!(lf2_host) if respond_to?(:host!)
          lf2_normalized_provider = SocialIdentifiable.normalize_provider(lf2_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf2_continue_path =
            if lf2_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf2_normalized_provider}_path",
                ri: lf2_ri,
              )
            elsif lf2_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf2_normalized_provider}_registration_path",
                ri: lf2_ri,
                rt: lf2_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf2_normalized_provider}_session_path",
                ri: lf2_ri,
                rt: lf2_rt,
              )
            end
          lf2_headers = social_callback_headers(lf2_host)
          lf2_headers["Referer"] = lf2_referer if lf2_referer.present?
          if lf2_user
            lf2_user_headers =
              begin
                rr2_headers =
                  begin
                    rp_headers = as_user_headers(lf2_user, host: lf2_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr2_host = rr2_headers["Host"]
                rr2_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr2_host}/") if rr2_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr2_family, rr2_surface = rr2_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr2_family) && rr2_surface == "app"
                  rr2_client_id =
                    case rr2_family
                    when "base" then "base-#{rr2_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr2_family}-#{rr2_surface}"
                    end
                  rr2_token = ClientToken.find_by!(public_id: rr2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr2_client = OidcClientRegistry.find!(rr2_client_id)
                  rr2_key = [rr2_client.client_id, rr2_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr2_key] && rr2_token.currently_usable? &&
                      !(rr2_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr2_token.device_session_id,
                        oidc_client_id: rr2_client.client_id,
                        revoked_at: nil,
                      ))
                    rr2_token.rotate_refresh_token! unless rr2_token.device_session_record.current_refresh_token_id
                    rr2_now = Time.current
                    rr2_session = ClientRpSession.create!(
                      client_token: rr2_token,
                      oidc_client_id: rr2_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr2_now,
                      refresh_token_expires_at: rr2_now + 10.minutes,
                    )
                    rr2_access = AuthenticationTokenService.encode(
                      rr2_token.actor_record,
                      host: rr2_host,
                      resource_type: "client",
                      session_public_id: rr2_token.public_id,
                      base_session_public_id: rr2_token.public_id,
                      oidc_sid: rr2_session.public_id,
                      oidc_jti: rr2_session.oidc_jti,
                      expires_at: rr2_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr2_client),
                      audiences: [rr2_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr2_client),
                      subject: OidcSubject.for(
                        rr2_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr2_client.client_id,
                    )
                    @base_browser_rp_credentials[rr2_key] =
                      [rr2_access, rr2_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr2_key]
                    rr2_access, rr2_refresh = @base_browser_rp_credentials.fetch(rr2_key)
                    rr2_cookie = [
                      rr2_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr2_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr2_refresh)}",
                    ].join("; ")
                    rr2_headers = rr2_headers.merge(
                      "Cookie" => rr2_cookie,
                      "HTTP_COOKIE" => rr2_cookie,
                    )
                  end
                end
                rr2_headers
              end
            lf2_token = ClientToken.find_by(public_id: lf2_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf2_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf2_intent.to_s == "link" && lf2_token
            lf2_headers = lf2_headers.merge(lf2_user_headers)
          end
          post(lf2_continue_path, headers: lf2_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow1_form = response.parsed_body.at_css("form#social-completion-form")
        flow1_fields =
          flow1_form.css("input[name]").to_h { |flow1_input|
            [
              flow1_input["name"],
              flow1_input["value"],
            ]
          }
        flow1_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow1_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow1_pair| flow1_pair.start_with?("#{flow1_rails_cookie}=") }
        flow1_owner_cookie << "#{flow1_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow1_rails_cookie))}"
        post(
          flow1_form["action"], params: flow1_fields, headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow1_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow1_target = URI.parse(response.location)
      if flow1_target.path == "/sign/in/check"
        flow1_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow1_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow1_sid_cookie])
        flow1_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app", transaction_id: flow1_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow1_form = response.parsed_body.at_css("form")
        flow1_fields =
          flow1_form.css("input[name]").to_h { |flow1_input|
            [
              flow1_input["name"],
              flow1_input["value"],
            ]
          }
        post(
          flow1_form["action"], params: flow1_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow1_target = URI.parse(response.location)
        flow1_principal = Client.find_by!(public_id: flow1_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow1_principal)
      end
      break unless flow1_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion /oauth/authorize).include?(flow1_target.path)

      flow1_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow1_base_cookie = @base_browser.cookies.to_hash.map { |flow1_name, flow1_value|
        "#{flow1_name}=#{Rack::Utils.escape(flow1_value)}"
      }.join("; ")
      flow1_base_headers = { "Origin" => "https://#{flow1_base_host}",
                             "Sec-Fetch-Site" => "same-origin",
                             "Cookie" => flow1_base_cookie,
                             "HTTP_COOKIE" => flow1_base_cookie, }
      host!(flow1_base_host)
      https!
      get(flow1_target.request_uri, headers: flow1_base_headers)
      flow1_form = response.parsed_body.at_css("form")
      flow1_fields =
        flow1_form.css("input[name]").to_h { |flow1_input|
          [
            flow1_input["name"],
            flow1_input["value"],
          ]
        }
      post(flow1_form["action"], params: flow1_fields, headers: flow1_base_headers)
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(URI.parse(response.location).request_uri, headers: flow1_base_headers)
        flow1_form = response.parsed_body.at_css("form")
        flow1_fields =
          flow1_form.css("input[name]").to_h { |flow1_input|
            [
              flow1_input["name"],
              flow1_input["value"],
            ]
          }
        post(flow1_form["action"], params: flow1_fields, headers: flow1_base_headers)
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow1_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow1_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow1_callback_uri.host == flow1_base_host
        flow1_rt = Rack::Utils.parse_query(flow1_callback_uri.query).fetch("rt")
        flow1_payload, = JWT.decode(
          flow1_rt, JitSecurityJwtRegistry.public_key_for(
            flow1_issuer.id,
            flow1_issuer.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow1_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow1_callback_uri = URI.parse(flow1_payload.fetch("url"))
      end
      flow1_protocol_browser = open_session
      flow1_protocol_browser.host!(flow1_base_host)
      flow1_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow1_transport =
        Faraday::Adapter::Test::Stubs.new do |flow1_stub|
          flow1_stub.post(/.*/) do |flow1_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow1_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow1_outer_actor = Actor.context
            flow1_executor_key = Rails.application.executor.active_key
            flow1_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow1_executor_key)
            begin
              flow1_protocol_browser.host!(flow1_env.url.authority)
              flow1_protocol_browser.https!(flow1_env.url.scheme == "https")
              flow1_protocol_browser.post(
                flow1_env.url.request_uri, params: Rack::Utils.parse_query(flow1_env.body),
                                           headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow1_executor_key] = flow1_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow1_outer_controller),
                          Actor.context.equal?(flow1_outer_actor), flow1_protocol_browser.response.status,]
            [flow1_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow1_protocol_browser.response.body,]
          end
          flow1_stub.get(/.*/) do |flow1_env|
            flow1_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow1_outer_actor = Actor.context
            flow1_executor_key = Rails.application.executor.active_key
            flow1_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow1_executor_key)
            begin
              flow1_protocol_browser.host!(flow1_env.url.authority)
              flow1_protocol_browser.https!(flow1_env.url.scheme == "https")
              flow1_protocol_browser.get(
                flow1_env.url.request_uri, headers: {
                  "Authorization" => flow1_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow1_executor_key] = flow1_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow1_outer_controller),
                          Actor.context.equal?(flow1_outer_actor), flow1_protocol_browser.response.status,]
            [flow1_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow1_protocol_browser.response.body,]
          end
        end
      flow1_connection =
        Faraday.new do |flow1_builder|
          flow1_builder.request(:url_encoded)
          flow1_builder.adapter(:test, flow1_transport)
        end
      OutboundHttp::Connection.stub(
        :build, ->(**flow1_args) {
          assert_equal flow1_base_host, flow1_args.fetch(:url).host
          flow1_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow1_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow1_transport.verify_stubbed_calls
    end

    assert_response :redirect
    assert_social_login_lands_on_app_dashboard(response.location)

    cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowState::COMPLETED, cycle.state_id
  end

  test "Google login with session limit pending redirects to acme sign-in limitation" do
    existing_uid = "existing_google_session_limit_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "lim_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    2.times { create_active_user_session_for_limit(existing_user) }
    setup_google_mock_auth(uid: existing_uid)

    state =
      begin
        fv5052 = "google"
        fv5051 = "login"
        fv5050 = nil
        begin
          lf3_provider = fv5052
          lf3_intent = fv5051
          lf3_user = nil
          lf3_entry = fv5050
          lf3_ri = "jp"
          lf3_rt = nil
          lf3_referer = nil
          lf3_host = @host.presence || configured_host(:sign_service)
          host!(lf3_host) if respond_to?(:host!)
          lf3_normalized_provider = SocialIdentifiable.normalize_provider(lf3_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf3_continue_path =
            if lf3_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf3_normalized_provider}_path",
                ri: lf3_ri,
              )
            elsif lf3_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf3_normalized_provider}_registration_path",
                ri: lf3_ri,
                rt: lf3_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf3_normalized_provider}_session_path",
                ri: lf3_ri,
                rt: lf3_rt,
              )
            end
          lf3_headers = social_callback_headers(lf3_host)
          lf3_headers["Referer"] = lf3_referer if lf3_referer.present?
          if lf3_user
            lf3_user_headers =
              begin
                rr3_headers =
                  begin
                    rp_headers = as_user_headers(lf3_user, host: lf3_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr3_host = rr3_headers["Host"]
                rr3_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr3_host}/") if rr3_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr3_family, rr3_surface = rr3_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr3_family) && rr3_surface == "app"
                  rr3_client_id =
                    case rr3_family
                    when "base" then "base-#{rr3_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr3_family}-#{rr3_surface}"
                    end
                  rr3_token = ClientToken.find_by!(public_id: rr3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr3_client = OidcClientRegistry.find!(rr3_client_id)
                  rr3_key = [rr3_client.client_id, rr3_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr3_key] && rr3_token.currently_usable? &&
                      !(rr3_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr3_token.device_session_id,
                        oidc_client_id: rr3_client.client_id,
                        revoked_at: nil,
                      ))
                    rr3_token.rotate_refresh_token! unless rr3_token.device_session_record.current_refresh_token_id
                    rr3_now = Time.current
                    rr3_session = ClientRpSession.create!(
                      client_token: rr3_token,
                      oidc_client_id: rr3_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr3_now,
                      refresh_token_expires_at: rr3_now + 10.minutes,
                    )
                    rr3_access = AuthenticationTokenService.encode(
                      rr3_token.actor_record,
                      host: rr3_host,
                      resource_type: "client",
                      session_public_id: rr3_token.public_id,
                      base_session_public_id: rr3_token.public_id,
                      oidc_sid: rr3_session.public_id,
                      oidc_jti: rr3_session.oidc_jti,
                      expires_at: rr3_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr3_client),
                      audiences: [rr3_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr3_client),
                      subject: OidcSubject.for(
                        rr3_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr3_client.client_id,
                    )
                    @base_browser_rp_credentials[rr3_key] =
                      [rr3_access, rr3_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr3_key]
                    rr3_access, rr3_refresh = @base_browser_rp_credentials.fetch(rr3_key)
                    rr3_cookie = [
                      rr3_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr3_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr3_refresh)}",
                    ].join("; ")
                    rr3_headers = rr3_headers.merge(
                      "Cookie" => rr3_cookie,
                      "HTTP_COOKIE" => rr3_cookie,
                    )
                  end
                end
                rr3_headers
              end
            lf3_token = ClientToken.find_by(public_id: lf3_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf3_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf3_intent.to_s == "link" && lf3_token
            lf3_headers = lf3_headers.merge(lf3_user_headers)
          end
          post(lf3_continue_path, headers: lf3_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    assert_no_difference(-> { ClientToken.where(user_id: existing_user.id).count }) do
      1.times do
        if response.media_type == "text/html" && response.body.include?("social-completion-form")
          flow2_form = response.parsed_body.at_css("form#social-completion-form")
          flow2_fields =
            flow2_form.css("input[name]").to_h { |flow2_input|
              [
                flow2_input["name"],
                flow2_input["value"],
              ]
            }
          flow2_rails_cookie = Rails.application.config.session_options.fetch(:key)
          flow2_owner_cookie =
            request.headers["Cookie"].to_s.split("; ")
              .reject { |flow2_pair| flow2_pair.start_with?("#{flow2_rails_cookie}=") }
          flow2_owner_cookie << "#{flow2_rails_cookie}=#{Rack::Utils.escape(
            response
                        .cookies.fetch(flow2_rails_cookie),
          )}"
          post(
            flow2_form["action"],
            params: flow2_fields,
            headers: {
              "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
              "Cookie" => flow2_owner_cookie.join("; "),
              "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
          break
        end
        break unless response.redirect? && @base_browser

        flow2_target = URI.parse(response.location)
        if flow2_target.path == "/sign/in/check"
          flow2_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
          flow2_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow2_sid_cookie])
          flow2_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
            surface: "app",
            transaction_id: flow2_ceremony.authorization_transaction_ref,
          )
          get(auth_app_sign_oidc_handoff_path(ri: "jp"))
          flow2_form = response.parsed_body.at_css("form")
          flow2_fields =
            flow2_form.css("input[name]").to_h { |flow2_input|
              [
                flow2_input["name"],
                flow2_input["value"],
              ]
            }
          post(
            flow2_form["action"], params: flow2_fields, headers: {
              "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
              "Sec-Fetch-Site" => "same-origin",
            },
          )
          flow2_target = URI.parse(response.location)
          flow2_principal = Client.find_by!(public_id: flow2_parent.reload.actor_ref)
          BaseSelectorBootstrapAuthority.call(
            surface: :app,
            principal: flow2_principal,
          )
        end
        break unless flow2_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
          %w(/social/authentication/completion
             /oauth/authorize).include?(flow2_target.path)

        flow2_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
        flow2_base_cookie = @base_browser.cookies.to_hash.map { |flow2_name, flow2_value|
          "#{flow2_name}=#{Rack::Utils.escape(flow2_value)}"
        }.join("; ")
        flow2_base_headers = {
          "Origin" => "https://#{flow2_base_host}",
          "Sec-Fetch-Site" => "same-origin",
          "Cookie" => flow2_base_cookie,
          "HTTP_COOKIE" => flow2_base_cookie,
        }
        host!(flow2_base_host)
        https!
        get(
          flow2_target.request_uri,
          headers: flow2_base_headers,
        )
        flow2_form = response.parsed_body.at_css("form")
        flow2_fields =
          flow2_form.css("input[name]").to_h { |flow2_input|
            [
              flow2_input["name"],
              flow2_input["value"],
            ]
          }
        post(
          flow2_form["action"],
          params: flow2_fields,
          headers: flow2_base_headers,
        )
        if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
          get(
            URI.parse(response.location).request_uri,
            headers: flow2_base_headers,
          )
          flow2_form = response.parsed_body.at_css("form")
          flow2_fields =
            flow2_form.css("input[name]").to_h { |flow2_input|
              [
                flow2_input["name"],
                flow2_input["value"],
              ]
            }
          post(
            flow2_form["action"],
            params: flow2_fields,
            headers: flow2_base_headers,
          )
        end
        break unless response.redirect?
        # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
        break unless URI.parse(response.location).path == "/oidc/callback" ||
          URI.parse(response.location).host ==
            URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

        flow2_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
        flow2_callback_uri = URI.parse(response.location)
        # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
        unless flow2_callback_uri.host == flow2_base_host
          flow2_rt = Rack::Utils.parse_query(flow2_callback_uri.query).fetch("rt")
          flow2_payload, = JWT.decode(
            flow2_rt, JitSecurityJwtRegistry.public_key_for(
              flow2_issuer.id,
              flow2_issuer.current_kid,
            ), true,
            algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow2_base_host}",
            verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
          )
          flow2_callback_uri = URI.parse(flow2_payload.fetch("url"))
        end
        flow2_protocol_browser = open_session
        flow2_protocol_browser.host!(flow2_base_host)
        flow2_protocol_browser.https!
        # Substitute network transport only: the token and UserInfo requests still run
        # through their real public controllers, including PKCE and client authentication.
        flow2_transport =
          Faraday::Adapter::Test::Stubs.new do |flow2_stub|
            flow2_stub.post(/.*/) do |flow2_env|
              # The nested Rack executor must not complete the in-flight callback.
              flow2_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
              flow2_outer_actor = Actor.context
              flow2_executor_key = Rails.application.executor.active_key
              flow2_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow2_executor_key)
              begin
                flow2_protocol_browser.host!(flow2_env.url.authority)
                flow2_protocol_browser.https!(flow2_env.url.scheme == "https")
                flow2_protocol_browser.post(
                  flow2_env.url.request_uri,
                  params: Rack::Utils.parse_query(flow2_env.body),
                  headers: { "Accept" => "application/json" },
                )
              ensure
                ActiveSupport::IsolatedExecutionState[flow2_executor_key] =
                  flow2_outer_execution
              end

              assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow2_outer_controller) }
              assert_withheld { Actor.context.equal?(flow2_outer_actor) }
              assert_equal 200,
                           flow2_protocol_browser.response.status
              [flow2_protocol_browser.response.status, { "Content-Type" => "application/json" },
               flow2_protocol_browser.response.body,]
            end
            flow2_stub.get(/.*/) do |flow2_env|
              flow2_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
              flow2_outer_actor = Actor.context
              flow2_executor_key = Rails.application.executor.active_key
              flow2_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow2_executor_key)
              begin
                flow2_protocol_browser.host!(flow2_env.url.authority)
                flow2_protocol_browser.https!(flow2_env.url.scheme == "https")
                flow2_protocol_browser.get(
                  flow2_env.url.request_uri, headers: {
                    "Authorization" => flow2_env.request_headers.fetch("Authorization"),
                    "Accept" => "application/json",
                  },
                )
              ensure
                ActiveSupport::IsolatedExecutionState[flow2_executor_key] =
                  flow2_outer_execution
              end

              assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow2_outer_controller) }
              assert_withheld { Actor.context.equal?(flow2_outer_actor) }
              assert_equal 200,
                           flow2_protocol_browser.response.status
              [flow2_protocol_browser.response.status, { "Content-Type" => "application/json" },
               flow2_protocol_browser.response.body,]
            end
          end
        flow2_connection =
          Faraday.new do |flow2_builder|
            flow2_builder.request(:url_encoded)
            flow2_builder.adapter(
              :test,
              flow2_transport,
            )
          end
        OutboundHttp::Connection.stub(
          :build,
          ->(**flow2_args) {
            assert_equal flow2_base_host,
                         flow2_args.fetch(:url).host
            flow2_connection
          },
        ) do
          TestSupport::OutboundHttpGuard.allow do
            get(flow2_callback_uri.request_uri)
          end
        end

        assert_equal [true, true, true],
                     [response.redirect?,
                      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
        flow2_transport.verify_stubbed_calls
      end
    end

    # A same-host redirect on the Base host that ran the completion: the pending sign-in flow is held
    # by that host's Rails session, and the URL carries no grant of its own.
    assert_response :redirect
    redirect_uri = URI.parse(response.location)

    assert_equal "/sign/in/limitation", redirect_uri.path
    assert_nil Rack::Utils.parse_nested_query(redirect_uri.query.to_s)["social_resolution"]
    assert_equal 2, ClientToken.where(user_id: existing_user.id).count
    flow = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_predicate flow, :sign_in_session_issuance_pending?
    assert_predicate ClientSessionLimitResolutionTransaction.find_by!(sign_in_flow_id: flow.id), :open?

    # The limitation page itself, reached through the flow locator held by the Base session, is
    # exercised in test/controllers/base/app/sign/in/limitations_controller_test.rb.
  end

  def create_active_user_session_for_limit(user)
    token = ClientToken.new(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    token.save!
    token
  end

  test "Google established login callback posts a one-shot result to acme without provider tokens" do
    existing_uid = "existing_google_transport_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "trn_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: existing_uid,
      info: {},
      credentials: {
        token: "transport_access_token",
        refresh_token: "transport_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
    )

    state =
      begin
        fv5049 = "google"
        fv5048 = "login"
        fv5047 = nil
        begin
          lf4_provider = fv5049
          lf4_intent = fv5048
          lf4_user = nil
          lf4_entry = fv5047
          lf4_ri = "jp"
          lf4_rt = nil
          lf4_referer = nil
          lf4_host = @host.presence || configured_host(:sign_service)
          host!(lf4_host) if respond_to?(:host!)
          lf4_normalized_provider = SocialIdentifiable.normalize_provider(lf4_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf4_continue_path =
            if lf4_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf4_normalized_provider}_path",
                ri: lf4_ri,
              )
            elsif lf4_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf4_normalized_provider}_registration_path",
                ri: lf4_ri,
                rt: lf4_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf4_normalized_provider}_session_path",
                ri: lf4_ri,
                rt: lf4_rt,
              )
            end
          lf4_headers = social_callback_headers(lf4_host)
          lf4_headers["Referer"] = lf4_referer if lf4_referer.present?
          if lf4_user
            lf4_user_headers =
              begin
                rr4_headers =
                  begin
                    rp_headers = as_user_headers(lf4_user, host: lf4_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr4_host = rr4_headers["Host"]
                rr4_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr4_host}/") if rr4_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr4_family, rr4_surface = rr4_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr4_family) && rr4_surface == "app"
                  rr4_client_id =
                    case rr4_family
                    when "base" then "base-#{rr4_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr4_family}-#{rr4_surface}"
                    end
                  rr4_token = ClientToken.find_by!(public_id: rr4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr4_client = OidcClientRegistry.find!(rr4_client_id)
                  rr4_key = [rr4_client.client_id, rr4_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr4_key] && rr4_token.currently_usable? &&
                      !(rr4_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr4_token.device_session_id,
                        oidc_client_id: rr4_client.client_id,
                        revoked_at: nil,
                      ))
                    rr4_token.rotate_refresh_token! unless rr4_token.device_session_record.current_refresh_token_id
                    rr4_now = Time.current
                    rr4_session = ClientRpSession.create!(
                      client_token: rr4_token,
                      oidc_client_id: rr4_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr4_now,
                      refresh_token_expires_at: rr4_now + 10.minutes,
                    )
                    rr4_access = AuthenticationTokenService.encode(
                      rr4_token.actor_record,
                      host: rr4_host,
                      resource_type: "client",
                      session_public_id: rr4_token.public_id,
                      base_session_public_id: rr4_token.public_id,
                      oidc_sid: rr4_session.public_id,
                      oidc_jti: rr4_session.oidc_jti,
                      expires_at: rr4_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr4_client),
                      audiences: [rr4_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr4_client),
                      subject: OidcSubject.for(
                        rr4_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr4_client.client_id,
                    )
                    @base_browser_rp_credentials[rr4_key] =
                      [rr4_access, rr4_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr4_key]
                    rr4_access, rr4_refresh = @base_browser_rp_credentials.fetch(rr4_key)
                    rr4_cookie = [
                      rr4_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr4_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr4_refresh)}",
                    ].join("; ")
                    rr4_headers = rr4_headers.merge(
                      "Cookie" => rr4_cookie,
                      "HTTP_COOKIE" => rr4_cookie,
                    )
                  end
                end
                rr4_headers
              end
            lf4_token = ClientToken.find_by(public_id: lf4_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf4_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf4_intent.to_s == "link" && lf4_token
            lf4_headers = lf4_headers.merge(lf4_user_headers)
          end
          post(lf4_continue_path, headers: lf4_headers)
          social_auth_state_from_response
        end
      end

    assert_difference("ClientSignInFlow.count", 1) do
      assert_no_difference("ClientToken.count") do
        get auth_app_social_google_callback_url(ri: "jp"),
            params: { state: state }, headers: browser_headers.merge(@callback_headers)
      end
    end
    assert_response :see_other
    assert_equal "/sign/in/check", URI.parse(response.location).path
    get auth_app_sign_oidc_handoff_path(ri: "jp")

    assert_response :success
    form = response.parsed_body.at_css("form")
    fields = form.css("input[name]").to_h { |input| [input["name"], input["value"]] }
    post form["action"], params: fields, headers: {
      "Origin" => "https://#{@host}", "Sec-Fetch-Site" => "same-origin",
    }
    target = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), target.host
    assert_equal "/oauth/authorize", target.path
    assert_predicate Rack::Utils.parse_query(target.query)["result_ref"], :present?
    @base_browser.get(target.request_uri)
    document = Nokogiri::HTML(@base_browser.response.body)
    form = document.at_css("form")

    assert_equal 200, @base_browser.response.status
    assert_not_nil form
    assert_not_includes @base_browser.response.body, "transport_access_token"
    assert_not_includes @base_browser.response.body, "transport_refresh_token"
    assert_not_includes @base_browser.response.body, "old_token"
    assert_equal "post", form["method"]
    assert_equal "/oauth/authorize", form["action"]
    assert_not_nil form.at_css("input[name='result_ref']")
    assert_nil form.at_css("input[name='return_to']")
    assert_not_respond_to identity.reload, :token
  end

  test "Google sign up entry with existing identity falls through to sign in flow" do
    existing_uid = "existing_google_signup_entry_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "sug_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
    setup_google_mock_auth(uid: existing_uid)

    user_count_before = Client.count

    state =
      begin
        fv5046 = "google"
        fv5045 = "login"
        fv5044 = "sign_up"
        begin
          lf5_provider = fv5046
          lf5_intent = fv5045
          lf5_user = nil
          lf5_entry = fv5044
          lf5_ri = "jp"
          lf5_rt = nil
          lf5_referer = nil
          lf5_host = @host.presence || configured_host(:sign_service)
          host!(lf5_host) if respond_to?(:host!)
          lf5_normalized_provider = SocialIdentifiable.normalize_provider(lf5_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf5_continue_path =
            if lf5_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf5_normalized_provider}_path",
                ri: lf5_ri,
              )
            elsif lf5_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf5_normalized_provider}_registration_path",
                ri: lf5_ri,
                rt: lf5_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf5_normalized_provider}_session_path",
                ri: lf5_ri,
                rt: lf5_rt,
              )
            end
          lf5_headers = social_callback_headers(lf5_host)
          lf5_headers["Referer"] = lf5_referer if lf5_referer.present?
          if lf5_user
            lf5_user_headers =
              begin
                rr5_headers =
                  begin
                    rp_headers = as_user_headers(lf5_user, host: lf5_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr5_host = rr5_headers["Host"]
                rr5_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr5_host}/") if rr5_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr5_family, rr5_surface = rr5_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr5_family) && rr5_surface == "app"
                  rr5_client_id =
                    case rr5_family
                    when "base" then "base-#{rr5_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr5_family}-#{rr5_surface}"
                    end
                  rr5_token = ClientToken.find_by!(public_id: rr5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr5_client = OidcClientRegistry.find!(rr5_client_id)
                  rr5_key = [rr5_client.client_id, rr5_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr5_key] && rr5_token.currently_usable? &&
                      !(rr5_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr5_token.device_session_id,
                        oidc_client_id: rr5_client.client_id,
                        revoked_at: nil,
                      ))
                    rr5_token.rotate_refresh_token! unless rr5_token.device_session_record.current_refresh_token_id
                    rr5_now = Time.current
                    rr5_session = ClientRpSession.create!(
                      client_token: rr5_token,
                      oidc_client_id: rr5_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr5_now,
                      refresh_token_expires_at: rr5_now + 10.minutes,
                    )
                    rr5_access = AuthenticationTokenService.encode(
                      rr5_token.actor_record,
                      host: rr5_host,
                      resource_type: "client",
                      session_public_id: rr5_token.public_id,
                      base_session_public_id: rr5_token.public_id,
                      oidc_sid: rr5_session.public_id,
                      oidc_jti: rr5_session.oidc_jti,
                      expires_at: rr5_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr5_client),
                      audiences: [rr5_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr5_client),
                      subject: OidcSubject.for(
                        rr5_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr5_client.client_id,
                    )
                    @base_browser_rp_credentials[rr5_key] =
                      [rr5_access, rr5_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr5_key]
                    rr5_access, rr5_refresh = @base_browser_rp_credentials.fetch(rr5_key)
                    rr5_cookie = [
                      rr5_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr5_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr5_refresh)}",
                    ].join("; ")
                    rr5_headers = rr5_headers.merge(
                      "Cookie" => rr5_cookie,
                      "HTTP_COOKIE" => rr5_cookie,
                    )
                  end
                end
                rr5_headers
              end
            lf5_token = ClientToken.find_by(public_id: lf5_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf5_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf5_intent.to_s == "link" && lf5_token
            lf5_headers = lf5_headers.merge(lf5_user_headers)
          end
          post(lf5_continue_path, headers: lf5_headers)
          social_auth_state_from_response
        end
      end

    sign_up_cycle = ClientSignUpFlow.order(:id).last

    assert_equal "google", sign_up_cycle.entry_method
    assert_equal "social_callback", sign_up_cycle.step

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow3_form = response.parsed_body.at_css("form#social-completion-form")
        flow3_fields =
          flow3_form.css("input[name]").to_h { |flow3_input|
            [
              flow3_input["name"],
              flow3_input["value"],
            ]
          }
        flow3_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow3_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow3_pair| flow3_pair.start_with?("#{flow3_rails_cookie}=") }
        flow3_owner_cookie << "#{flow3_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow3_rails_cookie))}"
        post(
          flow3_form["action"], params: flow3_fields, headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow3_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow3_target = URI.parse(response.location)
      if flow3_target.path == "/sign/in/check"
        flow3_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow3_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow3_sid_cookie])
        flow3_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app", transaction_id: flow3_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow3_form = response.parsed_body.at_css("form")
        flow3_fields =
          flow3_form.css("input[name]").to_h { |flow3_input|
            [
              flow3_input["name"],
              flow3_input["value"],
            ]
          }
        post(
          flow3_form["action"], params: flow3_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow3_target = URI.parse(response.location)
        flow3_principal = Client.find_by!(public_id: flow3_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow3_principal)
      end
      break unless flow3_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion /oauth/authorize).include?(flow3_target.path)

      flow3_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow3_base_cookie = @base_browser.cookies.to_hash.map { |flow3_name, flow3_value|
        "#{flow3_name}=#{Rack::Utils.escape(flow3_value)}"
      }.join("; ")
      flow3_base_headers = { "Origin" => "https://#{flow3_base_host}",
                             "Sec-Fetch-Site" => "same-origin",
                             "Cookie" => flow3_base_cookie,
                             "HTTP_COOKIE" => flow3_base_cookie, }
      host!(flow3_base_host)
      https!
      get(flow3_target.request_uri, headers: flow3_base_headers)
      flow3_form = response.parsed_body.at_css("form")
      flow3_fields =
        flow3_form.css("input[name]").to_h { |flow3_input|
          [
            flow3_input["name"],
            flow3_input["value"],
          ]
        }
      post(
        flow3_form["action"],
        params: flow3_fields,
        headers: flow3_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(URI.parse(response.location).request_uri, headers: flow3_base_headers)
        flow3_form = response.parsed_body.at_css("form")
        flow3_fields =
          flow3_form.css("input[name]").to_h { |flow3_input|
            [
              flow3_input["name"],
              flow3_input["value"],
            ]
          }
        post(
          flow3_form["action"],
          params: flow3_fields,
          headers: flow3_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow3_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow3_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow3_callback_uri.host == flow3_base_host
        flow3_rt = Rack::Utils.parse_query(flow3_callback_uri.query).fetch("rt")
        flow3_payload, = JWT.decode(
          flow3_rt, JitSecurityJwtRegistry.public_key_for(
            flow3_issuer.id,
            flow3_issuer.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow3_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow3_callback_uri = URI.parse(flow3_payload.fetch("url"))
      end
      flow3_protocol_browser = open_session
      flow3_protocol_browser.host!(flow3_base_host)
      flow3_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow3_transport =
        Faraday::Adapter::Test::Stubs.new do |flow3_stub|
          flow3_stub.post(/.*/) do |flow3_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow3_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow3_outer_actor = Actor.context
            flow3_executor_key = Rails.application.executor.active_key
            flow3_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow3_executor_key)
            begin
              flow3_protocol_browser.host!(flow3_env.url.authority)
              flow3_protocol_browser.https!(flow3_env.url.scheme == "https")
              flow3_protocol_browser.post(
                flow3_env.url.request_uri,
                params: Rack::Utils.parse_query(flow3_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow3_executor_key] =
                flow3_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow3_outer_controller),
                          Actor.context.equal?(flow3_outer_actor), flow3_protocol_browser.response.status,]
            [flow3_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow3_protocol_browser.response.body,]
          end
          flow3_stub.get(/.*/) do |flow3_env|
            flow3_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow3_outer_actor = Actor.context
            flow3_executor_key = Rails.application.executor.active_key
            flow3_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow3_executor_key)
            begin
              flow3_protocol_browser.host!(flow3_env.url.authority)
              flow3_protocol_browser.https!(flow3_env.url.scheme == "https")
              flow3_protocol_browser.get(
                flow3_env.url.request_uri, headers: {
                  "Authorization" => flow3_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow3_executor_key] =
                flow3_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow3_outer_controller),
                          Actor.context.equal?(flow3_outer_actor), flow3_protocol_browser.response.status,]
            [flow3_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow3_protocol_browser.response.body,]
          end
        end
      flow3_connection =
        Faraday.new do |flow3_builder|
          flow3_builder.request(:url_encoded)
          flow3_builder.adapter(:test, flow3_transport)
        end
      OutboundHttp::Connection.stub(
        :build, ->(**flow3_args) {
          assert_equal flow3_base_host, flow3_args.fetch(:url).host
          flow3_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow3_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow3_transport.verify_stubbed_calls
    end

    assert_response :redirect
    assert_social_login_lands_on_app_dashboard(response.location)
    assert_equal user_count_before, Client.count

    sign_in_cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowState::COMPLETED, sign_in_cycle.reload.state_id
    assert_equal "social_callback", sign_up_cycle.reload.step
  end

  test "Google sign up entry without an existing identity creates the client, identity and ceremony" do
    new_uid = "new_google_signup_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    user_count_before = Client.count

    state =
      begin
        fv5043 = "google"
        fv5042 = "login"
        fv5041 = "sign_up"
        begin
          lf6_provider = fv5043
          lf6_intent = fv5042
          lf6_user = nil
          lf6_entry = fv5041
          lf6_ri = "jp"
          lf6_rt = nil
          lf6_referer = nil
          lf6_host = @host.presence || configured_host(:sign_service)
          host!(lf6_host) if respond_to?(:host!)
          lf6_normalized_provider = SocialIdentifiable.normalize_provider(lf6_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf6_continue_path =
            if lf6_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf6_normalized_provider}_path",
                ri: lf6_ri,
              )
            elsif lf6_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf6_normalized_provider}_registration_path",
                ri: lf6_ri,
                rt: lf6_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf6_normalized_provider}_session_path",
                ri: lf6_ri,
                rt: lf6_rt,
              )
            end
          lf6_headers = social_callback_headers(lf6_host)
          lf6_headers["Referer"] = lf6_referer if lf6_referer.present?
          if lf6_user
            lf6_user_headers =
              begin
                rr6_headers =
                  begin
                    rp_headers = as_user_headers(lf6_user, host: lf6_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr6_host = rr6_headers["Host"]
                rr6_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr6_host}/") if rr6_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr6_family, rr6_surface = rr6_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr6_family) && rr6_surface == "app"
                  rr6_client_id =
                    case rr6_family
                    when "base" then "base-#{rr6_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr6_family}-#{rr6_surface}"
                    end
                  rr6_token = ClientToken.find_by!(public_id: rr6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr6_client = OidcClientRegistry.find!(rr6_client_id)
                  rr6_key = [rr6_client.client_id, rr6_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr6_key] && rr6_token.currently_usable? &&
                      !(rr6_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr6_token.device_session_id,
                        oidc_client_id: rr6_client.client_id,
                        revoked_at: nil,
                      ))
                    rr6_token.rotate_refresh_token! unless rr6_token.device_session_record.current_refresh_token_id
                    rr6_now = Time.current
                    rr6_session = ClientRpSession.create!(
                      client_token: rr6_token,
                      oidc_client_id: rr6_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr6_now,
                      refresh_token_expires_at: rr6_now + 10.minutes,
                    )
                    rr6_access = AuthenticationTokenService.encode(
                      rr6_token.actor_record,
                      host: rr6_host,
                      resource_type: "client",
                      session_public_id: rr6_token.public_id,
                      base_session_public_id: rr6_token.public_id,
                      oidc_sid: rr6_session.public_id,
                      oidc_jti: rr6_session.oidc_jti,
                      expires_at: rr6_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr6_client),
                      audiences: [rr6_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr6_client),
                      subject: OidcSubject.for(
                        rr6_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr6_client.client_id,
                    )
                    @base_browser_rp_credentials[rr6_key] =
                      [rr6_access, rr6_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr6_key]
                    rr6_access, rr6_refresh = @base_browser_rp_credentials.fetch(rr6_key)
                    rr6_cookie = [
                      rr6_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr6_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr6_refresh)}",
                    ].join("; ")
                    rr6_headers = rr6_headers.merge(
                      "Cookie" => rr6_cookie,
                      "HTTP_COOKIE" => rr6_cookie,
                    )
                  end
                end
                rr6_headers
              end
            lf6_token = ClientToken.find_by(public_id: lf6_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf6_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf6_intent.to_s == "link" && lf6_token
            lf6_headers = lf6_headers.merge(lf6_user_headers)
          end
          post(lf6_continue_path, headers: lf6_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow4_form = response.parsed_body.at_css("form#social-completion-form")
        flow4_fields =
          flow4_form.css("input[name]").to_h { |flow4_input|
            [
              flow4_input["name"],
              flow4_input["value"],
            ]
          }
        flow4_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow4_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow4_pair| flow4_pair.start_with?("#{flow4_rails_cookie}=") }
        flow4_owner_cookie << "#{flow4_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow4_rails_cookie))}"
        post(
          flow4_form["action"], params: flow4_fields, headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow4_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow4_target = URI.parse(response.location)
      if flow4_target.path == "/sign/in/check"
        flow4_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow4_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow4_sid_cookie])
        flow4_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app", transaction_id: flow4_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow4_form = response.parsed_body.at_css("form")
        flow4_fields =
          flow4_form.css("input[name]").to_h { |flow4_input|
            [
              flow4_input["name"],
              flow4_input["value"],
            ]
          }
        post(
          flow4_form["action"], params: flow4_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow4_target = URI.parse(response.location)
        flow4_principal = Client.find_by!(public_id: flow4_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow4_principal)
      end
      break unless flow4_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion /oauth/authorize).include?(flow4_target.path)

      flow4_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow4_base_cookie = @base_browser.cookies.to_hash.map { |flow4_name, flow4_value|
        "#{flow4_name}=#{Rack::Utils.escape(flow4_value)}"
      }.join("; ")
      flow4_base_headers = {
        "Origin" => "https://#{flow4_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow4_base_cookie,
        "HTTP_COOKIE" => flow4_base_cookie,
      }
      host!(flow4_base_host)
      https!
      get(flow4_target.request_uri, headers: flow4_base_headers)
      flow4_form = response.parsed_body.at_css("form")
      flow4_fields =
        flow4_form.css("input[name]").to_h { |flow4_input|
          [
            flow4_input["name"],
            flow4_input["value"],
          ]
        }
      post(
        flow4_form["action"],
        params: flow4_fields,
        headers: flow4_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(URI.parse(response.location).request_uri, headers: flow4_base_headers)
        flow4_form = response.parsed_body.at_css("form")
        flow4_fields =
          flow4_form.css("input[name]").to_h { |flow4_input|
            [
              flow4_input["name"],
              flow4_input["value"],
            ]
          }
        post(
          flow4_form["action"],
          params: flow4_fields,
          headers: flow4_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow4_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow4_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow4_callback_uri.host == flow4_base_host
        flow4_rt = Rack::Utils.parse_query(flow4_callback_uri.query).fetch("rt")
        flow4_payload, = JWT.decode(
          flow4_rt, JitSecurityJwtRegistry.public_key_for(
            flow4_issuer.id,
            flow4_issuer.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow4_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow4_callback_uri = URI.parse(flow4_payload.fetch("url"))
      end
      flow4_protocol_browser = open_session
      flow4_protocol_browser.host!(flow4_base_host)
      flow4_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow4_transport =
        Faraday::Adapter::Test::Stubs.new do |flow4_stub|
          flow4_stub.post(/.*/) do |flow4_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow4_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow4_outer_actor = Actor.context
            flow4_executor_key = Rails.application.executor.active_key
            flow4_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow4_executor_key)
            begin
              flow4_protocol_browser.host!(flow4_env.url.authority)
              flow4_protocol_browser.https!(flow4_env.url.scheme == "https")
              flow4_protocol_browser.post(
                flow4_env.url.request_uri,
                params: Rack::Utils.parse_query(flow4_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow4_executor_key] =
                flow4_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow4_outer_controller),
                          Actor.context.equal?(flow4_outer_actor), flow4_protocol_browser.response.status,]
            [flow4_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow4_protocol_browser.response.body,]
          end
          flow4_stub.get(/.*/) do |flow4_env|
            flow4_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow4_outer_actor = Actor.context
            flow4_executor_key = Rails.application.executor.active_key
            flow4_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow4_executor_key)
            begin
              flow4_protocol_browser.host!(flow4_env.url.authority)
              flow4_protocol_browser.https!(flow4_env.url.scheme == "https")
              flow4_protocol_browser.get(
                flow4_env.url.request_uri, headers: {
                  "Authorization" => flow4_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow4_executor_key] =
                flow4_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow4_outer_controller),
                          Actor.context.equal?(flow4_outer_actor), flow4_protocol_browser.response.status,]
            [flow4_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow4_protocol_browser.response.body,]
          end
        end
      flow4_connection =
        Faraday.new do |flow4_builder|
          flow4_builder.request(:url_encoded)
          flow4_builder.adapter(:test, flow4_transport)
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow4_args) {
          assert_equal flow4_base_host,
                       flow4_args.fetch(:url).host
          flow4_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow4_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow4_transport.verify_stubbed_calls
    end

    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last
    patch auth_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    patch auth_app_sign_up_check_google_birthdate_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow5_form = response.parsed_body.at_css("form#social-completion-form")
        flow5_fields =
          flow5_form.css("input[name]").to_h { |flow5_input|
            [
              flow5_input["name"],
              flow5_input["value"],
            ]
          }
        flow5_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow5_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow5_pair| flow5_pair.start_with?("#{flow5_rails_cookie}=") }
        flow5_owner_cookie << "#{flow5_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow5_rails_cookie))}"
        post(
          flow5_form["action"],
          params: flow5_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow5_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow5_target = URI.parse(response.location)
      if flow5_target.path == "/sign/in/check"
        flow5_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow5_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow5_sid_cookie])
        flow5_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow5_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow5_form = response.parsed_body.at_css("form")
        flow5_fields =
          flow5_form.css("input[name]").to_h { |flow5_input|
            [
              flow5_input["name"],
              flow5_input["value"],
            ]
          }
        post(
          flow5_form["action"], params: flow5_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow5_target = URI.parse(response.location)
        flow5_principal = Client.find_by!(public_id: flow5_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow5_principal,
        )
      end
      break unless flow5_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow5_target.path)

      flow5_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow5_base_cookie = @base_browser.cookies.to_hash.map { |flow5_name, flow5_value|
        "#{flow5_name}=#{Rack::Utils.escape(flow5_value)}"
      }.join("; ")
      flow5_base_headers = {
        "Origin" => "https://#{flow5_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow5_base_cookie,
        "HTTP_COOKIE" => flow5_base_cookie,
      }
      host!(flow5_base_host)
      https!
      get(
        flow5_target.request_uri,
        headers: flow5_base_headers,
      )
      flow5_form = response.parsed_body.at_css("form")
      flow5_fields =
        flow5_form.css("input[name]").to_h { |flow5_input|
          [
            flow5_input["name"],
            flow5_input["value"],
          ]
        }
      post(
        flow5_form["action"],
        params: flow5_fields,
        headers: flow5_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(URI.parse(response.location).request_uri, headers: flow5_base_headers)
        flow5_form = response.parsed_body.at_css("form")
        flow5_fields =
          flow5_form.css("input[name]").to_h { |flow5_input|
            [
              flow5_input["name"],
              flow5_input["value"],
            ]
          }
        post(
          flow5_form["action"],
          params: flow5_fields,
          headers: flow5_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow5_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow5_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow5_callback_uri.host == flow5_base_host
        flow5_rt = Rack::Utils.parse_query(flow5_callback_uri.query).fetch("rt")
        flow5_payload, = JWT.decode(
          flow5_rt,
          JitSecurityJwtRegistry.public_key_for(
            flow5_issuer.id,
            flow5_issuer.current_kid,
          ),
          true,
          algorithms: ["ES384"],
          verify_iss: true,
          iss: "https://#{flow5_base_host}",
          verify_aud: true,
          aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow5_callback_uri = URI.parse(flow5_payload.fetch("url"))
      end
      flow5_protocol_browser = open_session
      flow5_protocol_browser.host!(flow5_base_host)
      flow5_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow5_transport =
        Faraday::Adapter::Test::Stubs.new do |flow5_stub|
          flow5_stub.post(/.*/) do |flow5_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow5_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow5_outer_actor = Actor.context
            flow5_executor_key = Rails.application.executor.active_key
            flow5_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow5_executor_key)
            begin
              flow5_protocol_browser.host!(flow5_env.url.authority)
              flow5_protocol_browser.https!(flow5_env.url.scheme == "https")
              flow5_protocol_browser.post(
                flow5_env.url.request_uri,
                params: Rack::Utils.parse_query(flow5_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow5_executor_key] =
                flow5_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow5_outer_controller),
                          Actor.context.equal?(flow5_outer_actor), flow5_protocol_browser.response.status,]
            [flow5_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow5_protocol_browser.response.body,]
          end
          flow5_stub.get(/.*/) do |flow5_env|
            flow5_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow5_outer_actor = Actor.context
            flow5_executor_key = Rails.application.executor.active_key
            flow5_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow5_executor_key)
            begin
              flow5_protocol_browser.host!(flow5_env.url.authority)
              flow5_protocol_browser.https!(flow5_env.url.scheme == "https")
              flow5_protocol_browser.get(
                flow5_env.url.request_uri, headers: {
                  "Authorization" => flow5_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow5_executor_key] =
                flow5_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow5_outer_controller),
                          Actor.context.equal?(flow5_outer_actor), flow5_protocol_browser.response.status,]
            [flow5_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow5_protocol_browser.response.body,]
          end
        end
      flow5_connection =
        Faraday.new do |flow5_builder|
          flow5_builder.request(:url_encoded)
          flow5_builder.adapter(
            :test,
            flow5_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow5_args) {
          assert_equal flow5_base_host,
                       flow5_args.fetch(:url).host
          flow5_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow5_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow5_transport.verify_stubbed_calls
    end

    assert_equal user_count_before + 1, Client.count
    identity = ClientGoogleIdentity.find_by!(uid: new_uid)
    cycle = ClientSignUpFlow.order(:id).last

    assert_equal "google", cycle.entry_method
    assert_equal identity.user_id, cycle.principal_id
  end

  test "Google sign up refuses a birthdate submitted against a stale or malformed checkpoint version" do
    new_uid = "stale_checkpoint_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    user_count_before = Client.count

    state =
      begin
        fv5040 = "google"
        fv5039 = "login"
        fv5038 = "sign_up"
        begin
          lf7_provider = fv5040
          lf7_intent = fv5039
          lf7_user = nil
          lf7_entry = fv5038
          lf7_ri = "jp"
          lf7_rt = nil
          lf7_referer = nil
          lf7_host = @host.presence || configured_host(:sign_service)
          host!(lf7_host) if respond_to?(:host!)
          lf7_normalized_provider = SocialIdentifiable.normalize_provider(lf7_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf7_continue_path =
            if lf7_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf7_normalized_provider}_path",
                ri: lf7_ri,
              )
            elsif lf7_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf7_normalized_provider}_registration_path",
                ri: lf7_ri,
                rt: lf7_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf7_normalized_provider}_session_path",
                ri: lf7_ri,
                rt: lf7_rt,
              )
            end
          lf7_headers = social_callback_headers(lf7_host)
          lf7_headers["Referer"] = lf7_referer if lf7_referer.present?
          if lf7_user
            lf7_user_headers =
              begin
                rr7_headers =
                  begin
                    rp_headers = as_user_headers(lf7_user, host: lf7_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr7_host = rr7_headers["Host"]
                rr7_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr7_host}/") if rr7_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr7_family, rr7_surface = rr7_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr7_family) && rr7_surface == "app"
                  rr7_client_id =
                    case rr7_family
                    when "base" then "base-#{rr7_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr7_family}-#{rr7_surface}"
                    end
                  rr7_token = ClientToken.find_by!(public_id: rr7_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr7_client = OidcClientRegistry.find!(rr7_client_id)
                  rr7_key = [rr7_client.client_id, rr7_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr7_key] && rr7_token.currently_usable? &&
                      !(rr7_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr7_token.device_session_id,
                        oidc_client_id: rr7_client.client_id,
                        revoked_at: nil,
                      ))
                    rr7_token.rotate_refresh_token! unless rr7_token.device_session_record.current_refresh_token_id
                    rr7_now = Time.current
                    rr7_session = ClientRpSession.create!(
                      client_token: rr7_token,
                      oidc_client_id: rr7_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr7_now,
                      refresh_token_expires_at: rr7_now + 10.minutes,
                    )
                    rr7_access = AuthenticationTokenService.encode(
                      rr7_token.actor_record,
                      host: rr7_host,
                      resource_type: "client",
                      session_public_id: rr7_token.public_id,
                      base_session_public_id: rr7_token.public_id,
                      oidc_sid: rr7_session.public_id,
                      oidc_jti: rr7_session.oidc_jti,
                      expires_at: rr7_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr7_client),
                      audiences: [rr7_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr7_client),
                      subject: OidcSubject.for(
                        rr7_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr7_client.client_id,
                    )
                    @base_browser_rp_credentials[rr7_key] =
                      [rr7_access, rr7_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr7_key]
                    rr7_access, rr7_refresh = @base_browser_rp_credentials.fetch(rr7_key)
                    rr7_cookie = [
                      rr7_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr7_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr7_refresh)}",
                    ].join("; ")
                    rr7_headers = rr7_headers.merge(
                      "Cookie" => rr7_cookie,
                      "HTTP_COOKIE" => rr7_cookie,
                    )
                  end
                end
                rr7_headers
              end
            lf7_token = ClientToken.find_by(public_id: lf7_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf7_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf7_intent.to_s == "link" && lf7_token
            lf7_headers = lf7_headers.merge(lf7_user_headers)
          end
          post(lf7_continue_path, headers: lf7_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow6_form = response.parsed_body.at_css("form#social-completion-form")
        flow6_fields =
          flow6_form.css("input[name]").to_h { |flow6_input|
            [
              flow6_input["name"],
              flow6_input["value"],
            ]
          }
        flow6_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow6_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow6_pair| flow6_pair.start_with?("#{flow6_rails_cookie}=") }
        flow6_owner_cookie << "#{flow6_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow6_rails_cookie))}"
        post(
          flow6_form["action"],
          params: flow6_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow6_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow6_target = URI.parse(response.location)
      if flow6_target.path == "/sign/in/check"
        flow6_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow6_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow6_sid_cookie])
        flow6_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow6_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow6_form = response.parsed_body.at_css("form")
        flow6_fields =
          flow6_form.css("input[name]").to_h { |flow6_input|
            [
              flow6_input["name"],
              flow6_input["value"],
            ]
          }
        post(
          flow6_form["action"], params: flow6_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow6_target = URI.parse(response.location)
        flow6_principal = Client.find_by!(public_id: flow6_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow6_principal,
        )
      end
      break unless flow6_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow6_target.path)

      flow6_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow6_base_cookie = @base_browser.cookies.to_hash.map { |flow6_name, flow6_value|
        "#{flow6_name}=#{Rack::Utils.escape(flow6_value)}"
      }.join("; ")
      flow6_base_headers = {
        "Origin" => "https://#{flow6_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow6_base_cookie,
        "HTTP_COOKIE" => flow6_base_cookie,
      }
      host!(flow6_base_host)
      https!
      get(
        flow6_target.request_uri,
        headers: flow6_base_headers,
      )
      flow6_form = response.parsed_body.at_css("form")
      flow6_fields =
        flow6_form.css("input[name]").to_h { |flow6_input|
          [
            flow6_input["name"],
            flow6_input["value"],
          ]
        }
      post(
        flow6_form["action"],
        params: flow6_fields,
        headers: flow6_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow6_base_headers,
        )
        flow6_form = response.parsed_body.at_css("form")
        flow6_fields =
          flow6_form.css("input[name]").to_h { |flow6_input|
            [
              flow6_input["name"],
              flow6_input["value"],
            ]
          }
        post(
          flow6_form["action"],
          params: flow6_fields,
          headers: flow6_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow6_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow6_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow6_callback_uri.host == flow6_base_host
        flow6_rt = Rack::Utils.parse_query(flow6_callback_uri.query).fetch("rt")
        flow6_payload, = JWT.decode(
          flow6_rt,
          JitSecurityJwtRegistry.public_key_for(
            flow6_issuer.id,
            flow6_issuer.current_kid,
          ),
          true,
          algorithms: ["ES384"],
          verify_iss: true,
          iss: "https://#{flow6_base_host}",
          verify_aud: true,
          aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow6_callback_uri = URI.parse(flow6_payload.fetch("url"))
      end
      flow6_protocol_browser = open_session
      flow6_protocol_browser.host!(flow6_base_host)
      flow6_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow6_transport =
        Faraday::Adapter::Test::Stubs.new do |flow6_stub|
          flow6_stub.post(/.*/) do |flow6_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow6_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow6_outer_actor = Actor.context
            flow6_executor_key = Rails.application.executor.active_key
            flow6_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow6_executor_key)
            begin
              flow6_protocol_browser.host!(flow6_env.url.authority)
              flow6_protocol_browser.https!(flow6_env.url.scheme == "https")
              flow6_protocol_browser.post(
                flow6_env.url.request_uri,
                params: Rack::Utils.parse_query(flow6_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow6_executor_key] =
                flow6_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow6_outer_controller),
                          Actor.context.equal?(flow6_outer_actor), flow6_protocol_browser.response.status,]
            [flow6_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow6_protocol_browser.response.body,]
          end
          flow6_stub.get(/.*/) do |flow6_env|
            flow6_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow6_outer_actor = Actor.context
            flow6_executor_key = Rails.application.executor.active_key
            flow6_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow6_executor_key)
            begin
              flow6_protocol_browser.host!(flow6_env.url.authority)
              flow6_protocol_browser.https!(flow6_env.url.scheme == "https")
              flow6_protocol_browser.get(
                flow6_env.url.request_uri, headers: {
                  "Authorization" => flow6_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow6_executor_key] =
                flow6_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow6_outer_controller),
                          Actor.context.equal?(flow6_outer_actor), flow6_protocol_browser.response.status,]
            [flow6_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow6_protocol_browser.response.body,]
          end
        end
      flow6_connection =
        Faraday.new do |flow6_builder|
          flow6_builder.request(:url_encoded)
          flow6_builder.adapter(
            :test,
            flow6_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow6_args) {
          assert_equal flow6_base_host,
                       flow6_args.fetch(:url).host
          flow6_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow6_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow6_transport.verify_stubbed_calls
    end

    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last
    patch auth_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    current_version = cycle.reload.checkpoint_version

    [current_version - 1, "not-a-number"].each do |submitted|
      patch auth_app_sign_up_check_google_birthdate_url(
        ri: "jp", fb: SignFlowBindingCodec.encode(
          flow: SignUpCycleLocator.new(
            session,
            surface: :app,
          ).current,
          surface: :app,
        ),
      ),
            params: { requirement: "birthdate", birthdate: "2000-01-01", checkpoint_version: submitted },
            headers: browser_headers.merge(@callback_headers)

      assert_response :conflict, submitted.inspect
      assert_equal "stale_checkpoint", response.body
    end

    assert_equal user_count_before, Client.count
    assert_nil ClientGoogleIdentity.find_by(uid: new_uid)
    assert_equal current_version, cycle.reload.checkpoint_version
  end

  test "Google sign up of an applicant below the minimum age creates no account and shows the age restriction" do
    new_uid = "underage_signup_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)
    user_count_before = Client.count

    state =
      begin
        fv5037 = "google"
        fv5036 = "login"
        fv5035 = "sign_up"
        begin
          lf8_provider = fv5037
          lf8_intent = fv5036
          lf8_user = nil
          lf8_entry = fv5035
          lf8_ri = "jp"
          lf8_rt = nil
          lf8_referer = nil
          lf8_host = @host.presence || configured_host(:sign_service)
          host!(lf8_host) if respond_to?(:host!)
          lf8_normalized_provider = SocialIdentifiable.normalize_provider(lf8_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf8_continue_path =
            if lf8_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf8_normalized_provider}_path",
                ri: lf8_ri,
              )
            elsif lf8_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf8_normalized_provider}_registration_path",
                ri: lf8_ri,
                rt: lf8_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf8_normalized_provider}_session_path",
                ri: lf8_ri,
                rt: lf8_rt,
              )
            end
          lf8_headers = social_callback_headers(lf8_host)
          lf8_headers["Referer"] = lf8_referer if lf8_referer.present?
          if lf8_user
            lf8_user_headers =
              begin
                rr8_headers =
                  begin
                    rp_headers = as_user_headers(lf8_user, host: lf8_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr8_host = rr8_headers["Host"]
                rr8_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr8_host}/") if rr8_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr8_family, rr8_surface = rr8_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr8_family) && rr8_surface == "app"
                  rr8_client_id =
                    case rr8_family
                    when "base" then "base-#{rr8_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr8_family}-#{rr8_surface}"
                    end
                  rr8_token = ClientToken.find_by!(public_id: rr8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr8_client = OidcClientRegistry.find!(rr8_client_id)
                  rr8_key = [rr8_client.client_id, rr8_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr8_key] && rr8_token.currently_usable? &&
                      !(rr8_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr8_token.device_session_id,
                        oidc_client_id: rr8_client.client_id,
                        revoked_at: nil,
                      ))
                    rr8_token.rotate_refresh_token! unless rr8_token.device_session_record.current_refresh_token_id
                    rr8_now = Time.current
                    rr8_session = ClientRpSession.create!(
                      client_token: rr8_token,
                      oidc_client_id: rr8_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr8_now,
                      refresh_token_expires_at: rr8_now + 10.minutes,
                    )
                    rr8_access = AuthenticationTokenService.encode(
                      rr8_token.actor_record,
                      host: rr8_host,
                      resource_type: "client",
                      session_public_id: rr8_token.public_id,
                      base_session_public_id: rr8_token.public_id,
                      oidc_sid: rr8_session.public_id,
                      oidc_jti: rr8_session.oidc_jti,
                      expires_at: rr8_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr8_client),
                      audiences: [rr8_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr8_client),
                      subject: OidcSubject.for(
                        rr8_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr8_client.client_id,
                    )
                    @base_browser_rp_credentials[rr8_key] =
                      [rr8_access, rr8_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr8_key]
                    rr8_access, rr8_refresh = @base_browser_rp_credentials.fetch(rr8_key)
                    rr8_cookie = [
                      rr8_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr8_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr8_refresh)}",
                    ].join("; ")
                    rr8_headers = rr8_headers.merge(
                      "Cookie" => rr8_cookie,
                      "HTTP_COOKIE" => rr8_cookie,
                    )
                  end
                end
                rr8_headers
              end
            lf8_token = ClientToken.find_by(public_id: lf8_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf8_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf8_intent.to_s == "link" && lf8_token
            lf8_headers = lf8_headers.merge(lf8_user_headers)
          end
          post(lf8_continue_path, headers: lf8_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow7_form = response.parsed_body.at_css("form#social-completion-form")
        flow7_fields =
          flow7_form.css("input[name]").to_h { |flow7_input|
            [
              flow7_input["name"],
              flow7_input["value"],
            ]
          }
        flow7_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow7_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow7_pair| flow7_pair.start_with?("#{flow7_rails_cookie}=") }
        flow7_owner_cookie << "#{flow7_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow7_rails_cookie))}"
        post(
          flow7_form["action"],
          params: flow7_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow7_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow7_target = URI.parse(response.location)
      if flow7_target.path == "/sign/in/check"
        flow7_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow7_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow7_sid_cookie])
        flow7_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow7_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow7_form = response.parsed_body.at_css("form")
        flow7_fields =
          flow7_form.css("input[name]").to_h { |flow7_input|
            [
              flow7_input["name"],
              flow7_input["value"],
            ]
          }
        post(
          flow7_form["action"], params: flow7_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow7_target = URI.parse(response.location)
        flow7_principal = Client.find_by!(public_id: flow7_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow7_principal,
        )
      end
      break unless flow7_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow7_target.path)

      flow7_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow7_base_cookie = @base_browser.cookies.to_hash.map { |flow7_name, flow7_value|
        "#{flow7_name}=#{Rack::Utils.escape(flow7_value)}"
      }.join("; ")
      flow7_base_headers = {
        "Origin" => "https://#{flow7_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow7_base_cookie,
        "HTTP_COOKIE" => flow7_base_cookie,
      }
      host!(flow7_base_host)
      https!
      get(
        flow7_target.request_uri,
        headers: flow7_base_headers,
      )
      flow7_form = response.parsed_body.at_css("form")
      flow7_fields =
        flow7_form.css("input[name]").to_h { |flow7_input|
          [
            flow7_input["name"],
            flow7_input["value"],
          ]
        }
      post(
        flow7_form["action"],
        params: flow7_fields,
        headers: flow7_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow7_base_headers,
        )
        flow7_form = response.parsed_body.at_css("form")
        flow7_fields =
          flow7_form.css("input[name]").to_h { |flow7_input|
            [
              flow7_input["name"],
              flow7_input["value"],
            ]
          }
        post(
          flow7_form["action"],
          params: flow7_fields,
          headers: flow7_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow7_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow7_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow7_callback_uri.host == flow7_base_host
        flow7_rt = Rack::Utils.parse_query(flow7_callback_uri.query).fetch("rt")
        flow7_payload, = JWT.decode(
          flow7_rt,
          JitSecurityJwtRegistry.public_key_for(
            flow7_issuer.id,
            flow7_issuer.current_kid,
          ),
          true,
          algorithms: ["ES384"],
          verify_iss: true,
          iss: "https://#{flow7_base_host}",
          verify_aud: true,
          aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow7_callback_uri = URI.parse(flow7_payload.fetch("url"))
      end
      flow7_protocol_browser = open_session
      flow7_protocol_browser.host!(flow7_base_host)
      flow7_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow7_transport =
        Faraday::Adapter::Test::Stubs.new do |flow7_stub|
          flow7_stub.post(/.*/) do |flow7_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow7_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow7_outer_actor = Actor.context
            flow7_executor_key = Rails.application.executor.active_key
            flow7_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow7_executor_key)
            begin
              flow7_protocol_browser.host!(flow7_env.url.authority)
              flow7_protocol_browser.https!(flow7_env.url.scheme == "https")
              flow7_protocol_browser.post(
                flow7_env.url.request_uri,
                params: Rack::Utils.parse_query(flow7_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow7_executor_key] =
                flow7_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow7_outer_controller) }
            assert_withheld { Actor.context.equal?(flow7_outer_actor) }
            assert_equal 200,
                         flow7_protocol_browser.response.status
            [flow7_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow7_protocol_browser.response.body,]
          end
          flow7_stub.get(/.*/) do |flow7_env|
            flow7_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow7_outer_actor = Actor.context
            flow7_executor_key = Rails.application.executor.active_key
            flow7_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow7_executor_key)
            begin
              flow7_protocol_browser.host!(flow7_env.url.authority)
              flow7_protocol_browser.https!(flow7_env.url.scheme == "https")
              flow7_protocol_browser.get(
                flow7_env.url.request_uri, headers: {
                  "Authorization" => flow7_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow7_executor_key] =
                flow7_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow7_outer_controller) }
            assert_withheld { Actor.context.equal?(flow7_outer_actor) }
            assert_equal 200,
                         flow7_protocol_browser.response.status
            [flow7_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow7_protocol_browser.response.body,]
          end
        end
      flow7_connection =
        Faraday.new do |flow7_builder|
          flow7_builder.request(:url_encoded)
          flow7_builder.adapter(
            :test,
            flow7_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow7_args) {
          assert_equal flow7_base_host,
                       flow7_args.fetch(:url).host
          flow7_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow7_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow7_transport.verify_stubbed_calls
    end

    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last
    patch auth_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    patch auth_app_sign_up_check_google_birthdate_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: {
            requirement: "birthdate",
            birthdate: (Time.zone.today - 10.years).iso8601,
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host

    assert_includes CGI.unescapeHTML(response.body), I18n.t("sign.app.registration.checkpoint.age_restricted")
    assert_includes response.headers["Cache-Control"].to_s.split(", "), "no-store"
    assert_equal user_count_before, Client.count
    assert_nil ClientGoogleIdentity.find_by(uid: new_uid)

    get auth_app_sign_up_check_google_birthdate_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: cycle,
        surface: :app,
      ),
    ), headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host

    assert_includes CGI.unescapeHTML(response.body), I18n.t("sign.app.registration.checkpoint.age_restricted")
    assert_equal user_count_before, Client.count, "revisiting the step must not reopen the sign-up"
  end

  test "Apple sign up entry without an existing identity creates the client, identity and ceremony" do
    new_uid = "new_apple_signup_#{SecureRandom.hex(4)}"
    user_count_before = Client.count

    state =
      begin
        fv5034 = "apple"
        fv5033 = "login"
        fv5032 = "sign_up"
        begin
          lf9_provider = fv5034
          lf9_intent = fv5033
          lf9_user = nil
          lf9_entry = fv5032
          lf9_ri = "jp"
          lf9_rt = nil
          lf9_referer = nil
          lf9_host = @host.presence || configured_host(:sign_service)
          host!(lf9_host) if respond_to?(:host!)
          lf9_normalized_provider = SocialIdentifiable.normalize_provider(lf9_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf9_continue_path =
            if lf9_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf9_normalized_provider}_path",
                ri: lf9_ri,
              )
            elsif lf9_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf9_normalized_provider}_registration_path",
                ri: lf9_ri,
                rt: lf9_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf9_normalized_provider}_session_path",
                ri: lf9_ri,
                rt: lf9_rt,
              )
            end
          lf9_headers = social_callback_headers(lf9_host)
          lf9_headers["Referer"] = lf9_referer if lf9_referer.present?
          if lf9_user
            lf9_user_headers =
              begin
                rr9_headers =
                  begin
                    rp_headers = as_user_headers(lf9_user, host: lf9_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr9_host = rr9_headers["Host"]
                rr9_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr9_host}/") if rr9_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr9_family, rr9_surface = rr9_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr9_family) && rr9_surface == "app"
                  rr9_client_id =
                    case rr9_family
                    when "base" then "base-#{rr9_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr9_family}-#{rr9_surface}"
                    end
                  rr9_token = ClientToken.find_by!(public_id: rr9_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr9_client = OidcClientRegistry.find!(rr9_client_id)
                  rr9_key = [rr9_client.client_id, rr9_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr9_key] && rr9_token.currently_usable? &&
                      !(rr9_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr9_token.device_session_id,
                        oidc_client_id: rr9_client.client_id,
                        revoked_at: nil,
                      ))
                    rr9_token.rotate_refresh_token! unless rr9_token.device_session_record.current_refresh_token_id
                    rr9_now = Time.current
                    rr9_session = ClientRpSession.create!(
                      client_token: rr9_token,
                      oidc_client_id: rr9_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr9_now,
                      refresh_token_expires_at: rr9_now + 10.minutes,
                    )
                    rr9_access = AuthenticationTokenService.encode(
                      rr9_token.actor_record,
                      host: rr9_host,
                      resource_type: "client",
                      session_public_id: rr9_token.public_id,
                      base_session_public_id: rr9_token.public_id,
                      oidc_sid: rr9_session.public_id,
                      oidc_jti: rr9_session.oidc_jti,
                      expires_at: rr9_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr9_client),
                      audiences: [rr9_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr9_client),
                      subject: OidcSubject.for(
                        rr9_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr9_client.client_id,
                    )
                    @base_browser_rp_credentials[rr9_key] =
                      [rr9_access, rr9_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr9_key]
                    rr9_access, rr9_refresh = @base_browser_rp_credentials.fetch(rr9_key)
                    rr9_cookie = [
                      rr9_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr9_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr9_refresh)}",
                    ].join("; ")
                    rr9_headers = rr9_headers.merge(
                      "Cookie" => rr9_cookie,
                      "HTTP_COOKIE" => rr9_cookie,
                    )
                  end
                end
                rr9_headers
              end
            lf9_token = ClientToken.find_by(public_id: lf9_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf9_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf9_intent.to_s == "link" && lf9_token
            lf9_headers = lf9_headers.merge(lf9_user_headers)
          end
          post(lf9_continue_path, headers: lf9_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: new_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    cycle = ClientSignUpFlow.order(:id).last

    assert_equal "apple", cycle.entry_method

    patch auth_app_sign_up_check_apple_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: {
            confirm_new_social_identity: "1",
            checkpoint_version: cycle.checkpoint_version,
            "cf-turnstile-response": "test_token",
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect?
    patch auth_app_sign_up_check_apple_birthdate_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: {
            requirement: "birthdate",
            birthdate: "2000-01-01",
            checkpoint_version: cycle.reload.checkpoint_version,
          }, headers: browser_headers.merge(@callback_headers)
    follow_redirect! while response.redirect? && URI.parse(response.location).host == @host
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow8_form = response.parsed_body.at_css("form#social-completion-form")
        flow8_fields =
          flow8_form.css("input[name]").to_h { |flow8_input|
            [
              flow8_input["name"],
              flow8_input["value"],
            ]
          }
        flow8_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow8_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow8_pair| flow8_pair.start_with?("#{flow8_rails_cookie}=") }
        flow8_owner_cookie << "#{flow8_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow8_rails_cookie))}"
        post(
          flow8_form["action"],
          params: flow8_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow8_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow8_target = URI.parse(response.location)
      if flow8_target.path == "/sign/in/check"
        flow8_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow8_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow8_sid_cookie])
        flow8_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow8_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow8_form = response.parsed_body.at_css("form")
        flow8_fields =
          flow8_form.css("input[name]").to_h { |flow8_input|
            [
              flow8_input["name"],
              flow8_input["value"],
            ]
          }
        post(
          flow8_form["action"], params: flow8_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow8_target = URI.parse(response.location)
        flow8_principal = Client.find_by!(public_id: flow8_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow8_principal,
        )
      end
      break unless flow8_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow8_target.path)

      flow8_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow8_base_cookie = @base_browser.cookies.to_hash.map { |flow8_name, flow8_value|
        "#{flow8_name}=#{Rack::Utils.escape(flow8_value)}"
      }.join("; ")
      flow8_base_headers = {
        "Origin" => "https://#{flow8_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow8_base_cookie,
        "HTTP_COOKIE" => flow8_base_cookie,
      }
      host!(flow8_base_host)
      https!
      get(
        flow8_target.request_uri,
        headers: flow8_base_headers,
      )
      flow8_form = response.parsed_body.at_css("form")
      flow8_fields =
        flow8_form.css("input[name]").to_h { |flow8_input|
          [
            flow8_input["name"],
            flow8_input["value"],
          ]
        }
      post(
        flow8_form["action"],
        params: flow8_fields,
        headers: flow8_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow8_base_headers,
        )
        flow8_form = response.parsed_body.at_css("form")
        flow8_fields =
          flow8_form.css("input[name]").to_h { |flow8_input|
            [
              flow8_input["name"],
              flow8_input["value"],
            ]
          }
        post(
          flow8_form["action"],
          params: flow8_fields,
          headers: flow8_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow8_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow8_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow8_callback_uri.host == flow8_base_host
        flow8_rt = Rack::Utils.parse_query(flow8_callback_uri.query).fetch("rt")
        flow8_payload, = JWT.decode(
          flow8_rt,
          JitSecurityJwtRegistry.public_key_for(
            flow8_issuer.id,
            flow8_issuer.current_kid,
          ),
          true,
          algorithms: ["ES384"],
          verify_iss: true,
          iss: "https://#{flow8_base_host}",
          verify_aud: true,
          aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow8_callback_uri = URI.parse(flow8_payload.fetch("url"))
      end
      flow8_protocol_browser = open_session
      flow8_protocol_browser.host!(flow8_base_host)
      flow8_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow8_transport =
        Faraday::Adapter::Test::Stubs.new do |flow8_stub|
          flow8_stub.post(/.*/) do |flow8_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow8_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow8_outer_actor = Actor.context
            flow8_executor_key = Rails.application.executor.active_key
            flow8_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow8_executor_key)
            begin
              flow8_protocol_browser.host!(flow8_env.url.authority)
              flow8_protocol_browser.https!(flow8_env.url.scheme == "https")
              flow8_protocol_browser.post(
                flow8_env.url.request_uri,
                params: Rack::Utils.parse_query(flow8_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow8_executor_key] =
                flow8_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow8_outer_controller) }
            assert_withheld { Actor.context.equal?(flow8_outer_actor) }
            assert_equal 200,
                         flow8_protocol_browser.response.status
            [flow8_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow8_protocol_browser.response.body,]
          end
          flow8_stub.get(/.*/) do |flow8_env|
            flow8_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow8_outer_actor = Actor.context
            flow8_executor_key = Rails.application.executor.active_key
            flow8_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow8_executor_key)
            begin
              flow8_protocol_browser.host!(flow8_env.url.authority)
              flow8_protocol_browser.https!(flow8_env.url.scheme == "https")
              flow8_protocol_browser.get(
                flow8_env.url.request_uri, headers: {
                  "Authorization" => flow8_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow8_executor_key] =
                flow8_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow8_outer_controller) }
            assert_withheld { Actor.context.equal?(flow8_outer_actor) }
            assert_equal 200,
                         flow8_protocol_browser.response.status
            [flow8_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow8_protocol_browser.response.body,]
          end
        end
      flow8_connection =
        Faraday.new do |flow8_builder|
          flow8_builder.request(:url_encoded)
          flow8_builder.adapter(
            :test,
            flow8_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow8_args) {
          assert_equal flow8_base_host,
                       flow8_args.fetch(:url).host
          flow8_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow8_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow8_transport.verify_stubbed_calls
    end

    assert_equal user_count_before + 1, Client.count
    identity = ClientAppleIdentity.find_by!(uid: new_uid)

    assert_equal identity.user_id, cycle.reload.principal_id
  end

  test "Apple login with existing identity does not create new user" do
    existing_uid = "existing_apple_user_#{SecureRandom.hex(4)}"

    existing_user = Client.create!(status_id: ClientStatus::NOTHING, public_id: "ex_ap_#{SecureRandom.hex(4)}")
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    user_count_before = Client.count

    state =
      begin
        fv5031 = "apple"
        fv5030 = "login"
        fv5029 = nil
        begin
          lf10_provider = fv5031
          lf10_intent = fv5030
          lf10_user = nil
          lf10_entry = fv5029
          lf10_ri = "jp"
          lf10_rt = nil
          lf10_referer = nil
          lf10_host = @host.presence || configured_host(:sign_service)
          host!(lf10_host) if respond_to?(:host!)
          lf10_normalized_provider = SocialIdentifiable.normalize_provider(lf10_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf10_continue_path =
            if lf10_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf10_normalized_provider}_path",
                ri: lf10_ri,
              )
            elsif lf10_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf10_normalized_provider}_registration_path",
                ri: lf10_ri,
                rt: lf10_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf10_normalized_provider}_session_path",
                ri: lf10_ri,
                rt: lf10_rt,
              )
            end
          lf10_headers = social_callback_headers(lf10_host)
          lf10_headers["Referer"] = lf10_referer if lf10_referer.present?
          if lf10_user
            lf10_user_headers =
              begin
                rr10_headers =
                  begin
                    rp_headers = as_user_headers(lf10_user, host: lf10_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr10_host = rr10_headers["Host"]
                rr10_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr10_host}/") if rr10_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr10_family, rr10_surface = rr10_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr10_family) && rr10_surface == "app"
                  rr10_client_id =
                    case rr10_family
                    when "base" then "base-#{rr10_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr10_family}-#{rr10_surface}"
                    end
                  rr10_token = ClientToken.find_by!(public_id: rr10_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr10_client = OidcClientRegistry.find!(rr10_client_id)
                  rr10_key = [rr10_client.client_id, rr10_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr10_key] && rr10_token.currently_usable? &&
                      !(rr10_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr10_token.device_session_id,
                        oidc_client_id: rr10_client.client_id,
                        revoked_at: nil,
                      ))
                    rr10_token.rotate_refresh_token! unless rr10_token.device_session_record.current_refresh_token_id
                    rr10_now = Time.current
                    rr10_session = ClientRpSession.create!(
                      client_token: rr10_token,
                      oidc_client_id: rr10_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr10_now,
                      refresh_token_expires_at: rr10_now + 10.minutes,
                    )
                    rr10_access = AuthenticationTokenService.encode(
                      rr10_token.actor_record,
                      host: rr10_host,
                      resource_type: "client",
                      session_public_id: rr10_token.public_id,
                      base_session_public_id: rr10_token.public_id,
                      oidc_sid: rr10_session.public_id,
                      oidc_jti: rr10_session.oidc_jti,
                      expires_at: rr10_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr10_client),
                      audiences: [rr10_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr10_client),
                      subject: OidcSubject.for(
                        rr10_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr10_client.client_id,
                    )
                    @base_browser_rp_credentials[rr10_key] =
                      [rr10_access, rr10_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr10_key]
                    rr10_access, rr10_refresh = @base_browser_rp_credentials.fetch(rr10_key)
                    rr10_cookie = [
                      rr10_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr10_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr10_refresh)}",
                    ].join("; ")
                    rr10_headers = rr10_headers.merge(
                      "Cookie" => rr10_cookie,
                      "HTTP_COOKIE" => rr10_cookie,
                    )
                  end
                end
                rr10_headers
              end
            lf10_token = ClientToken.find_by(public_id: lf10_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf10_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf10_intent.to_s == "link" && lf10_token
            lf10_headers = lf10_headers.merge(lf10_user_headers)
          end
          post(lf10_continue_path, headers: lf10_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: existing_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow9_form = response.parsed_body.at_css("form#social-completion-form")
        flow9_fields =
          flow9_form.css("input[name]").to_h { |flow9_input|
            [
              flow9_input["name"],
              flow9_input["value"],
            ]
          }
        flow9_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow9_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow9_pair| flow9_pair.start_with?("#{flow9_rails_cookie}=") }
        flow9_owner_cookie << "#{flow9_rails_cookie}=#{Rack::Utils.escape(response.cookies.fetch(flow9_rails_cookie))}"
        post(
          flow9_form["action"],
          params: flow9_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow9_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow9_target = URI.parse(response.location)
      if flow9_target.path == "/sign/in/check"
        flow9_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow9_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow9_sid_cookie])
        flow9_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow9_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow9_form = response.parsed_body.at_css("form")
        flow9_fields =
          flow9_form.css("input[name]").to_h { |flow9_input|
            [
              flow9_input["name"],
              flow9_input["value"],
            ]
          }
        post(
          flow9_form["action"], params: flow9_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow9_target = URI.parse(response.location)
        flow9_principal = Client.find_by!(public_id: flow9_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow9_principal,
        )
      end
      break unless flow9_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow9_target.path)

      flow9_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow9_base_cookie = @base_browser.cookies.to_hash.map { |flow9_name, flow9_value|
        "#{flow9_name}=#{Rack::Utils.escape(flow9_value)}"
      }.join("; ")
      flow9_base_headers = {
        "Origin" => "https://#{flow9_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow9_base_cookie,
        "HTTP_COOKIE" => flow9_base_cookie,
      }
      host!(flow9_base_host)
      https!
      get(
        flow9_target.request_uri,
        headers: flow9_base_headers,
      )
      flow9_form = response.parsed_body.at_css("form")
      flow9_fields =
        flow9_form.css("input[name]").to_h { |flow9_input|
          [
            flow9_input["name"],
            flow9_input["value"],
          ]
        }
      post(
        flow9_form["action"],
        params: flow9_fields,
        headers: flow9_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow9_base_headers,
        )
        flow9_form = response.parsed_body.at_css("form")
        flow9_fields =
          flow9_form.css("input[name]").to_h { |flow9_input|
            [
              flow9_input["name"],
              flow9_input["value"],
            ]
          }
        post(
          flow9_form["action"],
          params: flow9_fields,
          headers: flow9_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow9_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow9_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow9_callback_uri.host == flow9_base_host
        flow9_rt = Rack::Utils.parse_query(flow9_callback_uri.query).fetch("rt")
        flow9_payload, = JWT.decode(
          flow9_rt,
          JitSecurityJwtRegistry.public_key_for(
            flow9_issuer.id,
            flow9_issuer.current_kid,
          ),
          true,
          algorithms: ["ES384"],
          verify_iss: true,
          iss: "https://#{flow9_base_host}",
          verify_aud: true,
          aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow9_callback_uri = URI.parse(flow9_payload.fetch("url"))
      end
      flow9_protocol_browser = open_session
      flow9_protocol_browser.host!(flow9_base_host)
      flow9_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow9_transport =
        Faraday::Adapter::Test::Stubs.new do |flow9_stub|
          flow9_stub.post(/.*/) do |flow9_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow9_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow9_outer_actor = Actor.context
            flow9_executor_key = Rails.application.executor.active_key
            flow9_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow9_executor_key)
            begin
              flow9_protocol_browser.host!(flow9_env.url.authority)
              flow9_protocol_browser.https!(flow9_env.url.scheme == "https")
              flow9_protocol_browser.post(
                flow9_env.url.request_uri,
                params: Rack::Utils.parse_query(flow9_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow9_executor_key] =
                flow9_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow9_outer_controller) }
            assert_withheld { Actor.context.equal?(flow9_outer_actor) }
            assert_equal 200,
                         flow9_protocol_browser.response.status
            [flow9_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow9_protocol_browser.response.body,]
          end
          flow9_stub.get(/.*/) do |flow9_env|
            flow9_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow9_outer_actor = Actor.context
            flow9_executor_key = Rails.application.executor.active_key
            flow9_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow9_executor_key)
            begin
              flow9_protocol_browser.host!(flow9_env.url.authority)
              flow9_protocol_browser.https!(flow9_env.url.scheme == "https")
              flow9_protocol_browser.get(
                flow9_env.url.request_uri, headers: {
                  "Authorization" => flow9_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow9_executor_key] =
                flow9_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow9_outer_controller) }
            assert_withheld { Actor.context.equal?(flow9_outer_actor) }
            assert_equal 200,
                         flow9_protocol_browser.response.status
            [flow9_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow9_protocol_browser.response.body,]
          end
        end
      flow9_connection =
        Faraday.new do |flow9_builder|
          flow9_builder.request(:url_encoded)
          flow9_builder.adapter(
            :test,
            flow9_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow9_args) {
          assert_equal flow9_base_host,
                       flow9_args.fetch(:url).host
          flow9_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow9_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow9_transport.verify_stubbed_calls
    end

    assert_equal user_count_before, Client.count
  end

  test "Apple login with existing identity completes on the app Dashboard, never Home" do
    existing_uid = "existing_apple_dashboard_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "apd_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    state =
      begin
        fv5028 = "apple"
        fv5027 = "login"
        fv5026 = nil
        begin
          lf11_provider = fv5028
          lf11_intent = fv5027
          lf11_user = nil
          lf11_entry = fv5026
          lf11_ri = "jp"
          lf11_rt = nil
          lf11_referer = nil
          lf11_host = @host.presence || configured_host(:sign_service)
          host!(lf11_host) if respond_to?(:host!)
          lf11_normalized_provider = SocialIdentifiable.normalize_provider(lf11_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf11_continue_path =
            if lf11_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf11_normalized_provider}_path",
                ri: lf11_ri,
              )
            elsif lf11_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf11_normalized_provider}_registration_path",
                ri: lf11_ri,
                rt: lf11_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf11_normalized_provider}_session_path",
                ri: lf11_ri,
                rt: lf11_rt,
              )
            end
          lf11_headers = social_callback_headers(lf11_host)
          lf11_headers["Referer"] = lf11_referer if lf11_referer.present?
          if lf11_user
            lf11_user_headers =
              begin
                rr11_headers =
                  begin
                    rp_headers = as_user_headers(lf11_user, host: lf11_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr11_host = rr11_headers["Host"]
                rr11_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr11_host}/") if rr11_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr11_family, rr11_surface = rr11_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr11_family) && rr11_surface == "app"
                  rr11_client_id =
                    case rr11_family
                    when "base" then "base-#{rr11_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr11_family}-#{rr11_surface}"
                    end
                  rr11_token = ClientToken.find_by!(public_id: rr11_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr11_client = OidcClientRegistry.find!(rr11_client_id)
                  rr11_key = [rr11_client.client_id, rr11_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr11_key] && rr11_token.currently_usable? &&
                      !(rr11_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr11_token.device_session_id,
                        oidc_client_id: rr11_client.client_id,
                        revoked_at: nil,
                      ))
                    rr11_token.rotate_refresh_token! unless rr11_token.device_session_record.current_refresh_token_id
                    rr11_now = Time.current
                    rr11_session = ClientRpSession.create!(
                      client_token: rr11_token,
                      oidc_client_id: rr11_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr11_now,
                      refresh_token_expires_at: rr11_now + 10.minutes,
                    )
                    rr11_access = AuthenticationTokenService.encode(
                      rr11_token.actor_record,
                      host: rr11_host,
                      resource_type: "client",
                      session_public_id: rr11_token.public_id,
                      base_session_public_id: rr11_token.public_id,
                      oidc_sid: rr11_session.public_id,
                      oidc_jti: rr11_session.oidc_jti,
                      expires_at: rr11_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr11_client),
                      audiences: [rr11_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr11_client),
                      subject: OidcSubject.for(
                        rr11_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr11_client.client_id,
                    )
                    @base_browser_rp_credentials[rr11_key] =
                      [rr11_access, rr11_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr11_key]
                    rr11_access, rr11_refresh = @base_browser_rp_credentials.fetch(rr11_key)
                    rr11_cookie = [
                      rr11_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr11_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr11_refresh)}",
                    ].join("; ")
                    rr11_headers = rr11_headers.merge(
                      "Cookie" => rr11_cookie,
                      "HTTP_COOKIE" => rr11_cookie,
                    )
                  end
                end
                rr11_headers
              end
            lf11_token = ClientToken.find_by(public_id: lf11_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf11_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf11_intent.to_s == "link" && lf11_token
            lf11_headers = lf11_headers.merge(lf11_user_headers)
          end
          post(lf11_continue_path, headers: lf11_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: existing_uid)

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow10_form = response.parsed_body.at_css("form#social-completion-form")
        flow10_fields =
          flow10_form.css("input[name]").to_h { |flow10_input|
            [
              flow10_input["name"],
              flow10_input["value"],
            ]
          }
        flow10_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow10_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow10_pair| flow10_pair.start_with?("#{flow10_rails_cookie}=") }
        flow10_owner_cookie << "#{flow10_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow10_rails_cookie),
        )}"
        post(
          flow10_form["action"],
          params: flow10_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow10_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow10_target = URI.parse(response.location)
      if flow10_target.path == "/sign/in/check"
        flow10_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow10_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow10_sid_cookie])
        flow10_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow10_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow10_form = response.parsed_body.at_css("form")
        flow10_fields =
          flow10_form.css("input[name]").to_h { |flow10_input|
            [
              flow10_input["name"],
              flow10_input["value"],
            ]
          }
        post(
          flow10_form["action"], params: flow10_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow10_target = URI.parse(response.location)
        flow10_principal = Client.find_by!(public_id: flow10_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow10_principal,
        )
      end
      break unless flow10_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow10_target.path)

      flow10_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow10_base_cookie = @base_browser.cookies.to_hash.map { |flow10_name, flow10_value|
        "#{flow10_name}=#{Rack::Utils.escape(flow10_value)}"
      }.join("; ")
      flow10_base_headers = {
        "Origin" => "https://#{flow10_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow10_base_cookie,
        "HTTP_COOKIE" => flow10_base_cookie,
      }
      host!(flow10_base_host)
      https!
      get(
        flow10_target.request_uri,
        headers: flow10_base_headers,
      )
      flow10_form = response.parsed_body.at_css("form")
      flow10_fields =
        flow10_form.css("input[name]").to_h { |flow10_input|
          [
            flow10_input["name"],
            flow10_input["value"],
          ]
        }
      post(
        flow10_form["action"],
        params: flow10_fields,
        headers: flow10_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow10_base_headers,
        )
        flow10_form = response.parsed_body.at_css("form")
        flow10_fields =
          flow10_form.css("input[name]").to_h { |flow10_input|
            [
              flow10_input["name"],
              flow10_input["value"],
            ]
          }
        post(
          flow10_form["action"],
          params: flow10_fields,
          headers: flow10_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow10_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow10_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow10_callback_uri.host == flow10_base_host
        flow10_rt = Rack::Utils.parse_query(flow10_callback_uri.query).fetch("rt")
        flow10_payload, = JWT.decode(
          flow10_rt,
          JitSecurityJwtRegistry.public_key_for(
            flow10_issuer.id,
            flow10_issuer.current_kid,
          ),
          true,
          algorithms: ["ES384"],
          verify_iss: true,
          iss: "https://#{flow10_base_host}",
          verify_aud: true,
          aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow10_callback_uri = URI.parse(flow10_payload.fetch("url"))
      end
      flow10_protocol_browser = open_session
      flow10_protocol_browser.host!(flow10_base_host)
      flow10_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow10_transport =
        Faraday::Adapter::Test::Stubs.new do |flow10_stub|
          flow10_stub.post(/.*/) do |flow10_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow10_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow10_outer_actor = Actor.context
            flow10_executor_key = Rails.application.executor.active_key
            flow10_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow10_executor_key)
            begin
              flow10_protocol_browser.host!(flow10_env.url.authority)
              flow10_protocol_browser.https!(flow10_env.url.scheme == "https")
              flow10_protocol_browser.post(
                flow10_env.url.request_uri,
                params: Rack::Utils.parse_query(flow10_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow10_executor_key] =
                flow10_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow10_outer_controller) }
            assert_withheld { Actor.context.equal?(flow10_outer_actor) }
            assert_equal 200,
                         flow10_protocol_browser.response.status
            [flow10_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow10_protocol_browser.response.body,]
          end
          flow10_stub.get(/.*/) do |flow10_env|
            flow10_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow10_outer_actor = Actor.context
            flow10_executor_key = Rails.application.executor.active_key
            flow10_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow10_executor_key)
            begin
              flow10_protocol_browser.host!(flow10_env.url.authority)
              flow10_protocol_browser.https!(flow10_env.url.scheme == "https")
              flow10_protocol_browser.get(
                flow10_env.url.request_uri, headers: {
                  "Authorization" => flow10_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow10_executor_key] =
                flow10_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow10_outer_controller) }
            assert_withheld { Actor.context.equal?(flow10_outer_actor) }
            assert_equal 200,
                         flow10_protocol_browser.response.status
            [flow10_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow10_protocol_browser.response.body,]
          end
        end
      flow10_connection =
        Faraday.new do |flow10_builder|
          flow10_builder.request(:url_encoded)
          flow10_builder.adapter(
            :test,
            flow10_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow10_args) {
          assert_equal flow10_base_host,
                       flow10_args.fetch(:url).host
          flow10_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow10_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow10_transport.verify_stubbed_calls
    end

    assert_response :redirect
    assert_social_login_lands_on_app_dashboard(response.location)
  end

  test "Apple sign up entry with existing identity falls through to sign in flow" do
    existing_uid = "existing_apple_signup_entry_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "sua_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    ClientAppleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "apple",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )
    user_count_before = Client.count

    state =
      begin
        fv5025 = "apple"
        fv5024 = "login"
        fv5023 = "sign_up"
        begin
          lf12_provider = fv5025
          lf12_intent = fv5024
          lf12_user = nil
          lf12_entry = fv5023
          lf12_ri = "jp"
          lf12_rt = nil
          lf12_referer = nil
          lf12_host = @host.presence || configured_host(:sign_service)
          host!(lf12_host) if respond_to?(:host!)
          lf12_normalized_provider = SocialIdentifiable.normalize_provider(lf12_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf12_continue_path =
            if lf12_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf12_normalized_provider}_path",
                ri: lf12_ri,
              )
            elsif lf12_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf12_normalized_provider}_registration_path",
                ri: lf12_ri,
                rt: lf12_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf12_normalized_provider}_session_path",
                ri: lf12_ri,
                rt: lf12_rt,
              )
            end
          lf12_headers = social_callback_headers(lf12_host)
          lf12_headers["Referer"] = lf12_referer if lf12_referer.present?
          if lf12_user
            lf12_user_headers =
              begin
                rr12_headers =
                  begin
                    rp_headers = as_user_headers(lf12_user, host: lf12_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr12_host = rr12_headers["Host"]
                rr12_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr12_host}/") if rr12_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr12_family, rr12_surface = rr12_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr12_family) && rr12_surface == "app"
                  rr12_client_id =
                    case rr12_family
                    when "base" then "base-#{rr12_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr12_family}-#{rr12_surface}"
                    end
                  rr12_token = ClientToken.find_by!(public_id: rr12_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr12_client = OidcClientRegistry.find!(rr12_client_id)
                  rr12_key = [rr12_client.client_id, rr12_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr12_key] && rr12_token.currently_usable? &&
                      !(rr12_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr12_token.device_session_id,
                        oidc_client_id: rr12_client.client_id,
                        revoked_at: nil,
                      ))
                    rr12_token.rotate_refresh_token! unless rr12_token.device_session_record.current_refresh_token_id
                    rr12_now = Time.current
                    rr12_session = ClientRpSession.create!(
                      client_token: rr12_token,
                      oidc_client_id: rr12_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr12_now,
                      refresh_token_expires_at: rr12_now + 10.minutes,
                    )
                    rr12_access = AuthenticationTokenService.encode(
                      rr12_token.actor_record,
                      host: rr12_host,
                      resource_type: "client",
                      session_public_id: rr12_token.public_id,
                      base_session_public_id: rr12_token.public_id,
                      oidc_sid: rr12_session.public_id,
                      oidc_jti: rr12_session.oidc_jti,
                      expires_at: rr12_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr12_client),
                      audiences: [rr12_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr12_client),
                      subject: OidcSubject.for(
                        rr12_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr12_client.client_id,
                    )
                    @base_browser_rp_credentials[rr12_key] =
                      [rr12_access, rr12_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr12_key]
                    rr12_access, rr12_refresh = @base_browser_rp_credentials.fetch(rr12_key)
                    rr12_cookie = [
                      rr12_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr12_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr12_refresh)}",
                    ].join("; ")
                    rr12_headers = rr12_headers.merge(
                      "Cookie" => rr12_cookie,
                      "HTTP_COOKIE" => rr12_cookie,
                    )
                  end
                end
                rr12_headers
              end
            lf12_token = ClientToken.find_by(public_id: lf12_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf12_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf12_intent.to_s == "link" && lf12_token
            lf12_headers = lf12_headers.merge(lf12_user_headers)
          end
          post(lf12_continue_path, headers: lf12_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: existing_uid)

    sign_up_cycle = ClientSignUpFlow.order(:id).last

    assert_equal "apple", sign_up_cycle.entry_method
    assert_equal "social_callback", sign_up_cycle.step

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow11_form = response.parsed_body.at_css("form#social-completion-form")
        flow11_fields =
          flow11_form.css("input[name]").to_h { |flow11_input|
            [
              flow11_input["name"],
              flow11_input["value"],
            ]
          }
        flow11_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow11_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow11_pair| flow11_pair.start_with?("#{flow11_rails_cookie}=") }
        flow11_owner_cookie << "#{flow11_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow11_rails_cookie),
        )}"
        post(
          flow11_form["action"],
          params: flow11_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow11_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow11_target = URI.parse(response.location)
      if flow11_target.path == "/sign/in/check"
        flow11_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow11_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow11_sid_cookie])
        flow11_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow11_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow11_form = response.parsed_body.at_css("form")
        flow11_fields =
          flow11_form.css("input[name]").to_h { |flow11_input|
            [
              flow11_input["name"],
              flow11_input["value"],
            ]
          }
        post(
          flow11_form["action"], params: flow11_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow11_target = URI.parse(response.location)
        flow11_principal = Client.find_by!(public_id: flow11_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow11_principal,
        )
      end
      break unless flow11_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow11_target.path)

      flow11_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow11_base_cookie = @base_browser.cookies.to_hash.map { |flow11_name, flow11_value|
        "#{flow11_name}=#{Rack::Utils.escape(flow11_value)}"
      }.join("; ")
      flow11_base_headers = {
        "Origin" => "https://#{flow11_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow11_base_cookie,
        "HTTP_COOKIE" => flow11_base_cookie,
      }
      host!(flow11_base_host)
      https!
      get(
        flow11_target.request_uri,
        headers: flow11_base_headers,
      )
      flow11_form = response.parsed_body.at_css("form")
      flow11_fields =
        flow11_form.css("input[name]").to_h { |flow11_input|
          [
            flow11_input["name"],
            flow11_input["value"],
          ]
        }
      post(
        flow11_form["action"],
        params: flow11_fields,
        headers: flow11_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow11_base_headers,
        )
        flow11_form = response.parsed_body.at_css("form")
        flow11_fields =
          flow11_form.css("input[name]").to_h { |flow11_input|
            [
              flow11_input["name"],
              flow11_input["value"],
            ]
          }
        post(
          flow11_form["action"],
          params: flow11_fields,
          headers: flow11_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow11_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow11_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow11_callback_uri.host == flow11_base_host
        flow11_rt = Rack::Utils.parse_query(flow11_callback_uri.query).fetch("rt")
        flow11_payload, = JWT.decode(
          flow11_rt, JitSecurityJwtRegistry.public_key_for(
            flow11_issuer.id,
            flow11_issuer.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow11_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow11_callback_uri = URI.parse(flow11_payload.fetch("url"))
      end
      flow11_protocol_browser = open_session
      flow11_protocol_browser.host!(flow11_base_host)
      flow11_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow11_transport =
        Faraday::Adapter::Test::Stubs.new do |flow11_stub|
          flow11_stub.post(/.*/) do |flow11_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow11_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow11_outer_actor = Actor.context
            flow11_executor_key = Rails.application.executor.active_key
            flow11_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow11_executor_key)
            begin
              flow11_protocol_browser.host!(flow11_env.url.authority)
              flow11_protocol_browser.https!(flow11_env.url.scheme == "https")
              flow11_protocol_browser.post(
                flow11_env.url.request_uri,
                params: Rack::Utils.parse_query(flow11_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow11_executor_key] =
                flow11_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow11_outer_controller) }
            assert_withheld { Actor.context.equal?(flow11_outer_actor) }
            assert_equal 200,
                         flow11_protocol_browser.response.status
            [flow11_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow11_protocol_browser.response.body,]
          end
          flow11_stub.get(/.*/) do |flow11_env|
            flow11_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow11_outer_actor = Actor.context
            flow11_executor_key = Rails.application.executor.active_key
            flow11_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow11_executor_key)
            begin
              flow11_protocol_browser.host!(flow11_env.url.authority)
              flow11_protocol_browser.https!(flow11_env.url.scheme == "https")
              flow11_protocol_browser.get(
                flow11_env.url.request_uri, headers: {
                  "Authorization" => flow11_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow11_executor_key] =
                flow11_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow11_outer_controller) }
            assert_withheld { Actor.context.equal?(flow11_outer_actor) }
            assert_equal 200,
                         flow11_protocol_browser.response.status
            [flow11_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow11_protocol_browser.response.body,]
          end
        end
      flow11_connection =
        Faraday.new do |flow11_builder|
          flow11_builder.request(:url_encoded)
          flow11_builder.adapter(
            :test,
            flow11_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow11_args) {
          assert_equal flow11_base_host,
                       flow11_args.fetch(:url).host
          flow11_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow11_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow11_transport.verify_stubbed_calls
    end

    assert_response :redirect
    assert_social_login_lands_on_app_dashboard(response.location)
    assert_equal user_count_before, Client.count

    sign_in_cycle = ClientSignInFlow.where(principal_id: existing_user.id).recent_first.first

    assert_equal ClientSignInFlowState::COMPLETED, sign_in_cycle.reload.state_id
    assert_equal "social_callback", sign_up_cycle.reload.step
  end

  # ============================================================================
  # New user creation
  # ============================================================================
  # rubocop:disable Minitest/MultipleAssertions
  test "unknown Google sign-in neither registers an account nor links an identity" do
    setup_google_mock_auth(uid: "unknown-signin-#{SecureRandom.hex(8)}")
    assert_no_difference(
      ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
       "ClientToken.count",],
    ) do
      post auth_app_social_google_session_path(ri: "jp"), headers: @callback_headers
      state = social_auth_state_from_response

      assert_predicate state, :present?
      get auth_app_social_google_callback_path(ri: "jp"), params: { state: state }, headers: @callback_headers
    end
    assert_redirected_to auth_app_sign_in_url(ri: "jp")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flash, :empty?
  end

  test "Google birthdate before confirmation halts the original signup without provisioning" do
    new_uid = "brand_new_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    user_count_before = Client.count
    identity_count_before = ClientGoogleIdentity.count

    state =
      begin
        fv5022 = "google"
        fv5021 = "login"
        fv5020 = "sign_up"
        begin
          lf13_provider = fv5022
          lf13_intent = fv5021
          lf13_user = nil
          lf13_entry = fv5020
          lf13_ri = "jp"
          lf13_rt = nil
          lf13_referer = nil
          lf13_host = @host.presence || configured_host(:sign_service)
          host!(lf13_host) if respond_to?(:host!)
          lf13_normalized_provider = SocialIdentifiable.normalize_provider(lf13_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf13_continue_path =
            if lf13_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf13_normalized_provider}_path",
                ri: lf13_ri,
              )
            elsif lf13_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf13_normalized_provider}_registration_path",
                ri: lf13_ri,
                rt: lf13_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf13_normalized_provider}_session_path",
                ri: lf13_ri,
                rt: lf13_rt,
              )
            end
          lf13_headers = social_callback_headers(lf13_host)
          lf13_headers["Referer"] = lf13_referer if lf13_referer.present?
          if lf13_user
            lf13_user_headers =
              begin
                rr13_headers =
                  begin
                    rp_headers = as_user_headers(lf13_user, host: lf13_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr13_host = rr13_headers["Host"]
                rr13_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr13_host}/") if rr13_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr13_family, rr13_surface = rr13_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr13_family) && rr13_surface == "app"
                  rr13_client_id =
                    case rr13_family
                    when "base" then "base-#{rr13_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr13_family}-#{rr13_surface}"
                    end
                  rr13_token = ClientToken.find_by!(public_id: rr13_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr13_client = OidcClientRegistry.find!(rr13_client_id)
                  rr13_key = [rr13_client.client_id, rr13_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr13_key] && rr13_token.currently_usable? &&
                      !(rr13_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr13_token.device_session_id,
                        oidc_client_id: rr13_client.client_id,
                        revoked_at: nil,
                      ))
                    rr13_token.rotate_refresh_token! unless rr13_token.device_session_record.current_refresh_token_id
                    rr13_now = Time.current
                    rr13_session = ClientRpSession.create!(
                      client_token: rr13_token,
                      oidc_client_id: rr13_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr13_now,
                      refresh_token_expires_at: rr13_now + 10.minutes,
                    )
                    rr13_access = AuthenticationTokenService.encode(
                      rr13_token.actor_record,
                      host: rr13_host,
                      resource_type: "client",
                      session_public_id: rr13_token.public_id,
                      base_session_public_id: rr13_token.public_id,
                      oidc_sid: rr13_session.public_id,
                      oidc_jti: rr13_session.oidc_jti,
                      expires_at: rr13_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr13_client),
                      audiences: [rr13_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr13_client),
                      subject: OidcSubject.for(
                        rr13_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr13_client.client_id,
                    )
                    @base_browser_rp_credentials[rr13_key] =
                      [rr13_access, rr13_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr13_key]
                    rr13_access, rr13_refresh = @base_browser_rp_credentials.fetch(rr13_key)
                    rr13_cookie = [
                      rr13_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr13_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr13_refresh)}",
                    ].join("; ")
                    rr13_headers = rr13_headers.merge(
                      "Cookie" => rr13_cookie,
                      "HTTP_COOKIE" => rr13_cookie,
                    )
                  end
                end
                rr13_headers
              end
            lf13_token = ClientToken.find_by(public_id: lf13_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf13_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf13_intent.to_s == "link" && lf13_token
            lf13_headers = lf13_headers.merge(lf13_user_headers)
          end
          post(lf13_continue_path, headers: lf13_headers)
          social_auth_state_from_response
        end
      end

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                get auth_app_social_google_callback_url(ri: "jp"),
                    params: { state: state },
                    headers: browser_headers.merge(@callback_headers)
                1.times do
                  if response.media_type == "text/html" && response.body.include?("social-completion-form")
                    flow12_form = response.parsed_body.at_css("form#social-completion-form")
                    flow12_fields =
                      flow12_form.css("input[name]").to_h { |flow12_input|
                        [
                          flow12_input["name"],
                          flow12_input["value"],
                        ]
                      }
                    flow12_rails_cookie = Rails.application.config.session_options.fetch(:key)
                    flow12_owner_cookie =
                      request.headers["Cookie"].to_s.split("; ")
                        .reject { |flow12_pair| flow12_pair.start_with?("#{flow12_rails_cookie}=") }
                    flow12_owner_cookie << "#{flow12_rails_cookie}=#{Rack::Utils.escape(
                      response
                                            .cookies.fetch(flow12_rails_cookie),
                    )}"
                    post(
                      flow12_form["action"],
                      params: flow12_fields,
                      headers: {
                        "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                        "Cookie" => flow12_owner_cookie.join("; "),
                        "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                        "Sec-Fetch-Site" => "same-origin",
                      },
                    )
                    break
                  end
                  break unless response.redirect? && @base_browser

                  flow12_target = URI.parse(response.location)
                  if flow12_target.path == "/sign/in/check"
                    flow12_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
                    flow12_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow12_sid_cookie])
                    flow12_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
                      surface: "app",
                      transaction_id: flow12_ceremony.authorization_transaction_ref,
                    )
                    get(auth_app_sign_oidc_handoff_path(ri: "jp"))
                    flow12_form = response.parsed_body.at_css("form")
                    flow12_fields =
                      flow12_form.css("input[name]").to_h { |flow12_input|
                        [
                          flow12_input["name"],
                          flow12_input["value"],
                        ]
                      }
                    post(
                      flow12_form["action"], params: flow12_fields, headers: {
                        "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                        "Sec-Fetch-Site" => "same-origin",
                      },
                    )
                    flow12_target = URI.parse(response.location)
                    flow12_principal = Client.find_by!(public_id: flow12_parent.reload.actor_ref)
                    BaseSelectorBootstrapAuthority.call(
                      surface: :app,
                      principal: flow12_principal,
                    )
                  end
                  break unless flow12_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                    %w(/social/authentication/completion
                       /oauth/authorize).include?(flow12_target.path)

                  flow12_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
                  flow12_base_cookie = @base_browser.cookies.to_hash.map { |flow12_name, flow12_value|
                    "#{flow12_name}=#{Rack::Utils.escape(flow12_value)}"
                  }.join("; ")
                  flow12_base_headers = {
                    "Origin" => "https://#{flow12_base_host}",
                    "Sec-Fetch-Site" => "same-origin",
                    "Cookie" => flow12_base_cookie,
                    "HTTP_COOKIE" => flow12_base_cookie,
                  }
                  host!(flow12_base_host)
                  https!
                  get(
                    flow12_target.request_uri,
                    headers: flow12_base_headers,
                  )
                  flow12_form = response.parsed_body.at_css("form")
                  flow12_fields =
                    flow12_form.css("input[name]").to_h { |flow12_input|
                      [
                        flow12_input["name"],
                        flow12_input["value"],
                      ]
                    }
                  post(
                    flow12_form["action"],
                    params: flow12_fields,
                    headers: flow12_base_headers,
                  )
                  if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
                    get(
                      URI.parse(response.location).request_uri,
                      headers: flow12_base_headers,
                    )
                    flow12_form = response.parsed_body.at_css("form")
                    flow12_fields =
                      flow12_form.css("input[name]").to_h { |flow12_input|
                        [
                          flow12_input["name"],
                          flow12_input["value"],
                        ]
                      }
                    post(
                      flow12_form["action"],
                      params: flow12_fields,
                      headers: flow12_base_headers,
                    )
                  end
                  break unless response.redirect?
                  # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
                  break unless URI.parse(response.location).path == "/oidc/callback" ||
                    URI.parse(response.location).host ==
                      URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

                  flow12_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
                  flow12_callback_uri = URI.parse(response.location)
                  # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
                  unless flow12_callback_uri.host == flow12_base_host
                    flow12_rt = Rack::Utils.parse_query(flow12_callback_uri.query).fetch("rt")
                    flow12_payload, = JWT.decode(
                      flow12_rt, JitSecurityJwtRegistry.public_key_for(
                        flow12_issuer.id,
                        flow12_issuer.current_kid,
                      ), true,
                      algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow12_base_host}",
                      verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                    )
                    flow12_callback_uri = URI.parse(flow12_payload.fetch("url"))
                  end
                  flow12_protocol_browser = open_session
                  flow12_protocol_browser.host!(flow12_base_host)
                  flow12_protocol_browser.https!
                  # Substitute network transport only: the token and UserInfo requests still run
                  # through their real public controllers, including PKCE and client authentication.
                  flow12_transport =
                    Faraday::Adapter::Test::Stubs.new do |flow12_stub|
                      flow12_stub.post(/.*/) do |flow12_env|
                        # The nested Rack executor must not complete the in-flight callback.
                        flow12_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                        flow12_outer_actor = Actor.context
                        flow12_executor_key = Rails.application.executor.active_key
                        flow12_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow12_executor_key)
                        begin
                          flow12_protocol_browser.host!(flow12_env.url.authority)
                          flow12_protocol_browser.https!(flow12_env.url.scheme == "https")
                          flow12_protocol_browser.post(
                            flow12_env.url.request_uri,
                            params: Rack::Utils.parse_query(flow12_env.body),
                            headers: { "Accept" => "application/json" },
                          )
                        ensure
                          ActiveSupport::IsolatedExecutionState[flow12_executor_key] =
                            flow12_outer_execution
                        end

                        assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow12_outer_controller) }
                        assert_withheld { Actor.context.equal?(flow12_outer_actor) }
                        assert_equal 200,
                                     flow12_protocol_browser.response.status
                        [flow12_protocol_browser.response.status, { "Content-Type" => "application/json" },
                         flow12_protocol_browser.response.body,]
                      end
                      flow12_stub.get(/.*/) do |flow12_env|
                        flow12_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                        flow12_outer_actor = Actor.context
                        flow12_executor_key = Rails.application.executor.active_key
                        flow12_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow12_executor_key)
                        begin
                          flow12_protocol_browser.host!(flow12_env.url.authority)
                          flow12_protocol_browser.https!(flow12_env.url.scheme == "https")
                          flow12_protocol_browser.get(
                            flow12_env.url.request_uri, headers: {
                              "Authorization" => flow12_env.request_headers.fetch("Authorization"),
                              "Accept" => "application/json",
                            },
                          )
                        ensure
                          ActiveSupport::IsolatedExecutionState[flow12_executor_key] =
                            flow12_outer_execution
                        end

                        assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow12_outer_controller) }
                        assert_withheld { Actor.context.equal?(flow12_outer_actor) }
                        assert_equal 200,
                                     flow12_protocol_browser.response.status
                        [flow12_protocol_browser.response.status, { "Content-Type" => "application/json" },
                         flow12_protocol_browser.response.body,]
                      end
                    end
                  flow12_connection =
                    Faraday.new do |flow12_builder|
                      flow12_builder.request(:url_encoded)
                      flow12_builder.adapter(
                        :test,
                        flow12_transport,
                      )
                    end
                  OutboundHttp::Connection.stub(
                    :build,
                    ->(**flow12_args) {
                      assert_equal flow12_base_host,
                                   flow12_args.fetch(:url).host
                      flow12_connection
                    },
                  ) do
                    TestSupport::OutboundHttpGuard.allow do
                      get(flow12_callback_uri.request_uri)
                    end
                  end

                  assert_equal [true, true, true],
                               [response.redirect?,
                                cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                                cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
                  flow12_transport.verify_stubbed_calls
                end
              end
            end
          end
        end
      end
    end

    assert_redirected_to sign_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    )
    follow_redirect!

    assert_response :ok
    assert_includes response.body, "このGoogleアカウントは未登録です。"
    assert_includes response.body, "新しいUmaxica Identityを作成します。"
    assert_includes response.body, "既存アカウントとは後から統合できません。"
    assert_includes response.body, "間違いならキャンセルしてください。"
    # The social sign-up checkpoint asks for an explicit confirmation before an identity is
    # created; the page object names that component and carries the label it asks agreement to.
    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
    assert_predicate inertia_props.fetch("confirm_label"), :present?
    assert_select "script:not([nonce])", false

    cycle = SignUpCycleLocator.new(session, surface: :app, cycle_class: ClientSignUpFlow).current

    assert_predicate cycle, :present?

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        assert_no_difference("ClientAccount.count") do
          assert_no_difference("OperatorOrganization.count") do
            assert_no_difference("Avatar.count") do
              assert_no_difference("ClientToken.count") do
                patch auth_app_sign_up_check_google_birthdate_path(
                  ri: "jp", fb: SignFlowBindingCodec.encode(
                    flow: SignUpCycleLocator.new(
                      session,
                      surface: :app,
                    ).current,
                    surface: :app,
                  ),
                ),
                      params: {
                        requirement: "birthdate",
                        birthdate: "2000-02-03",
                        checkpoint_version: cycle.checkpoint_version,
                      },
                      headers: browser_headers.merge(@callback_headers)
              end
            end
          end
        end
      end
    end

    assert_response :conflict

    assert_predicate cycle.reload, :sign_up_halted?
    assert_equal user_count_before, Client.count
    assert_equal identity_count_before, ClientGoogleIdentity.count
  end

  # rubocop:enable Minitest/MultipleAssertions

  test "duplicate Google callback failure after new-account checkpoint returns to sign in" do
    new_uid = "duplicate_callback_google_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state =
      begin
        fv5019 = "google"
        fv5018 = "login"
        fv5017 = "sign_up"
        begin
          lf14_provider = fv5019
          lf14_intent = fv5018
          lf14_user = nil
          lf14_entry = fv5017
          lf14_ri = "jp"
          lf14_rt = nil
          lf14_referer = nil
          lf14_host = @host.presence || configured_host(:sign_service)
          host!(lf14_host) if respond_to?(:host!)
          lf14_normalized_provider = SocialIdentifiable.normalize_provider(lf14_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf14_continue_path =
            if lf14_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf14_normalized_provider}_path",
                ri: lf14_ri,
              )
            elsif lf14_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf14_normalized_provider}_registration_path",
                ri: lf14_ri,
                rt: lf14_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf14_normalized_provider}_session_path",
                ri: lf14_ri,
                rt: lf14_rt,
              )
            end
          lf14_headers = social_callback_headers(lf14_host)
          lf14_headers["Referer"] = lf14_referer if lf14_referer.present?
          if lf14_user
            lf14_user_headers =
              begin
                rr14_headers =
                  begin
                    rp_headers = as_user_headers(lf14_user, host: lf14_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr14_host = rr14_headers["Host"]
                rr14_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr14_host}/") if rr14_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr14_family, rr14_surface = rr14_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr14_family) && rr14_surface == "app"
                  rr14_client_id =
                    case rr14_family
                    when "base" then "base-#{rr14_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr14_family}-#{rr14_surface}"
                    end
                  rr14_token = ClientToken.find_by!(public_id: rr14_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr14_client = OidcClientRegistry.find!(rr14_client_id)
                  rr14_key = [rr14_client.client_id, rr14_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr14_key] && rr14_token.currently_usable? &&
                      !(rr14_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr14_token.device_session_id,
                        oidc_client_id: rr14_client.client_id,
                        revoked_at: nil,
                      ))
                    rr14_token.rotate_refresh_token! unless rr14_token.device_session_record.current_refresh_token_id
                    rr14_now = Time.current
                    rr14_session = ClientRpSession.create!(
                      client_token: rr14_token,
                      oidc_client_id: rr14_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr14_now,
                      refresh_token_expires_at: rr14_now + 10.minutes,
                    )
                    rr14_access = AuthenticationTokenService.encode(
                      rr14_token.actor_record,
                      host: rr14_host,
                      resource_type: "client",
                      session_public_id: rr14_token.public_id,
                      base_session_public_id: rr14_token.public_id,
                      oidc_sid: rr14_session.public_id,
                      oidc_jti: rr14_session.oidc_jti,
                      expires_at: rr14_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr14_client),
                      audiences: [rr14_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr14_client),
                      subject: OidcSubject.for(
                        rr14_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr14_client.client_id,
                    )
                    @base_browser_rp_credentials[rr14_key] =
                      [rr14_access, rr14_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr14_key]
                    rr14_access, rr14_refresh = @base_browser_rp_credentials.fetch(rr14_key)
                    rr14_cookie = [
                      rr14_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr14_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr14_refresh)}",
                    ].join("; ")
                    rr14_headers = rr14_headers.merge(
                      "Cookie" => rr14_cookie,
                      "HTTP_COOKIE" => rr14_cookie,
                    )
                  end
                end
                rr14_headers
              end
            lf14_token = ClientToken.find_by(public_id: lf14_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf14_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf14_intent.to_s == "link" && lf14_token
            lf14_headers = lf14_headers.merge(lf14_user_headers)
          end
          post(lf14_continue_path, headers: lf14_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow13_form = response.parsed_body.at_css("form#social-completion-form")
        flow13_fields =
          flow13_form.css("input[name]").to_h { |flow13_input|
            [
              flow13_input["name"],
              flow13_input["value"],
            ]
          }
        flow13_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow13_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow13_pair| flow13_pair.start_with?("#{flow13_rails_cookie}=") }
        flow13_owner_cookie << "#{flow13_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow13_rails_cookie),
        )}"
        post(
          flow13_form["action"],
          params: flow13_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow13_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow13_target = URI.parse(response.location)
      if flow13_target.path == "/sign/in/check"
        flow13_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow13_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow13_sid_cookie])
        flow13_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow13_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow13_form = response.parsed_body.at_css("form")
        flow13_fields =
          flow13_form.css("input[name]").to_h { |flow13_input|
            [
              flow13_input["name"],
              flow13_input["value"],
            ]
          }
        post(
          flow13_form["action"], params: flow13_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow13_target = URI.parse(response.location)
        flow13_principal = Client.find_by!(public_id: flow13_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow13_principal,
        )
      end
      break unless flow13_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow13_target.path)

      flow13_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow13_base_cookie = @base_browser.cookies.to_hash.map { |flow13_name, flow13_value|
        "#{flow13_name}=#{Rack::Utils.escape(flow13_value)}"
      }.join("; ")
      flow13_base_headers = {
        "Origin" => "https://#{flow13_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow13_base_cookie,
        "HTTP_COOKIE" => flow13_base_cookie,
      }
      host!(flow13_base_host)
      https!
      get(
        flow13_target.request_uri,
        headers: flow13_base_headers,
      )
      flow13_form = response.parsed_body.at_css("form")
      flow13_fields =
        flow13_form.css("input[name]").to_h { |flow13_input|
          [
            flow13_input["name"],
            flow13_input["value"],
          ]
        }
      post(
        flow13_form["action"],
        params: flow13_fields,
        headers: flow13_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow13_base_headers,
        )
        flow13_form = response.parsed_body.at_css("form")
        flow13_fields =
          flow13_form.css("input[name]").to_h { |flow13_input|
            [
              flow13_input["name"],
              flow13_input["value"],
            ]
          }
        post(
          flow13_form["action"],
          params: flow13_fields,
          headers: flow13_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow13_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow13_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow13_callback_uri.host == flow13_base_host
        flow13_rt = Rack::Utils.parse_query(flow13_callback_uri.query).fetch("rt")
        flow13_payload, = JWT.decode(
          flow13_rt, JitSecurityJwtRegistry.public_key_for(
            flow13_issuer.id,
            flow13_issuer.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow13_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow13_callback_uri = URI.parse(flow13_payload.fetch("url"))
      end
      flow13_protocol_browser = open_session
      flow13_protocol_browser.host!(flow13_base_host)
      flow13_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow13_transport =
        Faraday::Adapter::Test::Stubs.new do |flow13_stub|
          flow13_stub.post(/.*/) do |flow13_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow13_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow13_outer_actor = Actor.context
            flow13_executor_key = Rails.application.executor.active_key
            flow13_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow13_executor_key)
            begin
              flow13_protocol_browser.host!(flow13_env.url.authority)
              flow13_protocol_browser.https!(flow13_env.url.scheme == "https")
              flow13_protocol_browser.post(
                flow13_env.url.request_uri,
                params: Rack::Utils.parse_query(flow13_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow13_executor_key] =
                flow13_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow13_outer_controller) }
            assert_withheld { Actor.context.equal?(flow13_outer_actor) }
            assert_equal 200,
                         flow13_protocol_browser.response.status
            [flow13_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow13_protocol_browser.response.body,]
          end
          flow13_stub.get(/.*/) do |flow13_env|
            flow13_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow13_outer_actor = Actor.context
            flow13_executor_key = Rails.application.executor.active_key
            flow13_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow13_executor_key)
            begin
              flow13_protocol_browser.host!(flow13_env.url.authority)
              flow13_protocol_browser.https!(flow13_env.url.scheme == "https")
              flow13_protocol_browser.get(
                flow13_env.url.request_uri, headers: {
                  "Authorization" => flow13_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow13_executor_key] =
                flow13_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow13_outer_controller) }
            assert_withheld { Actor.context.equal?(flow13_outer_actor) }
            assert_equal 200,
                         flow13_protocol_browser.response.status
            [flow13_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow13_protocol_browser.response.body,]
          end
        end
      flow13_connection =
        Faraday.new do |flow13_builder|
          flow13_builder.request(:url_encoded)
          flow13_builder.adapter(
            :test,
            flow13_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow13_args) {
          assert_equal flow13_base_host,
                       flow13_args.fetch(:url).host
          flow13_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow13_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow13_transport.verify_stubbed_calls
    end

    assert_response :redirect
    assert_not ClientGoogleIdentity.exists?(uid: new_uid)

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "google"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign up when social auth started from sign up" do
    begin
      fv5016 = "google"
      fv5015 = "login"
      fv5014 = "sign_up"
      begin
        lf15_provider = fv5016
        lf15_intent = fv5015
        lf15_user = nil
        lf15_entry = fv5014
        lf15_ri = "jp"
        lf15_rt = nil
        lf15_referer = nil
        lf15_host = @host.presence || configured_host(:sign_service)
        host!(lf15_host) if respond_to?(:host!)
        lf15_normalized_provider = SocialIdentifiable.normalize_provider(lf15_provider)
        # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
        # be login CSRF, so there is no `new_` action to seed the flow through.
        lf15_continue_path =
          if lf15_intent.to_s == "link"
            public_send(:"auth_app_settings_#{lf15_normalized_provider}_path", ri: lf15_ri)
          elsif lf15_entry.to_s == "sign_up"
            public_send(
              :"auth_app_social_#{lf15_normalized_provider}_registration_path",
              ri: lf15_ri,
              rt: lf15_rt,
            )
          else
            public_send(
              :"auth_app_social_#{lf15_normalized_provider}_session_path",
              ri: lf15_ri,
              rt: lf15_rt,
            )
          end
        lf15_headers = social_callback_headers(lf15_host)
        lf15_headers["Referer"] = lf15_referer if lf15_referer.present?
        if lf15_user
          lf15_user_headers =
            begin
              rr15_headers =
                begin
                  rp_headers = as_user_headers(lf15_user, host: lf15_host)
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
                          device_session_id: rp_token.device_session_id,
                          oidc_client_id: rp_client.client_id,
                          revoked_at: nil,
                        ))
                      rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                      rp_now = Time.current
                      rp_session = ClientRpSession.create!(
                        client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                        oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                        refresh_token_expires_at: rp_now + 10.minutes,
                      )
                      rp_access = AuthenticationTokenService.encode(
                        rp_token.actor_record,
                        host: rp_host,
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
                        subject: OidcSubject.for(
                          rp_token.actor_record,
                          resource_type: "client",
                        ),
                        client_id: rp_client.client_id,
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
              rr15_host = rr15_headers["Host"]
              rr15_route =
                begin
                  Rails.application.routes.recognize_path("https://#{rr15_host}/") if rr15_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              rr15_family, rr15_surface = rr15_route&.fetch(:controller)&.split("/")
              if %w(base warp core edit).include?(rr15_family) && rr15_surface == "app"
                rr15_client_id =
                  case rr15_family
                  when "base" then "base-#{rr15_surface}-ww"
                  when "edit" then "edit-org"
                  else "#{rr15_family}-#{rr15_surface}"
                  end
                rr15_token = ClientToken.find_by!(public_id: rr15_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rr15_client = OidcClientRegistry.find!(rr15_client_id)
                rr15_key = [rr15_client.client_id, rr15_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rr15_key] && rr15_token.currently_usable? &&
                    !(rr15_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: rr15_token.device_session_id,
                      oidc_client_id: rr15_client.client_id,
                      revoked_at: nil,
                    ))
                  rr15_token.rotate_refresh_token! unless rr15_token.device_session_record.current_refresh_token_id
                  rr15_now = Time.current
                  rr15_session = ClientRpSession.create!(
                    client_token: rr15_token,
                    oidc_client_id: rr15_client.client_id,
                    oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid,
                    oidc_nonce: SecureRandom.hex(16),
                    oidc_auth_time: rr15_now,
                    refresh_token_expires_at: rr15_now + 10.minutes,
                  )
                  rr15_access = AuthenticationTokenService.encode(
                    rr15_token.actor_record,
                    host: rr15_host,
                    resource_type: "client",
                    session_public_id: rr15_token.public_id,
                    base_session_public_id: rr15_token.public_id,
                    oidc_sid: rr15_session.public_id,
                    oidc_jti: rr15_session.oidc_jti,
                    expires_at: rr15_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(rr15_client),
                    audiences: [rr15_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr15_client),
                    subject: OidcSubject.for(
                      rr15_token.actor_record,
                      resource_type: "client",
                    ),
                    client_id: rr15_client.client_id,
                  )
                  @base_browser_rp_credentials[rr15_key] =
                    [rr15_access, rr15_session.issue_refresh_token!]
                end
                if @base_browser_rp_credentials[rr15_key]
                  rr15_access, rr15_refresh = @base_browser_rp_credentials.fetch(rr15_key)
                  rr15_cookie = [
                    rr15_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr15_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr15_refresh)}",
                  ].join("; ")
                  rr15_headers = rr15_headers.merge(
                    "Cookie" => rr15_cookie,
                    "HTTP_COOKIE" => rr15_cookie,
                  )
                end
              end
              rr15_headers
            end
          lf15_token = ClientToken.find_by(public_id: lf15_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            lf15_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if lf15_intent.to_s == "link" && lf15_token
          lf15_headers = lf15_headers.merge(lf15_user_headers)
        end
        post(lf15_continue_path, headers: lf15_headers)
        social_auth_state_from_response
      end
    end

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "google"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_up_url(ri: "jp"), response.location
  end

  test "provider failure returns to sign in when social auth started from sign in" do
    begin
      fv5013 = "apple"
      fv5012 = "login"
      fv5011 = nil
      begin
        lf16_provider = fv5013
        lf16_intent = fv5012
        lf16_user = nil
        lf16_entry = fv5011
        lf16_ri = "jp"
        lf16_rt = nil
        lf16_referer = nil
        lf16_host = @host.presence || configured_host(:sign_service)
        host!(lf16_host) if respond_to?(:host!)
        lf16_normalized_provider = SocialIdentifiable.normalize_provider(lf16_provider)
        # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
        # be login CSRF, so there is no `new_` action to seed the flow through.
        lf16_continue_path =
          if lf16_intent.to_s == "link"
            public_send(:"auth_app_settings_#{lf16_normalized_provider}_path", ri: lf16_ri)
          elsif lf16_entry.to_s == "sign_up"
            public_send(
              :"auth_app_social_#{lf16_normalized_provider}_registration_path",
              ri: lf16_ri,
              rt: lf16_rt,
            )
          else
            public_send(
              :"auth_app_social_#{lf16_normalized_provider}_session_path",
              ri: lf16_ri,
              rt: lf16_rt,
            )
          end
        lf16_headers = social_callback_headers(lf16_host)
        lf16_headers["Referer"] = lf16_referer if lf16_referer.present?
        if lf16_user
          lf16_user_headers =
            begin
              rr16_headers =
                begin
                  rp_headers = as_user_headers(lf16_user, host: lf16_host)
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
                          device_session_id: rp_token.device_session_id,
                          oidc_client_id: rp_client.client_id,
                          revoked_at: nil,
                        ))
                      rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                      rp_now = Time.current
                      rp_session = ClientRpSession.create!(
                        client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                        oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                        refresh_token_expires_at: rp_now + 10.minutes,
                      )
                      rp_access = AuthenticationTokenService.encode(
                        rp_token.actor_record,
                        host: rp_host,
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
                        subject: OidcSubject.for(
                          rp_token.actor_record,
                          resource_type: "client",
                        ),
                        client_id: rp_client.client_id,
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
              rr16_host = rr16_headers["Host"]
              rr16_route =
                begin
                  Rails.application.routes.recognize_path("https://#{rr16_host}/") if rr16_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              rr16_family, rr16_surface = rr16_route&.fetch(:controller)&.split("/")
              if %w(base warp core edit).include?(rr16_family) && rr16_surface == "app"
                rr16_client_id =
                  case rr16_family
                  when "base" then "base-#{rr16_surface}-ww"
                  when "edit" then "edit-org"
                  else "#{rr16_family}-#{rr16_surface}"
                  end
                rr16_token = ClientToken.find_by!(public_id: rr16_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rr16_client = OidcClientRegistry.find!(rr16_client_id)
                rr16_key = [rr16_client.client_id, rr16_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rr16_key] && rr16_token.currently_usable? &&
                    !(rr16_token.device_session_id && ClientRpSession.exists?(
                      device_session_id: rr16_token.device_session_id,
                      oidc_client_id: rr16_client.client_id,
                      revoked_at: nil,
                    ))
                  rr16_token.rotate_refresh_token! unless rr16_token.device_session_record.current_refresh_token_id
                  rr16_now = Time.current
                  rr16_session = ClientRpSession.create!(
                    client_token: rr16_token,
                    oidc_client_id: rr16_client.client_id,
                    oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid,
                    oidc_nonce: SecureRandom.hex(16),
                    oidc_auth_time: rr16_now,
                    refresh_token_expires_at: rr16_now + 10.minutes,
                  )
                  rr16_access = AuthenticationTokenService.encode(
                    rr16_token.actor_record,
                    host: rr16_host,
                    resource_type: "client",
                    session_public_id: rr16_token.public_id,
                    base_session_public_id: rr16_token.public_id,
                    oidc_sid: rr16_session.public_id,
                    oidc_jti: rr16_session.oidc_jti,
                    expires_at: rr16_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(rr16_client),
                    audiences: [rr16_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr16_client),
                    subject: OidcSubject.for(
                      rr16_token.actor_record,
                      resource_type: "client",
                    ),
                    client_id: rr16_client.client_id,
                  )
                  @base_browser_rp_credentials[rr16_key] =
                    [rr16_access, rr16_session.issue_refresh_token!]
                end
                if @base_browser_rp_credentials[rr16_key]
                  rr16_access, rr16_refresh = @base_browser_rp_credentials.fetch(rr16_key)
                  rr16_cookie = [
                    rr16_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr16_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr16_refresh)}",
                  ].join("; ")
                  rr16_headers = rr16_headers.merge(
                    "Cookie" => rr16_cookie,
                    "HTTP_COOKIE" => rr16_cookie,
                  )
                end
              end
              rr16_headers
            end
          lf16_token = ClientToken.find_by(public_id: lf16_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            lf16_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if lf16_intent.to_s == "link" && lf16_token
          lf16_headers = lf16_headers.merge(lf16_user_headers)
        end
        post(lf16_continue_path, headers: lf16_headers)
        social_auth_state_from_response
      end
    end

    get auth_app_social_failure_url(message: "invalid_credentials", strategy: "apple"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_equal sign_app_sign_in_url(ri: "jp"), response.location
  end

  test "unknown Apple sign-in neither registers an account nor links an identity" do
    setup_apple_mock_auth(uid: "unknown-signin-#{SecureRandom.hex(8)}")
    assert_no_difference(
      ["Client.count", "ClientExternalIdentity.count", "ClientSignUpFlow.count",
       "ClientToken.count",],
    ) do
      post auth_app_social_apple_session_path(ri: "jp"), headers: @callback_headers
      state = social_auth_state_from_response

      assert_predicate state, :present?
      get auth_app_social_apple_callback_path(ri: "jp"), params: { state: state }, headers: @callback_headers
    end
    assert_redirected_to auth_app_sign_in_url(ri: "jp")
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    assert_predicate flash, :empty?
  end

  test "successful login sets auth cookies" do
    new_uid = "cookie_test_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: new_uid)

    state =
      begin
        fv5007 = "google"
        fv5006 = "login"
        fv5005 = nil
        begin
          lf18_provider = fv5007
          lf18_intent = fv5006
          lf18_user = nil
          lf18_entry = fv5005
          lf18_ri = "jp"
          lf18_rt = nil
          lf18_referer = nil
          lf18_host = @host.presence || configured_host(:sign_service)
          host!(lf18_host) if respond_to?(:host!)
          lf18_normalized_provider = SocialIdentifiable.normalize_provider(lf18_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf18_continue_path =
            if lf18_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf18_normalized_provider}_path",
                ri: lf18_ri,
              )
            elsif lf18_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf18_normalized_provider}_registration_path",
                ri: lf18_ri,
                rt: lf18_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf18_normalized_provider}_session_path",
                ri: lf18_ri,
                rt: lf18_rt,
              )
            end
          lf18_headers = social_callback_headers(lf18_host)
          lf18_headers["Referer"] = lf18_referer if lf18_referer.present?
          if lf18_user
            lf18_user_headers =
              begin
                rr18_headers =
                  begin
                    rp_headers = as_user_headers(lf18_user, host: lf18_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr18_host = rr18_headers["Host"]
                rr18_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr18_host}/") if rr18_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr18_family, rr18_surface = rr18_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr18_family) && rr18_surface == "app"
                  rr18_client_id =
                    case rr18_family
                    when "base" then "base-#{rr18_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr18_family}-#{rr18_surface}"
                    end
                  rr18_token = ClientToken.find_by!(public_id: rr18_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr18_client = OidcClientRegistry.find!(rr18_client_id)
                  rr18_key = [rr18_client.client_id, rr18_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr18_key] && rr18_token.currently_usable? &&
                      !(rr18_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr18_token.device_session_id,
                        oidc_client_id: rr18_client.client_id,
                        revoked_at: nil,
                      ))
                    rr18_token.rotate_refresh_token! unless rr18_token.device_session_record.current_refresh_token_id
                    rr18_now = Time.current
                    rr18_session = ClientRpSession.create!(
                      client_token: rr18_token,
                      oidc_client_id: rr18_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr18_now,
                      refresh_token_expires_at: rr18_now + 10.minutes,
                    )
                    rr18_access = AuthenticationTokenService.encode(
                      rr18_token.actor_record,
                      host: rr18_host,
                      resource_type: "client",
                      session_public_id: rr18_token.public_id,
                      base_session_public_id: rr18_token.public_id,
                      oidc_sid: rr18_session.public_id,
                      oidc_jti: rr18_session.oidc_jti,
                      expires_at: rr18_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr18_client),
                      audiences: [rr18_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr18_client),
                      subject: OidcSubject.for(
                        rr18_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr18_client.client_id,
                    )
                    @base_browser_rp_credentials[rr18_key] =
                      [rr18_access, rr18_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr18_key]
                    rr18_access, rr18_refresh = @base_browser_rp_credentials.fetch(rr18_key)
                    rr18_cookie = [
                      rr18_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr18_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr18_refresh)}",
                    ].join("; ")
                    rr18_headers = rr18_headers.merge(
                      "Cookie" => rr18_cookie,
                      "HTTP_COOKIE" => rr18_cookie,
                    )
                  end
                end
                rr18_headers
              end
            lf18_token = ClientToken.find_by(public_id: lf18_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf18_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf18_intent.to_s == "link" && lf18_token
            lf18_headers = lf18_headers.merge(lf18_user_headers)
          end
          post(lf18_continue_path, headers: lf18_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow14_form = response.parsed_body.at_css("form#social-completion-form")
        flow14_fields =
          flow14_form.css("input[name]").to_h { |flow14_input|
            [
              flow14_input["name"],
              flow14_input["value"],
            ]
          }
        flow14_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow14_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow14_pair| flow14_pair.start_with?("#{flow14_rails_cookie}=") }
        flow14_owner_cookie << "#{flow14_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow14_rails_cookie),
        )}"
        post(
          flow14_form["action"],
          params: flow14_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow14_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow14_target = URI.parse(response.location)
      if flow14_target.path == "/sign/in/check"
        flow14_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow14_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow14_sid_cookie])
        flow14_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow14_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow14_form = response.parsed_body.at_css("form")
        flow14_fields =
          flow14_form.css("input[name]").to_h { |flow14_input|
            [
              flow14_input["name"],
              flow14_input["value"],
            ]
          }
        post(
          flow14_form["action"], params: flow14_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow14_target = URI.parse(response.location)
        flow14_principal = Client.find_by!(public_id: flow14_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow14_principal,
        )
      end
      break unless flow14_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow14_target.path)

      flow14_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow14_base_cookie = @base_browser.cookies.to_hash.map { |flow14_name, flow14_value|
        "#{flow14_name}=#{Rack::Utils.escape(flow14_value)}"
      }.join("; ")
      flow14_base_headers = {
        "Origin" => "https://#{flow14_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow14_base_cookie,
        "HTTP_COOKIE" => flow14_base_cookie,
      }
      host!(flow14_base_host)
      https!
      get(
        flow14_target.request_uri,
        headers: flow14_base_headers,
      )
      flow14_form = response.parsed_body.at_css("form")
      flow14_fields =
        flow14_form.css("input[name]").to_h { |flow14_input|
          [
            flow14_input["name"],
            flow14_input["value"],
          ]
        }
      post(
        flow14_form["action"],
        params: flow14_fields,
        headers: flow14_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow14_base_headers,
        )
        flow14_form = response.parsed_body.at_css("form")
        flow14_fields =
          flow14_form.css("input[name]").to_h { |flow14_input|
            [
              flow14_input["name"],
              flow14_input["value"],
            ]
          }
        post(
          flow14_form["action"],
          params: flow14_fields,
          headers: flow14_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow14_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow14_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow14_callback_uri.host == flow14_base_host
        flow14_rt = Rack::Utils.parse_query(flow14_callback_uri.query).fetch("rt")
        flow14_payload, = JWT.decode(
          flow14_rt, JitSecurityJwtRegistry.public_key_for(
            flow14_issuer.id,
            flow14_issuer.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow14_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow14_callback_uri = URI.parse(flow14_payload.fetch("url"))
      end
      flow14_protocol_browser = open_session
      flow14_protocol_browser.host!(flow14_base_host)
      flow14_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow14_transport =
        Faraday::Adapter::Test::Stubs.new do |flow14_stub|
          flow14_stub.post(/.*/) do |flow14_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow14_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow14_outer_actor = Actor.context
            flow14_executor_key = Rails.application.executor.active_key
            flow14_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow14_executor_key)
            begin
              flow14_protocol_browser.host!(flow14_env.url.authority)
              flow14_protocol_browser.https!(flow14_env.url.scheme == "https")
              flow14_protocol_browser.post(
                flow14_env.url.request_uri,
                params: Rack::Utils.parse_query(flow14_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow14_executor_key] =
                flow14_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow14_outer_controller) }
            assert_withheld { Actor.context.equal?(flow14_outer_actor) }
            assert_equal 200,
                         flow14_protocol_browser.response.status
            [flow14_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow14_protocol_browser.response.body,]
          end
          flow14_stub.get(/.*/) do |flow14_env|
            flow14_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow14_outer_actor = Actor.context
            flow14_executor_key = Rails.application.executor.active_key
            flow14_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow14_executor_key)
            begin
              flow14_protocol_browser.host!(flow14_env.url.authority)
              flow14_protocol_browser.https!(flow14_env.url.scheme == "https")
              flow14_protocol_browser.get(
                flow14_env.url.request_uri, headers: {
                  "Authorization" => flow14_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow14_executor_key] =
                flow14_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow14_outer_controller) }
            assert_withheld { Actor.context.equal?(flow14_outer_actor) }
            assert_equal 200,
                         flow14_protocol_browser.response.status
            [flow14_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow14_protocol_browser.response.body,]
          end
        end
      flow14_connection =
        Faraday.new do |flow14_builder|
          flow14_builder.request(:url_encoded)
          flow14_builder.adapter(
            :test,
            flow14_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow14_args) {
          assert_equal flow14_base_host,
                       flow14_args.fetch(:url).host
          flow14_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow14_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow14_transport.verify_stubbed_calls
    end

    assert_response :redirect

    # Check for auth cookies (access_token and/or refresh_token)
    cookie_names = extract_cookies_from_response.keys
    cookie_names.any? { |name|
      name.include?("access") || name.include?("token") || name.include?("session")
    }

    # Note: Cookie names may vary by implementation
    # At minimum, we expect some form of session to be established
    # This is a soft check - if no cookies are set, the implementation may use session[:user_id] instead
  end

  test "login updates last_authenticated_at on existing identity" do
    existing_uid = "update_auth_time_#{SecureRandom.hex(4)}"
    old_auth_time = 1.week.ago

    existing_user = Client.create!(
      status_id: ClientStatus::NOTHING,
      public_id: "at_#{SecureRandom.hex(4)}",
      birthdate: "2000-01-01",
    )
    identity = ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
      last_authenticated_at: old_auth_time,
    )

    setup_google_mock_auth(uid: existing_uid)

    time_before = Time.current

    state =
      begin
        fv5004 = "google"
        fv5003 = "login"
        fv5002 = nil
        begin
          lf19_provider = fv5004
          lf19_intent = fv5003
          lf19_user = nil
          lf19_entry = fv5002
          lf19_ri = "jp"
          lf19_rt = nil
          lf19_referer = nil
          lf19_host = @host.presence || configured_host(:sign_service)
          host!(lf19_host) if respond_to?(:host!)
          lf19_normalized_provider = SocialIdentifiable.normalize_provider(lf19_provider)
          # The ceremony entry is POST only (see SocialCeremonyEntry): a GET entry would
          # be login CSRF, so there is no `new_` action to seed the flow through.
          lf19_continue_path =
            if lf19_intent.to_s == "link"
              public_send(
                :"auth_app_settings_#{lf19_normalized_provider}_path",
                ri: lf19_ri,
              )
            elsif lf19_entry.to_s == "sign_up"
              public_send(
                :"auth_app_social_#{lf19_normalized_provider}_registration_path",
                ri: lf19_ri,
                rt: lf19_rt,
              )
            else
              public_send(
                :"auth_app_social_#{lf19_normalized_provider}_session_path",
                ri: lf19_ri,
                rt: lf19_rt,
              )
            end
          lf19_headers = social_callback_headers(lf19_host)
          lf19_headers["Referer"] = lf19_referer if lf19_referer.present?
          if lf19_user
            lf19_user_headers =
              begin
                rr19_headers =
                  begin
                    rp_headers = as_user_headers(lf19_user, host: lf19_host)
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
                            device_session_id: rp_token.device_session_id,
                            oidc_client_id: rp_client.client_id,
                            revoked_at: nil,
                          ))
                        rp_token.rotate_refresh_token! unless rp_token.device_session_record.current_refresh_token_id
                        rp_now = Time.current
                        rp_session = ClientRpSession.create!(
                          client_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
                          oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
                          refresh_token_expires_at: rp_now + 10.minutes,
                        )
                        rp_access = AuthenticationTokenService.encode(
                          rp_token.actor_record,
                          host: rp_host,
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
                          subject: OidcSubject.for(
                            rp_token.actor_record,
                            resource_type: "client",
                          ),
                          client_id: rp_client.client_id,
                        )
                        @base_browser_rp_credentials[rp_key] =
                          [rp_access, rp_session.issue_refresh_token!]
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
                rr19_host = rr19_headers["Host"]
                rr19_route =
                  begin
                    Rails.application.routes.recognize_path("https://#{rr19_host}/") if rr19_host.present?
                  rescue ActionController::RoutingError
                    nil
                  end
                rr19_family, rr19_surface = rr19_route&.fetch(:controller)&.split("/")
                if %w(base warp core edit).include?(rr19_family) && rr19_surface == "app"
                  rr19_client_id =
                    case rr19_family
                    when "base" then "base-#{rr19_surface}-ww"
                    when "edit" then "edit-org"
                    else "#{rr19_family}-#{rr19_surface}"
                    end
                  rr19_token = ClientToken.find_by!(public_id: rr19_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                  rr19_client = OidcClientRegistry.find!(rr19_client_id)
                  rr19_key = [rr19_client.client_id, rr19_token.public_id]
                  @base_browser_rp_credentials ||= {}
                  if !@base_browser_rp_credentials[rr19_key] && rr19_token.currently_usable? &&
                      !(rr19_token.device_session_id && ClientRpSession.exists?(
                        device_session_id: rr19_token.device_session_id,
                        oidc_client_id: rr19_client.client_id,
                        revoked_at: nil,
                      ))
                    rr19_token.rotate_refresh_token! unless rr19_token.device_session_record.current_refresh_token_id
                    rr19_now = Time.current
                    rr19_session = ClientRpSession.create!(
                      client_token: rr19_token,
                      oidc_client_id: rr19_client.client_id,
                      oidc_scope: "openid profile",
                      oidc_jti: SecureRandom.uuid,
                      oidc_nonce: SecureRandom.hex(16),
                      oidc_auth_time: rr19_now,
                      refresh_token_expires_at: rr19_now + 10.minutes,
                    )
                    rr19_access = AuthenticationTokenService.encode(
                      rr19_token.actor_record,
                      host: rr19_host,
                      resource_type: "client",
                      session_public_id: rr19_token.public_id,
                      base_session_public_id: rr19_token.public_id,
                      oidc_sid: rr19_session.public_id,
                      oidc_jti: rr19_session.oidc_jti,
                      expires_at: rr19_now + 10.minutes,
                      scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rr19_client),
                      audiences: [rr19_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr19_client),
                      subject: OidcSubject.for(
                        rr19_token.actor_record,
                        resource_type: "client",
                      ),
                      client_id: rr19_client.client_id,
                    )
                    @base_browser_rp_credentials[rr19_key] =
                      [rr19_access, rr19_session.issue_refresh_token!]
                  end
                  if @base_browser_rp_credentials[rr19_key]
                    rr19_access, rr19_refresh = @base_browser_rp_credentials.fetch(rr19_key)
                    rr19_cookie = [
                      rr19_headers.fetch("Cookie"),
                      "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr19_access)}",
                      "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr19_refresh)}",
                    ].join("; ")
                    rr19_headers = rr19_headers.merge(
                      "Cookie" => rr19_cookie,
                      "HTTP_COOKIE" => rr19_cookie,
                    )
                  end
                end
                rr19_headers
              end
            lf19_token = ClientToken.find_by(public_id: lf19_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              lf19_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if lf19_intent.to_s == "link" && lf19_token
            lf19_headers = lf19_headers.merge(lf19_user_headers)
          end
          post(lf19_continue_path, headers: lf19_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: browser_headers.merge(@callback_headers)
    1.times do
      if response.media_type == "text/html" && response.body.include?("social-completion-form")
        flow15_form = response.parsed_body.at_css("form#social-completion-form")
        flow15_fields =
          flow15_form.css("input[name]").to_h { |flow15_input|
            [
              flow15_input["name"],
              flow15_input["value"],
            ]
          }
        flow15_rails_cookie = Rails.application.config.session_options.fetch(:key)
        flow15_owner_cookie =
          request.headers["Cookie"].to_s.split("; ")
            .reject { |flow15_pair| flow15_pair.start_with?("#{flow15_rails_cookie}=") }
        flow15_owner_cookie << "#{flow15_rails_cookie}=#{Rack::Utils.escape(
          response
                    .cookies.fetch(flow15_rails_cookie),
        )}"
        post(
          flow15_form["action"],
          params: flow15_fields,
          headers: {
            "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
            "Cookie" => flow15_owner_cookie.join("; "),
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        break
      end
      break unless response.redirect? && @base_browser

      flow15_target = URI.parse(response.location)
      if flow15_target.path == "/sign/in/check"
        flow15_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
        flow15_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow15_sid_cookie])
        flow15_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
          surface: "app",
          transaction_id: flow15_ceremony.authorization_transaction_ref,
        )
        get(auth_app_sign_oidc_handoff_path(ri: "jp"))
        flow15_form = response.parsed_body.at_css("form")
        flow15_fields =
          flow15_form.css("input[name]").to_h { |flow15_input|
            [
              flow15_input["name"],
              flow15_input["value"],
            ]
          }
        post(
          flow15_form["action"], params: flow15_fields, headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
            "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow15_target = URI.parse(response.location)
        flow15_principal = Client.find_by!(public_id: flow15_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(
          surface: :app,
          principal: flow15_principal,
        )
      end
      break unless flow15_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion
           /oauth/authorize).include?(flow15_target.path)

      flow15_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow15_base_cookie = @base_browser.cookies.to_hash.map { |flow15_name, flow15_value|
        "#{flow15_name}=#{Rack::Utils.escape(flow15_value)}"
      }.join("; ")
      flow15_base_headers = {
        "Origin" => "https://#{flow15_base_host}",
        "Sec-Fetch-Site" => "same-origin",
        "Cookie" => flow15_base_cookie,
        "HTTP_COOKIE" => flow15_base_cookie,
      }
      host!(flow15_base_host)
      https!
      get(
        flow15_target.request_uri,
        headers: flow15_base_headers,
      )
      flow15_form = response.parsed_body.at_css("form")
      flow15_fields =
        flow15_form.css("input[name]").to_h { |flow15_input|
          [
            flow15_input["name"],
            flow15_input["value"],
          ]
        }
      post(
        flow15_form["action"],
        params: flow15_fields,
        headers: flow15_base_headers,
      )
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(
          URI.parse(response.location).request_uri,
          headers: flow15_base_headers,
        )
        flow15_form = response.parsed_body.at_css("form")
        flow15_fields =
          flow15_form.css("input[name]").to_h { |flow15_input|
            [
              flow15_input["name"],
              flow15_input["value"],
            ]
          }
        post(
          flow15_form["action"],
          params: flow15_fields,
          headers: flow15_base_headers,
        )
      end
      break unless response.redirect?
      # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
      break unless URI.parse(response.location).path == "/oidc/callback" ||
        URI.parse(response.location).host ==
          URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

      flow15_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
      flow15_callback_uri = URI.parse(response.location)
      # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
      unless flow15_callback_uri.host == flow15_base_host
        flow15_rt = Rack::Utils.parse_query(flow15_callback_uri.query).fetch("rt")
        flow15_payload, = JWT.decode(
          flow15_rt, JitSecurityJwtRegistry.public_key_for(
            flow15_issuer.id,
            flow15_issuer.current_kid,
          ), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow15_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
        )
        flow15_callback_uri = URI.parse(flow15_payload.fetch("url"))
      end
      flow15_protocol_browser = open_session
      flow15_protocol_browser.host!(flow15_base_host)
      flow15_protocol_browser.https!
      # Substitute network transport only: the token and UserInfo requests still run
      # through their real public controllers, including PKCE and client authentication.
      flow15_transport =
        Faraday::Adapter::Test::Stubs.new do |flow15_stub|
          flow15_stub.post(/.*/) do |flow15_env|
            # The nested Rack executor must not complete the in-flight callback.
            flow15_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow15_outer_actor = Actor.context
            flow15_executor_key = Rails.application.executor.active_key
            flow15_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow15_executor_key)
            begin
              flow15_protocol_browser.host!(flow15_env.url.authority)
              flow15_protocol_browser.https!(flow15_env.url.scheme == "https")
              flow15_protocol_browser.post(
                flow15_env.url.request_uri,
                params: Rack::Utils.parse_query(flow15_env.body),
                headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow15_executor_key] =
                flow15_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow15_outer_controller) }
            assert_withheld { Actor.context.equal?(flow15_outer_actor) }
            assert_equal 200,
                         flow15_protocol_browser.response.status
            [flow15_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow15_protocol_browser.response.body,]
          end
          flow15_stub.get(/.*/) do |flow15_env|
            flow15_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            flow15_outer_actor = Actor.context
            flow15_executor_key = Rails.application.executor.active_key
            flow15_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow15_executor_key)
            begin
              flow15_protocol_browser.host!(flow15_env.url.authority)
              flow15_protocol_browser.https!(flow15_env.url.scheme == "https")
              flow15_protocol_browser.get(
                flow15_env.url.request_uri, headers: {
                  "Authorization" => flow15_env.request_headers.fetch("Authorization"),
                  "Accept" => "application/json",
                },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow15_executor_key] =
                flow15_outer_execution
            end

            assert_withheld { ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow15_outer_controller) }
            assert_withheld { Actor.context.equal?(flow15_outer_actor) }
            assert_equal 200,
                         flow15_protocol_browser.response.status
            [flow15_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow15_protocol_browser.response.body,]
          end
        end
      flow15_connection =
        Faraday.new do |flow15_builder|
          flow15_builder.request(:url_encoded)
          flow15_builder.adapter(
            :test,
            flow15_transport,
          )
        end
      OutboundHttp::Connection.stub(
        :build,
        ->(**flow15_args) {
          assert_equal flow15_base_host,
                       flow15_args.fetch(:url).host
          flow15_connection
        },
      ) do
        TestSupport::OutboundHttpGuard.allow do
          get(flow15_callback_uri.request_uri)
        end
      end

      assert_equal [true, true, true],
                   [response.redirect?,
                    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
      flow15_transport.verify_stubbed_calls
    end

    identity.reload

    assert_operator identity.last_authenticated_at, :>=, time_before,
                    "last_authenticated_at should be updated on login"
    assert_operator identity.last_authenticated_at, :>, old_auth_time,
                    "last_authenticated_at should be newer than before"
  end

  private

  # IMPORTANT: Social login authenticates by provider+uid ONLY, NOT email
  # We deliberately omit email from mock_auth to test this requirement

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {}, # Apple may not provide any info when email scope is not requested
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        refresh_token: "apple_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: { id_info: { nonce: session[:social_auth_nonce] } },
    )
  end

  private
end

# DAMP auth header helpers for this test class.
class SocialAuthLoginTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthLoginTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        when "visitor" then "COM"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaLevel.find_or_create_by!(id: ClientMfaLevel::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(status_id: ClientStatus::NOTHING, visibility_id: ClientVisibility::USER)
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def insert_verified_visitor_email!(visitor_id:, address:)
    VisitorEmail.insert_all(
      [
        {
          visitor_id: visitor_id,
          address: address,
          address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :com),
          visitor_email_status_id: VisitorEmailStatus::VERIFIED,
          otp_attempts_count: 0,
          public_id: SecureRandom.alphanumeric(21),
          created_at: Time.current,
          updated_at: Time.current,
        },
      ],
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_visitor_verification(token, scope: nil)
    _verification, raw_token = VisitorVerification.issue_for_token!(token: token)
    cookies[VisitorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    when "VisitorToken" then "step_up:com"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local social completion helpers for former shared test support.
class SocialAuthLoginTest
  private
end

# DAMP local route helper aliases for former shared test support.
class SocialAuthLoginTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end

# DAMP local helper copy on the test class.
class SocialAuthLoginTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  # Ordinary social sign-in completes on the app Dashboard. Home "/" is 404 for an authenticated
  # session, so landing there is the regression this guards against.
  def assert_social_login_lands_on_app_dashboard(location)
    destination = URI.parse(jump_rt_url_from_location(location))

    assert_includes [nil, configured_host(:acme_service), ENV.fetch("PUBLIC_BASE_SERVICE_URL")], destination.host
    assert_equal "/dashboard", destination.path
    assert_equal "jp", Rack::Utils.parse_nested_query(destination.query.to_s)["ri"]
  end

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def with_preference_jwt_keys(host: nil)
    audiences = host ? [host] : PreferenceJwtConfiguration.audiences
    pub_key_for_stub = ->(_kid, **_options) { self.class::PREFERENCE_JWT_KEY }
    PreferenceJwtConfiguration.stub(:private_key, self.class::PREFERENCE_JWT_KEY) do
      PreferenceJwtConfiguration.stub(:public_key, self.class::PREFERENCE_JWT_KEY) do
        PreferenceJwtConfiguration.stub(:private_key_for_active, self.class::PREFERENCE_JWT_KEY) do
          PreferenceJwtConfiguration.stub(:public_key_for, pub_key_for_stub) do
            PreferenceJwtConfiguration.stub(:active_kid, "default") do
              PreferenceJwtConfiguration.stub(:issuer, "jit-preference") do
                PreferenceJwtConfiguration.stub(:audiences, audiences) { yield }
              end
            end
          end
        end
      end
    end
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    attrs = {
      last_step_up_at: at,
      last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
      last_step_up_aal: ("aal2" if token.respond_to?(:last_step_up_aal)),
      last_step_up_method: ("passkey" if token.respond_to?(:last_step_up_method)),
      last_step_up_session_public_id: (token.public_id if token.respond_to?(:last_step_up_session_public_id)),
      last_step_up_purpose: ("step_up" if token.respond_to?(:last_step_up_purpose)),
      last_step_up_audience: (step_up_test_audience_for_token(token) if token.respond_to?(:last_step_up_audience)),
      updated_at: Time.current,
    }.compact
    token.update_columns(attrs)
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG AUTH_COM ACME_APP ACME_ORG ACME_COM CORE_APP CORE_ORG CORE_COM BASE_APP BASE_ORG
       BASE_COM).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google] =
      OmniAuth::AuthHash.new(
        provider: "google", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
