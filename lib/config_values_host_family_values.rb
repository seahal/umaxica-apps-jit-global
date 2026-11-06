# frozen_string_literal: true

module ConfigValues
  HostFamilyValues =
    Data.define(
      :acme_service,
      :acme_corporate,
      :acme_staff,
      :sign_service,
      :sign_corporate,
      :sign_staff,
      :core_service,
      :core_corporate,
      :core_staff,
      :base_service,
      :base_corporate,
      :base_staff,
      :visa_service,
      :visa_corporate,
      :visa_staff,
      :warp_service,
      :warp_corporate,
      :warp_staff,
      :palm_service,
      :docs_service,
      :docs_corporate,
      :docs_staff,
      :news_service,
      :news_corporate,
      :news_staff,
      :help_service,
      :help_corporate,
      :help_staff,
      :info_service,
      :info_corporate,
      :info_staff,
      :guid_service,
      :edit_staff,
      :tech_staff,
    ) do
      def acme_origins
        [acme_service, acme_corporate, acme_staff]
      end

      def sign_origins
        [sign_service, sign_corporate, sign_staff]
      end

      def core_origins
        [core_service, core_corporate, core_staff]
      end

      def auth_service = sign_service

      def auth_corporate = sign_corporate

      def auth_staff = sign_staff

      def auth_origins
        [auth_service, auth_corporate, auth_staff]
      end

      def warp_origins
        [warp_service, warp_corporate, warp_staff]
      end

      def base_origins
        [base_service, base_corporate, base_staff]
      end

      def base_for_resource_type(resource_type)
        case resource_type.to_s
        when "client" then base_service
        when "operator", "staff" then base_staff
        else raise ArgumentError, "unsupported Base authority resource type"
        end
      end

      def visa_origins
        [visa_service, visa_corporate, visa_staff]
      end

      def docs_origins
        [docs_service, docs_corporate, docs_staff]
      end

      def news_origins
        [news_service, news_corporate, news_staff]
      end

      def info_origins
        [info_service, info_corporate, info_staff]
      end
    end
end

ConfigValuesHostFamilyValues = ConfigValues::HostFamilyValues

