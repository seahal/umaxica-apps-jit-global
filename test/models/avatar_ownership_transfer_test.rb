# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/avatar_test_factory"

class AvatarOwnershipTransferTest < ActiveSupport::TestCase
  test "database rejects blank identifiers even when model validations are bypassed" do
    HandleStatus.ensure_defaults!
    capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)

    {
      public_id: "public_id",
      from_owner_collective_public_id: "source owner id",
      to_owner_collective_public_id: "target owner id",
      request_actor_public_id: "request actor id",
    }.each do |column, label|
      handle = Handle.create!(
        handle: "transfer-check-#{SecureRandom.hex(5)}",
        handle_status_id: HandleStatus::ACTIVE,
        cooldown_until: Time.current,
        is_system: false,
      )
      avatar = AvatarTestFactory.create!(
        moniker: "Transfer #{SecureRandom.hex(2)}",
        capability: capability,
        active_handle: handle,
      )
      requested_at = Time.current
      attributes = {
        avatar_id: avatar.id,
        public_id: SecureRandom.hex(12),
        from_owner_surface: "app",
        from_owner_collective_public_id: "source-owner",
        to_owner_surface: "org",
        to_owner_collective_public_id: "target-owner",
        state: "pending",
        requested_at: requested_at,
        expires_at: requested_at + 5.days,
        request_actor_surface: "app",
        request_actor_public_id: "source-actor",
        created_at: requested_at,
        updated_at: requested_at,
      }
      attributes[column] = " \t"

      assert_raises(ActiveRecord::StatementInvalid, "blank #{label}") do
        AvatarRecord.transaction(requires_new: true) do
          AvatarOwnershipTransfer.insert_all!([attributes])
        end
      end
    end
  end
end
