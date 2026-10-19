# typed: false
# frozen_string_literal: true

require "uri"
require "json"
require "pg"
require "active_record/database_configurations"

module Umaxica
  module TestEnvironment
    class ConfigurationError < StandardError; end

    # Validates Rails' effective test database configurations before Active Record opens a
    # connection. This is intentionally configuration-only: identity and catalog checks belong to
    # scripts/test-environment-check, which runs before Rails boots.
    module DatabaseSafety
      DATABASE_URL_NAMES = /(?:\A|_)DATABASE_URL\z/.freeze
      # The fixed Dev Container test target, written literally in config/database.yml as well.
      # It is never read from the environment: an exported variable must not be able to redirect
      # a destructive test preparation (user decision 2026-10-19). `db` is compose.yaml's
      # POSTGRES_DB, the administration database that is never itself a test target.
      TEST_HOST = "primary"
      TEST_PORT = 5432
      TEST_USER = "root"
      TEST_PASSWORD = "development"
      ADMIN_DATABASE = "db"

      module_function

      def verify!(configurations: nil, environment: ENV, rails_environment: Rails.env)
        return true unless rails_environment.to_s == "test"

        isolated_run_id = environment["POSTGRESQL_ISOLATED_TEST_RUN_ID"].to_s
        reject_unhandled_database_url_overrides!(environment)

        effective_configurations = configurations || effective_test_configurations
        raise ConfigurationError, "test database configurations are empty" if effective_configurations.empty?

        effective_configurations.each do |configuration|
          validate_configuration!(configuration, isolated_run_id:)
        end
        verify_isolated_catalog!(effective_configurations, environment:, run_id: isolated_run_id) unless
          isolated_run_id.empty?
        true
      end

      def report(configurations: nil, environment: ENV, rails_environment: Rails.env)
        verify!(configurations:, environment:, rails_environment:)
        effective_configurations = configurations || effective_test_configurations
        effective_configurations.map do |configuration|
          {
            name: configuration.name,
            database: configuration.database,
            host: configuration.configuration_hash[:host],
            port: configuration.configuration_hash[:port],
          }
        end
      end

      # A worker verifies its own creation receipts after the framework retargets
      # its configurations, while also retaining the verified parent-fleet boundary.
      def verify_worker_catalog!(configurations:, worker:, workers:, manifest_path:, environment: ENV)
        unless configurations.any? && configurations.all? { |configuration| configuration.env_name == "test" }
          raise ConfigurationError, "isolated worker configurations must belong to test"
        end

        unless worker.is_a?(Integer) && workers.is_a?(Integer) && worker >= 0 && worker < workers &&
            workers == Integer(required(environment, "PARALLEL_WORKERS"), 10)
          raise ConfigurationError, "isolated worker identity is invalid"
        end

        parent_configurations =
          configurations.map do |configuration|
            suffix = "_#{worker}"
            unless configuration.database.end_with?(suffix)
              raise ConfigurationError, "worker database suffix does not match worker identity"
            end

            configuration.dup.tap { |copy| copy._database = configuration.database.delete_suffix(suffix) }
          end
        verify!(configurations: parent_configurations, environment:)
        worker_environment = environment.to_h.merge("POSTGRESQL_ISOLATED_TEST_MANIFEST" => manifest_path)
        verify_isolated_catalog!(
          configurations, environment: worker_environment,
                          run_id: required(environment, "POSTGRESQL_ISOLATED_TEST_RUN_ID"),
        )
        true
      end

      # Verify the database catalog before a test preparation task mutates any schema. The
      # configuration check above proves that Rails will address test-prefixed names on the
      # expected host; this check proves those names exist on the same PostgreSQL server and that
      # the administration connection is not one of the databases that the task is preparing.
      # `catalog_databases` is injectable so contract tests can exercise the decision without
      # opening a database connection.
      def verify_catalog!(configurations: nil, environment: ENV, rails_environment: Rails.env,
                          catalog_databases: nil)
        verify!(configurations:, environment:, rails_environment:)
        effective_configurations = configurations || effective_test_configurations
        expected_databases = effective_configurations.map { |configuration| configuration.database.to_s }
        expected_databases.uniq!
        expected_databases.sort!
        # verify! has already required every target to be a test_ or codex_integrity_ database, so
        # none of them can be the fixed administration database.
        admin_database = ADMIN_DATABASE
        catalog = catalog_databases || query_catalog!(admin_database:, database_names: expected_databases)
        raw_databases = catalog.is_a?(Hash) ? catalog.fetch(:databases) : catalog
        available_databases = Array(raw_databases).map(&:to_s)
        available_databases.uniq!
        available_databases.sort!
        missing = expected_databases - available_databases
        unless missing.empty?
          raise ConfigurationError,
                "PostgreSQL test database manifest is missing: #{missing.join(", ")}"
        end

        writable_configurations =
          effective_configurations.reject { |configuration| configuration.configuration_hash[:replica] }
        writable_test_databases = writable_configurations.map { |configuration| configuration.database.to_s }
        writable_test_databases.uniq!
        writable_test_databases.sort!

        {
          admin_database: admin_database,
          test_databases: expected_databases,
          writable_test_databases:,
          catalog_databases: available_databases,
          server_address: catalog.is_a?(Hash) ? catalog[:server_address] : nil,
          server_port: catalog.is_a?(Hash) ? catalog[:server_port] : nil,
          server_version: catalog.is_a?(Hash) ? catalog[:server_version] : nil,
        }
      end

      def prepare_database_names!(manifest:, environment: ENV)
        raw_names = required(environment, "POSTGRESQL_TEST_PREPARE_DATABASES")
        names = raw_names.split(",").map(&:strip)
        names.reject!(&:empty?)
        names.uniq!
        names.sort!
        raise ConfigurationError, "POSTGRESQL_TEST_PREPARE_DATABASES is empty" if names.empty?

        verified_databases = manifest.fetch(:test_databases)
        writable_databases = manifest.fetch(:writable_test_databases)
        unknown = names - verified_databases
        unless unknown.empty?
          raise ConfigurationError,
                "POSTGRESQL_TEST_PREPARE_DATABASES contains unverified databases: #{unknown.join(", ")}"
        end

        missing = writable_databases - names
        unless missing.empty?
          raise ConfigurationError,
                "POSTGRESQL_TEST_PREPARE_DATABASES does not cover every verified test database; " \
                "missing: #{missing.join(", ")}"
        end
        names
      end

      def validate_configuration!(configuration, isolated_run_id:)
        values = configuration.configuration_hash
        name = configuration.name.to_s
        database = configuration.database.to_s
        host = values[:host].to_s
        # A missing port would make libpq use its default, so it must not inherit the expected one.
        raise ConfigurationError, "test database #{name} has no port" if values[:port].blank?

        port = parse_port(values[:port])
        username = values[:username].to_s

        raise ConfigurationError, "test database #{name} has no host" if host.empty?
        unless host == TEST_HOST
          raise ConfigurationError, "test database #{name} host #{host.inspect} is not #{TEST_HOST.inspect}"
        end
        unless port == TEST_PORT
          raise ConfigurationError, "test database #{name} port #{port} is not #{TEST_PORT}"
        end

        expected_isolated = "codex_integrity_#{isolated_run_id}_#{name.delete_suffix("_replica")}"
        if isolated_run_id.empty? && !database.start_with?("test_")
          raise ConfigurationError, "test database #{name} uses non-test database #{database.inspect}"
        elsif !isolated_run_id.empty? && database != expected_isolated
          raise ConfigurationError, "isolated test database #{name} has an unexpected target"
        end
        unless username == TEST_USER
          raise ConfigurationError, "test database #{name} username is not #{TEST_USER.inspect}"
        end

        validate_url!(configuration, database:)
      end

      def validate_url!(configuration, database:)
        url = configuration.configuration_hash[:url].to_s
        return if url.empty?

        uri = URI.parse(url)

        unless uri.scheme.in?(%w(postgres postgresql))
          raise ConfigurationError, "test database #{configuration.name} URL must use PostgreSQL"
        end
        unless uri.host == TEST_HOST && (uri.port || 5432) == TEST_PORT
          raise ConfigurationError, "test database #{configuration.name} URL target is not the test target"
        end

        url_database = uri.path.to_s.delete_prefix("/")
        unless url_database.empty? || url_database == database
          raise ConfigurationError, "test database #{configuration.name} URL database does not match Rails config"
        end
      rescue URI::InvalidURIError => e
        raise ConfigurationError, "test database #{configuration.name} URL is invalid", cause: e
      end

      def reject_unhandled_database_url_overrides!(environment)
        overrides = environment.keys.grep(DATABASE_URL_NAMES).select { |name| environment[name].to_s != "" }
        unsupported = overrides - ["DATABASE_URL"]
        return if unsupported.empty?

        raise ConfigurationError,
              "unsupported test database URL overrides: #{unsupported.sort.join(", ")}"
      end

      def query_catalog!(admin_database:, database_names:)
        connection = PG.connect(
          host: TEST_HOST, port: TEST_PORT, user: TEST_USER, password: TEST_PASSWORD, dbname: admin_database,
        )
        connection.exec("BEGIN READ ONLY")
        connection.exec("SET LOCAL statement_timeout = '5s'")
        connection.exec("SET LOCAL lock_timeout = '1s'")
        identity = connection.exec(<<~SQL.squish).first
          select current_database() as database,
                 coalesce(inet_server_addr()::text, 'local') as server_address,
                 inet_server_port() as server_port,
                 current_setting('server_version') as server_version
        SQL
        databases =
          connection.exec("select datname from pg_database").filter_map do |row|
            name = row.fetch("datname")
            name if database_names.include?(name)
          end
        connection.exec("ROLLBACK")

        {
          databases: databases,
          server_address: identity.fetch("server_address"),
          server_port: identity.fetch("server_port"),
          server_version: identity.fetch("server_version"),
        }
      rescue PG::Error => e
        raise ConfigurationError, "cannot inspect PostgreSQL test catalog: #{e.class}: #{e.message}", cause: e
      ensure
        connection&.close
      end

      def verify_isolated_catalog!(configurations, environment:, run_id:)
        unless run_id.match?(/\A[0-9]{8}[a-z0-9]{0,12}\z/)
          raise ConfigurationError, "isolated test run id is invalid"
        end
        unless Integer(required(environment, "PARALLEL_WORKERS"), 10).positive?
          raise ConfigurationError, "isolated test worker count must be positive"
        end

        manifest = load_isolated_manifest!(environment)
        names = configurations.map(&:database)
        names.uniq!
        names.sort!
        validate_isolated_manifest!(manifest, names:, run_id:)

        connection = PG.connect(
          host: TEST_HOST, port: TEST_PORT, user: TEST_USER, password: TEST_PASSWORD, dbname: ADMIN_DATABASE,
          connect_timeout: 3,
        )
        connection.exec("BEGIN READ ONLY")
        connection.exec("SET LOCAL statement_timeout = '5s'")
        connection.exec("SET LOCAL lock_timeout = '1s'")
        rows = connection.exec_params(<<~SQL.squish, ["{#{names.join(",")}}"])
          SELECT datname, oid::text AS oid, pg_get_userbyid(datdba) AS owner,
                 shobj_description(oid, 'pg_database') AS comment
            FROM pg_database WHERE datname = ANY($1::text[])
        SQL
        validate_isolated_database_rows!(rows, manifest:)
        connection.exec("ROLLBACK")
      rescue KeyError, JSON::ParserError, Errno::ENOENT, PG::Error => e
        raise ConfigurationError, "isolated test identity verification failed: #{e.class}", cause: e
      ensure
        connection&.close
      end

      def load_isolated_manifest!(environment)
        manifest_path = required(environment, "POSTGRESQL_ISOLATED_TEST_MANIFEST")
        root = Rails.root.join("tmp").realpath.to_s
        path = File.realpath(manifest_path)
        unless path.start_with?("#{root}/") && File.file?(path)
          raise ConfigurationError, "isolated test manifest must be under tmp/"
        end

        JSON.parse(File.read(path))
      end

      def validate_isolated_manifest!(manifest, names:, run_id:)
        listed_names = manifest.fetch("databases").map { |entry| entry.fetch("name") }
        listed_names.sort!
        return if manifest.fetch("run_id") == run_id && manifest.fetch("host") == TEST_HOST &&
          manifest.fetch("port") == TEST_PORT && manifest.fetch("user") == TEST_USER &&
          listed_names == names

        raise ConfigurationError, "isolated test manifest does not match effective configurations"
      end

      def validate_isolated_database_rows!(rows, manifest:)
        actual = rows.index_by { |row| row.fetch("datname") }
        expected_comment = "Disposable isolated Codex PostgreSQL integrity verification 2026-09-24"
        manifest.fetch("databases").each do |entry|
          name = entry.fetch("name")
          row = actual[name]
          valid = row && row.fetch("oid") == entry.fetch("oid").to_s &&
            row.fetch("owner") == TEST_USER && row.fetch("owner") == entry.fetch("owner") &&
            row.fetch("comment") == expected_comment && row.fetch("comment") == entry.fetch("comment")
          raise ConfigurationError, "isolated database identity mismatch: #{name}" unless valid
        end
      end

      # Built from the raw configuration (DATABASE_URL merged) without loading
      # ActiveRecord::Base, whose on_load hook establishes the connection pools.
      def effective_test_configurations
        ActiveRecord::DatabaseConfigurations.new(Rails.application.config.database_configuration).configs_for(
          env_name: "test",
          include_hidden: true,
        )
      end

      def required(environment, name)
        value = environment.fetch(name).to_s
        raise ConfigurationError, "#{name} is required" if value.empty?

        value
      rescue KeyError => e
        raise ConfigurationError, "#{name} is required", cause: e
      end

      def parse_port(value)
        port = value.is_a?(Integer) ? value : Integer(value.to_s, 10)
        raise ConfigurationError, "database port must be between 1 and 65535" unless port.between?(1, 65_535)

        port
      rescue ArgumentError, TypeError => e
        raise ConfigurationError, "database port must be an integer", cause: e
      end

      private_class_method :validate_configuration!, :validate_url!, :reject_unhandled_database_url_overrides!,
                           :query_catalog!, :verify_isolated_catalog!, :load_isolated_manifest!,
                           :validate_isolated_manifest!, :validate_isolated_database_rows!,
                           :effective_test_configurations
    end
  end
end
