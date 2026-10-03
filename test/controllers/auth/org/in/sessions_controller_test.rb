# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "minitest/mock"
require "base64"

class Auth::Org::Sign::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  include OrgEntraFirstStageHelper

  fixtures :operators, :operator_statuses, :operator_token_statuses, :operator_token_kinds,
           :operator_passkeys, :operator_passkey_statuses

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    @staff = operators(:one)
    # Clean up any existing tokens for this staff
    OperatorToken.where(staff: @staff).delete_all
    @original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_allow_forgery_protection
  end

  # ===================================================================
  # show -- authentication & access control
  # ===================================================================

  test "show without authentication redirects to login" do
    get auth_org_sign_in_session_url(ri: "jp"),
        headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_match %r{/sign/in}, response.location
  end

  test "migrated settings sessions route is not served by sign" do
    with_env(
      "PRIVATE_AUTH_STAFF_URL" => "auth.org.localhost",
      "AUTH_STAFF_URL" => "log.umaxica.org",
      "BASE_STAFF_URL" => "www.umaxica.org",
    ) do
      Rails.application.reload_routes!

      get(
        "https://log.umaxica.org/settings/sessions?ri=jp",
        headers: browser_headers.merge("Host" => "log.umaxica.org"),
      )

      assert_response :not_found
      assert_nil response.location
    end
  ensure
    Rails.application.reload_routes!
  end

  # The page opens only for a verified sign-in flow waiting on the session limit, reached here
  # through the real Entra + passkey ceremony (adr/root-login-establishment-boundary.md).

  test "show for a pending sign-in lists the active session and offers only cancellation" do
    existing = enter_pending_session_limit!

    get auth_org_sign_in_session_url(ri: "jp")

    assert_response :success
    assert_equal "auth/org/sign/in/sessions/show", inertia_component
    assert_equal auth_org_sign_in_session_path(ri: "jp"), inertia_props.fetch("form_action")
    assert_nil inertia_props["revoke_session_ids"]
    assert_not inertia_props.key?("back_link")
    assert_equal I18n.t("session_limit.edit.cancel_logout"), inertia_props.fetch("cancel_logout_label")
    rendered_ref = inertia_props.fetch("sessions").first.fetch("ref")

    assert_equal existing.first, OperatorToken.find_from_signed_ref(rendered_ref)
  end

  test "show with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    get auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  test "a legacy restricted session does not open the page" do
    token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    get auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :redirect
    assert_match %r{/sign/in}, response.location
  end

  test "update without authentication redirects to login" do
    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_match %r{/sign/in}, response.location
  end

  test "update with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"), params: { revoke_refs: ["some-ref"] }, headers: headers

    assert_response :forbidden
  end

  test "update without selections keeps the flow pending" do
    enter_pending_session_limit!

    patch auth_org_sign_in_session_url(ri: "jp"), params: { revoke_refs: [] }

    assert_response :unprocessable_content
    assert_predicate latest_flow, :sign_in_session_limit_pending?
  end

  test "update revokes the selected session and commits the waiting sign-in" do
    existing = enter_pending_session_limit!

    assert_difference(-> { OperatorToken.where(staff_id: @staff.id).count }, 1) do
      patch auth_org_sign_in_session_url(ri: "jp"), params: { revoke_refs: [existing.first.signed_ref] }
    end

    assert_response :redirect
    assert_not existing.first.reload.currently_usable?
    issued = OperatorToken.where(staff_id: @staff.id).order(:id).last

    assert_predicate issued, :active_status?
    assert_equal issued.id, latest_flow.token_id
  end

  test "update with an unusable ref issues nothing while the limit is full" do
    enter_pending_session_limit!

    assert_no_difference(-> { OperatorToken.where(staff_id: @staff.id).count }) do
      patch auth_org_sign_in_session_url(ri: "jp"), params: { ref: "totally_invalid_ref" }
    end

    assert_response :success
    assert_predicate latest_flow, :sign_in_session_limit_pending?
  end

  test "update ignores ref belonging to another staff" do
    other_staff = operators(:two)
    OperatorToken.where(staff: other_staff).delete_all
    other_token = OperatorToken.create!(staff: other_staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    enter_pending_session_limit!

    patch auth_org_sign_in_session_url(ri: "jp"), params: { revoke_refs: [other_token.signed_ref] }

    assert_predicate other_token.reload, :currently_usable?
    assert_predicate latest_flow, :sign_in_session_limit_pending?
  end

  test "destroy without authentication redirects to login" do
    delete auth_org_sign_in_session_url(ri: "jp"), headers: browser_headers.merge("Host" => @host)

    assert_response :redirect
    assert_match %r{/sign/in}, response.location
  end

  test "destroy with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  test "destroy cancels only the waiting flow and keeps the existing session" do
    existing = enter_pending_session_limit!
    flow = latest_flow

    delete auth_org_sign_in_session_url(ri: "jp")

    assert_response :see_other
    assert_redirected_to auth_org_sign_in_url(ri: "jp")
    assert_predicate flow.reload, :sign_in_failed?
    assert(existing.all? { |token| token.reload.currently_usable? })
  end

  test "destroy with ref param revokes that session and re-renders show" do
    existing = enter_pending_session_limit!

    delete auth_org_sign_in_session_url(ri: "jp"), params: { ref: existing.first.signed_ref }

    assert_response :success
    assert_not existing.first.reload.currently_usable?
  end

  test "destroy with ref belonging to another staff does not revoke" do
    other_staff = operators(:two)
    OperatorToken.where(staff: other_staff).delete_all
    other_token = OperatorToken.create!(staff: other_staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    enter_pending_session_limit!

    delete auth_org_sign_in_session_url(ri: "jp"), params: { ref: other_token.signed_ref }

    assert_predicate other_token.reload, :currently_usable?
  end

  private

  # Fills the one-session limit, then completes Entra and the passkey stage so this browser holds a
  # verified flow in SESSION_LIMIT_PENDING. Returns the session that fills the limit.
  def enter_pending_session_limit!
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    existing = Array.new(OperatorToken::MAX_SESSIONS_PER_STAFF) { create_active_session(@staff) }
    passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: Base64.urlsafe_encode64("staff_limit_#{SecureRandom.hex(6)}", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "staff_login_key",
      description: "Staff Login Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    complete_org_entra_first_stage!(@staff)
    post(auth_org_sign_in_passkey_options_url(ri: "jp"), params: {})
    challenge_id = response.parsed_body.fetch("challenge_id")
    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)
    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post(
        auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
          challenge_id: challenge_id,
          credential: {
            id: passkey.webauthn_id,
            response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
          },
        },
      )
    end

    assert_equal "session_limit_pending", response.parsed_body.fetch("status")
    assert_predicate latest_flow, :sign_in_session_limit_pending?
    existing
  ensure
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  def latest_flow
    OperatorSignInFlow.where(principal_id: @staff.id).recent_first.first
  end

  def create_active_session(staff)
    token = OperatorToken.create!(
      staff: staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!
    token
  end

  def as_staff_headers_with_token(staff, token, host:, expires_at: 30.minutes.from_now)
    access_token = AuthenticationToken.encode(
      staff, host: host, session_public_id: token.public_id,
             resource_type: "operator",
             expires_at: expires_at,
             jwt_issuer_id: jwt_issuer_id_for_test_host(host, "operator"),
    )
    browser_headers.merge(
      "Host" => host,
      "Origin" => "http://#{host}",
      "HTTP_ORIGIN" => "http://#{host}",
      "Authorization" => "Bearer #{access_token}",
      "Cookie" => [
        "csrf_token=test_csrf_token",
        "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}",
      ].join("; "),
    )
  end

  def with_env(vars)
    original = {}
    vars.each_key { |key| original[key] = ENV[key] }

    vars.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
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
          ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
        end
      token ||= ClientToken.create!(user_id: user.id, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
    end

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(user, host: host, session_public_id: token.public_id, resource_type: "client")
      }",
    )
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(staff, host: host, session_public_id: token.public_id, resource_type: "operator")
      }",
    )
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

    base.merge(
      "Authorization" => "Bearer #{
        jwt_access_token_for(visitor, host: host, session_public_id: token.public_id, resource_type: "visitor")
      }",
    )
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
    service =
      if normalized.include?("base") || normalized.include?("www.")
        "BASE"
      elsif normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      else
        "AUTH"
      end
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

# DAMP auth header helpers for this test class.
class Auth::Org::Sign::In::SessionsControllerTest
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end
