# typed: false
# frozen_string_literal: true

require "test_helper"

# Jump refuses an rt whose url origin equals its iss. Each Base self-RP (base-{app,com,org}-ww)
# shares its origin with its authority and callback, so those moves go by path; cross-origin targets
# keep using Jump.
class BaseSameOriginHandoffTest < ActionDispatch::IntegrationTest
  SURFACES = [
    { tld: "app", host_env: "PUBLIC_BASE_SERVICE_URL", core_client_id: "core-app-jp" },
    { tld: "com", host_env: "PUBLIC_BASE_CORPORATE_URL", core_client_id: "core-com-jp" },
    { tld: "org", host_env: "PUBLIC_BASE_STAFF_URL", core_client_id: "core-org-jp" },
  ].freeze

  setup do
    ClientIdentityState.ensure_defaults!
    VisitorIdentityState.ensure_defaults!
    OperatorIdentityState.ensure_defaults!
  end

  test "Base sign entry POST moves to its own authorize endpoint without Jump on every surface" do
    SURFACES.each do |surface|
      base_host = ENV.fetch(surface.fetch(:host_env))
      host! base_host
      https!

      post "/sign", params: { ri: "jp" }, headers: {
        "Origin" => "https://#{base_host}", "Sec-Fetch-Site" => "same-origin",
      }

      assert_response :see_other, base_host
      target = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(target.query)

      assert_equal "https", target.scheme, base_host
      assert_equal base_host, target.host
      assert_equal "/oauth/authorize", target.path, base_host
      assert_nil query["rt"], base_host
      assert_equal "base-#{surface.fetch(:tld)}-ww", query.fetch("client_id")
      assert_equal "https://#{base_host}/oidc/callback", query.fetch("redirect_uri")
      assert_equal "S256", query.fetch("code_challenge_method"), base_host
      assert_predicate query.fetch("state"), :present?, base_host
    end
  end

  test "Base prompt none returns login_required to the same-origin self-RP callback without Jump" do
    SURFACES.each do |surface|
      base_host = ENV.fetch(surface.fetch(:host_env))
      host! base_host
      https!
      state = SecureRandom.urlsafe_base64(32)

      get "/oauth/authorize", params: {
        response_type: "code",
        client_id: "base-#{surface.fetch(:tld)}-ww",
        redirect_uri: "https://#{base_host}/oidc/callback",
        scope: "openid profile",
        state: state,
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)), padding: false),
        code_challenge_method: "S256",
        prompt: "none",
        ri: "jp",
      }

      assert_response :found, base_host
      callback = URI.parse(response.location)
      query = Rack::Utils.parse_nested_query(callback.query)

      assert_equal base_host, callback.host
      assert_equal "/oidc/callback", callback.path, base_host
      assert_nil query["rt"], base_host
      assert_equal "login_required", query.fetch("error"), base_host
      assert_equal state, query.fetch("state"), base_host
    end
  end

  test "Base prompt none still hands login_required for a cross-origin Core callback to Jump" do
    SURFACES.each do |surface|
      base_host = ENV.fetch(surface.fetch(:host_env))
      core_callback = OidcClientRegistry.find!(surface.fetch(:core_client_id)).redirect_uris.first
      host! base_host
      https!

      get "/oauth/authorize", params: {
        response_type: "code",
        client_id: surface.fetch(:core_client_id),
        redirect_uri: core_callback,
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)), padding: false),
        code_challenge_method: "S256",
        prompt: "none",
        ri: "jp",
      }

      assert_response :found, base_host
      gateway = URI.parse(response.location)
      rt = Rack::Utils.parse_nested_query(gateway.query).fetch("rt")
      payload, = JWT.decode(rt, nil, false)
      target = URI.parse(payload.fetch("url"))

      assert_equal "jump.umaxica.net", gateway.host
      assert_equal "https://#{base_host}", payload.fetch("iss")
      assert_equal URI.parse(core_callback).host, target.host
      assert_equal "/oidc/callback", target.path, base_host
    end
  end

  test "Base app authorize returns a base-app-ww code to the same-origin callback without Jump" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    host! base_host
    https!
    user = clients(:one)
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, authentication_event_at: Time.current,
    )
    access_token = AuthenticationToken.encode(
      user, host: base_host, session_public_id: token.public_id, resource_type: "client",
            jwt_issuer_id: JitSecurityJwtRegistry.surface("BASE_APP").id,
    )
    state = SecureRandom.urlsafe_base64(32)

    get "/oauth/authorize", params: {
      response_type: "code",
      client_id: "base-app-ww",
      redirect_uri: "https://#{base_host}/oidc/callback",
      scope: "openid profile",
      state: state,
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)), padding: false),
      code_challenge_method: "S256",
      ri: "jp",
    }, headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :found
    callback = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(callback.query)

    assert_equal "https", callback.scheme
    assert_equal base_host, callback.host
    assert_equal "/oidc/callback", callback.path
    assert_nil query["rt"]
    assert_predicate query.fetch("code"), :present?
    assert_equal state, query.fetch("state")
  end

  test "Base com authorize returns a base-com-ww code to the same-origin callback without Jump" do
    base_host = ENV.fetch("PUBLIC_BASE_CORPORATE_URL")
    host! base_host
    https!
    visitor = visitors(:reserved_visitor)
    token = VisitorToken.create!(
      authentication_epoch: 0,
      visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      authentication_event_at: Time.current,
    )
    access_token = AuthenticationToken.encode(
      visitor, host: base_host, session_public_id: token.public_id, resource_type: "visitor",
               jwt_issuer_id: JitSecurityJwtRegistry.surface("BASE_COM").id,
    )
    state = SecureRandom.urlsafe_base64(32)

    get "/oauth/authorize", params: {
      response_type: "code",
      client_id: "base-com-ww",
      redirect_uri: "https://#{base_host}/oidc/callback",
      scope: "openid profile",
      state: state,
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)), padding: false),
      code_challenge_method: "S256",
      ri: "jp",
    }, headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :found
    callback = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(callback.query)

    assert_equal base_host, callback.host
    assert_equal "/oidc/callback", callback.path
    assert_nil query["rt"]
    assert_predicate query.fetch("code"), :present?
    assert_equal state, query.fetch("state")
  end

  test "Base org authorize returns a base-org-ww code to the same-origin callback without Jump" do
    base_host = ENV.fetch("PUBLIC_BASE_STAFF_URL")
    host! base_host
    https!
    operator = operators(:one)
    token = OperatorToken.create!(
      authentication_epoch: 0,
      staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE, discard_at: 1.day.from_now,
      authentication_event_at: Time.current,
    )
    access_token = AuthenticationToken.encode(
      operator, host: base_host, session_public_id: token.public_id, resource_type: "operator",
                jwt_issuer_id: JitSecurityJwtRegistry.surface("BASE_ORG").id,
    )
    state = SecureRandom.urlsafe_base64(32)

    get "/oauth/authorize", params: {
      response_type: "code",
      client_id: "base-org-ww",
      redirect_uri: "https://#{base_host}/oidc/callback",
      scope: "openid profile",
      state: state,
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)), padding: false),
      code_challenge_method: "S256",
      ri: "jp",
    }, headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :found
    callback = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(callback.query)

    assert_equal base_host, callback.host
    assert_equal "/oidc/callback", callback.path
    assert_nil query["rt"]
    assert_predicate query.fetch("code"), :present?
    assert_equal state, query.fetch("state")
  end

  test "Base app authorize still hands a cross-origin Core code callback to Jump" do
    base_host = ENV.fetch("PUBLIC_BASE_SERVICE_URL")
    core_callback = OidcClientRegistry.find!("core-app-jp").redirect_uris.first
    host! base_host
    https!
    user = clients(:one)
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE, authentication_event_at: Time.current,
    )
    access_token = AuthenticationToken.encode(
      user, host: base_host, session_public_id: token.public_id, resource_type: "client",
            jwt_issuer_id: JitSecurityJwtRegistry.surface("BASE_APP").id,
    )

    get "/oauth/authorize", params: {
      response_type: "code",
      client_id: "core-app-jp",
      redirect_uri: core_callback,
      scope: "openid profile",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest(SecureRandom.urlsafe_base64(48)), padding: false),
      code_challenge_method: "S256",
      ri: "jp",
    }, headers: { "Authorization" => "Bearer #{access_token}" }

    assert_response :found
    gateway = URI.parse(response.location)
    rt = Rack::Utils.parse_nested_query(gateway.query).fetch("rt")
    payload, = JWT.decode(rt, nil, false)
    target = URI.parse(payload.fetch("url"))

    assert_equal "jump.umaxica.net", gateway.host
    assert_equal "https://#{base_host}", payload.fetch("iss")
    assert_equal URI.parse(core_callback).host, target.host
    assert_equal "/oidc/callback", target.path
  end
end
