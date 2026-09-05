# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseHealthsControllerTest < ActionDispatch::IntegrationTest
  test "network host GET /health returns OK response without redirect" do
    host! ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost")

    get base_network_health_url, headers: browser_headers

    assert_response :success

    assert_health_response
  end

  test "network host health probes return OK without redirect" do
    host! ENV.fetch("PRIVATE_BASE_NETWORK_URL", "base.net.localhost")

    get base_network_health_liveness_url, headers: browser_headers

    assert_probe_response("liveness")

    get base_network_health_readiness_url, headers: browser_headers

    assert_probe_response("readiness")

    get base_network_health_startup_url, headers: browser_headers

    assert_probe_response("startup")
  end

  test "developer host GET /health returns OK response without redirect" do
    host! ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost")

    get base_developer_health_url, headers: browser_headers

    assert_response :success

    assert_health_response
  end

  test "developer host health probes return OK without redirect" do
    host! ENV.fetch("PRIVATE_BASE_DEVELOPER_URL", "base.dev.localhost")

    get base_developer_health_liveness_url, headers: browser_headers

    assert_probe_response("liveness")

    get base_developer_health_readiness_url, headers: browser_headers

    assert_probe_response("readiness")

    get base_developer_health_startup_url, headers: browser_headers

    assert_probe_response("startup")
  end

  private

  def assert_health_response
    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain", response.media_type
    assert_not_equal "text/html", response.media_type
    assert_match(/\Astatus: \w+\nstartup: \w+\nliveness: \w+\nreadiness: \w+\n\z/, response.body)
  end

  def assert_probe_response(_check)
    assert_response :success
    assert_not_predicate response, :redirect?
    assert_equal "text/plain", response.media_type
    assert_not_equal "application/json", response.media_type
    assert_equal "ok\n", response.body
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
class BaseHealthsControllerTest
  private
end
