# typed: false
# frozen_string_literal: true

module JumpRtReturnPolicy
  module_function

  # Frozen directed graph of exactly twenty [source, destination] edges between logical Jump
  # issuer namespaces. Each namespace resolves to its origin through JumpRtSurface, so the graph
  # never depends on host shape and an environment's identities map onto the same edges.
  ALLOWED_EDGES = [
    %w(AUTH_APP BASE_APP), %w(AUTH_COM BASE_COM), %w(AUTH_ORG BASE_ORG),
    %w(BASE_APP AUTH_APP), %w(BASE_COM AUTH_COM), %w(BASE_ORG AUTH_ORG),
    %w(BASE_APP CORE_APP), %w(BASE_COM CORE_COM), %w(BASE_ORG CORE_ORG),
    %w(CORE_APP BASE_APP), %w(CORE_COM BASE_COM), %w(CORE_ORG BASE_ORG),
    %w(BASE_APP WARP_APP), %w(BASE_COM WARP_COM), %w(BASE_ORG WARP_ORG),
    %w(WARP_APP BASE_APP), %w(WARP_COM BASE_COM), %w(WARP_ORG BASE_ORG),
    %w(BASE_APP PALM_APP), %w(PALM_APP BASE_APP),
  ].map(&:freeze).freeze

  def allowed_source?(destination_origin:, source:)
    destination = namespace_for_origin(normalize_origin(destination_origin))
    source_namespace = namespace_for_origin(normalize_origin(source))
    return false if destination.nil? || source_namespace.nil?

    ALLOWED_EDGES.include?([source_namespace, destination])
  end

  # Configured origins must be pairwise distinct; an ambiguous identity is a configuration error,
  # not a reason to pick one namespace.
  def namespace_for_origin(origin)
    return nil if origin.nil?

    matches = JumpRtSurface::ISSUER_NAMESPACES.select { |namespace| JumpRtSurface.issuer_origin(namespace) == origin }
    raise JumpRtConfigurationError,
          "Jump issuer origin #{origin} is configured for #{matches.join(", ")}" if matches.size > 1

    matches.first
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
