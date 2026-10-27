# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_rp_logout_hint_helper"

class OidcLogoutRealmAcceptanceTest < ActionDispatch::IntegrationTest
  include OidcRpLogoutHintHelper

  fixtures :clients, :visitors, :operators, :client_token_kinds, :visitor_token_kinds, :operator_token_kinds

  test "APP logout preserves COM and ORG sessions and refuses a COM hint at APP" do
    client = clients(:one)
    visitor = visitors(:reserved_visitor)
    operator = operators(:one)
    app = ClientToken.create!(authentication_epoch: 0, user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    com = VisitorToken.create!(authentication_epoch: 0, visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    org = OperatorToken.create!(authentication_epoch: 0, staff: operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    grant = OpComGrant.create!(
      authentication_epoch: 0, visitor_token: com, oidc_client_id: "core-com-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    store_oidc_rp_logout_hint!(grant, visitor, OidcClientRegistry.find!(grant.oidc_client_id))
    host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    browser = open_session
    browser.host!(host)
    browser.https!
    access = AuthenticationToken.encode(
      client, host: host, resource_type: "client", session_public_id: app.device_session.public_id,
              oidc_sid: app.device_session.public_id, oidc_jti: app.oidc_jti,
              jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
              authentication_context: app.authentication_context_value.to_s,
    )
    browser.cookies << Rack::Test::Cookie.new(
      "#{AuthenticationBase::ACCESS_COOKIE_KEY}=#{Rack::Utils.escape(access)}", URI.parse("https://#{host}/"),
    )
    browser.get(
      "/oidc/logout",
      params: { client_id: grant.oidc_client_id, id_token_hint: grant.logout_hint.id_token, ri: "jp" },
    )

    assert_equal 400, browser.response.status
    assert_nil browser.response.location
    assert_predicate com.reload, :currently_usable?
    assert_predicate org.reload, :currently_usable?
    assert_predicate grant.reload, :active?

    browser.post("/oidc/logout", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    browser.post("/oidc/logout/confirmation?ri=jp")

    assert_equal 303, browser.response.status
    assert_predicate app.reload, :revoked?
    assert_predicate com.reload, :currently_usable?
    assert_predicate org.reload, :currently_usable?
    assert_predicate grant.reload, :active?
  end
end
