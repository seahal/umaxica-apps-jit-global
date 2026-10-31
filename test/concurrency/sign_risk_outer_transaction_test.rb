# frozen_string_literal: true

require "test_helper"

class SignRiskOuterTransactionTest < ActiveSupport::TestCase
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(app org).product(%i(commit rollback), %i(joined savepoint)).each do |realm, outcome, nesting|
    test "#{realm} risk stop inside #{nesting} waits for outer #{outcome}" do
      if realm == "app"
        actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        root = ClientToken.create!(user: actor, authentication_epoch: 0)
        event_class = AppIdentityAuthenticationEvent
        receipt_class = OpAppInboundEventReceipt
        device_class = ClientDeviceSession
      else
        actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
        root = OperatorToken.create!(staff: actor, authentication_epoch: 0)
        event_class = OrgIdentityAuthenticationEvent
        receipt_class = OpOrgInboundEventReceipt
        device_class = OperatorDeviceSession
      end
      device_id = root.device_session_id
      event_id = nil
      issue =
        lambda do
          SignRiskEnforcer.revoke!(actor)
          event_id = event_class.find_by!(actor_ref: actor.id.to_s).event_id
        end

      actor.class.transaction do
        if nesting == :savepoint
          actor.class.transaction(requires_new: true) { issue.call }
        else
          issue.call
        end

        assert_not receipt_class.exists?(event_id:)
        assert_not_predicate root.reload, :revoked?
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      if outcome == :commit
        assert_equal 1, actor.reload.authentication_epoch
        assert event_class.exists?(event_id:)
        assert receipt_class.exists?(event_id:)
        assert_predicate root.reload, :revoked?
      else
        assert_equal 0, actor.reload.authentication_epoch
        assert_not event_class.exists?(event_id:)
        assert_not receipt_class.exists?(event_id:)
        assert_not_predicate root.reload, :revoked?
      end
    ensure
      delete_authority_stops_for!(realm:, root_ids: [root&.id])
      receipt_class&.where(event_id:)&.delete_all if event_id
      event_class&.where(event_id:)&.delete_all if event_id
      root&.delete
      device_class&.where(id: device_id)&.delete_all if device_id
      actor&.delete
    end
  end
end
