# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Sign::In::SessionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_statuses, :operator_token_kinds

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

  test "show with restricted session displays sessions" do
    active_token = create_active_session(@staff)
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    get auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :success
    assert_not response.redirect?
    assert_equal "auth/org/sign/in/sessions/show", inertia_component
    assert_equal auth_org_sign_in_session_path(ri: "jp"), inertia_props.fetch("form_action")
    # Sessions are chosen one at a time by signed reference, never by a multi-select of ids.
    assert_nil inertia_props["revoke_session_ids"]
    assert_equal I18n.t("session_limit.edit.cancel_logout"), inertia_props.fetch("cancel_logout_label")
    rendered_ref = inertia_props.fetch("sessions").first.fetch("ref")

    assert_equal active_token, OperatorToken.find_from_signed_ref(rendered_ref)
  end

  test "show with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    get auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- authentication & access control
  # ===================================================================

  test "update without authentication redirects to login" do
    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: browser_headers.merge(
            "Host" => @host,
            "Origin" => "http://#{@host}",
            "HTTP_ORIGIN" => "http://#{@host}",
          )

    assert_response :redirect
    assert_match %r{/sign/in}, response.location
  end

  test "update with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: ["some-ref"] },
          headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # update -- empty selections
  # ===================================================================

  test "update without selections flashes alert and re-renders show" do
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [] },
          headers: headers

    assert_response :unprocessable_content
  end

  # ===================================================================
  # update -- revoke by refs (batch) + promotion
  # ===================================================================

  test "update revokes selected sessions and promotes restricted session" do
    active_token1 = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token1.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal OperatorTokenStatus::ACTIVE, restricted_token.staff_token_status_id

    active_token1.reload

    assert_not active_token1.currently_usable?
  end

  test "update revokes session but does not promote when still at limit" do
    # Create 1 active session -- revoking 0 keeps at limit
    active_token1 = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    # Send an invalid ref so nothing actually gets revoked
    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: ["invalid_ref_value"] },
          headers: headers

    # Still restricted -- not promoted because active_count == MAX_SESSIONS_PER_STAFF
    restricted_token.reload

    assert_equal OperatorTokenStatus::RESTRICTED, restricted_token.staff_token_status_id
    assert_response :success # re-renders show
  end

  test "update skips current session ref in batch revoke" do
    # Need 1 active session to prevent auto-promotion after no-op revoke
    active_token1 = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    # Try to revoke the current (restricted) session via refs -- should be skipped
    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [restricted_token.signed_ref] },
          headers: headers

    restricted_token.reload
    # Actor session should NOT be revoked via batch refs
    assert_equal OperatorTokenStatus::RESTRICTED, restricted_token.staff_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "update ignores ref belonging to another staff" do
    other_staff = operators(:two)
    OperatorToken.where(staff: other_staff).delete_all
    other_token = OperatorToken.create!(staff: other_staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [other_token.signed_ref] },
          headers: headers

    # Other staff's token must remain untouched
    other_token.reload

    assert_predicate other_token, :currently_usable?
  end

  # ===================================================================
  # update -- revoke by single ref param
  # ===================================================================

  test "update with ref param revokes specific session" do
    active_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { ref: active_token.signed_ref },
          headers: headers

    active_token.reload

    assert_not active_token.currently_usable?

    # With only 1 active left (now 0 after revoke), restricted should be promoted
    restricted_token.reload

    assert_equal OperatorTokenStatus::ACTIVE, restricted_token.staff_token_status_id
  end

  test "update with ref param rejects revoking current session" do
    # Need 1 active session to prevent auto-promotion
    active_token1 = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { ref: restricted_token.signed_ref },
          headers: headers

    restricted_token.reload

    assert_equal OperatorTokenStatus::RESTRICTED, restricted_token.staff_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "update with invalid ref param flashes alert and stays on page" do
    # Need 1 active session to prevent auto-promotion
    active_token1 = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token1.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { ref: "totally_invalid_ref" },
          headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal OperatorTokenStatus::RESTRICTED, restricted_token.staff_token_status_id
  end

  # ===================================================================
  # update -- redirect after promotion
  # ===================================================================

  test "update promotes and redirects to settings path by default" do
    active_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    assert_response :redirect
    assert_match %r{\Ahttps://jump\.umaxica\.net/}, response.location
    assert_includes response.location, "rt="
  end

  test "update with pt param redirects to the requested path" do
    active_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)
    pt = "/settings"

    patch auth_org_sign_in_session_url(ri: "jp", pt: pt),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal OperatorTokenStatus::ACTIVE, restricted_token.staff_token_status_id
    assert_response :redirect
    assert_match %r{\Ahttps://jump\.umaxica\.net/}, response.location
    assert_includes response.location, "rt="
  end

  test "update with invalid pt param falls back to default path" do
    active_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    patch auth_org_sign_in_session_url(ri: "jp", pt: "not-a-token"),
          params: { revoke_refs: [active_token.signed_ref] },
          headers: headers

    restricted_token.reload

    assert_equal OperatorTokenStatus::ACTIVE, restricted_token.staff_token_status_id
    assert_response :redirect
    assert_match %r{\Ahttps://jump\.umaxica\.net/}, response.location
    assert_includes response.location, "rt="
  end

  # ===================================================================
  # destroy -- authentication & access control
  # ===================================================================

  test "destroy without authentication redirects to login" do
    delete auth_org_sign_in_session_url(ri: "jp"),
           headers: browser_headers.merge(
             "Host" => @host,
             "Origin" => "http://#{@host}",
             "HTTP_ORIGIN" => "http://#{@host}",
           )

    assert_response :redirect
    assert_match %r{/sign/in}, response.location
  end

  test "destroy with active session returns forbidden" do
    active_token = create_active_session(@staff)
    headers = as_staff_headers_with_token(@staff, active_token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :forbidden
  end

  # ===================================================================
  # destroy -- cancel restricted session (no ref)
  # ===================================================================

  test "destroy cancels restricted session and redirects to login" do
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :see_other
    assert_match %r{/sign/in}, response.location

    token.reload

    assert_not token.currently_usable?
    assert_equal OperatorTokenStatus::REVOKED, token.staff_token_status_id
  end

  test "delete session route cancels restricted session and redirects to login" do
    token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"), headers: headers

    assert_response :see_other
    assert_match %r{/sign/in}, response.location

    token.reload

    assert_not token.currently_usable?
    assert_equal OperatorTokenStatus::REVOKED, token.staff_token_status_id
  end

  # ===================================================================
  # destroy -- revoke specific session (with ref)
  # ===================================================================

  test "destroy with ref param revokes specific session and re-renders show" do
    active_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    active_token.rotate_refresh_token!

    restricted_token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::RESTRICTED)
    restricted_token.rotate_refresh_token!

    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"),
           params: { ref: active_token.signed_ref },
           headers: headers

    assert_response :success # re-renders show, does not redirect

    active_token.reload

    assert_not active_token.currently_usable?

    # Restricted session remains (not cancelled)
    restricted_token.reload

    assert_equal OperatorTokenStatus::RESTRICTED, restricted_token.staff_token_status_id
  end

  test "destroy with ref param rejects revoking current session" do
    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"),
           params: { ref: restricted_token.signed_ref },
           headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal OperatorTokenStatus::RESTRICTED, restricted_token.staff_token_status_id
    assert_predicate restricted_token, :currently_usable?
  end

  test "destroy with invalid ref param does not revoke anything" do
    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"),
           params: { ref: "invalid_ref" },
           headers: headers

    assert_response :success # re-renders show
    restricted_token.reload

    assert_equal OperatorTokenStatus::RESTRICTED, restricted_token.staff_token_status_id
  end

  test "destroy with ref belonging to another staff does not revoke" do
    other_staff = operators(:two)
    OperatorToken.where(staff: other_staff).delete_all
    other_token = OperatorToken.create!(staff: other_staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    other_token.rotate_refresh_token!

    restricted_token = create_restricted_session(@staff)
    headers = as_staff_headers_with_token(@staff, restricted_token, host: @host)

    delete auth_org_sign_in_session_url(ri: "jp"),
           params: { ref: other_token.signed_ref },
           headers: headers

    other_token.reload

    assert_predicate other_token, :currently_usable?
  end

  # ===================================================================
  # restricted session expiry (boundary analysis)
  # ===================================================================

  test "restricted session at 14 minutes is still accessible (boundary: within TTL)" do
    token = create_restricted_session(@staff, discarded_at: 15.minutes.from_now)
    headers = as_staff_headers_with_token(@staff, token, host: @host, expires_at: 30.minutes.from_now)

    travel 14.minutes do
      get auth_org_sign_in_session_url(ri: "jp"), headers: headers

      assert_response :success
    end

    assert_response :success
    token.reload

    assert_equal OperatorTokenStatus::RESTRICTED, token.staff_token_status_id
  end

  test "restricted session expires after 15 minutes and is locked" do
    token = create_restricted_session(@staff, discarded_at: 15.minutes.from_now)
    headers = as_staff_headers_with_token(@staff, token, host: @host)
    logs = []

    travel 16.minutes do
      Rails.logger.stub(
        :info, ->(*args) do
                 message = args.first
                 logs << JSON.parse(message, symbolize_names: true) if message.present?
               end,
      ) do
        get auth_org_sign_in_session_url(ri: "jp"), headers: headers
      end
    end

    assert_response :locked
    assert_equal "きんそくじこうです", response.body
    assert_not response.redirect?
    assert_includes logs.pluck(:event), "session.restricted.expired"
  end

  # ===================================================================
  # RestrictedSessionGuard -- non-session routes blocked for org
  # ===================================================================

  test "restricted session is blocked on non-session base org routes" do
    token = create_restricted_session(@staff)
    base_host = ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost")
    headers = {
      "Host" => base_host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get auth_org_dashboard_url(ri: "jp", host: base_host), headers: headers

    assert_response :bad_request
  end

  private

  def create_restricted_session(staff, discarded_at: nil)
    token = OperatorToken.create!(
      staff: staff,
      staff_token_status_id: OperatorTokenStatus::RESTRICTED,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    token.rotate_refresh_token!(discarded_at: discarded_at)
    token
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
          ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
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
            "discarded_at > ?",
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
            "discarded_at > ?",
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

# DAMP auth header helpers for this test class.
class Auth::Org::Sign::In::SessionsControllerTest
  private

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end
