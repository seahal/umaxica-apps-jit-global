# typed: false
# frozen_string_literal: true

require "test_helper"

class TestEnvironmentEdgeContractTest < ActiveSupport::TestCase
  Config = Struct.new(:name, :database, :configuration_hash, keyword_init: true)

  test "database safety skips test-only checks outside the test environment" do
    assert Umaxica::TestEnvironment::DatabaseSafety.verify!(
      environment: {},
      rails_environment: "development",
    )
  end

  test "database safety rejects an empty effective configuration" do
    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.verify!(
          configurations: [],
          environment: database_environment,
        )
      end

    assert_match(/configurations are empty/, error.message)
  end

  test "database catalog rejects a production administration database" do
    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!(
          configurations: [database_config],
          environment: database_environment.merge("POSTGRESQL_DATABASE" => "production"),
          catalog_databases: ["test_primary_db"],
        )
      end

    assert_match(/must not be a development or production database/, error.message)
  end

  test "database catalog accepts an array and reports absent server identity" do
    manifest = Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!(
      configurations: [database_config],
      environment: database_environment.merge("POSTGRESQL_DATABASE" => "db"),
      catalog_databases: ["test_primary_db", "test_primary_db"],
    )

    assert_equal ["test_primary_db"], manifest.fetch(:catalog_databases)
    assert_nil manifest.fetch(:server_address)
    assert_nil manifest.fetch(:server_port)
    assert_nil manifest.fetch(:server_version)
  end

  test "database preparation rejects a blank list after trimming" do
    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.prepare_database_names!(
          manifest: { test_databases: ["test_primary_db"] },
          environment: { "POSTGRESQL_TEST_PREPARE_DATABASES" => " , " },
        )
      end

    assert_match(/POSTGRESQL_TEST_PREPARE_DATABASES is empty/, error.message)
  end

  test "database safety rejects each unsafe effective configuration target" do
    cases = {
      "blank host" => database_config(values: { port: 5432, username: "test-user" }),
      "wrong host" => database_config(values: { host: "other-db", port: 5432, username: "test-user" }),
      "wrong port" => database_config(values: { host: "test-db", port: 5433, username: "test-user" }),
      "non-test database" => database_config(database: "development_primary_db"),
      "wrong user" => database_config(values: { host: "test-db", port: 5432, username: "other-user" }),
    }

    cases.each do |label, config|
      error =
        assert_raises(Umaxica::TestEnvironment::ConfigurationError, label) do
          Umaxica::TestEnvironment::DatabaseSafety.verify!(
            configurations: [config],
            environment: database_environment,
          )
        end
      assert_predicate error.message, :present?
    end
  end

  test "database safety validates explicit URL scheme target and database" do
    {
      "wrong scheme" => "redis://test-db:5432/test_primary_db",
      "wrong target" => "postgres://other-db:5432/test_primary_db",
      "wrong database" => "postgres://test-db:5432/test_other_db",
      "invalid URL" => "postgres://[invalid",
    }.each do |label, url|
      error =
        assert_raises(Umaxica::TestEnvironment::ConfigurationError, label) do
          Umaxica::TestEnvironment::DatabaseSafety.verify!(
            configurations: [database_config(values: database_config_values.merge(url:))],
            environment: database_environment,
          )
        end
      assert_predicate error.message, :present?
    end
  end

  test "database safety rejects unsupported database URL overrides" do
    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.verify!(
          configurations: [database_config],
          environment: database_environment.merge("PRIMARY_DATABASE_URL" => "postgres://other-db/test"),
        )
      end

    assert_match(/unsupported test database URL overrides/, error.message)
  end

  test "database safety rejects invalid and missing required values" do
    assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
      Umaxica::TestEnvironment::DatabaseSafety.verify!(
        configurations: [database_config],
        environment: database_environment.merge("POSTGRESQL_TEST_HOST" => ""),
      )
    end

    ["0", "65536", "not-a-port"].each do |port|
      error =
        assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
          Umaxica::TestEnvironment::DatabaseSafety.verify!(
            configurations: [database_config],
            environment: database_environment.merge("POSTGRESQL_PORT" => port),
          )
        end
      assert_match(/POSTGRESQL_PORT/, error.message)
    end
  end

  test "Valkey settings reject missing and malformed KVS endpoints" do
    base = valkey_environment

    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::Settings.load(rails_env: "test", environment: base.except("VALKEY_KVS_HOST"))
    end

    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::Settings.load(
        rails_env: "test",
        environment: base.merge("VALKEY_KVS_PORT" => "not-a-port"),
      )
    end
  end

  test "Valkey namespace scope is empty without a run and rejects unsafe run ids" do
    original_run_id = ENV.delete("VALKEY_NAMESPACE_RUN_ID")
    original_worker_id = ENV.delete("VALKEY_NAMESPACE_WORKER_ID")
    begin
      assert_empty Umaxica::Valkey::Namespaces.runtime_scope

      ENV["VALKEY_NAMESPACE_RUN_ID"] = "run with spaces"
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::Namespaces.runtime_scope
      end

      ENV["VALKEY_NAMESPACE_RUN_ID"] = "safe-run"

      assert_equal({ suite_run_id: "safe-run" }, Umaxica::Valkey::Namespaces.runtime_scope)
    ensure
      if original_run_id
        ENV["VALKEY_NAMESPACE_RUN_ID"] = original_run_id
      else
        ENV.delete("VALKEY_NAMESPACE_RUN_ID")
      end
      if original_worker_id
        ENV["VALKEY_NAMESPACE_WORKER_ID"] = original_worker_id
      else
        ENV.delete("VALKEY_NAMESPACE_WORKER_ID")
      end
    end
  end

  test "Valkey URL parser rejects unknown, blank, unsupported, and malformed input" do
    [nil, ""].each do |url|
      assert_raises(Umaxica::Valkey::ConfigurationError) do
        Umaxica::Valkey::ResponsibilityUrls.parse(url, responsibility: :cache)
      end
    end

    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.parse("redis://valkey:6379/0", responsibility: :unknown)
    end
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.parse("http://valkey:6379/0", responsibility: :cache)
    end
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::ResponsibilityUrls.parse("redis://valkey:6379/not-a-db", responsibility: :cache)
    end
  end

  test "Valkey cleanup rejects unsafe prefixes and detects remaining keys" do
    connection = Object.new
    connection.define_singleton_method(:call) do |command, *_args|
      raise RuntimeError, "unexpected command #{command}" unless command == "SCAN"

      ["0", ["auth_state:test:remaining"]]
    end

    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "")
    end
    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::Cleanup.delete_by_prefix(connection, prefix: "auth_state:test")
    end
    assert_raises(Umaxica::Valkey::OperationError) do
      Umaxica::Valkey::Cleanup.ensure_empty!(connection, prefix: "auth_state:test:")
    end
  end

  private

  def database_environment
    {
      "POSTGRESQL_TEST_HOST" => "test-db",
      "POSTGRESQL_PORT" => "5432",
      "POSTGRESQL_USER" => "test-user",
      "POSTGRESQL_DATABASE" => "db",
    }
  end

  def database_config(database: "test_primary_db", values: database_config_values)
    Config.new(name: "primary", database:, configuration_hash: values)
  end

  def database_config_values
    { host: "test-db", port: 5432, username: "test-user" }
  end

  def valkey_environment
    {
      "VALKEY_KVS_HOST" => "valkey-kvs",
      "VALKEY_KVS_PORT" => "6379",
    }
  end
end
