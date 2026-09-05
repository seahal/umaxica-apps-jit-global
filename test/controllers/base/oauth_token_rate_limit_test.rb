# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BaseOauthTokenRateLimitTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  TokenResult =
    Struct.new(:success, :error, :error_description, keyword_init: true) do
      def success?
        success
      end
    end

  setup do
    clear_rate_limit_store

    # `counts_rate_limits!` must actually be in force: with the suite default
    # NullStore behind the wrapper, every assertion below would pass vacuously
    # because no request would ever be counted.
    assert_instance_of ActiveSupport::Cache::MemoryStore, rate_limit_store.__getobj__
  end

  teardown do
    clear_rate_limit_store
  end

  test "base app oauth token endpoint rate limits repeated requests" do
    assert_token_endpoint_rate_limit(
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
      url_helper: ->(host:) { base_app_oauth_token_url(host: host) },
    )
  end

  test "base com oauth token endpoint rate limits repeated requests" do
    assert_token_endpoint_rate_limit(
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      url_helper: ->(host:) { base_com_oauth_token_url(host: host) },
    )
  end

  test "base org oauth token endpoint rate limits repeated requests" do
    assert_token_endpoint_rate_limit(
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      url_helper: ->(host:) { base_org_oauth_token_url(host: host) },
    )
  end

  private

  def assert_token_endpoint_rate_limit(host:, url_helper:)
    remote_ip = "198.51.100.42"
    result = TokenResult.new(
      success: false,
      error: "invalid_grant",
      error_description: "invalid_code",
    )

    OidcTokenExchangeCoordinator.stub(:call, ->(**) { result }) do
      10.times do
        post(
          url_helper.call(host: host),
          params: invalid_token_params,
          as: :json,
          headers: { "REMOTE_ADDR" => remote_ip },
        )

        assert_not_equal 429, response.status
      end

      post(
        url_helper.call(host: host),
        params: invalid_token_params,
        as: :json,
        headers: { "REMOTE_ADDR" => remote_ip },
      )

      # 429 is not an OAuth-defined error response: RFC 6749 5.2 covers 400 and 401 only. The
      # protocol exemption therefore does not extend here, and the rejection uses Problem Details
      # like any other rate-limited endpoint. See adr/api-error-format-problem-details.md.
      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
      assert_nil response.headers["X-RateLimit-Rule"]
      assert_equal "application/problem+json", response.media_type
      assert_equal "urn:umaxica:problem:rate-limited", response.parsed_body.fetch("type")
      assert_equal I18n.t("errors.rate_limit.exceeded"), response.parsed_body.fetch("detail")
    end
  end

  def invalid_token_params
    {
      grant_type: "authorization_code",
      code: "invalid-code",
      redirect_uri: "https://client.example/callback",
      client_id: "invalid-client",
      client_secret: "invalid-secret",
      code_verifier: "invalid-verifier",
    }
  end

  def rate_limit_store
    Rails.configuration.x.rate_limit.fetch(:store)
  end

  def clear_rate_limit_store
    rate_limit_store.clear
  end
end
