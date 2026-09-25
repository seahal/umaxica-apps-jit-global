# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Base::Org::SwitcherControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  test "unauthenticated operator cannot access switcher" do
    get base_org_switcher_url(host: @host), headers: host_headers(@host), as: :json

    assert_response :unauthorized
  end

  test "authenticated operator can access switcher show" do
    select_token!
    get base_org_switcher_url(host: @host), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    ), as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "HTML switcher page displays the optional Avatar candidate context" do
    select_token!
    get base_org_switcher_url(host: @host, ri: "jp"), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    )

    assert_response :success
    assert_equal "base/org/switchers/show", inertia_component
    assert_equal base_org_dashboard_path(ri: "jp"), inertia_props.dig("up_link", "href")
    assert_nil inertia_props.fetch("candidates").first.fetch("avatar_public_id")
  end

  test "authenticated operator can access switcher update" do
    select_token!
    candidate = BaseSwitcherAuthority.current(
      surface: :org,
      principal: @operator,
      session: @token,
    ).fetch(:candidates).first
    patch base_org_switcher_url(host: @host), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    ), params: {
      account_public_id: candidate.fetch(:public_id),
      organization_public_id: candidate.dig(:organization, :public_id),
      organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
      avatar_public_id: candidate.dig(:avatar, :public_id),
    }, as: :json

    assert_response :success
    assert_equal "switched", response.parsed_body.fetch("status")
    assert_predicate @token.reload, :selected_actor_context?
  end

  test "operator can select an org-owned Avatar without making it the operator identity" do
    bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    avatar_result = AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: bootstrap.account,
      avatar_params: { moniker: "Bureau avatar" },
      handle_params: { handle: "bureau-avatar" },
      owner_surface: "org",
      owner_collective_public_id: bootstrap.collective.public_id,
    )

    assert_predicate avatar_result, :success?

    candidates = BaseSwitcherAuthority.current(
      surface: :org,
      principal: @operator,
      session: @token,
    ).fetch(:candidates)
    avatar_candidate =
      candidates.find { |candidate|
        candidate.dig(:avatar, :public_id) == avatar_result.avatar.public_id
      }

    assert avatar_candidate

    patch base_org_switcher_url(host: @host), headers: as_staff_headers(
      @operator,
      host: @host,
      session_public_id: @token.public_id,
    ), params: {
      account_public_id: avatar_candidate.fetch(:public_id),
      organization_public_id: avatar_candidate.dig(:organization, :public_id),
      organization_unit_public_id: avatar_candidate.dig(:organization, :unit_public_id),
      avatar_public_id: avatar_candidate.dig(:avatar, :public_id),
    }, as: :json

    assert_response :success
    assert_equal "switched", response.parsed_body.fetch("status")
    assert_equal avatar_result.avatar.public_id, @token.reload.selected_avatar_public_id
    assert_equal bootstrap.account.public_id, @token.selected_account_public_id
  end

  private

  def select_token!
    BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
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
class Base::Org::SwitcherControllerTest
  private
end

# DAMP: authenticated header helpers that attach a real JWT access cookie so the
# Base RP authentication pipeline recognizes the logged-in session instead of
# redirecting to /oauth/authorize. This final reopening overrides any earlier
# helper definitions in this file so every "logged in" request carries a valid
# access token cookie for the correct actor and surface.
class Base::Org::SwitcherControllerTest
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
    token ||= ClientToken.where(user_id: user.id).where("discard_at > ?", Time.current).order(created_at: :desc).first
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
      "discard_at > ?",
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
      "discard_at > ?",
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
