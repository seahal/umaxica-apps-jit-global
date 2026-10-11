# frozen_string_literal: true

# Override db:test:prepare to run db:migrate instead of db:schema:load.
#
# The default Rails behavior (db:schema:load) clears schema_migrations because
# the project's structure.sql files do not include schema_migrations data.
# Running db:migrate instead keeps schema_migrations accurate and avoids the
# "Migrations are pending" halt at the start of every test run.
Rake::Task["db:test:prepare"].clear if Rake::Task.task_defined?("db:test:prepare")

namespace :db do
  namespace :test do
    desc "Override db:test:prepare to run db:migrate instead of db:schema:load"
    task prepare: :environment do
      manifest = Umaxica::TestEnvironment::DatabaseSafety.verify_catalog!
      selected_databases = Umaxica::TestEnvironment::DatabaseSafety.prepare_database_names!(
        manifest:,
      )
      puts "Test database manifest: admin=#{manifest.fetch(:admin_database)} " \
           "databases=#{manifest.fetch(:test_databases).join(",")} " \
           "server=#{manifest[:server_address]}:#{manifest[:server_port]} " \
           "version=#{manifest[:server_version]}"
      puts "Test database migration scope: #{selected_databases.join(",")}"

      ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: "test") do |pool|
        db_config = pool.db_config
        next if db_config.replica?
        next unless selected_databases.include?(db_config.database)

        ActiveRecord::Tasks::DatabaseTasks.migrate(db_config)
      end
    end
  end
end
