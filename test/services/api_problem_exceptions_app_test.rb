# typed: false
# frozen_string_literal: true

require "test_helper"

class ApiProblemExceptionsAppTest < ActiveSupport::TestCase
  test "an api path is answered with a problem document rather than an html page" do
    status, headers, body = call(status: 404, original_path: "/api/v0/entries/missing")

    assert_equal 404, status
    assert_equal "application/problem+json", headers.fetch("content-type")

    document = JSON.parse(body.first)

    assert_equal "urn:umaxica:problem:not-found", document.fetch("type")
    assert_equal 404, document.fetch("status")
    assert_equal "/api/v0/entries/missing", document.fetch("instance")
  end

  test "the status member always agrees with the status line" do
    { 400 => "bad-request", 404 => "not-found", 500 => "server-error", 503 => "service-unavailable" }
      .each do |code, slug|
        status, _headers, body = call(status: code, original_path: "/api/v0/session")
        document = JSON.parse(body.first)

        assert_equal code, status
        assert_equal code, document.fetch("status")
        assert_equal "urn:umaxica:problem:#{slug}", document.fetch("type")
      end
  end

  test "an unmapped status still resolves to a registered type" do
    _status, _headers, body = call(status: 418, original_path: "/api/v0/session")

    assert_equal "urn:umaxica:problem:bad-request", JSON.parse(body.first).fetch("type")

    _status, _headers, server_body = call(status: 507, original_path: "/api/v0/session")

    assert_equal "urn:umaxica:problem:server-error", JSON.parse(server_body.first).fetch("type")
  end

  test "the document carries no exception detail" do
    _status, _headers, body = call(status: 500, original_path: "/api/v0/session")
    document = JSON.parse(body.first)

    # `detail` is returned to the caller, and an exception message can carry parameters, identifiers,
    # or internal state. The request id is the only correlation handle the client gets.
    assert_not document.key?("detail")
    assert_equal "req-1", document.fetch("request_id")
  end

  test "an error response is never cacheable" do
    _status, headers, _body = call(status: 500, original_path: "/api/v0/session")

    assert_equal "no-store", headers.fetch("cache-control")
  end

  test "a non-api path is delegated to the static html pages" do
    _status, headers, _body = call(status: 404, original_path: "/some/page")

    assert_includes headers.fetch("content-type"), "text/html"
  end

  test "the legacy edge and web namespaces are not claimed" do
    # They still render their own error shapes from controllers, so answering their routing misses
    # with Problem Details would give one endpoint two different error formats.
    _status, edge_headers, _body = call(status: 404, original_path: "/edge/v0/token/check")
    _status, web_headers, _body = call(status: 404, original_path: "/web/v0/in/email/otp")

    assert_includes edge_headers.fetch("content-type"), "text/html"
    assert_includes web_headers.fetch("content-type"), "text/html"
  end

  private

  # Mirrors what ActionDispatch::ShowExceptions hands the exceptions app: PATH_INFO rewritten to the
  # status, and the real path stashed in `action_dispatch.original_path`.
  def call(status:, original_path:)
    env = Rack::MockRequest.env_for("https://core.app.localhost/#{status}")
    env["action_dispatch.original_path"] = original_path
    env["action_dispatch.request_id"] = "req-1"
    ApiProblemExceptionsApp.call(env)
  end
end
