# frozen_string_literal: true

require "test_helper"

class OrgOperatorLifecycleOuterTransactionTest < ActiveSupport::TestCase
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(withdraw suspend terminate).product(%i(commit rollback), %i(joined savepoint)).each do |action, outcome, nesting|
    test "operator #{action} inside #{nesting} delivers only after outer #{outcome}" do
      requester = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      executor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      target = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      root = OperatorToken.create!(staff: target, authentication_epoch: 0)
      device_id = root.device_session_id
      request = OperatorLifecycleRequest.create!(
        action:, status: OperatorLifecycleRequest::STATUS_APPROVED, target_operator: target,
        requested_by_operator: requester, approved_by_operator: executor, approved_at: Time.current, reason: "approved",
      )
      event_id = nil
      transition =
        lambda do
          result = OrgOperatorLifecycleExecute.call(request:, actor: executor)

          assert_predicate result, :success?
          event_id = OrgIdentityAuthenticationEvent.find_by!(actor_ref: target.id.to_s).event_id
        end

      OrgPrincipalRecord.transaction do
        if nesting == :savepoint
          OrgPrincipalRecord.transaction(requires_new: true) { transition.call }
        else
          transition.call
        end

        assert_not OpOrgInboundEventReceipt.exists?(event_id:)
        assert_not_predicate root.reload, :revoked?
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      assert_equal outcome == :commit, OpOrgInboundEventReceipt.exists?(event_id:)
      assert_equal outcome == :commit, root.reload.revoked?
      assert_equal outcome == :commit, request.reload.executed?
      assert_equal outcome == :commit, target.reload.deactivated_at.present?
    ensure
      delete_authority_stops_for!(realm: "org", root_ids: [root&.id])
      OpOrgInboundEventReceipt.where(event_id:).delete_all if event_id
      OrgIdentityAuthenticationEvent.where(actor_ref: target.id.to_s).delete_all if target
      request&.delete
      root&.delete
      OperatorDeviceSession.where(id: device_id).delete_all if device_id
      target&.delete
      requester&.delete
      executor&.delete
    end
  end
end
