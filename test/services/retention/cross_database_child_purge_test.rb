# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../support/avatar_test_factory"
# require "helpers/global_test_support"

module Retention
  class CrossDatabaseChildPurgeTest < ActiveSupport::TestCase
    test "deletes non-audit cross-database children but retains chronicle audit" do
      user = Client.create!(public_id: "cdp_#{SecureRandom.hex(6)}", status_id: ClientStatus::ACTIVE)

      notification = ClientNotificationRecord.create!(client: user)

      capability = AvatarCapability.find_or_create_by!(id: AvatarCapability::NORMAL)
      handle = Handle.create!(handle: "cdp_h-#{SecureRandom.hex(4)}", cooldown_until: Time.current)
      avatar = AvatarTestFactory.create!(moniker: "Cdp", capability: capability, active_handle: handle)
      assignment = avatar.avatar_assignments.create!(user: user, role: "owner")

      chronicle = ClientChronicle.create!(
        user: user,
        user_chronicle_level: ClientChronicleLevel.find_or_create_by!(id: ClientChronicleLevel::INFO),
        user_chronicle_event: ClientChronicleEvent.find(ClientChronicleEvent::LOGIN_SUCCESS),
        timestamp: Time.current,
        ip_address: "192.168.1.1",
      )

      RetentionCrossDatabaseChildPurge.call(actor: user)

      assert_not ClientNotificationRecord.exists?(notification.id),
                 "notification_records (app_signal DB) should be purged"
      assert_not AvatarAssignment.exists?(assignment.id),
                 "avatar_assignments (avatar DB) join row should be purged"
      assert ClientChronicle.exists?(chronicle.id),
             "chronicle (audit) must be retained across actor purge"
    end

    test "is a no-op for unknown actor types" do
      assert_nothing_raised do
        RetentionCrossDatabaseChildPurge.call(actor: Object.new)
      end
    end
  end
end
