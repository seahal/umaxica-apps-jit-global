# typed: false
# frozen_string_literal: true

require "uri"

# Pre-deployment contract for the approved regional RP matrix.
#
# This value does not register clients or generate credentials. It only derives exact URI
# bindings from an existing canonical source and refuses to invent a host when that source is
# absent. The active seven-client registry remains the compatibility registry until every target
# caller, audience, key namespace, and RP-session binding has migrated.
module RegionalRpClientMatrix
  class MissingCanonicalHost < KeyError; end

  class MissingCanonicalAudience < KeyError; end

  class InvalidCanonicalRegistration < KeyError; end

  CALLBACK_PATH = "/oidc/callback"
  POST_LOGOUT_PATH = "/sign/out"
  BACKCHANNEL_LOGOUT_PATH = "/oidc/backchannel/logout"

  CLIENT_IDS = AuthBoundaryAuthorityMap.approved_rp_client_ids.freeze

  module_function

  def client_ids
    CLIENT_IDS
  end

  # Expected Base registry shape for the approved matrix. This is a repository contract only: it
  # names the source of each binding without inventing a host, audience, or credential and does not
  # activate a client in the compatibility registry.
  def expected_registry_contract
    CLIENT_IDS.map do |client_id|
      metadata = AuthBoundaryAuthorityMap.approved_rp_faces.fetch(client_id)

      {
        client_id:,
        surface: metadata.fetch(:surface),
        face: metadata.fetch(:face),
        region: metadata.fetch(:region),
        actor: metadata.fetch(:actor),
        canonical_host_source: canonical_host_source_for(metadata),
        audience_source: { client_id:, attribute: :aud }.freeze,
        jwt_namespace: jwt_namespace_for(client_id),
        rp_session_client_id: client_id,
      }.freeze
    end.freeze
  end

  def client_id_for(surface:, face:, region:)
    normalized_surface = surface.to_s
    normalized_face = face.to_s
    normalized_region = region.to_s
    match =
      CLIENT_IDS.find do |client_id|
        metadata = AuthBoundaryAuthorityMap.approved_rp_faces.fetch(client_id)
        next false if metadata.fetch(:region).blank?

        metadata.fetch(:surface) == normalized_surface &&
          metadata.fetch(:face) == normalized_face &&
          metadata.fetch(:region).to_s == normalized_region
      end
    return match if match

    raise ArgumentError, "unapproved regional RP cell: #{surface}/#{face}/#{region}"
  end

  # Returns the URI and local binding portion that can be derived without inventing an audience.
  # A caller that needs a complete OIDC registration must use `binding_for`, which fails closed
  # until the repository has one canonical regional audience source.
  def uri_binding_for(client_id)
    metadata =
      AuthBoundaryAuthorityMap.approved_rp_faces.fetch(client_id.to_s) do
        raise ArgumentError, "unapproved RP client: #{client_id}"
      end
    base_uri = canonical_base_uri_for(client_id.to_s, metadata)

    {
      client_id: client_id.to_s,
      surface: metadata.fetch(:surface),
      face: metadata.fetch(:face),
      region: metadata.fetch(:region),
      actor: metadata.fetch(:actor),
      jwt_namespace: jwt_namespace_for(client_id.to_s),
      rp_session_client_id: client_id.to_s,
      host: URI.parse(base_uri).host,
      redirect_uri: join_uri(base_uri, CALLBACK_PATH),
      post_logout_redirect_uri: join_uri(base_uri, POST_LOGOUT_PATH),
      backchannel_logout_uri: join_uri(base_uri, BACKCHANNEL_LOGOUT_PATH),
    }.freeze
  end

  def binding_for(client_id)
    uri_binding = uri_binding_for(client_id)
    registered_client = OidcClientRegistry.find(client_id)
    audience = registered_client&.aud.presence
    raise MissingCanonicalAudience, "no canonical audience for #{client_id}" if audience.blank?

    validate_registered_client!(registered_client, uri_binding, audience)

    uri_binding.merge(audience:).freeze
  end

  def validate_registered_client!(registered_client, uri_binding, audience)
    expected_client_id = uri_binding.fetch(:client_id)
    unless registered_client.client_id == expected_client_id
      raise InvalidCanonicalRegistration, "registry client ID mismatch for #{expected_client_id}"
    end

    unless registered_client.resource_type.to_s == uri_binding.fetch(:actor)
      raise InvalidCanonicalRegistration, "registry resource type mismatch for #{expected_client_id}"
    end

    unless registered_client.respond_to?(:private_key_jwt_client?) && registered_client.private_key_jwt_client?
      raise InvalidCanonicalRegistration, "registry auth method is not private_key_jwt for #{expected_client_id}"
    end

    expected_redirect_uri = uri_binding.fetch(:redirect_uri)
    registered_redirect_uris =
      registered_client.redirect_uris_by_realm.fetch(uri_binding.fetch(:actor), [])
    unless registered_redirect_uris.include?(expected_redirect_uri)
      raise InvalidCanonicalRegistration, "registry redirect URI mismatch for #{expected_client_id}"
    end

    unless registered_client.post_logout_redirect_uris.include?(uri_binding.fetch(:post_logout_redirect_uri))
      raise InvalidCanonicalRegistration, "registry post-logout URI mismatch for #{expected_client_id}"
    end

    unless registered_client.backchannel_logout_uris.include?(uri_binding.fetch(:backchannel_logout_uri))
      raise InvalidCanonicalRegistration, "registry backchannel URI mismatch for #{expected_client_id}"
    end

    unless registered_client.jwt_namespace == uri_binding.fetch(:jwt_namespace)
      raise InvalidCanonicalRegistration, "registry key namespace mismatch for #{expected_client_id}"
    end

    regional_audience_conflict =
      CLIENT_IDS.any? do |candidate_id|
        next false if candidate_id == expected_client_id

        candidate = OidcClientRegistry.find(candidate_id)
        candidate&.aud.present? && candidate.aud == audience
      end
    return unless regional_audience_conflict

    raise InvalidCanonicalRegistration, "regional audience is shared for #{expected_client_id}"
  end
  private_class_method :validate_registered_client!

  def jwt_namespace_for(client_id)
    metadata =
      AuthBoundaryAuthorityMap.approved_rp_faces.fetch(client_id.to_s) do
        raise ArgumentError, "unapproved RP client: #{client_id}"
      end
    return "EDIT_ORG" if client_id.to_s == "edit-org"

    surface_namespace = { "core" => "CORE", "warp" => "WARP" }.fetch(metadata.fetch(:surface))
    parts = [surface_namespace, metadata.fetch(:face), metadata.fetch(:region)]
    parts.compact!
    parts.map! { |part| part.to_s.upcase }
    parts
      .join("_")
  end

  def accepts_exact_cell?(client_id:, surface:, face:, region:)
    client_id.to_s == client_id_for(surface:, face:, region:)
  rescue ArgumentError
    false
  end

  def canonical_base_uri_for(client_id, metadata)
    case metadata.fetch(:surface)
    when "core"
      RegionalRootUrlRegistry.url_for(
        surface: metadata.fetch(:face).to_sym,
        region: metadata.fetch(:region),
      ) || raise(MissingCanonicalHost, "no canonical Core host for #{client_id}")
    when "warp"
      warp_host = canonical_warp_host_for(metadata)
      raise MissingCanonicalHost, "no canonical Warp host for #{client_id}" if warp_host.blank?

      normalize_origin(warp_host)
    when "edit"
      edit_host = ENV.fetch("PUBLIC_EDIT_STAFF_URL", nil).presence
      raise MissingCanonicalHost, "no canonical Edit host for #{client_id}" if edit_host.blank?

      normalize_origin(edit_host)
    else
      raise MissingCanonicalHost, "no regional host source for #{client_id}"
    end
  end
  private_class_method :canonical_base_uri_for

  def canonical_host_source_for(metadata)
    case metadata.fetch(:surface)
    when "core"
      :regional_root_url_registry
    when "warp"
      return :warp_boot_hosts if metadata.fetch(:region) == "jp"

      warp_env_key(metadata)
    when "edit"
      :public_edit_staff_url
    else
      raise MissingCanonicalHost, "no regional host source"
    end
  end
  private_class_method :canonical_host_source_for

  def warp_env_key(metadata)
    "PUBLIC_WARP_#{metadata.fetch(:face).upcase}_#{metadata.fetch(:region).upcase}_URL"
  end
  private_class_method :warp_env_key

  def canonical_warp_host_for(metadata)
    return ENV.fetch(warp_env_key(metadata), nil).presence unless metadata.fetch(:region) == "jp"

    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    host_method = {
      "app" => :warp_service,
      "com" => :warp_corporate,
      "org" => :warp_staff,
    }.fetch(metadata.fetch(:face))
    hosts.public_send(host_method).to_s.presence
  end
  private_class_method :canonical_warp_host_for

  def normalize_origin(value)
    origin = value.to_s
    origin = "https://#{origin}" unless origin.include?("://")
    parsed = URI.parse(origin)
    invalid_path = parsed.path.present? && parsed.path != "/"
    invalid_scheme = parsed.scheme != "http" && parsed.scheme != "https"
    has_userinfo = parsed.userinfo.present?
    has_suffix = parsed.query.present? || parsed.fragment.present?
    raise MissingCanonicalHost, "invalid canonical host source" if parsed.host.blank? || invalid_path ||
      invalid_scheme || has_userinfo || has_suffix

    parsed.path = "/"
    parsed.to_s
  rescue URI::InvalidURIError
    raise MissingCanonicalHost, "invalid canonical host source"
  end
  private_class_method :normalize_origin

  def join_uri(base_uri, path)
    URI.join(base_uri, path).to_s
  rescue URI::InvalidURIError
    raise MissingCanonicalHost, "invalid canonical host source"
  end
  private_class_method :join_uri
end
