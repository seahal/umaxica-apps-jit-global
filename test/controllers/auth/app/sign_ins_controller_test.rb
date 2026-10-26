# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Auth
  module App
    class AuthInsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host! @host
      end

      test "direct entry without login challenge is refused without admission" do
        get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_response :bad_request
        assert_nil response.location
        assert_includes response.headers["Cache-Control"], "no-store"

        assert_nil session[:oidc_authorization_login_challenge]
      end

      test "direct entry without login challenge starts no OIDC handoff state" do
        get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

        assert_nil session[:oidc_authorization_login_challenge]
        assert_nil session[:oidc_code_verifier]
        assert_nil session[:oidc_state]
        assert_nil session[:oidc_nonce]
        assert_nil session["oidc_pending_flows"]
      end

      test "local ceremony renders supported authentication links without the device mock" do
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference }, headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path(ri: "jp"), params: { entry_ref: reference }, headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success

        query = {}

        assert_equal [
          [new_auth_app_sign_in_email_path(query, ri: "jp"), I18n.t("sign.app.authentication.new.links.email")],
          [new_auth_app_sign_in_passkey_path(query, ri: "jp"), I18n.t("sign.app.authentication.new.links.passkey")],
          [new_auth_app_sign_in_secret_url(query, ri: "jp", host: @host),
           I18n.t("sign.app.authentication.new.links.secret"),],
        ], inertia_props.fetch("methods").map { |method| [method.fetch("href"), method.fetch("label")] }
        assert_equal %w(email passkey secret), inertia_props.fetch("methods").map { |method|
          method.fetch("key")
        }
        assert_equal %w(google apple), inertia_props.fetch("social_providers").map { |provider| provider.fetch("key") }
        # This page is admitted for an OIDC parent and is still its first page: Cancel and Switch are
        # offered as POST forms, and the plain Auth-to-Auth link to Sign Up is not (D06/D09).
        assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
        assert_equal "sign_up", inertia_props.fetch("switch_form").fetch("to")
        assert_nil inertia_props.fetch("registration_link")
      end

      test "should get new with existing preference refresh cookie" do
        token, verifier = AppPreference.generate_refresh_token(public_id: "app-pref-existingxxxx")
        preference = AppPreference.create!(
          public_id: "app-pref-existingxxxx",
          token_digest: AppPreference.digest_refresh_token(verifier),
          jti: SecureRandom.uuid,
          status_id: AppPreferenceStatus::NOTHING,
          binding_method_id: AppPreferenceBindingMethod::LEGACY,
          dbsc_status_id: AppPreferenceDbscStatus::NOTHING,
          expires_at: 20.years.from_now,
        )
        AppPreferenceCookie.create!(preference: preference)
        cookies[::PreferenceCookieName.refresh(surface: :app)] = token

        entry_params = { ri: "jp" }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success
      end

      test "authentication links carry pt" do
        pt = Base64.urlsafe_encode64("https://log.umaxica.app/settings/sessions?ri=jp", padding: false)

        entry_params = { ri: "jp", pt: pt }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success
        assert_equal [
          new_auth_app_sign_in_email_path(ri: "jp"),
          new_auth_app_sign_in_passkey_path(ri: "jp"),
          new_auth_app_sign_in_secret_url(ri: "jp", host: @host),
        ], inertia_props.fetch("methods").map { |method| method.fetch("href") }
      end

      test "sign up link includes pt when pt is present" do
        entry_params = { ri: "jp", pt: "abc" }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success
        # An OIDC-bound page moves to Sign Up only through the Switch form, which carries no pt:
        # the parent authorization already fixes where the user returns.
        assert_nil inertia_props.fetch("registration_link")
        assert_equal "/sign/switch?ri=jp", inertia_props.fetch("switch_form").fetch("action")
      end

      test "sign up link includes only ri when pt is absent" do
        entry_params = { ri: "jp" }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success
        # An OIDC-bound page moves to Sign Up only through the Switch form, which carries no pt:
        # the parent authorization already fixes where the user returns.
        assert_nil inertia_props.fetch("registration_link")
        assert_equal "/sign/switch?ri=jp", inertia_props.fetch("switch_form").fetch("action")
      end

      test "sign up link preserves encoded-like pt value safely" do
        pt = "aHR0cHM6Ly9leGFtcGxlLmNvbS8_cD0xJmE9Mg%3D%3D"
        entry_params = { ri: "jp", pt: pt }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success
        # An OIDC-bound page moves to Sign Up only through the Switch form, which carries no pt:
        # the parent authorization already fixes where the user returns.
        assert_nil inertia_props.fetch("registration_link")
        assert_equal "/sign/switch?ri=jp", inertia_props.fetch("switch_form").fetch("action")
      end

      test "should render in english when lx=en" do
        entry_params = { lx: "en", ri: "jp" }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success
        assert_select "html[lang=en]"
        assert_match(/Need an account/, inertia_props.fetch("switch_form").fetch("label"))
      end

      test "shows social login buttons" do
        entry_params = { ri: "jp" }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

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
        entry_params = { ri: "jp" }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

        assert_response :success
        apple = inertia_props.fetch("social_providers").find { |provider| provider.fetch("key") == "apple" }

        assert_equal auth_app_social_apple_session_path(ri: "jp"), apple.fetch("action")
        assert_includes ["Sign in with Apple", "Sign up with Apple", "Continue with Apple", "Appleで続行"],
                        apple.fetch("label")
      end

      test "apple button renders the official logo artwork for both appearances" do
        entry_params = { ri: "jp" }
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "authentication",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference
        binding = ClientAuthAdmissionBinding.find_by!(entry_ref: reference)
        headers = { "Host" => @host }

        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        assert_equal "/ceremony_bindings", URI.parse(response.location).path
        get response.location, headers: headers

        assert_response :see_other
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        get auth_app_sign_in_path, params: entry_params.merge(entry_ref: reference), headers: headers

        assert_response :see_other
        follow_redirect!

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

        assert_response :forbidden
        assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
        assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
        assert_includes response.headers["Cache-Control"], "no-store"
      end

      test "logged in entry with login challenge does not resume authorization" do
        user = clients(:one)
        issuance =
          OidcAuthorizationTransactionCoordinator.issue!(
            surface: "app",
            intent: "sign_in",
            params: {
              response_type: "code",
              client_id: "core-app-jp",
              redirect_uri: OidcClientRegistry.find!("core-app-jp").redirect_uris.first,
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
              code_challenge_method: "S256",
              state: SecureRandom.urlsafe_base64(16),
              nonce: SecureRandom.urlsafe_base64(16),
              scope: "openid profile",
            },
          )
        headers = as_user_headers(user, host: @host)
        reference = BaseAuthAdmissionCoordinator.issue_handoff!(
          transaction: issuance.transaction,
          base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
          base_token: nil,
        ).reference

        get auth_app_sign_in_path(ri: "jp", transaction_ref: reference), headers: headers

        assert_response :forbidden
        assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
        assert_includes response.headers["Cache-Control"], "no-store"
        transaction = issuance.transaction.reload

        assert_equal "pending", transaction.status
        assert_nil transaction.actor_ref
        assert_nil transaction.session_ref
        assert_nil session[:oidc_authorization_login_challenge]
      end

      private

      # core-app-jp is a first-party RP, so Base issues its parent with the neutral authentication
      # intent; a fixed sign_in intent is not reachable for a registered client.
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
end

# DAMP auth header helpers for this test class.
class Auth::App::AuthInsControllerTest
  private

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
end
