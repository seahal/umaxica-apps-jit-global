# frozen_string_literal: true

require "test_helper"

class AdministrativeAccessOuterTransactionTest < ActiveSupport::TestCase
  include AuthorityStopCleanup

  self.use_transactional_tests = false
  self.fixture_table_names = []

  %w(app org).product(
    %i(lock unlock), %i(commit rollback),
    %i(joined savepoint),
  ).each do |realm, action, outcome, nesting|
    test "#{realm} administrative #{action} inside #{nesting} waits for outer #{outcome}" do
      operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
      if realm == "app"
        account = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
        root = ClientToken.create!(user: account, authentication_epoch: 0)
        event_class = AppIdentityAuthenticationEvent
        receipt_class = OpAppInboundEventReceipt
        device_class = ClientDeviceSession
      else
        account = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
        root = OperatorToken.create!(staff: account, authentication_epoch: 0)
        event_class = OrgIdentityAuthenticationEvent
        receipt_class = OpOrgInboundEventReceipt
        device_class = OperatorDeviceSession
      end
      device_id = root.device_session_id
      audit_scope = AccountAccessEvent.where(account_type: account.class.name, account_id: account.id)
      event_ids = []
      if action == :unlock
        AdministrativeAccessLock.lock!(account:, operator:, reason_code: "security_incident")
        event_ids = event_class.where(actor_ref: account.id.to_s).pluck(:event_id)
      end
      initial_audit_count = audit_scope.count

      transition =
        lambda do
          if action == :lock
            AdministrativeAccessLock.lock!(account:, operator:, reason_code: "security_incident")
            event_ids = event_class.where(actor_ref: account.id.to_s).pluck(:event_id)

            assert_not receipt_class.exists?(event_id: event_ids)
            assert_not_predicate root.reload, :revoked?
          else
            AdministrativeAccessLock.unlock!(account:, operator:, reason_code: "operator_error_recovery")
          end
        end
      account.class.transaction do
        if nesting == :savepoint
          account.class.transaction(requires_new: true) { transition.call }
        else
          transition.call
        end

        if action == :lock
          assert_not receipt_class.exists?(event_id: event_ids)
          assert_not_predicate root.reload, :revoked?
        end

        assert_equal initial_audit_count, audit_scope.count
        raise ActiveRecord::Rollback if outcome == :rollback
      end

      expected_audits = initial_audit_count + ((outcome == :commit) ? 1 : 0)

      assert_equal expected_audits, audit_scope.count
      if action == :lock
        assert_equal outcome == :commit, account.reload.admin_locked?
        assert_equal outcome == :commit, receipt_class.exists?(event_id: event_ids)
        assert_equal outcome == :commit, root.reload.revoked?
      else
        assert_equal outcome == :rollback, account.reload.admin_locked?
        assert_predicate root.reload, :revoked?
      end
    ensure
      delete_authority_stops_for!(realm:, root_ids: [root&.id])
      receipt_class&.where(event_id: event_ids)&.delete_all if event_ids.present?
      event_class&.where(actor_ref: account.id.to_s)&.delete_all if account
      audit_scope&.delete_all
      root&.delete
      device_class&.where(id: device_id)&.delete_all if device_id
      account&.delete
      operator&.delete
    end
  end
end
