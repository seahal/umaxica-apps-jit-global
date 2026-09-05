# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::App::Organizations::MembershipsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @user)
    @organization_public_id = @bootstrap.collective.public_id
    @membership = @bootstrap.account.current_memberships.first
  end

  test "unauthenticated cannot access memberships" do
    get base_app_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
        headers: host_headers(@host)

    assert_response :redirect
  end

  test "index returns empty json" do
    get base_app_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host), as: :json

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "new renders plain text" do
    get new_base_app_organization_membership_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_equal "New Membership", response.body
  end

  test "edit renders plain text" do
    get edit_base_app_organization_membership_url(@organization_public_id, @membership.id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_equal "Edit Membership", response.body
  end

  test "create returns unprocessable content" do
    post base_app_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
         headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
  end

  test "update returns unprocessable content" do
    patch base_app_organization_membership_url(@organization_public_id, @membership.id, ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
  end

  test "destroy returns no content" do
    delete base_app_organization_membership_url(@organization_public_id, @membership.id, ri: "jp", host: @host),
           headers: as_user_headers(@user, host: @host)

    assert_response :no_content
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

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end
end

# DAMP auth header helpers for this test class.
class Base::App::Organizations::MembershipsControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::App::Organizations::MembershipsControllerTest
  test "show returns empty json for a membership the actor may read" do
    get base_app_organization_membership_url(@organization_public_id, @membership.id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host), as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
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

  # Derive the issuer id from the test host. Base RP hosts (www.umaxica.app/.org/.com)
  # must resolve to surface:BASE_* so the access token issuer matches the surface the
  # controller validates against.
  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service =
      if normalized.include?("acme")
        "ACME"
      elsif normalized.include?("core")
        "CORE"
      elsif normalized.include?("auth") || normalized.include?("sign") || normalized.include?("log.umaxica")
        "SIGN"
      else
        "BASE"
      end
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

  def ensure_visitor_token_reference_records!
    VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
    VisitorTokenStatus.find_or_create_by!(id: VisitorTokenStatus::ACTIVE)
    VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::LEGACY)
    VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
  end

  def as_user_headers(user, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-USER" => user.id.to_s)
    return base unless user.respond_to?(:persisted?) && user.persisted? && user.class.name == "Client"

    ensure_user_token_reference_records!
    token = session_public_id.present? ? ClientToken.find_by(public_id: session_public_id) : nil
    token ||= ClientToken.where(user_id: user.id).where("discarded_at > ?", Time.current).order(created_at: :desc).first
    token ||= ClientToken.create!(
      user_id: user.id,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      user_token_binding_method_id: ClientTokenBindingMethod::LEGACY,
      user_token_dbsc_status_id: ClientTokenDbscStatus::NOTHING,
    )
    token_public_id = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(user, host: host, session_public_id: token_public_id, resource_type: "client")
    set_access_cookie(access_token)
    base["Cookie"] = [base["Cookie"], "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"].compact.join("; ")
    base["X-TEST-SESSION-PUBLIC-ID"] = token_public_id
    base
  end

  def as_staff_headers(staff, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-STAFF" => staff.id.to_s)
    return base unless staff.respond_to?(:persisted?) && staff.persisted? && staff.class.name == "Operator"

    ensure_staff_token_reference_records!
    token = session_public_id.present? ? OperatorToken.find_by(public_id: session_public_id) : nil
    token ||= OperatorToken.where(staff_id: staff.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= OperatorToken.create!(
      staff_id: staff.id,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_binding_method_id: OperatorTokenBindingMethod::LEGACY,
      staff_token_dbsc_status_id: OperatorTokenDbscStatus::NOTHING,
    )
    token_public_id = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      staff, host: host, session_public_id: token_public_id,
             resource_type: "operator",
    )
    set_access_cookie(access_token)
    base["Cookie"] = [base["Cookie"], "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"].compact.join("; ")
    base["X-TEST-SESSION-PUBLIC-ID"] = token_public_id
    base
  end

  def as_visitor_headers(visitor, host: nil, headers: {}, session_public_id: nil)
    base = host_headers(host).merge(headers).merge("X-TEST-CURRENT-RESOURCE" => visitor.id.to_s)
    return base unless visitor.respond_to?(:persisted?) && visitor.persisted? && visitor.class.name == "Visitor"

    ensure_visitor_token_reference_records!
    token = session_public_id.present? ? VisitorToken.find_by(public_id: session_public_id) : nil
    token ||= VisitorToken.where(visitor_id: visitor.id).where(
      "discarded_at > ?",
      Time.current,
    ).order(created_at: :desc).first
    token ||= VisitorToken.create!(
      visitor_id: visitor.id,
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      visitor_token_binding_method_id: VisitorTokenBindingMethod::LEGACY,
      visitor_token_dbsc_status_id: VisitorTokenDbscStatus::NOTHING,
    )
    token_public_id = session_public_id.presence || token.public_id
    access_token = jwt_access_token_for(
      visitor, host: host, session_public_id: token_public_id,
               resource_type: "visitor",
    )
    set_access_cookie(access_token)
    base["Cookie"] = [base["Cookie"], "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{access_token}"].compact.join("; ")
    base["X-TEST-SESSION-PUBLIC-ID"] = token_public_id
    base
  end
end
