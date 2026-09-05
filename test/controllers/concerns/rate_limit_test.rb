# typed: false
# frozen_string_literal: true

require "prism"
require_relative "../../test_helper"

class RateLimitDummyController < ApplicationController
  include ::RateLimit

  rate_limit(
    to: 1,
    within: 1.minute,
    by: -> { request.remote_ip },
    with: -> { render_rate_limited(retry_after: 60) },
    store: rate_limit_store,
    name: "dummy_ip",
    only: :index,
  )

  def index
    render json: { ok: true }
  end
end

class RateLimitShortNameController < ApplicationController
  include ::RateLimit

  rate_limit(
    to: 1,
    within: 1.minute,
    by: -> { request.remote_ip },
    with: -> { render_rate_limited(retry_after: 60) },
    store: rate_limit_store,
    name: "short",
    only: :index,
  )
  rate_limit(
    to: 10,
    within: 1.minute,
    by: -> { request.remote_ip },
    with: -> { render_rate_limited(retry_after: 60) },
    store: rate_limit_store,
    name: "long",
    only: :index,
  )

  def index
    render json: { ok: true }
  end
end

class RateLimitSharedScopeOneController < ApplicationController
  include ::RateLimit

  rate_limit(
    to: 1,
    within: 1.minute,
    by: -> { request.remote_ip },
    scope: "shared_test_scope",
    name: "shared",
    with: -> { render_rate_limited(retry_after: 60) },
    store: rate_limit_store,
  )

  def index
    render json: { ok: true }
  end
end

class RateLimitSharedScopeTwoController < ApplicationController
  include ::RateLimit

  rate_limit(
    to: 1,
    within: 1.minute,
    by: -> { request.remote_ip },
    scope: "shared_test_scope",
    name: "shared",
    with: -> { render_rate_limited(retry_after: 60) },
    store: rate_limit_store,
  )

  def index
    render json: { ok: true }
  end
end

