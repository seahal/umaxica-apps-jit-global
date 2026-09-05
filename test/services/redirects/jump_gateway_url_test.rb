# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectsJumpGatewayUrlTest < ActiveSupport::TestCase
  test "builds jump gateway url with rt query" do
    with_env("PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net") do
      token = "#{"a" * 22}.#{"b" * 22}.#{"c" * 22}"
      result = RedirectsJumpGatewayUrl.call(token)

      assert_predicate result, :ok?
      assert_equal "https://jump.umaxica.net/?rt=#{token}", result.value
      query = Rack::Utils.parse_query(URI.parse(result.value).query)

      assert_equal token, query.fetch("rt")
    end
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
    private_key = OpenSSL::PKey::EC.generate("secp384r1")
    with_env(
      "JWT_SIGN_APP_ACTIVE_KID" => "sign-app-es384-test-a",
      "PRIVATE_AUTH_SERVICE_URL" => "log.umaxica.app",
      "PUBLIC_JUMP_GATEWAY_URL" => "https://jump.umaxica.net",
    ) do
      JumpRtKeyring.stub(:private_key, private_key) do
        token = JumpRtIssuer.call(namespace: "SIGN_APP", url: "https://www.umaxica.app/dashboard")
        result = RedirectsJumpGatewayUrl.call(token)

        assert_predicate result, :ok?
        assert_equal token, Rack::Utils.parse_query(URI.parse(result.value).query).fetch("rt")
      end
    end
  end

  test "rejects invalid gateway origin URI" do
    with_env("PUBLIC_JUMP_GATEWAY_URL" => "://invalid") do
      result = RedirectsJumpGatewayUrl.call("#{"a" * 22}.#{"b" * 22}.#{"c" * 22}")

      assert_not result.ok?
      assert_equal "invalid_uri", result.failure_reason
    end
  end

  test "rejects unsafe gateway origins" do
    with_env("PUBLIC_JUMP_GATEWAY_URL" => "http://jump.example") do
      result = RedirectsJumpGatewayUrl.call("#{"a" * 22}.#{"b" * 22}.#{"c" * 22}")

      assert_not result.ok?
      assert_equal "invalid_uri", result.failure_reason
    end
  end

  # The one exception to the https requirement. A developer runs the gateway over plain http on a
  # `.localhost` name, and requiring https there would break every local jump redirect; allowing it
  # anywhere else would let a redirect leave over cleartext. Both halves of the host test are
  # pinned, since `localhost` itself does not end with `.localhost`.
  test "a plain http gateway origin is allowed only on a local host name" do
    ["http://jump.localhost", "http://localhost:3000"].each do |origin|
      with_env("PUBLIC_JUMP_GATEWAY_URL" => origin) do
        result = RedirectsJumpGatewayUrl.call("#{"a" * 22}.#{"b" * 22}.#{"c" * 22}")

        assert_predicate result, :ok?, "#{origin} must be usable in a local environment"
        assert result.value.start_with?("#{origin}/?rt=")
      end
    end
  end

  private

  def with_env(values)
    previous = values.transform_values { |_value| nil }
    values.each do |key, value|
      previous[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
