# typed: false
# frozen_string_literal: true

module JumpRtReturnPolicy
  module_function

  # The Rails-side Jump contract is a reviewable data table. `issuer_namespace` is the signing
  # identity, `destination_namespace` is the origin named by the signed URL, and `purpose` explains
  # why the edge exists. Origins are resolved only through JumpRtSurface; host spelling never
  # changes the graph.
  EDGE_CATALOG = [
    %w(AUTH_APP BASE_APP reauthentication_result),
    %w(AUTH_COM BASE_COM reauthentication_result),
    %w(AUTH_ORG BASE_ORG reauthentication_result),
    %w(BASE_APP AUTH_APP reauthentication_start),
    %w(BASE_COM AUTH_COM reauthentication_start),
    %w(BASE_ORG AUTH_ORG reauthentication_start),
    %w(AUTH_APP VISA_APP authentication_result),
    %w(AUTH_COM VISA_COM authentication_result),
    %w(AUTH_ORG VISA_ORG authentication_result),
    %w(VISA_APP AUTH_APP authentication_ceremony),
    %w(VISA_COM AUTH_COM authentication_ceremony),
    %w(VISA_ORG AUTH_ORG authentication_ceremony),
    %w(BASE_APP VISA_APP authorization_start),
    %w(BASE_COM VISA_COM authorization_start),
    %w(BASE_ORG VISA_ORG authorization_start),
    %w(CORE_APP VISA_APP authorization_start),
    %w(CORE_COM VISA_COM authorization_start),
    %w(CORE_ORG VISA_ORG authorization_start),
    %w(WARP_APP VISA_APP authorization_start),
    %w(WARP_COM VISA_COM authorization_start),
    %w(WARP_ORG VISA_ORG authorization_start),
    %w(PALM_APP VISA_APP authorization_start),
    %w(VISA_APP BASE_APP authorization_response),
    %w(VISA_COM BASE_COM authorization_response),
    %w(VISA_ORG BASE_ORG authorization_response),
    %w(VISA_APP CORE_APP authorization_response),
    %w(VISA_COM CORE_COM authorization_response),
    %w(VISA_ORG CORE_ORG authorization_response),
    %w(VISA_APP WARP_APP authorization_response),
    %w(VISA_COM WARP_COM authorization_response),
    %w(VISA_ORG WARP_ORG authorization_response),
    %w(VISA_APP PALM_APP authorization_response),
    %w(BASE_APP CORE_APP rp_switch),
    %w(BASE_COM CORE_COM rp_switch),
    %w(BASE_ORG CORE_ORG rp_switch),
    %w(CORE_APP BASE_APP rp_return),
    %w(CORE_COM BASE_COM rp_return),
    %w(CORE_ORG BASE_ORG rp_return),
    %w(BASE_APP WARP_APP rp_switch),
    %w(BASE_COM WARP_COM rp_switch),
    %w(BASE_ORG WARP_ORG rp_switch),
    %w(WARP_APP BASE_APP rp_return),
    %w(WARP_COM BASE_COM rp_return),
    %w(WARP_ORG BASE_ORG rp_return),
    %w(BASE_APP PALM_APP rp_switch),
    %w(PALM_APP BASE_APP rp_return),
  ].map do |issuer_namespace, destination_namespace, purpose|
    {
      issuer_namespace: issuer_namespace,
      destination_namespace: destination_namespace,
      purpose: purpose,
    }.freeze
  end.freeze

  # Frozen directed graph derived from the table above. Keep this projection because the runtime
  # verifier needs only the pair, while the catalog remains available to audits and handoffs.
  ALLOWED_EDGES = EDGE_CATALOG.map do |edge|
    [edge.fetch(:issuer_namespace), edge.fetch(:destination_namespace)].freeze
  end.freeze

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
