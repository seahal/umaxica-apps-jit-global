# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SignInAdmissionTest < ActionDispatch::IntegrationTest
  NAVIGATION_HEADERS = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }.freeze

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    https!
  end

  test "direct entry without admission is refused and starts no ceremony" do
    get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil cookies["auth_sid"]
  end

  test "legacy admission query is rejected without consuming a code" do
    issuance = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )

    get auth_app_sign_in_url(ri: "jp", admission: issuance.code), headers: { "Host" => @host }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.invalid_request")
  end

  test "valid admission redeems once and 303s to a clean sign-in URL" do
    transaction, reference = issue_admission!
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference:)

    admit_auth_ceremony_entry!(auth_app_sign_in_path, reference:, params: { ri: "jp" })

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @host, location.host

    assert_equal "/sign/in", location.path
    location_query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_nil location_query["admission"]
    assert_nil location_query["entry_ref"]

    binding.reload

    assert_predicate binding, :redeemed?
    attached_session_id = binding.auth_ceremony_session_id

    assert_equal AuthCeremonySession::STATUS_REPLACED,
                 ClientAuthCeremonySession.find(attached_session_id).status_id
    record = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)

    assert_equal AuthCeremonySession::STATUS_ADMITTED, record.status_id
    assert_equal transaction.transaction_id, record.authorization_transaction_ref
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil session[:oidc_authorization_intent]
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"

    assert_equal record.id, ClientAuthCeremonySession.find_active_by_raw_sid(cookies[cookie_name]).id

    follow_redirect!

    assert_response :success
    assert_equal "auth/app/sign_ins/new", inertia_component
    assert_predicate cookies["auth_sid"].presence || cookies["__Host-auth_sid"].presence, :present?
  end

  test "Auth APP sign-in state is issued in a secure host-only purpose cookie" do
    _transaction, reference = issue_admission!

    admit_auth_ceremony_entry!(auth_app_sign_in_path, reference:, params: { ri: "jp" })
    follow_redirect!

    assert_response :success
    headers = Array(response.headers["Set-Cookie"]).join("\n")
    purpose_cookie = headers.lines.find { |line| line.start_with?("__Host-umaxica-sign-in=") }

    assert_not_nil purpose_cookie, "sign-in state should use its purpose-specific cookie"
    assert_includes purpose_cookie, "Secure"
    assert_includes purpose_cookie, "HttpOnly"
    assert_includes purpose_cookie, "Path=/"
    assert_not_match(/\bDomain=/i, purpose_cookie)
  end

  test "a tampered sign-in purpose cookie shows restart guidance without changing cookies" do
    _transaction, reference = issue_admission!
    admit_auth_ceremony_entry!(auth_app_sign_in_path, reference:, params: { ri: "jp" })
    follow_redirect!
    cookies_before = cookies.to_hash.deep_dup
    cookie_header = cookies_before.map { |name, value| "#{name}=#{value}" }.join("; ")
    cookie_header = [cookie_header, "__Host-umaxica-sign-in=not-an-encrypted-cookie"].compact_blank.join("; ")

    get auth_app_sign_in_url(ri: "jp"), headers: { "Cookie" => cookie_header }

    assert_response :conflict
    assert_includes response.body, "最初からやり直してください"
    assert_equal cookies_before, cookies.to_hash
  end

  test "an unsigned local return target is not carried into the clean sign-in URL" do
    _transaction, reference = issue_admission!

    admit_auth_ceremony_entry!(
      auth_app_sign_in_path, reference:, params: { ri: "jp", pt: "/settings/sessions?ri=jp" },
    )

    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal "/sign/in", location.path
    assert_nil Rack::Utils.parse_nested_query(location.query.to_s)["pt"]
  end

  test "a replayed Base-owned admission without its Auth cookie is refused" do
    issuance = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference: issuance.reference)
    admit_auth_ceremony_entry!(auth_app_sign_in_path, reference: issuance.reference, params: { ri: "jp" })

    assert_response :see_other
    binding.reload
    admitted_session_id = binding.admitted_auth_ceremony_session_id
    cookie_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    cookies.delete(cookie_name)

    assert_no_difference -> { ClientAuthCeremonySession.count } do
      get auth_app_sign_in_url(ri: "jp", entry_ref: issuance.reference),
          headers: NAVIGATION_HEADERS.merge("Host" => @host)
    end

    # A redeemed reference whose Auth session no longer matches is a phase conflict (D-52/B-01),
    # not a context-free entry: the browser is told the screen went stale instead of a bare 400.
    assert_response :conflict
    assert_equal AuthAdmissionBinding::REDEEMED_STATUS_ID, binding.reload.status_id
    assert_equal admitted_session_id, binding.admitted_auth_ceremony_session_id
    assert_equal AuthCeremonySession::STATUS_ADMITTED,
                 ClientAuthCeremonySession.find(admitted_session_id).status_id
  end

  test "replayed admission returns to the clean sign-in ceremony" do
    _transaction, reference = issue_admission!

    admit_auth_ceremony_entry!(auth_app_sign_in_path, reference:, params: { ri: "jp" })

    assert_response :see_other
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "app", reference:)
    admitted_session_id = binding.admitted_auth_ceremony_session_id
    sessions_before_replay = ClientAuthCeremonySession.count

    get auth_app_sign_in_url(ri: "jp", entry_ref: reference),
        headers: NAVIGATION_HEADERS.merge("Host" => @host)

    assert_response :see_other
    assert_equal "/sign/in", URI.parse(response.location).path
    assert_equal sessions_before_replay, ClientAuthCeremonySession.count
    assert_equal admitted_session_id, binding.reload.admitted_auth_ceremony_session_id
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
    issuance = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )
    [issuance.transaction, issuance.reference]
  end
end
