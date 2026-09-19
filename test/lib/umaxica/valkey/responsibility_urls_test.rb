# typed: false
# frozen_string_literal: true

require "test_helper"

class UmaxicaValkeyResponsibilityUrlsTest < ActiveSupport::TestCase
  test "parses responsibility URLs and expected nonprod DB indexes" do
    parsed = Umaxica::Valkey::ResponsibilityUrls.parse(
      "redis://127.0.0.1:6379/2",
      responsibility: :auth_state,
    )

    assert_equal :auth_state, parsed.responsibility
    assert_equal 2, parsed.db
    assert_equal "127.0.0.1", parsed.host
    assert_equal 6379, parsed.port
    assert_predicate parsed, :redis_scheme?

    assert_equal 0, Umaxica::Valkey::ResponsibilityUrls.expected_db(:cache, env: "development")
    assert_equal 1, Umaxica::Valkey::ResponsibilityUrls.expected_db(:rate_limit, env: "development")
    assert_equal 2, Umaxica::Valkey::ResponsibilityUrls.expected_db(:auth_state, env: "development")
    assert_equal 3, Umaxica::Valkey::ResponsibilityUrls.expected_db(:cache, env: "test")
    assert_equal 4, Umaxica::Valkey::ResponsibilityUrls.expected_db(:rate_limit, env: "test")
    assert_equal 5, Umaxica::Valkey::ResponsibilityUrls.expected_db(:auth_state, env: "test")
  end

  test "rejects blank host and wrong nonprod DB" do
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.parse("redis:///0", responsibility: :cache)
    end

    parsed = Umaxica::Valkey::ResponsibilityUrls.parse(
      "redis://127.0.0.1:6379/0",
      responsibility: :auth_state,
    )
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.assert_nonprod_db!(parsed, env: "development")
    end
  end
end
