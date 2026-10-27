# frozen_string_literal: true

require "test_helper"

class Wu44RootEpochRevocationContractTest < ActiveSupport::TestCase
  fixtures :clients, :client_token_statuses, :client_token_kinds

  test "A44-6 single-root sign-out leaves the actor epoch and another browser root current" do
    user = clients(:one)
    epoch = user.authentication_epoch
    signed_out_root = ClientToken.create!(
      authentication_epoch: epoch,
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_root = ClientToken.create!(
      authentication_epoch: epoch,
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      resource: user,
      token: signed_out_root,
      reason: "A44-6-single-root",
    )

    assert_predicate signed_out_root.reload, :revoked?
    assert_equal epoch, user.reload.authentication_epoch
    assert_predicate other_root.reload, :currently_usable?
    browser_token = jwt_access_token_for(
      user,
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      session_public_id: other_root.public_id,
      resource_type: "client",
    )
    browser_result = AuthenticationCurrentResourceResolver.new(
      access_token: browser_token,
      request_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      resource_type: "client",
      resource_class: Client,
      token_class: ClientToken,
      jwt_issuer_id: "surface:BASE_APP",
    ).call

    assert_predicate browser_result, :success?
    assert_equal other_root.public_id, browser_result.token_public_id
  end

  test "A44-6 OIDC token revocation leaves another browser root current without advancing the actor epoch" do
    user = clients(:one)
    epoch = user.authentication_epoch
    revoked_grant_root = ClientToken.create!(
      authentication_epoch: epoch,
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_root = ClientToken.create!(
      authentication_epoch: epoch,
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    grant = OpAppGrant.create!(
      authentication_epoch: epoch,
      client_token: revoked_grant_root,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = grant.issue_refresh_token!

    result =
      OidcClientRegistry.stub(:authenticate, true) do
        OidcTokenRevoker.call(
          token: refresh_token,
          client_id: "core-app-jp",
          client_secret: "test-client-secret",
          token_type_hint: "refresh_token",
        )
      end

    assert_predicate result, :success?
    assert_predicate grant.reload, :revoked?
    assert_predicate revoked_grant_root.reload, :currently_usable?
    assert_equal epoch, user.reload.authentication_epoch
    browser_token = jwt_access_token_for(
      user,
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      session_public_id: other_root.public_id,
      resource_type: "client",
    )
    browser_result = AuthenticationCurrentResourceResolver.new(
      access_token: browser_token,
      request_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      resource_type: "client",
      resource_class: Client,
      token_class: ClientToken,
      jwt_issuer_id: "surface:BASE_APP",
    ).call

    assert_predicate browser_result, :success?
    assert_equal other_root.public_id, browser_result.token_public_id
  end

  test "A44-6 refresh reuse revokes only the grant and leaves another browser root current" do
    user = clients(:one)
    epoch = user.authentication_epoch
    reused_grant_root = ClientToken.create!(
      authentication_epoch: epoch,
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_root = ClientToken.create!(
      authentication_epoch: epoch,
      user: user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    grant = OpAppGrant.create!(
      authentication_epoch: epoch,
      client_token: reused_grant_root,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      refresh_token_expires_at: 1.hour.from_now,
    )
    first_refresh_token = grant.issue_refresh_token!

    rotation = OidcRefreshTokenIssuer.call(refresh_token: first_refresh_token, resource_type: "client")
    replay = OidcRefreshTokenIssuer.call(refresh_token: first_refresh_token, resource_type: "client")

    assert_predicate rotation, :success?
    assert_equal :refresh_token_reuse_detected, replay.reason
    assert_predicate grant.reload, :revoked?
    assert_predicate reused_grant_root.reload, :currently_usable?
    assert_equal epoch, user.reload.authentication_epoch
    browser_token = jwt_access_token_for(
      user,
      host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      session_public_id: other_root.public_id,
      resource_type: "client",
    )
    browser_result = AuthenticationCurrentResourceResolver.new(
      access_token: browser_token,
      request_host: ENV.fetch("PUBLIC_BASE_SERVICE_URL"),
      resource_type: "client",
      resource_class: Client,
      token_class: ClientToken,
      jwt_issuer_id: "surface:BASE_APP",
    ).call

    assert_predicate browser_result, :success?
    assert_equal other_root.public_id, browser_result.token_public_id
  end
end
