# typed: false
# frozen_string_literal: true

module JumpRtReturnPolicy
  module_function

  ALLOWED_SOURCES = {
    "https://www.umaxica.app" => %w(https://auth.umaxica.app https://www.umaxica.app),
    "https://www.umaxica.com" => %w(https://auth.umaxica.com https://www.umaxica.com),
    "https://www.umaxica.org" => %w(https://auth.umaxica.org https://www.umaxica.org),
    "https://jpx.umaxica.app" => %w(https://jpx.umaxica.app),
    "https://jpx.umaxica.com" => %w(https://jpx.umaxica.com),
    "https://jpx.umaxica.org" => %w(https://jpx.umaxica.org),
    "https://www.jp.umaxica.app" => %w(https://auth.umaxica.app https://www.jp.umaxica.app),
    "https://www.jp.umaxica.com" => %w(https://auth.umaxica.com https://www.jp.umaxica.com),
    "https://www.jp.umaxica.org" => %w(https://auth.umaxica.org https://www.jp.umaxica.org),
  }.freeze

  def allowed_source?(destination_origin:, source:)
    sources = allowed_sources.fetch(normalize_origin(destination_origin), [])
    sources.include?(normalize_origin(source))
  end

  def allowed_sources
    ALLOWED_SOURCES.merge(env_allowed_sources) do |_origin, left, right|
      (left + right).uniq
    end
  end

  def normalize_origin(value)
    uri = URI.parse(value.to_s)
    return nil unless uri.is_a?(URI::HTTP)
    return nil unless %w(http https).include?(uri.scheme)
    return nil if uri.host.blank?
    return nil if uri.userinfo.present?

    port = (uri.port && uri.port != default_port_for(uri.scheme)) ? ":#{uri.port}" : ""
    "#{uri.scheme.downcase}://#{uri.host.downcase}#{port}"
  rescue URI::InvalidURIError
    nil
  end

  def default_port_for(scheme)
    scheme.to_s.casecmp("https").zero? ? 443 : 80
  end

  def env_allowed_sources
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    env_base_and_core_sources(hosts).merge(env_sign_sources(hosts)).compact
  end

  def env_base_and_core_sources(hosts)
    {
      normalize_origin(hosts.base_service.to_s) => env_sources(
        destination_host: hosts.base_service.host, issuer_host: hosts.sign_service.host,
      ),
      normalize_origin(hosts.base_corporate.to_s) => env_sources(
        destination_host: hosts.base_corporate.host, issuer_host: hosts.sign_corporate.host,
      ),
      normalize_origin(hosts.base_staff.to_s) => env_sources(
        destination_host: hosts.base_staff.host, issuer_host: hosts.sign_staff.host,
      ),
      normalize_origin(hosts.core_service.to_s) => env_sources(
        destination_host: hosts.core_service.host, issuer_host: hosts.sign_service.host,
      ),
      normalize_origin(hosts.core_corporate.to_s) => env_sources(
        destination_host: hosts.core_corporate.host, issuer_host: hosts.sign_corporate.host,
      ),
      normalize_origin(hosts.core_staff.to_s) => env_sources(
        destination_host: hosts.core_staff.host, issuer_host: hosts.sign_staff.host,
      ),
    }
  end

  def env_sign_sources(hosts)
    {
      normalize_origin(hosts.sign_service.to_s) => env_sources(
        destination_host: hosts.sign_service.host, issuer_host: hosts.base_service.host,
      ),
      normalize_origin(hosts.sign_corporate.to_s) => env_sources(
        destination_host: hosts.sign_corporate.host, issuer_host: hosts.base_corporate.host,
      ),
      normalize_origin(hosts.sign_staff.to_s) => env_sources(
        destination_host: hosts.sign_staff.host, issuer_host: hosts.base_staff.host,
      ),
    }
  end

  def env_sources(destination_host:, issuer_host:)
    sources = [normalize_origin("https://#{issuer_host}"), normalize_origin("https://#{destination_host}")]
    sources.compact!
    sources.uniq!
    sources
  end
end
