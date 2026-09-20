# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialCallbackGuardIncludedDoTest < ActiveSupport::TestCase
  test "REQUEST_PHASE_PATH constant is defined" do
    assert_kind_of Regexp, SocialCallbackGuard::REQUEST_PHASE_PATH
  end

  test "request phase rejects missing and mismatched sources" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, ["id.example.test"])
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, ["https://id.example.test"])

    missing_source_env = Rack::MockRequest.env_for("/social/apple", method: "POST")
    missing_source_env["rack.session"] = {}
    status, = SocialCallbackGuard.verify_request_phase!(missing_source_env)

    assert_equal 403, status

    mismatch_env = Rack::MockRequest.env_for(
      "/social/apple",
      :method => "POST",
      "HTTP_ORIGIN" => "https://evil.example.test",
    )
    mismatch_env["rack.session"] = {}
    status, = SocialCallbackGuard.verify_request_phase!(mismatch_env)

    assert_equal 403, status
  ensure
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "request phase captures and generates state" do
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, ["id.example.test"])
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, ["https://id.example.test"])

    env = Rack::MockRequest.env_for(
      "/social/apple?state=known-state",
      :method => "POST",
      "HTTP_ORIGIN" => "https://id.example.test",
    )
    env["rack.session"] = {}

    assert_nil SocialCallbackGuard.verify_request_phase!(env)
    assert_equal "known-state", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]
    assert_not env["rack.session"].key?(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)

    issued_count = ClientOauthCallbackState.count
    SocialCallbackGuard.capture_request_state!(env)

    assert_equal "apple", env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    assert_equal issued_count, ClientOauthCallbackState.count
    assert_not env["rack.session"].key?(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)

    generated_env = Rack::MockRequest.env_for(
      "/social/apple",
      :method => "POST",
      "HTTP_ORIGIN" => "https://id.example.test",
    )
    generated_env["rack.session"] = {}

    assert_nil SocialCallbackGuard.verify_request_phase!(generated_env)
    assert_match(/state=/, generated_env["QUERY_STRING"])
    assert_predicate generated_env["rack.session"][SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY], :present?
    assert_not generated_env["rack.session"].key?(SocialCallbackGuard::SOCIAL_STATE_USED_AT_SESSION_KEY)
  ensure
    SocialCallbackGuard.instance_variable_set(:@allowed_hosts, nil)
    SocialCallbackGuard.instance_variable_set(:@allowed_request_origins, nil)
  end

  test "apple request phase logs safe nonce context" do
    env = Rack::MockRequest.env_for(
      "/social/apple?state=known-state",
      :method => "GET",
      "HTTP_ORIGIN" => "https://id.example.test",
    )
    env["rack.session"] = { "omniauth.nonce" => "strategy-nonce" }

    logged =
      capture_json_logs do
        SocialCallbackGuard.capture_request_state!(env)
      end

    event = logged.find { |entry| entry[:event] == "social_auth.apple.request_phase_nonce_context" }

    assert_not_nil event
    assert_equal "/social/apple", event.dig(:data, :request_path)
    assert_equal "GET", event.dig(:data, :request_method)
    assert event.dig(:data, :strategy_has_value)
    assert event.dig(:data, :callback_present)
    assert_not_includes logged.to_s, "strategy-nonce"
  end

  test "normalizes malformed origins and referer sources" do
    assert_nil SocialCallbackGuard.normalize_origin("http://[")

    origin_env = Rack::MockRequest.env_for("/", "HTTP_ORIGIN" => "http://[")
    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(origin_env))

    assert_equal :origin_parse_error, source
    assert_nil normalized

    referer_env = Rack::MockRequest.env_for("/", "HTTP_REFERER" => "http://[")
    source, normalized = SocialCallbackGuard.normalized_request_source(Rack::Request.new(referer_env))

    assert_equal :referer_parse_error, source
    assert_nil normalized

    empty_env = Rack::MockRequest.env_for("/")

    assert_equal [:missing_source, nil], SocialCallbackGuard.normalized_request_source(Rack::Request.new(empty_env))
  end

  def capture_json_logs
    logged = []
    collector =
      lambda do |message = nil, &block|
        message = block.call if message.nil? && block
        logged << JSON.parse(message, symbolize_names: true) if message.to_s.start_with?("{")
      rescue JSON::ParserError
        nil
      end

    logger = Object.new
    logger.define_singleton_method(:info) do |message = nil, &block|
      collector.call(message, &block)
    end
    logger.define_singleton_method(:error) do |message = nil, &block|
      collector.call(message, &block)
    end

    Rails.stub(:logger, logger) do
      yield
    end

    logged
  end
end

class SocialCallbackGuardIncludedDoTest
  test "request and capture phases reject unmatched, bad, blank, and duplicate inputs" do
    unmatched = Rack::MockRequest.env_for("/other", method: "POST")
    unmatched["rack.session"] = {}

    assert_nil SocialCallbackGuard.verify_request_phase!(unmatched)
    assert_nil SocialCallbackGuard.capture_request_state!(unmatched)

    bad_method = Rack::MockRequest.env_for("/social/google", method: "GET")
    bad_method["rack.session"] = {}
    result = SocialCallbackGuard.verify_request_phase!(bad_method)

    assert_equal 403, result.first

    blank = Rack::MockRequest.env_for("/social/google", method: "POST")
    blank["rack.session"] = {}

    assert_nil SocialCallbackGuard.capture_request_state!(blank)

    duplicate = Rack::MockRequest.env_for("/social/google?state=state", method: "POST")
    duplicate["rack.session"] = {
      SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY => "state",
      SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY => "google",
    }

    assert_nil SocialCallbackGuard.capture_request_state!(duplicate)
    assert_equal "google", duplicate["rack.session"][SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
  end

  test "social source and method helpers cover unknown providers and ports" do
    assert_not SocialCallbackGuard.allowed_request_method?("unknown", "POST")
    assert_not SocialCallbackGuard.allowed_callback_method?("unknown", "GET")
    assert_equal "example.test:8443", SocialCallbackGuard.normalize_host_port("https://EXAMPLE.TEST:8443")
    assert_nil SocialCallbackGuard.normalize_host_port("http://[")
    assert_equal "https://example.test:8443", SocialCallbackGuard.normalize_origin("https://EXAMPLE.TEST:8443/path")
  end
end