class RateLimitTest < ActionDispatch::IntegrationTest
  counts_rate_limits!
  self.fixture_table_names = []

  setup do
    clear_rate_limit_store
  end

  teardown do
    clear_rate_limit_store
  end

  test "rails rate limiter returns a 429 problem document with Retry-After and RateLimit" do
    with_routing do |set|
      set.draw { get "/test_rate_limit", to: "rate_limit_dummy#index" }

      get "/test_rate_limit", headers: { "Host" => "example.com", "Accept" => "application/json" }

      assert_response :success

      get "/test_rate_limit", headers: { "Host" => "example.com", "Accept" => "application/json" }

      assert_response :too_many_requests
      assert_equal "application/problem+json; charset=utf-8", response.content_type
      assert_equal "60", response.headers["Retry-After"]
      assert_equal %("default";r=0;t=60), response.headers["RateLimit"]

      body = response.parsed_body

      assert_equal "urn:umaxica:problem:rate-limited", body.fetch("type")
      assert_equal 429, body.fetch("status")
      assert_equal I18n.t("errors.rate_limit.exceeded"), body.fetch("detail")
      assert_predicate body.fetch("request_id"), :present?
    end
  end

  # The rule that fired must not reach the client: it tells a caller which quota to avoid and how to
  # reshape traffic around it. Operators read it from the notification asserted below instead.
  test "the response discloses neither the rule that fired nor the enforcing layer" do
    with_routing do |set|
      set.draw { get "/test_rate_limit", to: "rate_limit_dummy#index" }

      get "/test_rate_limit", headers: { "Host" => "example.com", "Accept" => "application/json" }
      get "/test_rate_limit", headers: { "Host" => "example.com", "Accept" => "application/json" }

      assert_response :too_many_requests
      assert_nil response.headers["X-RateLimit-Rule"]
      assert_nil response.headers["X-RateLimit-Layer"]
      assert_not_includes response.body, "dummy_ip"
      # RateLimit-Policy carries a quota and window that render_rate_limited does not receive.
      # Omitting it is deliberate; a fabricated policy would misstate the limit.
      assert_nil response.headers["RateLimit-Policy"]
    end
  end

  test "rails rate limiter returns html 429 with plain message" do
    with_routing do |set|
      set.draw { get "/test_rate_limit_html", to: "rate_limit_dummy#index" }

      get "/test_rate_limit_html", headers: { "Host" => "example.com", "Accept" => "text/html" }
      get "/test_rate_limit_html", headers: { "Host" => "example.com", "Accept" => "text/html" }

      assert_response :too_many_requests
      assert_equal "text/plain; charset=utf-8", response.content_type
      assert_equal I18n.t("errors.rate_limit.exceeded"), response.body
      assert_equal "60", response.headers["Retry-After"]
    end
  end

  test "rails limiter emits a notification event" do
    payloads = []
    callback = ->(_name, _start, _finish, _id, payload) { payloads << payload }

    ActiveSupport::Notifications.subscribed(callback, "rate_limit.action_controller") do
      with_routing do |set|
        set.draw { get "/test_rate_limit", to: "rate_limit_dummy#index" }

        get "/test_rate_limit", headers: { "Host" => "example.com" }
        get "/test_rate_limit", headers: { "Host" => "example.com" }
      end
    end

    assert_predicate payloads, :any?, "Expected rate_limit.action_controller to be emitted"
    assert_equal "dummy_ip", payloads.last[:name]
    assert_predicate payloads.last[:cache_key], :present?
  end

  test "distinct names in the same controller do not collide" do
    with_routing do |set|
      set.draw { get "/test_named", to: "rate_limit_short_name#index" }

      get "/test_named", headers: { "Host" => "example.com" }

      assert_response :success

      get "/test_named", headers: { "Host" => "example.com" }

      assert_response :too_many_requests
    end
  end

  test "shared scope is honored across controllers" do
    with_routing do |set|
      set.draw do
        get "/test_scope_one", to: "rate_limit_shared_scope_one#index"
        get "/test_scope_two", to: "rate_limit_shared_scope_two#index"
      end

      get "/test_scope_one", headers: { "Host" => "example.com" }

      assert_response :success

      get "/test_scope_two", headers: { "Host" => "example.com" }

      assert_response :too_many_requests
    end
  end

  test "legacy rate limit APIs are removed" do
    assert_not_respond_to RateLimit, :store
    assert_not RateLimit.const_defined?(:STORE_REGISTRY, false)
    assert_not RateLimit.const_defined?(:SKIP_DEFAULT_CLASSES, false)

    controller = RateLimitDummyController.new

    assert_not_respond_to RateLimitDummyController, :has_custom_rate_limit!
    assert_not_respond_to controller, :check_default_rate_limit, true
    assert_not_respond_to controller, :handle_rate_limit_exceeded!, true
  end

  test "production code does not use removed rate limit APIs" do
    patterns = [
      "RateLimit.store",
      "has_custom_rate_limit!",
      "skip_default_rate_limit?",
      "check_default_rate_limit",
      "handle_rate_limit_exceeded!",
      "STORE_REGISTRY",
    ]
    files = Rails.root.glob("{app,config}/**/*.rb").reject { |path| path.to_s.include?("/vendor/") }
    violations =
      files.flat_map do |path|
        content = path.read
        patterns.filter_map { |pattern|
          "#{path.relative_path_from(Rails.root)}: #{pattern}" if content.include?(pattern)
        }
      end

    assert_empty violations
  end

  test "production rate limit declarations explicitly declare a store" do
    offenders = production_rate_limit_store_offenders

    assert_empty offenders, "production rate_limit declarations missing explicit store:\n#{offenders.join("\n")}"
  end

  test "rate limit redis url has no localhost fallback" do
    config_content =
      Rails.root.glob("config/environments/*.rb").map(&:read).join("\n")

    assert_no_match(/RATE_LIMIT_REDIS_URL["']\s*,/, config_content)
  end

  private

  def clear_rate_limit_store
    Rails.configuration.x.rate_limit.fetch(:store).clear
  end

  def production_rate_limit_store_offenders
    Rails.root.glob("app/**/*.rb").flat_map do |path|
      rate_limit_call_sources(path).filter_map do |call|
        next if call.fetch(:source).match?(/\bstore\s*:/)

        "#{path.relative_path_from(Rails.root)}:#{call.fetch(:line)}"
      end
    end
  end

  def rate_limit_call_sources(path)
    parse_result = Prism.parse_file(path.to_s)

    assert_predicate parse_result, :success?, "failed to parse #{path.relative_path_from(Rails.root)}"

    calls = []

    walk_prism(parse_result.value) do |node|
      next unless node.is_a?(Prism::CallNode)
      next unless node.name == :rate_limit
      next unless node.receiver.nil?

      source = node.location.slice
      next unless source.match?(/\bto\s*:/)
      next unless source.match?(/\bwithin\s*:/)

      calls << { line: node.location.start_line, source: source }
    end

    calls
  end

  def walk_prism(node, &)
    return unless node

    yield node
    node.child_nodes.each { |child| walk_prism(child, &) if child }
  end
end
