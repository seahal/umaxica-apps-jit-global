# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OmniauthCallbacksTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses,
           :client_totp_credential_statuses

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    # The ceremony runs on the Auth host the application is configured with: a request
    # made to any other host gets a session cookie the application does not read back,
    # so the sign-up ticket is lost and the flow restarts instead of advancing.
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    @expected_redirect = %r{\Ahttps?://#{Regexp.escape(@host)}/.*}.freeze
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    ClientTokenBindingMethod.ensure_defaults!
    ClientTokenDbscStatus.ensure_defaults!
    ClientTokenKind.ensure_defaults!
    ClientTokenStatus.ensure_defaults!
  end

  test "unknown Google identity enters sign up checkpoint instead of signing in" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "123456789",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow0_provider = "google"
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

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        get auth_app_social_google_callback_url(ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
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

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?
  end

  test "google callback without region parameter is processed without regional redirect" do
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "google_no_region_#{SecureRandom.hex(4)}",
        info: {},
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow1_provider = "google"
        begin
          flow2_provider = flow1_provider
          flow2_intent = "login"
          flow2_user = nil
          flow2_entry = nil
          flow2_ri = "jp"
          flow2_rt = nil
          flow2_referer = nil
          unless flow2_intent.to_s == "link"
            @base_browser = open_session
            flow2_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow2_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow2_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow2_ri,
                pt: "/dashboard?ri=#{flow2_ri}",
              },
            )
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
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow2_target.host == flow2_auth_host

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
      end

    get auth_app_social_google_callback_url,
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
    assert_not_includes response.location, "code="
  end

  test "unknown Apple identity enters sign up checkpoint instead of signing in" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    state =
      begin
        flow3_provider = "apple"
        flow3_intent = "login"
        flow3_user = nil
        flow3_entry = "sign_up"
        flow3_ri = "jp"
        flow3_rt = nil
        flow3_referer = nil
        unless flow3_intent.to_s == "link"
          @base_browser = open_session
          flow3_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          flow3_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.host!(flow3_base_host)
          @base_browser.https!
          @base_browser.get("/sign", params: { ri: flow3_ri, pt: "/dashboard?ri=#{flow3_ri}" })
          flow3_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
          flow3_fields =
            flow3_form.css("input[name]").to_h { |flow3_input|
              [
                flow3_input["name"],
                flow3_input["value"],
              ]
            }
          @base_browser.post(
            flow3_form["action"], params: flow3_fields, headers: {
              "Origin" => "https://#{flow3_base_host}", "Sec-Fetch-Site" => "same-origin",
            },
          )
          flow3_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
          2.times do |flow3_index|
            flow3_target = URI.parse(@base_browser.response.location)
            # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
            unless flow3_target.host == flow3_base_host
              flow3_rt = Rack::Utils.parse_query(flow3_target.query).fetch("rt")
              flow3_payload, = JWT.decode(
                flow3_rt, JitSecurityJwtRegistry.public_key_for(
                  flow3_issuer.id,
                  flow3_issuer.current_kid,
                ), true,
                algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow3_base_host}",
                verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
              )
              flow3_target = URI.parse(flow3_payload.fetch("url"))
            end
            if flow3_index.zero?
              raise RuntimeError,
                    "Base authorization host mismatch" unless flow3_target.host == flow3_base_host

              @base_browser.get(flow3_target.request_uri)
              flow3_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
              flow3_fields =
                flow3_form.css("input[name]").to_h { |flow3_input|
                  [
                    flow3_input["name"],
                    flow3_input["value"],
                  ]
                }
              @base_browser.post(
                flow3_form["action"], params: flow3_fields, headers: {
                  "Origin" => "https://#{flow3_base_host}", "Sec-Fetch-Site" => "same-origin",
                },
              )
            else
              raise RuntimeError, "Auth admission host mismatch" unless flow3_target.host == flow3_auth_host

              host!(flow3_auth_host)
              https!
              get(flow3_target.request_uri)
            end
          end
          3.times do |flow3_index|
            flow3_sender = (flow3_index == 1) ? @base_browser : self
            flow3_form = Nokogiri::HTML(flow3_sender.response.body).at_css("form")
            flow3_fields =
              flow3_form.css("input[name]").to_h { |flow3_input|
                [
                  flow3_input["name"],
                  flow3_input["value"],
                ]
              }
            flow3_sender.post(
              flow3_form["action"], params: flow3_fields, headers: {
                "Origin" => "https://#{(flow3_index == 1) ? flow3_base_host : flow3_auth_host}",
                "Sec-Fetch-Site" => "same-origin",
              },
            )
            raise RuntimeError,
                  "Social admission failed at step #{flow3_index}" unless flow3_sender.response.status == 303
            next if flow3_index == 2

            flow3_receiver = flow3_index.zero? ? @base_browser : self
            flow3_receiver.get(URI.parse(flow3_sender.response.location).request_uri)
          end
        end
        flow3_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host!(flow3_host)
        flow3_normalized_provider = SocialIdentifiable.normalize_provider(flow3_provider)
        flow3_continue_path =
          if flow3_intent.to_s == "link"
            ((if flow3_normalized_provider == "google"
                auth_app_settings_google_path(ri: flow3_ri)
              else
                auth_app_settings_apple_path(ri: flow3_ri)
              end))
          elsif flow3_entry.to_s == "sign_up"
            ((flow3_normalized_provider == "google") ? auth_app_social_google_registration_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ) : auth_app_social_apple_registration_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ))
          else
            ((flow3_normalized_provider == "google") ? auth_app_social_google_session_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ) : auth_app_social_apple_session_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ))
          end
        flow3_headers = social_callback_headers(flow3_host)
        flow3_headers["Referer"] = flow3_referer if flow3_referer.present?
        if flow3_user
          flow3_user_headers =
            as_user_headers(flow3_user, host: flow3_host)
          flow3_token = ClientToken.find_by(public_id: flow3_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            flow3_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if flow3_intent.to_s == "link" && flow3_token
          flow3_headers = flow3_headers.merge(flow3_user_headers)
        end
        post(flow3_continue_path, headers: flow3_headers)
        social_auth_state_from_response
      end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_123",
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
      assert_no_difference("ClientAppleIdentity.count") do
        get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
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

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?
  end

  test "unknown Apple GET callback enters sign up checkpoint instead of signing in" do
    state =
      begin
        flow4_provider = "apple"
        flow4_intent = "login"
        flow4_user = nil
        flow4_entry = "sign_up"
        flow4_ri = "jp"
        flow4_rt = nil
        flow4_referer = nil
        unless flow4_intent.to_s == "link"
          @base_browser = open_session
          flow4_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          flow4_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.host!(flow4_base_host)
          @base_browser.https!
          @base_browser.get("/sign", params: { ri: flow4_ri, pt: "/dashboard?ri=#{flow4_ri}" })
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
              raise RuntimeError, "Auth admission host mismatch" unless flow4_target.host == flow4_auth_host

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

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_get_callback_uid",
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
      assert_no_difference("ClientAppleIdentity.count") do
        get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
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

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?
  end

  test "apple social login with MFA enabled enters the ordinary MFA challenge" do
    user = Client.create!(birthdate: "2000-02-03", mfa_level_enabled: true)
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    ClientAppleIdentity.create!(
      user: user,
      uid: "apple_mfa_skip_uid",
      provider: "apple",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    state =
      begin
        flow5_provider = "apple"
        begin
          flow6_provider = flow5_provider
          flow6_intent = "login"
          flow6_user = nil
          flow6_entry = nil
          flow6_ri = "jp"
          flow6_rt = nil
          flow6_referer = nil
          unless flow6_intent.to_s == "link"
            @base_browser = open_session
            flow6_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow6_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow6_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow6_ri,
                pt: "/dashboard?ri=#{flow6_ri}",
              },
            )
            flow6_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow6_fields =
              flow6_form.css("input[name]").to_h { |flow6_input|
                [
                  flow6_input["name"],
                  flow6_input["value"],
                ]
              }
            @base_browser.post(
              flow6_form["action"], params: flow6_fields, headers: {
                "Origin" => "https://#{flow6_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow6_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow6_index|
              flow6_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow6_target.host == flow6_base_host
                flow6_rt = Rack::Utils.parse_query(flow6_target.query).fetch("rt")
                flow6_payload, = JWT.decode(
                  flow6_rt, JitSecurityJwtRegistry.public_key_for(
                    flow6_issuer.id,
                    flow6_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow6_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow6_target = URI.parse(flow6_payload.fetch("url"))
              end
              if flow6_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow6_target.host == flow6_base_host

                @base_browser.get(flow6_target.request_uri)
                flow6_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow6_fields =
                  flow6_form.css("input[name]").to_h { |flow6_input|
                    [
                      flow6_input["name"],
                      flow6_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow6_form["action"], params: flow6_fields, headers: {
                    "Origin" => "https://#{flow6_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow6_target.host == flow6_auth_host

                host!(flow6_auth_host)
                https!
                get(flow6_target.request_uri)
              end
            end
            3.times do |flow6_index|
              flow6_sender = (flow6_index == 1) ? @base_browser : self
              flow6_form = Nokogiri::HTML(flow6_sender.response.body).at_css("form")
              flow6_fields =
                flow6_form.css("input[name]").to_h { |flow6_input|
                  [
                    flow6_input["name"],
                    flow6_input["value"],
                  ]
                }
              flow6_sender.post(
                flow6_form["action"], params: flow6_fields, headers: {
                  "Origin" => "https://#{(flow6_index == 1) ? flow6_base_host : flow6_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow6_index}" unless flow6_sender.response.status == 303
              next if flow6_index == 2

              flow6_receiver = flow6_index.zero? ? @base_browser : self
              flow6_receiver.get(URI.parse(flow6_sender.response.location).request_uri)
            end
          end
          flow6_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow6_host)
          flow6_normalized_provider = SocialIdentifiable.normalize_provider(flow6_provider)
          flow6_continue_path =
            if flow6_intent.to_s == "link"
              ((if flow6_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow6_ri)
                else
                  auth_app_settings_apple_path(ri: flow6_ri)
                end))
            elsif flow6_entry.to_s == "sign_up"
              ((flow6_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ))
            else
              ((flow6_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ))
            end
          flow6_headers = social_callback_headers(flow6_host)
          flow6_headers["Referer"] = flow6_referer if flow6_referer.present?
          if flow6_user
            flow6_user_headers =
              as_user_headers(flow6_user, host: flow6_host)
            flow6_token = ClientToken.find_by(public_id: flow6_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow6_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow6_intent.to_s == "link" && flow6_token
            flow6_headers = flow6_headers.merge(flow6_user_headers)
          end
          post(flow6_continue_path, headers: flow6_headers)
          social_auth_state_from_response
        end
      end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_mfa_skip_uid",
        info: {},
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # The sign callback only hands evidence to Base. Base applies the ordinary
    # sign-in graph, where social is not a local MFA bypass.
    assert_emits_acme_completion_only!
    assert_response :redirect
    assert_match %r{/sign/in/challenge}, response.location
    assert_predicate session[:pending_mfa], :present?
  end

  test "should sign in with existing Google user" do
    user = Client.create!(birthdate: "2000-02-03")
    ClientGoogleIdentity.create!(
      user: user,
      uid: "existing_uid",
      provider: "google",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "existing_uid",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow7_provider = "google"
        begin
          flow8_provider = flow7_provider
          flow8_intent = "login"
          flow8_user = nil
          flow8_entry = nil
          flow8_ri = "jp"
          flow8_rt = nil
          flow8_referer = nil
          unless flow8_intent.to_s == "link"
            @base_browser = open_session
            flow8_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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
            flow8_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow8_index|
              flow8_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow8_target.host == flow8_base_host
                flow8_rt = Rack::Utils.parse_query(flow8_target.query).fetch("rt")
                flow8_payload, = JWT.decode(
                  flow8_rt, JitSecurityJwtRegistry.public_key_for(
                    flow8_issuer.id,
                    flow8_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow8_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow8_target = URI.parse(flow8_payload.fetch("url"))
              end
              if flow8_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow8_target.host == flow8_base_host

                @base_browser.get(flow8_target.request_uri)
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
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow8_target.host == flow8_auth_host

                host!(flow8_auth_host)
                https!
                get(flow8_target.request_uri)
              end
            end
            3.times do |flow8_index|
              flow8_sender = (flow8_index == 1) ? @base_browser : self
              flow8_form = Nokogiri::HTML(flow8_sender.response.body).at_css("form")
              flow8_fields =
                flow8_form.css("input[name]").to_h { |flow8_input|
                  [
                    flow8_input["name"],
                    flow8_input["value"],
                  ]
                }
              flow8_sender.post(
                flow8_form["action"], params: flow8_fields, headers: {
                  "Origin" => "https://#{(flow8_index == 1) ? flow8_base_host : flow8_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow8_index}" unless flow8_sender.response.status == 303
              next if flow8_index == 2

              flow8_receiver = flow8_index.zero? ? @base_browser : self
              flow8_receiver.get(URI.parse(flow8_sender.response.location).request_uri)
            end
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
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # Established social login is base authority: the sign callback emits a
    # one-shot completion form (evidence only) and the session is established on
    # base completion, which redirects to the Base Dashboard.
    assert_emits_acme_completion_only!

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
          flow9_form["action"], params: flow9_fields, headers: {
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
          surface: "app", transaction_id: flow9_ceremony.authorization_transaction_ref,
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
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
        flow9_target = URI.parse(response.location)
        flow9_principal = Client.find_by!(public_id: flow9_parent.reload.actor_ref)
        BaseSelectorBootstrapAuthority.call(surface: :app, principal: flow9_principal)
      end
      break unless flow9_target.host == ENV.fetch("PUBLIC_BASE_SERVICE_URL") &&
        %w(/social/authentication/completion /oauth/authorize).include?(flow9_target.path)

      flow9_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
      flow9_base_cookie = @base_browser.cookies.to_hash.map { |flow9_name, flow9_value|
        "#{flow9_name}=#{Rack::Utils.escape(flow9_value)}"
      }.join("; ")
      flow9_base_headers = { "Origin" => "https://#{flow9_base_host}",
                             "Sec-Fetch-Site" => "same-origin",
                             "Cookie" => flow9_base_cookie,
                             "HTTP_COOKIE" => flow9_base_cookie, }
      host!(flow9_base_host)
      https!
      get(flow9_target.request_uri, headers: flow9_base_headers)
      flow9_form = response.parsed_body.at_css("form")
      flow9_fields =
        flow9_form.css("input[name]").to_h { |flow9_input|
          [
            flow9_input["name"],
            flow9_input["value"],
          ]
        }
      post(flow9_form["action"], params: flow9_fields, headers: flow9_base_headers)
      if response.redirect? && URI.parse(response.location).path == "/oauth/authorize"
        get(URI.parse(response.location).request_uri, headers: flow9_base_headers)
        flow9_form = response.parsed_body.at_css("form")
        flow9_fields =
          flow9_form.css("input[name]").to_h { |flow9_input|
            [
              flow9_input["name"],
              flow9_input["value"],
            ]
          }
        post(flow9_form["action"], params: flow9_fields, headers: flow9_base_headers)
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
          flow9_rt, JitSecurityJwtRegistry.public_key_for(flow9_issuer.id, flow9_issuer.current_kid), true,
          algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow9_base_host}",
          verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
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
                flow9_env.url.request_uri, params: Rack::Utils.parse_query(flow9_env.body),
                                           headers: { "Accept" => "application/json" },
              )
            ensure
              ActiveSupport::IsolatedExecutionState[flow9_executor_key] = flow9_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow9_outer_controller),
                          Actor.context.equal?(flow9_outer_actor), flow9_protocol_browser.response.status,]
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
              ActiveSupport::IsolatedExecutionState[flow9_executor_key] = flow9_outer_execution
            end

            # Do not print the outer request or credentials on failure.
            assert_equal [true, true, 200],
                         [ActiveSupport::ExecutionContext.to_h.fetch(:controller).equal?(flow9_outer_controller),
                          Actor.context.equal?(flow9_outer_actor), flow9_protocol_browser.response.status,]
            [flow9_protocol_browser.response.status, { "Content-Type" => "application/json" },
             flow9_protocol_browser.response.body,]
          end
        end
      flow9_connection =
        Faraday.new do |flow9_builder|
          flow9_builder.request(:url_encoded)
          flow9_builder.adapter(:test, flow9_transport)
        end
      OutboundHttp::Connection.stub(
        :build, ->(**flow9_args) {
          assert_equal flow9_base_host, flow9_args.fetch(:url).host
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

    # Home `/` is 404 for an authenticated session, so ordinary sign-in lands on
    # `/dashboard` (adr/home-dashboard-authentication-boundary.md).
    landing = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), landing.host
    assert_equal "/dashboard", landing.path
  end

  test "existing Google identity without birthdate stays on login side" do
    user = Client.create!
    ClientGoogleIdentity.create!(
      user: user,
      uid: "existing_missing_birthdate_uid",
      provider: "google",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "existing_missing_birthdate_uid",
        info: {},
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow10_provider = "google"
        begin
          flow11_provider = flow10_provider
          flow11_intent = "login"
          flow11_user = nil
          flow11_entry = nil
          flow11_ri = "jp"
          flow11_rt = nil
          flow11_referer = nil
          unless flow11_intent.to_s == "link"
            @base_browser = open_session
            flow11_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
            flow11_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
            @base_browser.host!(flow11_base_host)
            @base_browser.https!
            @base_browser.get(
              "/sign", params: {
                ri: flow11_ri,
                pt: "/dashboard?ri=#{flow11_ri}",
              },
            )
            flow11_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
            flow11_fields =
              flow11_form.css("input[name]").to_h { |flow11_input|
                [
                  flow11_input["name"],
                  flow11_input["value"],
                ]
              }
            @base_browser.post(
              flow11_form["action"], params: flow11_fields, headers: {
                "Origin" => "https://#{flow11_base_host}", "Sec-Fetch-Site" => "same-origin",
              },
            )
            flow11_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow11_index|
              flow11_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow11_target.host == flow11_base_host
                flow11_rt = Rack::Utils.parse_query(flow11_target.query).fetch("rt")
                flow11_payload, = JWT.decode(
                  flow11_rt, JitSecurityJwtRegistry.public_key_for(
                    flow11_issuer.id,
                    flow11_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow11_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow11_target = URI.parse(flow11_payload.fetch("url"))
              end
              if flow11_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow11_target.host == flow11_base_host

                @base_browser.get(flow11_target.request_uri)
                flow11_form = Nokogiri::HTML(@base_browser.response.body).at_css("form")
                flow11_fields =
                  flow11_form.css("input[name]").to_h { |flow11_input|
                    [
                      flow11_input["name"],
                      flow11_input["value"],
                    ]
                  }
                @base_browser.post(
                  flow11_form["action"], params: flow11_fields, headers: {
                    "Origin" => "https://#{flow11_base_host}", "Sec-Fetch-Site" => "same-origin",
                  },
                )
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow11_target.host == flow11_auth_host

                host!(flow11_auth_host)
                https!
                get(flow11_target.request_uri)
              end
            end
            3.times do |flow11_index|
              flow11_sender = (flow11_index == 1) ? @base_browser : self
              flow11_form = Nokogiri::HTML(flow11_sender.response.body).at_css("form")
              flow11_fields =
                flow11_form.css("input[name]").to_h { |flow11_input|
                  [
                    flow11_input["name"],
                    flow11_input["value"],
                  ]
                }
              flow11_sender.post(
                flow11_form["action"], params: flow11_fields, headers: {
                  "Origin" => "https://#{(flow11_index == 1) ? flow11_base_host : flow11_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow11_index}" unless flow11_sender.response.status == 303
              next if flow11_index == 2

              flow11_receiver = flow11_index.zero? ? @base_browser : self
              flow11_receiver.get(URI.parse(flow11_sender.response.location).request_uri)
            end
          end
          flow11_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow11_host)
          flow11_normalized_provider = SocialIdentifiable.normalize_provider(flow11_provider)
          flow11_continue_path =
            if flow11_intent.to_s == "link"
              ((if flow11_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow11_ri)
                else
                  auth_app_settings_apple_path(ri: flow11_ri)
                end))
            elsif flow11_entry.to_s == "sign_up"
              ((flow11_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ))
            else
              ((flow11_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ))
            end
          flow11_headers = social_callback_headers(flow11_host)
          flow11_headers["Referer"] = flow11_referer if flow11_referer.present?
          if flow11_user
            flow11_user_headers =
              as_user_headers(flow11_user, host: flow11_host)
            flow11_token = ClientToken.find_by(public_id: flow11_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow11_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow11_intent.to_s == "link" && flow11_token
            flow11_headers = flow11_headers.merge(flow11_user_headers)
          end
          post(flow11_continue_path, headers: flow11_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_equal URI.parse(auth_app_sign_in_check_url(ri: "jp")).path, URI.parse(response.location).path
    assert_not ClientToken.exists?(user_id: user.id), "ClientToken must not be created before birthdate checkpoint"
  end

  test "social login with MFA enabled enters the ordinary MFA challenge" do
    user = Client.create!(birthdate: "2000-02-03")
    user.update!(mfa_level_enabled: true)
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    ClientGoogleIdentity.create!(
      user: user,
      uid: "totp_required_uid",
      provider: "google",
      token: "existing_token",
      refresh_token: "existing_refresh",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "totp_required_uid",
        info: { image: "http://example.com/image.jpg" },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow12_provider = "google"
        begin
          flow13_provider = flow12_provider
          flow13_intent = "login"
          flow13_user = nil
          flow13_entry = nil
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

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # The sign callback only hands evidence to Base. Base applies the ordinary
    # sign-in graph, where social is not a local MFA bypass.
    assert_emits_acme_completion_only!
    assert_response :redirect
    assert_match %r{/sign/in/challenge}, response.location
    assert_predicate session[:pending_mfa], :present?
  end

  test "google login with missing user_token_kind does not crash callback" do
    ClientToken.delete_all
    ClientTokenKind.delete_all

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "missing_kind_uid",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow14_provider = "google"
        begin
          flow15_provider = flow14_provider
          flow15_intent = "login"
          flow15_user = nil
          flow15_entry = nil
          flow15_ri = "jp"
          flow15_rt = nil
          flow15_referer = nil
          unless flow15_intent.to_s == "link"
            @base_browser = open_session
            flow15_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
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
            flow15_issuer = JitSecurityJwtRegistry.surface("BASE_APP")
            2.times do |flow15_index|
              flow15_target = URI.parse(@base_browser.response.location)
              # A same-origin hop moves by path; only a cross-origin hop carries a Jump rt.
              unless flow15_target.host == flow15_base_host
                flow15_rt = Rack::Utils.parse_query(flow15_target.query).fetch("rt")
                flow15_payload, = JWT.decode(
                  flow15_rt, JitSecurityJwtRegistry.public_key_for(
                    flow15_issuer.id,
                    flow15_issuer.current_kid,
                  ), true,
                  algorithms: ["ES384"], verify_iss: true, iss: "https://#{flow15_base_host}",
                  verify_aud: true, aud: Rails.configuration.x.boot_config.fetch(:jump).audience,
                )
                flow15_target = URI.parse(flow15_payload.fetch("url"))
              end
              if flow15_index.zero?
                raise RuntimeError,
                      "Base authorization host mismatch" unless flow15_target.host == flow15_base_host

                @base_browser.get(flow15_target.request_uri)
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
              else
                raise RuntimeError,
                      "Auth admission host mismatch" unless flow15_target.host == flow15_auth_host

                host!(flow15_auth_host)
                https!
                get(flow15_target.request_uri)
              end
            end
            3.times do |flow15_index|
              flow15_sender = (flow15_index == 1) ? @base_browser : self
              flow15_form = Nokogiri::HTML(flow15_sender.response.body).at_css("form")
              flow15_fields =
                flow15_form.css("input[name]").to_h { |flow15_input|
                  [
                    flow15_input["name"],
                    flow15_input["value"],
                  ]
                }
              flow15_sender.post(
                flow15_form["action"], params: flow15_fields, headers: {
                  "Origin" => "https://#{(flow15_index == 1) ? flow15_base_host : flow15_auth_host}",
                  "Sec-Fetch-Site" => "same-origin",
                },
              )
              raise RuntimeError,
                    "Social admission failed at step #{flow15_index}" unless flow15_sender.response.status == 303
              next if flow15_index == 2

              flow15_receiver = flow15_index.zero? ? @base_browser : self
              flow15_receiver.get(URI.parse(flow15_sender.response.location).request_uri)
            end
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
          post(flow15_continue_path, headers: flow15_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
  end

  test "google login with session limit exceeded redirects to session management" do
    # Create an existing user with Google social identity
    user = Client.create!(birthdate: "2000-02-03")
    ClientGoogleIdentity.create!(
      user: user,
      uid: "session_limit_uid",
      provider: "google",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Create 2 active sessions to hit the limit
    ClientToken.where(user_id: user.id).delete_all
    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "session_limit_uid",
        info: { image: "http://example.com/image.jpg" },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    sessions_before = ClientToken.where(user_id: user.id).count

    state =
      begin
        flow16_provider = "google"
        begin
          flow17_provider = flow16_provider
          flow17_intent = "login"
          flow17_user = nil
          flow17_entry = nil
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

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # Session-limit enforcement belongs to base completion. The sign callback
    # emits the completion form only and must not create or restrict a sign-side
    # session token of its own.
    assert_emits_acme_completion_only!

    assert_equal sessions_before, ClientToken.where(user_id: user.id).count,
                 "sign must not establish a session token for an established social login"
    restricted = ClientToken.where(user_id: user.id, user_token_status_id: ClientTokenStatus::RESTRICTED)

    assert_equal 0, restricted.count
  end

  private

  # Auth records ceremony evidence; Root issuance remains on the original Base parent.
  def assert_emits_acme_completion_only!
    assert_response :see_other
    target = URI.parse(response.location.to_s)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), target.host
    assert_includes ["/sign/in/check", "/sign/in/challenge"], target.path
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  def create_rotated_active_user_session(user, rotations:)
    token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end

# DAMP local helper copy for former shared test support.
class OmniauthCallbacksTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
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
class OmniauthCallbacksTest
  private
end

# DAMP local route helper aliases for former shared test support.
class OmniauthCallbacksTest
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
class OmniauthCallbacksTest
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
