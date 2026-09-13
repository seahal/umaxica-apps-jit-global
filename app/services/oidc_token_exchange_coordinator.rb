# typed: false
# frozen_string_literal: true

class OidcTokenExchangeCoordinator < ApplicationService
  Result =
    Data.define(:success, :token_response, :error, :error_description) do
      def success? = success
    end

  def initialize(grant_type:, code:, redirect_uri:, client_id:, client_secret: nil, code_verifier:,
                 client_assertion_type: nil, client_assertion: nil,
                 dpop_proof: nil, token_endpoint_uri: nil, request_method: "POST")
    super()
    @grant_type = grant_type
    @code = code
    @redirect_uri = redirect_uri
    @client_id = client_id
    @client_secret = client_secret
    @client_assertion_type = client_assertion_type
    @client_assertion = client_assertion
    @code_verifier = code_verifier
    @dpop_proof = dpop_proof
    @token_endpoint_uri = token_endpoint_uri
    @request_method = request_method
  end

  def call
    return failure("invalid_request", "grant_type must be 'authorization_code'") unless valid_grant_type?
    return failure("invalid_client", "OIDC client authentication failed") unless authenticated_client?

    authorization_code = find_code
    return failure("invalid_grant", "Authorization code not found") unless authorization_code

    code_failure = validate_code(authorization_code)
    return code_failure if code_failure

    scope_failure = validate_authorized_scopes(authorization_code)
    return scope_failure if scope_failure

    pkce_failure = verify_pkce(authorization_code)
    return pkce_failure if pkce_failure

    dpop_jkt = validate_dpop_proof(authorization_code)
    return dpop_jkt if dpop_jkt.is_a?(Result)

    consume_and_issue_tokens!(authorization_code, dpop_jkt: dpop_jkt)
  end

  private

  attr_reader :grant_type, :code, :redirect_uri, :client_id, :client_secret, :client_assertion_type,
              :client_assertion, :code_verifier,
              :dpop_proof, :token_endpoint_uri, :request_method

  def valid_grant_type?
    grant_type == "authorization_code"
  end

  def authenticated_client?
    client = OidcClientRegistry.find(client_id)
    return false unless client

    return false if client_id.blank?

    # Dispatch strictly on the client's registered auth method (the SSOT). A
    # client must not be able to authenticate with a method it is not registered
    # for: a private_key_jwt client cannot fall back to client_secret, and a
    # secret client cannot present an assertion.
    case client.registered_token_endpoint_auth_method
    when "none"
      public_client_authenticated?
    when "private_key_jwt"
      return false if client_secret.present?

      authenticated_client_assertion?
    else
      # client_secret_post, or an unregistered method which is treated as a
      # confidential secret client (never a public/assertion client).
      return false if client_assertion.present? || client_assertion_type.present?

      OidcClientRegistry.authenticate(client_id, client_secret)
    end
  end

  def public_client_authenticated?
    client_secret.blank? && client_assertion.blank? && client_assertion_type.blank?
  end

  def authenticated_client_assertion?
    return false unless client_assertion_type == OidcClientAssertionJwt::ASSERTION_TYPE
    return false if token_endpoint_uri.blank?
    return false if client_assertion.blank?

    OidcClientRegistry.authenticate_assertion(
      client_id,
      client_assertion,
      token_url: token_endpoint_uri,
    )
  end

  def find_code
    OrgTicketRecord.connected_to(role: :writing) do
      OperatorAuthorizationCode.lock.find_by(code: code)
    end || ComTicketRecord.connected_to(role: :writing) do
      VisitorAuthorizationCode.lock.find_by(code: code)
    end || AppTicketRecord.connected_to(role: :writing) do
      ClientAuthorizationCode.lock.find_by(code: code)
    end
  end

  def validate_code(authorization_code)
    return failure("invalid_grant", "Authorization code expired") if authorization_code.expired?
    return failure("invalid_grant", "Authorization code already consumed") if authorization_code.consumed?
    return failure("invalid_grant", "Authorization code revoked") if authorization_code.revoked?
    return failure(
      "invalid_grant",
      "Authorization code is unbound",
    ) if root_token_from_authorization_code(authorization_code).blank?
    return failure("invalid_request", "redirect_uri mismatch") unless authorization_code.redirect_uri == redirect_uri
    return failure("invalid_request", "client_id mismatch") unless authorization_code.client_id == client_id
    return failure(
      "invalid_request",
      "redirect_uri is not registered for this authorization code's realm",
    ) unless OidcClientRegistry.valid_redirect_uri?(
      client_id, authorization_code.redirect_uri, resource_type: authorization_code.resource_type,
    )

    nil
  end

  def validate_authorized_scopes(authorization_code)
    client = OidcClientRegistry.find!(client_id)
    requested_scopes = authorization_code.scope.to_s.split
    invalid_scopes = requested_scopes - client.allowed_scopes

    return nil if requested_scopes.include?("openid") && invalid_scopes.empty?

    failure("invalid_grant", "Authorization code scope is invalid")
  end

  def verify_pkce(authorization_code)
    return failure("invalid_request", "code_verifier is required") if code_verifier.blank?
    return nil if authorization_code.verify_pkce(code_verifier)

    failure("invalid_request", "PKCE verification failed")
  end

  def consume_and_issue_tokens!(authorization_code, dpop_jkt: nil)
    client = OidcClientRegistry.find!(client_id)
    resource = authorization_code.resource
    return failure("invalid_grant", "resource is not active") unless resource&.active?

    connection_class = connection_class_for(authorization_code)

    # The transaction must be opened on the ticket connection, not on
    # ActiveRecord::Base. Authorization codes, token usages, and OIDC connection
    # records all live on the per-surface ticket database, while
    # ActiveRecord::Base is the primary (publishing) connection - so
    # `ActiveRecord::Base.transaction` wrapped none of the writes below, and the
    # `SELECT ... FOR UPDATE` taken by `lock!` committed and released
    # immediately. That left `consumed?` here and `consume!` further down as a
    # TOCTOU window in which one authorization code could be redeemed twice.
    connection_class.connected_to(role: :writing) do
      connection_class.transaction do
        authorization_code.lock!
        return failure("invalid_grant", "Authorization code expired") if authorization_code.expired?
        return failure("invalid_grant", "Authorization code already consumed") if authorization_code.consumed?
        return failure("invalid_grant", "Authorization code revoked") if authorization_code.revoked?

        root_token = root_token_from_authorization_code(authorization_code)
        return failure("invalid_grant", "Authorization code is unbound") unless root_token
        return failure("invalid_grant", "root session is not active") unless root_token.currently_usable?
        return failure("invalid_grant", "root session actor mismatch") unless root_token_actor_matches?(
          root_token,
          resource,
        )

        OidcConnectionRecorder.call(
          resource: resource,
          client: client,
          scope: authorization_code.scope,
          used_at: Time.current,
        )

        usage = create_or_resolve_active_usage!(
          root_token: root_token,
          client: client,
          scope: authorization_code.scope,
          dpop_jkt: dpop_jkt,
        )

        refresh_plain = issue_or_rotate_usage_refresh_token!(usage)
        authorization_code.consume!
        issue_exchanged_token_result(
          authorization_code: authorization_code,
          resource: resource,
          client: client,
          root_token: root_token,
          usage: usage,
          refresh_plain: refresh_plain,
          dpop_jkt: dpop_jkt,
        )
      end
    end
  end

  def create_or_resolve_active_usage!(root_token:, client:, scope:, dpop_jkt:)
    usage_class = usage_class_for_root_token(root_token)
    owner = connection_owner_for(usage_class)
    usage = nil

    owner.connected_to(role: :writing) do
      usage = usage_class.lock.find_by(
        parent_token_foreign_key_for(usage_class) => root_token.id,
        :oidc_client_id => client.client_id,
        :revoked_at => nil,
      )

      usage ||= usage_class.create!(
        parent_token_foreign_key_for(usage_class) => root_token,
        :oidc_client_id => client.client_id,
        :oidc_scope => scope,
        :oidc_jti => SecureRandom.uuid,
        :dpop_jkt => dpop_jkt,
        :last_used_at => Time.current,
        :refresh_token_expires_at => refresh_expires_at_for(root_token),
      )

      usage.update!(
        oidc_scope: scope,
        oidc_jti: SecureRandom.uuid,
        dpop_jkt: dpop_jkt,
        last_used_at: Time.current,
      )
      usage.public_send("#{parent_token_foreign_key_for(usage_class)}=", root_token)

      usage
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def issue_or_rotate_usage_refresh_token!(usage)
    usage.refresh_token_digest.present? ? usage.rotate_refresh_token! : usage.issue_refresh_token!
  end

  def token_usage_oidc_jti(usage)
    usage.oidc_jti.presence || raise(ArgumentError, "OIDC token usage is missing oidc_jti")
  end

  def issue_exchanged_token_result(authorization_code:, resource:, client:, root_token:, usage:, refresh_plain:,
                                   dpop_jkt:)
    now = Time.current.utc
    resource_type = resource_type_for(authorization_code)
    client = client_for_resource_type(client, resource_type)
    issuer = OidcIssuer.for_resource_type(resource_type)
    subject = OidcSubject.for(resource, resource_type: resource_type)
    access_expires_at = session_token_expiry(now, root_token)
    Result.new(
      success: true,
      token_response: {
        access_token: encode_exchanged_access_token(
          authorization_code: authorization_code, resource: resource, client: client, root_token: root_token,
          usage: usage, dpop_jkt: dpop_jkt, access_expires_at: access_expires_at,
          resource_type: resource_type, issuer: issuer, subject: subject,
        ),
        token_type: dpop_jkt.present? ? "DPoP" : "Bearer",
        expires_in: [(access_expires_at - now).to_i, 0].max,
        refresh_token: refresh_plain,
        id_token: encode_exchanged_id_token(
          authorization_code: authorization_code, resource: resource, client: client, usage: usage,
          now: now, root_token: root_token, resource_type: resource_type, issuer: issuer, subject: subject,
        ),
      },
      error: nil,
      error_description: nil,
    )
  end

  def encode_exchanged_access_token(authorization_code:, resource:, client:, root_token:, usage:, dpop_jkt:,
                                    access_expires_at:, resource_type:, issuer:, subject:)
    AuthenticationTokenService.encode(
      resource,
      host: OidcIssuer.host_for_resource_type(resource_type),
      session_public_id: root_token.public_id,
      oidc_sid: usage.public_id,
      oidc_jti: token_usage_oidc_jti(usage),
      resource_type: resource_type,
      expires_at: access_expires_at,
      scopes: authorization_code.scope.to_s.split,
      acr: authorization_code.acr,
      amr: Array(authorization_code.auth_method),
      dpop_jkt: dpop_jkt,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      audiences: [client.aud],
      subject: subject,
      auth_time: authorization_code.created_at || now,
      client_id: client.client_id,
    )
  end

  def encode_exchanged_id_token(authorization_code:, resource:, client:, usage:, now:, root_token:, resource_type:,
                                issuer:, subject:)
    OidcIdTokenIssuer.call(
      resource: resource,
      client: client,
      nonce: authorization_code.nonce,
      issued_at: now,
      expires_at: SessionAbsoluteExpiryValue.cap(
        proposed_expiry: now + OidcIdTokenIssuer::TOKEN_TTL,
        absolute_expiry: root_token.discarded_at,
      ),
      acr: authorization_code.acr,
      amr: Array(authorization_code.auth_method),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
      issuer: issuer,
      subject: subject,
      sid: usage.public_id,
      auth_time: authorization_code.created_at || now,
    )
  end

  def usage_class_for_root_token(root_token)
    case root_token
    when ClientToken then ClientTokenUsage
    when OperatorToken then OperatorTokenUsage
    when VisitorToken then VisitorTokenUsage
    else
      raise ArgumentError, "unsupported root token class: #{root_token.class.name}"
    end
  end

  def connection_owner_for(klass)
    owner = klass
    owner = owner.superclass until owner.connection_class? || owner == ApplicationRecord
    owner
  end

  def parent_token_foreign_key_for(usage_class)
    case usage_class.name
    when "OperatorTokenUsage" then :operator_token
    when "VisitorTokenUsage" then :visitor_token
    else :client_token
    end
  end

  def root_token_from_authorization_code(authorization_code)
    case authorization_code
    when ClientAuthorizationCode then authorization_code.client_token
    when OperatorAuthorizationCode then authorization_code.operator_token
    when VisitorAuthorizationCode then authorization_code.visitor_token
    end
  end

  def root_token_actor_matches?(root_token, resource)
    case root_token
    when ClientToken then root_token.user == resource
    when OperatorToken then root_token.staff == resource
    when VisitorToken then root_token.visitor == resource
    else false
    end
  end

  def refresh_expires_at_for(root_token)
    ttl =
      case root_token
      when OperatorToken then SecurityTokenLifetimes::OPERATOR_REFRESH_TOKEN_TTL
      when VisitorToken then SecurityTokenLifetimes::VISITOR_REFRESH_TOKEN_TTL
      else SecurityTokenLifetimes::CLIENT_REFRESH_TOKEN_TTL
      end
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: ttl.from_now,
      absolute_expiry: root_token.discarded_at,
    )
  end

  def session_token_expiry(now, root_token)
    SessionAbsoluteExpiryValue.cap(
      proposed_expiry: now + AuthenticationBase::ACCESS_TOKEN_TTL,
      absolute_expiry: root_token.discarded_at,
    )
  end

  def connection_class_for(authorization_code)
    case authorization_code
    when OperatorAuthorizationCode then OrgTicketRecord
    when VisitorAuthorizationCode then ComTicketRecord
    else AppTicketRecord
    end
  end

  def validate_dpop_proof(authorization_code)
    return nil if dpop_proof.blank?

    result = DpopProofVerifier.new(
      proof_jwt: dpop_proof,
      request_method: request_method,
      request_uri: token_endpoint_uri.to_s,
      resource_type: resource_type_for(authorization_code),
    ).call

    return failure("invalid_request", "DPoP proof invalid: #{result.error}") unless result.valid?

    result.jkt
  end

  def resource_type_for(authorization_code)
    case authorization_code
    when OperatorAuthorizationCode then "operator"
    when VisitorAuthorizationCode then "visitor"
    else "client"
    end
  end

  def client_for_resource_type(client, resource_type)
    OidcClientRegistry::VisitorAccount.new(
      client_id: client.client_id,
      client_secret: client.client_secret,
      redirect_uris: client.redirect_uris,
      redirect_uris_by_realm: client.redirect_uris_by_realm,
      post_logout_redirect_uris: client.post_logout_redirect_uris,
      backchannel_logout_uris: client.backchannel_logout_uris,
      backchannel_logout_session_required: client.backchannel_logout_session_required,
      aud: client.aud,
      resource_type: resource_type,
      name: client.name,
      domains: client.domains,
      allowed_scopes: client.allowed_scopes,
      registered_token_endpoint_auth_method: client.registered_token_endpoint_auth_method,
      metadata_token_endpoint_auth_method: client.metadata_token_endpoint_auth_method,
      jwt_namespace: client.jwt_namespace,
    )
  end

  def failure(error, description)
    Result.new(success: false, token_response: nil, error: error, error_description: description)
  end
end
