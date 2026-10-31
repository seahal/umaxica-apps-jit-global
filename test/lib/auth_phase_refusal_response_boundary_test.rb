# frozen_string_literal: true

require "test_helper"

class AuthPhaseRefusalResponseBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "marked conflict filters exact authentication cookies and DBSC headers after downstream response" do
    downstream =
      lambda do |_env|
        [409, {
          "set-cookie" => [
            "auth_sid=old; Path=/; Expires=Wed, 21 Oct 2030 07:28:00 GMT",
            "auth_sid_extra=keep; Path=/", "preference=keep; Path=/", "__Host-session=old; Path=/",
          ],
          "Secure-Session-Challenge" => "challenge",
          "location" => "/elsewhere",
          "authorization" => "preserved",
          "Cache-Control" => "public",
        }, ["refused"],]
      end
    env = { AuthPhaseRefusalResponseBoundary::ENV_KEY => true, "REQUEST_METHOD" => "POST" }

    status, headers, body = AuthPhaseRefusalResponseBoundary.new(downstream).call(env)

    assert_equal 409, status
    assert_equal ["auth_sid_extra=keep; Path=/", "preference=keep; Path=/"], headers.fetch("set-cookie")
    assert_not headers.key?("Secure-Session-Challenge")
    assert_not headers.key?("location")
    assert_not headers.key?("Cache-Control")
    assert_equal "private, no-store", headers.fetch("cache-control")
    assert_equal "preserved", headers.fetch("authorization")
    assert_equal ["refused"], body
  end

  test "newline cookie headers preserve expires commas and HEAD has no body" do
    app =
      ->(_) {
        [409, { "set-cookie" => "session=x; Path=/\nother=y; Expires=Wed, 21 Oct 2030 07:28:00 GMT" }, ["body"]]
      }
    env = { AuthPhaseRefusalResponseBoundary::ENV_KEY => true, "REQUEST_METHOD" => "HEAD" }

    status, headers, body = AuthPhaseRefusalResponseBoundary.new(app).call(env)

    assert_equal 409, status
    assert_equal "other=y; Expires=Wed, 21 Oct 2030 07:28:00 GMT", headers.fetch("set-cookie")
    assert_empty body
  end

  test "every protected cookie and DBSC header is filtered without prefix matching" do
    protected_cookies = %w(
      __Host-session session __Host-auth_sid auth_sid __Host-auth_access auth_access
      __Host-auth_refresh auth_refresh __Host-auth_dbsc auth_dbsc
    )
    protected_headers = %w(
      Secure-Session-Registration Secure-Session-Challenge Secure-Session-Id Secure-Session-Response
      Secure-Session-Skipped Sec-Session-Registration Sec-Session-Challenge Sec-Session-Id
      Sec-Session-Response Sec-Session-Skipped
    )
    headers = protected_headers.index_with { "value" }
    headers["set-cookie"] = protected_cookies.flat_map { |name| ["#{name}=x", "#{name}_extra=y"] }
    headers["Sec-Session-Id-Extra"] = "keep"
    env = { AuthPhaseRefusalResponseBoundary::ENV_KEY => true, "REQUEST_METHOD" => "GET" }
    _, filtered, = AuthPhaseRefusalResponseBoundary.new(->(_) { [409, headers, []] }).call(env)

    assert_equal protected_cookies.map { |name| "#{name}_extra=y" }, filtered.fetch("set-cookie")
    protected_headers.each { |name| assert_not filtered.key?(name), name }
    assert_equal "keep", filtered.fetch("Sec-Session-Id-Extra")
  end

  test "malformed cookie header fails closed" do
    app = ->(_) { [409, { "set-cookie" => ["auth_sid=x", 1] }, ["body"]] }
    env = { AuthPhaseRefusalResponseBoundary::ENV_KEY => true, "REQUEST_METHOD" => "POST" }

    status, headers, = AuthPhaseRefusalResponseBoundary.new(app).call(env)

    assert_equal 500, status
    assert_not headers.key?("set-cookie")
  end

  test "comma combined authentication cookie fails closed" do
    app = ->(_) { [409, { "set-cookie" => "other=y, auth_sid=x; Path=/" }, ["body"]] }
    env = { AuthPhaseRefusalResponseBoundary::ENV_KEY => true, "REQUEST_METHOD" => "POST" }

    status, headers, = AuthPhaseRefusalResponseBoundary.new(app).call(env)

    assert_equal 500, status
    assert_not headers.key?("set-cookie")
  end

  test "downstream errors are not handled by the response filter" do
    app = ->(_) { raise ArgumentError, "downstream failure" }

    assert_raises(ArgumentError) { AuthPhaseRefusalResponseBoundary.new(app).call({}) }
  end

  test "unmarked and non-conflict responses remain unchanged" do
    response = [409, { "set-cookie" => "auth_sid=x" }, ["body"]]
    boundary = AuthPhaseRefusalResponseBoundary.new(->(_) { response })

    assert_same response[1], boundary.call({})[1]
    response[0] = 400

    assert_same response[1], boundary.call({ AuthPhaseRefusalResponseBoundary::ENV_KEY => true })[1]
  end
end
