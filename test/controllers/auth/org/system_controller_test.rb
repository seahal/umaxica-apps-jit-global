# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::SystemControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
  end

  test "index redirects to base org authority" do
    get auth_org_system_index_url(ri: "jp"), headers: host_headers(@host)

    assert_response :see_other
    gateway = URI.parse(response.location)
    assert_equal "jump.umaxica.net", gateway.host
    payload, = JWT.decode(Rack::Utils.parse_nested_query(gateway.query).fetch("rt"), nil, false)
    uri = URI.parse(payload.fetch("url"))

    assert_equal ENV.fetch("PUBLIC_BASE_STAFF_URL"), uri.host
    assert_equal "/system", uri.path
  end

  # Redirect-only controllers do not run PreferenceGlobal#set_region, so nothing normalizes `ri`
  # into params before the hop to Base. Forwarding the query as-is dropped the region entirely and
  # left Base to re-derive it from its own context, silently discarding the region the caller was
  # browsing in. The redirect must carry a valid region either way.
  test "index carries a normalized region to base when the request has none" do
    get auth_org_system_index_url, headers: host_headers(@host)

    assert_response :see_other
    payload, = JWT.decode(Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("rt"), nil, false)
    query = Rack::Utils.parse_nested_query(URI.parse(payload.fetch("url")).query)

    assert_equal "jp", query["ri"]
  end

  test "index preserves an explicit region across the hop to base" do
    get auth_org_system_index_url(ri: "us"), headers: host_headers(@host)

    assert_response :see_other
    payload, = JWT.decode(Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("rt"), nil, false)
    query = Rack::Utils.parse_nested_query(URI.parse(payload.fetch("url")).query)

    assert_equal "us", query["ri"]
  end

  test "index normalizes an unrecognized region instead of forwarding it" do
    get auth_org_system_index_url(ri: "xx"), headers: host_headers(@host)

    assert_response :see_other
    payload, = JWT.decode(Rack::Utils.parse_nested_query(URI.parse(response.location).query).fetch("rt"), nil, false)
    query = Rack::Utils.parse_nested_query(URI.parse(payload.fetch("url")).query)

    assert_equal "jp", query["ri"]
  end

  test "route path is preserved for compatibility" do
    assert_equal "/system", auth_org_system_index_path
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
class Auth::Org::SystemControllerTest
  private
end
