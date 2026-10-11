# typed: false
# frozen_string_literal: true

require "test_helper"
require "set"

class TestEnvironmentIsolationContractTest < ActiveSupport::TestCase
  test "test boot uses an explicit PostgreSQL host and test-only Valkey databases" do
    database_config = Rails.root.join("config/database.yml").read

    assert_match(/test_host\s*=\s*Rails\.env\.test\?\s*\?\s*ENV\.fetch\("POSTGRESQL_TEST_HOST"\)/, database_config)
    assert_no_match(/ENV\.fetch\("POSTGRESQL_TEST_HOST",/, database_config)

    %i(cache rate_limit auth_state).each do |responsibility|
      parsed = Umaxica::Valkey::ResponsibilityUrls.parse(
        ENV.fetch("#{responsibility.to_s.upcase}_REDIS_URL"),
        responsibility: responsibility,
      )

      assert_equal(
        Umaxica::Valkey::ResponsibilityUrls.expected_db(responsibility, env: "test"),
        parsed.db,
      )
    end
  end

  test "application auth-state namespaces include the isolated run and worker" do
    scope = Umaxica::Valkey::Namespaces.runtime_scope

    assert_equal ENV.fetch("VALKEY_NAMESPACE_RUN_ID"), scope.fetch(:suite_run_id)
    assert_equal ENV.fetch("VALKEY_NAMESPACE_WORKER_ID"), scope.fetch(:worker_id)
    assert_includes(
      Umaxica::Valkey::Namespaces.authorization_codes(**scope),
      ":#{ENV.fetch("VALKEY_NAMESPACE_RUN_ID")}:#{ENV.fetch("VALKEY_NAMESPACE_WORKER_ID")}",
    )
  end

  test "a default authorization-code store writes inside the isolated scope" do
    run_id = ENV.fetch("VALKEY_NAMESPACE_RUN_ID")
    worker_id = ENV.fetch("VALKEY_NAMESPACE_WORKER_ID")
    namespace = Umaxica::Valkey::Namespaces.authorization_codes(
      suite_run_id: run_id,
      worker_id: worker_id,
    )
    connection = Umaxica::Valkey::Connection.new(
      url: ENV.fetch("AUTH_STATE_REDIS_URL"),
      namespace: "e0_contract_probe",
    )
    foreign_connection = Umaxica::Valkey::Connection.new(
      url: ENV.fetch("AUTH_STATE_REDIS_URL"),
      namespace: Umaxica::Valkey::Namespaces.authorization_codes(
        suite_run_id: run_id,
        worker_id: "foreign",
      ),
    )
    foreign_key = foreign_connection.key("sentinel")
    foreign_connection.call("SET", foreign_key, "1", "EX", 30)

    store = Valkey::AuthState::AuthorizationCodeStore.new
    before = scan_keys(connection, "#{namespace}:*")
    raw_code = store.issue!(
      client_id: "e0-contract",
      redirect_uri: "https://example.test/callback",
      subject: "e0-subject",
      code_challenge: "e0-challenge",
      code_challenge_method: "S256",
      resource_type: "client",
    )
    after = scan_keys(connection, "#{namespace}:*")
    created = after - before

    assert_equal 1, created.length
    assert_match(/\A#{Regexp.escape(namespace)}:/, created.first)
    assert_equal "e0-subject", store.read(raw_code).fetch("subject")
    assert_not_includes after, foreign_key
  ensure
    connection&.close
    foreign_connection&.close
  end

  test "test services are non-delivering by default" do
    assert_equal :test, Rails.application.config.action_mailer.delivery_method
    assert_equal "test", Rails.application.config.sms_provider
    assert_equal "TurnstileVerifierStub", Rails.application.config.x.turnstile.verifier
  end

  test "database safety rejects a non-test effective database without connecting" do
    config = Struct.new(:name, :database, :configuration_hash).new(
      "primary",
      "development_primary_db",
      { host: "test-db", port: 5432, username: "test-user" },
    )

    assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
      Umaxica::TestEnvironment::DatabaseSafety.verify!(
        configurations: [config],
        environment: {
          "POSTGRESQL_TEST_HOST" => "test-db",
          "POSTGRESQL_PORT" => "5432",
          "POSTGRESQL_USER" => "test-user",
        },
      )
    end
  end

  test "database safety rejects a test database without an explicit port" do
    config = Struct.new(:name, :database, :configuration_hash).new(
      "primary",
      "test_primary_db",
      { host: "test-db", username: "test-user" },
    )

    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.verify!(
          configurations: [config],
          environment: {
            "POSTGRESQL_TEST_HOST" => "test-db",
            "POSTGRESQL_PORT" => "5432",
            "POSTGRESQL_USER" => "test-user",
          },
        )
      end
    assert_match(/has no port/, error.message)
  end

  test "database manifest rejects an effective test database absent from the PostgreSQL catalog" do
    config = Struct.new(:name, :database, :configuration_hash).new(
      "primary",
      "test_primary_db",
      { host: "test-db", port: 5432, username: "test-user" },
    )

    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!(
          configurations: [config],
          environment: {
            "POSTGRESQL_TEST_HOST" => "test-db",
            "POSTGRESQL_PORT" => "5432",
            "POSTGRESQL_USER" => "test-user",
            "POSTGRESQL_DATABASE" => "db",
          },
          catalog_databases: [],
        )
      end

    assert_match(/missing: test_primary_db/, error.message)
  end

  test "database manifest rejects an administration database that is also prepared" do
    config = Struct.new(:name, :database, :configuration_hash).new(
      "primary",
      "test_primary_db",
      { host: "test-db", port: 5432, username: "test-user" },
    )

    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!(
          configurations: [config],
          environment: {
            "POSTGRESQL_TEST_HOST" => "test-db",
            "POSTGRESQL_PORT" => "5432",
            "POSTGRESQL_USER" => "test-user",
            "POSTGRESQL_DATABASE" => "test_primary_db",
          },
          catalog_databases: ["test_primary_db"],
        )
      end

    assert_match(/also an effective test database/, error.message)
  end

  test "database preparation requires an explicit verified migration scope" do
    manifest = { test_databases: ["test_primary_db", "test_app_db"] }

    assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
      Umaxica::TestEnvironment::DatabaseSafety.prepare_database_names!(
        manifest:,
        environment: {},
      )
    end

    assert_equal ["test_primary_db"],
                 Umaxica::TestEnvironment::DatabaseSafety.prepare_database_names!(
                   manifest:,
                   environment: { "POSTGRESQL_TEST_PREPARE_DATABASES" => "test_primary_db" },
                 )

    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        Umaxica::TestEnvironment::DatabaseSafety.prepare_database_names!(
          manifest:,
          environment: { "POSTGRESQL_TEST_PREPARE_DATABASES" => "test_missing_db" },
        )
      end
    assert_match(/unverified databases/, error.message)
  end

  test "CI prepares only through the isolated test database task" do
    ci = Rails.root.join("config/ci.rb").read

    assert_includes ci, "POSTGRESQL_TEST_PREPARE_DATABASES="
    assert_includes ci, "test_primary_db,test_app_ticket_db,test_com_ticket_db,test_org_ticket_db "
    assert_includes ci, "scripts/test-isolated env RAILS_ENV=test bin/rails db:test:prepare"
    assert_no_match(/bin\/rails db:prepare/, ci)
  end

  test "database safety runs before Active Record initializes the database" do
    names = Rails.application.initializers.tsort.map(&:name)

    assert_operator names.index("umaxica.test_database_safety"), :<,
                    names.index("active_record.initialize_database")
  end

  test "database safety reports the effective test target without secrets" do
    config = Struct.new(:name, :database, :configuration_hash).new(
      "primary",
      "test_primary_db",
      { host: "test-db", port: 5432, username: "test-user" },
    )

    report = Umaxica::TestEnvironment::DatabaseSafety.report(
      configurations: [config],
      environment: {
        "POSTGRESQL_TEST_HOST" => "test-db",
        "POSTGRESQL_PORT" => "5432",
        "POSTGRESQL_USER" => "test-user",
      },
    )

    assert_equal [{ name: "primary", database: "test_primary_db", host: "test-db", port: 5432 }], report
    assert report.none? { |entry| entry.values.any? { |value| value.to_s.include?("password") } }
  end

  test "database catalog inspection records the server identity and closes its connection" do
    config = Struct.new(:name, :database, :configuration_hash).new(
      "primary",
      "test_primary_db",
      { host: "test-db", port: 5432, username: "test-user" },
    )
    connection = Object.new
    closed = false
    connection.define_singleton_method(:exec) do |sql|
      if sql.include?("current_database")
        [{ "database" => "db", "server_address" => "10.0.0.5", "server_port" => "5432", "server_version" => "17" }]
      else
        [{ "datname" => "test_primary_db" }]
      end
    end
    connection.define_singleton_method(:close) { closed = true }

    manifest =
      PG.stub(:connect, ->(**) { connection }) do
        Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!(
          configurations: [config],
          environment: {
            "POSTGRESQL_TEST_HOST" => "test-db",
            "POSTGRESQL_PORT" => "5432",
            "POSTGRESQL_USER" => "test-user",
            "POSTGRESQL_PASSWORD" => "redacted",
            "POSTGRESQL_DATABASE" => "db",
          },
        )
      end

    assert_equal ["test_primary_db"], manifest.fetch(:test_databases)
    assert_equal "10.0.0.5", manifest.fetch(:server_address)
    assert_equal "17", manifest.fetch(:server_version)
    assert closed
  end

  test "database catalog inspection reports a PostgreSQL connection failure" do
    config = Struct.new(:name, :database, :configuration_hash).new(
      "primary",
      "test_primary_db",
      { host: "test-db", port: 5432, username: "test-user" },
    )
    error =
      assert_raises(Umaxica::TestEnvironment::ConfigurationError) do
        PG.stub(:connect, ->(**) { raise PG::Error, "catalog unavailable" }) do
          Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!(
            configurations: [config],
            environment: {
              "POSTGRESQL_TEST_HOST" => "test-db",
              "POSTGRESQL_PORT" => "5432",
              "POSTGRESQL_USER" => "test-user",
              "POSTGRESQL_PASSWORD" => "redacted",
              "POSTGRESQL_DATABASE" => "db",
            },
          )
        end
      end

    assert_match(/cannot inspect PostgreSQL test catalog/, error.message)
  end

  test "Valkey test target rejects a wrong logical database before cleanup" do
    environment = ENV.to_h.merge(
      "AUTH_STATE_REDIS_URL" => ENV.fetch("AUTH_STATE_REDIS_URL").sub(%r{/5\z}, "/2"),
    )

    assert_raises(Umaxica::Valkey::ConfigurationError) do
      Umaxica::Valkey::TestTarget.parse!(environment:)
    end
  end

  private

  def scan_keys(connection, pattern)
    cursor = "0"
    keys = Set.new
    loop do
      cursor, batch = connection.call("SCAN", cursor, "MATCH", pattern)
      keys = keys | Array(batch)
      break if cursor.to_s == "0"
    end
    keys
  end
end
