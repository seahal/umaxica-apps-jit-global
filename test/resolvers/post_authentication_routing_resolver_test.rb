# frozen_string_literal: true

require "test_helper"

class PostAuthenticationRoutingResolverTest < ActiveSupport::TestCase
  test "routes a completed flow to the signed return target" do
    flow = Data.define(:return_to) do
      def sign_in_completed? = true
    end.new(return_to: "/settings/security")

    decision = PostAuthenticationRoutingResolver.call(flow: flow, default_path: "/dashboard")

    assert_equal :signed_return, decision.kind
    assert_equal "/settings/security", decision.target
  end

  test "routes a durable OIDC continuation before a signed return target" do
    flow = Data.define(:return_to) do
      def sign_in_completed? = true
    end.new(return_to: "/stale-tab")

    decision = PostAuthenticationRoutingResolver.call(
      flow: flow,
      default_path: "/dashboard",
      oidc_continuation: "/oauth/authorize/complete",
    )

    assert_equal :oidc_continuation, decision.kind
    assert_equal "/oauth/authorize/complete", decision.target
  end

  test "routes a durable RP continuation when no OIDC continuation exists" do
    flow = Data.define(:return_to) do
      def sign_in_completed? = true
    end.new(return_to: nil)

    decision = PostAuthenticationRoutingResolver.call(
      flow: flow,
      default_path: "/dashboard",
      rp_continuation: "/rp/complete",
    )

    assert_equal :rp_continuation, decision.kind
    assert_equal "/rp/complete", decision.target
  end

  test "routes missing or unsafe return facts to dashboard" do
    missing = Data.define(:return_to) do
      def sign_in_completed? = true
    end.new(return_to: nil)
    unsafe = Data.define(:return_to) do
      def sign_in_completed? = true
    end.new(return_to: "https://evil.example")

    missing_decision = PostAuthenticationRoutingResolver.call(flow: missing, default_path: "/dashboard")
    unsafe_decision = PostAuthenticationRoutingResolver.call(flow: unsafe, default_path: "/dashboard")

    assert_equal :dashboard, missing_decision.kind
    assert_equal :dashboard, unsafe_decision.kind
    assert_equal "/dashboard", unsafe_decision.target
  end

  test "does not route an incomplete flow or unsafe continuation" do
    incomplete = Data.define(:return_to) do
      def sign_in_completed? = false
    end.new(return_to: "/dashboard")

    assert_raises ArgumentError do
      PostAuthenticationRoutingResolver.call(flow: incomplete, default_path: "/dashboard")
    end

    completed = Data.define(:return_to) do
      def sign_in_completed? = true
    end.new(return_to: nil)

    assert_raises ArgumentError do
      PostAuthenticationRoutingResolver.call(
        flow: completed,
        default_path: "/dashboard",
        oidc_continuation: "https://evil.example",
      )
    end
  end
end
