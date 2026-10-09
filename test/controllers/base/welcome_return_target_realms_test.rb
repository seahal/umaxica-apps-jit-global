# typed: false
# frozen_string_literal: true

require "test_helper"

# The com and org Welcome pages apply the same return-target contract as app
# (test/controllers/base/app/welcomes_controller_test.rb), each for its own surface only.
class Base::Com::WelcomeReturnTargetControllerTest < ActionController::TestCase
  tests Base::Com::WelcomesController

  setup do
    @host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :com, principal: @visitor)
    BaseSelectorAuthority.prepare(surface: :com, principal: @visitor, session: @token)
    @request.host = @host
    begin
      rp_host = @host
      rp_token = @token
      rp_client = OidcClientRegistry.find!("base-com-ww")
      rp_key = [rp_client.client_id, rp_token.public_id]
      @base_browser_rp_credentials ||= {}
      if @base_browser_rp_credentials[rp_key] ||
          (rp_token.currently_usable? &&
            !(rp_token.device_session_id && VisitorRpSession.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            )))
        unless @base_browser_rp_credentials[rp_key]
          rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
          rp_now = Time.current
          rp_session = VisitorRpSession.create!(
            visitor_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            @visitor, host: rp_host, resource_type: "visitor",
                      session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                      oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                      expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                      issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                      subject: OidcSubject.for(@visitor, resource_type: "visitor"), client_id: rp_client.client_id,
          )
          @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
        end
        rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
        [
          "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
        ]
      else
        []
      end
    end.each do |pair|
      name, value = pair.split("=", 2)
      @request.cookies[name] = Rack::Utils.unescape(value)
    end
    @request.session[:com_sign_in_welcome] = {
      "remaining" => 5,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "sequence_id" => nil,
    }
    @request.session[:authentication_pt_nonce] = "com-welcome-nonce"
    @request.headers["X-Inertia"] = "true"
    @request.headers["X-Inertia-Version"] = InertiaRails.configuration.version
  end

  test "com Next returns to the verified pre-sign-in page" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5006 = "/identity?ri=jp"
                           fv5008 = { surface: "com" }
                           fv5007 = fv5008.fetch(:surface)
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             { "flow" => "authentication",
                               "surface" => fv5007,
                               "session_nonce" => "com-welcome-nonce",
                               "pt" => fv5006, },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
                           )
                         end, }

    assert_response :success
    assert_equal "/identity?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "com ignores a return target issued for the app surface" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5003 = "/identity?ri=jp"
                           fv5005 = { surface: "app" }
                           fv5004 = fv5005.fetch(:surface)
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             { "flow" => "authentication",
                               "surface" => fv5004,
                               "session_nonce" => "com-welcome-nonce",
                               "pt" => fv5003, },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
                           )
                         end, }

    assert_equal "/dashboard?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "com skips the page without its own gate even when the app gate is present" do
    @request.session[:app_sign_in_welcome] = @request.session.delete(:com_sign_in_welcome)

    get :show, params: { ri: "jp",
                         pt: begin
                           fv5000 = "/identity?ri=jp"
                           fv5002 = { surface: "com" }
                           fv5001 = fv5002.fetch(:surface)
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             { "flow" => "authentication",
                               "surface" => fv5001,
                               "session_nonce" => "com-welcome-nonce",
                               "pt" => fv5000, },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
                           )
                         end, }

    assert_redirected_to "/dashboard?ri=jp"
  end

  private
end

