# frozen_string_literal: true

require "test_helper"

class BasePasskeyMutationStepUpTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "Base passkey rename and deletion require scoped step-up in app com and org" do
    [[Client, ClientPasskey, ClientToken, OpAppGrant, :user_id, :client_token, "app", "client"],
     [Visitor, VisitorPasskey, VisitorToken, OpComGrant, :visitor_id, :visitor_token, "com", "visitor"],
     [Operator, OperatorPasskey, OperatorToken, OpOrgGrant, :staff_id, :operator_token,
      "org", "operator",],].each do |actor_class, key_class, token_class, rp_class, owner_key, root_key, surface, type|
      actor = actor_class.create!
      token = token_class.create!(owner_key => actor.id, :root_login_established_at => Time.current)
      metadata = (key_class == OperatorPasskey) ? {} : { uv_verified_at: Time.current }
      key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "surviving-key", **metadata,
      )
      target = key_class.create!(
        owner_key => actor.id, :webauthn_id => SecureRandom.uuid,
        :public_key => "target-key", :description => "Original", **metadata,
      )
      client = OidcClientRegistry.find!("base-#{surface}-ww")
      host = URI.parse(client.redirect_uris.first).host
      rp = rp_class.create!(
        root_key => token, :oidc_client_id => client.client_id,
        :oidc_scope => "openid profile", :oidc_jti => SecureRandom.uuid,
        :oidc_auth_time => Time.current, :refresh_token_expires_at => 10.minutes.from_now,
      )
      access = AuthenticationTokenService.encode(
        actor, host: host, resource_type: type, session_public_id: token.public_id,
               base_session_public_id: token.public_id, oidc_sid: rp.public_id, oidc_jti: rp.oidc_jti,
               expires_at: 10.minutes.from_now, scopes: %w(openid profile), issuer: OidcIssuer.for_client(client),
               audiences: [client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
               subject: OidcSubject.for(actor, resource_type: type), client_id: client.client_id,
      )
      browser = open_session
      browser.https!
      browser.host!(host)
      browser.cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
      browser.cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = rp.issue_refresh_token!
      ref = (key_class == OperatorPasskey) ? target.external_id : target.public_id
      path =
        case surface
        when "app" then base_app_identity_passkey_path(ref, ri: "jp")
        when "com" then base_com_identity_passkey_path(ref, ri: "jp")
        when "org" then base_org_identity_passkey_path(ref, ri: "jp")
        else raise ArgumentError, "unsupported test surface"
        end
      headers = { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://#{host}" }

      browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

      assert_equal 401, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_equal "Original", target.reload.description
      browser.delete(path, headers: headers)

      assert_equal 401, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_equal 1, target.reload.status_id

      token.update!(
        last_step_up_at: Time.current, last_step_up_scope: "settings_passkey", last_step_up_method: "passkey",
        last_step_up_credential_ref: ref, last_step_up_session_public_id: token.public_id,
        last_step_up_purpose: "step_up", last_step_up_audience: "step_up:#{surface}",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: false,
      )
      [{ last_step_up_scope: "settings_email" }, { last_step_up_at: 16.minutes.ago }].each do |invalid|
        token.update!({ last_step_up_scope: "settings_passkey", last_step_up_at: Time.current }.merge(invalid))
        browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

        assert_equal 401, browser.response.status
        assert_equal "Original", target.reload.description
        browser.delete(path, headers: headers)

        assert_equal 401, browser.response.status
        assert_equal 1, target.reload.status_id
      end
      token.update!(last_step_up_scope: "settings_passkey", last_step_up_at: Time.current)
      browser.patch(path, params: { passkey: { description: "Changed" } }, headers: headers)

      assert_equal 303, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_equal "Changed", target.reload.description
      browser.delete(path, headers: headers)

      assert_equal 303, browser.response.status, "#{surface}: #{browser.response.body.first(100)}"
      assert_not target.class.exists?(target.id),
                 "#{surface}: passkey removal must physically delete the current credential"
    end
  end
end
