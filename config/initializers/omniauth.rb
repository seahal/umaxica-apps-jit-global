# typed: false
# frozen_string_literal: true

# =============================================================================
# OmniAuth Configuration
# =============================================================================
#
# Supported providers:
# - Google OAuth2: Standard OAuth2 flow with state parameter
# - Apple Sign In: Uses OIDC code flow with query response mode
#
# Routing (OmniAuth standard):
# - Start:    POST /social/google, POST /social/apple (CSRF protected via omniauth-rails_csrf_protection)
# - Callback: GET /social/google/callback, GET /social/apple/callback
# - Failure:  GET /social/failure
#
# Our custom entry point:
# - GET /social/:provider/session/new and /social/:provider/registration/new -> prepares intent, renders a POST form
#
# State Parameter:
# - SocialCallbackGuard validates callback state through CallbackStateStore for all app providers.
# - SocialAuth stores intent context; provider callback CSRF protection is not solely owned
#   by that concern.
# - Apple provider_ignores_state disables provider-side state handling only; app-side
#   CallbackStateStore/SocialCallbackGuard validation still runs.
#
# IMPORTANT: Apple Sign In Constraints
# - Callback URL must be HTTPS with a valid domain (no localhost/IP)
# - Local development requires a tunnel (ngrok, Cloudflare Tunnel, etc.)
# - Register exactly: https://<your-domain>/social/apple/callback in Apple Developer
# - Callback uses GET because response_mode is query.
#
# IMPORTANT: Google Cloud Console Setup
# - App client: register /social/google/callback
#
# =============================================================================

require Rails.root.join(
  "lib/external_authentication_infrastructure_omniauth_apple_nonce_enforcement",
)
require Rails.root.join(
  "lib/external_authentication_infrastructure_omniauth_google_oidc_enforcement",
)
require Rails.root.join("lib/omniauth/strategies/umaxica_entra")
require Rails.root.join("lib/entra_omniauth_boot_credentials")

OmniAuth::Strategies::Apple.prepend(
  ExternalAuthenticationInfrastructureOmniauthAppleNonceEnforcement,
)
OmniAuth::Strategies::GoogleOauth2.prepend(
  ExternalAuthenticationInfrastructureOmniauthGoogleOidcEnforcement,
)

# Load credentials early
# App (user) Google credentials
google_client_id = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_ID)
google_client_secret = Rails.app.creds.option(:OMNI_AUTH_GOOGLE_APP_CLIENT_SECRET)
apple_client_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_CLIENT_ID)
apple_team_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_TEAM_ID)
apple_key_id = Rails.app.creds.option(:OMNI_AUTH_APPLE_KEY_ID)
apple_pem = Rails.app.creds.option(:OMNI_AUTH_APPLE_PRIVATE_KEY)

# Org (staff) Microsoft Entra ID credential. Tenant id and client id are read
# through ExternalAuthentication::ProviderRegistry, which names them on the
# provider entry; only the secret is needed here, because it is the one value
# the OmniAuth client options must carry. Production still fails boot when the
# secret is absent. Development and test omit the entra provider instead of
# requiring an unused IdP credential for CMS and other non-Entra tests.
entra_client_secret = EntraOmniauthBootCredentials.secret_for_boot(
  Rails.app.creds.option(:OMNI_AUTH_ENTRA_ORG_CLIENT_SECRET),
)

module OmniAuthCallbackOrigin
  module_function

  CALLBACK_ORIGIN_VALUE = ConfigValues.build(
    ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    allow_localhost: !Rails.env.production?,
  )
  CALLBACK_ORIGIN = CALLBACK_ORIGIN_VALUE.to_s.freeze

  def call(_env)
    callback_origin
  end

  def callback_origin
    CALLBACK_ORIGIN
  end

  def callback_host
    uri = CALLBACK_ORIGIN_VALUE.uri
    return uri.host if uri.port == uri.default_port

    "#{uri.host}:#{uri.port}"
  end
end

OmniAuth.config.full_host = ->(env) { OmniAuthCallbackOrigin.call(env) }
OmniAuth.config.path_prefix = "/social"

