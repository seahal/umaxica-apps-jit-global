# typed: false
# frozen_string_literal: true

require "concurrent"

module OidcClientRegistry
  class ClientNotFound < StandardError; end

  class InvalidRedirectUri < StandardError; end

  class ClientAuthenticationConfigurationError < StandardError; end

  DEFAULT_ALLOWED_SCOPES = %w(openid profile email).freeze

  ClientConfiguration =
    Data.define(
      :client_id, :client_secret, :redirect_uris, :redirect_uris_by_realm, :post_logout_redirect_uris,
      :aud, :resource_type,
      :name, :domains, :allowed_scopes, :registered_token_endpoint_auth_method,
      :metadata_token_endpoint_auth_method, :jwt_namespace, :required_operator_capability,
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
  AssertionAuthenticationResult =
    Data.define(:authenticated, :client, :step_up_claims_state, :step_up_expectation) do
      def authenticated? = authenticated

      def step_up_claims_present? = step_up_claims_state != :none
    end
  CLIENTS_MUTEX = Mutex.new
  CLIENTS_CACHE = Concurrent::AtomicReference.new(nil)

  module_function

  # @param client_id [String]
  # @return [ClientConfiguration, nil]
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

    ClientConfiguration.new(
      client_id: client_id.to_s,
      client_secret: resolve_secret_credential(client_id.to_s),
      redirect_uris: all_redirect_uris,
      redirect_uris_by_realm: redirect_uris_by_realm,
      post_logout_redirect_uris: (config[:post_logout_redirect_uris] || []).uniq,
      required_operator_capability: config[:required_operator_capability],
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
  # @return [ClientConfiguration]
  # @raise [ClientNotFound]
  def find!(client_id)
    find(client_id) || raise(ClientNotFound, "Unknown OIDC client: #{client_id}")
  end

  # @param client_id [String]
  # @param uri [String]
  # @param resource_type [String, nil] when given, the redirect_uri must be registered for this
  #   realm (client/operator) specifically, not merely registered anywhere for the client.
  # @return [Boolean]
  def valid_redirect_uri?(client_id, uri, resource_type: nil)
    client = find(client_id)

    OidcRedirectUriPolicy.valid_redirect_uri?(client, uri, resource_type: resource_type)
  end

  def valid_post_logout_redirect_uri?(client_id:, uri:, resource_type:)
    client = find(client_id)
    return false unless OidcRedirectUriPolicy.valid_post_logout_redirect_uri?(client, uri)

    normalize_resource_type(client.resource_type) == normalize_resource_type(resource_type)
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
    verify_client_assertion(client_id, assertion, token_url:).authenticated?
  end

  def verify_client_assertion(client_id, assertion, token_url:)
    client = find(client_id)
    unless client&.private_key_jwt_client?
      return AssertionAuthenticationResult.new(
        authenticated: false, client: nil, step_up_claims_state: :none, step_up_expectation: nil,
      )
    end

    verification = OidcClientAssertionJwt.verify(client_id:, assertion:, token_url:)
    AssertionAuthenticationResult.new(
      authenticated: verification.authenticated?,
      client: verification.authenticated? ? client : nil,
      step_up_claims_state: verification.step_up_claims_state,
      step_up_expectation: verification.step_up_expectation,
    )
  end

  def jwt_namespace_for(client_id)
    find(client_id)&.jwt_namespace
  end

  def client_ids
    clients.keys
  end

  def validate_private_key_jwt_configuration!
    # An RP cell process holds only its own client key (RuntimeRole.rp_private_env_names).
    checked_ids =
      if RuntimeRole::RP_ROLES.include?(RuntimeRole.current)
        [RpCellBinding.fetch(RuntimeRole.cell_connection).client_id]
      else
        client_ids
      end
    missing =
      checked_ids.filter_map do |client_id|
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

  # RFC 8414 describes the methods supported by the revocation endpoint separately from the token
  # endpoint.  This application intentionally derives the set from the same registered client
  # contract used by the revoker; advertising a method that no registered client can use would make
  # discovery lie, while accepting an unregistered method would turn revocation into a guessing
  # oracle.
  def revocation_endpoint_auth_methods_for(resource_type)
    normalized_resource_type = normalize_resource_type(resource_type)

    result =
      clients.values.filter_map do |config|
        next unless normalize_resource_type(config[:resource_type]) == normalized_resource_type

        config[:token_endpoint_auth_method].presence
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
        visa_service visa_staff visa_corporate
        warp_service warp_staff warp_corporate
        core_service core_staff core_corporate
      ).map { |name| [name, hosts.public_send(name).to_s] }
    env_signature =
      %w(
        PUBLIC_AUTH_SERVICE_URL PUBLIC_AUTH_STAFF_URL PUBLIC_AUTH_CORPORATE_URL
        PRIVATE_AUTH_SERVICE_URL PRIVATE_AUTH_STAFF_URL PRIVATE_AUTH_CORPORATE_URL
        BASE_SERVICE_URL BASE_STAFF_URL BASE_CORPORATE_URL
        VISA_SERVICE_URL VISA_STAFF_URL VISA_CORPORATE_URL
        PUBLIC_VISA_SERVICE_URL PUBLIC_VISA_STAFF_URL PUBLIC_VISA_CORPORATE_URL
        PUBLIC_WARP_SERVICE_URL PUBLIC_WARP_STAFF_URL PUBLIC_WARP_CORPORATE_URL
        PUBLIC_EDIT_STAFF_URL
        PUBLIC_CORE_SERVICE_URL PUBLIC_CORE_STAFF_URL PUBLIC_CORE_CORPORATE_URL
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

  def redirect_uris_by_realm_for(config)
    return config[:redirect_uris_by_realm] if config[:redirect_uris_by_realm]

    { normalize_resource_type(config[:resource_type]) => Array(config[:redirect_uris]) }
  end

  def normalize_resource_type(resource_type)
    case resource_type.to_s
    when "operator", "staff" then "operator"
    when "client" then "client"
    else raise ArgumentError, "unsupported OIDC resource type"
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
                       :normalize_resource_type, :metadata_auth_method, :normalize_allowed_scopes,
                       :normalize_host
end
