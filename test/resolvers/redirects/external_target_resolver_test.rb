# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectsExternalTargetResolverTest < ActiveSupport::TestCase
  test "resolves allowlisted external key" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = RedirectsExternalTargetResolver.call(:rp_app, path: "/signed-out", query: { ok: "1" })

      assert_predicate result, :ok?
      assert_equal "https://rp.example/signed-out?ok=1", result.value
    end
  end

  test "rejects unknown allowlist key" do
    assert_not RedirectsExternalTargetResolver.call(:evil, path: "/").ok?
  end

  test "rejects http downgrade except local development origins" do
    with_env("RP_APP_URL" => "http://evil.example") do
      result = RedirectsExternalTargetResolver.call(:rp_app, path: "/signed-out")

      assert_not result.ok?
      assert_equal "https_required", result.failure_reason
    end
  end

  test "path join cannot escape to another host" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = RedirectsExternalTargetResolver.call(:rp_app, path: "//evil.example")

      assert_not result.ok?
    end
  end

  test "query merge strips dangerous redirect parameters" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = RedirectsExternalTargetResolver.call(
        :rp_app,
        path: "/signed-out?pt=/safe",
        query: { "redirect_uri" => "https://evil.example", "nt" => "dashboard", "ok" => "1" },
      )

      assert_predicate result, :ok?
      assert_equal "https://rp.example/signed-out?ok=1", result.value
    end
  end

  test "the Jump gateway is not a generic external redirect target" do
    assert_not RedirectsExternalTargetResolver.call(:jump, path: "/").ok?
  end

  test "generic external redirect still strips rt query" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = RedirectsExternalTargetResolver.call(:rp_app, path: "/", query: { rt: "aaa.bbb.ccc", ok: "1" })

      assert_predicate result, :ok?
      assert_equal "https://rp.example/?ok=1", result.value
    end
  end

  test "raw user supplied external urls require exact normalized origin allowlist" do
    allowed = ["https://safe.example/callback"]

    accepted = RedirectsExternalTargetResolver.url(
      "https://safe.example/after?ok=1",
      allowed_urls: allowed,
      source: :user_input,
    )
    denied = RedirectsExternalTargetResolver.url(
      "https://safe.example.evil.test/after",
      allowed_urls: allowed,
      source: :user_input,
    )

    assert_predicate accepted, :ok?
    assert_equal "https://safe.example/after?ok=1", accepted.value
    assert_not denied.ok?
    assert_equal "origin_denied", denied.failure_reason
  end

  test "registry derived targets do not treat user input as an origin" do
    with_env("RP_APP_URL" => "https://rp.example") do
      result = RedirectsExternalTargetResolver.call(
        :rp_app,
        path: "/signed-out",
        query: { "url" => "https://evil.example", "ok" => "1" },
        source: :registry,
      )

      assert_predicate result, :ok?
      assert_equal "https://rp.example/signed-out?ok=1", result.value
    end
  end

  test "url helper rejects userinfo fragment and control characters" do
    rejected_userinfo = RedirectsExternalTargetResolver.url(
      "https://user:pass@safe.example/after",
      allowed_urls: ["https://safe.example"],
      source: :user_input,
    )
    rejected_fragment = RedirectsExternalTargetResolver.url(
      "https://safe.example/after#frag",
      allowed_urls: ["https://safe.example"],
      source: :user_input,
    )
    rejected_control = RedirectsExternalTargetResolver.url(
      "https://safe.example/after\n",
      allowed_urls: ["https://safe.example"],
      source: :user_input,
    )

    assert_not rejected_userinfo.ok?
    assert_equal "userinfo", rejected_userinfo.failure_reason
    assert_not rejected_fragment.ok?
    assert_equal "fragment", rejected_fragment.failure_reason
    assert_not rejected_control.ok?
    assert_equal "invalid_uri", rejected_control.failure_reason
  end

  test "url helper rejects blank hosts http urls and malformed values" do
    no_host = RedirectsExternalTargetResolver.url(
      "https:///path",
      allowed_urls: ["https://safe.example"],
      source: :user_input,
    )
    http_url = RedirectsExternalTargetResolver.url(
      "http://safe.example/after",
      allowed_urls: ["http://safe.example"],
      source: :user_input,
    )
    malformed = RedirectsExternalTargetResolver.url(
      "://",
      allowed_urls: ["https://safe.example"],
      source: :user_input,
    )

    assert_equal "invalid_uri", no_host.failure_reason
    assert_equal "https_required", http_url.failure_reason
    assert_equal "invalid_uri", malformed.failure_reason
  end

  test "call rejects unknown keys non https origins and string keys" do
    assert_equal "unknown_key", RedirectsExternalTargetResolver.call("not a key").failure_reason
    assert_equal "unknown_key", RedirectsExternalTargetResolver.call(12).failure_reason

    with_env("RP_APP_URL" => "http://rp.example") do
      result = RedirectsExternalTargetResolver.call("rp_app", path: "/")

      assert_equal "https_required", result.failure_reason
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
