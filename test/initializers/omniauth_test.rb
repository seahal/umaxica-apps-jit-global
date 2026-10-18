# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OmniauthTest < ActiveSupport::TestCase
  test "omniauth request phase uses social path prefix" do
    assert_equal "/social", OmniAuth.config.path_prefix
  end

  test "omniauth request phase accepts only POST" do
    assert_equal [:post], OmniAuth.config.allowed_request_methods
  end

  test "Google requests online access only" do
    initializer = Rails.root.join("config/initializers/omniauth.rb").read

    assert_includes initializer, 'access_type: "online"'
    assert_not_includes initializer, 'access_type: "offline"'
  end

  test "callback origin ignores the request host" do
    env = Rack::MockRequest.env_for(
      "https://attacker.example.test/social/google/callback",
      "HTTP_HOST" => "attacker.example.test",
    )

    assert_equal OmniAuthCallbackOrigin.callback_origin, OmniAuthCallbackOrigin.call(env)
  end

  test "callback origin is a valid configured origin" do
    assert_match %r{\Ahttps?://}, OmniAuthCallbackOrigin.callback_origin
    assert_predicate OmniAuthCallbackOrigin.callback_host, :present?
  end

  test "apple failure logs nonce context without raw nonce values" do
    env = Rack::MockRequest.env_for("/social/failure?message=invalid_credentials&strategy=apple")
    env["omniauth.error.type"] = "invalid_credentials"
    env["omniauth.error.strategy"] = Struct.new(:name).new("apple")
    env["omniauth.error"] = StandardError.new("id_token_claims_invalid | nonce invalid")
    env["rack.session"] = {
      "omniauth.nonce" => "strategy-nonce",
      :social_auth_nonce => "app-nonce",
    }

    logged = []
    logger = Struct.new(:logged) do
      def error(*)
      end

      def info(message = nil)
        logged << JSON.parse(message, symbolize_names: true) if message.to_s.start_with?("{")
      end
    end.new(logged)

    Rails.stub(:logger, logger) do
      OmniAuth.config.on_failure.call(env)
    end

    event = logged.find { |entry| entry[:event] == "social_auth.apple.nonce_failure_context" }

    assert_not_nil event
    assert_equal "/social/failure", event.dig(:data, :request_path)
    assert_equal "GET", event.dig(:data, :request_method)
    assert event.dig(:data, :strategy_has_value)
    assert event.dig(:data, :app_has_value)
    assert_not_includes logged.to_s, "strategy-nonce"
    assert_not_includes logged.to_s, "app-nonce"
  end

  test "omniauth failure logs normalized metadata without the provider exception message" do
    env = Rack::MockRequest.env_for("/social/failure?message=invalid_credentials&strategy=google")
    env["omniauth.error.type"] = "invalid_credentials"
    env["omniauth.error.strategy"] = Struct.new(:name).new("google")
    provider_secret = "audit-provider-response-token-not-a-real-secret"
    env["omniauth.error"] = StandardError.new("provider response contained #{provider_secret}")

    errors = []
    logger = Struct.new(:errors) do
      def error(message)
        errors << message
      end

      def info(*)
      end
    end.new(errors)

    Rails.stub(:logger, logger) do
      OmniAuth.config.on_failure.call(env)
    end

    event = errors.map { |message| JSON.parse(message) }.find { |entry| entry["event"] == "social_auth.failure" }

    assert_not_nil event
    assert_equal "google", event.dig("data", "strategy")
    assert_equal "invalid_credentials", event.dig("data", "type")
    assert_equal "StandardError", event.dig("data", "error_class")
    assert_not_includes errors.join("\n"), provider_secret
  end

  test "omniauth failure stops with a plain-text fatal error when the strategy raised a code defect" do
    env = Rack::MockRequest.env_for("/social/google", method: "POST")
    env["omniauth.error.type"] = "undefined method 'bytesize' for nil"
    env["omniauth.error.strategy"] = Struct.new(:name).new("google")
    defect = NoMethodError.new("undefined method 'bytesize' for nil")
    defect.set_backtrace(["#{Rails.root.join("lib/example.rb:1:in 'call'")}"])
    env["omniauth.error"] = defect

    errors = []
    logger = Struct.new(:errors) do
      def error(message)
        errors << message
      end
    end.new(errors)

    status, headers, body = Rails.stub(:logger, logger) { OmniAuth.config.on_failure.call(env) }
    text = +""
    body.each { |chunk| text << chunk }

    assert_equal 500, status
    assert_equal "text/plain; charset=utf-8", headers["Content-Type"]
    assert_nil headers["Location"]
    assert_equal "致命的なエラーが発生しました", text

    event = errors.map { |message| JSON.parse(message) }.find { |entry| entry["event"] == "social_auth.fatal" }

    assert_equal "NoMethodError", event.dig("data", "error_class")
    assert_equal "#{Rails.root.join("lib/example.rb:1:in 'call'")}", event.dig("data", "origin")
    assert_not_includes errors.join("\n"), "bytesize"
  end

  test "omniauth failure keeps redirecting to the failure endpoint for an ordinary provider error" do
    env = Rack::MockRequest.env_for("/social/google/callback")
    env["omniauth.error.type"] = "invalid_credentials"
    env["omniauth.error.strategy"] = Struct.new(:name).new("google")
    env["omniauth.error"] = StandardError.new("provider rejected the code")

    status, headers, = Rails.stub(:logger, Logger.new(nil)) { OmniAuth.config.on_failure.call(env) }

    assert_equal 302, status
    assert_equal "/social/failure?message=invalid_credentials&strategy=google", headers["Location"]
  end
end
