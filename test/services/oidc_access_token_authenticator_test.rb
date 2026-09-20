# typed: false
# frozen_string_literal: true

require "test_helper"

# OidcAccessTokenAuthenticator is the userinfo gate for RP-held Access JWTs. Every case below mints
# a real token for a real Browser Session / RP Session and changes exactly one fact about it, so a
# refusal can only come from the check that owns that fact.
class OidcAccessTokenAuthenticatorTest < ActiveSupport::TestCase
  test "a well-formed client Access JWT for an active RP Session authenticates" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(
      user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    session = ClientRpSession.create!(
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
            expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
            audiences: [client.aud], subject: OidcSubject.for(user, resource_type: "client"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
    )

    result = OidcAccessTokenAuthenticator.call(
      access_token: token, resource_type: "client", host: OidcIssuer.host_for_resource_type("client"),
    )

    assert_predicate result, :success?
    assert_equal user, result.resource
    assert_equal session, result.token
  end

  test "operator and visitor Access JWTs resolve against their own RP Session and actor" do
    { "operator" => [Operator, OperatorToken, OperatorRpSession, :staff, :operator_token],
      "visitor" => [Visitor, VisitorToken, VisitorRpSession, :visitor, :visitor_token], }.each do |type, spec|
      actor_class, token_class, session_class, actor_key, root_key = spec
      client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
        .find { _1 && OidcIssuer.resource_type_for_client(_1) == type }
      actor = actor_class.create!(status_id: "#{actor_class.name}Status".constantize::ACTIVE)
      root = token_class.create!(actor_key => actor)
      session = session_class.create!(
        root_key => root, :oidc_client_id => client.client_id, :oidc_scope => "openid",
        :oidc_jti => SecureRandom.uuid, :refresh_token_expires_at => 1.hour.from_now,
      )
      token = AuthenticationTokenService.encode(
        actor, host: OidcIssuer.host_for_resource_type(type), resource_type: type,
               session_public_id: root.public_id, oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
               expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type(type),
               audiences: [client.aud], subject: OidcSubject.for(actor, resource_type: type),
               jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type), client_id: client.client_id,
      )

      result = OidcAccessTokenAuthenticator.call(
        access_token: token, resource_type: type, host: OidcIssuer.host_for_resource_type(type),
      )

      assert_predicate result, :success?, type
      assert_equal actor, result.resource, type
    end
  end

  test "a token presented under the wrong scheme or with an unrequested proof is refused" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(user: user)
    session = ClientRpSession.create!(
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
            expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
            audiences: [client.aud], subject: OidcSubject.for(user, resource_type: "client"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
    )
    host = OidcIssuer.host_for_resource_type("client")

    dpop_scheme = OidcAccessTokenAuthenticator.call(
      access_token: token, resource_type: "client", host: host, authorization_scheme: "DPoP", dpop_proof: "proof",
      request_method: "GET", request_uri: "https://#{host}/userinfo",
    )
    bearer_with_proof = OidcAccessTokenAuthenticator.call(
      access_token: token, resource_type: "client", host: host, authorization_scheme: "Bearer", dpop_proof: "proof",
      request_method: "GET", request_uri: "https://#{host}/userinfo",
    )

    assert_equal "invalid_token", dpop_scheme.error, "an unbound token must not be accepted as DPoP"
    assert_equal "invalid_token", bearer_with_proof.error, "a stray DPoP proof must not be ignored"
  end

  test "a DPoP-bound token is refused as a plain bearer token" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    user = Client.create!(status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(user: user)
    session = ClientRpSession.create!(
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    key = OpenSSL::PKey::EC.generate("prime256v1")
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
            expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
            audiences: [client.aud], subject: OidcSubject.for(user, resource_type: "client"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
            dpop_jkt: JitSecurityJwtThumbprintCalculator.calculate(JWT::JWK.new(key).export),
    )

    result = OidcAccessTokenAuthenticator.call(
      access_token: token, resource_type: "client", host: OidcIssuer.host_for_resource_type("client"),
      authorization_scheme: "Bearer",
    )

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "each broken binding between the token and its session or actor is refused" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    operator_client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "operator" }
    host = OidcIssuer.host_for_resource_type("client")
    cases = {
      "undecodable token" => { token: "not-a-jwt" },
      "no openid scope" => { scopes: %w(profile) },
      "RP Session bound to an unknown client" => { session_client_id: "unknown-rp" },
      "RP Session bound to another realm's client" => { session_client_id: operator_client.client_id },
      "jti of a different length" => { jti: "short" },
      "jti of the same length but different value" => { jti: SecureRandom.uuid },
      "subject of another actor" => { subject: "someone-else" },
      "revoked parent Browser Session" => { root_status: ClientTokenStatus::REVOKED },
      "admin-locked actor" => {
        user_attrs: { access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
                      admin_locked_at: Time.current,
                      admin_locked_by_operator_id: 1,
                      admin_locked_reason_code: "security_incident", },
      },
      "token issued before an administrative lock threshold" => {
        user_attrs: { token_valid_after_at: 1.minute.from_now },
      },
    }

    cases.each do |label, change|
      user = Client.create!({ status_id: ClientStatus::ACTIVE }.merge(change.fetch(:user_attrs, {})))
      root = ClientToken.create!(user: user, user_token_status_id: change.fetch(:root_status, ClientTokenStatus::ACTIVE))
      session = ClientRpSession.create!(
        client_token: root, oidc_client_id: change.fetch(:session_client_id, client.client_id), oidc_scope: "openid",
        oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
      )
      token =
        change.fetch(:token) do
          AuthenticationTokenService.encode(
            user, host: host, resource_type: "client",
                  session_public_id: root.public_id, oidc_sid: session.public_id,
                  oidc_jti: change.fetch(:jti, session.oidc_jti), expires_at: 5.minutes.from_now,
                  scopes: change.fetch(:scopes, %w(openid)), issuer: OidcIssuer.for_resource_type("client"),
                  audiences: [client.aud],
                  subject: change.fetch(:subject, OidcSubject.for(user, resource_type: "client")),
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
          )
        end

      result = OidcAccessTokenAuthenticator.call(access_token: token, resource_type: "client", host: host)

      assert_not result.success?, label
      expected = (label == "no openid scope") ? "insufficient_scope" : "invalid_token"

      assert_equal expected, result.error, label
    end
  end

  test "a blank token is refused before decoding" do
    result = OidcAccessTokenAuthenticator.call(access_token: nil, resource_type: "client", host: "app.example.test")

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end
end
