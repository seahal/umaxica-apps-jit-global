# typed: false
# frozen_string_literal: true

class PalmAccessTokenAuthenticator < ApplicationService
  AUDIENCE = "palm-api"
  REQUIRED_SCOPE = "palm.read"
  ALLOWED_CLIENT_IDS = %w(app-ios-rp app-android-rp).freeze
  RESOURCE_TYPE = "client"

  Result =
    Data.define(:success, :payload, :resource, :error) do
      def success? = success
    end

  def initialize(access_token:, host:, authorization_scheme:)
    super()
    @access_token = access_token
    @host = host
    @authorization_scheme = authorization_scheme
  end

  def call
    return failure("invalid_token") if access_token.blank?
    return failure("invalid_token") unless authorization_scheme.to_s.casecmp?("Bearer")

    payload = AuthenticationTokenService.decode(
      access_token,
      host: host,
      resource_type: RESOURCE_TYPE,
      issuer: OidcIssuer.for_resource_type(RESOURCE_TYPE),
      audiences: [AUDIENCE],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(RESOURCE_TYPE),
    )
    return failure("invalid_token") unless payload
    # DPoP-bound Palm tokens require end-to-end proof validation; do not accept them as Bearer.
    return failure("invalid_token") if payload.dig("cnf", "jkt").present?
    return failure("insufficient_scope") unless scope_allowed?(payload)
    return failure("invalid_token") unless allowed_client_id?(payload)

    token = find_token(payload)
    return failure("invalid_token") unless token&.active?
    return failure("invalid_token") unless token_belongs_to_audience?(token, payload)
    return failure("invalid_token") unless token_jti_matches?(token, payload)

    resource = find_resource(payload)
    return failure("invalid_token") unless resource&.active?
    return failure("invalid_token") if resource.respond_to?(:admin_locked?) && resource.admin_locked?
    if resource.respond_to?(:access_token_stale_for_administrative_lock?) &&
        resource.access_token_stale_for_administrative_lock?(payload)
      return failure("invalid_token")
    end

    Result.new(success: true, payload: payload, resource: resource, error: nil)
  end

  private

  attr_reader :access_token, :host, :authorization_scheme

  def scope_allowed?(payload)
    Array(AuthorizationTokenClaims.scopes(payload)).include?(REQUIRED_SCOPE)
  end

  def allowed_client_id?(payload)
    ALLOWED_CLIENT_IDS.include?(AuthorizationTokenClaims.client_id(payload).to_s)
  end

  def find_resource(payload)
    public_id = OidcSubject.public_id_from(AuthorizationTokenClaims.subject(payload), resource_type: RESOURCE_TYPE)
    return nil if public_id.blank?

    AppZenithRecord.connected_to(role: :reading) do
      Client.find_by(public_id: public_id)
    end
  end

  def find_token(payload)
    sid = payload["sid"].to_s
    return if sid.blank?

    AppTicketRecord.connected_to(role: :reading) do
      ClientRpSession.find_by(public_id: sid) ||
        ClientToken.find_by(oidc_sid: sid) ||
        ClientToken.find_by(public_id: sid)
    end
  end

  def token_belongs_to_audience?(token, payload)
    return false unless token.respond_to?(:oidc_client_id)

    client = OidcClientRegistry.find(token.oidc_client_id)
    return false unless client
    return false unless OidcIssuer.resource_type_for_client(client) == RESOURCE_TYPE

    Array(payload["aud"]).include?(client.aud) && client.aud == AUDIENCE
  end

  def token_jti_matches?(token, payload)
    return true unless token.respond_to?(:oidc_jti)
    return true if token.oidc_jti.blank?

    expected = token.oidc_jti.to_s
    actual = payload["jti"].to_s
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def failure(error)
    Result.new(success: false, payload: nil, resource: nil, error: error)
  end
end
