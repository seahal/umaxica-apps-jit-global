# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"

class Auth::App::VerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost")
    @user = clients(:one)
    @headers = as_user_headers(@user, host: @host)
    ClientEmail.create!(
      user: @user,
      address: "verification-link-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_private_key: "otp_private_key",
      otp_counter: "0",
    )
  end

  test "should get show" do
    get auth_app_verification_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_equal(
      { "label" => I18n.t("actions.cancel"),
        "action" => auth_app_verification_cancellation_path(ri: "jp"),
        "method" => "post", },
      inertia_props.fetch("cancel"),
    )
  end

  test "redirects to setup page when no verification methods are registered" do
    user = Client.create!
    headers = as_user_headers(user, host: @host)

    get auth_app_verification_url(ri: "jp"), headers: headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["pt"], :present?
  end

  test "show renders method links when scope and return_to are provided" do
    return_to = Base64.urlsafe_encode64("/settings/emails?ri=jp")

    get auth_app_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :success
    assert_equal "auth/app/verifications/show", inertia_component
    assert_equal I18n.t("sign.app.verification.index.title"), inertia_props.fetch("title")
    assert inertia_method_hrefs.any? { |href| href.start_with?(new_auth_app_verification_email_path(ri: "jp")) }
  end

  test "show handles bad request error" do
    get auth_app_verification_url(scope: "settings_email", return_to: "%%%INVALID%%%", ri: "jp"),
        headers: @headers

    assert_response :success
    assert inertia_method_hrefs.any? { |href| href.start_with?(new_auth_app_verification_email_path(ri: "jp")) }
  end

  test "show handles scope and return target mismatch without redirecting back to verification" do
    return_to = Base64.urlsafe_encode64("/settings/mfa/challenge?ri=jp")

    get auth_app_verification_url(scope: "settings_email", pt: return_to, ri: "jp"),
        headers: @headers

    assert_response :redirect
    assert_redirected_to auth_app_settings_path(ri: "jp")
  end

  test "show discards expired step_up session instead of redirecting to itself" do
    token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    ClientStepUpSession.create!(
      user_token: token,
      scope: "settings_email",
      return_to: "/settings/emails?ri=jp",
      status: "PENDING",
      discard_at: 1.minute.ago,
      purge_eligible_at: 1.minute.from_now,
    )

    get auth_app_verification_url(ri: "jp"), headers: @headers

    assert_response :redirect
    assert_redirected_to auth_app_settings_path(ri: "jp")
    assert_nil token.reload.step_up_session
  end

  test "show with recent verification shows success message" do
    # Create a token with recent step_up
    token = ClientToken.find_by(user_id: @user.id)
    token&.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_email")

    get auth_app_verification_url(ri: "jp"), headers: @headers

    # Should show success or verification page
    assert_response :success
  end

  private

  def inertia_method_hrefs
    inertia_props.fetch("methods").map { |method| method.fetch("href") }
  end

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
          ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
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
            "discard_at > ?",
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
            "discard_at > ?",
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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Auth::App::VerificationsControllerTest
  private

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
