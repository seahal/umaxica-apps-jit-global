# typed: false
# frozen_string_literal: true

require "test_helper"

# A signed-in principal's preference change is written to the browser preference and mirrored to
# the principal's own account preference in the same operation, so the choice follows the
# principal to the next device. Anonymous browsers only change the browser preference.
class PreferenceSignedInDualWriteTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :visitors

  test "a signed-in client's region change is mirrored to the account preference with its regional defaults" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    headers =
      begin
        rp_headers = as_user_headers(client, host: host)
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
    get base_app_preference_path(ri: "jp"), headers: headers

    assert_response :success

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: "US" } }, headers: headers

    assert_response :redirect
    account = ClientPreference.includes(:user_preference_region, :user_preference_language).find_by!(user_id: client.id)

    assert_equal ClientPreferenceRegionOption::US, account.user_preference_region.option_id
    assert_equal ClientPreferenceLanguageOption::EN, account.user_preference_language.option_id
  end

  test "an anonymous region change leaves no account preference behind" do
    host! ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    get base_app_preference_path(ri: "jp")

    assert_response :success

    assert_no_difference("ClientPreference.count") do
      patch base_app_preference_region_path(ri: "jp"), params: { preference_region: { option_id: "US" } }
    end

    preference = AppPreference.includes(:app_preference_region).order(:created_at).last

    assert_equal AppPreferenceRegionOption::US, preference.app_preference_region.option_id
  end

  test "a signed-in operator's and visitor's region changes are mirrored to their own account preferences" do
    [
      [ENV.fetch("PUBLIC_BASE_STAFF_URL"), operators(:one), :as_staff_headers, :base_org_preference_path,
       :base_org_preference_region_path, OperatorPreference, :staff_id, OperatorPreferenceRegion,
       OperatorPreferenceRegionOption::US,],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL"), visitors(:reserved_visitor), :as_visitor_headers,
       :base_com_preference_path, :base_com_preference_region_path, VisitorPreference, :visitor_id,
       VisitorPreferenceRegion,
       VisitorPreferenceRegionOption::US,],
    ].each do |host, actor, headers_method, page, region_path, account_class, fk, region_class, us|
      host! host
      headers = public_send(headers_method, actor, host: host)
      token_model, rp_model, root_association, resource_type, client_id =
        if actor.is_a?(Operator)
          [OperatorToken, OpOrgGrant, :operator_token, "operator", "base-org-ww"]
        else
          [VisitorToken, OpComGrant, :visitor_token, "visitor", "base-com-ww"]
        end
      token = token_model.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
      rp_client = OidcClientRegistry.find!(client_id)
      now = rp_model.database_now
      rp_session = rp_model.create!(
        root_association => token, :oidc_client_id => client_id, :oidc_scope => "openid profile",
        :oidc_jti => SecureRandom.uuid, :oidc_nonce => SecureRandom.hex(16),
        :oidc_auth_time => now, :refresh_token_expires_at => now + 10.minutes,
      )
      access = AuthenticationTokenService.encode(
        actor, host: host, resource_type: resource_type, session_public_id: token.public_id,
               base_session_public_id: token.public_id, oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
               expires_at: now + 10.minutes, scopes: %w(openid profile), issuer: OidcIssuer.for_client(rp_client),
               audiences: [rp_client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
               subject: OidcSubject.for(actor, resource_type: resource_type), client_id: client_id,
      )
      cookie = [headers.fetch("Cookie"),
                "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(access)}",
                "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(
                  rp_session
                                    .issue_refresh_token!,
                )}",].join("; ")
      headers = headers.merge("Cookie" => cookie, "HTTP_COOKIE" => cookie)

      get public_send(page, ri: "jp"), headers: headers

      assert_response :success, account_class.name

      patch public_send(region_path, ri: "jp"), params: { preference_region: { option_id: "US" } }, headers: headers

      assert_response :redirect, account_class.name
      account_class.connection_class_for_self.connected_to(role: :writing) do
        account = account_class.find_by!(fk => actor.id)

        assert_equal us, region_class.find_by!(preference_id: account.id).option_id, account_class.name
      end
    end
  end
end
