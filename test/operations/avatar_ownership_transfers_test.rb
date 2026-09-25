# typed: false
# frozen_string_literal: true

require "test_helper"

class AvatarOwnershipTransfersTest < ActiveSupport::TestCase
  setup do
    @source_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: @source_actor)
    @avatar = @source.avatar

    @target_actor = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @target_actor)
  end

  test "request creates one pending five-day transfer without changing ownership" do
    requested_at = Time.current

    transfer = request_transfer

    assert_equal "pending", transfer.state
    assert_equal requested_at.to_i, transfer.requested_at.to_i
    assert_equal requested_at.to_i + 5.days.to_i, transfer.expires_at.to_i
    assert_equal "app", transfer.from_owner_surface
    assert_equal @source.collective.public_id, transfer.from_owner_collective_public_id
    assert_equal "org", transfer.to_owner_surface
    assert_equal @target.collective.public_id, transfer.to_owner_collective_public_id
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
  end

  test "target owner accepts once and source selection no longer resolves the Avatar" do
    source_token = client_token_for(@source_actor)
    BaseSelectorAuthority.prepare(surface: :app, principal: @source_actor, session: source_token)
    BaseSwitcherAuthority.switch(
      surface: :app,
      principal: @source_actor,
      session: source_token,
      params: selector_ids(@source, @avatar),
    )
    target_token = operator_token_for(@target_actor)
    BaseSelectorAuthority.prepare(surface: :org, principal: @target_actor, session: target_token)
    transfer = request_transfer

    accepted = AvatarOwnershipTransfers::AcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      transfer_public_id: transfer.public_id,
    )

    assert_equal "accepted", accepted.state
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
    assert_equal @target.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id
    assert_equal accepted.accepted_at, @avatar.avatar_ownership_periods.order(:valid_from).last.valid_from
    assert_nil target_token.reload.selected_avatar_public_id
    assert_equal [], BaseSwitcherAuthority.current(
      surface: :app,
      principal: @source_actor,
      session: source_token,
    ).fetch(:candidates).select { |candidate| candidate.dig(:avatar, :public_id) == @avatar.public_id }

    candidates = BaseSwitcherAuthority.current(
      surface: :org,
      principal: @target_actor,
      session: target_token,
    ).fetch(:candidates)
    candidate = candidates.find { |entry| entry.dig(:avatar, :public_id) == @avatar.public_id }
    assert candidate

    BaseSwitcherAuthority.switch(
      surface: :org,
      principal: @target_actor,
      session: target_token,
      params: {
        account_public_id: candidate.fetch(:public_id),
        organization_public_id: candidate.dig(:organization, :public_id),
        organization_unit_public_id: candidate.dig(:organization, :unit_public_id),
        avatar_public_id: candidate.dig(:avatar, :public_id),
      },
    )
    assert_equal @avatar.public_id, target_token.reload.selected_avatar_public_id

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      AvatarOwnershipTransfers::AcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        transfer_public_id: transfer.public_id,
      )
    end
  end

  test "org owner can transfer to app and target can subsequently select the Avatar" do
    @client_token_for_source = ClientToken.create!(
      user: @source_actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    BaseSelectorAuthority.prepare(surface: :app, principal: @source_actor, session: @client_token_for_source)
    prior_selected_avatar_id = @client_token_for_source.reload.selected_avatar_public_id
    @source.avatar.current_avatar_persona_binding.revoke!(force: true)
    org_avatar_result = AvatarProvisioning::Create.call(
      actor: @target_actor,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Org owned Avatar" },
      handle_params: { handle: "org-owned-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )
    assert_predicate org_avatar_result, :success?, org_avatar_result.errors.inspect
    avatar = org_avatar_result.avatar
    transfer = AvatarOwnershipTransfers::RequestOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      avatar_public_id: avatar.public_id,
      target_surface: "app",
      target_collective_public_id: @source.collective.public_id,
    )

    accepted = AvatarOwnershipTransfers::AcceptOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      transfer_public_id: transfer.public_id,
    )

    assert_equal "accepted", accepted.state
    assert_equal "app", avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
    assert_equal prior_selected_avatar_id, @client_token_for_source.reload.selected_avatar_public_id
    candidate = BaseSwitcherAuthority.current(
      surface: :app,
      principal: @source_actor,
      session: @client_token_for_source,
    ).fetch(:candidates).find { |entry| entry.dig(:avatar, :public_id) == avatar.public_id }
    assert candidate
  end

  test "request rejects same owner, unsupported surface, and a member without permission" do
    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      AvatarOwnershipTransfers::RequestOperation.call(
        actor: @source_actor,
        surface: "app",
        subject_public_id: @source.account.public_id,
        avatar_public_id: @avatar.public_id,
        target_surface: "app",
        target_collective_public_id: @source.collective.public_id,
      )
    end

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      AvatarOwnershipTransfers::RequestOperation.call(
        actor: @source_actor,
        surface: "app",
        subject_public_id: @source.account.public_id,
        avatar_public_id: @avatar.public_id,
        target_surface: "com",
        target_collective_public_id: @source.collective.public_id,
      )
    end

    membership = @source.account.persona_memberships.find_by!(enterprise: @source.collective)
    membership.update!(membership_kind_id: PersonaMembershipKind::MEMBER)

    assert_raises(AvatarOwnershipTransfers::Unauthorized) { request_transfer }
    assert_equal 0, AvatarOwnershipTransfer.where(avatar: @avatar).count
  end

  test "expiry at the boundary is materialized and cannot transfer ownership" do
    transfer = request_transfer
    travel_to transfer.expires_at, with_usec: true do
      assert_raises(AvatarOwnershipTransfers::Expired) do
        AvatarOwnershipTransfers::AcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          transfer_public_id: transfer.public_id,
        )
      end
    end

    assert_equal "expired", transfer.reload.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
  end

  test "accept immediately before expiry remains valid" do
    transfer = request_transfer
    travel_to(transfer.expires_at - 1.second, with_usec: true) do
      accepted = AvatarOwnershipTransfers::AcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        transfer_public_id: transfer.public_id,
      )

      assert_equal "accepted", accepted.state
    end
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
  end

  test "accept immediately after expiry records expired state and denies ownership change" do
    transfer = request_transfer
    travel_to(transfer.expires_at + 1.second, with_usec: true) do
      assert_raises(AvatarOwnershipTransfers::Expired) do
        AvatarOwnershipTransfers::AcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          transfer_public_id: transfer.public_id,
        )
      end
    end
    assert_equal "expired", transfer.reload.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
  end

  test "source owner can cancel but cannot replay a terminal transfer" do
    transfer = request_transfer

    cancelled = AvatarOwnershipTransfers::CancelOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      transfer_public_id: transfer.public_id,
    )

    assert_equal "cancelled", cancelled.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      AvatarOwnershipTransfers::CancelOperation.call(
        actor: @source_actor,
        surface: "app",
        subject_public_id: @source.account.public_id,
        transfer_public_id: transfer.public_id,
      )
    end
  end

  test "transfer removes owner-mismatched group membership and preserves target-matched membership" do
    source_group = group_for(@source, surface: "app")
    target_group = group_for(@target, surface: "org")
    stale_membership = membership_for(source_group)
    matching_membership = membership_for(target_group)
    transfer = request_transfer

    AvatarOwnershipTransfers::AcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      transfer_public_id: transfer.public_id,
    )

    assert_equal "removed", stale_membership.reload.state
    assert_predicate stale_membership.removed_at, :present?
    assert_equal "active", matching_membership.reload.state
    assert_nil matching_membership.removed_at
  end

  private

  def request_transfer
    AvatarOwnershipTransfers::RequestOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      avatar_public_id: @avatar.public_id,
      target_surface: "org",
      target_collective_public_id: @target.collective.public_id,
    )
  end

  def group_for(bootstrap, surface:)
    group = AvatarGroup.create!(
      account_surface: surface,
      account_public_id: bootstrap.account.public_id,
      name: "#{surface}-group-#{SecureRandom.hex(4)}",
      state: "active",
    )
    AvatarGroupOwnershipPeriod.create!(
      avatar_group: group,
      owner_surface: surface,
      owner_collective_public_id: bootstrap.collective.public_id,
      valid_from: Time.current,
    )
    group
  end

  def membership_for(group)
    GroupAvatarMembership.create!(
      avatar_group: group,
      avatar: @avatar,
      role: GroupAvatarMembership::ROLE,
      position: 0,
      state: "active",
    )
  end

  def client_token_for(actor)
    ClientToken.create!(user: actor, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  def operator_token_for(actor)
    OperatorToken.create!(staff: actor, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
  end

  def selector_ids(bootstrap, avatar)
    {
      account_public_id: bootstrap.account.public_id,
      organization_public_id: bootstrap.collective.public_id,
      organization_unit_public_id: bootstrap.unit.public_id,
      avatar_public_id: avatar.public_id,
    }
  end
end
