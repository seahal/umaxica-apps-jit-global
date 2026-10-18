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
    transfer = request_transfer

    assert_equal "pending", transfer.state
    assert_equal transfer.requested_at.to_i + 5.days.to_i, transfer.expires_at.to_i
    assert_equal "app", transfer.from_owner_surface
    assert_equal @source.collective.public_id, transfer.from_owner_collective_public_id
    assert_equal "org", transfer.to_owner_surface
    assert_equal @target.collective.public_id, transfer.to_owner_collective_public_id
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
  end

  test "registry request reserves a concrete operation and replays by idempotency key" do
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39"
    attributes = {
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      avatar_public_id: @avatar.public_id,
      target_surface: "org",
      target_collective_public_id: @target.collective.public_id,
      idempotency_key: key,
      request_fingerprint: registry_request_fingerprint,
    }

    first = AvatarOwnershipTransfers::RegistryRequestOperation.call(**attributes)
    second = AvatarOwnershipTransfers::RegistryRequestOperation.call(**attributes)

    assert_equal first.id, second.id
    assert_equal "pending", first.state
    assert_equal "enterprise_to_bureau", first.operation_kind
    assert_equal @avatar.id, first.avatar_id
    assert_equal @avatar.enterprise_ownership_periods.current.first.id,
                 first.enterprise_to_bureau_detail.source_ownership_period_id
    assert_equal @source.collective.public_id, first.enterprise_to_bureau_detail.source_enterprise_public_id
    assert_equal @target.collective.public_id, first.enterprise_to_bureau_detail.destination_bureau_public_id
    assert_equal @source_actor.public_id, first.enterprise_to_bureau_detail.request_actor_public_id
    assert_equal 1, AvatarTransferReservation.where(id: first.id).count
  end

  test "registry idempotency key is bound to the authenticated initiator" do
    reservation = registry_request
    other_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      AvatarOwnershipTransfers::RegistryRequestOperation.call(
        actor: other_actor,
        surface: "app",
        subject_public_id: @source.account.public_id,
        avatar_public_id: @avatar.public_id,
        target_surface: "org",
        target_collective_public_id: @target.collective.public_id,
        idempotency_key: reservation.idempotency_key,
        request_fingerprint: registry_request_fingerprint,
      )
    end
  end

  test "registry request rejects a caller supplied fingerprint that is not derived from the request" do
    key = "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a46"
    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      AvatarOwnershipTransfers::RegistryRequestOperation.call(
        actor: @source_actor,
        surface: "app",
        subject_public_id: @source.account.public_id,
        avatar_public_id: @avatar.public_id,
        target_surface: "org",
        target_collective_public_id: @target.collective.public_id,
        idempotency_key: key,
        request_fingerprint: Digest::SHA256.hexdigest("attacker-controlled-input"),
      )
    end

    assert_not AvatarTransferReservation.exists?(idempotency_key: key)
  end

  test "source owner cancels a pending registry reservation without changing ownership" do
    reservation = registry_request

    cancelled = AvatarOwnershipTransfers::RegistryCancelOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal "cancelled", cancelled.state
    assert_predicate cancelled.completed_at, :present?
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      AvatarOwnershipTransfers::RegistryCancelOperation.call(
        actor: @source_actor,
        surface: "app",
        subject_public_id: @source.account.public_id,
        reservation_public_id: reservation.public_id,
      )
    end
  end

  test "target owner accepts a registry reservation and advances the concrete ownership generation" do
    reservation = registry_request
    source_period = @avatar.enterprise_ownership_periods.current.first

    accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal "accepted", accepted.state
    assert_predicate accepted.completed_at, :present?
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
    assert_equal @target.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id
    assert_not_equal Float::INFINITY, source_period.reload.valid_to
    bureau_periods = AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).current

    assert_equal source_period.valid_to, bureau_periods.first.valid_from
    assert_equal @target.collective.public_id,
                 bureau_periods.first.bureau_public_id
    assert_equal accepted.completed_at,
                 AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: accepted.id).accepted_at
    assert_equal @target_actor.public_id,
                 AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: accepted.id)
                   .accept_actor_public_id
    assert_equal @target_actor.public_id,
                 bureau_periods.first.transferred_by_actor_public_id
  end

  test "registry acceptance after cutover writes only the concrete ownership source" do
    # This slice commits through the Avatar connection, which is intentionally outside the
    # ordinary fixture transaction. Build a private source actor/avatar so a pending reservation
    # from another committed test cannot make the one-pending-per-Avatar invariant collide here.
    source_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    source = BaseSelectorBootstrapAuthority.call(surface: :app, principal: source_actor)
    avatar = source.avatar

    AvatarRecord.transaction(joinable: false) do
      reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
        actor: source_actor,
        surface: "app",
        subject_public_id: source.account.public_id,
        avatar_public_id: avatar.public_id,
        target_surface: "org",
        target_collective_public_id: @target.collective.public_id,
        idempotency_key: SecureRandom.uuid,
        request_fingerprint: registry_request_fingerprint(
          actor: source_actor,
          subject_public_id: source.account.public_id,
          avatar_public_id: avatar.public_id,
          target_collective_public_id: @target.collective.public_id,
        ),
      )
      legacy_period_count = avatar.avatar_ownership_periods.count

      AvatarOwnershipCutover.create!(
        id: AvatarOwnershipCutover::CUTOVER_ID,
        cutover_at: Time.utc(2030, 1, 1),
      )

      target_group = GroupManagement::Create.call(
        account_surface: "org",
        account_public_id: @target.account.public_id,
        owner_surface: "org",
        owner_collective_public_id: @target.collective.public_id,
        actor: @target_actor,
        subject_public_id: @target.account.public_id,
        name: "Concrete destination group",
      )
      source_group = GroupManagement::Create.call(
        account_surface: "app",
        account_public_id: source.account.public_id,
        owner_surface: "app",
        owner_collective_public_id: source.collective.public_id,
        actor: source_actor,
        subject_public_id: source.account.public_id,
        name: "Concrete former-owner group",
      )
      target_membership = GroupAvatarMembership.create!(
        avatar_group: target_group,
        avatar: avatar,
        role: GroupAvatarMembership::ROLE,
        position: 0,
        state: "active",
      )
      source_membership = GroupAvatarMembership.create!(
        avatar_group: source_group,
        avatar: avatar,
        role: GroupAvatarMembership::ROLE,
        position: 0,
        state: "active",
      )

      accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        reservation_public_id: reservation.public_id,
      )

      assert_equal "accepted", accepted.state
      assert_equal legacy_period_count, AvatarOwnershipPeriod.where(avatar_id: avatar.id).count
      assert_equal "org", avatar.current_ownership_period.owner_surface
      assert_equal @target.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
      assert_equal "active", target_membership.reload.state
      assert_equal "removed", source_membership.reload.state
      assert_equal @target.account.public_id, target_group.reload.account_public_id
      assert_equal source.account.public_id, source_group.reload.account_public_id
      raise ActiveRecord::Rollback
    end
  end

  test "a completed registry request replays its recorded result for the same request" do
    reservation = registry_request

    AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    replay = registry_request

    assert_equal reservation.id, replay.id
    assert_equal "accepted", replay.state
    assert_equal reservation.public_id, replay.public_id
  end

  test "registry accept replay returns the recorded result without changing history" do
    reservation = registry_request

    accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      reservation_public_id: reservation.public_id,
    )
    legacy_period_count = @avatar.avatar_ownership_periods.count
    bureau_period_count = @avatar.bureau_ownership_periods.count

    replayed = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal accepted.id, replayed.id
    assert_equal "accepted", replayed.state
    assert_equal accepted.completed_at, replayed.completed_at
    assert_equal legacy_period_count, AvatarOwnershipPeriod.where(avatar_id: @avatar.id).count
    assert_equal bureau_period_count, AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).count
    accepted_detail = AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: accepted.id)
    replayed_detail = AvatarEnterpriseToBureauTransferDetail.find_by!(transfer_reservation_id: replayed.id)

    assert_equal accepted_detail.accepted_at, replayed_detail.accepted_at
  end

  test "registry transfer removes owner-mismatched group membership and preserves target membership" do
    source_group = group_for(@source, surface: "app")
    target_group = group_for(@target, surface: "org")
    stale_membership = membership_for(source_group)
    matching_membership = membership_for(target_group)
    reservation = registry_request

    AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal "removed", stale_membership.reload.state
    assert_predicate stale_membership.removed_at, :present?
    assert_equal "active", matching_membership.reload.state
    assert_nil matching_membership.removed_at
  end

  test "registry transfer accepts a Bureau-owned Avatar into an Enterprise" do
    result = AvatarProvisioning::Create.call(
      actor: @target_actor,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Bureau source" },
      handle_params: { handle: "registry-bureau-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )

    assert_predicate result, :success?, result.errors.inspect
    avatar = result.avatar

    reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      avatar_public_id: avatar.public_id,
      target_surface: "app",
      target_collective_public_id: @source.collective.public_id,
      idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a40",
      request_fingerprint: registry_request_fingerprint(
        actor: @target_actor, surface: "org", subject_public_id: @target.account.public_id,
        avatar_public_id: avatar.public_id, target_surface: "app",
        target_collective_public_id: @source.collective.public_id,
      ),
    )

    accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal "accepted", accepted.state
    assert_equal "app", avatar.reload.current_ownership_period.owner_surface
    assert_equal @source.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
    assert_empty avatar.bureau_ownership_periods.current
    assert_equal @source.collective.public_id, avatar.enterprise_ownership_periods.current.first.enterprise_public_id
  end

  test "registry transfer accepts an Enterprise-owned Avatar into another Enterprise" do
    target_actor = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    target = BaseSelectorBootstrapAuthority.call(surface: :app, principal: target_actor)
    reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      avatar_public_id: @avatar.public_id,
      target_surface: "app",
      target_collective_public_id: target.collective.public_id,
      idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a43",
      request_fingerprint: registry_request_fingerprint(
        actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
        avatar_public_id: @avatar.public_id, target_surface: "app",
        target_collective_public_id: target.collective.public_id,
      ),
    )

    accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: target_actor,
      surface: "app",
      subject_public_id: target.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal "accepted", accepted.state
    assert_equal "app", @avatar.reload.current_ownership_period.owner_surface
    assert_equal target.collective.public_id, @avatar.current_ownership_period.owner_collective_public_id
    assert_equal target.collective.public_id, @avatar.enterprise_ownership_periods.current.first.enterprise_public_id
    assert_empty @avatar.bureau_ownership_periods.current
  end

  test "returning to the original owner does not reactivate its historical grant" do
    original_period = @avatar.enterprise_ownership_periods.current.first
    historical_grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: original_period,
      subject: @source.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @source_actor.public_id,
      granting_subject_public_id: @source.account.public_id,
    )

    assert AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: original_period,
      subject: @source.account,
      capability: "avatar.view",
    )

    to_bureau = registry_request
    AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      reservation_public_id: to_bureau.public_id,
    )

    back_to_enterprise = AvatarOwnershipTransfers::RegistryRequestOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      avatar_public_id: @avatar.public_id,
      target_surface: "app",
      target_collective_public_id: @source.collective.public_id,
      idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a45",
      request_fingerprint: registry_request_fingerprint(
        actor: @target_actor,
        surface: "org",
        subject_public_id: @target.account.public_id,
        avatar_public_id: @avatar.public_id,
        target_surface: "app",
        target_collective_public_id: @source.collective.public_id,
      ),
    )

    AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      reservation_public_id: back_to_enterprise.public_id,
    )

    current_period = @avatar.reload.enterprise_ownership_periods.current.first

    assert_not_equal original_period.id, current_period.id
    assert_not AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: original_period,
      subject: @source.account,
      capability: "avatar.view",
    )
    assert_not AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: current_period,
      subject: @source.account,
      capability: "avatar.view",
    )
    assert_nil historical_grant.reload.revoked_at

    fresh_grant = AvatarAccessGrants::IssueOperation.call(
      ownership_period: current_period,
      subject: @source.account,
      capability: "avatar.view",
      granted_by_actor_public_id: @source_actor.public_id,
      granting_subject_public_id: @source.account.public_id,
    )

    assert AvatarAccessGrantResolver.call(
      avatar: @avatar,
      ownership_period: current_period,
      subject: @source.account,
      capability: "avatar.view",
    )
    assert_not_equal historical_grant.id, fresh_grant.id
  end

  test "registry transfer accepts a Bureau-owned Avatar into another Bureau" do
    target_actor = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    target = BaseSelectorBootstrapAuthority.call(surface: :org, principal: target_actor)
    result = AvatarProvisioning::Create.call(
      actor: @target_actor,
      subject_type: :agent,
      subject: @target.account,
      avatar_params: { moniker: "Bureau 2" },
      handle_params: { handle: "registry-bureau-to-bureau-#{SecureRandom.hex(4)}" },
      owner_surface: "org",
      owner_collective_public_id: @target.collective.public_id,
    )

    assert_predicate result, :success?, result.errors.inspect

    avatar = result.avatar

    reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      avatar_public_id: avatar.public_id,
      target_surface: "org",
      target_collective_public_id: target.collective.public_id,
      idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a44",
      request_fingerprint: registry_request_fingerprint(
        actor: @target_actor, surface: "org", subject_public_id: @target.account.public_id,
        avatar_public_id: avatar.public_id, target_surface: "org",
        target_collective_public_id: target.collective.public_id,
      ),
    )

    accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: target_actor,
      surface: "org",
      subject_public_id: target.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal "accepted", accepted.state
    assert_equal "org", avatar.reload.current_ownership_period.owner_surface
    assert_equal target.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
    assert_equal target.collective.public_id, avatar.bureau_ownership_periods.current.first.bureau_public_id
    assert_empty avatar.enterprise_ownership_periods.current
  end

  test "registry accept rejects a non-advancing transfer instant without changing history" do
    reservation = registry_request
    source_period = @avatar.enterprise_ownership_periods.current.first

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      Avatar.stub(:database_now, source_period.valid_from) do
        AvatarOwnershipTransfers::RegistryAcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          reservation_public_id: reservation.public_id,
        )
      end
    end

    assert_equal "pending", reservation.reload.state
    assert_equal Float::INFINITY, source_period.reload.valid_to
    assert_empty AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).current
  end

  test "registry accept rejects an instant that does not advance either ownership history" do
    reservation = registry_request
    source_period = @avatar.enterprise_ownership_periods.current.first
    legacy_period = @avatar.current_ownership_period
    legacy_period.update!(valid_from: source_period.valid_from + 1.second)

    assert_raises(AvatarOwnershipTransfers::InvalidTransfer) do
      Avatar.stub(:database_now, legacy_period.valid_from) do
        AvatarOwnershipTransfers::RegistryAcceptOperation.call(
          actor: @target_actor,
          surface: "org",
          subject_public_id: @target.account.public_id,
          reservation_public_id: reservation.public_id,
        )
      end
    end

    assert_equal "pending", reservation.reload.state
    assert_equal Float::INFINITY, source_period.reload.valid_to
    assert_equal Float::INFINITY, legacy_period.reload.valid_to
    assert_empty AvatarBureauOwnershipPeriod.where(avatar_id: @avatar.id).current
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
    assert_empty @avatar.enterprise_ownership_periods.current
    assert_equal @target.collective.public_id, @avatar.bureau_ownership_periods.current.first.bureau_public_id
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

    assert_equal @target.collective.public_id,
                 avatar.reload.bureau_ownership_periods.current.first.bureau_public_id
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
    assert_empty avatar.bureau_ownership_periods.current
    assert_equal @source.collective.public_id, avatar.enterprise_ownership_periods.current.first.enterprise_public_id
    assert_equal @source.collective.public_id, avatar.current_ownership_period.owner_collective_public_id
    assert_equal prior_selected_avatar_id, @client_token_for_source.reload.selected_avatar_public_id
    candidate =
      BaseSwitcherAuthority.current(
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

  test "transfer does not reinterpret a group's account context as Avatar ownership" do
    source_group = group_for(@source, surface: "app")
    target_group = group_for(@target, surface: "org")
    membership_for(source_group)
    membership_for(target_group)
    source_account = [source_group.account_surface, source_group.account_public_id]
    target_account = [target_group.account_surface, target_group.account_public_id]
    reservation = registry_request

    AvatarOwnershipTransfers::RegistryAcceptOperation.call(
      actor: @target_actor,
      surface: "org",
      subject_public_id: @target.account.public_id,
      reservation_public_id: reservation.public_id,
    )

    assert_equal source_account, [source_group.reload.account_surface, source_group.account_public_id]
    assert_equal target_account, [target_group.reload.account_surface, target_group.account_public_id]
    assert_equal "org", @avatar.reload.current_ownership_period.owner_surface
    assert_equal "removed", source_group.group_avatar_memberships.first.reload.state
    assert_equal "active", target_group.group_avatar_memberships.first.reload.state
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

  def registry_request
    AvatarOwnershipTransfers::RegistryRequestOperation.call(
      actor: @source_actor,
      surface: "app",
      subject_public_id: @source.account.public_id,
      avatar_public_id: @avatar.public_id,
      target_surface: "org",
      target_collective_public_id: @target.collective.public_id,
      idempotency_key: "018f2b18-6f5c-7a30-8ec2-4ebc1f0f7a39",
      request_fingerprint: registry_request_fingerprint,
    )
  end

  def registry_request_fingerprint(actor: @source_actor, surface: "app", subject_public_id: @source.account.public_id,
                                   avatar_public_id: @avatar.public_id, target_surface: "org",
                                   target_collective_public_id: @target.collective.public_id)
    Digest::SHA256.hexdigest(
      [
        "avatar_transfer", surface, actor.public_id, subject_public_id, avatar_public_id,
        target_surface, target_collective_public_id,
      ].join("\0"),
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
