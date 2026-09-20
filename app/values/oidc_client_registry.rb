# typed: false
# frozen_string_literal: true

require "concurrent"

module OidcClientRegistry
  class ClientNotFound < StandardError; end

  class InvalidRedirectUri < StandardError; end

  class ClientAuthenticationConfigurationError < StandardError; end

  DEFAULT_ALLOWED_SCOPES = %w(openid profile email).freeze
  PALM_ALLOWED_SCOPES = (DEFAULT_ALLOWED_SCOPES + %w(palm.read)).freeze

  VisitorAccount =
    Data.define(
      :client_id, :client_secret, :redirect_uris, :redirect_uris_by_realm, :post_logout_redirect_uris,
      :aud, :resource_type,
      :name, :domains, :allowed_scopes, :registered_token_endpoint_auth_method,
      :metadata_token_endpoint_auth_method, :jwt_namespace, :backchannel_logout_uris,
      :backchannel_logout_session_required,
    ) do
      def public_client?
        registered_token_endpoint_auth_method == "none"
      end

      def confidential_client?
        !public_client?
      end

      def private_key_jwt_client?
        registered_token_endpoint_auth_method == "private_key_jwt"
      end
    end
  CLIENTS_MUTEX = Mutex.new
  CLIENTS_CACHE = Concurrent::AtomicReference.new(nil)

  module_function

  # @param client_id [String]
  # @return [VisitorAccount, nil]
  def find(client_id)
    config = clients[client_id.to_s]
    return nil unless config

    registered_auth_method = config[:token_endpoint_auth_method]
    # A realm may be configured from several ENV keys that resolve to the same host (the public and
    # private auth origins are identical outside production), so collapse repeats here rather than
    # letting every consumer see the same URI twice.
    redirect_uris_by_realm = redirect_uris_by_realm_for(config).transform_values(&:uniq)
    all_redirect_uris = redirect_uris_by_realm.values.flatten
    all_redirect_uris.uniq!

    VisitorAccount.new(
      client_id: client_id.to_s,
      client_secret: resolve_secret_credential(client_id.to_s),
      redirect_uris: all_redirect_uris,
      redirect_uris_by_realm: redirect_uris_by_realm,
      post_logout_redirect_uris: (config[:post_logout_redirect_uris] || []).uniq,
      backchannel_logout_uris: (config[:backchannel_logout_uris] || []).uniq,
      backchannel_logout_session_required: config.fetch(:backchannel_logout_session_required, false),
      aud: config[:aud],
      resource_type: config[:resource_type],
      name: config[:name],
      domains: domains_from_redirect_uris(all_redirect_uris),
      allowed_scopes: normalize_allowed_scopes(config.fetch(:allowed_scopes, DEFAULT_ALLOWED_SCOPES)),
      registered_token_endpoint_auth_method: registered_auth_method,
      metadata_token_endpoint_auth_method: registered_auth_method || metadata_auth_method(client_id.to_s),
      jwt_namespace: config[:jwt_namespace],
    )
  end

  # @param client_id [String]
  # @return [VisitorAccount]
  # @raise [ClientNotFound]
  def find!(client_id)
    find(client_id) || raise(ClientNotFound, "Unknown OIDC client: #{client_id}")
  end

  # @param client_id [String]
  # @param uri [String]
  # @param resource_type [String, nil] when given, the redirect_uri must be registered for this
  #   realm (client/operator/visitor) specifically, not merely registered anywhere for the client.
  # @return [Boolean]
  def valid_redirect_uri?(client_id, uri, resource_type: nil)
    client = find(client_id)

    OidcRedirectUriPolicy.valid_redirect_uri?(client, uri, resource_type: resource_type)
  end

  def valid_post_logout_redirect_uri?(client_id:, uri:, resource_type:)
    client = find(client_id)
    return false unless OidcRedirectUriPolicy.valid_post_logout_redirect_uri?(client, uri)

    # Registered post_logout URIs mix all three realms in one list; a logout on
    # one surface must not redirect to another surface's host.
    logout_uri_resource_type(uri) == normalize_resource_type(resource_type)
  end

  def backchannel_logout_uris_for(client_id:, resource_type: nil)
    filter_logout_uris(find(client_id)&.backchannel_logout_uris || [], resource_type)
  end

  def logout_clients_for_resource_type(resource_type)
    clients.filter_map do |client_id, config|
      next if filter_logout_uris(Array(config[:backchannel_logout_uris]), resource_type).blank?

      find(client_id)
    end
  end

  # @param client_id [String]
  # @param secret_credential [String]
  # @return [Boolean]
  def authenticate(client_id, secret_credential)
    client = find(client_id)
    return false unless client
    return false if client.client_secret.blank? || secret_credential.blank?

    ActiveSupport::SecurityUtils.secure_compare(client.client_secret, secret_credential)
  end

  def authenticate_assertion(client_id, assertion, token_url:)
    client = find(client_id)
    return false unless client&.private_key_jwt_client?

    OidcClientAssertionJwt.valid?(client_id: client_id, assertion: assertion, token_url: token_url)
  end

  def jwt_namespace_for(client_id)
    find(client_id)&.jwt_namespace
  end

  def client_ids
    clients.keys
  end

  def validate_private_key_jwt_configuration!
    missing =
      client_ids.filter_map do |client_id|
        client = find(client_id)
        next unless client&.private_key_jwt_client?
        next if client.jwt_namespace.present? &&
          JitSecurityJwtRegistry.private_key_for("oidc_client:#{client.jwt_namespace}").present?

        "#{client.client_id}(#{client.jwt_namespace.presence || "missing_namespace"})"
      end

    return true if missing.empty?

    raise ClientAuthenticationConfigurationError,
          "private_key_jwt OIDC clients are missing signing keys: #{missing.join(", ")}"
  end

  def audiences_for_resource_type(resource_type)
    normalized_resource_type = normalize_resource_type(resource_type)

    result =
      clients.values.filter_map do |config|
        next unless normalize_resource_type(config[:resource_type]) == normalized_resource_type

        config[:aud]
      end
    result.uniq!
    result
  end

  def normalize_allowed_scopes(allowed_scopes)
    Array(allowed_scopes).map(&:to_s).freeze
  end

  # --- private ---

  def clients
    cached_clients = CLIENTS_CACHE.get
    signature = client_config_signature
    return cached_clients.fetch(:clients) if cached_clients&.fetch(:signature, nil) == signature

    CLIENTS_MUTEX.synchronize do
      cached_clients = CLIENTS_CACHE.get
      return cached_clients.fetch(:clients) if cached_clients&.fetch(:signature, nil) == signature

      begin
        built_clients = build_clients
        CLIENTS_CACHE.set({ signature: signature, clients: built_clients }.freeze)
        built_clients
      end
    end
  end

  def client_config_signature
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    boot_signature =
      %i(
        sign_service sign_staff sign_corporate
        base_service base_staff base_corporate
        side_service side_staff side_corporate
        core_service core_staff core_corporate
      ).map { |name| [name, hosts.public_send(name).to_s] }
    env_signature =
      %w(
        PUBLIC_AUTH_SERVICE_URL PUBLIC_AUTH_STAFF_URL PUBLIC_AUTH_CORPORATE_URL
        PRIVATE_AUTH_SERVICE_URL PRIVATE_AUTH_STAFF_URL PRIVATE_AUTH_CORPORATE_URL
        BASE_SERVICE_URL BASE_STAFF_URL BASE_CORPORATE_URL
        SIDE_SERVICE_URL SIDE_STAFF_URL SIDE_CORPORATE_URL
        CORE_SERVICE_URL CORE_STAFF_URL CORE_CORPORATE_URL
      ).map { |name| [name, ENV.fetch(name, nil)] }

    (boot_signature + env_signature).freeze
  end

  def build_clients
    OidcClientStoresStaticClientStore.clients
  end

  def resolve_secret_credential(client_id)
    OidcClientSecretResolver.resolve(client_id)
  end

  # This method is metadata/diagnostic-only. It must not be used for token endpoint authentication
  # or authorization decisions.
  def metadata_auth_method(_client_id)
    "client_secret_post"
  end

  def domains_from_redirect_uris(redirect_uris)
    result = redirect_uris.filter_map { |uri| URI.parse(uri).host.presence }
    result.uniq!
    result
  rescue URI::InvalidURIError
    []
  end

  def filter_logout_uris(uris, resource_type)
    return uris if resource_type.blank?

    normalized_resource_type = normalize_resource_type(resource_type)
    uris.select do |uri|
      logout_uri_resource_type(uri) == normalized_resource_type
    end
  end

  def logout_uri_resource_type(uri)
    host = URI.parse(uri.to_s).host.to_s
    return "operator" if logout_hosts_for("operator").include?(host)
    return "visitor" if logout_hosts_for("visitor").include?(host)

    "client"
  rescue URI::InvalidURIError
    nil
  end

  def logout_hosts_for(resource_type)
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    case normalize_resource_type(resource_type)
    when "operator"
      [
        normalize_host(hosts.sign_staff),
        normalize_host(hosts.auth_staff),
        normalize_host(hosts.core_staff),
        normalize_host(ENV.fetch("PRIVATE_AUTH_STAFF_URL", nil)),
        normalize_host(ENV.fetch("PUBLIC_AUTH_STAFF_URL", nil)),
      ].compact_blank.uniq
    when "visitor"
      [
        normalize_host(hosts.sign_corporate),
        normalize_host(hosts.auth_corporate),
        normalize_host(hosts.core_corporate),
        normalize_host(ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", nil)),
        normalize_host(ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", nil)),
      ].compact_blank.uniq
    else
      [
        normalize_host(hosts.sign_service),
        normalize_host(hosts.auth_service),
        normalize_host(hosts.core_service),
        normalize_host(ENV.fetch("PRIVATE_AUTH_SERVICE_URL", nil)),
        normalize_host(ENV.fetch("PUBLIC_AUTH_SERVICE_URL", nil)),
      ].compact_blank.uniq
    end
  end

  def redirect_uris_by_realm_for(config)
    return config[:redirect_uris_by_realm] if config[:redirect_uris_by_realm]

    { normalize_resource_type(config[:resource_type]) => Array(config[:redirect_uris]) }
  end

  def normalize_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff" then "operator"
    when "visitor", "customer" then "visitor"
    else "client"
    end
  end

  def normalize_host(host)
    parsed_host = URI.parse(host.to_s).host if host.to_s.include?("://")
    parsed_host.presence || URI.parse("//#{host}").host.to_s.presence || host.to_s
  rescue URI::InvalidURIError
    host.to_s
  end

  private_class_method :clients, :build_clients, :client_config_signature,
                       :resolve_secret_credential, :domains_from_redirect_uris,
                       :redirect_uris_by_realm_for,
                       :filter_logout_uris, :logout_uri_resource_type, :logout_hosts_for,
                       :normalize_resource_type, :metadata_auth_method, :normalize_allowed_scopes,
                       :normalize_host
end
