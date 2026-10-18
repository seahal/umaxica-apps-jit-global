# typed: false
# frozen_string_literal: true

require "test_helper"

class RequestBodySizeLimitTest < ActiveSupport::TestCase
  test "allows a JSON body at the configured boundary and preserves it for Rails" do
    body = "x" * RequestBodySizeLimit::MAX_JSON_BODY_BYTES
    received = nil
    app =
      lambda do |env|
        received = env.fetch("rack.input").read
        [200, { "content-type" => "application/json" }, ["{}"]]
      end

    status, = RequestBodySizeLimit.new(app).call(env_for_json(body))

    assert_equal 200, status
    assert_equal body, received
  end

  test "rejects a JSON body above the boundary before the downstream app reads it" do
    called = false
    app =
      lambda do |_env|
        called = true
        [200, {}, [""]]
      end
    body = "x" * (RequestBodySizeLimit::MAX_JSON_BODY_BYTES + 1)

    status, headers, = RequestBodySizeLimit.new(app).call(env_for_json(body))

    assert_equal 413, status
    assert_equal "application/problem+json", headers.fetch("Content-Type")
    assert_not called
  end

  test "rejects a chunked JSON body above the boundary without trusting Content-Length" do
    called = false
    app =
      lambda do |_env|
        called = true
        [200, {}, [""]]
      end
    body = "x" * (RequestBodySizeLimit::MAX_JSON_BODY_BYTES + 1)
    env = env_for_json(body).except("CONTENT_LENGTH")
    env["HTTP_TRANSFER_ENCODING"] = "chunked"

    status, = RequestBodySizeLimit.new(app).call(env)

    assert_equal 413, status
    assert_not called
  end

  test "rejects compressed JSON rather than applying the limit to an unsupported encoding" do
    called = false
    app =
      lambda do |_env|
        called = true
        [200, {}, [""]]
      end
    env = env_for_json("compressed")
    env["HTTP_CONTENT_ENCODING"] = "gzip"

    status, = RequestBodySizeLimit.new(app).call(env)

    assert_equal 415, status
    assert_not called
  end

  test "rejects a malformed JSON Content-Length before reading the body" do
    called = false
    app =
      lambda do |_env|
        called = true
        [200, {}, [""]]
      end
    env = env_for_json("{}")
    env["CONTENT_LENGTH"] = "not-a-length"

    status, = RequestBodySizeLimit.new(app).call(env)

    assert_equal 400, status
    assert_not called
  end

  test "rejects a negative JSON Content-Length before reading the body" do
    called = false
    app =
      lambda do |_env|
        called = true
        [200, {}, [""]]
      end
    env = env_for_json("{}")
    env["CONTENT_LENGTH"] = "-1"

    status, = RequestBodySizeLimit.new(app).call(env)

    assert_equal 400, status
    assert_not called
  end

  private

  def env_for_json(body)
    Rack::MockRequest.env_for(
      "/api/v0/test",
      :method => "POST",
      :input => StringIO.new(body),
      "CONTENT_TYPE" => "application/json",
      "CONTENT_LENGTH" => body.bytesize.to_s,
      "action_dispatch.request_id" => "request-body-limit-test",
    )
  end
end
