# typed: false
# frozen_string_literal: true

require "test_helper"

# OidcAccessTokenAuthenticator is the userinfo gate for RP-held Access JWTs. Every case below mints
# a real token for a real Base Browser Session / RP Session and changes exactly one fact about it,
# so a refusal can only come from the check that owns that fact.
class OidcAccessTokenAuthenticatorTest < ActiveSupport::TestCase
  test "a well-formed client Access JWT for an active Base Browser Session authenticates" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(
      authentication_epoch: 0,
      user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, base_session_public_id: root.public_id,
            oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
            expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
            audiences: [client.aud], subject: OidcSubject.for(user, resource_type: "client"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
    )

    result = OidcAccessTokenAuthenticator.call(
      access_token: token, resource_type: "client", host: OidcIssuer.host_for_resource_type("client"),
    )

    assert_predicate result, :success?
    assert_equal user, result.resource
    assert_equal root, result.token
  end

  test "a well-formed client Access JWT authenticates without an RP Session lookup" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(
      authentication_epoch: 0,
      user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, base_session_public_id: root.public_id,
            oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
            expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
            audiences: [client.aud], subject: OidcSubject.for(user, resource_type: "client"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
    )

    OpAppGrant.stub(:find_by, ->(**) { flunk("normal Access JWT authentication must not query RP Sessions") }) do
      result = OidcAccessTokenAuthenticator.call(
        access_token: token, resource_type: "client", host: OidcIssuer.host_for_resource_type("client"),
      )

      assert_predicate result, :success?
      assert_equal user, result.resource
    end
  end

  test "operator and visitor Access JWTs resolve against their own Base Session and actor" do
    { "operator" => [Operator, OperatorToken, OpOrgGrant, :staff, :operator_token],
      "visitor" => [Visitor, VisitorToken, OpComGrant, :visitor, :visitor_token], }.each do |type, spec|
      actor_class, token_class, session_class, actor_key, root_key = spec
      client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
        .find { _1 && OidcIssuer.resource_type_for_client(_1) == type }
      actor = actor_class.create!(
        security_mode_id: SecurityModeTestDefault.id_for(actor_class),
        status_id: "#{actor_class.name}Status".constantize::ACTIVE,
      )
      root = token_class.create!(:authentication_epoch => 0, actor_key => actor)
      session = session_class.create!(
        :authentication_epoch => 0,
        root_key => root, :oidc_client_id => client.client_id, :oidc_scope => "openid",
        :oidc_jti => SecureRandom.uuid, :refresh_token_expires_at => 1.hour.from_now,
      )
      token = AuthenticationTokenService.encode(
        actor, host: OidcIssuer.host_for_resource_type(type), resource_type: type,
               session_public_id: root.public_id, base_session_public_id: root.public_id,
               oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
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
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(authentication_epoch: 0, user: user)
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, base_session_public_id: root.public_id,
            oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
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
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(authentication_epoch: 0, user: user)
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    key = OpenSSL::PKey::EC.generate("prime256v1")
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, base_session_public_id: root.public_id,
            oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
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

  test "each broken binding between the token and its Base Session or actor is refused" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    operator_client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "operator" }
    host = OidcIssuer.host_for_resource_type("client")
    cases = {
      "undecodable token" => { token: "not-a-jwt" },
      "no openid scope" => { scopes: %w(profile) },
      "token bound to an unknown client" => { token_client_id: "unknown-rp" },
      "token bound to another realm's client" => { token_client_id: operator_client.client_id },
      "missing Base Session binding" => { missing_base_session: true },
      "subject of another actor" => { subject: "someone-else" },
      "historical restricted parent Browser Session" => { root_status: ClientTokenStatus::RESTRICTED },
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
      user = Client.create!(
        { security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE }
          .merge(change.fetch(:user_attrs, {})),
      )
      root = ClientToken.create!(authentication_epoch: 0, user: user, user_token_status_id: change.fetch(:root_status, ClientTokenStatus::ACTIVE))
      session = OpAppGrant.create!(
        authentication_epoch: 0,
        client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
        oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
      )
      token =
        change.fetch(:token) do
          AuthenticationTokenService.encode(
            user, host: host, resource_type: "client",
                  session_public_id: root.public_id, oidc_sid: session.public_id,
                  base_session_public_id: (root.public_id unless change[:missing_base_session]),
                  oidc_jti: session.oidc_jti, expires_at: 5.minutes.from_now,
                  scopes: change.fetch(:scopes, %w(openid)), issuer: OidcIssuer.for_resource_type("client"),
                  audiences: [client.aud],
                  subject: change.fetch(:subject, OidcSubject.for(user, resource_type: "client")),
                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
                  client_id: change.fetch(:token_client_id, client.client_id),
          )
        end

      result = OidcAccessTokenAuthenticator.call(access_token: token, resource_type: "client", host: host)

      assert_not result.success?, label
      expected = (label == "no openid scope") ? "insufficient_scope" : "invalid_token"

      assert_equal expected, result.error, label
    end
  end

  test "OIDC Access requires an explicit known context claim matching the current root" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(authentication_epoch: 0, user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    valid_token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, base_session_public_id: root.public_id,
            oidc_sid: session.public_id, oidc_jti: session.oidc_jti,
            expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
            audiences: [client.aud], subject: OidcSubject.for(user, resource_type: "client"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(client), client_id: client.client_id,
    )
    invalid_claims = {
      "missing" => :missing,
      "null" => nil,
      "empty" => "",
      "zero wrong type" => 0,
      "boolean wrong type" => false,
      "array wrong type" => [],
      "object wrong type" => {},
      "unknown" => "future-context",
      "Emergency claim on a Normal root" => AuthenticationContextValue::STANDBY_KEY,
    }

    invalid_claims.each do |label, claim|
      payload = JWT.decode(valid_token, nil, false).first
      if claim == :missing
        payload.delete(AuthenticationContextValue::CLAIM)
      else
        payload[AuthenticationContextValue::CLAIM] = claim
      end
      malformed_token = JitSecurityJwtKeyring.encode(
        payload,
        typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
        issuer_id: OidcIssuer.jwt_issuer_id_for_client(client),
      )

      result = OidcAccessTokenAuthenticator.call(
        access_token: malformed_token, resource_type: "client", host: OidcIssuer.host_for_resource_type("client"),
      )

      assert_equal "invalid_token", result.error, label
    end

    operator_client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "operator" }
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    operator_root = OperatorToken.create!(authentication_epoch: 0, staff: operator, authentication_context: AuthenticationContextValue::STANDBY_KEY)
    operator_session = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token: operator_root, oidc_client_id: operator_client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    access_token = AuthenticationTokenService.encode(
      operator,
      host: OidcIssuer.host_for_resource_type("operator"),
      resource_type: "operator",
      session_public_id: operator_root.public_id,
      base_session_public_id: operator_root.public_id,
      oidc_sid: operator_session.public_id,
      oidc_jti: operator_session.oidc_jti,
      expires_at: 5.minutes.from_now,
      scopes: %w(openid),
      issuer: OidcIssuer.for_resource_type("operator"),
      audiences: [operator_client.aud],
      subject: OidcSubject.for(operator, resource_type: "operator"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(operator_client),
      client_id: operator_client.client_id,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )

    mismatched_result = OidcAccessTokenAuthenticator.call(
      access_token: access_token,
      resource_type: "operator",
      host: OidcIssuer.host_for_resource_type("operator"),
    )

    assert_equal "invalid_token", mismatched_result.error, "explicit Normal must not authenticate an Emergency root"

    emergency_token = AuthenticationTokenService.encode(
      operator,
      host: OidcIssuer.host_for_resource_type("operator"),
      resource_type: "operator",
      session_public_id: operator_root.public_id,
      base_session_public_id: operator_root.public_id,
      oidc_sid: operator_session.public_id,
      oidc_jti: operator_session.oidc_jti,
      expires_at: 5.minutes.from_now,
      scopes: %w(openid),
      issuer: OidcIssuer.for_resource_type("operator"),
      audiences: [operator_client.aud],
      subject: OidcSubject.for(operator, resource_type: "operator"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(operator_client),
      client_id: operator_client.client_id,
      authentication_context: AuthenticationContextValue::STANDBY_KEY,
    )
    matching_result = OidcAccessTokenAuthenticator.call(
      access_token: emergency_token,
      resource_type: "operator",
      host: OidcIssuer.host_for_resource_type("operator"),
    )

    assert_predicate matching_result, :success?
    assert_equal operator, matching_result.resource
  end

  test "an Access JWT cannot use a Base Session belonging to another actor" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    first_user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    second_user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(authentication_epoch: 0, user: first_user, user_token_status_id: ClientTokenStatus::ACTIVE)
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    token = AuthenticationTokenService.encode(
      second_user,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: session.public_id,
      oidc_jti: session.oidc_jti,
      expires_at: 5.minutes.from_now,
      scopes: %w(openid),
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: [client.aud],
      subject: OidcSubject.for(second_user, resource_type: "client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      client_id: client.client_id,
    )

    result = OidcAccessTokenAuthenticator.call(
      access_token: token, resource_type: "client", host: OidcIssuer.host_for_resource_type("client"),
    )

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "a blank token is refused before decoding" do
    result = OidcAccessTokenAuthenticator.call(access_token: nil, resource_type: "client", host: "app.example.test")

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  # D-165 / A44-3: an identity stop advances the actor's epoch; an Access JWT under a root of the
  # older epoch is refused even before the OP-side invalidation ran, and stays refused after the
  # account is restored to active.
  test "an Access JWT of a root issued before an identity stop is refused, also after restore" do
    client = OidcClientRegistry.client_ids.map { OidcClientRegistry.find(_1) }
      .find { _1 && OidcIssuer.resource_type_for_client(_1) == "client" }
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(
      authentication_epoch: 0,
      user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB, user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token: root, oidc_client_id: client.client_id, oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, refresh_token_expires_at: 1.hour.from_now,
    )
    token = AuthenticationTokenService.encode(
      user, host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
            session_public_id: root.public_id, base_session_public_id: root.public_id,
            oidc_sid: grant.public_id, oidc_jti: grant.oidc_jti,
            expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
            audiences: [client.aud], subject: OidcSubject.for(user, resource_type: "client"),
            jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
    )
    authenticate =
      lambda do
        OidcAccessTokenAuthenticator.call(
          access_token: token, resource_type: "client", host: OidcIssuer.host_for_resource_type("client"),
        )
      end

    assert_predicate authenticate.call, :success?
    Client.transaction do
      user.lock!
      IdentityAuthenticationStopRecorder.call(actor: user, reason: "access_lock")
    end

    assert_equal "invalid_token", authenticate.call.error
    assert_predicate user.reload, :active?, "the account itself is active (restored)"
    assert_equal "invalid_token", authenticate.call.error
  end
end
