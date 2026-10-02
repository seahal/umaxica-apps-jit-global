# frozen_string_literal: true

require "ipaddr"
require "uri"

module ConfigValues
  OriginValue =
    Data.define(
      :scheme,
      :host,
      :port,
      :path,
      :query,
      :uri,
    ) do
      def to_s
        port_part = (port && port != default_port_for(scheme)) ? ":#{port}" : ""
        "#{scheme}://#{host}#{port_part}"
      end

      private

      def default_port_for(value)
        value.to_s.casecmp("https").zero? ? 443 : 80
      end
    end

  module_function

  def build(value, allow_localhost: false)
    raw = value.to_s.strip
    raise ArgumentError, "missing origin" if raw.blank?
    raise ArgumentError, "invalid origin" if raw.match?(/[\x00-\x1F\x7F]/)

    uri = URI.parse(normalize_origin(raw))
    validate_origin_uri!(uri, allow_localhost: allow_localhost)
    sanitize_origin_uri!(uri)
    OriginValue.new(uri.scheme, uri.host.downcase, uri.port, uri.path, uri.query, uri).freeze
  rescue URI::InvalidURIError
    raise ArgumentError, "invalid origin"
  end

  NON_PUBLIC_HOST_SUFFIXES = %w(.localhost .local .internal .test .example .invalid).freeze

  # Strict form for identities that cross the public internet (the Jump gateway and Jump issuer
  # origins). It never prepends a scheme, never permits http or localhost, and returns the
  # normalized "https://host" string. Raises ArgumentError naming what was rejected.
  def public_https_origin(value)
    raw = value.to_s
    raise ArgumentError, "missing origin" if raw.strip.empty?
    raise ArgumentError, "origin contains control characters" if raw.match?(/[\x00-\x1F\x7F]/)
    raise ArgumentError, "origin must use https" unless raw.match?(%r{\Ahttps://}i)

    uri = URI.parse(raw)
    raise ArgumentError, "origin must use https" unless uri.is_a?(URI::HTTPS)

    host = uri.hostname.to_s.downcase
    raise ArgumentError, "origin host is missing" if host.empty?
    raise ArgumentError, "origin must not contain userinfo" unless uri.userinfo.nil?
    raise ArgumentError, "origin must not contain a query" unless uri.query.nil?
    raise ArgumentError, "origin must not contain a fragment" unless uri.fragment.nil?
    raise ArgumentError, "origin must not contain a path" unless ["", "/"].include?(uri.path)
    raise ArgumentError, "origin must use the default https port" unless uri.port == 443 && !raw.match?(%r{\Ahttps://[^/]*:}i)

    validate_public_host!(host)
    "https://#{host}"
  rescue URI::InvalidURIError
    raise ArgumentError, "malformed origin"
  end

  def validate_public_host!(host)
    raise ArgumentError, "origin host must be a public DNS name" if ip_literal?(host)
    raise ArgumentError, "origin host must be a public DNS name" unless host.include?(".")
    raise ArgumentError, "origin host must be a public DNS name" if host.end_with?(".")
    raise ArgumentError, "origin host must be a public DNS name" if host == "localhost"
    return unless NON_PUBLIC_HOST_SUFFIXES.any? { |suffix| host.end_with?(suffix) }

    raise ArgumentError, "origin host must be a public DNS name"
  end

  def ip_literal?(host)
    IPAddr.new(host.delete_prefix("[").delete_suffix("]"))
    true
  rescue IPAddr::InvalidAddressError
    false
  end

  def validate_origin_uri!(uri, allow_localhost:)
    raise ArgumentError, "invalid origin" unless uri.is_a?(URI::HTTP)
    raise ArgumentError, "invalid origin" unless %w(http https).include?(uri.scheme)
    raise ArgumentError, "invalid origin" if uri.userinfo.present?
    raise ArgumentError, "invalid origin" if uri.host.blank?
    raise ArgumentError, "invalid origin" if uri.query.present?
    raise ArgumentError, "invalid origin" if uri.fragment.present?
    raise ArgumentError, "invalid origin" if uri.path.present? && uri.path != "/"
    raise ArgumentError, "invalid origin" if uri.host.include?(":") && uri.port.blank?

    return unless uri.scheme == "http"

    localhost = uri.host == "localhost" || uri.host.end_with?(".localhost")
    raise ArgumentError, "invalid origin" unless allow_localhost && localhost
  end

  def sanitize_origin_uri!(uri)
    uri.path = "/"
    uri.query = nil
    uri.fragment = nil
    uri.user = nil
    uri.password = nil
  end

  def normalize_origin(raw)
    return raw if raw.match?(%r{\Ahttps?://}i)

    "https://#{raw}"
  end

  private_class_method :validate_origin_uri!, :sanitize_origin_uri!, :validate_public_host!, :ip_literal?
end

ConfigValuesOriginValue = ConfigValues::OriginValue
