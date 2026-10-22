# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AppleSocialFlowsTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :app_preference_chronicle_levels

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.enabled = true
    # The ceremony runs on the Auth host the application is configured with: a request
    # made to any other host gets a session cookie the application does not read back,
    # so the sign-up ticket is lost and the flow restarts instead of advancing.
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @callback_headers = social_callback_headers(@host)
  end

  teardown do
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.enabled = false
  end

  test "confirmation refuses show and update without a sign-up flow and changes nothing" do
    assert_no_difference(["Client.count", "ClientSignUpFlow.count"]) do
      get sign_app_sign_up_check_apple_confirmation_url(ri: "jp"), headers: @callback_headers

      assert_response :conflict

      patch sign_app_sign_up_check_apple_confirmation_url(ri: "jp"),
            params: { confirm_new_social_identity: "1" },
            headers: @callback_headers

      assert_response :conflict
    end
  end

  test "sign up waits for confirmation before creating user and identity" do
    state =
      begin
        flow0_provider = "apple"
        flow0_intent = "login"
        flow0_user = nil
        flow0_entry = "sign_up"
        flow0_ri = "jp"
        flow0_rt = nil
        flow0_referer = nil
        unless flow0_intent.to_s == "link"
          @base_browser = open_session
          flow0_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          flow0_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.host!(flow0_base_host)
          @base_browser.https!
          @base_browser.get("/sign", params: { ri: flow0_ri, pt: "/dashboard?ri=#{flow0_ri}" })
          flow0_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
          flow0_fields =
            flow0_form.css("input[name]").to_h { |flow0_input|
              [
                flow0_input["name"],
                flow0_input["value"],
              ]
            }
          @base_browser.post(
            flow0_form["action"], params: flow0_fields, headers: {
              "Origin" => "https://#{flow0_base_host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
          flow0_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
          2.times do |flow0_index|
            flow0_target = URI.parse(@base_browser.response.location)
            # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
            unless flow0_target.host == flow0_base_host
              flow0_rt = Rack::Utils.parse_query(flow0_target.query).fetch("rt")
              flow0_payload, = JWT.decode(
                flow0_rt, JitSecurityJwtRegistry.public_key_for(
                  flow0_issuer.id,
                  flow0_issuer.current_kid,
                ), true,
                algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow0_base_host}",
                verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
              )
              flow0_target = URI.parse(flow0_payload.fetch("url"))
            end
            if flow0_index.zero?
              raise RuntimeError,
                    "Base authorization host mismatch" unless flow0_target.host == flow0_base_host

              @base_browser.get(flow0_target.request_uri)
              flow0_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
              flow0_fields =
                flow0_form.css("input[name]").to_h { |flow0_input|
                  [
                    flow0_input["name"],
                    flow0_input["value"],
                  ]
                }
              @base_browser.post(
                flow0_form["action"], params: flow0_fields, headers: {
                  "Origin" => "https://#{flow0_base_host}", "Sec-Fetch-Site" => "same-origin",
                },
              )
            else
              raise RuntimeError, "Auth admission host mismatch" unless flow0_target.host == flow0_auth_host

              host!(flow0_auth_host)
              https!
              get(flow0_target.request_uri)
            end
          end
          3.times do |flow0_index|
            flow0_sender = (flow0_index == 1) ? @base_browser : self
            flow0_form = Nokogiri::HTML(flow0_sender.response.body).at_css("form")
            flow0_fields =
              flow0_form.css("input[name]").to_h { |flow0_input|
                [
                  flow0_input["name"],
                  flow0_input["value"],
                ]
              }
            flow0_sender.post(
              flow0_form["action"], params: flow0_fields, headers: {
                "Origin" => "https://#{(flow0_index == 1) ? flow0_base_host : flow0_auth_host}",
                "Sec-Fetch-Site" => "same-origin",
              },
            )
            raise RuntimeError,
                  "Social admission failed at step #{flow0_index}" unless flow0_sender.response.status == 303
            next if flow0_index == 2

            flow0_receiver = flow0_index.zero? ? @base_browser : self
            flow0_receiver.get(URI.parse(flow0_sender.response.location).request_uri)
          end
        end
        flow0_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host!(flow0_host)
        flow0_normalized_provider = SocialIdentifiable.normalize_provider(flow0_provider)
        flow0_continue_path =
          if flow0_intent.to_s == "link"
            ((if flow0_normalized_provider == "google"
                auth_app_settings_google_path(ri: flow0_ri)
              else
                auth_app_settings_apple_path(ri: flow0_ri)
              end))
          elsif flow0_entry.to_s == "sign_up"
            ((flow0_normalized_provider == "google") ? auth_app_social_google_registration_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ) : auth_app_social_apple_registration_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ))
          else
            ((flow0_normalized_provider == "google") ? auth_app_social_google_session_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ) : auth_app_social_apple_session_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ))
          end
        flow0_headers = social_callback_headers(flow0_host)
        flow0_headers["Referer"] = flow0_referer if flow0_referer.present?
        if flow0_user
          flow0_user_headers =
            as_user_headers(flow0_user, host: flow0_host)
          flow0_token = ClientToken.find_by(public_id: flow0_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            flow0_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if flow0_intent.to_s == "link" && flow0_token
          flow0_headers = flow0_headers.merge(flow0_user_headers)
        end
        post(flow0_continue_path, headers: flow0_headers)
        social_auth_state_from_response
      end
    setup_apple_mock_auth(uid: "apple_flow_signup")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
            params: { state: state },
            headers: @callback_headers
      end
    end

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to sign_app_sign_up_check_apple_confirmation_url(
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
    # The social sign-up checkpoint asks for an explicit confirmation before an identity is
    # created; the page object names that component and carries the label it asks agreement to.
    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component
    assert_predicate inertia_props.fetch("confirm_label"), :present?

    cycle = ClientSignUpFlow.order(:id).last
    patch sign_app_sign_up_check_apple_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    ),
          params: { confirm_new_social_identity: "1", checkpoint_version: cycle.checkpoint_version },
          headers: @callback_headers

    assert_redirected_to sign_app_sign_up_check_apple_birthdate_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: SignUpCycleLocator.new(
          session,
          surface: :app,
        ).current,
        surface: :app,
      ),
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        patch sign_app_sign_up_check_apple_birthdate_url(
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
                checkpoint_version: cycle.reload.checkpoint_version,
              },
              headers: @callback_headers
      end
    end

    assert_response :redirect
    assert_equal "/social/authentication/completion", URI.parse(response.location).path

    assert_difference("Client.count", 1) do
      assert_difference("ClientAppleIdentity.count", 1) do
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
            flow1_owner_cookie << "#{flow1_rails_cookie}=#{Rack::Utils.escape(
              response
                            .cookies.fetch(flow1_rails_cookie),
            )}"
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
          post(
            flow1_form["action"],
            params: flow1_fields,
            headers: flow1_base_headers,
          )
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
            post(
              flow1_form["action"],
              params: flow1_fields,
              headers: flow1_base_headers,
            )
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
                  ActiveSupport::IsolatedExecutionState[flow1_executor_key] =
                    flow1_outer_execution
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
                  ActiveSupport::IsolatedExecutionState[flow1_executor_key] =
                    flow1_outer_execution
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
      end
    end
  end

  test "cancel after unknown Apple callback creates nothing durable" do
    state =
      begin
        flow2_provider = "apple"
        flow2_intent = "login"
        flow2_user = nil
        flow2_entry = "sign_up"
        flow2_ri = "jp"
        flow2_rt = nil
        flow2_referer = nil
        unless flow2_intent.to_s == "link"
          @base_browser = open_session
          flow2_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          flow2_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.host!(flow2_base_host)
          @base_browser.https!
          @base_browser.get("/sign", params: { ri: flow2_ri, pt: "/dashboard?ri=#{flow2_ri}" })
          flow2_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
          flow2_fields =
            flow2_form.css("input[name]").to_h { |flow2_input|
              [
                flow2_input["name"],
                flow2_input["value"],
              ]
            }
          @base_browser.post(
            flow2_form["action"], params: flow2_fields, headers: {
              "Origin" => "https://#{flow2_base_host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
          flow2_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
          2.times do |flow2_index|
            flow2_target = URI.parse(@base_browser.response.location)
            # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
            unless flow2_target.host == flow2_base_host
              flow2_rt = Rack::Utils.parse_query(flow2_target.query).fetch("rt")
              flow2_payload, = JWT.decode(
                flow2_rt, JitSecurityJwtRegistry.public_key_for(
                  flow2_issuer.id,
                  flow2_issuer.current_kid,
                ), true,
                algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow2_base_host}",
                verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
              )
              flow2_target = URI.parse(flow2_payload.fetch("url"))
            end
            if flow2_index.zero?
              raise RuntimeError,
                    "Base authorization host mismatch" unless flow2_target.host == flow2_base_host

              @base_browser.get(flow2_target.request_uri)
              flow2_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
              flow2_fields =
                flow2_form.css("input[name]").to_h { |flow2_input|
                  [
                    flow2_input["name"],
                    flow2_input["value"],
                  ]
                }
              @base_browser.post(
                flow2_form["action"], params: flow2_fields, headers: {
                  "Origin" => "https://#{flow2_base_host}", "Sec-Fetch-Site" => "same-origin",
                },
              )
            else
              raise RuntimeError, "Auth admission host mismatch" unless flow2_target.host == flow2_auth_host

              host!(flow2_auth_host)
              https!
              get(flow2_target.request_uri)
            end
          end
          3.times do |flow2_index|
            flow2_sender = (flow2_index == 1) ? @base_browser : self
            flow2_form = Nokogiri::HTML(flow2_sender.response.body).at_css("form")
            flow2_fields =
              flow2_form.css("input[name]").to_h { |flow2_input|
                [
                  flow2_input["name"],
                  flow2_input["value"],
                ]
              }
            flow2_sender.post(
              flow2_form["action"], params: flow2_fields, headers: {
                "Origin" => "https://#{(flow2_index == 1) ? flow2_base_host : flow2_auth_host}",
                "Sec-Fetch-Site" => "same-origin",
              },
            )
            raise RuntimeError,
                  "Social admission failed at step #{flow2_index}" unless flow2_sender.response.status == 303
            next if flow2_index == 2

            flow2_receiver = flow2_index.zero? ? @base_browser : self
            flow2_receiver.get(URI.parse(flow2_sender.response.location).request_uri)
          end
        end
        flow2_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host!(flow2_host)
        flow2_normalized_provider = SocialIdentifiable.normalize_provider(flow2_provider)
        flow2_continue_path =
          if flow2_intent.to_s == "link"
            ((if flow2_normalized_provider == "google"
                auth_app_settings_google_path(ri: flow2_ri)
              else
                auth_app_settings_apple_path(ri: flow2_ri)
              end))
          elsif flow2_entry.to_s == "sign_up"
            ((flow2_normalized_provider == "google") ? auth_app_social_google_registration_path(
              ri: flow2_ri,
              rt: flow2_rt,
            ) : auth_app_social_apple_registration_path(
              ri: flow2_ri,
              rt: flow2_rt,
            ))
          else
            ((flow2_normalized_provider == "google") ? auth_app_social_google_session_path(
              ri: flow2_ri,
              rt: flow2_rt,
            ) : auth_app_social_apple_session_path(
              ri: flow2_ri,
              rt: flow2_rt,
            ))
          end
        flow2_headers = social_callback_headers(flow2_host)
        flow2_headers["Referer"] = flow2_referer if flow2_referer.present?
        if flow2_user
          flow2_user_headers =
            as_user_headers(flow2_user, host: flow2_host)
          flow2_token = ClientToken.find_by(public_id: flow2_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            flow2_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if flow2_intent.to_s == "link" && flow2_token
          flow2_headers = flow2_headers.merge(flow2_user_headers)
        end
        post(flow2_continue_path, headers: flow2_headers)
        social_auth_state_from_response
      end
    setup_apple_mock_auth(uid: "apple_flow_cancel")

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: @callback_headers

    assert_redirected_to sign_app_sign_up_guard_apple_url(ri: "jp")

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        delete sign_app_sign_up_check_apple_confirmation_url(
          ri: "jp", fb: SignFlowBindingCodec.encode(
            flow: SignUpCycleLocator.new(
              session,
              surface: :app,
            ).current,
            surface: :app,
          ),
        ), headers: @callback_headers
      end
    end

    assert_redirected_to sign_app_sign_up_url(ri: "jp")
    assert_nil ClientAppleIdentity.find_by(uid: "apple_flow_cancel")
  end

  test "sign in uses existing identity" do
    user = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: "2000-01-01")
    ClientAccount.create!(user_id: user.id)
    ClientAppleIdentity.create!(
      user: user,
      uid: "apple_flow_existing",
      provider: "apple",
      token: "token_old",
      token_expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    state =
      begin
        flow3_intent = "login"
        flow3_user = nil
        begin
          flow4_provider = "apple"
          flow4_intent = flow3_intent
          flow4_user = flow3_user
          flow4_entry = nil
          flow4_ri = "jp"
          flow4_rt = nil
          flow4_referer = nil
          unless flow4_intent.to_s == "link"
            @base_browser = open_session
            flow4_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow4_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow4_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow4_ri,
                pt: "/dashboard?ri=#{flow4_ri}",
              },
            )
            flow4_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow4_fields =
              flow4_form.css("input[name]").to_h { |flow4_input|
                [
                  flow4_input["name"],
                  flow4_input["value"],
                ]
              }
            @base_browser.post(
              flow4_form["action"], params: flow4_fields, headers: {
                "Origin" => "https://#{flow4_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow4_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow4_index|
              flow4_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow4_target.host == flow4_base_host
                flow4_rt = Rack::Utils.parse_query(flow4_target.query).fetch("rt")
                flow4_payload, = JWT.decode(
                  flow4_rt, JitSecurityJwtRegistry.public_key_for(
                    flow4_issuer.id,
                    flow4_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow4_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow4_target = URI.parse(flow4_payload.fetch("url"))
              end
              if flow4_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow4_target.host == flow4_base_host

                @base_browser.get(flow4_target.request_uri)
                flow4_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow4_fields =
                  flow4_form.css("input[name]").to_h { |flow4_input|
                    [
                      flow4_input["name"],
                      flow4_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow4_form["action"], params: flow4_fields, headers: {
                    "Origin" => "https://#{flow4_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow4_target.host == flow4_auth_host

                host!(flow4_auth_host)
                https!
                get(flow4_target.request_uri)
              end
            end
            3.times do |flow4_index|
              flow4_sender = (flow4_index == 1) ? @base_browser : self
              flow4_form = Nokogiri::HTML(flow4_sender.response.body).at_css("form")
              flow4_fields =
                flow4_form.css("input[name]").to_h { |flow4_input|
                  [
                    flow4_input["name"],
                    flow4_input["value"],
                  ]
                }
              flow4_sender.post(
                flow4_form["action"], params: flow4_fields, headers: {
                  "Origin" => "https://#{(flow4_index == 1) ? flow4_base_host : flow4_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow4_index}" unless flow4_sender.response.status == 303
              next if flow4_index == 2

              flow4_receiver = flow4_index.zero? ? @base_browser : self
              flow4_receiver.get(URI.parse(flow4_sender.response.location).request_uri)
            end
          end
          flow4_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow4_host)
          flow4_normalized_provider = SocialIdentifiable.normalize_provider(flow4_provider)
          flow4_continue_path =
            if flow4_intent.to_s == "link"
              ((if flow4_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow4_ri)
                else
                  auth_app_settings_apple_path(ri: flow4_ri)
                end))
            elsif flow4_entry.to_s == "sign_up"
              ((flow4_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow4_ri,
                rt: flow4_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow4_ri,
                rt: flow4_rt,
              ))
            else
              ((flow4_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow4_ri,
                rt: flow4_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow4_ri,
                rt: flow4_rt,
              ))
            end
          flow4_headers = social_callback_headers(flow4_host)
          flow4_headers["Referer"] = flow4_referer if flow4_referer.present?
          if flow4_user
            flow4_user_headers =
              as_user_headers(flow4_user, host: flow4_host)
            flow4_token = ClientToken.find_by(public_id: flow4_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow4_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow4_intent.to_s == "link" && flow4_token
            flow4_headers = flow4_headers.merge(flow4_user_headers)
          end
          post(flow4_continue_path, headers: flow4_headers)
          social_auth_state_from_response
        end
      end
    setup_apple_mock_auth(uid: "apple_flow_existing", token: "token_new")

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: @callback_headers

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
          flow5_form["action"], params: flow5_fields, headers: {
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
          surface: "app", transaction_id: flow5_ceremony.authorization_transaction_ref,
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
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow5_target = URI.parse(response.location)
        flow5_principal = Client.find_by!(public_id: flow5_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow5_principal)
      end
      break unless flow5_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion /oauth/authorize).include?(flow5_target.path)

      flow5_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow5_base_cookie = @base_browser.cookies.to_hash.map { |flow5_name, flow5_value|
        "#{flow5_name}=#{Rack::Utils.escape(flow5_value)}"
      }.join("; ")
      flow5_base_headers = { "Origin" => "https://#{flow5_base_host}",
                             "Sec-Fetch-Site" => "same-origin",
                             "Cookie" => flow5_base_cookie,
                             "HTTP_COOKIE" => flow5_base_cookie, }
      host!(flow5_base_host)
      https!
      get(flow5_target.request_uri, headers: flow5_base_headers)
      flow5_form = response.parsed_body.at_css("form")
      flow5_fields =
        flow5_form.css("input[name]").to_h { |flow5_input|
          [
            flow5_input["name"],
            flow5_input["value"],
          ]
        }
      post(flow5_form["action"], params: flow5_fields, headers: flow5_base_headers)
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
        post(flow5_form["action"], params: flow5_fields, headers: flow5_base_headers)
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
          flow5_rt, JitSecurityJwtRegistry.public_key_for(flow5_issuer.id, flow5_issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow5_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
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
                flow5_env.url.request_uri, params: Rack::Utils.parse_query(flow5_env.body),
                                           headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow5_executor_key] = flow5_outer_execution
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
              ActiveSupport::IsolatedExecutionState[flow5_executor_key] = flow5_outer_execution
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
          flow5_builder.adapter(:test, flow5_transport)
        end
      OutboundHttp::Connection.stub(
        :build, ->(**flow5_args) {
          assert_equal flow5_base_host, flow5_args.fetch(:url).host
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

    assert_response :redirect
    redirect_uri = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), redirect_uri.host
    assert_equal "/dashboard", redirect_uri.path
    assert_equal "ri=jp", redirect_uri.query
  end

  private

  def setup_apple_mock_auth(uid:, token: "apple_token")
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: token,
        refresh_token: "apple_refresh_token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: { id_info: { nonce: session[:social_auth_nonce] } },
    )
  end

  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class AppleSocialFlowsTest
  private
end

# DAMP local helper copy for former shared test support.
class AppleSocialFlowsTest
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
class AppleSocialFlowsTest
  private
end

# DAMP local route helper aliases for former shared test support.
class AppleSocialFlowsTest
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
class AppleSocialFlowsTest
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
