# typed: false
# frozen_string_literal: true

module JumpRtReturnPolicy
  module_function

  # Directed, destination-indexed graph. An RP is approved explicitly, never by host shape.
  ALLOWED_SOURCES = {
    "https://auth.umaxica.app" => %w(https://www.umaxica.app).freeze,
    "https://auth.umaxica.com" => %w(https://www.umaxica.com).freeze,
    "https://auth.umaxica.org" => %w(https://www.umaxica.org).freeze,
    "https://www.umaxica.app" => %w(
      https://auth.umaxica.app https://jp.umaxica.app https://www-jp.umaxica.app https://palm-jp.umaxica.app
    ).freeze,
    "https://www.umaxica.com" => %w(
      https://auth.umaxica.com https://jp.umaxica.com https://www-jp.umaxica.com
    ).freeze,
    "https://www.umaxica.org" => %w(
      https://auth.umaxica.org https://jp.umaxica.org https://www-jp.umaxica.org
    ).freeze,
    "https://jp.umaxica.app" => %w(https://www.umaxica.app).freeze,
    "https://jp.umaxica.com" => %w(https://www.umaxica.com).freeze,
    "https://jp.umaxica.org" => %w(https://www.umaxica.org).freeze,
    "https://www-jp.umaxica.app" => %w(https://www.umaxica.app).freeze,
    "https://www-jp.umaxica.com" => %w(https://www.umaxica.com).freeze,
    "https://www-jp.umaxica.org" => %w(https://www.umaxica.org).freeze,
    "https://palm-jp.umaxica.app" => %w(https://www.umaxica.app).freeze,
  }.freeze

  def allowed_source?(destination_origin:, source:)
    destination = JitSecurityJwtRegistry.canonical_jump_origin(normalize_origin(destination_origin))
    source_origin = JitSecurityJwtRegistry.canonical_jump_origin(normalize_origin(source))
    sources = allowed_sources.fetch(destination, [])
    sources.include?(source_origin)
  end

  def allowed_sources
    ALLOWED_SOURCES
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
end
