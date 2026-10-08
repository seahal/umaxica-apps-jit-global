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

  test "new renders the existing membership entry with a parent link" do
    get new_base_app_organization_membership_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    page = JSON.parse(css_select("script[data-page='app']").first.text)

    assert_equal "base/app/organizations/memberships/new", page.fetch("component")
    assert_equal base_app_organization_memberships_path(@organization_public_id, ri: "jp"),
                 page.fetch("props").dig("up_link", "href")
  end

  test "edit renders the existing membership entry with a parent link" do
    get edit_base_app_organization_membership_url(@organization_public_id, @membership.id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    page = JSON.parse(css_select("script[data-page='app']").first.text)

    assert_equal "base/app/organizations/memberships/edit", page.fetch("component")
    assert_equal base_app_organization_membership_path(@organization_public_id, @membership.id, ri: "jp"),
                 page.fetch("props").dig("up_link", "href")
  end

  test "HTML membership index links only to memberships the principal can read" do
    other = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    other_bootstrap = BaseSelectorBootstrapAuthority.call(surface: :app, principal: other)
    foreign_membership = @bootstrap.collective.persona_memberships.create!(
      persona: other_bootstrap.account, enterprise_unit: @membership.enterprise_unit,
      membership_kind_id: @membership.membership_kind_id,
      membership_state_id: @membership.membership_state_id,
    )
    get base_app_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    page = JSON.parse(css_select("script[data-page='app']").first.text)
    props = page.fetch("props")

    assert_equal "base/app/organizations/memberships/index", page.fetch("component")
    assert_equal [base_app_organization_membership_path(@organization_public_id, @membership.id, ri: "jp")],
                 props.fetch("entries").map { |entry| entry.fetch("href") }
    assert_equal new_base_app_organization_membership_path(@organization_public_id, ri: "jp"),
                 props.dig("create_action", "href")
    assert_not props.fetch("entries").any? { |entry| entry.fetch("public_id") == foreign_membership.id.to_s }

    get base_app_organization_membership_url(@organization_public_id, foreign_membership.id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host), as: :json

    assert_response :forbidden
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
        "AUTH"
      else
        "BASE"
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
end