# =============================================================================
# Social Login Provider/Host Allow Matrix
# =============================================================================
# Replaces a blanket "block /social/* on every non-app host" rule with an
# explicit provider allow-list per surface. Only Apple/Google are allowed on
# the app surface; only Entra is allowed on the org (staff) surface; com
# (corporate/public) hosts allow no external OmniAuth strategy at all.
#
# `entra` is allowed ONLY on the specific staff auth host that owns
# /social/entra/callback (ExternalAuthenticationEntraRedirectUri), never on
# sign/base/core hosts, and never on corporate (com) hosts.
class OmniAuthSocialProviderHostMatrix
  # Every OmniAuth provider mounted under /social/*. A path segment outside
  # this set (e.g. "authentication" in /social/authentication/completion,
  # the app-surface social sign-up continuation/completion endpoints) is not
  # a provider at all and is handled by the non-provider branch below,
  # matching the pre-existing app-surface-only behavior for those paths.
  KNOWN_PROVIDERS = %w(google apple entra).freeze
  APP_ALLOWED_PROVIDERS = %w(google apple).freeze
  ORG_ALLOWED_PROVIDERS = %w(entra).freeze

  ENTRA_ALLOWED_PATHS = %w(
    /social/entra
    /social/entra/callback
    /social/entra/failure
  ).freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env["PATH_INFO"].to_s
    return @app.call(env) unless path.start_with?("/social/")

    surface = surface_for_host(Rack::Request.new(env).host)
    segment = path.delete_prefix("/social/").split("/", 2).first.presence

    if KNOWN_PROVIDERS.include?(segment)
      return not_found unless allowed?(surface: surface, provider: segment, path: path)
    else
      # Non-provider /social/* paths existed before this guard and are not
      # provider-specific; preserve the app-only behavior for them.
      return not_found unless surface == :app
    end

    @app.call(env)
  end

  private

  def allowed?(surface:, provider:, path:)
    case surface
    when :app
      APP_ALLOWED_PROVIDERS.include?(provider)
    when :org
      return false unless ORG_ALLOWED_PROVIDERS.include?(provider)

      ENTRA_ALLOWED_PATHS.any? { |allowed_path| path == allowed_path || path.start_with?("#{allowed_path}/") }
    else
      false
    end
  end

  ORG_HOST_ENV_KEYS = %w(PUBLIC_AUTH_STAFF_URL PRIVATE_AUTH_STAFF_URL).freeze
  COM_HOST_ENV_KEYS = %w(
    PUBLIC_AUTH_CORPORATE_URL PRIVATE_AUTH_CORPORATE_URL
    PUBLIC_BASE_CORPORATE_URL PRIVATE_BASE_CORPORATE_URL
  ).freeze

  def surface_for_host(host)
    boot_hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    return :org if host == boot_hosts.auth_staff.host || env_host_match?(ORG_HOST_ENV_KEYS, host)

    com_hosts = [boot_hosts.sign_corporate.host, boot_hosts.auth_corporate.host, boot_hosts.base_corporate.host]
    return :com if com_hosts.include?(host) || env_host_match?(COM_HOST_ENV_KEYS, host)

    :app
  end

  def env_host_match?(keys, host)
    keys.any? do |key|
      value = ENV.fetch(key, nil)
      next false if value.blank?

      ConfigValues.build(value, allow_localhost: !Rails.env.production?).uri&.host == host
    end
  rescue StandardError
    false
  end

  def not_found
    [404, { "Content-Type" => "text/plain" }, ["Not Found"]]
  end
end

class OmniAuthSocialOriginSanitizer
  AUTH_PATH_PREFIXES = %w(/social/google /social/apple /social/entra).freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    if auth_request_path?(env["PATH_INFO"])
      env.delete("HTTP_REFERER")
    end

    @app.call(env)
  end

  private

  def auth_request_path?(path)
    AUTH_PATH_PREFIXES.any? { |prefix| path.to_s.start_with?(prefix) }
  end
end

