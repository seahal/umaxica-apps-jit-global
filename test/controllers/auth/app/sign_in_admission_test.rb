# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SignInAdmissionTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    host! @host
  end

  test "direct entry without admission bridges to Base and starts no ceremony" do
    get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :see_other
    gateway = URI.parse(response.location)
    assert_equal "jump.umaxica.net", gateway.host
    payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)
    location = URI.parse(payload.fetch("url"))

    assert_equal ENV.fetch("PUBLIC_BASE_SERVICE_URL"), location.host
    assert_equal "/", location.path
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil cookies["auth_sid"]
  end

  test "legacy admission query is rejected without consuming a code" do
    issuance = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in")

    get auth_app_sign_in_url(ri: "jp", admission: issuance.code), headers: { "Host" => @host }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.invalid_request")
  end

  test "valid admission rotates ceremony session and 303s to a clean sign-in URL" do
    transaction, reference = issue_admission!

    get auth_app_sign_in_url(ri: "jp", transaction_ref: reference), headers: { "Host" => @host }

    assert_response :success
    assert_includes response.body, "auth-admission-continuation-form"
    assert_no_match(/name="admission"/, response.body)

    post auth_app_sign_in_path(ri: "jp"), params: {
      transaction_ref: reference,
      authenticity_token: response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1],
    }, headers: { "Host" => @host }

    assert_response :see_other
    location = URI.parse(response.location)
    assert_equal @host, location.host

    assert_equal "/sign/in", location.path
    assert_nil Rack::Utils.parse_nested_query(location.query.to_s)["admission"]

    record = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_predicate record, :admitted?
    assert_equal transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session[:oidc_authorization_intent]
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]

    follow_redirect!

    assert_response :success
    assert_equal "auth/app/sign_ins/new", inertia_component
    assert_predicate cookies["auth_sid"].presence || cookies["__Host-auth_sid"].presence, :present?
  end

  test "admission continuation carries the existing local return target" do
    _transaction, reference = issue_admission!

    get auth_app_sign_in_url(ri: "jp", pt: "/settings/sessions?ri=jp", transaction_ref: reference),
        headers: { "Host" => @host }

    assert_response :success
    assert_includes response.body, 'name="pt"'

    post auth_app_sign_in_path(ri: "jp"), params: {
      transaction_ref: reference,
      pt: "/settings/sessions?ri=jp",
      authenticity_token: response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1],
    }, headers: { "Host" => @host }

    assert_response :see_other
    assert_equal "/sign/in", URI.parse(response.location).path
  end

  test "Base-owned local admission reaches the ceremony without creating an OIDC transaction" do
    reference = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in").reference

    get auth_app_sign_in_url(ri: "jp", entry_ref: reference), headers: { "Host" => @host }

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    post auth_app_sign_in_path(ri: "jp"), params: {
      entry_ref: reference,
      authenticity_token: response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1],
    }, headers: { "Host" => @host }

    assert_response :see_other
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_nil session[:oidc_authorization_login_challenge]

    record = ClientAuthCeremonySession.order(created_at: :desc).first

    assert_predicate record, :admitted?
    assert_nil record.authorization_transaction_ref
    assert_nil session[:auth_ceremony_admitted_intent]

    follow_redirect!

    assert_response :success
    assert_equal "auth/app/sign_ins/new", inertia_component
  end

  test "a replayed Base-owned local admission is rejected" do
    reference = BaseAuthAdmissionCoordinator.issue_local_entry!(surface: "app", intent: "sign_in").reference

    get auth_app_sign_in_url(ri: "jp", entry_ref: reference), headers: { "Host" => @host }
    post auth_app_sign_in_path(ri: "jp"), params: {
      entry_ref: reference,
      authenticity_token: response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1],
    }, headers: { "Host" => @host }

    assert_response :see_other

    get auth_app_sign_in_url(ri: "jp", entry_ref: reference), headers: { "Host" => @host }
    post auth_app_sign_in_path(ri: "jp"), params: {
      entry_ref: reference,
      authenticity_token: response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1],
    }, headers: { "Host" => @host }

    assert_response :bad_request
  end

  test "replayed admission is rejected" do
    _transaction, reference = issue_admission!

    get auth_app_sign_in_url(ri: "jp", transaction_ref: reference), headers: { "Host" => @host }
    post auth_app_sign_in_path(ri: "jp"), params: {
      transaction_ref: reference,
      authenticity_token: response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1],
    }, headers: { "Host" => @host }

    assert_response :see_other

    get auth_app_sign_in_url(ri: "jp", transaction_ref: reference), headers: { "Host" => @host }
    post auth_app_sign_in_path(ri: "jp"), params: {
      transaction_ref: reference,
      authenticity_token: response.body[/name="authenticity_token"[^>]+value="([^"]+)"/, 1],
    }, headers: { "Host" => @host }

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
    [issuance.transaction, handoff.reference]
  end
end
