# typed: false
# frozen_string_literal: true

require "test_helper"

# A signed-in principal's explicitly submitted preference is written to the anonymous browser
# snapshot and the principal's own option-backed preference. Anonymous browsers only change the
# browser snapshot.
class PreferenceSignedInDualWriteTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators

  test "a signed-in client's region choice updates its explicit option-backed preference" do
    host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! host
    client = clients(:one)
    headers = as_user_headers(client, host: host)
    get base_app_preference_path(ri: "jp"), headers: headers

    assert_response :success

    patch base_app_preference_region_path(ri: "jp"),
          params: { preference_region: { option_id: "US" } }, headers: headers

    assert_response :redirect
    account = ClientPreference.includes(:client_preference_region, :client_preference_language)
      .find_by!(client_id: client.id)

    assert_equal ClientPreferenceRegionOption::US, account.client_preference_region.option_id
    assert_equal ClientPreferenceLanguageOption::EN, account.client_preference_language.option_id
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

  test "a signed-in operator's region choice updates its explicit option-backed preference" do
    [
      [ENV.fetch("PUBLIC_BASE_STAFF_URL"), operators(:one), :as_staff_headers, :base_org_preference_path,
       :base_org_preference_region_path, OperatorPreference, :operator_id, OperatorPreferenceRegion,
       OperatorPreferenceRegionOption::US,],
    ].each do |host, actor, headers_method, page, region_path, account_class, fk, region_class, us|
      host! host
      headers = public_send(headers_method, actor, host: host)
      token_model, rp_model, root_association, resource_type, client_id =
        [OperatorToken, OpOrgGrant, :operator_token, "operator", "base-org-ww"]
      token = token_model.find_by!(public_id: headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
      token.rotate_refresh_token! unless token.device_session_record.current_refresh_token_id
      rp_client = OidcClientRegistry.find!(client_id)
      now = rp_model.database_now
      rp_session = rp_model.create!(
        :authentication_epoch => 0,
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
