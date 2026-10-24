# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialAuthProviderBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    https! unless @host.include?("localhost")
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
  end

  test "google callback rejects forged id_info sub when uid is absent" do
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      info: {},
      credentials: {
        token: "google-token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: {
        id_info: {
          sub: "forged-google-sub",
          iat: Time.current.to_i,
        },
      },
    )
    state =
      begin
        flow0_provider = "google"
        flow0_intent = "login"
        flow0_user = nil
        flow0_entry = nil
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
              flow0_target = URI.parse(jump_rt_url_from_location_for_test(flow0_target.to_s))
            end
            if flow0_index.zero?
              raise RuntimeError,
                    "Base authorization host mismatch" unless flow0_target.host == visa_host_for_test_base_host(flow0_base_host)

              @base_browser.host!(flow0_target.host)
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
                  "Origin" => "https://#{visa_host_for_test_base_host(flow0_base_host)}", "Sec-Fetch-Site" => "same-origin",
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
        if flow0_entry.to_s == "sign_up" && flow0_intent.to_s != "link"
          switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
          host!(flow0_host)
        end
        post(flow0_continue_path, headers: flow0_headers)
        social_auth_state_from_response
      end

    assert_no_difference("ClientGoogleIdentity.count") do
      get auth_app_social_google_callback_url(ri: "jp"),
          params: { state: state },
          headers: social_callback_headers(@host)
    end

    assert_response :redirect
    assert_nil ClientGoogleIdentity.find_by(uid: "forged-google-sub")
  end

  test "callback rejects auth provider that does not match the route provider" do
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "provider-mismatch-uid",
      info: {},
      credentials: {
        token: "apple-token",
        refresh_token: "apple-refresh-token",
        expires_at: 1.week.from_now.to_i,
      },
    )
    state =
      begin
        flow1_provider = "google"
        flow1_intent = "login"
        flow1_user = nil
        flow1_entry = nil
        flow1_ri = "jp"
        flow1_rt = nil
        flow1_referer = nil
        unless flow1_intent.to_s == "link"
          @base_browser = open_session
          flow1_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          flow1_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.host!(flow1_base_host)
          @base_browser.https!
          @base_browser.get("/sign", params: { ri: flow1_ri, pt: "/dashboard?ri=#{flow1_ri}" })
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
              flow1_target = URI.parse(jump_rt_url_from_location_for_test(flow1_target.to_s))
            end
            if flow1_index.zero?
              raise RuntimeError,
                    "Base authorization host mismatch" unless flow1_target.host == visa_host_for_test_base_host(flow1_base_host)

              @base_browser.host!(flow1_target.host)
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
                  "Origin" => "https://#{visa_host_for_test_base_host(flow1_base_host)}", "Sec-Fetch-Site" => "same-origin",
                },
              )
            else
              raise RuntimeError, "Auth admission host mismatch" unless flow1_target.host == flow1_auth_host

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
        if flow1_entry.to_s == "sign_up" && flow1_intent.to_s != "link"
          switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
          host!(flow1_host)
        end
        post(flow1_continue_path, headers: flow1_headers)
        social_auth_state_from_response
      end

    assert_no_difference("ClientAppleIdentity.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        get auth_app_social_google_callback_url(ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_response :redirect
  end

  test "callback rejects stale provider assertion iat" do
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "stale-iat-google",
      info: {},
      credentials: {
        token: "google-token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: {
        id_info: {
          iat: 30.minutes.ago.to_i,
        },
      },
    )
    state =
      begin
        flow2_provider = "google"
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
              flow2_target = URI.parse(jump_rt_url_from_location_for_test(flow2_target.to_s))
            end
            if flow2_index.zero?
              raise RuntimeError,
                    "Base authorization host mismatch" unless flow2_target.host == visa_host_for_test_base_host(flow2_base_host)

              @base_browser.host!(flow2_target.host)
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
                  "Origin" => "https://#{visa_host_for_test_base_host(flow2_base_host)}", "Sec-Fetch-Site" => "same-origin",
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
        if flow2_entry.to_s == "sign_up" && flow2_intent.to_s != "link"
          switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
          host!(flow2_host)
        end
        post(flow2_continue_path, headers: flow2_headers)
        social_auth_state_from_response
      end

    assert_no_difference("ClientGoogleIdentity.count") do
      get auth_app_social_google_callback_url(ri: "jp"),
          params: { state: state },
          headers: social_callback_headers(@host)
    end

    assert_response :redirect
  end

  test "apple callback accepts provider nonce owned by omniauth strategy" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "apple-strategy-owned-nonce",
      info: {},
      credentials: {
        token: "apple-token",
        refresh_token: "apple-refresh-token",
        expires_at: 1.week.from_now.to_i,
      },
      extra: {
        raw_info: {
          iat: Time.current.to_i,
          nonce: "omniauth-apple-generated-nonce",
        },
      },
    )
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
              flow3_target = URI.parse(jump_rt_url_from_location_for_test(flow3_target.to_s))
            end
            if flow3_index.zero?
              raise RuntimeError,
                    "Base authorization host mismatch" unless flow3_target.host == visa_host_for_test_base_host(flow3_base_host)

              @base_browser.host!(flow3_target.host)
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
                  "Origin" => "https://#{visa_host_for_test_base_host(flow3_base_host)}", "Sec-Fetch-Site" => "same-origin",
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
        if flow3_entry.to_s == "sign_up" && flow3_intent.to_s != "link"
          switch_browser_to_sign_up!(integration_session, base_browser: @base_browser)
          host!(flow3_host)
        end
        post(flow3_continue_path, headers: flow3_headers)
        social_auth_state_from_response
      end

    get auth_app_social_apple_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
    assert_match(%r{/sign/up/guard/apple}, response.location)
  end
end

# DAMP local helper copy for former shared test support.
class SocialAuthProviderBoundaryTest
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

# DAMP local helper copy on the test class.
class SocialAuthProviderBoundaryTest
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
