# frozen_string_literal: true

require "test_helper"
require "timeout"

class PasskeyAuditDeliveryCommitOrderTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "ORG audit remains in Chronicle when Source acknowledgement fails and retry converges" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    passkey = PasskeyRegistrationOperation.call!(
      actor: operator, passkey_class: OperatorPasskey,
      attributes: { webauthn_id: SecureRandom.uuid, public_key: "audit-commit-order-key" },
      audit: { event_type: "passkey.registered.settings", surface: "org", actor_ref: operator.public_id },
    )
    event = OperatorPasskeyAuditOutbox.find_by!(external_id: passkey.external_id)
    observed_chronicle = nil
    observer =
      lambda do |_name, _start, _finish, _id, notification|
        next unless notification.fetch(:sql).match?(/\A\s*UPDATE\s+"operator_passkey_audit_outboxes"/i)

        reader =
          Thread.new do
            Chronicle.connection_pool.with_connection { Chronicle.exists?(event_uuid: event.event_uuid) }
          end
        observed_chronicle = Timeout.timeout(10) { reader.value }
        raise ActiveRecord::ConnectionNotEstablished, "injected Source acknowledgement failure"
      end

    ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
      assert_raises(ActiveRecord::ConnectionNotEstablished) { PasskeyAuditDeliveryJob.perform_now }
    end

    assert observed_chronicle
    assert_nil event.reload.acknowledged_at
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
    PasskeyAuditDeliveryJob.perform_now

    assert_predicate event.reload.acknowledged_at, :present?
    assert_equal 1, Chronicle.where(event_uuid: event.event_uuid).count
  ensure
    Chronicle.where(event_uuid: event.event_uuid).delete_all if event
    event&.delete
    passkey&.delete
    operator&.delete
  end
end
