# typed: false
# frozen_string_literal: true

require "test_helper"

class UmaxicaValkeySettingsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "development maps cache rate-limit and auth-state onto the odd logical DBs" do
    settings = Umaxica::Valkey::Settings.load(
      rails_env: "development",
      environment: development_environment,
    )

    assert_equal 1, settings.cache.db
    assert_equal "valkey-cache", settings.cache.host
    assert_equal "redis://valkey-cache:6379/1", settings.cache.url
    assert_equal 3, settings.rate_limit.db
    assert_equal "valkey-kvs", settings.rate_limit.host
    assert_equal "redis://valkey-kvs:6379/3", settings.rate_limit.url
    assert_equal 5, settings.auth_state.db
    assert_equal "redis://valkey-kvs:6379/5", settings.auth_state.url
    assert_not_predicate settings.cache, :memory?
  end

  test "test uses MemoryStore for cache and even KVS databases for rate-limit and auth-state" do
    settings = Umaxica::Valkey::Settings.load(
      rails_env: "test",
      environment: test_environment,
    )

    assert_predicate settings.cache, :memory?
    assert_equal 2, settings.cache.db
    assert_nil settings.cache.url
    assert_equal 4, settings.rate_limit.db
    assert_equal "redis://valkey-kvs:6379/4", settings.rate_limit.url
    assert_equal 6, settings.auth_state.db
    assert_equal "redis://valkey-kvs:6379/6", settings.auth_state.url
  end

  test "production reads explicit URLs and does not apply the nonprod DB map" do
    settings = Umaxica::Valkey::Settings.load(
      rails_env: "production",
      environment: {
        "CACHE_REDIS_URL" => "rediss://cache.example.invalid:6380/0",
        "RATE_LIMIT_REDIS_URL" => "rediss://kvs.example.invalid:6380/9",
        "AUTH_STATE_REDIS_URL" => "rediss://kvs.example.invalid:6380/11",
        "VALKEY_CACHE_HOST" => "valkey-cache",
        "VALKEY_KVS_HOST" => "valkey-kvs",
      },
    )

    assert_equal "rediss://cache.example.invalid:6380/0", settings.cache.url
    assert_equal 0, settings.cache.db
    assert_equal 9, settings.rate_limit.db
    assert_equal 11, settings.auth_state.db
    assert_not_equal 1, settings.cache.db
    assert_not_equal 3, settings.rate_limit.db
    assert_not_equal 5, settings.auth_state.db
  end

  test "production fails fast when a responsibility URL is missing" do
    error =
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::Settings.load(
          rails_env: "production",
          environment: {
            "CACHE_REDIS_URL" => "rediss://cache.example.invalid:6380/0",
            "RATE_LIMIT_REDIS_URL" => "rediss://kvs.example.invalid:6380/0",
          },
        )
      end
    assert_match(/AUTH_STATE_REDIS_URL is required/, error.message)
  end

  test "development fails fast when a KVS host is missing" do
    error =
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::Settings.load(
          rails_env: "development",
          environment: development_environment.except("VALKEY_KVS_HOST"),
        )
      end
    assert_match(/VALKEY_KVS_HOST is required/, error.message)
  end

  test "test boot does not require a cache Valkey host" do
    settings = Umaxica::Valkey::Settings.load(
      rails_env: "test",
      environment: test_environment.except("VALKEY_CACHE_HOST", "VALKEY_CACHE_PORT"),
    )

    assert_predicate settings.cache, :memory?
    assert_equal 4, settings.rate_limit.db
  end

  test "booted test environment uses MemoryStore for Rails.cache and KVS DB 6 for auth-state" do
    assert_kind_of ActiveSupport::Cache::MemoryStore, Rails.cache
    assert_not_kind_of ActiveSupport::Cache::NullStore, Rails.cache
    assert_equal 6, Umaxica::Valkey::Settings.current.auth_state.db
    assert_equal 4, Umaxica::Valkey::Settings.current.rate_limit.db
  end

  test "parallel worker namespaces do not collide and cleanup stays inside the worker prefix" do
    url = Umaxica::Valkey::Settings.current.auth_state.url
    left = Umaxica::Valkey::Connection.new(
      url: url,
      namespace: Umaxica::Valkey::Namespaces.authorization_codes(
        suite_run_id: "settings-run",
        worker_id: "1",
      ),
    )
    right = Umaxica::Valkey::Connection.new(
      url: url,
      namespace: Umaxica::Valkey::Namespaces.authorization_codes(
        suite_run_id: "settings-run",
        worker_id: "2",
      ),
    )
    left.call("SET", left.key("probe"), "left", "EX", 30)
    right.call("SET", right.key("probe"), "right", "EX", 30)

    assert_equal "left", left.call("GET", left.key("probe"))
    assert_equal "right", right.call("GET", right.key("probe"))
    assert_not_equal left.key("probe"), right.key("probe")

    Umaxica::Valkey::Cleanup.delete_by_prefix(left, prefix: "#{left.namespace}:")

    assert_nil left.call("GET", left.key("probe"))
    assert_equal "right", right.call("GET", right.key("probe"))
  ensure
    Umaxica::Valkey::Cleanup.delete_by_prefix(left, prefix: "#{left.namespace}:") if left
    Umaxica::Valkey::Cleanup.delete_by_prefix(right, prefix: "#{right.namespace}:") if right
    left&.close
    right&.close
  end

  private

  def development_environment
    {
      "VALKEY_CACHE_HOST" => "valkey-cache",
      "VALKEY_CACHE_PORT" => "6379",
      "VALKEY_KVS_HOST" => "valkey-kvs",
      "VALKEY_KVS_PORT" => "6379",
      "VALKEY_DIAGNOSTIC_HOST" => "valkey",
      "VALKEY_DIAGNOSTIC_PORT" => "6379",
    }
  end

  def test_environment
    {
      "VALKEY_KVS_HOST" => "valkey-kvs",
      "VALKEY_KVS_PORT" => "6379",
    }
  end
end