class << ConfigValues::HostFamilyValues
  def build(env:, production:)
    ConfigValues::HostFamilyValues.new(**host_family_origins(env: env, production: production)).freeze
  end

  def host_family_origins(env:, production:)
    host_family_primary_origins(env: env, production: production).merge(
      host_family_secondary_origins(env: env, production: production),
    )
  end

  def host_family_primary_origins(env:, production:)
    {
      acme_service: origin(env, acme_key(env, "SERVICE"), production: production),
      acme_corporate: origin(env, acme_key(env, "CORPORATE"), production: production),
      acme_staff: origin(env, acme_key(env, "STAFF"), production: production),
      sign_service: origin(env, auth_key(env, "SERVICE"), production: production),
      sign_corporate: origin(env, auth_key(env, "CORPORATE"), production: production),
      sign_staff: origin(env, auth_key(env, "STAFF"), production: production),
      core_service: origin(env, core_key(env, "SERVICE"), production: production),
      core_corporate: origin(env, core_key(env, "CORPORATE"), production: production),
      core_staff: origin(env, core_key(env, "STAFF"), production: production),
      base_service: origin(env, base_key(env, "SERVICE"), production: production),
      base_corporate: origin(env, base_key(env, "CORPORATE"), production: production),
      base_staff: origin(env, base_key(env, "STAFF"), production: production),
      visa_service: origin(env, visa_key(env, "SERVICE"), production: production),
      visa_corporate: origin(env, visa_key(env, "CORPORATE"), production: production),
      visa_staff: origin(env, visa_key(env, "STAFF"), production: production),
    }
  end

  def host_family_secondary_origins(env:, production:)
    {
      warp_service: origin(env, warp_key(env, "SERVICE"), production: production),
      warp_corporate: origin(env, warp_key(env, "CORPORATE"), production: production),
      warp_staff: origin(env, warp_key(env, "STAFF"), production: production),
      palm_service: origin(env, palm_key(env), production: production),
      tech_staff: required_origin(env, "PUBLIC_TECH_STAFF_URL", production: production),
      help_service: origin(env, help_key(env, "SERVICE"), production: production),
      help_corporate: origin(env, help_key(env, "CORPORATE"), production: production),
      help_staff: origin(env, help_key(env, "STAFF"), production: production),
      info_service: origin(env, info_key(env, "SERVICE"), production: production),
      info_corporate: origin(env, info_key(env, "CORPORATE"), production: production),
      info_staff: origin(env, info_key(env, "STAFF"), production: production),
    }.merge(host_family_content_origins(env: env, production: production))
      .merge(host_family_utility_origins(env: env, production: production))
  end

  def host_family_content_origins(env:, production:)
    {
      docs_service: origin(env, "PRIVATE_DOCS_SERVICE_URL", production: production),
      docs_corporate: origin(env, "PRIVATE_DOCS_CORPORATE_URL", production: production),
      docs_staff: origin(env, "PRIVATE_DOCS_STAFF_URL", production: production),
      news_service: origin(env, "PRIVATE_NEWS_SERVICE_URL", production: production),
      news_corporate: origin(env, "PRIVATE_NEWS_CORPORATE_URL", production: production),
      news_staff: origin(env, "PRIVATE_NEWS_STAFF_URL", production: production),
    }
  end

  def host_family_utility_origins(env:, production:)
    {
      guid_service: origin(env, guid_key(env), production: production),
      edit_staff: origin(env, edit_key(env), production: production),
    }
  end

  # Resolves the ENV key for a base surface (service/corporate/staff).
  def base_key(env, surface)
    if env.key?("BASE_#{surface}_URL")
      "BASE_#{surface}_URL"
    else
      "PUBLIC_BASE_#{surface}_URL"
    end
  end

  # ACME is the internal Base back-channel origin. Prefer its explicit private
  # host; retain the existing surface key for deployments that still provide it.
  def acme_key(env, surface)
    private_key = "PRIVATE_BASE_#{surface}_URL"
    env.key?(private_key) ? private_key : "BASE_#{surface}_URL"
  end

  # Palm is a browser-facing RP. Prefer its public host; retain the existing
  # service key for deployments that still provide it.
  def palm_key(env)
    public_key = "PUBLIC_PALM_SERVICE_URL"
    env.key?(public_key) ? public_key : "PALM_SERVICE_URL"
  end

  # Help and Info origins use the private ingress in development. The old
  # unprefixed keys remain accepted when they are the configured input.
  def help_key(env, surface)
    private_key = "PRIVATE_HELP_#{surface}_URL"
    env.key?(private_key) ? private_key : "HELP_#{surface}_URL"
  end

  def info_key(env, surface)
    private_key = "PRIVATE_INFO_#{surface}_URL"
    env.key?(private_key) ? private_key : "INFO_#{surface}_URL"
  end

  # Resolves the Visa OP origin for a realm. Deployments may use the private
  # style key or the public style key; the former remains authoritative when
  # both are present, matching the existing Base contract.
  def visa_key(env, surface)
    if env.key?("VISA_#{surface}_URL")
      "VISA_#{surface}_URL"
    else
      "PUBLIC_VISA_#{surface}_URL"
    end
  end

  # Resolves the canonical PUBLIC_WARP input for a Warp surface.
  def warp_key(_env, surface)
    "PUBLIC_WARP_#{surface}_URL"
  end

  # Resolves the ENV key for an auth surface (service/corporate/staff).
  #
  # Deployments publish this family as PUBLIC_AUTH_*_URL. Selecting that key when
  # the legacy AUTH_*_URL input is absent keeps the CSP form-action allowlist aligned
  # with the deployed Auth origin, including outside RAILS_ENV=production.
  def auth_key(env, surface)
    if env.key?("AUTH_#{surface}_URL")
      "AUTH_#{surface}_URL"
    else
      "PUBLIC_AUTH_#{surface}_URL"
    end
  end

  # Resolves the ENV key for a core surface (service/corporate/staff).
  #
  # PUBLIC_CORE_*_URL wins over CORE_*_URL, which is the reverse of base_key/warp_key/auth_key.
  # config/routes/core.rb constrains the Core surfaces on
  # `ENV["PUBLIC_CORE_*_URL"] || ENV["CORE_*_URL"]`, so the host Rails answers on already
  # prefers the PUBLIC value. Boot config feeds production Host Authorization and the
  # Core redirect URIs, both of which must name the host the route constraint accepts;
  # taking the opposite precedence would let a deployment that sets both keys route on one host
  # while registering a callback for the other.
  def core_key(env, surface)
    if env.key?("PUBLIC_CORE_#{surface}_URL")
      "PUBLIC_CORE_#{surface}_URL"
    else
      "CORE_#{surface}_URL"
    end
  end

  def guid_key(env)
    env.key?("GUID_SERVICE_URL") ? "GUID_SERVICE_URL" : "PUBLIC_GUID_SERVICE_URL"
  end

  def edit_key(env)
    env.key?("EDIT_STAFF_URL") ? "EDIT_STAFF_URL" : "PUBLIC_EDIT_STAFF_URL"
  end

  def origin(env, key, production:)
    raw = env.fetch(key)
    allow_localhost = !production
    uri = raw.to_s.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: allow_localhost)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end

  # Tech's host is required in every environment.
  def required_origin(env, key, production:)
    raw = env.fetch(key)
    allow_localhost = !production
    uri = raw.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: allow_localhost)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end

  private :host_family_origins, :host_family_primary_origins, :host_family_secondary_origins,
          :host_family_content_origins, :host_family_utility_origins, :acme_key, :guid_key, :edit_key,
          :help_key, :info_key, :palm_key, :required_origin, :visa_key
end
