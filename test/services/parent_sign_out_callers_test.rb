# frozen_string_literal: true

require "test_helper"

# AT-003 / DEC-082: every way a parent ends revokes the parent and every unrevoked RP row of that
# parent together, and enqueues no delivery job. Each case enters through the caller's own public
# boundary; the shared primitive's atomicity and rollback are covered in
# test/controllers/concerns/authentication/logout_current_session_test.rb.
class ParentSignOutCallersTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = clients(:one)
    AuthenticationSessionRevoker.tokens_for(@user).find_each(&:revoke!)
    @root = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @children = %w(core-app-jp warp-app-jp).map { |client_id| rp_session_for(@root, client_id) }
  end

  test "selected-session revocation ends the selected parent with its RP rows and leaves the current one" do
    current = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    current_child = rp_session_for(current, "core-app-jp")

    assert_no_enqueued_jobs do
      AuthenticationSelectedSessionRevoker.call(owner: @user, token: @root, current_token: current)
    end

    assert_parent_and_children_revoked
    assert_predicate current.reload, :currently_usable?
    assert_predicate current_child.reload, :active?
  end

  test "sign-out of all sessions ends every parent with its RP rows" do
    assert_no_enqueued_jobs { AuthenticationLogoutAllSessions.call(user: @user) }

    assert_parent_and_children_revoked
  end

  test "account-level emergency revocation ends the parent with its RP rows" do
    assert_no_enqueued_jobs do
      AccountSessionRevocation.emergency_revoke!(
        account: @user, operator: operators(:one),
        reason_code: "support_request",
      )
    end

    assert_parent_and_children_revoked
  end

  test "administrative risk revocation ends the parent with its RP rows" do
    assert_no_enqueued_jobs { SignRiskEnforcer.revoke!(@user) }

    assert_parent_and_children_revoked
  end

  test "a credential transition that revokes other sessions ends their parents with their RP rows" do
    current = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_no_enqueued_jobs do
      CredentialSecurityTransition.call(
        actor: @user, current_session: current, reason: :password_changed, affected_surface: :app,
        revoke_other_sessions: true,
      )
    end

    assert_parent_and_children_revoked
    assert_predicate current.reload, :currently_usable?
  end

  private

  def rp_session_for(root, client_id)
    OpAppGrant.create!(
      client_token: root,
      oidc_client_id: client_id,
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )
  end

  def assert_parent_and_children_revoked
    assert_not_predicate @root.reload, :currently_usable?
    assert_predicate @root.device_session.reload, :revoked?
    @children.each { |child| assert_predicate child.reload, :revoked? }
  end
end
