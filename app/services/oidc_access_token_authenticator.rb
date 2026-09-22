# typed: false
# frozen_string_literal: true

class OidcAccessTokenAuthenticator < ApplicationService
  Result =
    Data.define(:success, :payload, :token, :resource, :error) do
      def success? = success
    end

  def initialize(access_token:, resource_type:, host:, authorization_scheme: nil, dpop_proof: nil,
                 request_method: nil, request_uri: nil)
    super()
    @access_token = access_token
    @resource_type = OidcSubject.normalize_resource_type(resource_type)
    @host = host
    @authorization_scheme = authorization_scheme
    @dpop_proof = dpop_proof
    @request_method = request_method
    @request_uri = request_uri
  end

  def call
    return failure("invalid_token") if access_token.blank?

    payload = AuthenticationTokenService.decode(
      access_token,
      host: host,
      resource_type: resource_type,
      issuer: OidcIssuer.for_resource_type(resource_type),
      audiences: OidcClientRegistry.audiences_for_resource_type(resource_type),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(resource_type),
    )
    return failure("invalid_token") unless payload
    return failure("invalid_token") unless dpop_valid?(payload)

    base_session = find_base_session(payload)
    return failure("invalid_token") unless base_session&.currently_usable?
    return failure("invalid_token") unless token_belongs_to_audience?(payload)
    return failure("insufficient_scope") unless token_scope_allows_userinfo?(payload)

    resource = find_resource(payload)
    return failure("invalid_token") unless resource&.active?
    return failure("invalid_token") if resource.respond_to?(:admin_locked?) && resource.admin_locked?
    if resource.respond_to?(:access_token_stale_for_administrative_lock?) &&
        resource.access_token_stale_for_administrative_lock?(payload)
      return failure("invalid_token")
    end
    return failure("invalid_token") unless token_subject_matches?(resource, payload)
    return failure("invalid_token") unless base_session_actor_matches?(base_session, resource)

    Result.new(success: true, payload: payload, token: base_session, resource: resource, error: nil)
  end

  private

  attr_reader :access_token, :resource_type, :host, :authorization_scheme, :dpop_proof,
              :request_method, :request_uri

  # Enforce DPoP sender-constraint, mirroring
  # AuthenticationCurrentResourceResolver#dpop_valid?. A DPoP-bound access
  # token (one carrying cnf.jkt) must be presented with the DPoP scheme and a
  # valid proof; it must never be accepted as a plain Bearer token.
  def dpop_valid?(payload)
    token_jkt = payload.dig("cnf", "jkt")
    scheme_dpop = authorization_scheme.to_s.casecmp?("DPoP")

    return true if token_jkt.blank? && !scheme_dpop && dpop_proof.blank?
    return false unless scheme_dpop
    return false if token_jkt.blank?

    DpopRequestVerifier.new(
      access_token_payload: payload,
      proof_jwt: dpop_proof,
      request_method: request_method,
      request_uri: request_uri,
      access_token: access_token,
      resource_type: resource_type,
    ).call.valid?
  end

  # Normal Access JWT authentication is cryptographic (RFC 9068) plus a direct
  # binding to the Base Browser Session that issued the RP credentials. The RP
  # Session remains the refresh/revocation authority, but it is deliberately not
  # read on every authenticated request. `sid` remains the protocol identifier
  # for the RP Session; `umx_base_sid` identifies the parent Base session.
  def find_base_session(payload)
    base_sid = AuthorizationTokenClaims.base_session_id(payload).to_s
    return if base_sid.blank?

    token_class_for_resource_type.connection_class_for_self.connected_to(role: :reading) do
      token_class_for_resource_type.find_by(public_id: base_sid)
    end
  end

  def token_belongs_to_audience?(payload)
    client = OidcClientRegistry.find(AuthorizationTokenClaims.client_id(payload))
    return false unless client
    return false unless OidcIssuer.resource_type_for_client(client) == resource_type

    Array(payload["aud"]).include?(client.aud)
  end

  def token_scope_allows_userinfo?(payload)
    AuthorizationTokenClaims.scopes(payload).include?("openid")
  end

  def find_resource(payload)
    public_id = OidcSubject.public_id_from(
      AuthorizationTokenClaims.subject(payload),
      resource_type: resource_type,
    )
    return if public_id.blank?

    resource_class_for_resource_type.connection_class_for_self.connected_to(role: :reading) do
      resource_class_for_resource_type.find_by(public_id: public_id)
    end
  end

  def token_subject_matches?(resource, payload)
    expected = OidcSubject.for(resource, resource_type: resource_type)
    actual = payload["sub"].to_s
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def base_session_actor_matches?(base_session, resource)
    case resource_type
    when "operator" then base_session.staff_id == resource.id
    when "visitor" then base_session.visitor_id == resource.id
    else base_session.user_id == resource.id
    end
  end

  def resource_class_for_resource_type
    case resource_type
    when "operator" then Operator
    when "visitor" then Visitor
    else Client
    end
  end

  def token_class_for_resource_type
    case resource_type
    when "operator" then OperatorToken
    when "visitor" then VisitorToken
    else ClientToken
    end
  end

  def failure(error)
    Result.new(success: false, payload: nil, token: nil, resource: nil, error: error)
  end
end
