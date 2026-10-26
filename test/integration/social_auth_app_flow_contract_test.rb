# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialAuthAppFlowContractTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_email_statuses, :client_totp_credential_statuses

  PROVIDERS = {
    google: {
      provider: "google",
      normalized: "google",
      model: ClientExternalIdentity,
      config_path: :auth_app_settings_path,
      token_prefix: "google",
    },
    apple: {
      provider: "apple",
      normalized: "apple",
      model: ClientExternalIdentity,
      config_path: :auth_app_settings_apple_path,
      token_prefix: "apple",
    },
  }.freeze

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.enabled = true
    # The ceremony runs on the Auth host the application is configured with: a request
    # made to any other host gets a session cookie the application does not read back,
    # so the sign-up ticket is lost and the flow restarts instead of advancing.
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @base_host = ENV.fetch("PRIVATE_BASE_SERVICE_URL")
    @callback_headers = social_callback_headers(@host)
    TurnstileVerifierStub.challenge_response = { "success" => true }
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    TurnstileVerifierStub.enabled = false
  end

  test "Google sign up entry creates one client and one active social identity without email" do
    begin
      flow0_config = PROVIDERS.fetch(:google)
      flow0_uid = "#{flow0_config.fetch(:normalized)}_signup_#{SecureRandom.hex(4)}"
      flow0_state =
        begin
          flow1_provider = flow0_config.fetch(:provider)
          flow1_intent = "login"
          flow1_user = nil
          flow1_entry = "sign_up"
          flow1_ri = "jp"
          flow1_rt = nil
          flow1_referer = nil
          unless flow1_intent.to_s == "link"
            @base_browser = open_session
            flow1_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow1_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            flow1_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow1_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow1_ri,
                pt: "/dashboard?ri=#{flow1_ri}",
              },
            )
            flow1_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow1_fields =
              flow1_form.css("input[name]").to_h { |flow1_input|
                [
                  flow1_input["name"],
                  flow1_input["value"],
                ]
              }
            @base_browser.post(
              flow1_form["action"], params: flow1_fields, headers: {
                "Origin" => "https://#{flow1_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow1_rt = follow_social_authorization_bootstrap!(
              base_browser: @base_browser,
              base_host: flow1_base_host,
              visa_host: flow1_visa_host,
              auth_host: flow1_auth_host,
            )
            switch_social_browser_to_sign_up!(
              base_browser: @base_browser,
              auth_host: flow1_auth_host,
              visa_host: flow1_visa_host,
            )
          end
          flow1_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow1_host)
          flow1_normalized_provider = SocialIdentifiable.normalize_provider(flow1_provider)
          flow1_continue_path =
            if flow1_intent.to_s == "link"
              ((if flow1_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow1_ri)
                else
                  auth_app_settings_apple_path(ri: flow1_ri)
                end))
            elsif flow1_entry.to_s == "sign_up"
              ((flow1_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow1_ri,
                rt: flow1_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow1_ri,
                rt: flow1_rt,
              ))
            else
              ((flow1_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow1_ri,
                rt: flow1_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow1_ri,
                rt: flow1_rt,
              ))
            end
          flow1_headers = social_callback_headers(flow1_host)
          flow1_headers["Referer"] = flow1_referer if flow1_referer.present?
          if flow1_user
            flow1_user_headers =
              as_user_headers(flow1_user, host: flow1_host)
            flow1_token = ClientToken.find_by(public_id: flow1_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow1_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow1_intent.to_s == "link" && flow1_token
            flow1_headers = flow1_headers.merge(flow1_user_headers)
          end
          post(flow1_continue_path, headers: flow1_headers)
          social_auth_state_from_response
        end
      setup_mock_auth(flow0_config, uid: flow0_uid, token: "new_signup_token")

      begin
        flow2_config = flow0_config
        flow2_state = flow0_state
        assert_no_difference("Client.count") do
          assert_no_difference("#{flow2_config.fetch(:model)}.count") do
            begin
              flow3_config = flow2_config
              flow3_params = { state: flow2_state }
              flow3_headers = browser_headers.merge(@callback_headers)
              if flow3_config.fetch(:provider) == "apple"
                get(
                  auth_app_social_apple_callback_url(
                    provider: "apple",
                    ri: "jp",
                  ), params: flow3_params, headers: flow3_headers,
                )
              else
                get(
                  auth_app_social_google_callback_url(
                    provider: flow3_config.fetch(:provider),
                    ri: "jp",
                  ),
                  params: flow3_params,
                  headers: flow3_headers,
                )
              end
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
                  flow4_owner_cookie << "#{flow4_rails_cookie}=#{Rack::Utils.escape(
                    response
                                        .cookies.fetch(flow4_rails_cookie),
                  )}"
                  post(
                    flow4_form["action"],
                    params: flow4_fields,
                    headers: {
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
                    surface: "app",
                    transaction_id: flow4_ceremony.authorization_transaction_ref,
                  )
                  get(
                    auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                      "Sec-Fetch-Mode" => "navigate",
                      "Sec-Fetch-Dest" => "document",
                      "Sec-Fetch-Site" => "same-origin",
                    },
                  )
                  flow4_target = URI.parse(response.location)
                  flow4_principal = Client.find_by!(public_id: flow4_parent.reload.actor_ref)
                  BaseSelectorBootstrapAuthority.call(
                    surface: :app,
                    principal: flow4_principal,
                  )
                end
                if flow4_target.host == ENV.fetch("PUBLIC_VISA_SERVICE_URL") &&
                    flow4_target.path == "/oidc/result"
                  complete_social_oidc_visa_result!(
                    target: flow4_target,
                    base_browser: @base_browser,
                    base_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
                    visa_host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
                  )
                  break
                end
                break unless flow4_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                  %w(/social/authentication/completion
                     /oauth/authorize).include?(flow4_target.path)

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
                get(
                  flow4_target.request_uri,
                  headers: flow4_base_headers,
                )
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
                  get(
                    URI.parse(response.location).request_uri,
                    headers: flow4_base_headers,
                  )
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
                    flow4_rt,
                    JitSecurityJwtRegistry.public_key_for(
                      flow4_issuer.id,
                      flow4_issuer.current_kid,
                    ),
                    true,
                    algorithms: ["ES384"],
                    verify_iss: true,
                    iss: "https://#{flow4_base_host}",
                    verify_aud: true,
                    aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
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
                                   [ActiveSupport::ExecutionContext.to_h
                                     .fetch(:controller).equal?(flow4_outer_controller),
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
                                   [ActiveSupport::ExecutionContext.to_h
                                     .fetch(:controller).equal?(flow4_outer_controller),
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
                    get(flow4_callback_uri.request_uri, headers: flow4_base_headers)
                  end
                end

                assert_equal [true, true, true],
                             [response.redirect?,
                              cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                              cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
                flow4_transport.verify_stubbed_calls
              end
            end
          end
        end

        guard_url =
          if flow2_config.fetch(:normalized) == "google"
            auth_app_sign_up_guard_google_url(ri: "jp")
          else
            auth_app_sign_up_guard_apple_url(ri: "jp")
          end

        assert_redirected_to guard_url
        follow_redirect!

        @social_signup_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

        assert_predicate @social_signup_binding, :present?
        assert_redirected_to(
          (flow2_config
                    .fetch(:normalized) == "google") ? auth_app_sign_up_check_google_confirmation_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ) : auth_app_sign_up_check_apple_confirmation_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ),
        )
        follow_redirect!

        assert_response :ok
        assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
        assert_predicate inertia_props.fetch("confirm_label"), :present?
      end
      flow0_cycle = ClientSignUpFlow.order(:id).last

      begin
        flow5_config = flow0_config
        flow5_cycle = flow0_cycle
        assert_difference("Client.count", 1) do
          assert_no_difference("ClientExternalIdentity.count") do
            patch(
              ((flow5_config.fetch(:normalized) == "google") ? auth_app_sign_up_check_google_confirmation_url(
                ri: "jp",
                fb: @social_signup_binding,
              ) : auth_app_sign_up_check_apple_confirmation_url(
                ri: "jp",
                fb: @social_signup_binding,
              )),
              params: { confirm_new_social_identity: "1", checkpoint_version: flow5_cycle.checkpoint_version },
              headers: browser_headers.merge(@callback_headers),
            )
          end
        end

        @social_signup_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

        assert_redirected_to(
          (flow5_config
                    .fetch(:normalized) == "google") ? auth_app_sign_up_check_google_birthdate_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ) : auth_app_sign_up_check_apple_birthdate_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ),
        )
        follow_redirect!

        assert_no_difference("Client.count") do
          assert_difference("#{flow5_config.fetch(:model)}.count", 1) do
            patch(
              ((flow5_config.fetch(:normalized) == "google") ? auth_app_sign_up_check_google_birthdate_url(
                ri: "jp",
                fb: @social_signup_binding,
              ) : auth_app_sign_up_check_apple_birthdate_url(
                ri: "jp",
                fb: @social_signup_binding,
              )),
              params: {
                requirement: "birthdate",
                birthdate: "2000-02-03",
                checkpoint_version: flow5_cycle.reload.checkpoint_version,
              },
              headers: browser_headers.merge(@callback_headers),
            )
          end
        end

        assert_response :redirect
        # WU-05f: finalization hands the browser to the canonical Sign In flow; it never
        # re-enters the removed Base social sign-up completion transport.
        assert_equal "/sign/in/check", URI.parse(response.location).path

        assert_no_difference("Client.count") do
          assert_no_difference("#{flow5_config.fetch(:model)}.count") do
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
                flow6_owner_cookie << "#{flow6_rails_cookie}=#{Rack::Utils.escape(
                  response
                                    .cookies.fetch(flow6_rails_cookie),
                )}"
                post(
                  flow6_form["action"], params: flow6_fields, headers: {
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
                  surface: "app", transaction_id: flow6_ceremony.authorization_transaction_ref,
                )
                get(
                  auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Sec-Fetch-Mode" => "navigate",
                    "Sec-Fetch-Dest" => "document",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                flow6_target = URI.parse(response.location)
                flow6_principal = Client.find_by!(public_id: flow6_parent.reload.actor_ref)
                BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow6_principal)
              end
              if flow6_target.host == ENV.fetch("PUBLIC_VISA_SERVICE_URL") &&
                  flow6_target.path == "/oidc/result"
                complete_social_oidc_visa_result!(
                  target: flow6_target,
                  base_browser: @base_browser,
                  base_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
                  visa_host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
                )
                break
              end
              break unless flow6_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                %w(/social/authentication/completion /oauth/authorize).include?(flow6_target.path)

              flow6_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
              flow6_base_cookie = @base_browser.cookies.to_hash.map { |flow6_name, flow6_value|
                "#{flow6_name}=#{Rack::Utils.escape(flow6_value)}"
              }.join("; ")
              flow6_base_headers = { "Origin" => "https://#{flow6_base_host}",
                                     "Sec-Fetch-Site" => "same-origin",
                                     "Cookie" => flow6_base_cookie,
                                     "HTTP_COOKIE" => flow6_base_cookie, }
              host!(flow6_base_host)
              https!
              get(flow6_target.request_uri, headers: flow6_base_headers)
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
                get(URI.parse(response.location).request_uri, headers: flow6_base_headers)
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
                  flow6_rt, JitSecurityJwtRegistry.public_key_for(
                    flow6_issuer.id,
                    flow6_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow6_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
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
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow6_outer_controller),
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
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow6_outer_controller),
                                  Actor.context.equal?(flow6_outer_actor), flow6_protocol_browser.response.status,]
                    [flow6_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow6_protocol_browser.response.body,]
                  end
                end
              flow6_connection =
                Faraday.new do |flow6_builder|
                  flow6_builder.request(:url_encoded)
                  flow6_builder.adapter(:test, flow6_transport)
                end
              OutboundHttp::Connection.stub(
                :build, ->(**flow6_args) {
                  assert_equal flow6_base_host, flow6_args.fetch(:url).host
                  flow6_connection
                },
              ) do
                TestSupport::OutboundHttpGuard.allow do
                  get(flow6_callback_uri.request_uri, headers: flow6_base_headers)
                end
              end

              assert_equal [true, true, true],
                           [response.redirect?,
                            cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                            cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
              flow6_transport.verify_stubbed_calls
            end
          end
        end
      end

      flow0_identity = flow0_config.fetch(:model).find_by!(
        provider: flow0_config.fetch(:provider),
        subject: flow0_uid,
      )
      flow0_user = Client.find(flow0_identity.client_id)

      assert_response :redirect
      assert_equal "2000-02-03", flow0_user.reload.birthdate
      assert ClientToken.exists?(user_id: flow0_user.id)

      assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, flow0_user.status_id
      assert_equal "active", flow0_identity.state
      assert_equal flow0_config.fetch(:provider), flow0_identity.provider
      assert_not_nil flow0_identity.last_authenticated_at
      assert_nil ClientEmail.find_by(user: flow0_user)
    end
  end

  test "Apple sign up entry creates one client and one active social identity without email" do
    begin
      flow7_config = PROVIDERS.fetch(:apple)
      flow7_uid = "#{flow7_config.fetch(:normalized)}_signup_#{SecureRandom.hex(4)}"
      flow7_state =
        begin
          flow8_provider = flow7_config.fetch(:provider)
          flow8_intent = "login"
          flow8_user = nil
          flow8_entry = "sign_up"
          flow8_ri = "jp"
          flow8_rt = nil
          flow8_referer = nil
          unless flow8_intent.to_s == "link"
            @base_browser = open_session
            flow8_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow8_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            flow8_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow8_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow8_ri,
                pt: "/dashboard?ri=#{flow8_ri}",
              },
            )
            flow8_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow8_fields =
              flow8_form.css("input[name]").to_h { |flow8_input|
                [
                  flow8_input["name"],
                  flow8_input["value"],
                ]
              }
            @base_browser.post(
              flow8_form["action"], params: flow8_fields, headers: {
                "Origin" => "https://#{flow8_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow8_rt = follow_social_authorization_bootstrap!(
              base_browser: @base_browser,
              base_host: flow8_base_host,
              visa_host: flow8_visa_host,
              auth_host: flow8_auth_host,
            )
            switch_social_browser_to_sign_up!(
              base_browser: @base_browser,
              auth_host: flow8_auth_host,
              visa_host: flow8_visa_host,
            )
          end
          flow8_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow8_host)
          flow8_normalized_provider = SocialIdentifiable.normalize_provider(flow8_provider)
          flow8_continue_path =
            if flow8_intent.to_s == "link"
              ((if flow8_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow8_ri)
                else
                  auth_app_settings_apple_path(ri: flow8_ri)
                end))
            elsif flow8_entry.to_s == "sign_up"
              ((flow8_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow8_ri,
                rt: flow8_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow8_ri,
                rt: flow8_rt,
              ))
            else
              ((flow8_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow8_ri,
                rt: flow8_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow8_ri,
                rt: flow8_rt,
              ))
            end
          flow8_headers = social_callback_headers(flow8_host)
          flow8_headers["Referer"] = flow8_referer if flow8_referer.present?
          if flow8_user
            flow8_user_headers =
              as_user_headers(flow8_user, host: flow8_host)
            flow8_token = ClientToken.find_by(public_id: flow8_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow8_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow8_intent.to_s == "link" && flow8_token
            flow8_headers = flow8_headers.merge(flow8_user_headers)
          end
          post(flow8_continue_path, headers: flow8_headers)
          social_auth_state_from_response
        end
      setup_mock_auth(flow7_config, uid: flow7_uid, token: "new_signup_token")

      begin
        flow9_config = flow7_config
        flow9_state = flow7_state
        assert_no_difference("Client.count") do
          assert_no_difference("#{flow9_config.fetch(:model)}.count") do
            begin
              flow10_config = flow9_config
              flow10_params = { state: flow9_state }
              flow10_headers = browser_headers.merge(@callback_headers)
              if flow10_config.fetch(:provider) == "apple"
                get(
                  auth_app_social_apple_callback_url(
                    provider: "apple",
                    ri: "jp",
                  ), params: flow10_params, headers: flow10_headers,
                )
              else
                get(
                  auth_app_social_google_callback_url(
                    provider: flow10_config.fetch(:provider),
                    ri: "jp",
                  ),
                  params: flow10_params,
                  headers: flow10_headers,
                )
              end
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
                  get(
                    auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                      "Sec-Fetch-Mode" => "navigate",
                      "Sec-Fetch-Dest" => "document",
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
                if flow11_target.host == ENV.fetch("PUBLIC_VISA_SERVICE_URL") &&
                    flow11_target.path == "/oidc/result"
                  complete_social_oidc_visa_result!(
                    target: flow11_target,
                    base_browser: @base_browser,
                    base_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
                    visa_host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
                  )
                  break
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
                    flow11_rt,
                    JitSecurityJwtRegistry.public_key_for(
                      flow11_issuer.id,
                      flow11_issuer.current_kid,
                    ),
                    true,
                    algorithms: ["ES384"],
                    verify_iss: true,
                    iss: "https://#{flow11_base_host}",
                    verify_aud: true,
                    aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
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

                      # Do not print the outer request or credentials on failure.
                      assert_equal [true, true, 200],
                                   [ActiveSupport::ExecutionContext.to_h
                                     .fetch(:controller).equal?(flow11_outer_controller),
                                    Actor.context.equal?(flow11_outer_actor), flow11_protocol_browser.response.status,]
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

                      # Do not print the outer request or credentials on failure.
                      assert_equal [true, true, 200],
                                   [ActiveSupport::ExecutionContext.to_h
                                     .fetch(:controller).equal?(flow11_outer_controller),
                                    Actor.context.equal?(flow11_outer_actor), flow11_protocol_browser.response.status,]
                      [flow11_protocol_browser.response.status, { "Content-Type" => "application/json" },
                       flow11_protocol_browser.response.body,]
                    end
                  end
                flow11_connection =
                  Faraday.new do |flow11_builder|
                    flow11_builder.request(:url_encoded)
                    flow11_builder.adapter(:test, flow11_transport)
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
                    get(flow11_callback_uri.request_uri, headers: flow11_base_headers)
                  end
                end

                assert_equal [true, true, true],
                             [response.redirect?,
                              cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                              cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
                flow11_transport.verify_stubbed_calls
              end
            end
          end
        end

        guard_url =
          if flow9_config.fetch(:normalized) == "google"
            auth_app_sign_up_guard_google_url(ri: "jp")
          else
            auth_app_sign_up_guard_apple_url(ri: "jp")
          end

        assert_redirected_to guard_url
        follow_redirect!

        @social_signup_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

        assert_predicate @social_signup_binding, :present?
        assert_redirected_to(
          (flow9_config
                    .fetch(:normalized) == "google") ? auth_app_sign_up_check_google_confirmation_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ) : auth_app_sign_up_check_apple_confirmation_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ),
        )
        follow_redirect!

        assert_response :ok
        assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
        assert_predicate inertia_props.fetch("confirm_label"), :present?
      end
      flow7_cycle = ClientSignUpFlow.order(:id).last

      begin
        flow12_config = flow7_config
        flow12_cycle = flow7_cycle
        patch(
          ((flow12_config.fetch(:normalized) == "google") ? auth_app_sign_up_check_google_confirmation_url(
            ri: "jp",
            fb: @social_signup_binding,
          ) : auth_app_sign_up_check_apple_confirmation_url(
            ri: "jp",
            fb: @social_signup_binding,
          )),
          params: { confirm_new_social_identity: "1", checkpoint_version: flow12_cycle.checkpoint_version },
          headers: browser_headers.merge(@callback_headers),
        )

        @social_signup_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

        assert_redirected_to(
          (flow12_config
                    .fetch(:normalized) == "google") ? auth_app_sign_up_check_google_birthdate_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ) : auth_app_sign_up_check_apple_birthdate_url(
                      ri: "jp",
                      fb: @social_signup_binding,
                    ),
        )
        follow_redirect!

        assert_no_difference("Client.count") do
          assert_difference("#{flow12_config.fetch(:model)}.count", 1) do
            patch(
              ((flow12_config.fetch(:normalized) == "google") ? auth_app_sign_up_check_google_birthdate_url(
                ri: "jp",
                fb: @social_signup_binding,
              ) : auth_app_sign_up_check_apple_birthdate_url(
                ri: "jp",
                fb: @social_signup_binding,
              )),
              params: {
                requirement: "birthdate",
                birthdate: "2000-02-03",
                checkpoint_version: flow12_cycle.reload.checkpoint_version,
              },
              headers: browser_headers.merge(@callback_headers),
            )
          end
        end

        assert_response :redirect
        # WU-05f: finalization hands the browser to the canonical Sign In flow; it never
        # re-enters the removed Base social sign-up completion transport.
        assert_equal "/sign/in/check", URI.parse(response.location).path

        assert_no_difference("Client.count") do
          assert_no_difference("#{flow12_config.fetch(:model)}.count") do
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
                  flow13_form["action"], params: flow13_fields, headers: {
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
                  surface: "app", transaction_id: flow13_ceremony.authorization_transaction_ref,
                )
                get(
                  auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Sec-Fetch-Mode" => "navigate",
                    "Sec-Fetch-Dest" => "document",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                flow13_target = URI.parse(response.location)
                flow13_principal = Client.find_by!(public_id: flow13_parent.reload.actor_ref)
                BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow13_principal)
              end
              if flow13_target.host == ENV.fetch("PUBLIC_VISA_SERVICE_URL") &&
                  flow13_target.path == "/oidc/result"
                complete_social_oidc_visa_result!(
                  target: flow13_target,
                  base_browser: @base_browser,
                  base_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
                  visa_host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
                )
                break
              end
              break unless flow13_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                %w(/social/authentication/completion /oauth/authorize).include?(flow13_target.path)

              flow13_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
              flow13_base_cookie = @base_browser.cookies.to_hash.map { |flow13_name, flow13_value|
                "#{flow13_name}=#{Rack::Utils.escape(flow13_value)}"
              }.join("; ")
              flow13_base_headers = { "Origin" => "https://#{flow13_base_host}",
                                      "Sec-Fetch-Site" => "same-origin",
                                      "Cookie" => flow13_base_cookie,
                                      "HTTP_COOKIE" => flow13_base_cookie, }
              host!(flow13_base_host)
              https!
              get(flow13_target.request_uri, headers: flow13_base_headers)
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
                get(URI.parse(response.location).request_uri, headers: flow13_base_headers)
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

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow13_outer_controller),
                                  Actor.context.equal?(flow13_outer_actor), flow13_protocol_browser.response.status,]
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

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow13_outer_controller),
                                  Actor.context.equal?(flow13_outer_actor), flow13_protocol_browser.response.status,]
                    [flow13_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow13_protocol_browser.response.body,]
                  end
                end
              flow13_connection =
                Faraday.new do |flow13_builder|
                  flow13_builder.request(:url_encoded)
                  flow13_builder.adapter(:test, flow13_transport)
                end
              OutboundHttp::Connection.stub(
                :build, ->(**flow13_args) {
                  assert_equal flow13_base_host, flow13_args.fetch(:url).host
                  flow13_connection
                },
              ) do
                TestSupport::OutboundHttpGuard.allow do
                  get(flow13_callback_uri.request_uri, headers: flow13_base_headers)
                end
              end

              assert_equal [true, true, true],
                           [response.redirect?,
                            cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                            cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
              flow13_transport.verify_stubbed_calls
            end
          end
        end
      end

      flow7_identity = flow7_config.fetch(:model).find_by!(
        provider: flow7_config.fetch(:provider),
        subject: flow7_uid,
      )
      flow7_user = Client.find(flow7_identity.client_id)

      assert_response :redirect
      assert_equal "2000-02-03", flow7_user.reload.birthdate
      assert ClientToken.exists?(user_id: flow7_user.id)

      assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, flow7_user.status_id
      assert_equal "active", flow7_identity.state
      assert_equal flow7_config.fetch(:provider), flow7_identity.provider
      assert_not_nil flow7_identity.last_authenticated_at
      assert_nil ClientEmail.find_by(user: flow7_user)
    end
  end

  test "Google sign in reuses existing social identity and refreshes credentials" do
    begin
      flow14_config = PROVIDERS.fetch(:google)
      flow14_uid = "#{flow14_config.fetch(:normalized)}_signin_#{SecureRandom.hex(4)}"
      flow14_user = create_social_client
      flow14_identity = create_social_identity(flow14_config, user: flow14_user, uid: flow14_uid)

      flow14_state =
        begin
          flow15_provider = flow14_config.fetch(:provider)
          flow15_intent = "login"
          flow15_user = nil
          flow15_entry = nil
          flow15_ri = "jp"
          flow15_rt = nil
          flow15_referer = nil
          unless flow15_intent.to_s == "link"
            @base_browser = open_session
            flow15_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow15_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            flow15_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow15_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow15_ri,
                pt: "/dashboard?ri=#{flow15_ri}",
              },
            )
            flow15_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow15_fields =
              flow15_form.css("input[name]").to_h { |flow15_input|
                [
                  flow15_input["name"],
                  flow15_input["value"],
                ]
              }
            @base_browser.post(
              flow15_form["action"], params: flow15_fields, headers: {
                "Origin" => "https://#{flow15_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow15_rt = follow_social_authorization_bootstrap!(
              base_browser: @base_browser,
              base_host: flow15_base_host,
              visa_host: flow15_visa_host,
              auth_host: flow15_auth_host,
            )
          end
          flow15_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow15_host)
          flow15_normalized_provider = SocialIdentifiable.normalize_provider(flow15_provider)
          flow15_continue_path =
            if flow15_intent.to_s == "link"
              ((if flow15_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow15_ri)
                else
                  auth_app_settings_apple_path(ri: flow15_ri)
                end))
            elsif flow15_entry.to_s == "sign_up"
              ((flow15_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ))
            else
              ((flow15_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ))
            end
          flow15_headers = social_callback_headers(flow15_host)
          flow15_headers["Referer"] = flow15_referer if flow15_referer.present?
          if flow15_user
            flow15_user_headers =
              as_user_headers(flow15_user, host: flow15_host)
            flow15_token = ClientToken.find_by(public_id: flow15_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow15_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow15_intent.to_s == "link" && flow15_token
            flow15_headers = flow15_headers.merge(flow15_user_headers)
          end
          if flow15_entry.to_s == "sign_up" && flow15_intent.to_s != "link"
            switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
            host!(flow15_host)
          end
          post(flow15_continue_path, headers: flow15_headers)
          social_auth_state_from_response
        end
      setup_mock_auth(flow14_config, uid: flow14_uid, token: "fresh_token")

      assert_no_difference("Client.count") do
        assert_no_difference("#{flow14_config.fetch(:model)}.count") do
          begin
            flow16_config = flow14_config
            flow16_params = { state: flow14_state }
            flow16_headers = browser_headers.merge(@callback_headers)
            if flow16_config.fetch(:provider) == "apple"
              get(
                auth_app_social_apple_callback_url(
                  provider: "apple",
                  ri: "jp",
                ), params: flow16_params, headers: flow16_headers,
              )
            else
              get(
                auth_app_social_google_callback_url(provider: flow16_config.fetch(:provider), ri: "jp"),
                params: flow16_params,
                headers: flow16_headers,
              )
            end
            1.times do
              if response.media_type == "text/html" && response.body.include?("social-completion-form")
                flow17_form = response.parsed_body.at_css("form#social-completion-form")
                flow17_fields =
                  flow17_form.css("input[name]").to_h { |flow17_input|
                    [
                      flow17_input["name"],
                      flow17_input["value"],
                    ]
                  }
                flow17_rails_cookie = Rails.application.config.session_options.fetch(:key)
                flow17_owner_cookie =
                  request.headers["Cookie"].to_s.split("; ")
                    .reject { |flow17_pair| flow17_pair.start_with?("#{flow17_rails_cookie}=") }
                flow17_owner_cookie << "#{flow17_rails_cookie}=#{Rack::Utils.escape(
                  response
                                    .cookies.fetch(flow17_rails_cookie),
                )}"
                post(
                  flow17_form["action"], params: flow17_fields, headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Cookie" => flow17_owner_cookie.join("; "),
                    "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                break
              end
              break unless response.redirect? && @base_browser

              flow17_target = URI.parse(response.location)
              if flow17_target.path == "/sign/in/check"
                flow17_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
                flow17_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow17_sid_cookie])
                flow17_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
                  surface: "app", transaction_id: flow17_ceremony.authorization_transaction_ref,
                )
                get(
                  auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Sec-Fetch-Mode" => "navigate",
                    "Sec-Fetch-Dest" => "document",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                flow17_target = URI.parse(response.location)
                flow17_principal = Client.find_by!(public_id: flow17_parent.reload.actor_ref)
                BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow17_principal)
              end
              if flow17_target.host == ENV.fetch("PUBLIC_VISA_SERVICE_URL") &&
                  flow17_target.path == "/oidc/result"
                complete_social_oidc_visa_result!(
                  target: flow17_target,
                  base_browser: @base_browser,
                  base_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
                  visa_host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
                )
                break
              end
              break unless flow17_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                %w(/social/authentication/completion /oauth/authorize).include?(flow17_target.path)

              flow17_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
              flow17_base_cookie = @base_browser.cookies.to_hash.map { |flow17_name, flow17_value|
                "#{flow17_name}=#{Rack::Utils.escape(flow17_value)}"
              }.join("; ")
              flow17_base_headers = { "Origin" => "https://#{flow17_base_host}",
                                      "Sec-Fetch-Site" => "same-origin",
                                      "Cookie" => flow17_base_cookie,
                                      "HTTP_COOKIE" => flow17_base_cookie, }
              host!(flow17_base_host)
              https!
              get(flow17_target.request_uri, headers: flow17_base_headers)
              flow17_form = response.parsed_body.at_css("form")
              flow17_fields =
                flow17_form.css("input[name]").to_h { |flow17_input|
                  [
                    flow17_input["name"],
                    flow17_input["value"],
                  ]
                }
              post(
                flow17_form["action"],
                params: flow17_fields,
                headers: flow17_base_headers,
              )
              if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
                get(URI.parse(response.location).request_uri, headers: flow17_base_headers)
                flow17_form = response.parsed_body.at_css("form")
                flow17_fields =
                  flow17_form.css("input[name]").to_h { |flow17_input|
                    [
                      flow17_input["name"],
                      flow17_input["value"],
                    ]
                  }
                post(
                  flow17_form["action"],
                  params: flow17_fields,
                  headers: flow17_base_headers,
                )
              end
              break unless response.redirect?
              # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
              break unless URI.parse(response.location).path == "/oidc/callback" ||
                URI.parse(response.location).host ==
                  URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

              flow17_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
              flow17_callback_uri = URI.parse(response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow17_callback_uri.host == flow17_base_host
                flow17_rt = Rack::Utils.parse_query(flow17_callback_uri.query).fetch("rt")
                flow17_payload, = JWT.decode(
                  flow17_rt, JitSecurityJwtRegistry.public_key_for(
                    flow17_issuer.id,
                    flow17_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow17_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow17_callback_uri = URI.parse(flow17_payload.fetch("url"))
              end
              flow17_protocol_browser = open_session
              flow17_protocol_browser.host!(flow17_base_host)
              flow17_protocol_browser.https!
              # Substitute network transport only: the token and UserInfo requests still run
              # through their real public controllers, including PKCE and client authentication.
              flow17_transport =
                Faraday::Adapter::Test::Stubs.new do |flow17_stub|
                  flow17_stub.post(/.*/) do |flow17_env|
                    # The nested Rack executor must not complete the in-flight callback.
                    flow17_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow17_outer_actor = Actor.context
                    flow17_executor_key = Rails.application.executor.active_key
                    flow17_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow17_executor_key)
                    begin
                      flow17_protocol_browser.host!(flow17_env.url.authority)
                      flow17_protocol_browser.https!(flow17_env.url.scheme == "https")
                      flow17_protocol_browser.post(
                        flow17_env.url.request_uri,
                        params: Rack::Utils.parse_query(flow17_env.body),
                        headers: { "Accept" => "application/json" },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow17_executor_key] =
                        flow17_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow17_outer_controller),
                                  Actor.context.equal?(flow17_outer_actor), flow17_protocol_browser.response.status,]
                    [flow17_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow17_protocol_browser.response.body,]
                  end
                  flow17_stub.get(/.*/) do |flow17_env|
                    flow17_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow17_outer_actor = Actor.context
                    flow17_executor_key = Rails.application.executor.active_key
                    flow17_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow17_executor_key)
                    begin
                      flow17_protocol_browser.host!(flow17_env.url.authority)
                      flow17_protocol_browser.https!(flow17_env.url.scheme == "https")
                      flow17_protocol_browser.get(
                        flow17_env.url.request_uri, headers: {
                          "Authorization" => flow17_env.request_headers.fetch("Authorization"),
                          "Accept" => "application/json",
                        },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow17_executor_key] =
                        flow17_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow17_outer_controller),
                                  Actor.context.equal?(flow17_outer_actor), flow17_protocol_browser.response.status,]
                    [flow17_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow17_protocol_browser.response.body,]
                  end
                end
              flow17_connection =
                Faraday.new do |flow17_builder|
                  flow17_builder.request(:url_encoded)
                  flow17_builder.adapter(:test, flow17_transport)
                end
              OutboundHttp::Connection.stub(
                :build, ->(**flow17_args) {
                  assert_equal flow17_base_host, flow17_args.fetch(:url).host
                  flow17_connection
                },
              ) do
                TestSupport::OutboundHttpGuard.allow do
                  get(flow17_callback_uri.request_uri, headers: flow17_base_headers)
                end
              end

              assert_equal [true, true, true],
                           [response.redirect?,
                            cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                            cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
              flow17_transport.verify_stubbed_calls
            end
          end
        end
      end

      # WU-43/D-151 carries the RP return target as a path only. Region is not embedded in the
      # signed target query, so the callback returns to the normalized dashboard path.
      assert_redirected_to "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}/dashboard"
      flow14_identity.reload

      assert_equal flow14_user.id, flow14_identity.user_id
      assert_not_nil flow14_identity.last_authenticated_at
    end
  end

  test "Apple sign in reuses existing social identity and refreshes credentials" do
    begin
      flow18_config = PROVIDERS.fetch(:apple)
      flow18_uid = "#{flow18_config.fetch(:normalized)}_signin_#{SecureRandom.hex(4)}"
      flow18_user = create_social_client
      flow18_identity = create_social_identity(flow18_config, user: flow18_user, uid: flow18_uid)

      flow18_state =
        begin
          flow19_provider = flow18_config.fetch(:provider)
          flow19_intent = "login"
          flow19_user = nil
          flow19_entry = nil
          flow19_ri = "jp"
          flow19_rt = nil
          flow19_referer = nil
          unless flow19_intent.to_s == "link"
            @base_browser = open_session
            flow19_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow19_visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
            flow19_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow19_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow19_ri,
                pt: "/dashboard?ri=#{flow19_ri}",
              },
            )
            flow19_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow19_fields =
              flow19_form.css("input[name]").to_h { |flow19_input|
                [
                  flow19_input["name"],
                  flow19_input["value"],
                ]
              }
            @base_browser.post(
              flow19_form["action"], params: flow19_fields, headers: {
                "Origin" => "https://#{flow19_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow19_rt = follow_social_authorization_bootstrap!(
              base_browser: @base_browser,
              base_host: flow19_base_host,
              visa_host: flow19_visa_host,
              auth_host: flow19_auth_host,
            )
          end
          flow19_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow19_host)
          flow19_normalized_provider = SocialIdentifiable.normalize_provider(flow19_provider)
          flow19_continue_path =
            if flow19_intent.to_s == "link"
              ((if flow19_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow19_ri)
                else
                  auth_app_settings_apple_path(ri: flow19_ri)
                end))
            elsif flow19_entry.to_s == "sign_up"
              ((flow19_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow19_ri,
                rt: flow19_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow19_ri,
                rt: flow19_rt,
              ))
            else
              ((flow19_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow19_ri,
                rt: flow19_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow19_ri,
                rt: flow19_rt,
              ))
            end
          flow19_headers = social_callback_headers(flow19_host)
          flow19_headers["Referer"] = flow19_referer if flow19_referer.present?
          if flow19_user
            flow19_user_headers =
              as_user_headers(flow19_user, host: flow19_host)
            flow19_token = ClientToken.find_by(public_id: flow19_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow19_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow19_intent.to_s == "link" && flow19_token
            flow19_headers = flow19_headers.merge(flow19_user_headers)
          end
          if flow19_entry.to_s == "sign_up" && flow19_intent.to_s != "link"
            switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
            host!(flow19_host)
          end
          post(flow19_continue_path, headers: flow19_headers)
          social_auth_state_from_response
        end
      setup_mock_auth(flow18_config, uid: flow18_uid, token: "fresh_token")

      assert_no_difference("Client.count") do
        assert_no_difference("#{flow18_config.fetch(:model)}.count") do
          begin
            flow20_config = flow18_config
            flow20_params = { state: flow18_state }
            flow20_headers = browser_headers.merge(@callback_headers)
            if flow20_config.fetch(:provider) == "apple"
              get(
                auth_app_social_apple_callback_url(
                  provider: "apple",
                  ri: "jp",
                ), params: flow20_params, headers: flow20_headers,
              )
            else
              get(
                auth_app_social_google_callback_url(provider: flow20_config.fetch(:provider), ri: "jp"),
                params: flow20_params,
                headers: flow20_headers,
              )
            end
            1.times do
              if response.media_type == "text/html" && response.body.include?("social-completion-form")
                flow21_form = response.parsed_body.at_css("form#social-completion-form")
                flow21_fields =
                  flow21_form.css("input[name]").to_h { |flow21_input|
                    [
                      flow21_input["name"],
                      flow21_input["value"],
                    ]
                  }
                flow21_rails_cookie = Rails.application.config.session_options.fetch(:key)
                flow21_owner_cookie =
                  request.headers["Cookie"].to_s.split("; ")
                    .reject { |flow21_pair| flow21_pair.start_with?("#{flow21_rails_cookie}=") }
                flow21_owner_cookie << "#{flow21_rails_cookie}=#{Rack::Utils.escape(
                  response
                                    .cookies.fetch(flow21_rails_cookie),
                )}"
                post(
                  flow21_form["action"], params: flow21_fields, headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Cookie" => flow21_owner_cookie.join("; "),
                    "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                break
              end
              break unless response.redirect? && @base_browser

              flow21_target = URI.parse(response.location)
              if flow21_target.path == "/sign/in/check"
                flow21_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
                flow21_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow21_sid_cookie])
                flow21_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
                  surface: "app", transaction_id: flow21_ceremony.authorization_transaction_ref,
                )
                get(
                  auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Sec-Fetch-Mode" => "navigate",
                    "Sec-Fetch-Dest" => "document",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                flow21_target = URI.parse(response.location)
                flow21_principal = Client.find_by!(public_id: flow21_parent.reload.actor_ref)
                BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow21_principal)
              end
              if flow21_target.host == ENV.fetch("PUBLIC_VISA_SERVICE_URL") &&
                  flow21_target.path == "/oidc/result"
                complete_social_oidc_visa_result!(
                  target: flow21_target,
                  base_browser: @base_browser,
                  base_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
                  visa_host: ENV.fetch("PUBLIC_VISA_SERVICE_URL"),
                )
                break
              end
              break unless flow21_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                %w(/social/authentication/completion /oauth/authorize).include?(flow21_target.path)

              flow21_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
              flow21_base_cookie = @base_browser.cookies.to_hash.map { |flow21_name, flow21_value|
                "#{flow21_name}=#{Rack::Utils.escape(flow21_value)}"
              }.join("; ")
              flow21_base_headers = { "Origin" => "https://#{flow21_base_host}",
                                      "Sec-Fetch-Site" => "same-origin",
                                      "Cookie" => flow21_base_cookie,
                                      "HTTP_COOKIE" => flow21_base_cookie, }
              host!(flow21_base_host)
              https!
              get(flow21_target.request_uri, headers: flow21_base_headers)
              flow21_form = response.parsed_body.at_css("form")
              flow21_fields =
                flow21_form.css("input[name]").to_h { |flow21_input|
                  [
                    flow21_input["name"],
                    flow21_input["value"],
                  ]
                }
              post(
                flow21_form["action"],
                params: flow21_fields,
                headers: flow21_base_headers,
              )
              if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
                get(URI.parse(response.location).request_uri, headers: flow21_base_headers)
                flow21_form = response.parsed_body.at_css("form")
                flow21_fields =
                  flow21_form.css("input[name]").to_h { |flow21_input|
                    [
                      flow21_input["name"],
                      flow21_input["value"],
                    ]
                  }
                post(
                  flow21_form["action"],
                  params: flow21_fields,
                  headers: flow21_base_headers,
                )
              end
              break unless response.redirect?
              # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
              break unless URI.parse(response.location).path == "/oidc/callback" ||
                URI.parse(response.location).host ==
                  URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

              flow21_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
              flow21_callback_uri = URI.parse(response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow21_callback_uri.host == flow21_base_host
                flow21_rt = Rack::Utils.parse_query(flow21_callback_uri.query).fetch("rt")
                flow21_payload, = JWT.decode(
                  flow21_rt, JitSecurityJwtRegistry.public_key_for(
                    flow21_issuer.id,
                    flow21_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow21_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow21_callback_uri = URI.parse(flow21_payload.fetch("url"))
              end
              flow21_protocol_browser = open_session
              flow21_protocol_browser.host!(flow21_base_host)
              flow21_protocol_browser.https!
              # Substitute network transport only: the token and UserInfo requests still run
              # through their real public controllers, including PKCE and client authentication.
              flow21_transport =
                Faraday::Adapter::Test::Stubs.new do |flow21_stub|
                  flow21_stub.post(/.*/) do |flow21_env|
                    # The nested Rack executor must not complete the in-flight callback.
                    flow21_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow21_outer_actor = Actor.context
                    flow21_executor_key = Rails.application.executor.active_key
                    flow21_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow21_executor_key)
                    begin
                      flow21_protocol_browser.host!(flow21_env.url.authority)
                      flow21_protocol_browser.https!(flow21_env.url.scheme == "https")
                      flow21_protocol_browser.post(
                        flow21_env.url.request_uri,
                        params: Rack::Utils.parse_query(flow21_env.body),
                        headers: { "Accept" => "application/json" },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow21_executor_key] =
                        flow21_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow21_outer_controller),
                                  Actor.context.equal?(flow21_outer_actor), flow21_protocol_browser.response.status,]
                    [flow21_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow21_protocol_browser.response.body,]
                  end
                  flow21_stub.get(/.*/) do |flow21_env|
                    flow21_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow21_outer_actor = Actor.context
                    flow21_executor_key = Rails.application.executor.active_key
                    flow21_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow21_executor_key)
                    begin
                      flow21_protocol_browser.host!(flow21_env.url.authority)
                      flow21_protocol_browser.https!(flow21_env.url.scheme == "https")
                      flow21_protocol_browser.get(
                        flow21_env.url.request_uri, headers: {
                          "Authorization" => flow21_env.request_headers.fetch("Authorization"),
                          "Accept" => "application/json",
                        },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow21_executor_key] =
                        flow21_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow21_outer_controller),
                                  Actor.context.equal?(flow21_outer_actor), flow21_protocol_browser.response.status,]
                    [flow21_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow21_protocol_browser.response.body,]
                  end
                end
              flow21_connection =
                Faraday.new do |flow21_builder|
                  flow21_builder.request(:url_encoded)
                  flow21_builder.adapter(:test, flow21_transport)
                end
              OutboundHttp::Connection.stub(
                :build, ->(**flow21_args) {
                  assert_equal flow21_base_host, flow21_args.fetch(:url).host
                  flow21_connection
                },
              ) do
                TestSupport::OutboundHttpGuard.allow do
                  get(flow21_callback_uri.request_uri, headers: flow21_base_headers)
                end
              end

              assert_equal [true, true, true],
                           [response.redirect?,
                            cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                            cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
              flow21_transport.verify_stubbed_calls
            end
          end
        end
      end

      # WU-43/D-151 carries the RP return target as a path only. Region is not embedded in the
      # signed target query, so the callback returns to the normalized dashboard path.
      assert_redirected_to "https://#{ENV.fetch("PUBLIC_BASE_SERVICE_URL")}/dashboard"
      flow18_identity.reload

      assert_equal flow18_user.id, flow18_identity.user_id
      assert_not_nil flow18_identity.last_authenticated_at
    end
  end

  test "Google settings link creates identity for the signed-in client only" do
    begin
      fv5037 = PROVIDERS.fetch(:google)
      fv5036 = "#{fv5037.fetch(:normalized)}_link_#{SecureRandom.hex(4)}"
      fv5035 = create_social_client

      fv5038 =
        begin
          lf0_provider = fv5037.fetch(:provider)
          lf0_user = fv5035
          lf0_ri = "jp"
          lf0_host = @host || configured_host(:auth_service)
          host!(lf0_host) if respond_to?(:host!)

          lf0_user_headers =
            begin
              rr0_headers = as_user_headers(lf0_user, host: lf0_host)
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
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rr0_family}-#{rr0_surface}"
                  end
                rr0_token = ClientToken.find_by!(public_id: rr0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rr0_client = OidcClientRegistry.find!(rr0_client_id)
                rr0_key = [rr0_client.client_id, rr0_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rr0_key] && rr0_token.currently_usable? &&
                    !(rr0_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rr0_token.device_session_id,
                      oidc_client_id: rr0_client.client_id,
                      revoked_at: nil,
                    ))
                  rr0_token.rotate_refresh_token! unless rr0_token.device_session_record.current_refresh_token_id
                  rr0_now = Time.current
                  rr0_session = OpAppGrant.create!(
                    authentication_epoch: 0,
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
          lf0_session_public_id = lf0_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
          lf0_token = ClientToken.find_by(public_id: lf0_session_public_id)
          lf0_session_ref = lf0_token&.device_session_record&.public_id.presence || lf0_session_public_id
          mark_token_step_up_satisfied_for_test(
            lf0_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if lf0_token

          lf0_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
            surface: "app",
            actor_ref: lf0_user.public_id,
            session_ref: lf0_session_ref,
            operation: "link",
            provider: lf0_provider,
          )

          lf0_normalized_provider = SocialIdentifiable.normalize_provider(lf0_provider)
          lf0_continue_path = public_send(
            :"auth_app_settings_#{lf0_normalized_provider}_path",
            ri: lf0_ri,
            social_ceremony_grant: lf0_issuance.grant,
          )

          lf0_headers = social_callback_headers(lf0_host).merge(lf0_user_headers)
          post(lf0_continue_path, headers: lf0_headers)
          lf0_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
          lf0_user_headers["Cookie"] = [
            lf0_user_headers.fetch("Cookie"),
            "#{lf0_rails_cookie_key}=#{Rack::Utils.escape(response.cookies.fetch(lf0_rails_cookie_key))}",
          ].join("; ")
          lf0_user_headers["HTTP_COOKIE"] = lf0_user_headers.fetch("Cookie")
          lf0_state = social_auth_state_from_response

          assert_predicate(
            lf0_state,
            :present?,
            "expected social auth state from response status=#{response.status} " \
            "location=#{response.location.inspect} " \
            "flash=#{flash.to_hash.inspect} body=#{response.body.to_s.first(200).inspect}",
          )

          Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
            state: lf0_state,
            user_headers: lf0_user_headers,
            session_public_id: lf0_session_ref,
          )
        end
      setup_mock_auth(fv5037, uid: fv5036, token: "linked_token")

      # The sign callback creates the social identity directly for settings link.
      assert_no_difference("Client.count") do
        assert_difference("#{fv5037.fetch(:model)}.count", 1) do
          begin
            flow22_config = fv5037
            flow22_params = { state: fv5038.state }
            flow22_headers = @callback_headers.merge(fv5038.user_headers)
            if flow22_config.fetch(:provider) == "apple"
              get(
                auth_app_social_apple_callback_url(
                  provider: "apple",
                  ri: "jp",
                ), params: flow22_params, headers: flow22_headers,
              )
            else
              get(
                auth_app_social_google_callback_url(provider: flow22_config.fetch(:provider), ri: "jp"),
                params: flow22_params,
                headers: flow22_headers,
              )
            end
            1.times do
              if response.media_type == "text/html" && response.body.include?("social-completion-form")
                flow23_form = response.parsed_body.at_css("form#social-completion-form")
                flow23_fields =
                  flow23_form.css("input[name]").to_h { |flow23_input|
                    [
                      flow23_input["name"],
                      flow23_input["value"],
                    ]
                  }
                flow23_rails_cookie = Rails.application.config.session_options.fetch(:key)
                flow23_owner_cookie =
                  request.headers["Cookie"].to_s.split("; ")
                    .reject { |flow23_pair| flow23_pair.start_with?("#{flow23_rails_cookie}=") }
                flow23_owner_cookie << "#{flow23_rails_cookie}=#{Rack::Utils.escape(
                  response
                                    .cookies.fetch(flow23_rails_cookie),
                )}"
                post(
                  flow23_form["action"], params: flow23_fields, headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Cookie" => flow23_owner_cookie.join("; "),
                    "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                break
              end
              break unless response.redirect? && @base_browser

              flow23_target = URI.parse(response.location)
              if flow23_target.path == "/sign/in/check"
                flow23_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
                flow23_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow23_sid_cookie])
                flow23_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
                  surface: "app", transaction_id: flow23_ceremony.authorization_transaction_ref,
                )
                get(
                  auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Sec-Fetch-Mode" => "navigate",
                    "Sec-Fetch-Dest" => "document",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                flow23_target = URI.parse(response.location)
                flow23_principal = Client.find_by!(public_id: flow23_parent.reload.actor_ref)
                BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow23_principal)
              end
              break unless flow23_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                %w(/social/authentication/completion /oauth/authorize).include?(flow23_target.path)

              flow23_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
              flow23_base_cookie = @base_browser.cookies.to_hash.map { |flow23_name, flow23_value|
                "#{flow23_name}=#{Rack::Utils.escape(flow23_value)}"
              }.join("; ")
              flow23_base_headers = { "Origin" => "https://#{flow23_base_host}",
                                      "Sec-Fetch-Site" => "same-origin",
                                      "Cookie" => flow23_base_cookie,
                                      "HTTP_COOKIE" => flow23_base_cookie, }
              host!(flow23_base_host)
              https!
              get(flow23_target.request_uri, headers: flow23_base_headers)
              flow23_form = response.parsed_body.at_css("form")
              flow23_fields =
                flow23_form.css("input[name]").to_h { |flow23_input|
                  [
                    flow23_input["name"],
                    flow23_input["value"],
                  ]
                }
              post(
                flow23_form["action"],
                params: flow23_fields,
                headers: flow23_base_headers,
              )
              if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
                get(URI.parse(response.location).request_uri, headers: flow23_base_headers)
                flow23_form = response.parsed_body.at_css("form")
                flow23_fields =
                  flow23_form.css("input[name]").to_h { |flow23_input|
                    [
                      flow23_input["name"],
                      flow23_input["value"],
                    ]
                  }
                post(
                  flow23_form["action"],
                  params: flow23_fields,
                  headers: flow23_base_headers,
                )
              end
              break unless response.redirect?
              # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
              break unless URI.parse(response.location).path == "/oidc/callback" ||
                URI.parse(response.location).host ==
                  URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

              flow23_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
              flow23_callback_uri = URI.parse(response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow23_callback_uri.host == flow23_base_host
                flow23_rt = Rack::Utils.parse_query(flow23_callback_uri.query).fetch("rt")
                flow23_payload, = JWT.decode(
                  flow23_rt, JitSecurityJwtRegistry.public_key_for(
                    flow23_issuer.id,
                    flow23_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow23_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow23_callback_uri = URI.parse(flow23_payload.fetch("url"))
              end
              flow23_protocol_browser = open_session
              flow23_protocol_browser.host!(flow23_base_host)
              flow23_protocol_browser.https!
              # Substitute network transport only: the token and UserInfo requests still run
              # through their real public controllers, including PKCE and client authentication.
              flow23_transport =
                Faraday::Adapter::Test::Stubs.new do |flow23_stub|
                  flow23_stub.post(/.*/) do |flow23_env|
                    # The nested Rack executor must not complete the in-flight callback.
                    flow23_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow23_outer_actor = Actor.context
                    flow23_executor_key = Rails.application.executor.active_key
                    flow23_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow23_executor_key)
                    begin
                      flow23_protocol_browser.host!(flow23_env.url.authority)
                      flow23_protocol_browser.https!(flow23_env.url.scheme == "https")
                      flow23_protocol_browser.post(
                        flow23_env.url.request_uri,
                        params: Rack::Utils.parse_query(flow23_env.body),
                        headers: { "Accept" => "application/json" },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow23_executor_key] =
                        flow23_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow23_outer_controller),
                                  Actor.context.equal?(flow23_outer_actor), flow23_protocol_browser.response.status,]
                    [flow23_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow23_protocol_browser.response.body,]
                  end
                  flow23_stub.get(/.*/) do |flow23_env|
                    flow23_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow23_outer_actor = Actor.context
                    flow23_executor_key = Rails.application.executor.active_key
                    flow23_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow23_executor_key)
                    begin
                      flow23_protocol_browser.host!(flow23_env.url.authority)
                      flow23_protocol_browser.https!(flow23_env.url.scheme == "https")
                      flow23_protocol_browser.get(
                        flow23_env.url.request_uri, headers: {
                          "Authorization" => flow23_env.request_headers.fetch("Authorization"),
                          "Accept" => "application/json",
                        },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow23_executor_key] =
                        flow23_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow23_outer_controller),
                                  Actor.context.equal?(flow23_outer_actor), flow23_protocol_browser.response.status,]
                    [flow23_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow23_protocol_browser.response.body,]
                  end
                end
              flow23_connection =
                Faraday.new do |flow23_builder|
                  flow23_builder.request(:url_encoded)
                  flow23_builder.adapter(:test, flow23_transport)
                end
              OutboundHttp::Connection.stub(
                :build, ->(**flow23_args) {
                  assert_equal flow23_base_host, flow23_args.fetch(:url).host
                  flow23_connection
                },
              ) do
                TestSupport::OutboundHttpGuard.allow do
                  get(flow23_callback_uri.request_uri, headers: flow23_base_headers)
                end
              end

              assert_equal [true, true, true],
                           [response.redirect?,
                            cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                            cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
              flow23_transport.verify_stubbed_calls
            end
          end
        end
      end

      assert_redirected_to auth_app_settings_path(ri: "jp")
      fv5034 = fv5037.fetch(:model).find_by!(
        provider: fv5037.fetch(:provider),
        subject: fv5036,
      )

      assert_equal fv5035.id, fv5034.user_id
      assert_equal "active", fv5034.state
      assert_not_nil fv5034.last_authenticated_at
    end
  end

  test "Apple settings link creates identity for the signed-in client only" do
    begin
      fv5032 = PROVIDERS.fetch(:apple)
      fv5031 = "#{fv5032.fetch(:normalized)}_link_#{SecureRandom.hex(4)}"
      fv5030 = create_social_client

      fv5033 =
        begin
          lf1_provider = fv5032.fetch(:provider)
          lf1_user = fv5030
          lf1_ri = "jp"
          lf1_host = @host || configured_host(:auth_service)
          host!(lf1_host) if respond_to?(:host!)

          lf1_user_headers =
            begin
              rr1_headers = as_user_headers(lf1_user, host: lf1_host)
              rr1_host = rr1_headers["Host"]
              rr1_route =
                begin
                  Rails.application.routes.recognize_path("https://#{rr1_host}/") if rr1_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              rr1_family, rr1_surface = rr1_route&.fetch(:controller)&.split("/")
              if %w(base warp core edit).include?(rr1_family) && rr1_surface == "app"
                rr1_client_id =
                  case rr1_family
                  when "base" then "base-#{rr1_surface}-ww"
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{rr1_family}-#{rr1_surface}"
                  end
                rr1_token = ClientToken.find_by!(public_id: rr1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                rr1_client = OidcClientRegistry.find!(rr1_client_id)
                rr1_key = [rr1_client.client_id, rr1_token.public_id]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[rr1_key] && rr1_token.currently_usable? &&
                    !(rr1_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: rr1_token.device_session_id,
                      oidc_client_id: rr1_client.client_id,
                      revoked_at: nil,
                    ))
                  rr1_token.rotate_refresh_token! unless rr1_token.device_session_record.current_refresh_token_id
                  rr1_now = Time.current
                  rr1_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: rr1_token,
                    oidc_client_id: rr1_client.client_id,
                    oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid,
                    oidc_nonce: SecureRandom.hex(16),
                    oidc_auth_time: rr1_now,
                    refresh_token_expires_at: rr1_now + 10.minutes,
                  )
                  rr1_access = AuthenticationTokenService.encode(
                    rr1_token.actor_record,
                    host: rr1_host,
                    resource_type: "client",
                    session_public_id: rr1_token.public_id,
                    base_session_public_id: rr1_token.public_id,
                    oidc_sid: rr1_session.public_id,
                    oidc_jti: rr1_session.oidc_jti,
                    expires_at: rr1_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(rr1_client),
                    audiences: [rr1_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rr1_client),
                    subject: OidcSubject.for(
                      rr1_token.actor_record,
                      resource_type: "client",
                    ),
                    client_id: rr1_client.client_id,
                  )
                  @base_browser_rp_credentials[rr1_key] =
                    [rr1_access, rr1_session.issue_refresh_token!]
                end
                if @base_browser_rp_credentials[rr1_key]
                  rr1_access, rr1_refresh = @base_browser_rp_credentials.fetch(rr1_key)
                  rr1_cookie = [
                    rr1_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rr1_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rr1_refresh)}",
                  ].join("; ")
                  rr1_headers = rr1_headers.merge(
                    "Cookie" => rr1_cookie,
                    "HTTP_COOKIE" => rr1_cookie,
                  )
                end
              end
              rr1_headers
            end
          lf1_session_public_id = lf1_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
          lf1_token = ClientToken.find_by(public_id: lf1_session_public_id)
          lf1_session_ref = lf1_token&.device_session_record&.public_id.presence || lf1_session_public_id
          mark_token_step_up_satisfied_for_test(
            lf1_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if lf1_token

          lf1_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
            surface: "app",
            actor_ref: lf1_user.public_id,
            session_ref: lf1_session_ref,
            operation: "link",
            provider: lf1_provider,
          )

          lf1_normalized_provider = SocialIdentifiable.normalize_provider(lf1_provider)
          lf1_continue_path = public_send(
            :"auth_app_settings_#{lf1_normalized_provider}_path",
            ri: lf1_ri,
            social_ceremony_grant: lf1_issuance.grant,
          )

          lf1_headers = social_callback_headers(lf1_host).merge(lf1_user_headers)
          post(lf1_continue_path, headers: lf1_headers)
          lf1_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
          lf1_user_headers["Cookie"] = [
            lf1_user_headers.fetch("Cookie"),
            "#{lf1_rails_cookie_key}=#{Rack::Utils.escape(response.cookies.fetch(lf1_rails_cookie_key))}",
          ].join("; ")
          lf1_user_headers["HTTP_COOKIE"] = lf1_user_headers.fetch("Cookie")
          lf1_state = social_auth_state_from_response

          assert_predicate(
            lf1_state,
            :present?,
            "expected social auth state from response status=#{response.status} " \
            "location=#{response.location.inspect} " \
            "flash=#{flash.to_hash.inspect} body=#{response.body.to_s.first(200).inspect}",
          )

          Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
            state: lf1_state,
            user_headers: lf1_user_headers,
            session_public_id: lf1_session_ref,
          )
        end
      setup_mock_auth(fv5032, uid: fv5031, token: "linked_token")

      # The sign callback creates the social identity directly for settings link.
      assert_no_difference("Client.count") do
        assert_difference("#{fv5032.fetch(:model)}.count", 1) do
          begin
            flow24_config = fv5032
            flow24_params = { state: fv5033.state }
            flow24_headers = @callback_headers.merge(fv5033.user_headers)
            if flow24_config.fetch(:provider) == "apple"
              get(
                auth_app_social_apple_callback_url(
                  provider: "apple",
                  ri: "jp",
                ), params: flow24_params, headers: flow24_headers,
              )
            else
              get(
                auth_app_social_google_callback_url(provider: flow24_config.fetch(:provider), ri: "jp"),
                params: flow24_params,
                headers: flow24_headers,
              )
            end
            1.times do
              if response.media_type == "text/html" && response.body.include?("social-completion-form")
                flow25_form = response.parsed_body.at_css("form#social-completion-form")
                flow25_fields =
                  flow25_form.css("input[name]").to_h { |flow25_input|
                    [
                      flow25_input["name"],
                      flow25_input["value"],
                    ]
                  }
                flow25_rails_cookie = Rails.application.config.session_options.fetch(:key)
                flow25_owner_cookie =
                  request.headers["Cookie"].to_s.split("; ")
                    .reject { |flow25_pair| flow25_pair.start_with?("#{flow25_rails_cookie}=") }
                flow25_owner_cookie << "#{flow25_rails_cookie}=#{Rack::Utils.escape(
                  response
                                    .cookies.fetch(flow25_rails_cookie),
                )}"
                post(
                  flow25_form["action"], params: flow25_fields, headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Cookie" => flow25_owner_cookie.join("; "),
                    "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                break
              end
              break unless response.redirect? && @base_browser

              flow25_target = URI.parse(response.location)
              if flow25_target.path == "/sign/in/check"
                flow25_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
                flow25_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow25_sid_cookie])
                flow25_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
                  surface: "app", transaction_id: flow25_ceremony.authorization_transaction_ref,
                )
                get(
                  auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                    "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                    "Sec-Fetch-Mode" => "navigate",
                    "Sec-Fetch-Dest" => "document",
                    "Sec-Fetch-Site" => "same-origin",
                  },
                )
                flow25_target = URI.parse(response.location)
                flow25_principal = Client.find_by!(public_id: flow25_parent.reload.actor_ref)
                BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow25_principal)
              end
              break unless flow25_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
                %w(/social/authentication/completion /oauth/authorize).include?(flow25_target.path)

              flow25_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
              flow25_base_cookie = @base_browser.cookies.to_hash.map { |flow25_name, flow25_value|
                "#{flow25_name}=#{Rack::Utils.escape(flow25_value)}"
              }.join("; ")
              flow25_base_headers = { "Origin" => "https://#{flow25_base_host}",
                                      "Sec-Fetch-Site" => "same-origin",
                                      "Cookie" => flow25_base_cookie,
                                      "HTTP_COOKIE" => flow25_base_cookie, }
              host!(flow25_base_host)
              https!
              get(flow25_target.request_uri, headers: flow25_base_headers)
              flow25_form = response.parsed_body.at_css("form")
              flow25_fields =
                flow25_form.css("input[name]").to_h { |flow25_input|
                  [
                    flow25_input["name"],
                    flow25_input["value"],
                  ]
                }
              post(
                flow25_form["action"],
                params: flow25_fields,
                headers: flow25_base_headers,
              )
              if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
                get(URI.parse(response.location).request_uri, headers: flow25_base_headers)
                flow25_form = response.parsed_body.at_css("form")
                flow25_fields =
                  flow25_form.css("input[name]").to_h { |flow25_input|
                    [
                      flow25_input["name"],
                      flow25_input["value"],
                    ]
                  }
                post(
                  flow25_form["action"],
                  params: flow25_fields,
                  headers: flow25_base_headers,
                )
              end
              break unless response.redirect?
              # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
              break unless URI.parse(response.location).path == "/oidc/callback" ||
                URI.parse(response.location).host ==
                  URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

              flow25_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
              flow25_callback_uri = URI.parse(response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow25_callback_uri.host == flow25_base_host
                flow25_rt = Rack::Utils.parse_query(flow25_callback_uri.query).fetch("rt")
                flow25_payload, = JWT.decode(
                  flow25_rt, JitSecurityJwtRegistry.public_key_for(
                    flow25_issuer.id,
                    flow25_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow25_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow25_callback_uri = URI.parse(flow25_payload.fetch("url"))
              end
              flow25_protocol_browser = open_session
              flow25_protocol_browser.host!(flow25_base_host)
              flow25_protocol_browser.https!
              # Substitute network transport only: the token and UserInfo requests still run
              # through their real public controllers, including PKCE and client authentication.
              flow25_transport =
                Faraday::Adapter::Test::Stubs.new do |flow25_stub|
                  flow25_stub.post(/.*/) do |flow25_env|
                    # The nested Rack executor must not complete the in-flight callback.
                    flow25_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow25_outer_actor = Actor.context
                    flow25_executor_key = Rails.application.executor.active_key
                    flow25_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow25_executor_key)
                    begin
                      flow25_protocol_browser.host!(flow25_env.url.authority)
                      flow25_protocol_browser.https!(flow25_env.url.scheme == "https")
                      flow25_protocol_browser.post(
                        flow25_env.url.request_uri,
                        params: Rack::Utils.parse_query(flow25_env.body),
                        headers: { "Accept" => "application/json" },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow25_executor_key] =
                        flow25_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow25_outer_controller),
                                  Actor.context.equal?(flow25_outer_actor), flow25_protocol_browser.response.status,]
                    [flow25_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow25_protocol_browser.response.body,]
                  end
                  flow25_stub.get(/.*/) do |flow25_env|
                    flow25_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                    flow25_outer_actor = Actor.context
                    flow25_executor_key = Rails.application.executor.active_key
                    flow25_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow25_executor_key)
                    begin
                      flow25_protocol_browser.host!(flow25_env.url.authority)
                      flow25_protocol_browser.https!(flow25_env.url.scheme == "https")
                      flow25_protocol_browser.get(
                        flow25_env.url.request_uri, headers: {
                          "Authorization" => flow25_env.request_headers.fetch("Authorization"),
                          "Accept" => "application/json",
                        },
                      )
                    ensure
                      ActiveSupport::IsolatedExecutionState[flow25_executor_key] =
                        flow25_outer_execution
                    end

                    # Do not print the outer request or credentials on failure.
                    assert_equal [true, true, 200],
                                 [ActiveSupport::ExecutionContext.to_h
                                   .fetch(:controller).equal?(flow25_outer_controller),
                                  Actor.context.equal?(flow25_outer_actor), flow25_protocol_browser.response.status,]
                    [flow25_protocol_browser.response.status, { "Content-Type" => "application/json" },
                     flow25_protocol_browser.response.body,]
                  end
                end
              flow25_connection =
                Faraday.new do |flow25_builder|
                  flow25_builder.request(:url_encoded)
                  flow25_builder.adapter(:test, flow25_transport)
                end
              OutboundHttp::Connection.stub(
                :build, ->(**flow25_args) {
                  assert_equal flow25_base_host, flow25_args.fetch(:url).host
                  flow25_connection
                },
              ) do
                TestSupport::OutboundHttpGuard.allow do
                  get(flow25_callback_uri.request_uri, headers: flow25_base_headers)
                end
              end

              assert_equal [true, true, true],
                           [response.redirect?,
                            cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                            cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
              flow25_transport.verify_stubbed_calls
            end
          end
        end
      end

      assert_redirected_to auth_app_settings_path(ri: "jp")
      fv5029 = fv5032.fetch(:model).find_by!(
        provider: fv5032.fetch(:provider),
        subject: fv5031,
      )

      assert_equal fv5030.id, fv5029.user_id
      assert_equal "active", fv5029.state
      assert_not_nil fv5029.last_authenticated_at
    end
  end

  test "Google settings link rejects a signed-in client without fresh social-link step-up" do
    user = create_social_client
    token = ClientToken.create!(authentication_epoch: 0, user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_no_difference("ClientExternalIdentity.count") do
      http_headers_11 =
        begin
          fx0_user = user
          fx0_token = token
          begin
            f0_headers = as_user_headers(
              fx0_user,
              host: @host,
              session_public_id: fx0_token.public_id,
            )
            f0_host = f0_headers["Host"]
            f0_route =
              begin
                Rails.application.routes.recognize_path("https://#{f0_host}/") if f0_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f0_family, f0_surface = f0_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f0_family) && f0_surface == "app"
              f0_client_id =
                case f0_family
                when "base" then "base-#{f0_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f0_family}-#{f0_surface}"
                end
              f0_token = ClientToken.find_by!(public_id: f0_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f0_client = OidcClientRegistry.find!(f0_client_id)
              f0_key = [f0_client.client_id, f0_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f0_key] && f0_token.currently_usable? &&
                  !(f0_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f0_token.device_session_id,
                    oidc_client_id: f0_client.client_id,
                    revoked_at: nil,
                  ))
                f0_token.rotate_refresh_token! unless f0_token.device_session_record.current_refresh_token_id
                f0_now = Time.current
                f0_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f0_token, oidc_client_id: f0_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f0_now,
                  refresh_token_expires_at: f0_now + 10.minutes,
                )
                f0_access = AuthenticationTokenService.encode(
                  f0_token.actor_record, host: f0_host, resource_type: "client",
                                         session_public_id: f0_token.public_id,
                                         base_session_public_id: f0_token.public_id,
                                         oidc_sid: f0_session.public_id, oidc_jti: f0_session.oidc_jti,
                                         expires_at: f0_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f0_client), audiences: [f0_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f0_client),
                                         subject: OidcSubject.for(
                                           f0_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f0_client.client_id,
                )
                @base_browser_rp_credentials[f0_key] =
                  [f0_access, f0_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f0_key]
                f0_access, f0_refresh = @base_browser_rp_credentials.fetch(f0_key)
                f0_cookie = [
                  f0_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f0_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f0_refresh)}",
                ].join("; ")
                f0_headers = f0_headers.merge(
                  "Cookie" => f0_cookie,
                  "HTTP_COOKIE" => f0_cookie,
                )
              end
            end
            f0_headers
          end
        end
      post(
        settings_url_for(PROVIDERS.fetch(:google), ri: "jp"),
        headers: http_headers_11,
      )
    end

    assert_response :see_other
    assert_includes response.location, "scope=social_link"
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Apple settings link rejects a signed-in client without fresh social-link step-up" do
    user = create_social_client
    token = ClientToken.create!(authentication_epoch: 0, user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_no_difference("ClientExternalIdentity.count") do
      http_headers_10 =
        begin
          fx1_user = user
          fx1_token = token
          begin
            f1_headers = as_user_headers(
              fx1_user,
              host: @host,
              session_public_id: fx1_token.public_id,
            )
            f1_host = f1_headers["Host"]
            f1_route =
              begin
                Rails.application.routes.recognize_path("https://#{f1_host}/") if f1_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f1_family, f1_surface = f1_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f1_family) && f1_surface == "app"
              f1_client_id =
                case f1_family
                when "base" then "base-#{f1_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f1_family}-#{f1_surface}"
                end
              f1_token = ClientToken.find_by!(public_id: f1_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f1_client = OidcClientRegistry.find!(f1_client_id)
              f1_key = [f1_client.client_id, f1_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f1_key] && f1_token.currently_usable? &&
                  !(f1_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f1_token.device_session_id,
                    oidc_client_id: f1_client.client_id,
                    revoked_at: nil,
                  ))
                f1_token.rotate_refresh_token! unless f1_token.device_session_record.current_refresh_token_id
                f1_now = Time.current
                f1_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f1_token, oidc_client_id: f1_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f1_now,
                  refresh_token_expires_at: f1_now + 10.minutes,
                )
                f1_access = AuthenticationTokenService.encode(
                  f1_token.actor_record, host: f1_host, resource_type: "client",
                                         session_public_id: f1_token.public_id,
                                         base_session_public_id: f1_token.public_id,
                                         oidc_sid: f1_session.public_id, oidc_jti: f1_session.oidc_jti,
                                         expires_at: f1_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f1_client), audiences: [f1_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f1_client),
                                         subject: OidcSubject.for(
                                           f1_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f1_client.client_id,
                )
                @base_browser_rp_credentials[f1_key] =
                  [f1_access, f1_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f1_key]
                f1_access, f1_refresh = @base_browser_rp_credentials.fetch(f1_key)
                f1_cookie = [
                  f1_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f1_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f1_refresh)}",
                ].join("; ")
                f1_headers = f1_headers.merge(
                  "Cookie" => f1_cookie,
                  "HTTP_COOKIE" => f1_cookie,
                )
              end
            end
            f1_headers
          end
        end
      post(
        settings_url_for(PROVIDERS.fetch(:apple), ri: "jp"),
        headers: http_headers_10,
      )
    end

    assert_response :see_other
    assert_includes response.location, "scope=social_link"
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Google settings link rejects replacing an existing provider with a different uid" do
    begin
      fx2_config = PROVIDERS.fetch(:google)
      fx2_user = create_social_client
      fx2_existing = create_social_identity(
        fx2_config,
        user: fx2_user,
        uid: "existing_#{fx2_config.fetch(:normalized)}",
      )

      fx2_headers =
        begin
          f2_headers = as_user_headers(fx2_user, host: @host)
          f2_host = f2_headers["Host"]
          f2_route =
            begin
              Rails.application.routes.recognize_path("https://#{f2_host}/") if f2_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f2_family, f2_surface = f2_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f2_family) && f2_surface == "app"
            f2_client_id =
              case f2_family
              when "base" then "base-#{f2_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f2_family}-#{f2_surface}"
              end
            f2_token = ClientToken.find_by!(public_id: f2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f2_client = OidcClientRegistry.find!(f2_client_id)
            f2_key = [f2_client.client_id, f2_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f2_key] && f2_token.currently_usable? &&
                !(f2_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f2_token.device_session_id,
                  oidc_client_id: f2_client.client_id,
                  revoked_at: nil,
                ))
              f2_token.rotate_refresh_token! unless f2_token.device_session_record.current_refresh_token_id
              f2_now = Time.current
              f2_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f2_token, oidc_client_id: f2_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f2_now,
                refresh_token_expires_at: f2_now + 10.minutes,
              )
              f2_access = AuthenticationTokenService.encode(
                f2_token.actor_record, host: f2_host, resource_type: "client",
                                       session_public_id: f2_token.public_id,
                                       base_session_public_id: f2_token.public_id,
                                       oidc_sid: f2_session.public_id, oidc_jti: f2_session.oidc_jti,
                                       expires_at: f2_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f2_client), audiences: [f2_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f2_client),
                                       subject: OidcSubject.for(
                                         f2_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: f2_client.client_id,
              )
              @base_browser_rp_credentials[f2_key] =
                [f2_access, f2_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f2_key]
              f2_access, f2_refresh = @base_browser_rp_credentials.fetch(f2_key)
              f2_cookie = [
                f2_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f2_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f2_refresh)}",
              ].join("; ")
              f2_headers = f2_headers.merge(
                "Cookie" => f2_cookie,
                "HTTP_COOKIE" => f2_cookie,
              )
            end
          end
          f2_headers
        end
      fx2_token = ClientToken.find_by!(public_id: fx2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      mark_token_step_up_satisfied_for_test(fx2_token, scope: SocialAuth::SOCIAL_LINK_SCOPE)

      assert_no_difference("#{fx2_config.fetch(:model)}.count") do
        post(settings_url_for(fx2_config, ri: "jp"), headers: fx2_headers)
      end

      assert_response :unprocessable_content
      fx2_existing.reload

      assert_equal "existing_#{fx2_config.fetch(:normalized)}", fx2_existing.uid
      assert_nil fx2_config.fetch(:model).find_by(
        provider: fx2_config.fetch(:provider),
        subject: "different_#{fx2_config.fetch(:normalized)}",
      )
    end
  end

  test "Apple settings link rejects replacing an existing provider with a different uid" do
    begin
      fx3_config = PROVIDERS.fetch(:apple)
      fx3_user = create_social_client
      fx3_existing = create_social_identity(
        fx3_config,
        user: fx3_user,
        uid: "existing_#{fx3_config.fetch(:normalized)}",
      )

      fx3_headers =
        begin
          f3_headers = as_user_headers(fx3_user, host: @host)
          f3_host = f3_headers["Host"]
          f3_route =
            begin
              Rails.application.routes.recognize_path("https://#{f3_host}/") if f3_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f3_family, f3_surface = f3_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f3_family) && f3_surface == "app"
            f3_client_id =
              case f3_family
              when "base" then "base-#{f3_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f3_family}-#{f3_surface}"
              end
            f3_token = ClientToken.find_by!(public_id: f3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f3_client = OidcClientRegistry.find!(f3_client_id)
            f3_key = [f3_client.client_id, f3_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f3_key] && f3_token.currently_usable? &&
                !(f3_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f3_token.device_session_id,
                  oidc_client_id: f3_client.client_id,
                  revoked_at: nil,
                ))
              f3_token.rotate_refresh_token! unless f3_token.device_session_record.current_refresh_token_id
              f3_now = Time.current
              f3_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f3_token, oidc_client_id: f3_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f3_now,
                refresh_token_expires_at: f3_now + 10.minutes,
              )
              f3_access = AuthenticationTokenService.encode(
                f3_token.actor_record, host: f3_host, resource_type: "client",
                                       session_public_id: f3_token.public_id,
                                       base_session_public_id: f3_token.public_id,
                                       oidc_sid: f3_session.public_id, oidc_jti: f3_session.oidc_jti,
                                       expires_at: f3_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f3_client), audiences: [f3_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f3_client),
                                       subject: OidcSubject.for(
                                         f3_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: f3_client.client_id,
              )
              @base_browser_rp_credentials[f3_key] =
                [f3_access, f3_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f3_key]
              f3_access, f3_refresh = @base_browser_rp_credentials.fetch(f3_key)
              f3_cookie = [
                f3_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f3_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f3_refresh)}",
              ].join("; ")
              f3_headers = f3_headers.merge(
                "Cookie" => f3_cookie,
                "HTTP_COOKIE" => f3_cookie,
              )
            end
          end
          f3_headers
        end
      fx3_token = ClientToken.find_by!(public_id: fx3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      mark_token_step_up_satisfied_for_test(fx3_token, scope: SocialAuth::SOCIAL_LINK_SCOPE)

      assert_no_difference("#{fx3_config.fetch(:model)}.count") do
        post(settings_url_for(fx3_config, ri: "jp"), headers: fx3_headers)
      end

      assert_response :unprocessable_content
      fx3_existing.reload

      assert_equal "existing_#{fx3_config.fetch(:normalized)}", fx3_existing.uid
      assert_nil fx3_config.fetch(:model).find_by(
        provider: fx3_config.fetch(:provider),
        subject: "different_#{fx3_config.fetch(:normalized)}",
      )
    end
  end

  test "Google settings unlink succeeds when a verified email remains available" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "unlink_google")
    begin
      fv5028 = user
      fv5027 = ClientEmail.find_by!(user_id: fv5028.id)
      fv5027.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
      fv5027.finalize_binding! unless fv5027.binding_effective?
    end

    begin
      fv5026 = user
      fv5024 = PROVIDERS.fetch(:google)
      fv5025 = ClientToken.create!(authentication_epoch: 0, user_id: fv5026.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      satisfy_user_verification(fv5025)
      mark_token_step_up_satisfied_for_test(fv5025, scope: "social_unlink")

      http_headers_9 =
        begin
          lf2_user = fv5026
          lf2_token = fv5025
          begin
            rr2_headers = as_user_headers(
              lf2_user,
              host: @host,
              session_public_id: lf2_token.public_id,
            )
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
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{rr2_family}-#{rr2_surface}"
                end
              rr2_token = ClientToken.find_by!(public_id: rr2_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rr2_client = OidcClientRegistry.find!(rr2_client_id)
              rr2_key = [rr2_client.client_id, rr2_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rr2_key] && rr2_token.currently_usable? &&
                  !(rr2_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: rr2_token.device_session_id,
                    oidc_client_id: rr2_client.client_id,
                    revoked_at: nil,
                  ))
                rr2_token.rotate_refresh_token! unless rr2_token.device_session_record.current_refresh_token_id
                rr2_now = Time.current
                rr2_session = OpAppGrant.create!(
                  authentication_epoch: 0,
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
        end
      delete(
        settings_url_for(fv5024, ri: "jp", host: @host),
        headers: http_headers_9,
        params: { "cf-turnstile-response": "test" },
      )
    end

    assert_redirected_to auth_app_settings_google_url(ri: "jp", host: @host)
    assert_not ClientExternalIdentity.effective_binding.exists?(id: google_identity.id)
    assert_not_nil google_identity.reload.released_at
  end

  test "Apple settings unlink succeeds when a verified email remains available" do
    user = create_social_client
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "unlink_apple")
    begin
      fv5023 = user
      fv5022 = ClientEmail.find_by!(user_id: fv5023.id)
      fv5022.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
      fv5022.finalize_binding! unless fv5022.binding_effective?
    end

    begin
      fv5021 = user
      fv5019 = PROVIDERS.fetch(:apple)
      fv5020 = ClientToken.create!(authentication_epoch: 0, user_id: fv5021.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      satisfy_user_verification(fv5020)
      mark_token_step_up_satisfied_for_test(fv5020, scope: "social_unlink")

      http_headers_8 =
        begin
          lf3_user = fv5021
          lf3_token = fv5020
          begin
            rr3_headers = as_user_headers(
              lf3_user,
              host: @host,
              session_public_id: lf3_token.public_id,
            )
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
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{rr3_family}-#{rr3_surface}"
                end
              rr3_token = ClientToken.find_by!(public_id: rr3_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rr3_client = OidcClientRegistry.find!(rr3_client_id)
              rr3_key = [rr3_client.client_id, rr3_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rr3_key] && rr3_token.currently_usable? &&
                  !(rr3_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: rr3_token.device_session_id,
                    oidc_client_id: rr3_client.client_id,
                    revoked_at: nil,
                  ))
                rr3_token.rotate_refresh_token! unless rr3_token.device_session_record.current_refresh_token_id
                rr3_now = Time.current
                rr3_session = OpAppGrant.create!(
                  authentication_epoch: 0,
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
        end
      delete(
        settings_url_for(fv5019, ri: "jp", host: @host),
        headers: http_headers_8,
        params: { "cf-turnstile-response": "test" },
      )
    end

    assert_redirected_to auth_app_settings_apple_path(ri: "jp")
    assert_not ClientExternalIdentity.effective_binding.exists?(id: apple_identity.id)
    assert_not_nil apple_identity.reload.released_at
  end

  test "Apple settings link succeeds again after unlink" do
    user = create_social_client
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "relink_old_apple")
    begin
      fv5018 = user
      fv5017 = ClientEmail.find_by!(user_id: fv5018.id)
      fv5017.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
      fv5017.finalize_binding! unless fv5017.binding_effective?
    end

    begin
      fv5016 = user
      fv5014 = PROVIDERS.fetch(:apple)
      fv5015 = ClientToken.create!(authentication_epoch: 0, user_id: fv5016.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      satisfy_user_verification(fv5015)
      mark_token_step_up_satisfied_for_test(fv5015, scope: "social_unlink")

      http_headers_7 =
        begin
          lf4_user = fv5016
          lf4_token = fv5015
          begin
            rr4_headers = as_user_headers(
              lf4_user,
              host: @host,
              session_public_id: lf4_token.public_id,
            )
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
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{rr4_family}-#{rr4_surface}"
                end
              rr4_token = ClientToken.find_by!(public_id: rr4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rr4_client = OidcClientRegistry.find!(rr4_client_id)
              rr4_key = [rr4_client.client_id, rr4_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rr4_key] && rr4_token.currently_usable? &&
                  !(rr4_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: rr4_token.device_session_id,
                    oidc_client_id: rr4_client.client_id,
                    revoked_at: nil,
                  ))
                rr4_token.rotate_refresh_token! unless rr4_token.device_session_record.current_refresh_token_id
                rr4_now = Time.current
                rr4_session = OpAppGrant.create!(
                  authentication_epoch: 0,
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
        end
      delete(
        settings_url_for(fv5014, ri: "jp", host: @host),
        headers: http_headers_7,
        params: { "cf-turnstile-response": "test" },
      )
    end

    assert_redirected_to auth_app_settings_apple_path(ri: "jp")
    assert_not ClientExternalIdentity.effective_binding.exists?(id: apple_identity.id)
    assert_not_nil apple_identity.reload.released_at

    new_uid = "relink_new_apple_#{SecureRandom.hex(4)}"
    grant_session =
      begin
        fx4_provider = "apple"
        fx4_user = user
        fx4_ri = "jp"
        fx4_host = @host || configured_host(:auth_service)
        host!(fx4_host) if respond_to?(:host!)

        fx4_user_headers =
          begin
            f4_headers = as_user_headers(fx4_user, host: fx4_host)
            f4_host = f4_headers["Host"]
            f4_route =
              begin
                Rails.application.routes.recognize_path("https://#{f4_host}/") if f4_host.present?
              rescue ActionController::RoutingError
                nil
              end
            f4_family, f4_surface = f4_route&.fetch(:controller)&.split("/")
            if %w(base warp core edit).include?(f4_family) && f4_surface == "app"
              f4_client_id =
                case f4_family
                when "base" then "base-#{f4_surface}-ww"
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{f4_family}-#{f4_surface}"
                end
              f4_token = ClientToken.find_by!(public_id: f4_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              f4_client = OidcClientRegistry.find!(f4_client_id)
              f4_key = [f4_client.client_id, f4_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[f4_key] && f4_token.currently_usable? &&
                  !(f4_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: f4_token.device_session_id,
                    oidc_client_id: f4_client.client_id,
                    revoked_at: nil,
                  ))
                f4_token.rotate_refresh_token! unless f4_token.device_session_record.current_refresh_token_id
                f4_now = Time.current
                f4_session = OpAppGrant.create!(
                  authentication_epoch: 0,
                  client_token: f4_token, oidc_client_id: f4_client.client_id, oidc_scope: "openid profile",
                  oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f4_now,
                  refresh_token_expires_at: f4_now + 10.minutes,
                )
                f4_access = AuthenticationTokenService.encode(
                  f4_token.actor_record, host: f4_host, resource_type: "client",
                                         session_public_id: f4_token.public_id,
                                         base_session_public_id: f4_token.public_id,
                                         oidc_sid: f4_session.public_id, oidc_jti: f4_session.oidc_jti,
                                         expires_at: f4_now + 10.minutes, scopes: %w(openid profile),
                                         issuer: OidcIssuer.for_client(f4_client), audiences: [f4_client.aud],
                                         jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f4_client),
                                         subject: OidcSubject.for(
                                           f4_token.actor_record,
                                           resource_type: "client",
                                         ), client_id: f4_client.client_id,
                )
                @base_browser_rp_credentials[f4_key] =
                  [f4_access, f4_session.issue_refresh_token!]
              end
              if @base_browser_rp_credentials[f4_key]
                f4_access, f4_refresh = @base_browser_rp_credentials.fetch(f4_key)
                f4_cookie = [
                  f4_headers.fetch("Cookie"),
                  "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f4_access)}",
                  "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f4_refresh)}",
                ].join("; ")
                f4_headers = f4_headers.merge(
                  "Cookie" => f4_cookie,
                  "HTTP_COOKIE" => f4_cookie,
                )
              end
            end
            f4_headers
          end
        fx4_session_public_id = fx4_user_headers.fetch("X-TEST-SESSION-PUBLIC-ID")
        fx4_token = ClientToken.find_by(public_id: fx4_session_public_id)
        fx4_session_ref = fx4_token&.device_session_record&.public_id.presence || fx4_session_public_id
        mark_token_step_up_satisfied_for_test(
          fx4_token,
          scope: SocialAuth::SOCIAL_LINK_SCOPE,
        ) if fx4_token

        fx4_issuance = IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: fx4_user.public_id,
          session_ref: fx4_session_ref,
          operation: "link",
          provider: fx4_provider,
        )

        fx4_normalized_provider = SocialIdentifiable.normalize_provider(fx4_provider)
        fx4_continue_path = public_send(
          :"auth_app_settings_#{fx4_normalized_provider}_path",
          ri: fx4_ri,
          social_ceremony_grant: fx4_issuance.grant,
        )

        fx4_headers = social_callback_headers(fx4_host).merge(fx4_user_headers)
        post(fx4_continue_path, headers: fx4_headers)
        fx4_rails_cookie_key = Rails.application.config.session_options.fetch(:key)
        fx4_rails_cookie = response.cookies.fetch(fx4_rails_cookie_key)
        fx4_user_headers["Cookie"] = [
          fx4_user_headers.fetch("Cookie"),
          "#{fx4_rails_cookie_key}=#{Rack::Utils.escape(fx4_rails_cookie)}",
        ].join("; ")
        fx4_user_headers["HTTP_COOKIE"] = fx4_user_headers.fetch("Cookie")
        fx4_state = social_auth_state_from_response

        assert_predicate(
          fx4_state,
          :present?,
          "expected social auth state from response status=#{response.status} " \
          "location=#{response.location.inspect} " \
          "flash=#{flash.to_hash.inspect} body=#{response.body.to_s.first(200).inspect}",
        )

        Struct.new(:state, :user_headers, :session_public_id, keyword_init: true).new(
          state: fx4_state,
          user_headers: fx4_user_headers,
          session_public_id: fx4_session_ref,
        )
      end
    setup_mock_auth(PROVIDERS.fetch(:apple), uid: new_uid, token: "relinked_apple_token")

    # Settings link commits on Sign after the Sign-owned OAuth state and step-up checks.
    assert_no_difference("Client.count") do
      assert_difference("ClientExternalIdentity.count", 1) do
        begin
          flow26_config = PROVIDERS.fetch(:apple)
          flow26_params = { state: grant_session.state }
          flow26_headers = @callback_headers.merge(grant_session.user_headers)
          if flow26_config.fetch(:provider) == "apple"
            get(
              auth_app_social_apple_callback_url(
                provider: "apple",
                ri: "jp",
              ), params: flow26_params, headers: flow26_headers,
            )
          else
            get(
              auth_app_social_google_callback_url(provider: flow26_config.fetch(:provider), ri: "jp"),
              params: flow26_params,
              headers: flow26_headers,
            )
          end
          1.times do
            if response.media_type == "text/html" && response.body.include?("social-completion-form")
              flow27_form = response.parsed_body.at_css("form#social-completion-form")
              flow27_fields =
                flow27_form.css("input[name]").to_h { |flow27_input|
                  [
                    flow27_input["name"],
                    flow27_input["value"],
                  ]
                }
              flow27_rails_cookie = Rails.application.config.session_options.fetch(:key)
              flow27_owner_cookie =
                request.headers["Cookie"].to_s.split("; ")
                  .reject { |flow27_pair| flow27_pair.start_with?("#{flow27_rails_cookie}=") }
              flow27_owner_cookie << "#{flow27_rails_cookie}=#{Rack::Utils.escape(
                response
                                .cookies.fetch(flow27_rails_cookie),
              )}"
              post(
                flow27_form["action"], params: flow27_fields, headers: {
                  "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                  "Cookie" => flow27_owner_cookie.join("; "),
                  "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              break
            end
            break unless response.redirect? && @base_browser

            flow27_target = URI.parse(response.location)
            if flow27_target.path == "/sign/in/check"
              flow27_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
              flow27_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow27_sid_cookie])
              flow27_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
                surface: "app", transaction_id: flow27_ceremony.authorization_transaction_ref,
              )
              get(
                auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
                  "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                  "Sec-Fetch-Mode" => "navigate",
                  "Sec-Fetch-Dest" => "document",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              flow27_target = URI.parse(response.location)
              flow27_principal = Client.find_by!(public_id: flow27_parent.reload.actor_ref)
              BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow27_principal)
            end
            break unless flow27_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
              %w(/social/authentication/completion /oauth/authorize).include?(flow27_target.path)

            flow27_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow27_base_cookie = @base_browser.cookies.to_hash.map { |flow27_name, flow27_value|
              "#{flow27_name}=#{Rack::Utils.escape(flow27_value)}"
            }.join("; ")
            flow27_base_headers = { "Origin" => "https://#{flow27_base_host}",
                                    "Sec-Fetch-Site" => "same-origin",
                                    "Cookie" => flow27_base_cookie,
                                    "HTTP_COOKIE" => flow27_base_cookie, }
            host!(flow27_base_host)
            https!
            get(flow27_target.request_uri, headers: flow27_base_headers)
            flow27_form = response.parsed_body.at_css("form")
            flow27_fields =
              flow27_form.css("input[name]").to_h { |flow27_input|
                [
                  flow27_input["name"],
                  flow27_input["value"],
                ]
              }
            post(
              flow27_form["action"],
              params: flow27_fields,
              headers: flow27_base_headers,
            )
            if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
              get(URI.parse(response.location).request_uri, headers: flow27_base_headers)
              flow27_form = response.parsed_body.at_css("form")
              flow27_fields =
                flow27_form.css("input[name]").to_h { |flow27_input|
                  [
                    flow27_input["name"],
                    flow27_input["value"],
                  ]
                }
              post(
                flow27_form["action"],
                params: flow27_fields,
                headers: flow27_base_headers,
              )
            end
            break unless response.redirect?
            # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
            break unless URI.parse(response.location).path == "/oidc/callback" ||
              URI.parse(response.location).host ==
                URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

            flow27_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            flow27_callback_uri = URI.parse(response.location)
            # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
            unless flow27_callback_uri.host == flow27_base_host
              flow27_rt = Rack::Utils.parse_query(flow27_callback_uri.query).fetch("rt")
              flow27_payload, = JWT.decode(
                flow27_rt, JitSecurityJwtRegistry.public_key_for(
                  flow27_issuer.id,
                  flow27_issuer.current_kid,
                ), true,
                algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow27_base_host}",
                verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
              )
              flow27_callback_uri = URI.parse(flow27_payload.fetch("url"))
            end
            flow27_protocol_browser = open_session
            flow27_protocol_browser.host!(flow27_base_host)
            flow27_protocol_browser.https!
            # Substitute network transport only: the token and UserInfo requests still run
            # through their real public controllers, including PKCE and client authentication.
            flow27_transport =
              Faraday::Adapter::Test::Stubs.new do |flow27_stub|
                flow27_stub.post(/.*/) do |flow27_env|
                  # The nested Rack executor must not complete the in-flight callback.
                  flow27_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                  flow27_outer_actor = Actor.context
                  flow27_executor_key = Rails.application.executor.active_key
                  flow27_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow27_executor_key)
                  begin
                    flow27_protocol_browser.host!(flow27_env.url.authority)
                    flow27_protocol_browser.https!(flow27_env.url.scheme == "https")
                    flow27_protocol_browser.post(
                      flow27_env.url.request_uri,
                      params: Rack::Utils.parse_query(flow27_env.body),
                      headers: { "Accept" => "application/json" },
                    )
                  ensure
                    ActiveSupport::IsolatedExecutionState[flow27_executor_key] =
                      flow27_outer_execution
                  end

                  # Do not print the outer request or credentials on failure.
                  assert_equal [true, true, 200],
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow27_outer_controller),
                                Actor.context.equal?(flow27_outer_actor), flow27_protocol_browser.response.status,]
                  [flow27_protocol_browser.response.status, { "Content-Type" => "application/json" },
                   flow27_protocol_browser.response.body,]
                end
                flow27_stub.get(/.*/) do |flow27_env|
                  flow27_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                  flow27_outer_actor = Actor.context
                  flow27_executor_key = Rails.application.executor.active_key
                  flow27_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow27_executor_key)
                  begin
                    flow27_protocol_browser.host!(flow27_env.url.authority)
                    flow27_protocol_browser.https!(flow27_env.url.scheme == "https")
                    flow27_protocol_browser.get(
                      flow27_env.url.request_uri, headers: {
                        "Authorization" => flow27_env.request_headers.fetch("Authorization"),
                        "Accept" => "application/json",
                      },
                    )
                  ensure
                    ActiveSupport::IsolatedExecutionState[flow27_executor_key] =
                      flow27_outer_execution
                  end

                  # Do not print the outer request or credentials on failure.
                  assert_equal [true, true, 200],
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow27_outer_controller),
                                Actor.context.equal?(flow27_outer_actor), flow27_protocol_browser.response.status,]
                  [flow27_protocol_browser.response.status, { "Content-Type" => "application/json" },
                   flow27_protocol_browser.response.body,]
                end
              end
            flow27_connection =
              Faraday.new do |flow27_builder|
                flow27_builder.request(:url_encoded)
                flow27_builder.adapter(:test, flow27_transport)
              end
            OutboundHttp::Connection.stub(
              :build, ->(**flow27_args) {
                assert_equal flow27_base_host, flow27_args.fetch(:url).host
                flow27_connection
              },
            ) do
              TestSupport::OutboundHttpGuard.allow do
                get(flow27_callback_uri.request_uri, headers: flow27_base_headers)
              end
            end

            assert_equal [true, true, true],
                         [response.redirect?,
                          cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                          cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
            flow27_transport.verify_stubbed_calls
          end
        end
      end
    end

    assert_redirected_to auth_app_settings_path(ri: "jp")
    relinked_identity = ClientExternalIdentity.find_by!(provider: "apple", subject: new_uid)

    assert_equal user.id, relinked_identity.user_id
    assert_equal "active", relinked_identity.state
    assert_not ClientExternalIdentity.effective_binding.exists?(id: apple_identity.id)
  end

  test "Google settings unlink keeps the last active login method" do
    begin
      ct0_config = PROVIDERS.fetch(:google)
      ct0_user = create_social_client
      ct0_identity = create_social_identity(
        ct0_config,
        user: ct0_user,
        uid: "last_#{ct0_config.fetch(:normalized)}",
      )

      begin
        cc0_user = ct0_user
        cc0_config = ct0_config
        cc0_token = ClientToken.create!(
          authentication_epoch: 0,
          user_id: cc0_user.id,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        )
        satisfy_user_verification(cc0_token)
        mark_token_step_up_satisfied_for_test(
          cc0_token,
          scope: "social_unlink",
        )

        http_headers_6 =
          begin
            cc0_fixture_8_user = cc0_user
            cc0_fixture_8_token = cc0_token
            begin
              cc0_f8_headers = as_user_headers(
                cc0_fixture_8_user,
                host: @host,
                session_public_id: cc0_fixture_8_token.public_id,
              )
              cc0_f8_host = cc0_f8_headers["Host"]
              cc0_f8_route =
                begin
                  Rails.application.routes.recognize_path("https://#{cc0_f8_host}/") if cc0_f8_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              cc0_f8_family, cc0_f8_surface = cc0_f8_route&.fetch(:controller)&.split("/")
              if %w(base warp core
                    edit).include?(cc0_f8_family) && cc0_f8_surface == "app"
                cc0_f8_client_id =
                  case cc0_f8_family
                  when "base" then "base-#{cc0_f8_surface}-ww"
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{cc0_f8_family}-#{cc0_f8_surface}"
                  end
                cc0_f8_token = ClientToken.find_by!(public_id: cc0_f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                cc0_f8_client = OidcClientRegistry.find!(cc0_f8_client_id)
                cc0_f8_key = [
                  cc0_f8_client.client_id, cc0_f8_token.public_id,
                ]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[cc0_f8_key] && cc0_f8_token.currently_usable? &&
                    !(cc0_f8_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: cc0_f8_token.device_session_id,
                      oidc_client_id: cc0_f8_client.client_id,
                      revoked_at: nil,
                    ))
                  cc0_f8_token.rotate_refresh_token! unless cc0_f8_token.device_session_record.current_refresh_token_id
                  cc0_f8_now = Time.current
                  cc0_f8_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: cc0_f8_token,
                    oidc_client_id: cc0_f8_client.client_id,
                    oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid,
                    oidc_nonce: SecureRandom.hex(16),
                    oidc_auth_time: cc0_f8_now,
                    refresh_token_expires_at: cc0_f8_now + 10.minutes,
                  )
                  cc0_f8_access = AuthenticationTokenService.encode(
                    cc0_f8_token.actor_record,
                    host: cc0_f8_host,
                    resource_type: "client",
                    session_public_id: cc0_f8_token.public_id,
                    base_session_public_id: cc0_f8_token.public_id,
                    oidc_sid: cc0_f8_session.public_id,
                    oidc_jti: cc0_f8_session.oidc_jti,
                    expires_at: cc0_f8_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(cc0_f8_client),
                    audiences: [cc0_f8_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(cc0_f8_client),
                    subject: OidcSubject.for(
                      cc0_f8_token.actor_record,
                      resource_type: "client",
                    ),
                    client_id: cc0_f8_client.client_id,
                  )
                  @base_browser_rp_credentials[cc0_f8_key] =
                    [cc0_f8_access,
                     cc0_f8_session.issue_refresh_token!,]
                end
                if @base_browser_rp_credentials[cc0_f8_key]
                  cc0_f8_access, cc0_f8_refresh = @base_browser_rp_credentials.fetch(cc0_f8_key)
                  cc0_f8_cookie = [
                    cc0_f8_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(cc0_f8_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(cc0_f8_refresh)}",
                  ].join("; ")
                  cc0_f8_headers = cc0_f8_headers.merge(
                    "Cookie" => cc0_f8_cookie,
                    "HTTP_COOKIE" => cc0_f8_cookie,
                  )
                end
              end
              cc0_f8_headers
            end
          end
        delete(
          settings_url_for(cc0_config, ri: "jp", host: @host),
          headers: http_headers_6,
          params: { "cf-turnstile-response": "test" },
        )
      end

      assert_response :unprocessable_content
      assert ct0_config.fetch(:model).exists?(ct0_identity.id)
    end
  end

  test "Apple settings unlink keeps the last active login method" do
    begin
      ct1_config = PROVIDERS.fetch(:apple)
      ct1_user = create_social_client
      ct1_identity = create_social_identity(
        ct1_config,
        user: ct1_user,
        uid: "last_#{ct1_config.fetch(:normalized)}",
      )

      begin
        cc3_user = ct1_user
        cc3_config = ct1_config
        cc3_token = ClientToken.create!(
          authentication_epoch: 0,
          user_id: cc3_user.id,
          user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        )
        satisfy_user_verification(cc3_token)
        mark_token_step_up_satisfied_for_test(
          cc3_token,
          scope: "social_unlink",
        )

        http_headers_5 =
          begin
            cc3_fixture_8_user = cc3_user
            cc3_fixture_8_token = cc3_token
            begin
              cc3_f8_headers = as_user_headers(
                cc3_fixture_8_user,
                host: @host,
                session_public_id: cc3_fixture_8_token.public_id,
              )
              cc3_f8_host = cc3_f8_headers["Host"]
              cc3_f8_route =
                begin
                  Rails.application.routes.recognize_path("https://#{cc3_f8_host}/") if cc3_f8_host.present?
                rescue ActionController::RoutingError
                  nil
                end
              cc3_f8_family, cc3_f8_surface = cc3_f8_route&.fetch(:controller)&.split("/")
              if %w(base warp core
                    edit).include?(cc3_f8_family) && cc3_f8_surface == "app"
                cc3_f8_client_id =
                  case cc3_f8_family
                  when "base" then "base-#{cc3_f8_surface}-ww"
                  when "edit" then "edit-org-ww"
                  when "tech" then "tech-org-ww"
                  else "#{cc3_f8_family}-#{cc3_f8_surface}"
                  end
                cc3_f8_token = ClientToken.find_by!(public_id: cc3_f8_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
                cc3_f8_client = OidcClientRegistry.find!(cc3_f8_client_id)
                cc3_f8_key = [
                  cc3_f8_client.client_id, cc3_f8_token.public_id,
                ]
                @base_browser_rp_credentials ||= {}
                if !@base_browser_rp_credentials[cc3_f8_key] && cc3_f8_token.currently_usable? &&
                    !(cc3_f8_token.device_session_id && OpAppGrant.exists?(
                      device_session_id: cc3_f8_token.device_session_id,
                      oidc_client_id: cc3_f8_client.client_id,
                      revoked_at: nil,
                    ))
                  cc3_f8_token.rotate_refresh_token! unless cc3_f8_token.device_session_record.current_refresh_token_id
                  cc3_f8_now = Time.current
                  cc3_f8_session = OpAppGrant.create!(
                    authentication_epoch: 0,
                    client_token: cc3_f8_token,
                    oidc_client_id: cc3_f8_client.client_id,
                    oidc_scope: "openid profile",
                    oidc_jti: SecureRandom.uuid,
                    oidc_nonce: SecureRandom.hex(16),
                    oidc_auth_time: cc3_f8_now,
                    refresh_token_expires_at: cc3_f8_now + 10.minutes,
                  )
                  cc3_f8_access = AuthenticationTokenService.encode(
                    cc3_f8_token.actor_record,
                    host: cc3_f8_host,
                    resource_type: "client",
                    session_public_id: cc3_f8_token.public_id,
                    base_session_public_id: cc3_f8_token.public_id,
                    oidc_sid: cc3_f8_session.public_id,
                    oidc_jti: cc3_f8_session.oidc_jti,
                    expires_at: cc3_f8_now + 10.minutes,
                    scopes: %w(openid profile),
                    issuer: OidcIssuer.for_client(cc3_f8_client),
                    audiences: [cc3_f8_client.aud],
                    jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(cc3_f8_client),
                    subject: OidcSubject.for(
                      cc3_f8_token.actor_record,
                      resource_type: "client",
                    ),
                    client_id: cc3_f8_client.client_id,
                  )
                  @base_browser_rp_credentials[cc3_f8_key] =
                    [cc3_f8_access,
                     cc3_f8_session.issue_refresh_token!,]
                end
                if @base_browser_rp_credentials[cc3_f8_key]
                  cc3_f8_access, cc3_f8_refresh = @base_browser_rp_credentials.fetch(cc3_f8_key)
                  cc3_f8_cookie = [
                    cc3_f8_headers.fetch("Cookie"),
                    "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(cc3_f8_access)}",
                    "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(cc3_f8_refresh)}",
                  ].join("; ")
                  cc3_f8_headers = cc3_f8_headers.merge(
                    "Cookie" => cc3_f8_cookie,
                    "HTTP_COOKIE" => cc3_f8_cookie,
                  )
                end
              end
              cc3_f8_headers
            end
          end
        delete(
          settings_url_for(cc3_config, ri: "jp", host: @host),
          headers: http_headers_5,
          params: { "cf-turnstile-response": "test" },
        )
      end

      assert_response :unprocessable_content
      assert ct1_config.fetch(:model).exists?(ct1_identity.id)
    end
  end

  test "Google settings unlink redirects to verification without social unlink step-up" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "step_up_google")
    begin
      fv5013 = user
      fv5012 = ClientEmail.find_by!(user_id: fv5013.id)
      fv5012.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
      fv5012.finalize_binding! unless fv5012.binding_effective?
    end
    token = ClientToken.create!(authentication_epoch: 0, user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    http_headers_4 =
      begin
        fx5_user = user
        fx5_token = token
        begin
          f5_headers = as_user_headers(
            fx5_user,
            host: @host,
            session_public_id: fx5_token.public_id,
          )
          f5_host = f5_headers["Host"]
          f5_route =
            begin
              Rails.application.routes.recognize_path("https://#{f5_host}/") if f5_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f5_family, f5_surface = f5_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f5_family) && f5_surface == "app"
            f5_client_id =
              case f5_family
              when "base" then "base-#{f5_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f5_family}-#{f5_surface}"
              end
            f5_token = ClientToken.find_by!(public_id: f5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f5_client = OidcClientRegistry.find!(f5_client_id)
            f5_key = [f5_client.client_id, f5_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f5_key] && f5_token.currently_usable? &&
                !(f5_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f5_token.device_session_id,
                  oidc_client_id: f5_client.client_id,
                  revoked_at: nil,
                ))
              f5_token.rotate_refresh_token! unless f5_token.device_session_record.current_refresh_token_id
              f5_now = Time.current
              f5_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f5_token, oidc_client_id: f5_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f5_now,
                refresh_token_expires_at: f5_now + 10.minutes,
              )
              f5_access = AuthenticationTokenService.encode(
                f5_token.actor_record, host: f5_host, resource_type: "client",
                                       session_public_id: f5_token.public_id,
                                       base_session_public_id: f5_token.public_id,
                                       oidc_sid: f5_session.public_id, oidc_jti: f5_session.oidc_jti,
                                       expires_at: f5_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f5_client), audiences: [f5_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f5_client),
                                       subject: OidcSubject.for(
                                         f5_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: f5_client.client_id,
              )
              @base_browser_rp_credentials[f5_key] =
                [f5_access, f5_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f5_key]
              f5_access, f5_refresh = @base_browser_rp_credentials.fetch(f5_key)
              f5_cookie = [
                f5_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f5_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f5_refresh)}",
              ].join("; ")
              f5_headers = f5_headers.merge(
                "Cookie" => f5_cookie,
                "HTTP_COOKIE" => f5_cookie,
              )
            end
          end
          f5_headers
        end
      end
    delete(
      settings_url_for(PROVIDERS.fetch(:google), ri: "jp", host: @host),
      headers: http_headers_4,
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :unauthorized
    assert ClientExternalIdentity.effective_binding.exists?(id: google_identity.id)
  end

  test "Apple settings unlink rejects a signed-in client without social unlink step-up" do
    user = create_social_client
    apple_identity = create_social_identity(PROVIDERS.fetch(:apple), user:, uid: "step_up_apple")
    begin
      fv5011 = user
      fv5010 = ClientEmail.find_by!(user_id: fv5011.id)
      fv5010.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
      fv5010.finalize_binding! unless fv5010.binding_effective?
    end
    token = ClientToken.create!(authentication_epoch: 0, user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    http_headers_3 =
      begin
        fx6_user = user
        fx6_token = token
        begin
          f6_headers = as_user_headers(
            fx6_user,
            host: @host,
            session_public_id: fx6_token.public_id,
          )
          f6_host = f6_headers["Host"]
          f6_route =
            begin
              Rails.application.routes.recognize_path("https://#{f6_host}/") if f6_host.present?
            rescue ActionController::RoutingError
              nil
            end
          f6_family, f6_surface = f6_route&.fetch(:controller)&.split("/")
          if %w(base warp core edit).include?(f6_family) && f6_surface == "app"
            f6_client_id =
              case f6_family
              when "base" then "base-#{f6_surface}-ww"
              when "edit" then "edit-org-ww"
              when "tech" then "tech-org-ww"
              else "#{f6_family}-#{f6_surface}"
              end
            f6_token = ClientToken.find_by!(public_id: f6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
            f6_client = OidcClientRegistry.find!(f6_client_id)
            f6_key = [f6_client.client_id, f6_token.public_id]
            @base_browser_rp_credentials ||= {}
            if !@base_browser_rp_credentials[f6_key] && f6_token.currently_usable? &&
                !(f6_token.device_session_id && OpAppGrant.exists?(
                  device_session_id: f6_token.device_session_id,
                  oidc_client_id: f6_client.client_id,
                  revoked_at: nil,
                ))
              f6_token.rotate_refresh_token! unless f6_token.device_session_record.current_refresh_token_id
              f6_now = Time.current
              f6_session = OpAppGrant.create!(
                authentication_epoch: 0,
                client_token: f6_token, oidc_client_id: f6_client.client_id, oidc_scope: "openid profile",
                oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: f6_now,
                refresh_token_expires_at: f6_now + 10.minutes,
              )
              f6_access = AuthenticationTokenService.encode(
                f6_token.actor_record, host: f6_host, resource_type: "client",
                                       session_public_id: f6_token.public_id,
                                       base_session_public_id: f6_token.public_id,
                                       oidc_sid: f6_session.public_id, oidc_jti: f6_session.oidc_jti,
                                       expires_at: f6_now + 10.minutes, scopes: %w(openid profile),
                                       issuer: OidcIssuer.for_client(f6_client), audiences: [f6_client.aud],
                                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(f6_client),
                                       subject: OidcSubject.for(
                                         f6_token.actor_record,
                                         resource_type: "client",
                                       ), client_id: f6_client.client_id,
              )
              @base_browser_rp_credentials[f6_key] =
                [f6_access, f6_session.issue_refresh_token!]
            end
            if @base_browser_rp_credentials[f6_key]
              f6_access, f6_refresh = @base_browser_rp_credentials.fetch(f6_key)
              f6_cookie = [
                f6_headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(f6_access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(f6_refresh)}",
              ].join("; ")
              f6_headers = f6_headers.merge(
                "Cookie" => f6_cookie,
                "HTTP_COOKIE" => f6_cookie,
              )
            end
          end
          f6_headers
        end
      end
    delete(
      settings_url_for(PROVIDERS.fetch(:apple), ri: "jp", host: @host),
      headers: http_headers_3,
      params: { "cf-turnstile-response": "test" },
    )

    assert_response :unauthorized
    assert ClientExternalIdentity.effective_binding.exists?(id: apple_identity.id)
  end

  test "Google settings link rejects settings step-up scope" do
    user = create_social_client
    token = ClientToken.create!(authentication_epoch: 0, user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_email")

    http_headers_2 =
      begin
        rp_headers = as_user_headers(user, host: @host, session_public_id: token.public_id)
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
    post(
      settings_url_for(PROVIDERS.fetch(:google), ri: "jp"),
      headers: http_headers_2,
    )

    assert_response :see_other
    assert_match %r{\Ahttp://#{Regexp.escape(@host)}/verification\?}, response.location
    assert_includes response.location, "scope=social_link"
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
  end

  test "Google settings unlink keeps its existing refusal when Secret is the only remaining method" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "passcode_google")
    now = Client.database_now
    issuance = ClientSecretIssuance.create!(
      client: user, origin_operation_id: SecureRandom.uuid, origin: "manual", attempt_number: 1,
      browser_session_ref: "social-unlink-secret-fixture", planned_count: 1,
      presented_at: now, confirmed_at: now, expires_at: now + 1.minute,
    )
    raw = SecureRandom.base58(32)
    secret = ClientSecretCredential.create!(
      client: user, issuance: issuance, name: "Secret", password: raw,
      confirmed_at: now,
    )

    begin
      fv5009 = user
      fv5007 = PROVIDERS.fetch(:google)
      fv5008 = ClientToken.create!(authentication_epoch: 0, user_id: fv5009.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      satisfy_user_verification(fv5008)
      mark_token_step_up_satisfied_for_test(fv5008, scope: "social_unlink")

      http_headers_1 =
        begin
          lf5_user = fv5009
          lf5_token = fv5008
          begin
            rr5_headers = as_user_headers(
              lf5_user,
              host: @host,
              session_public_id: lf5_token.public_id,
            )
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
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{rr5_family}-#{rr5_surface}"
                end
              rr5_token = ClientToken.find_by!(public_id: rr5_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rr5_client = OidcClientRegistry.find!(rr5_client_id)
              rr5_key = [rr5_client.client_id, rr5_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rr5_key] && rr5_token.currently_usable? &&
                  !(rr5_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: rr5_token.device_session_id,
                    oidc_client_id: rr5_client.client_id,
                    revoked_at: nil,
                  ))
                rr5_token.rotate_refresh_token! unless rr5_token.device_session_record.current_refresh_token_id
                rr5_now = Time.current
                rr5_session = OpAppGrant.create!(
                  authentication_epoch: 0,
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
        end
      delete(
        settings_url_for(fv5007, ri: "jp", host: @host),
        headers: http_headers_1,
        params: { "cf-turnstile-response": "test" },
      )
    end

    assert_response :unprocessable_content
    assert PROVIDERS.fetch(:google).fetch(:model).exists?(google_identity.id)
    assert secret.reload.available_at?(at: Client.database_now)
  end

  test "Google settings unlink rejects failed Turnstile before unlinking" do
    user = create_social_client
    google_identity = create_social_identity(PROVIDERS.fetch(:google), user:, uid: "turnstile_google")
    begin
      fv5006 = user
      fv5005 = ClientEmail.find_by!(user_id: fv5006.id)
      fv5005.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
      fv5005.finalize_binding! unless fv5005.binding_effective?
    end
    TurnstileVerifierStub.challenge_response = { "success" => false }

    begin
      fv5004 = user
      fv5002 = PROVIDERS.fetch(:google)
      fv5003 = ClientToken.create!(authentication_epoch: 0, user_id: fv5004.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      satisfy_user_verification(fv5003)
      mark_token_step_up_satisfied_for_test(fv5003, scope: "social_unlink")

      http_headers_0 =
        begin
          lf6_user = fv5004
          lf6_token = fv5003
          begin
            rr6_headers = as_user_headers(
              lf6_user,
              host: @host,
              session_public_id: lf6_token.public_id,
            )
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
                when "edit" then "edit-org-ww"
                when "tech" then "tech-org-ww"
                else "#{rr6_family}-#{rr6_surface}"
                end
              rr6_token = ClientToken.find_by!(public_id: rr6_headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
              rr6_client = OidcClientRegistry.find!(rr6_client_id)
              rr6_key = [rr6_client.client_id, rr6_token.public_id]
              @base_browser_rp_credentials ||= {}
              if !@base_browser_rp_credentials[rr6_key] && rr6_token.currently_usable? &&
                  !(rr6_token.device_session_id && OpAppGrant.exists?(
                    device_session_id: rr6_token.device_session_id,
                    oidc_client_id: rr6_client.client_id,
                    revoked_at: nil,
                  ))
                rr6_token.rotate_refresh_token! unless rr6_token.device_session_record.current_refresh_token_id
                rr6_now = Time.current
                rr6_session = OpAppGrant.create!(
                  authentication_epoch: 0,
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
        end
      delete(
        settings_url_for(fv5002, ri: "jp", host: @host),
        headers: http_headers_0,
        params: { "cf-turnstile-response": "test" },
      )
    end

    assert_response :see_other
    assert_redirected_to auth_app_settings_google_url(ri: "jp", host: @host)
    assert ClientExternalIdentity.effective_binding.exists?(id: google_identity.id)
  end

  private

  def setup_mock_auth(config, uid:, token:)
    normalized = config.fetch(:normalized)
    credentials = { token: token, expires_at: 1.week.from_now.to_i }
    credentials[:refresh_token] = "refresh_#{token}" if normalized == "apple"

    extra = {}
    extra[:id_info] = { nonce: session[:social_auth_nonce] } if normalized == "apple"

    OmniAuth.config.mock_auth[normalized.to_sym] = OmniAuth::AuthHash.new(
      provider: normalized,
      uid: uid,
      info: {},
      credentials: credentials,
      extra: extra,
    )
  end

  def create_social_client
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      public_id: PublicId.generate,
      birthdate: "2000-02-03",
      last_step_up_at: 1.minute.ago,
    )
    ClientEmail.create!(
      user: user,
      address: "social-contract-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::UNVERIFIED,
    )
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      last_otp_at: Time.zone.at(0),
    )
    user
  end

  def create_social_identity(config, user:, uid:)
    config.fetch(:model).create!(
      client: user,
      subject: uid,
      provider: config.fetch(:provider),
      issuer: ExternalAuthentication::ProviderRegistry.fetch(config.fetch(:provider)).issuer,
      audience: "#{config.fetch(:provider)}-test-client-id",
      verification_authority: "test",
      verified_at: Time.current,
      state: "active",
    )
  end

  def settings_url_for(config, **params)
    public_send(:"auth_app_settings_#{config.fetch(:normalized)}_path", **params)
  end

  def token_bound_step_up_for_social_link(user)
    token = ClientToken.create!(authentication_epoch: 0, user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)
    token
  end

  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class SocialAuthAppFlowContractTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialAuthAppFlowContractTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    base_hosts = {
      "APP" => [
        ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
        ENV.fetch("PRIVATE_BASE_SERVICE_URL"),
      ],
      "ORG" => [
        ENV.fetch("PUBLIC_BASE_STAFF_URL"),
        ENV.fetch("PRIVATE_BASE_STAFF_URL"),
      ],
      "COM" => [
        ENV.fetch("PUBLIC_BASE_CORPORATE_URL"),
        ENV.fetch("PRIVATE_BASE_CORPORATE_URL"),
      ],
    }
    base_surface = base_hosts.find { |_surface, hosts| hosts.include?(normalized) }&.first
    return "surface:BASE_#{base_surface}" if base_surface

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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
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

  def satisfy_user_verification(token)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
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
class SocialAuthAppFlowContractTest
  private
end

# DAMP local helper copy on the test class.
class SocialAuthAppFlowContractTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

  # The Auth callback records the authenticated OIDC result on Visa. The browser then follows the
  # browser-bound GET continuation before the RP callback can run.
  def complete_social_oidc_visa_result!(target:, base_browser:, base_host:, visa_host:)
    raise "unexpected Visa result target" unless target.host == visa_host && target.path == "/oidc/result"

    base_browser.host!(visa_host)
    base_browser.https!
    base_browser.get(
      target.request_uri, headers: {
        "Host" => visa_host,
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Site" => "cross-site",
      },
    )
    raise "Visa result continuation did not redirect" unless base_browser.response.redirect?

    callback_uri = URI.parse(base_browser.response.location)
    unless callback_uri.host == base_host
      jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
      raise "unexpected OIDC callback transport host" unless callback_uri.host == jump_host

      result_token = Rack::Utils.parse_query(callback_uri.query).fetch("rt")
      issuer = JitSecurityJwtRegistry.surface("VISA_APP")
      payload, = JWT.decode(
        result_token,
        JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
        true,
        algorithms: ["ES384"],
        verify_iss: true,
        iss: "https://#{visa_host}",
        verify_aud: true,
        aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
      )
      callback_uri = URI.parse(payload.fetch("url"))
    end
    raise "unexpected OIDC callback path" unless callback_uri.host == base_host && callback_uri.path == "/oidc/callback"

    base_cookie = base_browser.cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; ")
    base_headers = {
      "Origin" => "https://#{base_host}",
      "Sec-Fetch-Site" => "same-origin",
      "Cookie" => base_cookie,
      "HTTP_COOKIE" => base_cookie,
    }
    protocol_browser = open_session
    protocol_browser.host!(base_host)
    protocol_browser.https!
    transport =
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post(/.*/) do |env|
          outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
          outer_actor = Actor.context
          executor_key = Rails.application.executor.active_key
          outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
          begin
            protocol_browser.host!(env.url.authority)
            protocol_browser.https!(env.url.scheme == "https")
            protocol_browser.post(
              env.url.request_uri,
              params: Rack::Utils.parse_query(env.body),
              headers: { "Accept" => "application/json" },
            )
          ensure
            ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
          end

          assert_equal [true, true, 200], [
            ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller),
            Actor.context.equal?(outer_actor),
            protocol_browser.response.status,
          ]
          [protocol_browser.response.status, { "Content-Type" => "application/json" },
           protocol_browser.response.body,]
        end
        stub.get(/.*/) do |env|
          outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
          outer_actor = Actor.context
          executor_key = Rails.application.executor.active_key
          outer_execution = ActiveSupport::IsolatedExecutionState.delete(executor_key)
          begin
            protocol_browser.host!(env.url.authority)
            protocol_browser.https!(env.url.scheme == "https")
            protocol_browser.get(
              env.url.request_uri,
              headers: {
                "Authorization" => env.request_headers.fetch("Authorization"),
                "Accept" => "application/json",
              },
            )
          ensure
            ActiveSupport::IsolatedExecutionState[executor_key] = outer_execution
          end

          assert_equal [true, true, 200], [
            ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(outer_controller),
            Actor.context.equal?(outer_actor),
            protocol_browser.response.status,
          ]
          [protocol_browser.response.status, { "Content-Type" => "application/json" },
           protocol_browser.response.body,]
        end
      end
    connection =
      Faraday.new do |builder|
        builder.request(:url_encoded)
        builder.adapter(:test, transport)
      end

    OutboundHttp::Connection.stub(
      :build,
      ->(**args) {
        assert_equal visa_host, args.fetch(:url).host
        connection
      },
    ) do
      TestSupport::OutboundHttpGuard.allow do
        host!(base_host)
        https!
        get(callback_uri.request_uri, headers: base_headers)
      end
    end

    assert_equal [true, true, true], [
      response.redirect?,
      cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
      cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,
    ]
    transport.verify_stubbed_calls
  end

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def follow_social_authorization_bootstrap!(base_browser:, base_host:, visa_host:, auth_host:)
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    target = URI.parse(base_browser.response.location.to_s)
    initial_rt = nil
    if target.host == jump_host
      target, initial_rt = decode_social_jump_target!(target, issuer_namespace: "BASE_APP", issuer_host: base_host)
    end
    raise "Visa authorization host mismatch" unless target.host == visa_host

    base_browser.host!(visa_host)
    base_browser.https!
    base_browser.get(target.request_uri, headers: social_navigation_headers(visa_host, site: "cross-site"))
    current_browser = base_browser
    current_host = visa_host

    12.times do
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      if target.host == jump_host
        namespace = (current_host == visa_host) ? "VISA_APP" : "AUTH_APP"
        target, = decode_social_jump_target!(target, issuer_namespace: namespace, issuer_host: current_host)
      end

      case target.host
      when visa_host
        base_browser.host!(visa_host)
        base_browser.https!
        base_browser.get(target.request_uri, headers: social_navigation_headers(visa_host, site: "cross-site"))
        current_browser = base_browser
        current_host = visa_host
      when auth_host
        host!(auth_host)
        https!
        get(target.request_uri, headers: social_navigation_headers(auth_host, site: "cross-site"))
        current_browser = self
        current_host = auth_host
      else
        raise "unexpected social bootstrap host: #{target.host.inspect}"
      end
    end

    raise "social authorization bootstrap did not reach Auth" unless current_browser.equal?(self)
    raise "social authorization bootstrap did not render Auth entry" unless response.successful?

    initial_rt
  end

  def switch_social_browser_to_sign_up!(base_browser:, auth_host:, visa_host:)
    switch_form = inertia_props.fetch("switch_form")
    csrf = switch_form.fetch("authenticity_token")

    post(
      switch_form.fetch("action"),
      params: { to: "sign_up", ri: "jp", authenticity_token: csrf },
      headers: social_navigation_headers(auth_host, site: "same-origin").merge(
        "Origin" => "https://#{auth_host}",
        "X-CSRF-Token" => csrf,
      ),
    )
    raise "Sign Up switch did not start" unless response.redirect?

    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    current_browser = self
    current_host = auth_host

    12.times do
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      if target.host == jump_host
        namespace = (current_host == auth_host) ? "AUTH_APP" : "VISA_APP"
        target, = decode_social_jump_target!(target, issuer_namespace: namespace, issuer_host: current_host)
      end

      case target.host
      when visa_host
        base_browser.host!(visa_host)
        base_browser.https!
        base_browser.get(target.request_uri, headers: social_navigation_headers(visa_host, site: "cross-site"))
        current_browser = base_browser
        current_host = visa_host
      when auth_host
        host!(auth_host)
        https!
        get(target.request_uri, headers: social_navigation_headers(auth_host, site: "cross-site"))
        current_browser = self
        current_host = auth_host
      else
        raise "unexpected Sign Up switch host: #{target.host.inspect}"
      end
    end

    raise "Sign Up switch did not settle on Auth" unless current_browser.equal?(self) && response.successful?
  end

  def decode_social_jump_target!(uri, issuer_namespace:, issuer_host:)
    token = Rack::Utils.parse_query(uri.query.to_s).fetch("rt")
    issuer = JitSecurityJwtRegistry.surface(issuer_namespace)
    payload, = JWT.decode(
      token,
      JitSecurityJwtRegistry.public_key_for(issuer.id, issuer.current_kid),
      true,
      algorithms: ["ES384"],
      verify_iss: true,
      iss: "https://#{issuer_host}",
      verify_aud: true,
      aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
    )
    [URI.parse(payload.fetch("url")), token]
  end

  def social_navigation_headers(host, site:)
    {
      "Host" => host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => site,
    }
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

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
  end

  def create_verified_visitor_with_email(email_address: "visitor-#{SecureRandom.hex(4)}@example.com")
    ensure_visitor_reference_records!
    visitor = Visitor.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::NOTHING,
      visibility_id: VisitorVisibility::VISITOR,
    )
    VisitorEmail.create!(
      visitor_id: visitor.id, address: email_address,
      address_digest: IdentifierBlindIndex.bidx_for_email(email_address, realm: :com),
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
    visitor.reload
  end

  def mark_token_step_up_satisfied_for_test(token, scope:)
    actor = token.actor_record
    token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
    credential = actor.client_totp_credentials.find_by(
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    ) || ClientTotpCredential.create_for_user!(
      user: actor, user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    requirement = StepUpRequirement.new(
      step_up_required: true, scope: scope, allowed_methods: [:totp],
      phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
      ttl: 15.minutes, purpose: "step_up", audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true, actor_ref: actor.public_id,
      resource_ref: nil, tenant_ref: nil,
    )
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: (scope == "settings_email") ? "/identity/emails" : "/settings/google",
      base_browser_nonce: nonce, base_token: token,
    )
    transaction = issuance.transaction
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    attached, raw_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    digest = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: issuance.reference, nonce: nonce)
    binding.confirm_base!(base_token: token, browser_digest: digest)
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface: "app", expected_intent: "step_up", binding: binding,
      raw_auth_sid: raw_sid,
    )
    admitted, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", previous_raw_sid: raw_sid,
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    # This fixture exercises Social authorization; TOTP code verification has its own public-boundary tests.
    transaction.record_verification!(
      method: "totp", aal: "aal1", phishing_resistant: false, user_verified: false,
      verified_at: transaction.class.database_now, verified_credential_ref: credential.public_id,
    )
    proof = BaseAuthAdmissionCoordinator.issue_result!(transaction: transaction, ceremony_session_ref: admitted.id.to_s)
    IdentityStepUpCeremonyFreshnessCommitter.call!(
      actor: actor, token: token, transaction: transaction, requirement: requirement, result_reference: proof.reference,
    )
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
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
