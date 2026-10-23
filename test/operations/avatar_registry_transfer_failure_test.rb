# frozen_string_literal: true

require "test_helper"

class AvatarRegistryTransferFailureTest < ActiveSupport::TestCase
  [["app", "app"], ["app", "org"], ["org", "app"], ["org", "org"]].each do |source_surface, target_surface|
    test "#{source_surface} to #{target_surface} transfer rolls back a destination write failure and retries once" do
      source_actor =
        case source_surface
        when "app" then Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
        )
        when "org" then Operator.create!(
          security_mode_id: SecurityModeConfigurable::ADVANCED,
          status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
        )
        else raise ArgumentError, "unsupported source"
        end
      target_actor =
        case target_surface
        when "app" then Client.create!(
          security_mode_id: SecurityModeConfigurable::NORMAL,
          status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER,
        )
        when "org" then Operator.create!(
          security_mode_id: SecurityModeConfigurable::ADVANCED,
          status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF,
        )
        else raise ArgumentError, "unsupported destination"
        end
      source = BaseSelectorBootstrapAuthority.call(surface: source_surface.to_sym, principal: source_actor)
      target = BaseSelectorBootstrapAuthority.call(surface: target_surface.to_sym, principal: target_actor)
      avatar =
        case source_surface
        when "app" then source.avatar
        when "org"
          provision = AvatarProvisioning::Create.call(
            actor: source_actor, subject_type: :agent, subject: source.account,
            avatar_params: { moniker: "Failure source" },
            handle_params: { handle: "transfer-failure-#{SecureRandom.hex(4)}" },
            owner_surface: "org", owner_collective_public_id: source.collective.public_id,
          )

          assert_predicate provision, :success?, provision.errors.inspect
          provision.avatar
        else raise ArgumentError, "unsupported source"
        end
      reservation = AvatarOwnershipTransfers::RegistryRequestOperation.call(
        actor: source_actor, surface: source_surface, subject_public_id: source.account.public_id,
        avatar_public_id: avatar.public_id, target_surface: target_surface,
        target_collective_public_id: target.collective.public_id, idempotency_key: SecureRandom.uuid,
        request_fingerprint: Digest::SHA256.hexdigest(
          ["avatar_transfer", source_surface, source_actor.public_id, source.account.public_id,
           avatar.public_id, target_surface, target.collective.public_id,].join("\0"),
        ),
      )
      before_reservation = reservation.attributes
      before_legacy = avatar.avatar_ownership_periods.order(:id).map(&:attributes)
      before_enterprise = avatar.enterprise_ownership_periods.order(:id).map(&:attributes)
      before_bureau = avatar.bureau_ownership_periods.order(:id).map(&:attributes)
      destination_model =
        case target_surface
        when "app" then AvatarEnterpriseOwnershipPeriod
        when "org" then AvatarBureauOwnershipPeriod
        else raise ArgumentError, "unsupported destination"
        end

      # The public persistence boundary fails after the operation has closed the old periods.
      # The operation and every earlier SQL write execute normally inside the real transaction.
      destination_model.stub(
        :create!, ->(**) {
                    raise ActiveRecord::StatementInvalid, "synthetic destination failure"
                  },
      ) do
        assert_raises(ActiveRecord::StatementInvalid) do
          AvatarOwnershipTransfers::RegistryAcceptOperation.call(
            actor: target_actor, surface: target_surface, subject_public_id: target.account.public_id,
            reservation_public_id: reservation.public_id,
          )
        end
      end

      assert_equal before_reservation, reservation.reload.attributes
      assert_equal before_legacy, AvatarOwnershipPeriod.where(avatar_id: avatar.id).order(:id).map(&:attributes)
      assert_equal before_enterprise,
                   AvatarEnterpriseOwnershipPeriod.where(avatar_id: avatar.id).order(:id).map(&:attributes)
      assert_equal before_bureau,
                   AvatarBureauOwnershipPeriod.where(avatar_id: avatar.id).order(:id).map(&:attributes)
      assert_equal source.collective.public_id, avatar.reload.current_ownership_period.owner_collective_public_id

      accepted = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: target_actor, surface: target_surface, subject_public_id: target.account.public_id,
        reservation_public_id: reservation.public_id,
      )

      assert_equal "accepted", accepted.state
      assert_equal target.collective.public_id, avatar.reload.current_ownership_period.owner_collective_public_id
      committed = accepted.attributes
      period_counts = [avatar.enterprise_ownership_periods.count, avatar.bureau_ownership_periods.count]

      replay = AvatarOwnershipTransfers::RegistryAcceptOperation.call(
        actor: target_actor, surface: target_surface, subject_public_id: target.account.public_id,
        reservation_public_id: reservation.public_id,
      )

      assert_equal committed, replay.attributes
      assert_equal period_counts, [avatar.enterprise_ownership_periods.count, avatar.bureau_ownership_periods.count]
    end
  end
end
