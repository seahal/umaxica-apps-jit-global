# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PublicRobotsRoutingTest < ActionDispatch::IntegrationTest
  test "acme surfaces define public file helpers" do
    assert_public_file_helpers(
      robots: %i(acme_com_robots_path acme_app_robots_path acme_org_robots_path),
      sitemap: %i(acme_com_sitemap_path acme_app_sitemap_path acme_org_sitemap_path),
    )
  end

  test "sign surfaces define public file helpers" do
    assert_public_file_helpers(
      robots: %i(sign_com_robots_path sign_app_robots_path sign_org_robots_path),
      sitemap: %i(sign_com_sitemap_path sign_app_sitemap_path sign_org_sitemap_path),
    )
  end

  test "base and palm surfaces define public file helpers" do
    assert_public_file_helpers(
      robots: %i(
        base_app_robots_path base_com_robots_path base_org_robots_path
        palm_app_robots_path
      ),
      sitemap: %i(
        base_app_sitemap_path base_com_sitemap_path base_org_sitemap_path
        palm_app_sitemap_path
      ),
    )
  end

  test "core surfaces do not define public file helpers" do
    %i(
      core_app_robots_path core_com_robots_path core_org_robots_path
      core_app_sitemap_path core_com_sitemap_path core_org_sitemap_path
    ).each do |helper|
      assert_not_respond_to self, helper
    end
  end

  test "content surfaces delegate robots to Next.js" do
    %i(
      help_app_robot_path help_com_robot_path help_org_robot_path
      docs_app_robot_path docs_com_robot_path docs_org_robot_path
      news_app_robot_path news_com_robot_path news_org_robot_path
    ).each do |helper|
      assert_not_respond_to self, helper
    end
  end

  test "public file endpoints respond without redirect" do
    endpoints = [
      [method(:base_app_robots_url), ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), "robots"],
      [method(:base_com_robots_url), ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"), "robots"],
      [method(:base_org_robots_url), ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), "robots"],
      [method(:palm_app_robots_url), ENV["PUBLIC_PALM_SERVICE_URL"] || "palm.app.localhost", "robots"],
      [method(:base_app_sitemap_url), ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), "sitemap"],
      [method(:base_com_sitemap_url), ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"), "sitemap"],
      [method(:base_org_sitemap_url), ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), "sitemap"],
      [method(:palm_app_sitemap_url), ENV["PUBLIC_PALM_SERVICE_URL"] || "palm.app.localhost", "sitemap"],
      [method(:acme_com_robots_url), ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost"), "robots"],
      [method(:acme_app_robots_url), ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"), "robots"],
      [method(:acme_org_robots_url), ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost"), "robots"],
      [method(:sign_com_robots_url), ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "id.com.localhost"), "robots"],
      [method(:sign_app_robots_url), ENV["PRIVATE_AUTH_SERVICE_URL"] || "id.app.localhost", "robots"],
      [method(:sign_org_robots_url), ENV["PRIVATE_AUTH_STAFF_URL"] || "id.org.localhost", "robots"],
      [method(:acme_com_sitemap_url), ENV.fetch("PRIVATE_BASE_CORPORATE_URL", "www.com.localhost"), "sitemap"],
      [method(:acme_app_sitemap_url), ENV.fetch("PRIVATE_BASE_SERVICE_URL", "www.app.localhost"), "sitemap"],
      [method(:acme_org_sitemap_url), ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost"), "sitemap"],
      [method(:sign_com_sitemap_url), ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "id.com.localhost"), "sitemap"],
      [method(:sign_app_sitemap_url), ENV["PRIVATE_AUTH_SERVICE_URL"] || "id.app.localhost", "sitemap"],
      [method(:sign_org_sitemap_url), ENV["PRIVATE_AUTH_STAFF_URL"] || "id.org.localhost", "sitemap"],
    ]

    endpoints.each do |helper, host, kind|
      host! host
      get helper.call(ri: "jp"), headers: browser_headers

      assert_response :success
      assert_not_predicate response, :redirect?
      if kind == "robots"
        assert_equal "text/plain; charset=utf-8", response.content_type
        assert_equal "User-agent: *\nDisallow:\n", response.body
      else
        assert_equal "application/xml; charset=utf-8", response.content_type
      end
    end
  end

  private

  def assert_public_file_helpers(robots:, sitemap:)
    robots.each do |helper|
      assert_respond_to self, helper
      assert_equal "/robots.txt", public_send(helper)
    end

    sitemap.each do |helper|
      assert_respond_to self, helper
      assert_equal "/sitemap.xml", public_send(helper)
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
            "discard_at > ?",
            Time.current,
          ).order(created_at: :desc).first
        end
      token ||= OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      base["X-TEST-SESSION-PUBLIC-ID"] = session_public_id.presence || token.public_id
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
            "discard_at > ?",
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
class PublicRobotsRoutingTest
  private
end

# DAMP local route helper aliases for former shared test support.
class PublicRobotsRoutingTest
  SURFACE_ROUTE_PREFIX_MAP = {
    "sign_app_" => "auth_app_",
    "sign_org_" => "auth_org_",
    "sign_com_" => "auth_com_",
    "acme_app_" => "base_app_",
    "acme_org_" => "base_org_",
    "acme_com_" => "base_com_",
  }.freeze unless const_defined?(:SURFACE_ROUTE_PREFIX_MAP, false)

  private

  def method_missing(name, ...)
    aliased_name = aliased_surface_route_helper_name(name)
    return public_send(aliased_name, ...) if aliased_name && respond_to?(aliased_name, true)

    super
  end

  def respond_to_missing?(name, include_private = false)
    aliased_name = aliased_surface_route_helper_name(name)
    (aliased_name && respond_to?(aliased_name, include_private)) || super
  end

  def aliased_surface_route_helper_name(name)
    helper_name = name.to_s
    self.class::SURFACE_ROUTE_PREFIX_MAP.each do |source_prefix, target_prefix|
      return helper_name.sub(source_prefix, target_prefix).to_sym if helper_name.start_with?(source_prefix)
    end
    nil
  end
end
