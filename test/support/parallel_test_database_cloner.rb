# frozen_string_literal: true

require "digest"
require "fileutils"
require "pg"
require "set"

module ParallelTestDatabaseCloner
  # CREATE DATABASE ... TEMPLATE fails when the template is used by another
  # concurrent copy, so parallelism is across distinct template sources only.
  CLONE_THREADS = 8

  module_function

  def install!(workers:)
    acquire_test_process_lock!

    return if workers <= 1

    ActiveSupport::Testing::Parallelization.before_fork_hook do
      rebuild_stale_worker_clones(workers)
    end

    ActiveSupport::Testing::Parallelization.after_fork_hook do |worker|
      ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true).each do |db_config|
        db_config._database = "#{db_config.database}_#{worker}"
      end
      ActiveRecord::Base.establish_connection
    end
  end

  def acquire_test_process_lock!
    return if @test_process_lock

    FileUtils.mkdir_p(Rails.root.join("tmp"))
    @test_process_lock = Rails.root.join("tmp/parallel-test-databases.lock").open(File::RDWR | File::CREAT, 0o644)
    @test_process_lock.flock(File::LOCK_EX)

    at_exit do
      @test_process_lock&.flock(File::LOCK_UN)
      @test_process_lock&.close
    end
  end

  # Staleness is judged from the schema_sha comment stamped on each clone
  # database (readable for all clones in one pg_database catalog query), NOT
  # from per-clone data fingerprints: clones are dropped and re-templated on any
  # schema change, and test writes are rolled back by transactional fixtures, so
  # a per-clone data scan (previously: one connection + count(*) on every table
  # for each of workers x databases clones) bought no real protection for its
  # cost. If a clone is ever corrupted outside that model, drop it (or wipe the
  # tmpfs data dir) and it is rebuilt on the next run.
  def rebuild_stale_worker_clones(workers)
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "test", include_hidden: true)
    base_configs = configs.reject(&:replica?)
    base_configs_by_name = base_configs.index_by(&:name)
    databases = configs.map(&:database).uniq.sort
    first_config = configs.first.configuration_hash
    schema_sha_by_database = base_configs.to_h { |config| [config.database, schema_sha(config)] }
    configs.select(&:replica?).each do |replica_config|
      base_config = base_configs_by_name.fetch(replica_config.name.delete_suffix("_replica"))
      schema_sha_by_database[replica_config.database] = schema_sha_by_database.fetch(base_config.database)
    end

    ActiveRecord::Base.connection_handler.clear_all_connections!

    admin_connection = connect(first_config, ENV.fetch("POSTGRESQL_DATABASE", "db"))
    admin_connection.exec("select pg_advisory_lock(hashtext('umaxica_parallel_test_database_cloner'))")

    stamped_sha = clone_sha_by_database(admin_connection)
    raise_if_missing_base_databases!(base_configs, stamped_sha)
    clone_replica_databases!(
      configs: configs,
      base_configs_by_name: base_configs_by_name,
      first_config: first_config,
      schema_sha_by_database: schema_sha_by_database,
      stamped_sha: stamped_sha,
    )
    clone_worker_databases!(
      databases: databases,
      workers: workers,
      first_config: first_config,
      schema_sha_by_database: schema_sha_by_database,
      stamped_sha: stamped_sha,
    )
  ensure
    admin_connection&.exec("select pg_advisory_unlock(hashtext('umaxica_parallel_test_database_cloner'))")
    admin_connection&.close
  end

  def raise_if_missing_base_databases!(base_configs, stamped_sha)
    missing_base = base_configs.map(&:database).reject { |database| stamped_sha.key?(database) }
    # rubocop:disable I18n/RailsI18n/DecorateString
    raise RuntimeError,
          "Missing base test DBs: #{missing_base.join(", ")}. " \
          "Run RAILS_ENV=test bin/rails db:test:prepare." unless missing_base.empty?
    # rubocop:enable I18n/RailsI18n/DecorateString
  end

  def clone_replica_databases!(configs:, base_configs_by_name:, first_config:, schema_sha_by_database:, stamped_sha:)
    replica_tasks =
      configs.select(&:replica?).filter_map do |replica_config|
        base_config = base_configs_by_name.fetch(replica_config.name.delete_suffix("_replica"))
        clone_task(
          stamped_sha,
          source: base_config.database,
          clone: replica_config.database,
          sha: schema_sha_by_database.fetch(replica_config.database),
        )
      end
    run_clone_tasks(first_config, replica_tasks)
    replica_tasks.each { |task| stamped_sha[task.fetch(:clone)] = task.fetch(:sha) }
  end

  def clone_worker_databases!(databases:, workers:, first_config:, schema_sha_by_database:, stamped_sha:)
    worker_tasks =
      databases.flat_map do |database|
        workers.times.filter_map do |worker|
          clone_task(
            stamped_sha,
            source: database,
            clone: "#{database}_#{worker}",
            sha: schema_sha_by_database.fetch(database),
          )
        end
      end
    run_clone_tasks(first_config, worker_tasks)
  end

  # One catalog query yields existence + stamped schema sha for every database.
  def clone_sha_by_database(connection)
    connection.exec(<<~SQL.squish).to_h { |row| [row.fetch("datname"), row["sha"]] }
      select datname, shobj_description(oid, 'pg_database') as sha
      from pg_database
    SQL
  end

  def clone_task(stamped_sha, source:, clone:, sha:)
    # A nil sha (schema dump file absent) cannot prove freshness, so the clone
    # rebuilds every run until the dump exists.
    return nil if sha && stamped_sha.key?(clone) && stamped_sha[clone] == sha

    { source: source, clone: clone, sha: sha, clone_exists: stamped_sha.key?(clone) }
  end

  def run_clone_tasks(config, tasks)
    groups = tasks.group_by { |task| task.fetch(:source) }.values
    return if groups.empty?

    queue = Queue.new
    groups.each { |group| queue << group }
    thread_count = [CLONE_THREADS, groups.size].min
    thread_count.times { queue << nil }

    errors = Queue.new
    Array.new(thread_count) {
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        connection = connect(config, ENV.fetch("POSTGRESQL_DATABASE", "db"))
        begin
          loop do
            group = queue.pop
            break if group.nil?

            group.each { |task| rebuild_clone(connection, **task) }
          end
        rescue => e
          errors << e
        ensure
          connection.close
        end
      end
    }.each(&:join)

    raise errors.pop unless errors.empty?
  end

  def rebuild_clone(admin_connection, source:, clone:, sha:, clone_exists:)
    if clone_exists
      terminate_connections(admin_connection, clone)

      begin
        admin_connection.exec("drop database #{admin_connection.quote_ident(clone)} with (force)")
      rescue PG::SyntaxError
        admin_connection.exec("drop database #{admin_connection.quote_ident(clone)}")
      end
    end

    admin_connection.exec(
      "create database #{admin_connection.quote_ident(clone)} template #{admin_connection.quote_ident(source)}",
    )
    return unless sha

    admin_connection.exec(
      "comment on database #{admin_connection.quote_ident(clone)} is '#{admin_connection.escape_string(sha)}'",
    )
  end

  def terminate_connections(connection, database)
    connection.exec_params(
      "select pg_terminate_backend(pid) from pg_stat_activity where datname = $1 and pid <> pg_backend_pid()",
      [database],
    )
  end

  # A clone is fresh iff it still matches the base database it was templated from, so the
  # fingerprint has to describe that base -- not merely the files the base was supposed to have been
  # built from.
  #
  # Hashing the migration sources alone is what made this go wrong before. `CREATE DATABASE ...
  # TEMPLATE` copies whatever the base currently holds, but the stamp asserted what the migration
  # files currently say, and nothing checked that the base had been rebuilt from them. Once a run
  # cloned a not-yet-migrated base, every clone carried the old schema under the new sha, and the
  # stamp then matched forever: `db:migrate:reset` fixed the base and left all twelve workers wrong,
  # failing with `relation "..." does not exist` against a base where the relation plainly existed.
  #
  # `base_schema_digest` closes that by reading the base's real catalog, so any change to the base --
  # a migration applied, a migration edited in place and replayed, a branch switch, manual DDL --
  # moves the sha and rebuilds the clones. The migration sources stay in the digest because they are
  # free here and still catch an edit whose effect on the catalog is nil.
  def schema_sha(config)
    schema_path = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(config, config.schema_format)
    return nil unless File.exist?(schema_path)

    digest = Digest::SHA1.new
    digest << File.binread(schema_path)
    Array(config.migrations_paths).sort.each do |path|
      Dir.glob(File.join(path, "*.rb")).sort.each do |migration_path|
        digest << migration_path
        digest << File.binread(migration_path)
      end
    end
    digest << base_schema_digest(config)
    digest.hexdigest
  end

  # Every column of every ordinary, partitioned, and view relation in `public`, ordered so the
  # digest does not depend on catalog scan order. Aggregated in PostgreSQL rather than in Ruby: one
  # round trip per base database, and nothing but the 32-byte result crosses the wire.
  BASE_SCHEMA_DIGEST_SQL = <<~SQL.squish
    select coalesce(md5(string_agg(entry, chr(10) order by entry)), '') as digest
    from (
      select c.relname || ':' || a.attname || ':' ||
             format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull as entry
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a on a.attrelid = c.oid
      where n.nspname = 'public'
        and c.relkind in ('r', 'p', 'v', 'm')
        and a.attnum > 0
        and not a.attisdropped
    ) columns
  SQL

  # A base database that does not exist yet has no schema to digest, and
  # `raise_if_missing_base_databases!` is what reports that -- with the remedy -- a moment later.
  # Returning a marker here keeps this from raising a bare PG error first.
  def base_schema_digest(config)
    connection = connect(config.configuration_hash, config.database)
    begin
      connection.exec(BASE_SCHEMA_DIGEST_SQL).first.fetch("digest")
    ensure
      connection.close
    end
  rescue PG::ConnectionBad
    "absent"
  end

  def connect(config, database)
    PG.connect(
      host: config.fetch(:host),
      port: config.fetch(:port, 5432),
      user: config.fetch(:username),
      password: config[:password],
      dbname: database,
    )
  end
end
