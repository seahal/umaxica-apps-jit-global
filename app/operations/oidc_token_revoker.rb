# typed: false
# frozen_string_literal: true

class OidcTokenRevoker < ApplicationService
  Result =
    Data.define(:success, :error, :error_description) do
      def success? = success
    end

  def initialize(token:, client_id:, client_secret:, token_type_hint: nil, host: nil, expected_resource_type: nil)
    super()
    @token = token
    @client_id = client_id
    @client_secret = client_secret
    @token_type_hint = token_type_hint
    @host = host
    @expected_resource_type = expected_resource_type
  end

  def call
    return failure("invalid_client", "OIDC client authentication failed") unless authenticated_client?

    revoke_refresh_token || revoke_access_token
    Result.new(success: true, error: nil, error_description: nil)
  end

  private

  attr_reader :token, :client_id, :client_secret, :token_type_hint, :host, :expected_resource_type

  def authenticated_client?
    if expected_resource_type.present?
      client = OidcClientRegistry.find(client_id)
      return false unless client
      return false if OidcIssuer.resource_type_for_client(client) != expected_resource_type.to_s
    end

    OidcClientRegistry.authenticate(client_id, client_secret)
  end

  def revoke_refresh_token
    return false if token.blank?

    parsed = ClientToken.parse_refresh_token(token)
    return false unless parsed

    public_id, verifier = parsed
    token_record = find_rp_session_by_public_id(public_id, resource_type: client_resource_type)
    return false unless token_record
    return false unless token_record.oidc_client_id == client_id
    return false unless token_record.refresh_token_digest_matches?(verifier)

    RpSessionRevoker.call(scope: :rp_session, record: token_record)
    true
  end

  def revoke_access_token
    client = OidcClientRegistry.find(client_id)
    return false unless client

    payload = AuthenticationTokenService.decode_allow_expired(
      token,
      host: host.presence || OidcIssuer.host_for_client(client),
      resource_type: client_resource_type,
      issuer: OidcIssuer.for_client(client),
      audiences: [client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
    )
    return false unless payload

    # OIDC revocation is scoped to the RP Session that issued the token. A
    # parent Base Browser Session may also carry an OIDC sid for legacy or
    # first-party browser flows, but falling back to that row here would let an
    # RP revoke the whole browser session when its own RP Session is absent.
    token_record = find_rp_session_by_sid(
      client_resource_type,
      payload["sid"],
    )
    return false unless token_record&.oidc_client_id == client_id
    return false unless token_jti_matches?(token_record, payload)

    RpSessionRevoker.call(scope: :rp_session, record: token_record)
    true
  end

  def find_rp_session_by_public_id(public_id, resource_type:)
    context, rp_session_class = rp_session_context_and_class(resource_type)

    context.connected_to(role: :writing) { rp_session_class.find_by(public_id: public_id) }
  end

  def find_rp_session_by_sid(resource_type, sid)
    return if sid.blank?

    context, rp_session_class = rp_session_context_and_class(resource_type)

    context.connected_to(role: :writing) do
      rp_session_class.find_by(public_id: sid)
    end
  end

  def token_jti_matches?(token_record, payload)
    return false unless token_record.has_attribute?(:oidc_jti)
    return false if token_record.oidc_jti.blank?

    expected = token_record.oidc_jti.to_s
    actual = payload["jti"].to_s
    return false unless expected.bytesize == actual.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, actual)
  end

  def rp_session_context_and_class(resource_type)
    case resource_type
    when "operator" then [OrgTicketRecord, OperatorRpSession]
    when "visitor" then [ComTicketRecord, VisitorRpSession]
    else [AppTicketRecord, ClientRpSession]
    end
  end

  def client_resource_type
    @client_resource_type ||= OidcIssuer.resource_type_for_client(OidcClientRegistry.find!(client_id))
  end

  def failure(error, description)
    Result.new(success: false, error: error, error_description: description)
  end
end
