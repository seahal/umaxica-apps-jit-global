# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth
  module App
    class AuthInsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
      end

      test "direct entry without login challenge lists the sign-in methods" do
        get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :success
        assert_includes response.headers["Cache-Control"], "no-store"

        query = {}

        assert_equal "auth/app/sign_ins/new", inertia_component
        assert_equal [
          new_auth_app_sign_in_email_path(query, ri: "jp"),
          new_auth_app_sign_in_passkey_path(query, ri: "jp"),
          new_auth_app_sign_in_secret_path(query, ri: "jp"),
        ], inertia_props.fetch("methods").map { |method| method.fetch("href") }
        assert_equal [
          auth_app_social_google_session_path(ri: "jp"),
          auth_app_social_apple_session_path(ri: "jp"),
        ], inertia_props.fetch("social_providers").map { |provider| provider.fetch("action") }
      end

      test "direct entry without login challenge starts no OIDC handoff state" do
        get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_nil session[:oidc_authorization_login_challenge]
        assert_nil session[:oidc_code_verifier]
        assert_nil session[:oidc_state]
        assert_nil session[:oidc_nonce]
        assert_nil session["oidc_pending_flows"]
      end

      test "local ceremony renders authentication links" do
        get auth_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success

        query = {}

        assert_equal [
          [new_auth_app_sign_in_email_path(query, ri: "jp"), I18n.t("sign.app.authentication.new.links.email")],
          [new_auth_app_sign_in_passkey_path(query, ri: "jp"), I18n.t("sign.app.authentication.new.links.passkey")],
          [
            new_auth_app_sign_in_secret_path(query, ri: "jp"),
            I18n.t("sign.app.authentication.new.links.secret_credential"),
          ],
        ], inertia_props.fetch("methods").map { |method| [method.fetch("href"), method.fetch("label")] }
      end

      test "should get new with existing preference refresh cookie" do
        token, verifier = AppPreference.generate_refresh_token(public_id: "app-pref-existing")
        preference = AppPreference.create!(
          public_id: "app-pref-existing",
          token_digest: AppPreference.digest_refresh_token(verifier),
          jti: SecureRandom.uuid,
          status_id: AppPreferenceStatus::NOTHING,
          binding_method_id: AppPreferenceBindingMethod::LEGACY,
          dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
          expires_at: 20.years.from_now,
        )
        AppPreferenceCookie.create!(preference: preference)
        cookies[::PreferenceCookieName.refresh(surface: :app)] = token

        get auth_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
      end

      test "authentication links carry pt" do
        pt = Base64.urlsafe_encode64("https://log.umaxica.app/settings/sessions?ri=jp", padding: false)

        get auth_app_sign_in_url(ri: "jp", pt: pt, login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_equal [
          new_auth_app_sign_in_email_path(ri: "jp"),
          new_auth_app_sign_in_passkey_path(ri: "jp"),
          new_auth_app_sign_in_secret_path(ri: "jp"),
        ], inertia_props.fetch("methods").map { |method| method.fetch("href") }
      end

      test "sign up link includes pt when pt is present" do
        get auth_app_sign_in_url(ri: "jp", pt: "abc", login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_equal "/sign/up?ri=jp", inertia_props.fetch("registration_link").fetch("href")
        assert_not_includes inertia_props.fetch("registration_link").fetch("href"), "pt=abc"
      end

      test "sign up link includes only ri when pt is absent" do
        get auth_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        assert_equal "/sign/up?ri=jp", inertia_props.fetch("registration_link").fetch("href")
        assert_not_includes inertia_props.fetch("registration_link").fetch("href"), "pt="
      end

      test "sign up link preserves encoded-like pt value safely" do
        pt = "aHR0cHM6Ly9leGFtcGxlLmNvbS8_cD0xJmE9Mg%3D%3D"
        get auth_app_sign_in_url(ri: "jp", pt: pt, login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_equal "/sign/up?ri=jp", inertia_props.fetch("registration_link").fetch("href")
        assert_not_includes inertia_props.fetch("registration_link").fetch("href"), "pt="
      end

      test "should render in english when lx=en" do
        get auth_app_sign_in_url(lx: "en", ri: "jp", login_challenge: login_challenge),
            headers: { "Host" => @host }

        assert_response :success
        assert_select "html[lang=en]"
        assert_match(/Need an account/, inertia_props.fetch("registration_link").fetch("label"))
      end

      test "shows social login buttons" do
        get auth_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        providers = inertia_props.fetch("social_providers")

        assert_equal [auth_app_social_google_session_path(ri: "jp")],
                     providers.select { |provider| provider.fetch("key") == "google" }
                       .map { |provider| provider.fetch("action") }
        assert_equal [auth_app_social_apple_session_path(ri: "jp")],
                     providers.select { |provider| provider.fetch("key") == "apple" }
                       .map { |provider| provider.fetch("action") }
        # The provider forms are native document POSTs, each carrying the global authenticity token
        # the ERB form embedded.
        assert_equal 1,
                     providers.count { |provider|
                       provider.fetch("key") == "google" && provider.fetch("authenticity_token").present?
                     }
      end

      test "apple button carries a permitted call to action on the custom button element" do
        get auth_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        apple = inertia_props.fetch("social_providers").find { |provider| provider.fetch("key") == "apple" }

        assert_equal auth_app_social_apple_session_path(ri: "jp"), apple.fetch("action")
        assert_includes ["Sign in with Apple", "Sign up with Apple", "Continue with Apple", "Appleで続行"],
                        apple.fetch("label")
      end

      test "apple button renders the official logo artwork for both appearances" do
        get auth_app_sign_in_url(ri: "jp", login_challenge: login_challenge), headers: { "Host" => @host }

        assert_response :success
        apple = inertia_props.fetch("social_providers").find { |provider| provider.fetch("key") == "apple" }

        assert_equal(
          {
            "white" => "/images/social/apple_logo_white.svg",
            "black" => "/images/social/apple_logo_black.svg",
            "width" => 28,
            "height" => 40,
          },
          apple.fetch("logos"),
        )
      end

      test "rejects direct entry when logged in" do
        user = clients(:one)

        get auth_app_sign_in_url(ri: "jp"), headers: as_user_headers(user, host: @host)

        assert_response :conflict
        assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
        assert_equal "Sign-in is unavailable while authenticated.", response.body
        assert_includes response.headers["Cache-Control"], "no-store"
      end

      test "logged in entry with login challenge does not resume authorization" do
        user = clients(:one)
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "sign_in",
            params: authorize_params,
          )
        headers = as_user_headers(user, host: @host)

        get auth_app_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
            headers: headers

        assert_response :conflict
        assert_equal "Sign-in is unavailable while authenticated.", response.body
        assert_includes response.headers["Cache-Control"], "no-store"
        transaction = issuance.transaction.reload

        assert_equal "pending", transaction.status
        assert_nil transaction.actor_ref
        assert_nil transaction.session_ref
        assert_nil session[:oidc_authorization_login_challenge]
      end

      private

      def login_challenge(intent: "sign_in")
        OidcAuthorizationTransactionCoordinator.issue!(
          surface: "app",
          intent: intent,
          params: authorize_params,
        ).transaction.login_challenge
      end

      def authorize_params
        {
          response_type: "code",
          client_id: "core-next-rp",
          redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        }
      end
    end
  end
end

class Auth::App::AuthInsControllerTest
  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)

    if user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"
      token =
        if session_public_id.present?
          ClientToken.find_by(public_id: session_public_id)
        else
          ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
      )
    else
      base
    end
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)

    if staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"
      token =
        if session_public_id.present?
          OperatorToken.find_by(public_id: session_public_id)
        else
          OperatorToken.where(staff_id: staff.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
      )
    else
      base
    end
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    VisitorTokenBindingMethod.ensure_defaults! if defined?(VisitorTokenBindingMethod)
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB) if defined?(VisitorTokenKind)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)

    if visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"
      token =
        if session_public_id.present?
          VisitorToken.find_by(public_id: session_public_id)
        else
          VisitorToken.where(visitor_id: visitor.id).where(
            "discarded_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= VisitorToken.create!(visitor_id: visitor.id, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    if token
      base.merge(
        "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
      )
    else
      base
    end
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::AuthInsControllerTest
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_access_token_for(resource, host: nil, session_id: nil, session_public_id: nil, resource_type: nil,
                           dpop_jkt: nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || "unknown"
    resource_type ||=
      case resource
      when Client then "client"
      when Operator then "operator"
      when Visitor then "visitor"
      end
    AuthenticationToken.encode(
      resource,
      host: host_value,
      session_id: session_id,
      session_public_id: session_public_id,
      resource_type: resource_type,
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: jwt_issuer_id_for_test_host(host_value, resource_type),
    )
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "SIGN")
    surface =
      if service == "SIGN"
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
end
