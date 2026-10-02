# typed: false
# frozen_string_literal: true

require "test_helper"

class RedirectsJumpGatewayUrlTest < ActiveSupport::TestCase
  test "builds jump gateway url with rt query on the boot-validated PUBLIC_JUMP_GATEWAY_URL origin" do
    token = "#{"a" * 22}.#{"b" * 22}.#{"c" * 22}"
    result = RedirectsJumpGatewayUrl.call(token)

    assert_predicate result, :ok?
    assert_equal "https://jump.umaxica.net/?rt=#{token}", result.value
    assert_equal token, Rack::Utils.parse_query(URI.parse(result.value).query).fetch("rt")
  end

  test "a removed gateway setting in the runtime ENV cannot redirect the gateway" do
    ENV["JUMP_GATEWAY_URL"] = "https://evil.example"
    token = "#{"a" * 22}.#{"b" * 22}.#{"c" * 22}"

    assert_equal "https://jump.umaxica.net/?rt=#{token}", RedirectsJumpGatewayUrl.call(token).value
  ensure
    ENV.delete("JUMP_GATEWAY_URL")
  end

  test "rejects malformed tokens" do
    assert_not RedirectsJumpGatewayUrl.call("xxx").ok?
    assert_not RedirectsJumpGatewayUrl.call("").ok?
    assert_not RedirectsJumpGatewayUrl.call("aaa.bbb").ok?
    assert_not RedirectsJumpGatewayUrl.call("aaa..ccc").ok?
    assert_not RedirectsJumpGatewayUrl.call("aaa.bbb.ccc=").ok?
    assert_not RedirectsJumpGatewayUrl.call("aaa.bbb.ccc+").ok?
    assert_not RedirectsJumpGatewayUrl.call("aaa.bbb.ccc/").ok?
    assert_not RedirectsJumpGatewayUrl.call("aaa.bbb.ccc\n").ok?
  end

  test "rejects extremely short three-part tokens" do
    result = RedirectsJumpGatewayUrl.call("aaa.bbb.ccc")

    assert_not result.ok?
    assert_equal "token_too_short", result.failure_reason
  end

  test "accepts rails issued jwt" do
    token = JumpRtIssuer.call(namespace: "AUTH_APP", url: "https://www.umaxica.app/dashboard")
    result = RedirectsJumpGatewayUrl.call(token)

    assert_predicate result, :ok?
    assert_equal token, Rack::Utils.parse_query(URI.parse(result.value).query).fetch("rt")
  end

  test "a plain http gateway origin is refused even in a local environment" do
    boot_config = { jump: Struct.new(:origin).new("http://jump.localhost") }

    Rails.configuration.x.stub(:boot_config, boot_config) do
      result = RedirectsJumpGatewayUrl.call("#{"a" * 22}.#{"b" * 22}.#{"c" * 22}")

      assert_not result.ok?
      assert_equal "https_required", result.failure_reason
    end
  end
end
