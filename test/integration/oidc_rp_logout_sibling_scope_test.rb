# frozen_string_literal: true

require "test_helper"
require_relative "../support/browser_rp_logout_flow_helper"

# D-33: confirming a signed RP logout hint stops the current Root Session and every sibling grant,
# emits one durable BCL participant for each live grant, and leaves unrelated roots intact.
class OidcRpLogoutSiblingScopeTest < ActionDispatch::IntegrationTest
  include BrowserRpLogoutFlowHelper

  setup do
    @visa_host = visa_host_for_test_surface(:app)
    @warp_host = ENV.fetch("PUBLIC_WARP_SERVICE_URL")
    https!
    @user = clients(:one)
    @root_token = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    @core_session = create_rp_session("core-app-jp")
  end

  test "zero siblings: the parent and the origin row are revoked" do
    sign_out_globally

    assert_not_predicate @root_token.reload, :currently_usable?
    assert_predicate @core_session.reload, :revoked?
  end

  test "one sibling is revoked with the parent" do
    sibling = create_rp_session("warp-app-jp")

    sign_out_globally

    assert_predicate sibling.reload, :revoked?
  end

  test "several siblings are revoked with the parent and another parent stays intact" do
    siblings = %w(warp-app-jp palm-app-jp).map { |client_id| create_rp_session(client_id) }
    other_root = ClientToken.create!(
      authentication_epoch: 0,
      user: @user,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    other_child = create_rp_session("warp-app-jp", root_token: other_root)

    sign_out_globally

    siblings.each { |sibling| assert_predicate sibling.reload, :revoked? }
    assert_predicate other_root.reload, :currently_usable?
    assert_predicate other_child.reload, :active?
  end

  test "an already-revoked historical row keeps its original revocation" do
    historical = create_rp_session("warp-app-jp")
    OpAuthorityStopCommitter.stop_grant(
      grant: historical,
      cause: "token_revocation",
      principal_public_id: @user.public_id,
      authority_evidence_ref: "test:historical-rp-grant",
    )
    revoked_at = historical.reload.revoked_at

    travel 1.minute do
      sign_out_globally
    end

    assert_equal revoked_at, historical.reload.revoked_at
  end

  test "a root stop sends a signed back-channel logout to each sibling grant" do
    sibling = create_rp_session("warp-app-jp")
    local_session = create_local_warp_session!(sibling)

    sign_out_globally

    stop_target = OpAppAuthorityStopRootTarget.find_by!(root: @root_token)
    stop = OpAppAuthorityStop.find(stop_target.stop_id)
    participant = OpAppAuthorityStopParticipant.find_by!(stop:, grant: sibling)

    assert_equal "warp-app-jp", participant.client_id
    assert_equal sibling.public_id, participant.sid
    assert_equal "pending", OpAuthorityStopReference::PARTICIPANT_STATUSES.key(participant.status_id)

    deliver_warp_backchannel_logout!(sibling)

    assert_not_nil local_session.reload.revoked_at
    assert_not_nil RpWarpAppOpSessionBinding.find_by!(sid: sibling.public_id).revoked_at
  end

  test "positive control: the sibling credentials are accepted before the sign-out" do
    sibling = create_rp_session("warp-app-jp")
    create_local_warp_session!(sibling)
    access, refresh = warp_credentials(sibling)

    reset!
    https!
    host!(@warp_host)
    cookies[OidcRpBrowserCredentialContract::ACCESS_COOKIE] = access
    cookies[OidcRpBrowserCredentialContract::REFRESH_COOKIE] = refresh
    get "/dashboard"

    assert_response :success
  end
end
