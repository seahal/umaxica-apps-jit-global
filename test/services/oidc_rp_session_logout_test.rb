# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcRpSessionLogoutTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses, :operator_token_kinds, :operator_token_statuses,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  test "a RP Session sid revokes only that RP Session" do
    operator = operators(:one)
    browser_session = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    rp_session = OperatorRpSession.create!(operator_token: browser_session, oidc_client_id: "org-console-rp")
    rp_session.issue_refresh_token!

    assert OidcRpSessionLogout.call(
      resource_type: "operator",
      client_id: "org-console-rp",
      sid: rp_session.public_id,
      reason: "oidc_backchannel_logout",
    )

    assert_predicate rp_session.reload, :revoked?
    assert_equal "success", rp_session.reload.last_logout_status
    assert_not_predicate browser_session.reload, :revoked?
  end

  test "a different client cannot revoke a RP Session by its sid" do
    operator = operators(:one)
    browser_session = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
      oidc_client_id: "org-console-rp",
    )
    rp_session = OperatorRpSession.create!(operator_token: browser_session, oidc_client_id: "org-console-rp")
    rp_session.issue_refresh_token!

    assert_not OidcRpSessionLogout.call(
      resource_type: "operator",
      client_id: "another-org-rp",
      sid: rp_session.public_id,
      reason: "oidc_backchannel_logout",
    )

    assert_not_predicate rp_session.reload, :revoked?
    assert_not_predicate browser_session.reload, :revoked?
  end

  test "a legacy parent sid uses the parent logout primitive" do
    operator = operators(:one)
    browser_session = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
      oidc_client_id: "org-console-rp",
      oidc_sid: SecureRandom.uuid,
    )

    assert OidcRpSessionLogout.call(
      resource_type: "operator",
      client_id: "org-console-rp",
      sid: browser_session.oidc_sid,
      reason: "oidc_backchannel_logout",
    )

    assert_predicate browser_session.reload, :revoked?
  end

  test "an expired RP refresh window does not prevent back-channel revocation" do
    operator = operators(:one)
    browser_session = OperatorToken.create!(
      staff: operator,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      discarded_at: 1.day.from_now,
    )
    rp_session = OperatorRpSession.create!(
      operator_token: browser_session,
      oidc_client_id: "org-console-rp",
      refresh_token_expires_at: 1.minute.ago,
    )

    assert OidcRpSessionLogout.call(
      resource_type: "operator",
      client_id: "org-console-rp",
      sid: rp_session.public_id,
      reason: "oidc_backchannel_logout",
    )

    assert_predicate rp_session.reload, :revoked?
  end
end
