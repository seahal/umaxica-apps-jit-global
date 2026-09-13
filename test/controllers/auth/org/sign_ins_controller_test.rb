# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::SignInsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
  end

  test "direct entry without a login challenge lists the sign-in methods" do
    get auth_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_nil session[:oidc_authorization_login_challenge]
    assert_equal "auth/org/sign/ins/show", inertia_component
    assert_includes method_hrefs, auth_org_social_entra_session_path(ri: "jp")
    assert_includes method_hrefs, new_auth_org_sign_in_emergency_passkey_path(ri: "jp")
  end

  # Normal sign-in has one entry, Entra, because the passkey and secret
  # ceremonies are its second stage and refuse to run on their own. Emergency
  # Access is the other entry, and it is a different ceremony, not another way
  # to sign in normally.
  test "direct entry lists entra and emergency access as siblings in one list" do
    get auth_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    methods = inertia_props.fetch("methods")

    assert_equal 2, methods.length
    assert_equal "provider", method_for("entra").fetch("kind")
    assert_equal auth_org_social_entra_session_path(ri: "jp"), method_for("entra").fetch("href")
    assert_equal "link", method_for("emergency").fetch("kind")
    assert_equal new_auth_org_sign_in_emergency_passkey_path(ri: "jp"), method_for("emergency").fetch("href")

    # The second stage is not offered as an entry point of its own.
    assert_not_includes method_hrefs, new_auth_org_sign_in_passkey_path(ri: "jp")
    assert_not_includes method_hrefs, new_auth_org_sign_in_secret_path(ri: "jp")
  end

  test "direct entry offers the reciprocal sign up link" do
    get auth_org_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :success
    assert_equal auth_org_sign_up_path(ri: "jp"), inertia_props.fetch("registration_link").fetch("href")
  end

  test "valid login challenge renders local ceremony" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get auth_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success
    assert_equal issuance.transaction.login_challenge, session[:oidc_authorization_login_challenge]
  end

  test "local ceremony renders authentication links only" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get auth_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success

    query = { ri: "jp" }

    assert_includes method_hrefs, auth_org_social_entra_session_path(query)
    assert_includes method_hrefs, new_auth_org_sign_in_emergency_passkey_path(query)
    # The org surface offers no consumer social providers.
    assert_empty method_hrefs.grep(%r{/social/auth/|/auth/google|/auth/apple})
  end

  test "local ceremony ignores inbound pt and keeps authentication links on ceremony flow" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get auth_org_sign_in_url(
      ri: "jp",
      pt: Base64.urlsafe_encode64("https://log.umaxica.org/settings/sessions?ri=jp", padding: false),
      login_challenge: issuance.transaction.login_challenge,
    ), headers: { "Host" => @host }

    assert_response :success
    assert_includes method_hrefs, auth_org_social_entra_session_path(ri: "jp")
    assert_includes method_hrefs, new_auth_org_sign_in_emergency_passkey_path(ri: "jp")
  end

  test "local ceremony does not render sign up link on sign in page" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get auth_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success
    assert_nil inertia_props["registration_link"]
  end

  test "local ceremony renders back to root link" do
    issuance = OidcAuthorizationTransactionCoordinator.issue!(
      surface: "org",
      intent: "sign_in",
      params: authorize_params,
    )

    get auth_org_sign_in_url(ri: "jp", login_challenge: issuance.transaction.login_challenge),
        headers: { "Host" => @host }

    assert_response :success

    base_staff_host = ENV.fetch("PRIVATE_BASE_STAFF_URL", "base.org.localhost")

    assert_equal auth_org_root_url(ri: "jp", host: base_staff_host),
                 inertia_props.fetch("back_to_root").fetch("href")
  end

  test "rejects direct entry when logged in without account-switching guidance" do
    staff = operators(:one)

    get auth_org_sign_in_url(ri: "jp"), headers: as_staff_headers(staff, host: @host)

    assert_response :conflict
    assert_equal "text/plain; charset=utf-8", response.headers["Content-Type"]
    assert_equal "Sign-in is unavailable while authenticated.", response.body
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  private

  def method_hrefs
    inertia_props.fetch("methods").map { |method| method.fetch("href") }
  end

  def method_for(key)
    inertia_props.fetch("methods").find { |method| method.fetch("key") == key }
  end

  def authorize_params
    {
      response_type: "code",
      client_id: "core-next-rp",
      redirect_uri: OidcClientRegistry.find!("core-next-rp").redirect_uris.first,
      code_challenge: "challenge",
      code_challenge_method: "S256",
      state: "state",
      nonce: "nonce",
      scope: "openid profile",
    }
  end
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

    base
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
      base["Authorization"] = "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }"
    end

    base
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

    base
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::Org::SignInsControllerTest
  private
end
