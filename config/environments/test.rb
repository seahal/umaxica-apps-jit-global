# typed: false
# frozen_string_literal: true

require_relative "../../test/support/swappable_cache_store"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Use the cheapest password hashing cost in tests. Honored by both bcrypt and
  # argon2 (ActiveModel::SecurePassword::Argon2Password switches to the
  # :unsafe_cheapest profile when min_cost is true). Set after initialization so
  # the secure_password algorithm is loaded first.
  config.after_initialize { ActiveModel::SecurePassword.min_cost = true }

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application before parallel workers fork.
  # Process-based parallelize relies on this so each worker inherits the loaded
  # constant table via copy-on-write instead of repeating cold autoload after fork.
  config.eager_load = true

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true

  # Both stores are null by default so no test inherits state it did not ask for.
  #
  # Rails.cache: a test that passes only because an earlier test warmed the cache
  # is a test that does not describe the behaviour it claims to. A null cache
  # forces every read to go to its real source.
  #
  # Rate limiting: the counters are process-global and survive a transaction
  # rollback, so a shared counting store makes an unrelated controller test fail
  # with 429 depending on suite order and parallel worker assignment. Tests whose
  # subject *is* rate limiting opt into a real counting store by declaring
  # `counts_rate_limits!` (test/support/rate_limit_store_override.rb), which is
  # where threshold, window, bucket, and 429 behaviour is asserted.
  config.cache_store = :null_store
  config.x.rate_limit.store = SwappableCacheStore.new(ActiveSupport::Cache::NullStore.new)

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Off by default, permanently - this is the Rails-generated test default, and under
  # `protect_from_forgery using: :header_or_legacy_token` a bare test request verifies
  # successfully anyway, so enabling it suite-wide would buy appearance, not coverage.
  # CSRF is asserted by targeted boundary tests that opt in with `with_forgery_protection`.
  # Decision and the condition that would reopen it:
  # adr/csrf-protection-disabled-in-test-environment.md
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  # config.active_storage.service = :test

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Tell Active Job to use the test adapter
  config.active_job.queue_adapter = :test
  config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue_replica } }

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Raise on deprecation warnings to catch issues early.
  config.active_support.deprecation = :raise

  # Raise error for missing translations in controllers, views, and models.
  config.i18n.raise_on_missing_translations = :strict

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Disallow deprecated .connection usage (must use .with_connection for multi-DB)
  config.active_record.permanent_connection_checkout = :deprecated
  config.active_record.async_query_executor = nil
  # Raise on SQL warnings from PostgreSQL.
  config.active_record.db_warnings_action = :raise
  config.active_record.dump_schema_after_migration = false

  # Detect N+1 queries and raise errors immediately.
  config.active_record.strict_loading_by_default = true
  config.active_record.strict_loading_mode = :n_plus_one_only
  config.active_record.action_on_strict_loading_violation = :raise

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # A parameter the permit list does not cover is a Strong Parameters gap, not a note to
  # read later. The default :log lets the gap ship; raise so a test fails on it.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # On by default since load_defaults 7.0 - pinned so a defaults bump cannot silently
  # turn redirect-to-user-input back into a warning.
  config.action_controller.action_on_open_redirect = :raise

  # Match development so an enqueue site that loses its job is visible in a failing test.
  config.active_job.verbose_enqueue_logs = true

  # A failing test with no log is a failing test you debug blind. Log to a file - never to
  # stdout, which would interleave with minitest's own output across parallel workers.
  #
  # :info is the default because it is the level that costs almost nothing and answers most
  # questions: request verb/path/status, redirect targets, rendered templates, enqueued jobs,
  # delivered mail. SQL lives at :debug and is the expensive one, both in I/O and in string
  # building, so it stays opt-in: run `LOG_LEVEL=debug bin/rails test path/to/file.rb` when a
  # specific failure needs query-level detail.
  #
  # `filter_parameters` (config/initializers/filter_parameter_logging.rb) already redacts
  # credentials, tokens, and identifiers, so the request lines here carry no secrets.
  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym

  # Truncate per run, deliberately in place of Rails' own bound on this file.
  #
  # Since `load_defaults "7.1"` Rails sets `log_file_size = 100.megabytes` for local
  # environments, so `log/test.log` already rotates at 100 MB keeping one old file - it does
  # not grow without bound. That bound protects the disk; it does not make the file readable.
  # Appending leaves several runs interleaved in one file, and a rotation can split the run
  # you are debugging across two files.
  #
  # Truncating makes the file mean exactly one thing: the run that just finished. It also
  # bounds the size far more tightly than 100 MB. Passing an open File (rather than a path)
  # is what takes this out of `log_file_size`'s hands, and that is intended.
  #
  # The cost: two `bin/rails test` invocations running at once clobber each other's log.
  test_log = Rails.root.join("log/test.log")
  test_log.dirname.mkpath
  test_log_device = test_log.open("w")
  test_log_device.sync = true

  # Workers fork after this logger is built and share the one file, so lines from different
  # workers interleave. Tagging by request id is what lets you follow one request through
  # that interleaving; Rails already prints a test-name banner for non-request tests.
  config.logger =
    ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(test_log_device))
  config.log_tags = [:request_id]

  # ci seed up.
  if ENV["CI"]
    config.assets.compile = false
    config.assets.gzip = false
  end

  # SMS Provider Configuration - Use test provider in test environment
  config.sms_provider = "test"

  # Unlogged tables skip WAL entirely -- less write work per test and less
  # pg_wal pressure on the tmpfs-backed primary. The old shared-memory concern
  # no longer applies: the postgres container now runs with shm_size 4gb.
  ActiveSupport.on_load(:active_record_postgresqladapter) do
    self.create_unlogged_tables = true
  end

  config.after_initialize do
    # Rails' fixture FK validation deadlocks under this multi-DB test suite; the
    # database constraints still enforce integrity when fixtures are loaded.
    ActiveRecord.verify_foreign_keys_for_fixtures = false
  end

  # Log slow queries over 100ms.
  config.active_record.query_log_tags_enabled = true
end
