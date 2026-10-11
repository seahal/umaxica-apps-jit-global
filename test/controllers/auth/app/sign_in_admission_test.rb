# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SignInAdmissionTest < ActionDispatch::IntegrationTest
  setup do
    skip "AUTH_STATE_REDIS_URL unset" if ENV["AUTH_STATE_REDIS_URL"].blank?

    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
  end

  test "direct entry without admission bridges to Base and starts no ceremony" do
    get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), location.host
    assert_equal "/", location.path
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil cookies["auth_sid"]
  end

  test "valid admission rotates ceremony session and 303s to a clean sign-in URL" do
    transaction, code = issue_admission!

    get auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => @host }

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal "/sign/in", location.path
    assert_nil Rack::Utils.parse_nested_query(location.query.to_s)["admission"]
    assert_equal transaction.login_challenge, session[:oidc_authorization_login_challenge]
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]

    follow_redirect!

    assert_response :success
    assert_equal "auth/app/sign_ins/new", inertia_component
    assert_predicate cookies["auth_sid"].presence || cookies["__Host-auth_sid"].presence, :present?
  end

  test "Base-owned local admission reaches the ceremony without creating an OIDC transaction" do
    code = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in").code

    get auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => @host }

    assert_response :see_other
    assert_nil session[:oidc_authorization_login_challenge]
    assert_equal "sign_in", session[:auth_ceremony_admitted_intent]

    follow_redirect!

    assert_response :success
    assert_equal "auth/app/sign_ins/new", inertia_component
  end

  test "a replayed Base-owned local admission is rejected" do
    code = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in").code

    get auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => @host }

    assert_response :see_other

    get auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => @host }

    assert_response :bad_request
  end

  test "replayed admission is rejected" do
    _transaction, code = issue_admission!

    get auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => @host }

    assert_response :see_other

    get auth_app_sign_in_url(ri: "jp", admission: code), headers: { "Host" => @host }

    assert_response :bad_request
  end

  test "google and apple callback routes remain at their existing paths" do
    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth", provider: "google" },
      { path: "http://#{@host}/social/google/callback", method: :get },
    )
    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth", provider: "apple" },
      { path: "http://#{@host}/social/apple/callback", method: :get },
    )
  end

  private

  def issue_admission!
    issuance =
      OidcAuthorizationTransactionCoordinator.issue!(
        surface: "app",
        intent: "sign_in",
        params: {
          response_type: "code",
          client_id: "core-app",
          redirect_uri: OidcClientRegistry.find!("core-app").redirect_uris.first,
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: SecureRandom.urlsafe_base64(16),
          nonce: SecureRandom.urlsafe_base64(16),
          scope: "openid profile",
        },
      )
    handoff = BaseAuthAdmissionCoordinator.issue_handoff!(transaction: issuance.transaction)
    [issuance.transaction, handoff.code]
  end
end
