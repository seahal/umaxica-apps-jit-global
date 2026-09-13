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

    token = find_token(payload)
    return failure("invalid_token") unless token&.active?
    return failure("invalid_token") unless token_belongs_to_audience?(token, payload)
    return failure("invalid_token") unless token_jti_matches?(token, payload)
    return failure("insufficient_scope") unless token_scope_allows_userinfo?(payload)

    resource = token_resource(token)
    return failure("invalid_token") unless resource&.active?
    return failure("invalid_token") if resource.respond_to?(:admin_locked?) && resource.admin_locked?
    if resource.respond_to?(:access_token_stale_for_administrative_lock?) &&
        resource.access_token_stale_for_administrative_lock?(payload)
      return failure("invalid_token")
    end
    return failure("invalid_token") unless token_subject_matches?(resource, payload)

    Result.new(success: true, payload: payload, token: token, resource: resource, error: nil)
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

  def find_token(payload)
    sid = payload["sid"].to_s
    return if sid.blank?

    token_context.connected_to(role: :reading) do
      usage = usage_class_for_resource_type&.find_by(public_id: sid)
      return usage if usage.present?

      token_class_for_resource_type.find_by(oidc_sid: sid) || token_class_for_resource_type.find_by(public_id: sid)
    end
  end

  def token_belongs_to_audience?(token, payload)
    return false unless token.respond_to?(:oidc_client_id)

    client = OidcClientRegistry.find(token.oidc_client_id)
    return false unless client
    return false unless OidcIssuer.resource_type_for_client(client) == resource_type

    Array(payload["aud"]).include?(client.aud)
  end

  def token_jti_matches?(token, payload)
    return true unless token.respond_to?(:oidc_jti)
    return true if token.oidc_jti.blank?

    expected = token.oidc_jti.to_s
    actual = payload["jti"].to_s
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def token_scope_allows_userinfo?(payload)
    AuthorizationTokenClaims.scopes(payload).include?("openid")
  end

  def token_subject_matches?(resource, payload)
    expected = OidcSubject.for(resource, resource_type: resource_type)
    actual = payload["sub"].to_s
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def token_resource(token)
    session_token = root_token_for(token)
    case resource_type
    when "operator" then session_token.staff
    when "visitor" then session_token.visitor
    else session_token.user
    end
  end

  def token_class_for_resource_type
    case resource_type
    when "operator" then OperatorToken
    when "visitor" then VisitorToken
    else ClientToken
    end
  end

  def usage_class_for_resource_type
    case resource_type
    when "operator" then OperatorTokenUsage
    when "visitor" then VisitorTokenUsage
    else ClientTokenUsage
    end
  end

  def root_token_for(token)
    return token.client_token if token.respond_to?(:client_token) && token.client_token.present?
    return token.operator_token if token.respond_to?(:operator_token) && token.operator_token.present?
    return token.visitor_token if token.respond_to?(:visitor_token) && token.visitor_token.present?

    token
  end

  def token_context
    case resource_type
    when "operator" then OrgTicketRecord
    when "visitor" then ComTicketRecord
    else AppTicketRecord
    end
  end

  def failure(error)
    Result.new(success: false, payload: nil, token: nil, resource: nil, error: error)
  end
end
