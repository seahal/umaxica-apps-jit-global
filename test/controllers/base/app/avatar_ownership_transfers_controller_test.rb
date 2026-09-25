# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::AvatarOwnershipTransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost")
    @client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @client)
    @client_token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :app, principal: @client, session: @client_token)

    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    @operator_token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @operator_token)
  end

  test "request requires its own Step-Up scope and preserves the selected Avatar" do
    selected_avatar_id = @client_token.reload.selected_avatar_public_id
    grant_step_up!(@client_token, scope: "avatar_transfer_accept", surface: "app")

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
           params: request_params.merge(avatar_public_id: "attacker-selected-avatar"),
           headers: as_user_headers(@client, host: @host, session_public_id: @client_token.public_id), as: :json

      assert_response :unprocessable_content
    end
    assert_equal selected_avatar_id, @client_token.reload.selected_avatar_public_id

    grant_step_up!(@client_token, scope: "avatar_transfer_request", surface: "app")
    post base_app_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: request_params.merge(avatar_public_id: "attacker-selected-avatar"),
         headers: as_user_headers(@client, host: @host, session_public_id: @client_token.public_id), as: :json

    assert_response :success
    transfer = AvatarOwnershipTransfer.find_by!(public_id: response.parsed_body.fetch("transfer_public_id"))
    assert_equal "pending", transfer.state
    assert_equal @source.avatar.id, transfer.avatar_id
    assert_equal selected_avatar_id, @client_token.reload.selected_avatar_public_id
  end

  test "request is denied without Step-Up" do
    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_app_avatar_ownership_transfers_url(host: @host),
           params: request_params,
           headers: as_user_headers(@client, host: @host, session_public_id: @client_token.public_id), as: :json

      assert_response :unprocessable_content
    end
  end

  test "org target accepts with its operation-specific Step-Up and no AAL floor" do
    grant_step_up!(@client_token, scope: "avatar_transfer_request", surface: "app")
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: as_user_headers(@client, host: @host, session_public_id: @client_token.public_id), as: :json
    assert_response :success
    transfer_id = response.parsed_body.fetch("transfer_public_id")

    grant_step_up!(@operator_token, scope: "avatar_transfer_accept", surface: "org", method: "passkey")
    post base_org_accept_avatar_ownership_transfer_url(transfer_id, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"), ri: "jp"),
         headers: as_staff_headers(@operator, host: ENV.fetch("PUBLIC_BASE_STAFF_URL"),
                                   session_public_id: @operator_token.public_id), as: :json

    assert_response :success
    assert_equal "accepted", response.parsed_body.fetch("status")
    assert_nil @operator_token.reload.selected_avatar_public_id
    assert_equal "org", @source.avatar.reload.current_ownership_period.owner_surface
    assert_nil @operator_token.selected_avatar_public_id
  end

  test "source cancellation requires the cancellation scope" do
    grant_step_up!(@client_token, scope: "avatar_transfer_request", surface: "app")
    post base_app_avatar_ownership_transfers_url(host: @host),
         params: request_params,
         headers: as_user_headers(@client, host: @host, session_public_id: @client_token.public_id), as: :json
    transfer_id = response.parsed_body.fetch("transfer_public_id")

    grant_step_up!(@client_token, scope: "avatar_transfer_request", surface: "app")
    post base_app_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: as_user_headers(@client, host: @host, session_public_id: @client_token.public_id), as: :json

    assert_response :unprocessable_content
    assert_equal "pending", AvatarOwnershipTransfer.find_by!(public_id: transfer_id).state

    grant_step_up!(@client_token, scope: "avatar_transfer_cancel", surface: "app")
    post base_app_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: as_user_headers(@client, host: @host, session_public_id: @client_token.public_id), as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
  end

  private

  def request_params
    {
      target_surface: "org",
      target_collective_public_id: @target.collective.public_id,
    }
  end

  def grant_step_up!(token, scope:, surface:, method: "totp")
    token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: scope,
      last_step_up_aal: nil,
      last_step_up_method: method,
      last_step_up_session_public_id: token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:#{surface}",
    )
  end
end
