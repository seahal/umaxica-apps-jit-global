# frozen_string_literal: true

# Local development provisioning for per-role secret isolation (R5-WU03A,
# docs/security/role-secret-isolation.md). Development only: it creates PostgreSQL login roles and
# per-role encrypted credentials bundles on this machine and never touches production, CI or any
# external service. Run it with the shared maintenance role:
#
#   UMAXICA_RUNTIME_ROLE=shared bin/rails runtime_roles:provision
#
# It is idempotent: existing bundles and keys are kept (their DATABASE_PASSWORD is reused), and the
# PostgreSQL role password and grants are re-applied to match RuntimeRole::ROLE_CONNECTIONS.
namespace :runtime_roles do
  desc "Create per-role credentials bundles and least-privilege PostgreSQL logins (development only)"
  task provision: :environment do
    raise ArgumentError, "runtime_roles:provision is development-only" unless Rails.env.development?
    raise ArgumentError, "run as the shared maintenance role" unless RuntimeRole.shared?

    require "securerandom"
    writers = ActiveRecord::Base.configurations.configs_for(env_name: "development").reject(&:replica?)
    databases = writers.to_h { |config| [config.name, config.database] }

    # Default PostgreSQL grants let every login CONNECT to every database. Remove that so a role
    # login reaches only the databases granted below.
    ActiveRecord::Base.connection_pool.with_connection do |admin|
      databases.each_value { |db|
        admin.execute("REVOKE CONNECT ON DATABASE #{admin.quote_table_name(db)} FROM PUBLIC")
      }
    end

    (RuntimeRole::ALL - [RuntimeRole::SHARED]).each do |role|
      paths = RuntimeRole.credentials_paths(env: "development", root: Rails.root, name: role)
      FileUtils.mkdir_p(File.dirname(paths.fetch(:content_path)))
      unless File.exist?(paths.fetch(:key_path))
        File.write(paths.fetch(:key_path), ActiveSupport::EncryptedConfiguration.generate_key)
        File.chmod(0o600, paths.fetch(:key_path))
      end
      bundle = ActiveSupport::EncryptedConfiguration.new(
        config_path: paths.fetch(:content_path), key_path: paths.fetch(:key_path),
        env_key: "UNUSED_ROLE_PROVISIONING_KEY", raise_if_missing_key: true,
      )
      values = bundle.config.dup
      # Role-scoped secrets. Only values generated here live in the bundle today; secrets still read
      # from the shared .env remain an open isolation gap listed in role-secret-isolation.md.
      values[:DATABASE_PASSWORD] ||= SecureRandom.base58(32)
      values[:SECRET_KEY_BASE] ||= SecureRandom.hex(64)
      bundle.write(values.deep_stringify_keys.to_yaml)

      login = RuntimeRole.database_login(role)
      ActiveRecord::Base.connection_pool.with_connection do |admin|
        quoted_login = admin.quote_table_name(login)
        password = admin.quote(values.fetch(:DATABASE_PASSWORD))
        exists = admin.select_value("SELECT 1 FROM pg_roles WHERE rolname = #{admin.quote(login)}")
        verb = exists ? "ALTER" : "CREATE"
        admin.execute(
          "#{verb} ROLE #{quoted_login} LOGIN PASSWORD #{password} " \
          "NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS",
        )
        RuntimeRole.connections_for(role).each do |connection|
          db = databases.fetch(connection)
          admin.execute("GRANT CONNECT ON DATABASE #{admin.quote_table_name(db)} TO #{quoted_login}")
        end
      end

      # Table privileges are per database, so grant them through a connection to each one.
      RuntimeRole.connections_for(role).each do |connection|
        config = writers.find { |c| c.name == connection }
        # A one-off maintenance-login connection to that database (Rails 8 removed
        # `postgresql_connection`; the adapter is built directly from the writer config).
        conn = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(config.configuration_hash)
        begin
          quoted_login = conn.quote_table_name(login)
          conn.execute("GRANT USAGE ON SCHEMA public TO #{quoted_login}")
          conn.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{quoted_login}")
          conn.execute("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO #{quoted_login}")
        ensure
          conn.disconnect!
        end
      end
      # Read-only feature flags in `primary` (RuntimeRole::FLAG_TABLES); no other table there.
      flag_config = writers.find { |c| c.name == RuntimeRole::FLAG_DATABASE }
      conn = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(flag_config.configuration_hash)
      begin
        quoted_login = conn.quote_table_name(login)
        conn.execute("GRANT CONNECT ON DATABASE #{conn.quote_table_name(flag_config.database)} TO #{quoted_login}")
        conn.execute("GRANT USAGE ON SCHEMA public TO #{quoted_login}")
        RuntimeRole::FLAG_TABLES.each do |table|
          conn.execute("GRANT SELECT ON #{conn.quote_table_name(table)} TO #{quoted_login}")
        end
      ensure
        conn.disconnect!
      end
      puts "provisioned #{role} -> #{login} (#{RuntimeRole.connections_for(role).join(", ")}; flags read-only)"
    end
  end
end
