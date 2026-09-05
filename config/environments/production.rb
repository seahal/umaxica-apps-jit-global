# typed: false
# frozen_string_literal: true

# Environment files are evaluated before autoloading is set up, so this is required explicitly rather
# than resolved from lib/ by Zeitwerk.
require_relative "../../lib/health_probe_paths"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  # config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  #
  # `PUBLIC_ASSET_URL` is the preferred name (adr/public-private-url-boundaries.md);
  # `ASSET_URL` stays a supported compatibility input because CI sets it
  # (.github/workflows/ci.yml). There is deliberately no literal default: a hardcoded
  # asset host silently served every production asset from one environment's CDN if the
  # variable was ever missing. Fail at boot and name what is missing instead.
  config.asset_host =
    ENV["PUBLIC_ASSET_URL"].presence || ENV["ASSET_URL"].presence ||
    raise(KeyError, "PUBLIC_ASSET_URL must be set in production (legacy alias: ASSET_URL)")

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL and use secure cookies.
  config.force_ssl = true

  # Rails emits HSTS as a safe default; the CDN may override or replace this header.
  # includeSubDomains is enabled so every subdomain is HTTPS-only. preload stays off:
  # preload-list registration is effectively irreversible and requires every subdomain to
  # serve HTTPS, so it is deferred until a deliberate review (see
  # adr/session-token-hardening-baseline.md).
  config.ssl_options = {
    hsts: {
      expires: 365.days,
      subdomains: true,
      preload: false,
    },
  }

  # Log application output to STDOUT for Cloud Run visibility.
  STDOUT.sync = true
  STDERR.sync = true
  primary_logger = ActiveSupport::Logger.new($stdout)
  primary_logger.formatter = config.log_formatter if config.log_formatter

  # Use BroadcastLogger (Rails 8 standard) to allow multiple log sinks if needed.
  config.logger = ActiveSupport::BroadcastLogger.new(
    ActiveSupport::TaggedLogging.new(primary_logger),
  )
  config.log_tags = [:request_id]

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/health"

  # Report deprecations via Sentry (do not silence them)
  config.active_support.report_deprecations = true
  config.active_support.deprecation = :notify

  # Treat PostgreSQL warnings as errors (same strict setting as dev/test)
  config.active_record.db_warnings_action = :raise

  # Warn on excessive record fetches (early detection of N+1 and query design issues)
  config.active_record.warn_on_records_fetched_greater_than = 10_000

  # Cache query log tags for performance
  config.active_record.cache_query_log_tags = true

  # Enumerate columns in SELECT to avoid prepared statement cache errors on column changes
  config.active_record.enumerate_columns_in_select_statements = true

  # Require --no-sandbox flag to run destructive console operations
  config.sandbox_by_default = true

  # Rails.cache and the rate-limit store are separate application contracts even
  # though both speak the Redis protocol. CACHE_REDIS_URL and
  # RATE_LIMIT_REDIS_URL are resolved independently so a deployment can point
  # them at separate services, separate managed databases, or the same provider,
  # without the application knowing which. Both use one-argument ENV.fetch: a
  # missing URL must stop the boot rather than silently degrade to an in-process
  # store that makes cache and rate-limit state per-process.
  #
  # Nothing authoritative lives in either. Cache entries are reconstructible and
  # carry an explicit TTL; rate-limit counters expire with their window.

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

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  # url_for's :host option expects a bare hostname; OriginValue#to_s returns a full
  # "https://..." origin, so use #host.
  config.action_mailer.default_url_options = { host: Rails.configuration.x.boot_config.fetch(:hosts).base_service.host }

  ## Email Settings
  config.action_mailer.delivery_method = :smtp
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

  # Locale fallbacks are configured in config/initializers/locale.rb, which is the single source of
  # truth for the load path, available locales, and the fallback chain. Setting them here as well
  # would be overwritten by that initializer and hide which value actually applies.

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # Collect all host ENV vars used in route constraints.
  boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
  # Rails host authorization matches against the bare hostname from the Host header,
  # so use OriginValue#host (e.g. "www.umaxica.app") - not #to_s which is a full origin.
  config.hosts = [
    boot_hosts.base_service.host,
    boot_hosts.base_corporate.host,
    boot_hosts.base_staff.host,
    boot_hosts.sign_service.host,
    boot_hosts.sign_corporate.host,
    boot_hosts.sign_staff.host,
    boot_hosts.core_service.host,
    boot_hosts.core_corporate.host,
    boot_hosts.core_staff.host,
    "auth.umaxica.app",
    "auth.umaxica.com",
    "auth.umaxica.org",
    "side-jp.umaxica.app",
    "side-jp.umaxica.com",
    "side-jp.umaxica.org",
    "www.umaxica.app",
    "www.umaxica.com",
    "www.umaxica.org",
    # Legacy Core host family. `adr/core-canonical-public-host.md` chose jp.umaxica.* as
    # canonical; these stay until the external OAuth/OIDC redirect URIs are re-registered
    # and the jpx.* column defaults are migrated, then they are removed.
    "jpx.umaxica.app",
    "jpx.umaxica.com",
    "jpx.umaxica.org",
    # Canonical Core host family. Listed alongside the legacy families during the cutover so
    # the origin answers on the new name before the edge publishes it.
    "jp.umaxica.app",
    "jp.umaxica.com",
    "jp.umaxica.org",
    boot_hosts.palm_service.host,
    boot_hosts.palm_corporate.host,
    boot_hosts.palm_staff.host,
    boot_hosts.help_service.host,
    boot_hosts.help_corporate.host,
    boot_hosts.help_staff.host,
    boot_hosts.info_service.host,
    boot_hosts.info_corporate.host,
    boot_hosts.info_staff.host,
  ]
  # The docs and news surfaces have no host entry. Their only entries here were
  # `docs.*.localhost` and `news.*.localhost` -- private development ingress names, which
  # no production request can carry: the edge routes no such name, and
  # ConfigValues::HostFamilyValues defines no docs/news member to derive a real one from.
  # They were removed rather than left as a development ingress name accepted in
  # production. Add the real ingress hosts here (preferably via boot_config) before serving
  # either surface publicly.

  # Skip DNS rebinding protection for the internal health probes, and only for them.
  #
  # This previously matched `"/health"` alone, while the probe set this application mounts is four
  # paths. `/health/liveness`, `/health/readiness` and `/health/startup` were therefore answered by
  # Host Authorization rather than by the probe whenever the caller addressed the origin by container
  # name or pod IP -- the normal orchestrator case, since those names are deliberately not in
  # `config.hosts`.
  #
  # `HealthProbePaths` matches the four paths exactly rather than by `/health/` prefix, so a probe
  # added later cannot inherit the exemption without a deliberate decision. See that file for what
  # the exemption costs and why it is acceptable for these four responses.
  #
  # Preferred over widening this list: give the probe a `Host` that is already in `config.hosts`.
  # A probe that sets its own `Host` header needs no exemption at all.
  config.host_authorization = { exclude: ->(request) { HealthProbePaths.probe?(request) } }

  ### Added by owner
  # We've configured this production environment to prevent the delivery of public static content.
  config.public_file_server.enabled = false

  # Gzip compression, restricted to content types that carry no secret alongside
  # attacker-influenced text.
  #
  # Compressing HTML is the BREACH precondition: every authenticated page embeds
  # the CSRF authenticity token, and the sign-in and identity surfaces reflect
  # submitted input back into the same response. An attacker who can trigger
  # requests and observe compressed response sizes can recover the token a byte
  # at a time, and Rails adds no length randomization. text/html is therefore
  # excluded here rather than compressed.
  config.middleware.use(
    Rack::Deflater,
    include: %w(
      application/javascript
      application/json
      application/xml
      image/svg+xml
      text/css
      text/javascript
      text/plain
      text/xml
    ),
  )

  # Additional security headers
  config.action_dispatch.default_headers.merge!(
    "Referrer-Policy" => "strict-origin-when-cross-origin",
    "X-Permitted-Cross-Domain-Policies" => "none",
  )

  # Default SameSite for cookies that do not set the attribute themselves (e.g. CSRF authenticity).
  # Strict by default: the Rails session cookie keeps SameSite=Lax via its explicit option in
  # config/initializers/session_store.rb (it must carry OIDC/email cross-site inbound flow state),
  # so this stricter default does not affect it. See plans/backlog for the session-cookie Strict
  # migration that would remove the remaining Lax dependency.
  config.action_dispatch.cookies_same_site_protection = :strict

  # Raise on missing callback actions (same as dev/test)
  config.action_controller.raise_on_missing_callback_actions = true

  # CSRF verification is mandatory here. Pinned explicitly so a Rails defaults change cannot
  # silently relax it, and so the contrast with the test environment is visible in the file.
  # adr/csrf-protection-disabled-in-test-environment.md
  config.action_controller.allow_forgery_protection = true

  # Raise on email delivery errors (immediate detection of SES failures)
  config.action_mailer.raise_delivery_errors = true

  # Raise on missing translation keys (quality assurance for i18n)
  config.i18n.raise_on_missing_translations = true
end
