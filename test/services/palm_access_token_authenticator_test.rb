# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class PalmAccessTokenAuthenticatorTest < ActiveSupport::TestCase
  HOST = "palm-jp.umaxica.app"

  test "accepts acme issued palm audience bearer token" do
    token = persisted_token
    result = authenticate(token: palm_token(sid: token.oidc_sid, jti: token.oidc_jti))

    assert_predicate result, :success?
    assert_equal clients(:one), result.resource
    assert_equal "app-ios-rp", AuthorizationTokenClaims.client_id(result.payload)
  end

  test "rejects missing bearer token" do
    result = authenticate(token: nil)

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects non bearer scheme" do
    result = authenticate(token: palm_token, scheme: "DPoP")

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects wrong audience" do
    result = authenticate(token: palm_token(audiences: ["core-browser"]))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects a core-app audienced access token" do
    result = authenticate(token: palm_token(audiences: ["core-app"]))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects palm-api audience token bound to a client_id not in the allowed native client list" do
    result = authenticate(
      token: palm_token(
        audiences: [PalmAccessTokenAuthenticator::AUDIENCE],
        client_id: "core-app",
      ),
    )

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects missing palm read scope" do
    result = authenticate(token: palm_token(scopes: %w(openid profile)))

    assert_not result.success?
    assert_equal "insufficient_scope", result.error
  end

  test "rejects unsupported native client id" do
    result = authenticate(token: palm_token(client_id: "core-app"))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects missing persisted client token" do
    result = authenticate(token: palm_token(sid: SecureRandom.uuid))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects inactive persisted client token" do
    token = persisted_token(user_token_status_id: ClientTokenStatus::REVOKED)

    result = authenticate(token: palm_token(sid: token.oidc_sid))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects rotated persisted client token when inactive" do
    token = persisted_token(user_token_status_id: ClientTokenStatus::ACTIVE)
    token.update!(user_token_status_id: ClientTokenStatus::REVOKED, rotated_at: Time.current)

    result = authenticate(token: palm_token(sid: token.oidc_sid))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects jti mismatch with persisted token" do
    token = persisted_token(oidc_jti: SecureRandom.uuid)

    result = authenticate(token: palm_token(sid: token.oidc_sid, jti: SecureRandom.uuid))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects wrong audience client binding" do
    token = persisted_token(oidc_client_id: "core-app")

    result = authenticate(token: palm_token(sid: token.oidc_sid))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects cnf bound token presented as bearer" do
    result = authenticate(token: palm_token(dpop_jkt: "thumbprint"))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects unknown subject" do
    subject = "#{OidcSubject.prefix_for("client")}_missing-client"
    result = authenticate(token: palm_token(subject: subject))

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "rejects administratively locked client" do
    client = clients(:one)
    client.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: operators(:one).id,
      admin_locked_reason_code: "security_incident",
    )

    result = authenticate(token: palm_token)

    assert_not result.success?
    assert_equal "invalid_token", result.error
  ensure
    client&.reload&.update!(
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ENABLED,
      token_valid_after_at: nil,
      admin_locked_at: nil,
      admin_locked_by_operator_id: nil,
      admin_locked_reason_code: nil,
    )
  end

  private

  def authenticate(token:, scheme: "Bearer")
    PalmAccessTokenAuthenticator.call(
      access_token: token,
      host: HOST,
      authorization_scheme: scheme,
    )
  end

  def palm_token(client: clients(:one), scopes: %w(openid palm.read), audiences: [PalmAccessTokenAuthenticator::AUDIENCE],
                 client_id: "app-ios-rp", subject: nil, sid: "palm-session", jti: SecureRandom.uuid,
                 dpop_jkt: nil)
    AuthenticationTokenService.encode(
      client,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: sid,
      session_id: sid,
      expires_at: 10.minutes.from_now,
      scopes: scopes,
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: audiences,
      subject: subject || OidcSubject.for(client, resource_type: "client"),
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      client_id: client_id,
      oidc_sid: sid,
      oidc_jti: jti,
      dpop_jkt: dpop_jkt,
    )
  end

  def persisted_token(oidc_client_id: "app-ios-rp", oidc_jti: SecureRandom.uuid,
                      user_token_status_id: ClientTokenStatus::ACTIVE)
    ClientToken.create!(
      user: clients(:one),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: user_token_status_id,
      oidc_sid: SecureRandom.uuid,
      oidc_jti: oidc_jti,
      oidc_client_id: oidc_client_id,
    )
  end
end