class Base::Org::WelcomeReturnTargetControllerTest < ActionController::TestCase
  tests Base::Org::WelcomesController

  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    @request.host = @host
    begin
      rp_host = @host
      rp_token = @token
      rp_client = OidcClientRegistry.find!("base-org-ww")
      rp_key = [rp_client.client_id, rp_token.public_id]
      @base_browser_rp_credentials ||= {}
      if @base_browser_rp_credentials[rp_key] ||
          (rp_token.currently_usable? &&
            !(rp_token.device_session_id && OperatorRpSession.exists?(
              device_session_id: rp_token.device_session_id, oidc_client_id: rp_client.client_id, revoked_at: nil,
            )))
        unless @base_browser_rp_credentials[rp_key]
          rp_token.rotate_refresh_token! unless rp_token.device_session.current_refresh_token_id
          rp_now = Time.current
          rp_session = OperatorRpSession.create!(
            operator_token: rp_token, oidc_client_id: rp_client.client_id, oidc_scope: "openid profile",
            oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: rp_now,
            refresh_token_expires_at: rp_now + 10.minutes,
          )
          rp_access = AuthenticationTokenService.encode(
            @operator, host: rp_host, resource_type: "operator",
                       session_public_id: rp_token.public_id, base_session_public_id: rp_token.public_id,
                       oidc_sid: rp_session.public_id, oidc_jti: rp_session.oidc_jti,
                       expires_at: rp_now + 10.minutes, scopes: %w(openid profile),
                       issuer: OidcIssuer.for_client(rp_client), audiences: [rp_client.aud],
                       jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(rp_client),
                       subject: OidcSubject.for(@operator, resource_type: "operator"), client_id: rp_client.client_id,
          )
          @base_browser_rp_credentials[rp_key] = [rp_access, rp_session.issue_refresh_token!]
        end
        rp_access, rp_refresh = @base_browser_rp_credentials.fetch(rp_key)
        [
          "#{OidcRpBrowserCredentialContract::ACCESS_COOKIE}=#{Rack::Utils.escape(rp_access)}",
          "#{OidcRpBrowserCredentialContract::REFRESH_COOKIE}=#{Rack::Utils.escape(rp_refresh)}",
        ]
      else
        []
      end
    end.each do |pair|
      name, value = pair.split("=", 2)
      @request.cookies[name] = Rack::Utils.unescape(value)
    end
    @request.session[:org_sign_in_welcome] = {
      "remaining" => 5,
      "issued_at" => Time.current.to_i,
      "expires_at" => 10.minutes.from_now.to_i,
      "sequence_id" => nil,
    }
    @request.session[:authentication_pt_nonce] = "org-welcome-nonce"
    @request.headers["X-Inertia"] = "true"
    @request.headers["X-Inertia-Version"] = InertiaRails.configuration.version
  end

  test "org Next returns to the verified pre-sign-in page" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5006 = "/identity?ri=jp"
                           fv5008 = { surface: "org" }
                           fv5007 = fv5008.fetch(:surface)
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             { "flow" => "authentication",
                               "surface" => fv5007,
                               "session_nonce" => "org-welcome-nonce",
                               "pt" => fv5006, },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
                           )
                         end, }

    assert_response :success
    assert_equal "/identity?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "org ignores a return target issued for the com surface" do
    get :show, params: { ri: "jp",
                         pt: begin
                           fv5003 = "/identity?ri=jp"
                           fv5005 = { surface: "com" }
                           fv5004 = fv5005.fetch(:surface)
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             { "flow" => "authentication",
                               "surface" => fv5004,
                               "session_nonce" => "org-welcome-nonce",
                               "pt" => fv5003, },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
                           )
                         end, }

    assert_equal "/dashboard?ri=jp", response.parsed_body.dig("props", "next_link", "href")
  end

  test "org skips the page without its own gate even when the com gate is present" do
    @request.session[:com_sign_in_welcome] = @request.session.delete(:org_sign_in_welcome)

    get :show, params: { ri: "jp",
                         pt: begin
                           fv5000 = "/identity?ri=jp"
                           fv5002 = { surface: "org" }
                           fv5001 = fv5002.fetch(:surface)
                           ActiveSupport::MessageVerifier.new(
                             Rails.application.key_generator.generate_key(
                               AuthenticationRedirects::PATH_TARGET_TOKEN_SALT,
                               32,
                             ),
                             digest: "SHA256", serializer: JSON, url_safe: true,
                           ).generate(
                             { "flow" => "authentication",
                               "surface" => fv5001,
                               "session_nonce" => "org-welcome-nonce",
                               "pt" => fv5000, },
                             purpose: AuthenticationRedirects::PATH_TARGET_TOKEN_PURPOSE, expires_in: 5.minutes,
                           )
                         end, }

    assert_redirected_to "/dashboard?ri=jp"
  end

  private
end
