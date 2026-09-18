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
      :side_service,
      :side_corporate,
      :side_staff,
      :palm_service,
      :palm_corporate,
      :palm_staff,
      :help_service,
      :help_corporate,
      :help_staff,
      :info_service,
      :info_corporate,
      :info_staff,
      :guid_service,
      :edit_staff,
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

      def side_origins
        [side_service, side_corporate, side_staff]
      end

      def base_origins
        [base_service, base_corporate, base_staff]
      end

      def palm_origins
        [palm_service, palm_corporate, palm_staff]
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

  def development_host(production, host)
    production ? nil : host
  end

  def host_family_primary_origins(env:, production:)
    {
      acme_service: origin(
        env, "BASE_SERVICE_URL", development_host(production, "base.app.localhost"),
        production: production,
      ),
      acme_corporate: origin(
        env, "BASE_CORPORATE_URL", development_host(production, "base.com.localhost"), production: production,
      ),
      acme_staff: origin(
        env, "BASE_STAFF_URL", development_host(production, "base.org.localhost"),
        production: production,
      ),
      sign_service: origin(
        env, auth_key(env, "SERVICE"), development_host(production, "sign.app.localhost"), production: production,
      ),
      sign_corporate: origin(
        env, auth_key(env, "CORPORATE"), development_host(production, "sign.com.localhost"), production: production,
      ),
      sign_staff: origin(
        env, auth_key(env, "STAFF"), development_host(production, "sign.org.localhost"), production: production,
      ),
      core_service: origin(
        env, core_key(env, "SERVICE"), development_host(production, "jpx.umaxica.app"), production: production,
      ),
      core_corporate: origin(
        env, core_key(env, "CORPORATE"), development_host(production, "jpx.umaxica.com"), production: production,
      ),
      core_staff: origin(
        env, core_key(env, "STAFF"), development_host(production, "jpx.umaxica.org"),
        production: production,
      ),
      base_service: origin(
        env, base_key(env, "SERVICE"), development_host(production, "www.umaxica.app"), production: production,
      ),
      base_corporate: origin(
        env, base_key(env, "CORPORATE"), development_host(production, "www.umaxica.com"), production: production,
      ),
      base_staff: origin(
        env, base_key(env, "STAFF"), development_host(production, "www.umaxica.org"), production: production,
      ),
    }
  end

  def host_family_secondary_origins(env:, production:)
    {
      side_service: origin(
        env, side_key(env, "SERVICE"), development_host(production, "www-jp.umaxica.app"), production: production,
      ),
      side_corporate: origin(
        env, side_key(env, "CORPORATE"), development_host(production, "www-jp.umaxica.com"), production: production,
      ),
      side_staff: origin(
        env, side_key(env, "STAFF"), development_host(production, "www-jp.umaxica.org"), production: production,
      ),
      palm_service: origin(
        env, "PALM_SERVICE_URL", development_host(production, "palm-jp.umaxica.app"), production: production,
      ),
      palm_corporate: origin(
        env, "PALM_CORPORATE_URL", development_host(production, "palm-jp.umaxica.com"), production: production,
      ),
      palm_staff: origin(
        env, "PALM_STAFF_URL", development_host(production, "palm-jp.umaxica.org"),
        production: production,
      ),
      help_service: origin(
        env, "HELP_SERVICE_URL", development_host(production, "help.app.localhost"), production: production,
      ),
      help_corporate: origin(
        env, "HELP_CORPORATE_URL", development_host(production, "help.com.localhost"), production: production,
      ),
      help_staff: origin(
        env, "HELP_STAFF_URL", development_host(production, "help.org.localhost"),
        production: production,
      ),
      info_service: origin(
        env, "INFO_SERVICE_URL", development_host(production, "info.app.localhost"), production: production,
      ),
      info_corporate: origin(
        env, "INFO_CORPORATE_URL", development_host(production, "info.com.localhost"), production: production,
      ),
      info_staff: origin(
        env, "INFO_STAFF_URL", development_host(production, "info.org.localhost"),
        production: production,
      ),
    }.merge(host_family_utility_origins(env: env, production: production))
  end

  def host_family_utility_origins(env:, production:)
    {
      guid_service: origin(
        env, guid_key(env), development_host(production, "guid.net.localhost"), production: production,
      ),
      edit_staff: origin(
        env, edit_key(env), development_host(production, "edit.org.localhost"), production: production,
      ),
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

  # Resolves the ENV key for a side surface (service/corporate/staff).
  def side_key(env, surface)
    if env.key?("SIDE_#{surface}_URL")
      "SIDE_#{surface}_URL"
    else
      "PUBLIC_SIDE_#{surface}_URL"
    end
  end

  # Resolves the ENV key for an auth surface (service/corporate/staff).
  #
  # Deployments publish this family as PUBLIC_AUTH_*_URL. Without this fallback the
  # sign origins kept their development localhost defaults outside
  # RAILS_ENV=production, so the CSP form-action allowlist advertised
  # sign.app.localhost instead of the real Auth origin and blocked the social
  # ceremony handoff back to Auth.
  def auth_key(env, surface)
    if env.key?("AUTH_#{surface}_URL")
      "AUTH_#{surface}_URL"
    else
      "PUBLIC_AUTH_#{surface}_URL"
    end
  end

  # Resolves the ENV key for a core surface (service/corporate/staff).
  #
  # PUBLIC_CORE_*_URL wins over CORE_*_URL, which is the reverse of base_key/side_key/auth_key.
  # config/routes/core.rb constrains the Core surfaces on
  # `ENV["PUBLIC_CORE_*_URL"] || ENV["CORE_*_URL"]`, so the host Rails answers on already
  # prefers the PUBLIC value. Boot config feeds production Host Authorization and the
  # core-next-rp redirect URIs, both of which must name the host the route constraint accepts;
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

  def origin(env, key, fallback, production:)
    raw = production ? env.fetch(key) : env.fetch(key, fallback)
    allow_localhost = !production
    uri = raw.to_s.match?(%r{\Ahttps?://}) ? raw : "https://#{raw}"
    ConfigValues.build(uri, allow_localhost: allow_localhost)
  rescue KeyError
    raise KeyError, "Missing required ENV key: #{key}"
  end
end
