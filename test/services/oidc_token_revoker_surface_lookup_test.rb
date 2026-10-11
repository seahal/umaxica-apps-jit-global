# typed: false
# frozen_string_literal: true

require "test_helper"

# OidcTokenRevoker resolves the record to revoke through the surface that owns
# the registered client: an operator client must never reach a visitor usage row
# and vice versa. OidcTokenRevokerCoverageTest stubs the lookups away, so these
# tests exercise them against the real per-surface ticket databases, including
# an access token bound to an OAuth usage row rather than to a parent browser
# session row.
class OidcTokenRevokerSurfaceLookupTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses,
           :client_token_binding_methods, :client_token_dbsc_statuses,
           :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses,
           :visitors, :visitor_statuses, :visitor_token_kinds, :visitor_token_statuses,
           :visitor_token_binding_methods, :visitor_token_dbsc_statuses

  test "a staff client revokes its own refresh token usage" do
    token = OperatorToken.create!(
      staff: operators(:one),
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    usage = OperatorRpSession.create!(operator_token: token, oidc_client_id: "docs_org")
    refresh_token = usage.issue_refresh_token!

    result =
      OidcClientRegistry.stub(:authenticate, true) do
        OidcTokenRevoker.call(
          token: refresh_token, client_id: "docs_org", client_secret: "secret",
          token_type_hint: "refresh_token",
        )
      end

    assert_predicate result, :success?
    assert_predicate usage.reload, :revoked?
  end

  test "a visitor client revokes its own refresh token usage" do
    token = VisitorToken.create!(
      visitor: visitors(:reserved_visitor),
      visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB,
      visitor_token_status_id: VisitorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    usage = VisitorRpSession.create!(visitor_token: token, oidc_client_id: "docs_com")
    refresh_token = usage.issue_refresh_token!

    result =
      OidcClientRegistry.stub(:authenticate, true) do
        OidcTokenRevoker.call(
          token: refresh_token, client_id: "docs_com", client_secret: "secret",
          token_type_hint: "refresh_token",
        )
      end

    assert_predicate result, :success?
    assert_predicate usage.reload, :revoked?
  end

  test "a staff refresh token is not revoked by a visitor client" do
    token = OperatorToken.create!(
      staff: operators(:one),
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    usage = OperatorRpSession.create!(operator_token: token, oidc_client_id: "docs_org")
    refresh_token = usage.issue_refresh_token!

    OidcClientRegistry.stub(:authenticate, true) do
      OidcTokenRevoker.call(
        token: refresh_token, client_id: "docs_com", client_secret: "secret",
        token_type_hint: "refresh_token",
      )
    end

    assert_not usage.reload.revoked?,
               "#{usage.public_id}: a visitor-authenticated revocation must not reach a staff usage row"
  end

  test "an access token sid that names only the parent does not revoke the parent" do
    token = ClientToken.create!(
      user: clients(:one),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
      oidc_client_id: "docs_app",
      oidc_sid: SecureRandom.uuid,
      oidc_jti: SecureRandom.uuid,
    )
    payload = { "sid" => token.oidc_sid, "jti" => token.oidc_jti }

    result =
      OidcClientRegistry.stub(:authenticate, true) do
        AuthenticationTokenService.stub(:decode_allow_expired, payload) do
          OidcTokenRevoker.call(
            token: "opaque-access-token", client_id: "docs_app", client_secret: "secret",
          )
        end
      end

    assert_predicate result, :success?
    assert_predicate token.reload, :currently_usable?
  end

  test "an access token whose jti does not match the session is not revoked" do
    token = ClientToken.create!(
      user: clients(:one),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
      oidc_client_id: "docs_app",
      oidc_sid: SecureRandom.uuid,
      oidc_jti: SecureRandom.uuid,
    )
    payload = { "sid" => token.oidc_sid, "jti" => SecureRandom.uuid }

    OidcClientRegistry.stub(:authenticate, true) do
      AuthenticationTokenService.stub(:decode_allow_expired, payload) do
        OidcTokenRevoker.call(
          token: "opaque-access-token", client_id: "docs_app", client_secret: "secret",
        )
      end
    end

    assert_not token.reload.revoked?
  end
end
