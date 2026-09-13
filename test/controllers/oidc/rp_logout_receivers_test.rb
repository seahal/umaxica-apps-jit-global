# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcRpLogoutReceiversTest < ActionDispatch::IntegrationTest
  SURFACES = [
    { host: ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      client_id: "sign-rp",
      resource_type: "client", },
    { host: ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      client_id: "sign-rp",
      resource_type: "visitor", },
    { host: ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
      client_id: "sign-rp",
      resource_type: "operator", },
    { host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"),
      client_id: "core-next-rp",
      resource_type: "client", },
    { host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"),
      client_id: "core-next-rp",
      resource_type: "visitor", },
    { host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"),
      client_id: "core-next-rp",
      resource_type: "operator", },
  ].freeze

  test "back-channel receiver revokes a matching RP session" do
    SURFACES.each do |surface|
      sid = SecureRandom.uuid
      token_record = create_session_token(surface, sid)

      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        token = forge_logout_token(surface, payload: base_logout_payload(surface, sid: sid))

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :success, surface.inspect
        assert_predicate token_record.reload, :revoked?, surface.inspect
      end
    end
  end

  test "back-channel receiver rejects invalid logout token without mutating session state" do
    SURFACES.each do |surface|
      token_record = create_session_token(surface, SecureRandom.uuid)

      post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: "invalid" }

      assert_response :bad_request, surface.inspect
      assert_not_predicate token_record.reload, :revoked?, surface.inspect
    end
  end

  test "back-channel receiver rejects non-UUID sid without mutating session state" do
    SURFACES.each do |surface|
      token_record = create_session_token(surface, SecureRandom.uuid)

      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        token = forge_logout_token(surface, payload: base_logout_payload(surface, sid: "not-a-uuid"))

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :bad_request, surface.inspect
        assert_not_predicate token_record.reload, :revoked?, surface.inspect
      end
    end
  end

  test "back-channel receiver rejects sub-only logout token without mutating session state" do
    SURFACES.each do |surface|
      token_record = create_session_token(surface, SecureRandom.uuid)

      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        payload = base_logout_payload(surface, sid: SecureRandom.uuid)
        payload.delete("sid")
        token = forge_logout_token(surface, payload: payload)

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :bad_request, surface.inspect
        assert_not_predicate token_record.reload, :revoked?, surface.inspect
      end
    end
  end

  test "back-channel receiver rejects wrong issuer without mutating session state" do
    SURFACES.each do |surface|
      token_record = create_session_token(surface, SecureRandom.uuid)

      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        payload = base_logout_payload(surface, sid: SecureRandom.uuid)
        payload["iss"] = wrong_issuer_for(surface.fetch(:resource_type))
        token = forge_logout_token(surface, payload: payload)

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :bad_request, surface.inspect
        assert_not_predicate token_record.reload, :revoked?, surface.inspect
      end
    end
  end

  test "back-channel receiver rejects wrong audience without mutating session state" do
    SURFACES.each do |surface|
      token_record = create_session_token(surface, SecureRandom.uuid)

      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        payload = base_logout_payload(surface, sid: SecureRandom.uuid)
        payload["aud"] = "unexpected-rp"
        token = forge_logout_token(surface, payload: payload)

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :bad_request, surface.inspect
        assert_not_predicate token_record.reload, :revoked?, surface.inspect
      end
    end
  end

  test "back-channel receiver rejects replayed logout token" do
    SURFACES.each do |surface|
      sid = SecureRandom.uuid
      token_record = create_session_token(surface, sid)

      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        token = forge_logout_token(surface, payload: base_logout_payload(surface, sid: sid))

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :success, surface.inspect
        assert_predicate token_record.reload, :revoked?, surface.inspect

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :bad_request, surface.inspect
        assert_predicate token_record.reload, :revoked?, surface.inspect
      end
    end
  end

  test "back-channel receiver is idempotent for unknown UUID sid" do
    SURFACES.each do |surface|
      with_oidc_key(namespace_for(surface.fetch(:resource_type))) do
        token = forge_logout_token(surface, payload: base_logout_payload(surface, sid: SecureRandom.uuid))

        post "https://#{surface.fetch(:host)}#{backchannel_logout_path(surface)}", params: { logout_token: token }

        assert_response :success, surface.inspect
      end
    end
  end

  private

  def namespace_for(resource_type)
    case resource_type
    when "operator" then "ACME_ORG"
    when "visitor" then "ACME_COM"
    else "ACME_APP"
    end
  end

  def wrong_issuer_for(resource_type)
    case resource_type
    when "operator", "visitor" then OidcIssuer.for_resource_type("client")
    else OidcIssuer.for_resource_type("visitor")
    end
  end

  def backchannel_logout_path(_surface)
    "/oidc/backchannel/logout"
  end

  def create_session_token(surface, sid)
    case surface.fetch(:resource_type)
    when "operator"
      staff = Operator.create!(public_id: Operator.generate_public_id, status_id: OperatorStatus::ACTIVE)
      token = OperatorToken.create!(
        staff: staff,
        staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
        staff_token_status_id: OperatorTokenStatus::ACTIVE,
        oidc_sid: sid,
      )
      token.rotate_refresh_token!
      token
    when "visitor"
      visitor = Visitor.create!(
        public_id: "v_#{SecureRandom.hex(8)}",
        status_id: VisitorStatus::ACTIVE,
        visibility_id: VisitorVisibility::VISITOR,
      )
      token = VisitorToken.create!(
        visitor: visitor,
        visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
        visitor_token_status_id: VisitorTokenStatus::ACTIVE,
        oidc_sid: sid,
      )
      token.rotate_refresh_token!
      token
    else
      user = Client.create!(
        public_id: "u_#{SecureRandom.hex(8)}",
        status_id: ClientStatus::ACTIVE,
        visibility_id: ClientVisibility::USER,
      )
      token = ClientToken.create!(
        user: user,
        user_token_kind_id: ClientTokenKind::BROWSER_WEB,
        user_token_status_id: ClientTokenStatus::ACTIVE,
        oidc_sid: sid,
      )
      token.rotate_refresh_token!
      token
    end
  end

  def with_oidc_key(namespace)
    key = OpenSSL::PKey::EC.generate("secp384r1")
    kid = "#{namespace.downcase.tr("_", "-")}-oidc-test"
    env = {
      "OIDC_CLIENT_#{namespace}_ACTIVE_KID" => kid,
      "OIDC_CLIENT_#{namespace}_PRIVATE_KEY" => Base64.strict_encode64(key.to_der),
    }
    previous = JitSecurityJwtRegistry.instance_variable_get(:@issuers)

    with_env(env) do
      JitSecurityJwtRegistry.reload!
      yield key, kid
    ensure
      JitSecurityJwtRegistry.instance_variable_set(:@issuers, previous)
    end
  end

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def base_logout_payload(surface, sid:)
    {
      "iss" => OidcIssuer.for_resource_type(surface.fetch(:resource_type)),
      "aud" => surface.fetch(:client_id),
      "iat" => Time.current.to_i,
      "exp" => 2.minutes.from_now.to_i,
      "jti" => SecureRandom.uuid,
      "typ" => OidcLogoutTokenCodec::TOKEN_TYPE,
      "events" => { OidcLogoutTokenCodec::EVENT_CLAIM => {} },
      "sub" => "subject-1",
      "sid" => sid,
    }
  end

  def forge_logout_token(surface, payload:)
    JitSecurityJwtKeyring.encode(
      payload,
      typ: payload["typ"].presence || OidcLogoutTokenCodec::TOKEN_TYPE,
      issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(surface.fetch(:resource_type)),
    )
  end
end
