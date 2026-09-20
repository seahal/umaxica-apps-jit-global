# frozen_string_literal: true

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

  private_class_method :validate_origin_uri!, :sanitize_origin_uri!
end

ConfigValuesOriginValue = ConfigValues::OriginValue
