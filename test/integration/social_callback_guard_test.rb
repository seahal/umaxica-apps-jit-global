# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialCallbackGuardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses

  setup do
    OmniAuth.config.test_mode = true
    https!
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    @previous_id_service_url = ENV["PRIVATE_AUTH_SERVICE_URL"]
    ENV["PRIVATE_AUTH_SERVICE_URL"] = @host
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  teardown do
    OmniAuth.config.mock_auth[:google_app] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    if @previous_id_service_url.nil?
      ENV.delete("PRIVATE_AUTH_SERVICE_URL")
    else
      ENV["PRIVATE_AUTH_SERVICE_URL"] = @previous_id_service_url
    end
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "callback phase rejects when state is missing" do
    setup_google_mock_auth(uid: "callback_google_missing_state_#{SecureRandom.hex(4)}")
    clients(:one)
    begin
      flow0_provider = "google_app"
      flow0_normalized_provider = (flow0_provider == "apple") ? "apple" : "google"
      begin
        flow1_provider = flow0_normalized_provider
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

    get auth_app_social_google_callback_path(ri: "jp"),
        headers: callback_headers.merge(
          begin
            rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
            continuity_cookie = [
              rp_headers.fetch("Cookie"),
              cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; "),
            ].join("; ")
            rp_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
          end,
        )

    assert_response :forbidden
    assert_equal sign_app_sign_in_url(ri: "jp", protocol: "https"), response.location
  end

  test "callback phase rejects when state mismatches" do
    setup_google_mock_auth(uid: "callback_google_bad_state_#{SecureRandom.hex(4)}")
    clients(:one)
    begin
      flow2_provider = "google_app"
      flow2_normalized_provider = (flow2_provider == "apple") ? "apple" : "google"
      begin
        flow3_provider = flow2_normalized_provider
        flow3_intent = "login"
        flow3_user = nil
        flow3_entry = nil
        flow3_ri = "jp"
        flow3_rt = nil
        flow3_referer = nil
        unless flow3_intent.to_s == "link"
          @base_browser = open_session
          flow3_base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
          flow3_auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          @base_browser.host!(flow3_base_host)
          @base_browser.https!
          @base_browser.get(
            "/sign", params: {
              ri: flow3_ri,
              pt: "/dashboard?ri=#{flow3_ri}",
            },
          )
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
              raise RuntimeError,
                    "Auth admission host mismatch" unless flow3_target.host == flow3_auth_host

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
    end

    get auth_app_social_google_callback_path(ri: "jp", state: "invalid_state"),
        headers: callback_headers.merge(
          begin
            rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
            continuity_cookie = [
              rp_headers.fetch("Cookie"),
              cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; "),
            ].join("; ")
            rp_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
          end,
        )

    assert_response :forbidden
  end

  test "callback phase rejects when state is expired" do
    setup_google_mock_auth(uid: "callback_google_expired_state_#{SecureRandom.hex(4)}")
    clients(:one)
    state =
      begin
        flow4_provider = "google_app"
        flow4_normalized_provider = (flow4_provider == "apple") ? "apple" : "google"
        begin
          flow5_provider = flow4_normalized_provider
          flow5_intent = "login"
          flow5_user = nil
          flow5_entry = nil
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

    travel_to 6.minutes.from_now do
      get auth_app_social_google_callback_path(ri: "jp", state: state),
          headers: callback_headers.merge(
            begin
              rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                    rp_token.actor_record, host: rp_host, resource_type: "client",
                                           session_public_id: rp_token.public_id,
                                           base_session_public_id: rp_token.public_id,
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
            end,
          )
    end

    assert_response :forbidden
  end

  test "callback phase rejects reused state" do
    uid = "callback_google_reused_state_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)
    user = clients(:one)
    create_google_identity!(user: user, uid: uid)
    state =
      begin
        flow6_provider = "google_app"
        flow6_normalized_provider = (flow6_provider == "apple") ? "apple" : "google"
        begin
          flow7_provider = flow6_normalized_provider
          flow7_intent = "login"
          flow7_user = nil
          flow7_entry = nil
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

    get auth_app_social_google_callback_path(ri: "jp", state: state),
        headers: callback_headers.merge(
          begin
            rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
            continuity_cookie = [
              rp_headers.fetch("Cookie"),
              cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; "),
            ].join("; ")
            rp_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
          end,
        )

    assert_response :redirect

    setup_google_mock_auth(uid: "callback_google_reused_state_2_#{SecureRandom.hex(4)}")
    get auth_app_social_google_callback_path(ri: "jp", state: state),
        headers: callback_headers.merge(
          begin
            rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
            continuity_cookie = [
              rp_headers.fetch("Cookie"),
              cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; "),
            ].join("; ")
            rp_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
          end,
        )

    assert_response :forbidden
  end

  test "callback phase rejects host mismatch" do
    setup_google_mock_auth(uid: "callback_google_host_mismatch_#{SecureRandom.hex(4)}")
    user = clients(:one)
    state =
      begin
        flow8_provider = "google_app"
        flow8_normalized_provider = (flow8_provider == "apple") ? "apple" : "google"
        begin
          flow9_provider = flow8_normalized_provider
          flow9_intent = "login"
          flow9_user = nil
          flow9_entry = nil
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

    get auth_app_social_google_callback_path(ri: "jp", state: state),
        headers: callback_headers(host: "#{@host}:444").merge(
          begin
            rp_headers = as_user_headers(user, host: "#{@host}:444")
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
            continuity_cookie = [
              rp_headers.fetch("Cookie"),
              cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; "),
            ].join("; ")
            rp_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
          end,
        )

    assert_response :forbidden
  end

  test "callback phase rejects bad callback method" do
    setup_google_mock_auth(uid: "callback_google_bad_method_#{SecureRandom.hex(4)}")
    clients(:one)
    state =
      begin
        flow10_provider = "google_app"
        flow10_normalized_provider = (flow10_provider == "apple") ? "apple" : "google"
        begin
          flow11_provider = flow10_normalized_provider
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

    post auth_app_social_google_callback_path(ri: "jp", state: state),
         headers: callback_headers.merge(
           begin
             rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                   rp_token.actor_record, host: rp_host, resource_type: "client",
                                          session_public_id: rp_token.public_id,
                                          base_session_public_id: rp_token.public_id,
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
           end,
         )

    assert_response :not_found
  end

  test "callback phase does not reject google origin header from provider domain" do
    uid = "callback_google_provider_origin_#{SecureRandom.hex(4)}"
    setup_google_mock_auth(uid: uid)
    user = clients(:one)
    create_google_identity!(user: user, uid: uid)
    state =
      begin
        flow12_provider = "google_app"
        flow12_normalized_provider = (flow12_provider == "apple") ? "apple" : "google"
        begin
          flow13_provider = flow12_normalized_provider
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

    get auth_app_social_google_callback_path(ri: "jp", state: state),
        headers: callback_headers(origin: "https://accounts.google.com")
          .merge(begin
            rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                                         session_public_id: rp_token.public_id,
                                         base_session_public_id: rp_token.public_id,
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
            continuity_cookie = [
              rp_headers.fetch("Cookie"),
              cookies.to_hash.map { |name, value| "#{name}=#{Rack::Utils.escape(value)}" }.join("; "),
            ].join("; ")
            rp_headers.merge("Cookie" => continuity_cookie, "HTTP_COOKIE" => continuity_cookie)
          end)

    assert_response :redirect
    assert_not_equal :forbidden, response.status
  end

  test "callback phase enforces google GET" do
    setup_google_mock_auth(uid: "callback_google_bad_method_post_#{SecureRandom.hex(4)}")
    clients(:one)
    state =
      begin
        flow14_provider = "google_app"
        flow14_normalized_provider = (flow14_provider == "apple") ? "apple" : "google"
        begin
          flow15_provider = flow14_normalized_provider
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

    post auth_app_social_google_callback_path(ri: "jp", state: state),
         headers: callback_headers.merge(
           begin
             rp_headers = social_callback_headers(@host).merge("Cookie" => "", "HTTP_COOKIE" => "")
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
                   rp_token.actor_record, host: rp_host, resource_type: "client",
                                          session_public_id: rp_token.public_id,
                                          base_session_public_id: rp_token.public_id,
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
           end,
         )

    assert_response :not_found
  end

  test "module helpers normalize methods, hosts, and origins" do
    assert SocialCallbackGuard.allowed_request_method?("google", "POST")
    assert_not SocialCallbackGuard.allowed_request_method?("google", "GET")
    assert_not SocialCallbackGuard.allowed_callback_method?("apple", "POST")
    assert SocialCallbackGuard.allowed_callback_method?("apple", "GET")
    assert_equal "id.app.localhost", SocialCallbackGuard.normalize_host_port("https://id.app.localhost")
    assert_equal "id.app.localhost:444", SocialCallbackGuard.normalize_host_port("https://id.app.localhost:444")
    assert_nil SocialCallbackGuard.normalize_host_port("::not a uri::")
    assert_equal "https://id.app.localhost", SocialCallbackGuard.normalize_origin("https://id.app.localhost")
    assert_equal "https://id.app.localhost:444", SocialCallbackGuard.normalize_origin("https://id.app.localhost:444/path")
    assert_nil SocialCallbackGuard.normalize_origin("ftp://id.app.localhost")
    assert_equal "https://id.app.localhost", SocialCallbackGuard.sanitize_source_header("https://id.app.localhost/path")
  end

  test "allowed hosts includes sign host environment names" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

    begin
      with_env("PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app", "AUTH_STAFF_URL" => "log.umaxica.org") do
        SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

        assert_includes SocialCallbackGuard.allowed_hosts, "log.umaxica.app"
        assert_includes SocialCallbackGuard.allowed_hosts, "log.umaxica.org"
      end
    ensure
      SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    end
  end

  # test_helper defines AUTH_SERVICE_URL / AUTH_CORPORATE_URL / AUTH_STAFF_URL, but deployments
  # configure only the PUBLIC_ and PRIVATE_ variants. Without this guard the unset aliases raised
  # KeyError inside the Google callback instead of being skipped.
  test "allowed hosts skips auth host aliases that are not configured" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

    begin
      with_env("AUTH_SERVICE_URL" => nil, "AUTH_CORPORATE_URL" => nil, "AUTH_STAFF_URL" => nil) do
        SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)

        hosts = SocialCallbackGuard.allowed_hosts

        assert_includes hosts, ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        assert_includes hosts, ENV.fetch("PUBLIC_AUTH_CORPORATE_URL")
        assert_includes hosts, ENV.fetch("PUBLIC_AUTH_STAFF_URL")
      end
    ensure
      SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    end
  end

  test "request phase helpers derive source, enforce state, and reject bad methods" do
    env = Rack::MockRequest.env_for(
      "https://#{@host}/social/google?foo=bar",
      "REQUEST_METHOD" => "POST",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(env))

    assert_equal :origin, source
    assert_equal "https://#{@host}", normalized

    SocialCallbackGuard.ensure_state_query_param!(env, Rack::Request.new(env), "google")

    assert_includes env["QUERY_STRING"], "state="
    assert_equal "google", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]

    env_with_state = Rack::MockRequest.env_for(
      "https://#{@host}/social/google?state=known",
      "REQUEST_METHOD" => "POST",
      "HTTP_ORIGIN" => "https://#{@host}",
      "rack.session" => {},
    )

    assert_nil SocialCallbackGuard.verify_request_phase!(env_with_state)
    assert_equal "known", env_with_state["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]

    rejected = SocialCallbackGuard.verify_request_phase!(
      Rack::MockRequest.env_for(
        "https://#{@host}/social/google",
        "REQUEST_METHOD" => "DELETE",
        "HTTP_ORIGIN" => "https://#{@host}",
        "rack.session" => {},
      ),
    )

    assert_equal 403, rejected.first
  end

  private

  def callback_headers(host: @host, origin: nil, referer: nil)
    headers = { "Host" => host, "X-STRICT-SOCIAL-STATE" => "1" }
    headers["Origin"] = origin if origin
    headers["Referer"] = referer if referer
    headers
  end

  def setup_apple_mock_auth(uid:)
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: uid,
      info: {},
      credentials: {
        token: "apple_token_#{SecureRandom.hex(8)}",
        discard_at: 1.week.from_now.to_i,
      },
    )
  end

  def create_google_identity!(user:, uid:)
    ClientGoogleIdentity.create!(
      user: user,
      uid: uid,
      provider: "google",
      token: "token",
      expires_at: 1.week.from_now.to_i,
      status_id: ClientGoogleIdentityStatus::ACTIVE,
    )
  end

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class SocialCallbackGuardTest
  private
end

# DAMP local helper copy for former shared test support.
class SocialCallbackGuardTest
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

# DAMP local route helper aliases for former shared test support.
class SocialCallbackGuardTest
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
class SocialCallbackGuardTest
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
