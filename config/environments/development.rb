# typed: false
# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Live DOM reloaders mutate forms in-place and break third-party challenge
  # widgets such as Cloudflare Turnstile. Keep them opt-in for public dev hosts.
  config.hotwire.spark.enabled = ENV["HOTWIRE_SPARK_ENABLED"] == "true"

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable Action Controller caching. By default Action Controller caching is disabled.
  # Run rails org:cache to toggle Action Controller caching.
  if Rails.root.join("tmp/caching-org.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true
    config.public_file_server.headers = { "cache-control" => "public, max-age=#{2.days.to_i}" }
  else
    config.action_controller.perform_caching = false
  end

  # Two physically separate Valkey services back two unrelated responsibilities.
  # Cache and rate-limit state have different lifetimes and different blast
  # radiuses, and either one has to be independently flushable without touching
  # the other, so the isolation boundary is the service -- not a logical Redis
  # database index on a shared one. Development runs the same shape as
  # production so the split is exercised rather than assumed.
  #
  # Neither store is authoritative. Losing the cache costs a refetch; losing the
  # rate-limit counters resets the current windows. Neither can corrupt
  # application state, which is what makes Valkey the right substrate for both
  # and the wrong one for anything in PostgreSQL.

  # `RedisCacheStore` swallows a connection error and returns nil. For the cache
  # that is correct -- a miss reconstructs from source. For rate limiting it is
  # not: Rails' `rate_limit` reads `count = store.increment(...)` and acts only
  # `if count && count > to`, so a nil turns every limit off. A Valkey outage
  # therefore drops abuse protection fleet-wide and, without this, does it
  # silently -- indistinguishable from ordinary traffic under the limit.
  #
  # Whether rate limiting should instead fail closed is a real question, but it
  # is an availability decision and not one to make implicitly here. What is not
  # in question is that the degradation must be visible. The exception message is
  # omitted on purpose: it can carry the store URL, and these URLs may embed
  # credentials.
  valkey_store_error_handler =
    lambda do |store|
      lambda do |method:, exception:, returning:|
        Rails.logger.error(
          JitLogEvent.format(
            "valkey.store.unavailable",
            store: store,
            op: method.to_s,
            error_class: exception.class.name,
            degraded_to: returning.inspect,
          ),
        )
      end
    end

  cache_namespace = ["cache", Rails.env, ENV["CACHE_NAMESPACE_SUFFIX"].presence].compact.join(":")
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("CACHE_REDIS_URL"),
    namespace: cache_namespace,
    error_handler: valkey_store_error_handler.call("cache"),
  }
  rate_limit_namespace = [
    "rate_limit",
    Rails.env,
    ENV["RATE_LIMIT_NAMESPACE_SUFFIX"].presence,
  ].compact.join(":")
  config.x.rate_limit.store =
    ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch("RATE_LIMIT_REDIS_URL"),
      namespace: rate_limit_namespace,
      error_handler: valkey_store_error_handler.call("rate_limit"),
    )

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true

  # Make template changes take effect immediately.
  config.action_mailer.perform_caching = false

  ## Letter Opener => https://github.com/ryanb/letter_opener
  #  config.action_mailer.delivery_method = :letter_opener
  # config.action_mailer.perform_deliveries = true

  # Raise on deprecation warnings to catch issues early.
  config.active_support.deprecation = :raise

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Raise on SQL warnings from PostgreSQL (overrides :log in application.rb).
  config.active_record.db_warnings_action = :raise
  config.active_record.dump_schema_after_migration = false

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Include source location in query log tags for easier debugging
  config.active_record.query_log_tags = %i(application controller action job source_location)

  # Detect N+1 queries and raise errors immediately.
  config.active_record.strict_loading_by_default = true
  config.active_record.strict_loading_mode = :n_plus_one_only
  config.active_record.action_on_strict_loading_violation = :raise

  # Disallow deprecated .connection usage (must use .with_connection for multi-DB)
  config.active_record.permanent_connection_checkout = :deprecated

  # Raise error for missing translations in controllers, views, and models.
  config.i18n.raise_on_missing_translations = :strict

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # CSRF verification is mandatory here. Pinned explicitly so a Rails defaults change cannot
  # silently relax it, and so the contrast with the test environment is visible in the file.
  # adr/csrf-protection-disabled-in-test-environment.md
  config.action_controller.allow_forgery_protection = true

  # A parameter the permit list does not cover is a Strong Parameters gap, not a note to
  # read later. The default :log lets the gap ship; raise so it stops the request here.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # On by default since load_defaults 7.0 - pinned so a defaults bump cannot silently
  # turn redirect-to-user-input back into a warning.
  config.action_controller.action_on_open_redirect = :raise

  # config/application.rb silences Rails' own CSRF warning so production keeps a single
  # redacted record per event. In development the raw reason is what makes a blocked
  # request diagnosable - which Origin failed to match which base_url - and the log holds
  # no real user data, so turn it back on here.
  config.action_controller.log_warning_on_csrf_failure = true

  # Apply autocorrection by RuboCop to files generated by `bin/rails generate`.
  config.generators.apply_rubocop_autocorrect_after_generate!

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  config.action_dispatch.verbose_redirect_logs = true

  # Use Solid Queue in Development.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue, reading: :queue_replica } }

  # Enable Gzip compression
  config.middleware.use(Rack::Deflater)

  # Enable DNS rebinding protection for hosts used in route constraints.
  boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
  boot_config_hosts = [
    boot_hosts.sign_origins,
    boot_hosts.core_origins,
    boot_hosts.base_origins,
    boot_hosts.palm_origins,
    [boot_hosts.help_service, boot_hosts.help_corporate, boot_hosts.help_staff],
    boot_hosts.info_origins,
  ].flatten
  boot_config_hosts.map!(&:host)

  # Development is published through Cloudflare Tunnel under the browser-facing site names,
  # with Cloudflare Access as the perimeter in front of them. Host Authorization therefore
  # has to admit both hostname families here, and boot_config is not filtered: requests that
  # arrive directly on the compose `frontend` network carry a PRIVATE_* `*.localhost` alias,
  # while requests the connector forwards carry the browser's public site name, because
  # cloudflared leaves `Host` unmodified unless `httpHostHeader` is set. Access, not Host
  # Authorization, is what keeps an unauthenticated stranger off this listener; Rails
  # authentication and authorization remain authoritative behind it.
  # See docs/architecture/cloudflare-request-paths.md.
  localhost_tunnel_hosts = %w(
    auth.app.localhost:3000
    auth.com.localhost:3000
    auth.org.localhost:3000
    base.app.localhost:3000
    base.org.localhost:3000
    base.com.localhost:3000
    base.net.localhost:3000
    base.dev.localhost:3000
    info.com.localhost:3000
    info.org.localhost:3000
    info.app.localhost:3000
    help.com.localhost:3000
    help.org.localhost:3000
    help.app.localhost:3000
    core.com.localhost:3000
    core.org.localhost:3000
    core.app.localhost:3000
    core.net.localhost:3000
    core.dev.localhost:3000
    docs.com.localhost:3000
    docs.org.localhost:3000
    docs.app.localhost:3000
    news.com.localhost:3000
    news.org.localhost:3000
    news.app.localhost:3000
    side.com.localhost:3000
    side.org.localhost:3000
    side.app.localhost:3000
    palm.app.localhost:3000
  )

  # Both families, deliberately. Per adr/public-private-url-boundaries.md, `PUBLIC_*` names
  # the site a browser or app sees (www.umaxica.app) and `PRIVATE_*` names the network-side
  # ingress the tunnel connects to. Host Authorization evaluates the `Host` Rails actually
  # receives, and in development that is either one: the private alias on a direct
  # `frontend` network request, or the public site name on a request forwarded by
  # cloudflared. Both are read from the environment rather than hardcoded so compose.yaml
  # stays the single source of hostnames; a new tunnel hostname is added there, not here.
  env_host_keys = %w(
    PRIVATE_BASE_CORPORATE_URL
    PRIVATE_BASE_SERVICE_URL
    PRIVATE_BASE_STAFF_URL
    PRIVATE_BASE_NETWORK_URL
    PRIVATE_BASE_DEVELOPER_URL
    PRIVATE_AUTH_CORPORATE_URL
    PRIVATE_AUTH_SERVICE_URL
    PRIVATE_AUTH_STAFF_URL
    PRIVATE_CORE_SERVICE_URL
    PRIVATE_CORE_STAFF_URL
    PRIVATE_CORE_CORPORATE_URL
    PRIVATE_PALM_SERVICE_URL
    PRIVATE_INFO_SERVICE_URL
    PRIVATE_INFO_STAFF_URL
    PRIVATE_INFO_CORPORATE_URL
    PRIVATE_DOCS_SERVICE_URL
    PRIVATE_DOCS_STAFF_URL
    PRIVATE_DOCS_CORPORATE_URL
    PRIVATE_NEWS_SERVICE_URL
    PRIVATE_NEWS_STAFF_URL
    PRIVATE_NEWS_CORPORATE_URL
    PRIVATE_HELP_SERVICE_URL
    PRIVATE_HELP_STAFF_URL
    PRIVATE_HELP_CORPORATE_URL
    PUBLIC_AUTH_SERVICE_URL
    PUBLIC_AUTH_CORPORATE_URL
    PUBLIC_AUTH_STAFF_URL
    PUBLIC_BASE_SERVICE_URL
    PUBLIC_BASE_CORPORATE_URL
    PUBLIC_BASE_STAFF_URL
    PUBLIC_BASE_DEVELOPER_URL
    PUBLIC_CORE_SERVICE_URL
    PUBLIC_CORE_CORPORATE_URL
    PUBLIC_CORE_STAFF_URL
    PUBLIC_SIDE_SERVICE_URL
    PUBLIC_SIDE_CORPORATE_URL
    PUBLIC_SIDE_STAFF_URL
    PUBLIC_PALM_SERVICE_URL
    PUBLIC_INFO_SERVICE_URL
    PUBLIC_INFO_CORPORATE_URL
    PUBLIC_INFO_STAFF_URL
    PUBLIC_DOCS_SERVICE_URL
    PUBLIC_DOCS_CORPORATE_URL
    PUBLIC_DOCS_STAFF_URL
  )
  env_hosts =
    ENV.values_at(*env_host_keys).compact_blank.flat_map do |value|
      origin = ConfigValues.build(value, allow_localhost: true)
      default_port = (origin.scheme == "https") ? 443 : 80
      [origin.host, ("#{origin.host}:#{origin.port}" if origin.port != default_port)]
    end

  config.hosts.concat(
    (boot_config_hosts + localhost_tunnel_hosts + env_hosts).compact_blank.uniq,
  )

  ## file watcher
  config.file_watcher = ActiveSupport::FileUpdateChecker

  ## Email Settings
  config.action_mailer.delivery_method = :smtp
  # Match the dev Auth surface private origin. `sign.app.localhost` predates the Sign ->
  # Auth surface rename and resolves nowhere: compose.yaml publishes no `sign.*` alias and
  # config.hosts has no such entry, so mail links built here were unreachable. Production
  # uses boot_config's base_service host. Puma serves on 3000.
  config.action_mailer.default_url_options = { host: "auth.app.localhost", port: 3000 }
  config.action_mailer.smtp_settings = {
    address: "email-smtp.#{ENV.fetch("AWS_SES_REGION", "ap-northeast-1")}.amazonaws.com",
    user_name: Rails.app.creds.option(:AWS_SES_SMTP_USERNAME),
    password: Rails.app.creds.option(:AWS_SES_SMTP_PASSWORD),
    port: 465,
    tls: true,
    authentication: :login,
    openssl_verify_mode: "peer",
    open_timeout: 5,
    read_timeout: 10,
  }

  # Serve Vite's auto-built files from public/vite-dev when the Vite dev server
  # is not the active asset host for a request.
  config.public_file_server.enabled = true

  # SMS Provider Configuration - Use test provider in development
  config.sms_provider = ENV.fetch("SMS_PROVIDER", "test")
end
