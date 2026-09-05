# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

# Probe controller inheriting the lightest surface base so the surface-wide
# default_web rate limit (declared on the base) is exercised end-to-end.
class DefaultWebRateLimitProbeController < Base::Net::ApplicationController
  def index
    render plain: "ok"
  end
end

class DefaultWebRateLimitTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  self.fixture_table_names = []

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  teardown { Rails.configuration.x.rate_limit.fetch(:store).clear }

  # The Host below must be one the application actually serves. FqdnAvailabilityGate runs ahead of
  # the rate limiter and refuses an unregistered hostname with 503, so a synthetic Host would never
  # reach the limit this test is about.

  test "surface base enforces the 300/min default web limit and renders the json 429" do
    with_routing do |set|
      set.draw { get "/default_web_probe", to: "default_web_rate_limit_probe#index" }

      300.times do
        get "/default_web_probe", headers: { "Host" => "base.net.localhost", "Accept" => "application/json" }

        assert_response :success
      end

      get "/default_web_probe", headers: { "Host" => "base.net.localhost", "Accept" => "application/json" }

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
      assert_nil response.headers["X-RateLimit-Rule"]
      assert_equal "application/problem+json", response.media_type

      body = response.parsed_body

      assert_equal "urn:umaxica:problem:rate-limited", body.fetch("type")
      assert_equal I18n.t("errors.rate_limit.exceeded"), body.fetch("detail")
      assert_not_includes response.body, "base_net_default_web"
    end
  end

  test "every ApplicationController that includes RateLimit declares a default_web limit" do
    bases =
      Rails.root.glob("app/controllers/**/application_controller.rb")
        .select { |path| path.read.match?(/include ::RateLimit\b/) }

    assert_operator bases.size, :>=, 11, "expected at least 11 RateLimit-including surface bases"

    missing =
      bases.reject do |path|
        path.read.match?(/rate_limit\(.*?scope:\s*"\w+_default_web".*?\)/m)
      end

    assert_empty missing.map { |path| path.relative_path_from(Rails.root).to_s },
                 "surface bases missing the default_web rate limit"
  end
end
