# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::AvatarOwnershipTransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    @operator = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @source = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @operator)
    @token = OperatorToken.create!(staff: @operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    BaseSelectorAuthority.prepare(surface: :org, principal: @operator, session: @token)
    @avatar_result = AvatarProvisioning::Create.call(
      actor: @operator,
      subject_type: :agent,
      subject: @source.account,
      avatar_params: { moniker: "Bureau Avatar" },
      handle_params: { handle: "bureau-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @source.collective.public_id,
    )

    assert_predicate @avatar_result, :success?, @avatar_result.errors.inspect
    select_source_avatar!

    @target_client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @target = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @target_client)
  end

  test "org owner can request app transfer and cancel only with cancel scope" do
    grant_step_up!("avatar_transfer_request")
    post base_org_avatar_ownership_transfers_url(host: @host, ri: "jp"),
         params: {
           target_surface: "app",
           target_collective_public_id: @target.collective.public_id,
         },
         headers: as_staff_headers(@operator, host: @host, session_public_id: @token.public_id), as: :json

    assert_response :success
    transfer_id = response.parsed_body.fetch("transfer_public_id")
    transfer = AvatarOwnershipTransfer.find_by!(public_id: transfer_id)

    assert_equal "org", transfer.from_owner_surface
    assert_equal "app", transfer.to_owner_surface
    assert_equal @avatar_result.avatar.id, transfer.avatar_id

    grant_step_up!("avatar_transfer_cancel")
    post base_org_cancel_avatar_ownership_transfer_url(transfer_id, host: @host),
         headers: as_staff_headers(@operator, host: @host, session_public_id: @token.public_id), as: :json

    assert_response :success
    assert_equal "cancelled", response.parsed_body.fetch("status")
    assert_equal "org", @avatar_result.avatar.reload.current_ownership_period.owner_surface
  end

  test "URL-provided Avatar cannot replace a nil selected Avatar" do
    assert_nil @source.avatar
    @token.update!(selected_avatar_public_id: nil)
    grant_step_up!("avatar_transfer_request")

    assert_no_difference -> { AvatarOwnershipTransfer.count } do
      post base_org_avatar_ownership_transfers_url(host: @host),
           params: {
             avatar_public_id: @avatar_result.avatar.public_id,
             target_surface: "app",
             target_collective_public_id: @target.collective.public_id,
           },
           headers: as_staff_headers(@operator, host: @host, session_public_id: @token.public_id), as: :json

      assert_response :forbidden
    end
  end

  private

  def select_source_avatar!
    BaseSwitcherAuthority.switch(
      surface: :org,
      principal: @operator,
      session: @token,
      params: {
        account_public_id: @source.account.public_id,
        organization_public_id: @source.collective.public_id,
        organization_unit_public_id: @source.unit.public_id,
        avatar_public_id: @avatar_result.avatar.public_id,
      },
    )
  end

  def grant_step_up!(scope)
    @token.update!(
      last_step_up_at: Time.current,
      last_step_up_scope: scope,
      last_step_up_aal: nil,
      last_step_up_method: "passkey",
      last_step_up_session_public_id: @token.public_id,
      last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:org",
    )
  end
end
