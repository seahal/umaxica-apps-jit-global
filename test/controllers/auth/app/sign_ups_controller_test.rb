# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::App::SignUpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  setup { host! host }

  test "direct entry without a login challenge is refused without admission" do
    get auth_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
  end

  test "direct entry without a login challenge starts no OIDC handoff state" do
    get auth_app_sign_up_url(format: :html, ri: "jp"), headers: { "Host" => host }

    assert_nil session[:oidc_code_verifier]
    assert_nil session[:oidc_state]
    assert_nil session[:oidc_nonce]
    assert_nil session["oidc_pending_flows"]
  end

  test "valid login challenge renders local ceremony" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
  end

  test "reloading OIDC sign-up entry after a Flow starts is refused without mutation" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
    sid_name = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    sid = cookies[sid_name]
    ceremony = ClientAuthCeremonySession.find_active_by_raw_sid(sid)
    flow = ClientSignUpFlow.create!(
      auth_admission_binding: binding.reload,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      entry_method: "email",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: Time.current,
      expires_at: ClientSignUpFlow.default_ttl.from_now,
    )
    records = [transaction, binding, ceremony, flow]
    before = records.map { |record| record.reload.attributes }
    session_before = session.to_hash

    get auth_app_sign_up_path(format: :html, ri: "jp"), headers: headers

    assert_equal [409, nil, I18n.t("errors.messages.phase_violation_refused"), "private, no-store"], [
      response.status, response.location, response.body, response.headers["Cache-Control"],
    ]
    assert_equal before, records.map { |record| record.reload.attributes }
    assert_equal session_before, session.to_hash
    assert_equal sid, cookies[sid_name]
    forbidden_names = (AuthPhaseRefusalResponseBoundary::COOKIE_NAMES + AuthPhaseRefusalResponseBoundary::DBSC_HEADERS)
      .map(&:downcase)
    cookie_lines = Array(response.headers["Set-Cookie"]).flat_map { |header| header.to_s.split("\n") }
    cookie_names = cookie_lines.map { |header| header.split("=", 2).first.downcase }
    response_names = cookie_names + response.headers.to_h.keys.map(&:downcase)

    assert_empty forbidden_names & response_names
  end

  test "sets lang attribute on html element" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_select("html[lang=?]", "ja")
    assert_not_select("html[lang=?]", "")
  end

  test "shows registration methods and social providers" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success

    # The four entry points the page offers: two contact methods and two providers.
    assert_equal 4, inertia_props.fetch("methods").size + inertia_props.fetch("social_providers").size
    # The first Sign Up page of an OIDC parent offers Cancel. This parent has the fixed sign_up
    # intent that prompt=create produces, so no Switch to Sign In and no plain link to it (D06).
    assert_equal "/sign/cancellation?ri=jp", inertia_props.fetch("cancel_form").fetch("action")
    assert_nil inertia_props.fetch("switch_form")
    assert_empty inertia_props.fetch("links")
  end

  test "shows telephone registration link" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
    assert_equal(
      [new_auth_app_sign_up_telephone_path(ri: "jp")],
      inertia_props.fetch("methods").filter_map { |method| method.fetch("href") if method.fetch("key") == "telephone" },
    )
  end

  test "shows social login buttons" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
    # The provider buttons keep posting to the ceremony endpoints; the button markup and its
    # CSRF field are covered by gait/features/auth/signup/social_provider_button.test.tsx.
    providers = inertia_props.fetch("social_providers")

    assert_equal(
      [["google", auth_app_social_google_registration_path(ri: "jp")],
       ["apple", auth_app_social_apple_registration_path(ri: "jp")],],
      providers.map { |provider| [provider.fetch("provider"), provider.fetch("url")] },
    )
  end

  test "renders registration layout structure" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success

    expected_brand = brand_name

    # The header, the main region and the footer are the React surface layout's; what the server
    # still owns is the chrome payload it renders them from.
    assert_select "head", count: 1
    assert_select "body", count: 1
    assert_match(/^©.*#{Regexp.escape(expected_brand)}$/, inertia_props.fetch("chrome").fetch("copyright"))
  end

  test "page renders the registration heading and no sign-in/up chrome navigation" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
    # The auth surface is itself the sign-in/sign-up entry point, so its shared header carries no
    # navigation back to those flows.
    assert_not inertia_props.fetch("chrome").key?("primary_navigation")
    assert_equal I18n.t("sign.app.registration.new.page_title"), inertia_props.fetch("title")
  end

  test "footer contains navigation links" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
    # Footer should contain copyright and links
    assert_not_empty inertia_props.fetch("chrome").fetch("footer_navigation")
    assert_not_empty inertia_props.fetch("chrome").fetch("copyright")
  end

  test "renders specific cta text" do
    client = OidcClientRegistry.find!("core-app-jp")
    transaction = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "app", intent: "sign_up", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris.first,
        code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        code_challenge_method: "S256",
        state: SecureRandom.urlsafe_base64(16),
        nonce: SecureRandom.urlsafe_base64(16),
        scope: "openid profile",
        prompt: "create",
      },
    ).transaction
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction: transaction, base_browser_nonce: nonce, base_token: nil,
    )
    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.reference)
    headers = {
      "Host" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
    https!
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    get response.location, headers: headers

    assert_response :see_other
    binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
    get auth_app_sign_up_path(format: :html), params: { ri: "jp", entry_ref: issuance.reference }, headers: headers

    assert_response :see_other
    follow_redirect!

    assert_response :success
    # Check for Japanese text (since previous test asserted lang=ja)
    assert_includes inertia_props.fetch("methods").map { |method| method.fetch("label") }, "メールで登録する"
  end

  test "logged in direct entry is refused with a plain 403" do
    user = clients(:one)
    get auth_app_sign_up_url(format: :html, ri: "jp"), headers: as_user_headers(user, host: host)

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil response.location
  end

  test "checkpoint without a sign-up admission is refused with the uniform error" do
    get auth_app_sign_up_guard_email_path(ri: "jp"), headers: { "Host" => host }

    # D-73: ownership is not proven, so nothing is redirected or ended.
    assert_response :bad_request
    assert_nil response.location
  end

  private

  def host
    ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
  end

  def brand_name
    (ENV["BRAND_NAME"].presence || ENV["NAME"]).to_s
  end

  private
end

# DAMP auth header helpers for this test class.
class Auth::App::SignUpsControllerTest
  private
end

# DAMP local helper copy on the test class.
class Auth::App::SignUpsControllerTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
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
    %w(AUTH_APP AUTH_ORG ACME_APP ACME_ORG CORE_APP CORE_ORG BASE_APP BASE_ORG).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
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

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
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
