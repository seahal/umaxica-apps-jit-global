# typed: false
# frozen_string_literal: true

require "test_helper"
require "support/external_identity_test_helper"
# require "helpers/global_test_support"

class AppleAuthTest < ActionDispatch::IntegrationTest
  include ExternalIdentityTestHelper

  fixtures :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.enabled = true
    # The ceremony runs on the Auth host the application is configured with: a request
    # made to any other host gets a session cookie the application does not read back,
    # so the sign-up ticket is lost and the flow restarts instead of advancing.
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:apple] = nil
    OmniAuth.config.mock_auth[:google] = nil
    TurnstileVerifierStub.enabled = false
  end

  test "first Apple login waits for confirmation before creating user" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    begin
      flow0_provider = "apple"
      flow0_entry = "sign_up"
      @social_state =
        begin
          flow1_provider = flow0_provider
          flow1_intent = "login"
          flow1_user = nil
          flow1_entry = flow0_entry
          flow1_ri = "jp"
          flow1_rt = nil
          flow1_referer = nil
          unless flow1_intent.to_s == "link"
            @base_browser = open_session
            flow1_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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
            flow1_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow1_index|
              flow1_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow1_target.host == flow1_base_host
                flow1_rt = Rack::Utils.parse_query(flow1_target.query).fetch("rt")
                flow1_payload, = JWT.decode(
                  flow1_rt, JitSecurityJwtRegistry.public_key_for(
                    flow1_issuer.id,
                    flow1_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow1_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow1_target = URI.parse(flow1_payload.fetch("url"))
              end
              if flow1_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow1_target.host == flow1_base_host

                @base_browser.get(flow1_target.request_uri)
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
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow1_target.host == flow1_auth_host

                host!(flow1_auth_host)
                https!
                get(flow1_target.request_uri)
              end
            end
            3.times do |flow1_index|
              flow1_sender = (flow1_index == 1) ? @base_browser : self
              flow1_form = Nokogiri::HTML(flow1_sender.response.body).at_css("form")
              flow1_fields =
                flow1_form.css("input[name]").to_h { |flow1_input|
                  [
                    flow1_input["name"],
                    flow1_input["value"],
                  ]
                }
              flow1_sender.post(
                flow1_form["action"], params: flow1_fields, headers: {
                  "Origin" => "https://#{(flow1_index == 1) ? flow1_base_host : flow1_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow1_index}" unless flow1_sender.response.status == 303
              next if flow1_index == 2

              flow1_receiver = flow1_index.zero? ? @base_browser : self
              flow1_receiver.get(URI.parse(flow1_sender.response.location).request_uri)
            end
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
    end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_new",
        info: {},
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        get auth_app_social_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
            headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    @social_signup_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_predicate @social_signup_binding, :present?
    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(ri: "jp", fb: @social_signup_binding)
    follow_redirect!

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?

    assert_difference("Client.count", 1) do
      assert_difference("ClientExternalIdentity.count", 1) do
        begin
          flow2_cycle = ClientSignUpFlow.order(:id).last
          flow2_provider = flow2_cycle.social_provider
          flow2_binding = request.query_parameters.fetch("fb")

          patch(
            ((flow2_provider == "google") ? sign_app_sign_up_check_google_confirmation_url(
              ri: "jp",
              fb: flow2_binding,
            ) : sign_app_sign_up_check_apple_confirmation_url(
              ri: "jp",
              fb: flow2_binding,
            )),
            params: {
              confirm_new_social_identity: "1",
              checkpoint_version: flow2_cycle.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

          assert_response :redirect
          flow2_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

          patch(
            ((flow2_provider == "google") ? sign_app_sign_up_check_google_birthdate_url(
              ri: "jp",
              fb: flow2_binding,
            ) : sign_app_sign_up_check_apple_birthdate_url(
              ri: "jp",
              fb: flow2_binding,
            )),
            params: {
              requirement: "birthdate",
              birthdate: "2000-02-03",
              checkpoint_version: flow2_cycle.reload.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

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
              flow3_owner_cookie << "#{flow3_rails_cookie}=#{Rack::Utils.escape(
                response
                                .cookies.fetch(flow3_rails_cookie),
              )}"
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
        end
      end
    end

    identity = ClientExternalIdentity.find_by!(provider: "apple", subject: "apple_uid_new")
    user = Client.find(identity.client_id)

    assert_equal ClientStatus::VERIFIED_WITH_SIGN_UP, user.status_id
    assert_nil ClientEmail.find_by(user_id: user.id)
  end

  test "callback initializes preference timezone options when missing" do
    ComSettingRecord.connected_to(role: :writing) do
      AppPreferenceTimezone.delete_all
      AppPreferenceRegion.delete_all
      AppPreferenceLanguage.delete_all
      AppPreferenceTheme.delete_all
      AppPreferenceCookie.delete_all
      AppPreference.delete_all
      AppPreferenceTimezoneOption.delete_all
      AppPreferenceRegionOption.delete_all
      AppPreferenceLanguageOption.delete_all
      AppPreferenceThemeOption.delete_all
    end

    begin
      flow4_provider = "apple"
      flow4_entry = "sign_up"
      @social_state =
        begin
          flow5_provider = flow4_provider
          flow5_intent = "login"
          flow5_user = nil
          flow5_entry = flow4_entry
          flow5_ri = "jp"
          flow5_rt = nil
          flow5_referer = nil
          unless flow5_intent.to_s == "link"
            @base_browser = open_session
            flow5_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow5_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow5_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow5_ri,
                pt: "/dashboard?ri=#{flow5_ri}",
              },
            )
            flow5_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow5_fields =
              flow5_form.css("input[name]").to_h { |flow5_input|
                [
                  flow5_input["name"],
                  flow5_input["value"],
                ]
              }
            @base_browser.post(
              flow5_form["action"], params: flow5_fields, headers: {
                "Origin" => "https://#{flow5_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow5_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow5_index|
              flow5_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow5_target.host == flow5_base_host
                flow5_rt = Rack::Utils.parse_query(flow5_target.query).fetch("rt")
                flow5_payload, = JWT.decode(
                  flow5_rt, JitSecurityJwtRegistry.public_key_for(
                    flow5_issuer.id,
                    flow5_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow5_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow5_target = URI.parse(flow5_payload.fetch("url"))
              end
              if flow5_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow5_target.host == flow5_base_host

                @base_browser.get(flow5_target.request_uri)
                flow5_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow5_fields =
                  flow5_form.css("input[name]").to_h { |flow5_input|
                    [
                      flow5_input["name"],
                      flow5_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow5_form["action"], params: flow5_fields, headers: {
                    "Origin" => "https://#{flow5_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow5_target.host == flow5_auth_host

                host!(flow5_auth_host)
                https!
                get(flow5_target.request_uri)
              end
            end
            3.times do |flow5_index|
              flow5_sender = (flow5_index == 1) ? @base_browser : self
              flow5_form = Nokogiri::HTML(flow5_sender.response.body).at_css("form")
              flow5_fields =
                flow5_form.css("input[name]").to_h { |flow5_input|
                  [
                    flow5_input["name"],
                    flow5_input["value"],
                  ]
                }
              flow5_sender.post(
                flow5_form["action"], params: flow5_fields, headers: {
                  "Origin" => "https://#{(flow5_index == 1) ? flow5_base_host : flow5_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow5_index}" unless flow5_sender.response.status == 303
              next if flow5_index == 2

              flow5_receiver = flow5_index.zero? ? @base_browser : self
              flow5_receiver.get(URI.parse(flow5_sender.response.location).request_uri)
            end
          end
          flow5_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow5_host)
          flow5_normalized_provider = SocialIdentifiable.normalize_provider(flow5_provider)
          flow5_continue_path =
            if flow5_intent.to_s == "link"
              ((if flow5_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow5_ri)
                else
                  auth_app_settings_apple_path(ri: flow5_ri)
                end))
            elsif flow5_entry.to_s == "sign_up"
              ((flow5_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow5_ri,
                rt: flow5_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow5_ri,
                rt: flow5_rt,
              ))
            else
              ((flow5_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow5_ri,
                rt: flow5_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow5_ri,
                rt: flow5_rt,
              ))
            end
          flow5_headers = social_callback_headers(flow5_host)
          flow5_headers["Referer"] = flow5_referer if flow5_referer.present?
          if flow5_user
            flow5_user_headers =
              as_user_headers(flow5_user, host: flow5_host)
            flow5_token = ClientToken.find_by(public_id: flow5_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow5_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow5_intent.to_s == "link" && flow5_token
            flow5_headers = flow5_headers.merge(flow5_user_headers)
          end
          post(flow5_continue_path, headers: flow5_headers)
          social_auth_state_from_response
        end
    end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_pref_#{SecureRandom.hex(4)}",
        info: {},
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
        headers: browser_headers.merge(@callback_headers)

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")

    ComSettingRecord.connected_to(role: :writing) do
      assert AppPreferenceTimezoneOption.exists?(id: AppPreferenceTimezoneOption::ASIA_TOKYO)
      assert_predicate AppPreferenceTimezone, :exists?
    end
  end

  test "should sign in existing user normally" do
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    ClientAppleIdentity.create!(
      user: user,
      uid: "apple_uid_existing",
      provider: "apple",
      token: "existing_token",
      token_expires_at: 1.week.from_now.to_i,
    )

    begin
      flow6_provider = "apple"
      flow6_entry = "sign_in"
      @social_state =
        begin
          flow7_provider = flow6_provider
          flow7_intent = "login"
          flow7_user = nil
          flow7_entry = flow6_entry
          flow7_ri = "jp"
          flow7_rt = nil
          flow7_referer = nil
          unless flow7_intent.to_s == "link"
            @base_browser = open_session
            flow7_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow7_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow7_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow7_ri,
                pt: "/dashboard?ri=#{flow7_ri}",
              },
            )
            flow7_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow7_fields =
              flow7_form.css("input[name]").to_h { |flow7_input|
                [
                  flow7_input["name"],
                  flow7_input["value"],
                ]
              }
            @base_browser.post(
              flow7_form["action"], params: flow7_fields, headers: {
                "Origin" => "https://#{flow7_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow7_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow7_index|
              flow7_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow7_target.host == flow7_base_host
                flow7_rt = Rack::Utils.parse_query(flow7_target.query).fetch("rt")
                flow7_payload, = JWT.decode(
                  flow7_rt, JitSecurityJwtRegistry.public_key_for(
                    flow7_issuer.id,
                    flow7_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow7_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow7_target = URI.parse(flow7_payload.fetch("url"))
              end
              if flow7_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow7_target.host == flow7_base_host

                @base_browser.get(flow7_target.request_uri)
                flow7_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow7_fields =
                  flow7_form.css("input[name]").to_h { |flow7_input|
                    [
                      flow7_input["name"],
                      flow7_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow7_form["action"], params: flow7_fields, headers: {
                    "Origin" => "https://#{flow7_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow7_target.host == flow7_auth_host

                host!(flow7_auth_host)
                https!
                get(flow7_target.request_uri)
              end
            end
            3.times do |flow7_index|
              flow7_sender = (flow7_index == 1) ? @base_browser : self
              flow7_form = Nokogiri::HTML(flow7_sender.response.body).at_css("form")
              flow7_fields =
                flow7_form.css("input[name]").to_h { |flow7_input|
                  [
                    flow7_input["name"],
                    flow7_input["value"],
                  ]
                }
              flow7_sender.post(
                flow7_form["action"], params: flow7_fields, headers: {
                  "Origin" => "https://#{(flow7_index == 1) ? flow7_base_host : flow7_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow7_index}" unless flow7_sender.response.status == 303
              next if flow7_index == 2

              flow7_receiver = flow7_index.zero? ? @base_browser : self
              flow7_receiver.get(URI.parse(flow7_sender.response.location).request_uri)
            end
          end
          flow7_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow7_host)
          flow7_normalized_provider = SocialIdentifiable.normalize_provider(flow7_provider)
          flow7_continue_path =
            if flow7_intent.to_s == "link"
              ((if flow7_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow7_ri)
                else
                  auth_app_settings_apple_path(ri: flow7_ri)
                end))
            elsif flow7_entry.to_s == "sign_up"
              ((flow7_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow7_ri,
                rt: flow7_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow7_ri,
                rt: flow7_rt,
              ))
            else
              ((flow7_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow7_ri,
                rt: flow7_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow7_ri,
                rt: flow7_rt,
              ))
            end
          flow7_headers = social_callback_headers(flow7_host)
          flow7_headers["Referer"] = flow7_referer if flow7_referer.present?
          if flow7_user
            flow7_user_headers =
              as_user_headers(flow7_user, host: flow7_host)
            flow7_token = ClientToken.find_by(public_id: flow7_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow7_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow7_intent.to_s == "link" && flow7_token
            flow7_headers = flow7_headers.merge(flow7_user_headers)
          end
          post(flow7_continue_path, headers: flow7_headers)
          social_auth_state_from_response
        end
    end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_existing",
        info: {},
        credentials: {
          token: "new_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
        headers: browser_headers.merge(@callback_headers)

    assert_equal URI.parse(auth_app_sign_in_check_url(ri: "jp")).path, URI.parse(response.location).path
    assert_not ClientToken.exists?(user_id: user.id), "ClientToken must not be created before login completion"
  end

  # ============================================================================
  # Regression tests: Email-less social login
  # IMPORTANT: These tests verify that social login works WITHOUT email
  # ============================================================================

  test "Apple login without email waits for confirmation before creating user" do
    # Requirement: Social login MUST work with provider+uid ONLY, NO email
    begin
      flow8_provider = "apple"
      flow8_entry = "sign_up"
      @social_state =
        begin
          flow9_provider = flow8_provider
          flow9_intent = "login"
          flow9_user = nil
          flow9_entry = flow8_entry
          flow9_ri = "jp"
          flow9_rt = nil
          flow9_referer = nil
          unless flow9_intent.to_s == "link"
            @base_browser = open_session
            flow9_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow9_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow9_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow9_ri,
                pt: "/dashboard?ri=#{flow9_ri}",
              },
            )
            flow9_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow9_fields =
              flow9_form.css("input[name]").to_h { |flow9_input|
                [
                  flow9_input["name"],
                  flow9_input["value"],
                ]
              }
            @base_browser.post(
              flow9_form["action"], params: flow9_fields, headers: {
                "Origin" => "https://#{flow9_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow9_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow9_index|
              flow9_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow9_target.host == flow9_base_host
                flow9_rt = Rack::Utils.parse_query(flow9_target.query).fetch("rt")
                flow9_payload, = JWT.decode(
                  flow9_rt, JitSecurityJwtRegistry.public_key_for(
                    flow9_issuer.id,
                    flow9_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow9_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow9_target = URI.parse(flow9_payload.fetch("url"))
              end
              if flow9_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow9_target.host == flow9_base_host

                @base_browser.get(flow9_target.request_uri)
                flow9_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow9_fields =
                  flow9_form.css("input[name]").to_h { |flow9_input|
                    [
                      flow9_input["name"],
                      flow9_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow9_form["action"], params: flow9_fields, headers: {
                    "Origin" => "https://#{flow9_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow9_target.host == flow9_auth_host

                host!(flow9_auth_host)
                https!
                get(flow9_target.request_uri)
              end
            end
            3.times do |flow9_index|
              flow9_sender = (flow9_index == 1) ? @base_browser : self
              flow9_form = Nokogiri::HTML(flow9_sender.response.body).at_css("form")
              flow9_fields =
                flow9_form.css("input[name]").to_h { |flow9_input|
                  [
                    flow9_input["name"],
                    flow9_input["value"],
                  ]
                }
              flow9_sender.post(
                flow9_form["action"], params: flow9_fields, headers: {
                  "Origin" => "https://#{(flow9_index == 1) ? flow9_base_host : flow9_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow9_index}" unless flow9_sender.response.status == 303
              next if flow9_index == 2

              flow9_receiver = flow9_index.zero? ? @base_browser : self
              flow9_receiver.get(URI.parse(flow9_sender.response.location).request_uri)
            end
          end
          flow9_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow9_host)
          flow9_normalized_provider = SocialIdentifiable.normalize_provider(flow9_provider)
          flow9_continue_path =
            if flow9_intent.to_s == "link"
              ((if flow9_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow9_ri)
                else
                  auth_app_settings_apple_path(ri: flow9_ri)
                end))
            elsif flow9_entry.to_s == "sign_up"
              ((flow9_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow9_ri,
                rt: flow9_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow9_ri,
                rt: flow9_rt,
              ))
            else
              ((flow9_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow9_ri,
                rt: flow9_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow9_ri,
                rt: flow9_rt,
              ))
            end
          flow9_headers = social_callback_headers(flow9_host)
          flow9_headers["Referer"] = flow9_referer if flow9_referer.present?
          if flow9_user
            flow9_user_headers =
              as_user_headers(flow9_user, host: flow9_host)
            flow9_token = ClientToken.find_by(public_id: flow9_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow9_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow9_intent.to_s == "link" && flow9_token
            flow9_headers = flow9_headers.merge(flow9_user_headers)
          end
          post(flow9_continue_path, headers: flow9_headers)
          social_auth_state_from_response
        end
    end

    uid = "apple_uid_no_email_#{SecureRandom.hex(4)}"
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: uid,
        info: {}, # Deliberately empty - no email provided
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        get auth_app_social_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
            headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    @social_signup_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_predicate @social_signup_binding, :present?
    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(ri: "jp", fb: @social_signup_binding)
    follow_redirect!

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?

    assert_difference("Client.count", 1) do
      assert_difference("ClientExternalIdentity.count", 1) do
        begin
          flow10_cycle = ClientSignUpFlow.order(:id).last
          flow10_provider = flow10_cycle.social_provider
          flow10_binding = request.query_parameters.fetch("fb")

          patch(
            ((flow10_provider == "google") ? sign_app_sign_up_check_google_confirmation_url(
              ri: "jp",
              fb: flow10_binding,
            ) : sign_app_sign_up_check_apple_confirmation_url(
              ri: "jp",
              fb: flow10_binding,
            )),
            params: {
              confirm_new_social_identity: "1",
              checkpoint_version: flow10_cycle.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

          assert_response :redirect
          flow10_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

          patch(
            ((flow10_provider == "google") ? sign_app_sign_up_check_google_birthdate_url(
              ri: "jp",
              fb: flow10_binding,
            ) : sign_app_sign_up_check_apple_birthdate_url(
              ri: "jp",
              fb: flow10_binding,
            )),
            params: {
              requirement: "birthdate",
              birthdate: "2000-02-03",
              checkpoint_version: flow10_cycle.reload.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

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
                flow11_form["action"], params: flow11_fields, headers: {
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
                surface: "app", transaction_id: flow11_ceremony.authorization_transaction_ref,
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
                  "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
                },
              )
              flow11_target = URI.parse(response.location)
              flow11_principal = Client.find_by!(public_id: flow11_parent.reload.actor_ref)
              BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow11_principal)
            end
            break unless flow11_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
              %w(/social/authentication/completion /oauth/authorize).include?(flow11_target.path)

            flow11_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow11_base_cookie = @base_browser.cookies.to_hash.map { |flow11_name, flow11_value|
              "#{flow11_name}=#{Rack::Utils.escape(flow11_value)}"
            }.join("; ")
            flow11_base_headers = { "Origin" => "https://#{flow11_base_host}",
                                    "Sec-Fetch-Site" => "same-origin",
                                    "Cookie" => flow11_base_cookie,
                                    "HTTP_COOKIE" => flow11_base_cookie, }
            host!(flow11_base_host)
            https!
            get(flow11_target.request_uri, headers: flow11_base_headers)
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
              get(URI.parse(response.location).request_uri, headers: flow11_base_headers)
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

                  # Do not print the outer request or credentials on failure.
                  assert_equal [true, true, 200],
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow11_outer_controller),
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
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow11_outer_controller),
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
              :build, ->(**flow11_args) {
                assert_equal flow11_base_host, flow11_args.fetch(:url).host
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
        end
      end
    end

    identity = ClientExternalIdentity.find_by(provider: "apple", subject: uid)

    assert_not_nil identity, "ClientAppleIdentity identity should exist"
    assert_predicate identity.client_id, :present?, "Client should be associated with identity"

    # CRITICAL: Verify NO email was saved
    user = Client.find(identity.client_id)

    assert_nil ClientEmail.find_by(user_id: user.id), "NO ClientEmail should exist for social login user"
  end

  test "Apple login without email does not save email to ClientAppleIdentity after confirmation" do
    # Even though ClientAppleIdentity schema may have an email column (legacy),
    # we MUST NOT write to it during social login
    begin
      flow12_provider = "apple"
      flow12_entry = "sign_up"
      @social_state =
        begin
          flow13_provider = flow12_provider
          flow13_intent = "login"
          flow13_user = nil
          flow13_entry = flow12_entry
          flow13_ri = "jp"
          flow13_rt = nil
          flow13_referer = nil
          unless flow13_intent.to_s == "link"
            @base_browser = open_session
            flow13_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow13_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow13_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow13_ri,
                pt: "/dashboard?ri=#{flow13_ri}",
              },
            )
            flow13_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow13_fields =
              flow13_form.css("input[name]").to_h { |flow13_input|
                [
                  flow13_input["name"],
                  flow13_input["value"],
                ]
              }
            @base_browser.post(
              flow13_form["action"], params: flow13_fields, headers: {
                "Origin" => "https://#{flow13_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow13_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow13_index|
              flow13_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow13_target.host == flow13_base_host
                flow13_rt = Rack::Utils.parse_query(flow13_target.query).fetch("rt")
                flow13_payload, = JWT.decode(
                  flow13_rt, JitSecurityJwtRegistry.public_key_for(
                    flow13_issuer.id,
                    flow13_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow13_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow13_target = URI.parse(flow13_payload.fetch("url"))
              end
              if flow13_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow13_target.host == flow13_base_host

                @base_browser.get(flow13_target.request_uri)
                flow13_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow13_fields =
                  flow13_form.css("input[name]").to_h { |flow13_input|
                    [
                      flow13_input["name"],
                      flow13_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow13_form["action"], params: flow13_fields, headers: {
                    "Origin" => "https://#{flow13_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow13_target.host == flow13_auth_host

                host!(flow13_auth_host)
                https!
                get(flow13_target.request_uri)
              end
            end
            3.times do |flow13_index|
              flow13_sender = (flow13_index == 1) ? @base_browser : self
              flow13_form = Nokogiri::HTML(flow13_sender.response.body).at_css("form")
              flow13_fields =
                flow13_form.css("input[name]").to_h { |flow13_input|
                  [
                    flow13_input["name"],
                    flow13_input["value"],
                  ]
                }
              flow13_sender.post(
                flow13_form["action"], params: flow13_fields, headers: {
                  "Origin" => "https://#{(flow13_index == 1) ? flow13_base_host : flow13_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow13_index}" unless flow13_sender.response.status == 303
              next if flow13_index == 2

              flow13_receiver = flow13_index.zero? ? @base_browser : self
              flow13_receiver.get(URI.parse(flow13_sender.response.location).request_uri)
            end
          end
          flow13_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow13_host)
          flow13_normalized_provider = SocialIdentifiable.normalize_provider(flow13_provider)
          flow13_continue_path =
            if flow13_intent.to_s == "link"
              ((if flow13_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow13_ri)
                else
                  auth_app_settings_apple_path(ri: flow13_ri)
                end))
            elsif flow13_entry.to_s == "sign_up"
              ((flow13_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ))
            else
              ((flow13_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ))
            end
          flow13_headers = social_callback_headers(flow13_host)
          flow13_headers["Referer"] = flow13_referer if flow13_referer.present?
          if flow13_user
            flow13_user_headers =
              as_user_headers(flow13_user, host: flow13_host)
            flow13_token = ClientToken.find_by(public_id: flow13_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow13_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow13_intent.to_s == "link" && flow13_token
            flow13_headers = flow13_headers.merge(flow13_user_headers)
          end
          post(flow13_continue_path, headers: flow13_headers)
          social_auth_state_from_response
        end
    end

    uid = "apple_uid_verify_no_email_#{SecureRandom.hex(4)}"
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: uid,
        info: {}, # No email in auth hash
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp", state: @social_state),
        headers: browser_headers.merge(@callback_headers)

    assert_response :redirect
    follow_redirect!
    follow_redirect!

    assert_difference("Client.count", 1) do
      assert_difference("ClientExternalIdentity.count", 1) do
        begin
          flow14_cycle = ClientSignUpFlow.order(:id).last
          flow14_provider = flow14_cycle.social_provider
          flow14_binding = request.query_parameters.fetch("fb")

          patch(
            ((flow14_provider == "google") ? sign_app_sign_up_check_google_confirmation_url(
              ri: "jp",
              fb: flow14_binding,
            ) : sign_app_sign_up_check_apple_confirmation_url(
              ri: "jp",
              fb: flow14_binding,
            )),
            params: {
              confirm_new_social_identity: "1",
              checkpoint_version: flow14_cycle.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

          assert_response :redirect
          flow14_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

          patch(
            ((flow14_provider == "google") ? sign_app_sign_up_check_google_birthdate_url(
              ri: "jp",
              fb: flow14_binding,
            ) : sign_app_sign_up_check_apple_birthdate_url(
              ri: "jp",
              fb: flow14_binding,
            )),
            params: {
              requirement: "birthdate",
              birthdate: "2000-02-03",
              checkpoint_version: flow14_cycle.reload.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

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
                flow15_form["action"], params: flow15_fields, headers: {
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
                surface: "app", transaction_id: flow15_ceremony.authorization_transaction_ref,
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
                  "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
                },
              )
              flow15_target = URI.parse(response.location)
              flow15_principal = Client.find_by!(public_id: flow15_parent.reload.actor_ref)
              BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow15_principal)
            end
            break unless flow15_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
              %w(/social/authentication/completion /oauth/authorize).include?(flow15_target.path)

            flow15_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow15_base_cookie = @base_browser.cookies.to_hash.map { |flow15_name, flow15_value|
              "#{flow15_name}=#{Rack::Utils.escape(flow15_value)}"
            }.join("; ")
            flow15_base_headers = { "Origin" => "https://#{flow15_base_host}",
                                    "Sec-Fetch-Site" => "same-origin",
                                    "Cookie" => flow15_base_cookie,
                                    "HTTP_COOKIE" => flow15_base_cookie, }
            host!(flow15_base_host)
            https!
            get(flow15_target.request_uri, headers: flow15_base_headers)
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
              get(URI.parse(response.location).request_uri, headers: flow15_base_headers)
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

                  # Do not print the outer request or credentials on failure.
                  assert_equal [true, true, 200],
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow15_outer_controller),
                                Actor.context.equal?(flow15_outer_actor), flow15_protocol_browser.response.status,]
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

                  # Do not print the outer request or credentials on failure.
                  assert_equal [true, true, 200],
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow15_outer_controller),
                                Actor.context.equal?(flow15_outer_actor), flow15_protocol_browser.response.status,]
                  [flow15_protocol_browser.response.status, { "Content-Type" => "application/json" },
                   flow15_protocol_browser.response.body,]
                end
              end
            flow15_connection =
              Faraday.new do |flow15_builder|
                flow15_builder.request(:url_encoded)
                flow15_builder.adapter(:test, flow15_transport)
              end
            OutboundHttp::Connection.stub(
              :build, ->(**flow15_args) {
                assert_equal flow15_base_host, flow15_args.fetch(:url).host
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
        end
      end
    end

    identity = ClientExternalIdentity.find_by(provider: "apple", subject: uid)

    assert_not_nil identity

    # Verify email column is NOT populated (if it exists in schema)
    # This ensures we don't accidentally write email even if the column exists
    if identity.respond_to?(:email)
      assert_nil identity.email, "ClientAppleIdentity.email should be nil"
    end
  end

  test "Google login without email waits for confirmation before creating user" do
    # Same requirement applies to Google
    OmniAuth.config.test_mode = true

    begin
      flow16_provider = "google_app"
      flow16_entry = "sign_up"
      @social_state =
        begin
          flow17_provider = flow16_provider
          flow17_intent = "login"
          flow17_user = nil
          flow17_entry = flow16_entry
          flow17_ri = "jp"
          flow17_rt = nil
          flow17_referer = nil
          unless flow17_intent.to_s == "link"
            @base_browser = open_session
            flow17_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow17_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow17_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow17_ri,
                pt: "/dashboard?ri=#{flow17_ri}",
              },
            )
            flow17_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow17_fields =
              flow17_form.css("input[name]").to_h { |flow17_input|
                [
                  flow17_input["name"],
                  flow17_input["value"],
                ]
              }
            @base_browser.post(
              flow17_form["action"], params: flow17_fields, headers: {
                "Origin" => "https://#{flow17_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow17_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow17_index|
              flow17_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow17_target.host == flow17_base_host
                flow17_rt = Rack::Utils.parse_query(flow17_target.query).fetch("rt")
                flow17_payload, = JWT.decode(
                  flow17_rt, JitSecurityJwtRegistry.public_key_for(
                    flow17_issuer.id,
                    flow17_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow17_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow17_target = URI.parse(flow17_payload.fetch("url"))
              end
              if flow17_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow17_target.host == flow17_base_host

                @base_browser.get(flow17_target.request_uri)
                flow17_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow17_fields =
                  flow17_form.css("input[name]").to_h { |flow17_input|
                    [
                      flow17_input["name"],
                      flow17_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow17_form["action"], params: flow17_fields, headers: {
                    "Origin" => "https://#{flow17_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow17_target.host == flow17_auth_host

                host!(flow17_auth_host)
                https!
                get(flow17_target.request_uri)
              end
            end
            3.times do |flow17_index|
              flow17_sender = (flow17_index == 1) ? @base_browser : self
              flow17_form = Nokogiri::HTML(flow17_sender.response.body).at_css("form")
              flow17_fields =
                flow17_form.css("input[name]").to_h { |flow17_input|
                  [
                    flow17_input["name"],
                    flow17_input["value"],
                  ]
                }
              flow17_sender.post(
                flow17_form["action"], params: flow17_fields, headers: {
                  "Origin" => "https://#{(flow17_index == 1) ? flow17_base_host : flow17_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow17_index}" unless flow17_sender.response.status == 303
              next if flow17_index == 2

              flow17_receiver = flow17_index.zero? ? @base_browser : self
              flow17_receiver.get(URI.parse(flow17_sender.response.location).request_uri)
            end
          end
          flow17_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow17_host)
          flow17_normalized_provider = SocialIdentifiable.normalize_provider(flow17_provider)
          flow17_continue_path =
            if flow17_intent.to_s == "link"
              ((if flow17_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow17_ri)
                else
                  auth_app_settings_apple_path(ri: flow17_ri)
                end))
            elsif flow17_entry.to_s == "sign_up"
              ((flow17_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ))
            else
              ((flow17_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ))
            end
          flow17_headers = social_callback_headers(flow17_host)
          flow17_headers["Referer"] = flow17_referer if flow17_referer.present?
          if flow17_user
            flow17_user_headers =
              as_user_headers(flow17_user, host: flow17_host)
            flow17_token = ClientToken.find_by(public_id: flow17_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow17_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow17_intent.to_s == "link" && flow17_token
            flow17_headers = flow17_headers.merge(flow17_user_headers)
          end
          post(flow17_continue_path, headers: flow17_headers)
          social_auth_state_from_response
        end
    end

    uid = "google_uid_no_email_#{SecureRandom.hex(4)}"
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: uid,
        info: { image: "https://example.com/image.jpg" }, # No email
        credentials: {
          token: "google_token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientExternalIdentity.count") do
        get auth_app_social_google_callback_url(ri: "jp", state: @social_state),
            headers: browser_headers.merge(@callback_headers)
      end
    end

    assert_redirected_to sign_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    @social_signup_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

    assert_predicate @social_signup_binding, :present?
    assert_redirected_to sign_app_sign_up_check_google_confirmation_url(ri: "jp", fb: @social_signup_binding)
    follow_redirect!

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?

    assert_difference("Client.count", 1) do
      assert_difference("ClientExternalIdentity.count", 1) do
        begin
          flow18_cycle = ClientSignUpFlow.order(:id).last
          flow18_provider = flow18_cycle.social_provider
          flow18_binding = request.query_parameters.fetch("fb")

          patch(
            ((flow18_provider == "google") ? sign_app_sign_up_check_google_confirmation_url(
              ri: "jp",
              fb: flow18_binding,
            ) : sign_app_sign_up_check_apple_confirmation_url(
              ri: "jp",
              fb: flow18_binding,
            )),
            params: {
              confirm_new_social_identity: "1",
              checkpoint_version: flow18_cycle.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

          assert_response :redirect
          flow18_binding = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("fb")

          patch(
            ((flow18_provider == "google") ? sign_app_sign_up_check_google_birthdate_url(
              ri: "jp",
              fb: flow18_binding,
            ) : sign_app_sign_up_check_apple_birthdate_url(
              ri: "jp",
              fb: flow18_binding,
            )),
            params: {
              requirement: "birthdate",
              birthdate: "2000-02-03",
              checkpoint_version: flow18_cycle.reload.checkpoint_version,
            },
            headers: browser_headers.merge(@callback_headers),
          )

          1.times do
            if response.media_type == "text/html" && response.body.include?("social-completion-form")
              flow19_form = response.parsed_body.at_css("form#social-completion-form")
              flow19_fields =
                flow19_form.css("input[name]").to_h { |flow19_input|
                  [
                    flow19_input["name"],
                    flow19_input["value"],
                  ]
                }
              flow19_rails_cookie = Rails.application.config.session_options.fetch(:key)
              flow19_owner_cookie =
                request.headers["Cookie"].to_s.split("; ")
                  .reject { |flow19_pair| flow19_pair.start_with?("#{flow19_rails_cookie}=") }
              flow19_owner_cookie << "#{flow19_rails_cookie}=#{Rack::Utils.escape(
                response
                                .cookies.fetch(flow19_rails_cookie),
              )}"
              post(
                flow19_form["action"], params: flow19_fields, headers: {
                  "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
                  "Cookie" => flow19_owner_cookie.join("; "),
                  "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              break
            end
            break unless response.redirect? && @base_browser

            flow19_target = URI.parse(response.location)
            if flow19_target.path == "/sign/in/check"
              flow19_sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
              flow19_ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(cookies[flow19_sid_cookie])
              flow19_parent = OidcAuthorizationTransactionCoordinator.find_by_transaction_id!(
                surface: "app", transaction_id: flow19_ceremony.authorization_transaction_ref,
              )
              get(auth_app_sign_oidc_handoff_path(ri: "jp"))
              flow19_form = response.parsed_body.at_css("form")
              flow19_fields =
                flow19_form.css("input[name]").to_h { |flow19_input|
                  [
                    flow19_input["name"],
                    flow19_input["value"],
                  ]
                }
              post(
                flow19_form["action"], params: flow19_fields, headers: {
                  "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
                },
              )
              flow19_target = URI.parse(response.location)
              flow19_principal = Client.find_by!(public_id: flow19_parent.reload.actor_ref)
              BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow19_principal)
            end
            break unless flow19_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
              %w(/social/authentication/completion /oauth/authorize).include?(flow19_target.path)

            flow19_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow19_base_cookie = @base_browser.cookies.to_hash.map { |flow19_name, flow19_value|
              "#{flow19_name}=#{Rack::Utils.escape(flow19_value)}"
            }.join("; ")
            flow19_base_headers = { "Origin" => "https://#{flow19_base_host}",
                                    "Sec-Fetch-Site" => "same-origin",
                                    "Cookie" => flow19_base_cookie,
                                    "HTTP_COOKIE" => flow19_base_cookie, }
            host!(flow19_base_host)
            https!
            get(flow19_target.request_uri, headers: flow19_base_headers)
            flow19_form = response.parsed_body.at_css("form")
            flow19_fields =
              flow19_form.css("input[name]").to_h { |flow19_input|
                [
                  flow19_input["name"],
                  flow19_input["value"],
                ]
              }
            post(
              flow19_form["action"],
              params: flow19_fields,
              headers: flow19_base_headers,
            )
            if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
              get(URI.parse(response.location).request_uri, headers: flow19_base_headers)
              flow19_form = response.parsed_body.at_css("form")
              flow19_fields =
                flow19_form.css("input[name]").to_h { |flow19_input|
                  [
                    flow19_input["name"],
                    flow19_input["value"],
                  ]
                }
              post(
                flow19_form["action"],
                params: flow19_fields,
                headers: flow19_base_headers,
              )
            end
            break unless response.redirect?
            # The Base self-RP callback is same-origin and arrives by path; a cross-origin one comes through Jump.
            break unless URI.parse(response.location).path == "/oidc/callback" ||
              URI.parse(response.location).host ==
                URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host

            flow19_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            flow19_callback_uri = URI.parse(response.location)
            # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
            unless flow19_callback_uri.host == flow19_base_host
              flow19_rt = Rack::Utils.parse_query(flow19_callback_uri.query).fetch("rt")
              flow19_payload, = JWT.decode(
                flow19_rt, JitSecurityJwtRegistry.public_key_for(
                  flow19_issuer.id,
                  flow19_issuer.current_kid,
                ), true,
                algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow19_base_host}",
                verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
              )
              flow19_callback_uri = URI.parse(flow19_payload.fetch("url"))
            end
            flow19_protocol_browser = open_session
            flow19_protocol_browser.host!(flow19_base_host)
            flow19_protocol_browser.https!
            # Substitute network transport only: the token and UserInfo requests still run
            # through their real public controllers, including PKCE and client authentication.
            flow19_transport =
              Faraday::Adapter::Test::Stubs.new do |flow19_stub|
                flow19_stub.post(/.*/) do |flow19_env|
                  # The nested Rack executor must not complete the in-flight callback.
                  flow19_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                  flow19_outer_actor = Actor.context
                  flow19_executor_key = Rails.application.executor.active_key
                  flow19_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow19_executor_key)
                  begin
                    flow19_protocol_browser.host!(flow19_env.url.authority)
                    flow19_protocol_browser.https!(flow19_env.url.scheme == "https")
                    flow19_protocol_browser.post(
                      flow19_env.url.request_uri,
                      params: Rack::Utils.parse_query(flow19_env.body),
                      headers: { "Accept" => "application/json" },
                    )
                  ensure
                    ActiveSupport::IsolatedExecutionState[flow19_executor_key] =
                      flow19_outer_execution
                  end

                  # Do not print the outer request or credentials on failure.
                  assert_equal [true, true, 200],
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow19_outer_controller),
                                Actor.context.equal?(flow19_outer_actor), flow19_protocol_browser.response.status,]
                  [flow19_protocol_browser.response.status, { "Content-Type" => "application/json" },
                   flow19_protocol_browser.response.body,]
                end
                flow19_stub.get(/.*/) do |flow19_env|
                  flow19_outer_controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
                  flow19_outer_actor = Actor.context
                  flow19_executor_key = Rails.application.executor.active_key
                  flow19_outer_execution = ActiveSupport::IsolatedExecutionState.delete(flow19_executor_key)
                  begin
                    flow19_protocol_browser.host!(flow19_env.url.authority)
                    flow19_protocol_browser.https!(flow19_env.url.scheme == "https")
                    flow19_protocol_browser.get(
                      flow19_env.url.request_uri, headers: {
                        "Authorization" => flow19_env.request_headers.fetch("Authorization"),
                        "Accept" => "application/json",
                      },
                    )
                  ensure
                    ActiveSupport::IsolatedExecutionState[flow19_executor_key] =
                      flow19_outer_execution
                  end

                  # Do not print the outer request or credentials on failure.
                  assert_equal [true, true, 200],
                               [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow19_outer_controller),
                                Actor.context.equal?(flow19_outer_actor), flow19_protocol_browser.response.status,]
                  [flow19_protocol_browser.response.status, { "Content-Type" => "application/json" },
                   flow19_protocol_browser.response.body,]
                end
              end
            flow19_connection =
              Faraday.new do |flow19_builder|
                flow19_builder.request(:url_encoded)
                flow19_builder.adapter(:test, flow19_transport)
              end
            OutboundHttp::Connection.stub(
              :build, ->(**flow19_args) {
                assert_equal flow19_base_host, flow19_args.fetch(:url).host
                flow19_connection
              },
            ) do
              TestSupport::OutboundHttpGuard.allow do
                get(flow19_callback_uri.request_uri)
              end
            end

            assert_equal [true, true, true],
                         [response.redirect?,
                          cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE].to_s.present?,
                          cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE].to_s.present?,]
            flow19_transport.verify_stubbed_calls
          end
        end
      end
    end

    identity = ClientExternalIdentity.find_by(provider: "google", subject: uid)

    assert_not_nil identity
    assert_nil ClientEmail.find_by(user_id: identity.client_id), "NO ClientEmail for Google login user"

    # Verify email column is NOT populated
    if identity.respond_to?(:email)
      assert_nil identity.email, "ClientGoogleIdentity.email should be nil"
    end
  end

  private

  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class AppleAuthTest
  private
end

# DAMP local helper copy for former shared test support.
class AppleAuthTest
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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
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
class AppleAuthTest
  private
end

# DAMP local route helper aliases for former shared test support.
class AppleAuthTest
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
class AppleAuthTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )
  PREFERENCE_JWT_KEY = OpenSSL::PKey::EC.generate("secp384r1") unless const_defined?(:PREFERENCE_JWT_KEY, false)

  private

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

  def ensure_visitor_reference_records!
    VisitorStatus.find_or_create_by!(id: VisitorStatus::NOTHING)
    VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
    VisitorMfaLevel.find_or_create_by!(id: VisitorMfaLevel::NOTHING)
    VisitorMfaStatus.find_or_create_by!(id: VisitorMfaStatus::UNCONFIGURED)
    VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
    VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
    VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
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

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
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
