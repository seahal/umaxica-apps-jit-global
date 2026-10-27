# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02VisaBaseIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    [
      ClientStatus, ClientVisibility, ClientMfaStatus,
      VisitorStatus, VisitorVisibility, VisitorMfaStatus,
      OperatorStatus, OperatorVisibility, OperatorMfaStatus,
    ].each(&:ensure_defaults!)
    ClientSecurityMode.insert_missing_fixed_ids!(ClientSecurityMode::DEFAULTS)
    VisitorSecurityMode.insert_missing_fixed_ids!(VisitorSecurityMode::DEFAULTS)
    OperatorSecurityMode.insert_missing_fixed_ids!(OperatorSecurityMode::DEFAULTS)
  end

  test "A02-5: ID Token and Access JWTs signed for Visa reject the retired www issuer in every realm" do
    realms = [
      ["client", "core-app-jp", "BASE_APP",
       Client.create!(status_id: ClientStatus::ACTIVE, security_mode_id: ClientSecurityMode::NORMAL),],
      ["visitor", "core-com-jp", "BASE_COM",
       Visitor.create!(
         status_id: VisitorStatus::ACTIVE, security_mode_id: VisitorSecurityMode::NORMAL,
         visibility_id: VisitorVisibility::VISITOR,
       ),],
      ["operator", "core-org-jp", "BASE_ORG",
       Operator.create!(
         status_id: OperatorStatus::ACTIVE, security_mode_id: OperatorSecurityMode::ADVANCED,
         visibility_id: OperatorVisibility::STAFF,
       ),],
    ]

    realms.each do |resource_type, client_id, base_namespace, actor|
      client = OidcClientRegistry.find!(client_id)
      visa_namespace = OidcIssuer.jwt_issuer_id_for_resource_type(resource_type)
      retired_issuer = JitSecurityJwtRegistry.surface(base_namespace).issuer
      issued_at = Time.current.utc.to_i
      nonce = "a02-5-#{resource_type}-#{SecureRandom.hex(8)}"
      id_token = JitSecurityJwtKeyring.encode(
        {
          "iss" => retired_issuer,
          "sub" => OidcSubject.for(actor, resource_type: resource_type),
          "aud" => [client.client_id],
          "exp" => 5.minutes.from_now.to_i,
          "iat" => issued_at,
          "nbf" => issued_at,
          "jti" => SecureRandom.uuid,
          "typ" => OidcIdTokenIssuer::TOKEN_TYPE,
          "act" => resource_type,
          "sid" => SecureRandom.urlsafe_base64(18),
          "nonce" => nonce,
          "acr" => "aal1",
        },
        typ: OidcIdTokenIssuer::TOKEN_TYPE,
        issuer_id: visa_namespace,
      )

      id_token_result = OidcIdTokenVerifier.call(
        id_token: id_token,
        client_id: client.client_id,
        resource_type: resource_type,
        expected_nonce: nonce,
        issuer: OidcIssuer.for_client(client),
        jwt_issuer_id: visa_namespace,
      )

      assert_equal [false, "invalid_id_token"], [id_token_result.success?, id_token_result.error], resource_type

      access_token = AuthenticationTokenService.encode(
        actor,
        host: OidcIssuer.host_for_resource_type(resource_type),
        resource_type: resource_type,
        session_public_id: actor.public_id,
        base_session_public_id: actor.public_id,
        oidc_sid: "a02-5-#{resource_type}-rp-session",
        oidc_jti: SecureRandom.uuid,
        expires_at: 5.minutes.from_now,
        scopes: %w(openid),
        issuer: retired_issuer,
        audiences: [client.aud],
        subject: OidcSubject.for(actor, resource_type: resource_type),
        jwt_issuer_id: visa_namespace,
        client_id: client.client_id,
      )
      access_payload = AuthenticationTokenService.decode(
        access_token,
        host: OidcIssuer.host_for_resource_type(resource_type),
        resource_type: resource_type,
        issuer: OidcIssuer.for_resource_type(resource_type),
        audiences: [client.aud],
        jwt_issuer_id: visa_namespace,
      )

      assert_nil access_payload, "#{resource_type} Access JWT with the old www issuer must be rejected"
    end
  end

  test "A02-5: client assertions with the retired www token endpoint audience fail in every realm" do
    clients = [
      %w(client core-app-jp BASE_APP),
      %w(visitor core-com-jp BASE_COM),
      %w(operator core-org-jp BASE_ORG),
    ]

    clients.each do |resource_type, client_id, base_namespace|
      retired_token_endpoint = "#{JitSecurityJwtRegistry.surface(base_namespace).issuer}/oauth/token"
      assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: retired_token_endpoint)

      assert_predicate assertion, :present?, "#{resource_type} assertion must be signed with its registered client key"
      assert_not OidcClientAssertionJwt.valid?(
        client_id: client_id,
        assertion: assertion,
        token_url: OidcIssuer.token_endpoint(resource_type),
      ), "#{resource_type} token endpoint must reject the retired www audience"
    end
  end
end
