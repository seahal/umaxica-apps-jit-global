# typed: false
# frozen_string_literal: true

require_relative "boot"

require "ipaddr"
require "rails/all"

Bundler.require(*Rails.groups)

require_relative "../lib/jit_security_active_record_encryption_key_provider"
require_relative "../lib/app_config_loader"
require_relative "../lib/trusted_forwarded_headers"

module Jit
  module TrustedProxiesConfig
    module_function

    def parse(value, required: false)
      proxies =
        value.to_s.split(",").filter_map do |proxy|
          normalized = proxy.strip
          next if normalized.empty?

          parse_proxy(normalized)
        end
      raise KeyError, "Missing required configuration: TRUSTED_PROXIES" if required && proxies.empty?

      proxies
    end

    def parse_proxy(value)
      proxy = IPAddr.new(value)
      if proxy == IPAddr.new("0.0.0.0/0") || proxy == IPAddr.new("::/0")
        raise ArgumentError, "TRUSTED_PROXIES must not contain a catch-all network"
      end

      proxy
    rescue IPAddr::InvalidAddressError => e
      raise ArgumentError, "Invalid TRUSTED_PROXIES entry: #{value.inspect}", cause: e
    end
  end

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults(8.2)

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # CommonHelper ones are `templates`, `generators`, or `middleware`, for example.
    # `omniauth` holds lib/omniauth/strategies/umaxica_entra.rb, which reopens
    # the omniauth_openid_connect gem's own OmniAuth::Strategies module
    # (capitalized "OmniAuth"); Zeitwerk's inflection for the directory name
    # ("Omniauth") would otherwise collide with it.
    # `rubocop` holds lib/rubocop/cop/umaxica/*.rb, the repository's custom
    # architecture cops. They subclass RuboCop::Cop::Base, which only exists
    # under `bin/rubocop`; autoloading them into the application would raise at
    # boot and, under eager loading, take the whole app down.
    config.autoload_lib(ignore: %w(assets tasks omniauth rubocop))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Register app/errors as an eager-load path (not autoload-only). Adding it to
    # autoload_paths alone excluded it from the default app/* eager-load set, so in
    # eager-loading environments (test/production) the error classes were resolved
    # lazily on first reference and skipped by `zeitwerk:check`. eager_load_paths
    # entries are also autoload paths, so this keeps autoloading and restores
    # boot-time constant verification.
    config.eager_load_paths << Rails.root.join("app/errors")
    config.eager_load_paths << Rails.root.join("app/lib")

    ### Added by user
    # Trust X-Forwarded-* headers from reverse proxy (Cloudflare Tunnel, Nginx, etc.)
    # This allows Rails to correctly determine the protocol (HTTP/HTTPS) and host
    trusted_proxies = TrustedProxiesConfig.parse(
      ENV["TRUSTED_PROXIES"],
      required: Rails.env.production?,
    )
    config.action_dispatch.trusted_proxies = trusted_proxies
    config.middleware.insert_before(
      ActionDispatch::RemoteIp,
      TrustedForwardedHeaders,
      trusted_proxies: trusted_proxies,
    )
    config.x.boot_config = AppConfigLoader.load!

    # Active Record Encryption Configuration
    if %w(test production development).include?(Rails.env)
      encryption_keys = JitSecurityActiveRecordEncryptionKeyProvider.fetch
      config.active_record.encryption.primary_key = encryption_keys.fetch(:current)
      config.active_record.encryption.previous = encryption_keys[:previous].map { |previous_key| { key: previous_key } }
      config.active_record.encryption.deterministic_key = encryption_keys.fetch(:deterministic)
      config.active_record.encryption.key_derivation_salt = encryption_keys.fetch(:key_derivation_salt)
    end

    # CSRF outcomes are recorded through CsrfNotificationSubscriber, which subscribes to
    # the three csrf_*.action_controller events (rails/rails#56355) and emits redacted
    # security.csrf.* application events.
    #
    # Rails' own ActionController::LogSubscriber handles the same events and writes
    # payload[:message] verbatim. That message is built by
    # unverified_request_warning_message and can read "HTTP Origin header (...) didn't
    # match request.base_url (...)": free text outside JitLogEvent.format, so
    # ObservabilityRedactor never sees it. Silencing it here leaves the redacted event as
    # the single source of truth. config/environments/development.rb turns it back on,
    # where the raw reason is the useful signal and no real user data is present.
    config.action_controller.log_warning_on_csrf_failure = false

    # Rails encrypted/signed cookies derive keys from secret_key_base.
    # Pin modern primitives explicitly and do not keep SHA1 compatibility rotations.
    config.action_dispatch.signed_cookie_digest = "SHA256"
    config.action_dispatch.encrypted_cookie_cipher = "aes-256-gcm"
    config.action_dispatch.use_authenticated_cookie_encryption = true

    # API paths must never receive an HTML error page. Routing misses under `/api/` never reach a
    # controller, so no `rescue_from` can cover them; only the exceptions app sees both those and
    # unhandled exceptions. Non-API paths keep the static pages in `public/`.
    config.exceptions_app = ->(env) { ApiProblemExceptionsApp.call(env) }

    # USE UTC. RFC 3339 output with a `Z` offset depends on this: a non-UTC zone would make
    # `Time#iso8601` emit a numeric offset instead, which the API contract does not allow.
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc
    config.active_record.schema_format = :sql

    # SMS Provider Configuration
    config.sms_provider = ENV.fetch("SMS_PROVIDER", "aws_sns")
    config.aws_region = ENV.fetch("AWS_REGION", "ap-northeast-1")

    # i18n locale bundles and default locale are configured in
    # config/initializers/locale.rb (single source of truth, includes fallbacks).

    # Set bigserial as default primary key for new tables
    config.generators do |g|
      g.orm(:active_record, primary_key_type: :bigserial)
    end

    # Multi-database async query executor (one thread pool per database)
    config.active_record.async_query_executor = :multi_thread_pool

    # Required belongs_to validation should confirm the associated row, not only
    # the foreign-key value. Tests that create many records should pass loaded
    # reference associations when they intentionally exercise bulk validation.
    config.active_record.belongs_to_required_validates_foreign_key = true

    # Log SQL warnings from PostgreSQL
    config.active_record.db_warnings_action = :raise

    # Allow per-model/per-attribute i18n error message format customization
    config.active_model.i18n_customize_full_message = true
  end
end