Rails.application.config.middleware.use(OmniAuthSocialOriginSanitizer)
Rails.application.config.middleware.use(OmniAuthSocialProviderHostMatrix)
Rails.application.config.middleware.use(OmniAuth::Builder) do
  # ---------------------------------------------------------------------------
  # Google OAuth2 - App (user sign-in/sign-up)
  # ---------------------------------------------------------------------------
  # Callback: GET /social/google/callback
  provider :google_oauth2,
           google_client_id,
           google_client_secret,
           {
             name: "google",
             callback_path: "/social/google/callback",
             scope: "openid",
             access_type: "online",
             prompt: "select_account",
             pkce: true,
             skip_info: true,
           }

  # ---------------------------------------------------------------------------
  # Apple Sign In
  # ---------------------------------------------------------------------------
  # Uses OIDC code flow. Callback: GET /social/apple/callback
  #
  # Required credentials:
  # - CLIENT_ID: Service ID (e.g., "com.example.app.web")
  # - TEAM_ID: Apple Developer Team ID (10 chars)
  # - KEY_ID: Key ID from Apple Developer (10 chars)
  # - PRIVATE_KEY: Contents of .p8 file (including BEGIN/END markers)
  provider :apple,
           apple_client_id,
           "", # Secret is derived from private key, not passed here
           {
             # OmniAuth standard callback path
             callback_path: "/social/apple/callback",
             # IMPORTANT: We authenticate by provider+uid only, NOT email
             # Empty scope means we only get the user identifier (sub claim in id_token)
             scope: "",
             team_id: apple_team_id,
             key_id: apple_key_id,
             pem: apple_pem,
             # Required: omniauth-apple's client_id method returns nil during callback
             # unless the aud from id_token is listed in authorized_client_ids
             authorized_client_ids: [apple_client_id],
             pkce: true,
             # The app validates its own social state in the callback controller.
             provider_ignores_state: true,
             authorize_params: {
               response_mode: "query",
               response_type: "code",
             },
           }

  # ---------------------------------------------------------------------------
  # Microsoft Entra ID - Org (staff) sign-in only, no JIT provisioning
  # ---------------------------------------------------------------------------
  # Umaxica-specific subclass of omniauth_openid_connect
  # (lib/omniauth/strategies/umaxica_entra.rb). Single tenant: the tenant id
  # and client id come from ProviderRegistry, which reads the credentials the
  # registry entry names, and the strategy applies the tenant-fixed endpoints
  # per request. Callback: GET /social/entra/callback.
  #
  # Local boots without a secret skip this provider so publishing tests do not
  # depend on Entra credentials. Production still required the secret above.
  if entra_client_secret
    provider :umaxica_entra,
             {
               name: "entra",
               callback_path: "/social/entra/callback",
               response_type: "code",
               response_mode: "query",
               scope: %i(openid profile),
               send_nonce: true,
               pkce: true,
               discovery: false,
               client_options: { secret: entra_client_secret },
             }
  end
end

# OmniAuth request phase accepts only the Rails authenticity-token-protected form submission.
# Callback state validation is enforced by SocialCallbackGuard and CallbackStateStore.
OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.after_request_phase = proc { |env| SocialCallbackGuard.capture_request_state!(env) }

# =============================================================================
# Failure Handling
# =============================================================================
# Redirect to our custom failure endpoint.
# This uses OmniAuth standard path: /social/failure
OmniAuth.config.on_failure =
  proc do |env|
    request = Rack::Request.new(env)
    message = env["omniauth.error.type"]&.to_s || "unknown_error"
    strategy = env["omniauth.error.strategy"]&.name || "unknown"

    # Provider exception messages can contain response bodies or credentials;
    # retain only allowlisted classification metadata.
    error = env["omniauth.error"]
    if error
      Rails.logger.error(
        JitLogEvent.format(
          "social_auth.failure",
          strategy: strategy,
          type: message,
          error_class: error.class.name,
        ),
      )
    end

    if strategy == "apple"
      Rails.logger.info(
        JitLogEvent.format(
          "social_auth.apple.nonce_failure_context",
          request_path: request.path,
          request_method: request.request_method,
          strategy_has_value: request.session["omniauth.nonce"].present?,
          app_has_value: request.session[:social_auth_nonce].present?,
          message: message,
        ),
      )
    end

    # Build failure URL with query parameters (OmniAuth standard path).
    # Entra (org surface) has its own failure endpoint; it must never redirect
    # to the app-surface /social/failure path.
    failure_path =
      if strategy == "entra"
        "/social/entra/failure?message=#{CGI.escape(message)}"
      else
        "/social/failure?message=#{CGI.escape(message)}&strategy=#{CGI.escape(strategy)}"
      end

    Rack::Response.new(["302 Found"], 302, "Location" => failure_path).finish
  end
