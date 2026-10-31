# frozen_string_literal: true

require "test_helper"
require "timeout"

class AdministrativeAccessLockClockTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  %i(lock unlock).each do |action|
    test "#{action} sets the token cutoff after obtaining the account lock" do
      account = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
      operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
      ready = Queue.new
      worker = nil
      marker = nil

      OpIdentityEventInvalidator.stub(:deliver, :applied) do
        if action == :unlock
          AdministrativeAccessLock.lock!(account:, operator:, reason_code: "security_incident")
        end
        account.with_lock do
          worker =
            Thread.new do
              Client.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()").to_i
                current = Client.find(account.id)
                if action == :lock
                  AdministrativeAccessLock.lock!(account: current, operator:, reason_code: "security_incident")
                else
                  AdministrativeAccessLock.unlock!(
                    account: current, operator:,
                    reason_code: "operator_error_recovery",
                  )
                end
              end
            ensure
              ActiveRecord::Base.connection_handler.clear_active_connections!
            end
          pid = Timeout.timeout(10) { ready.pop }
          Timeout.timeout(10) do
            loop do
              blocked =
                Client.uncached do
                  Client.lease_connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
                end
              break if blocked

              Thread.pass
            end
          end
          marker = Client.database_now
        end
        Timeout.timeout(10) { worker.value }
      end

      assert_operator account.reload.token_valid_after_at, :>=, marker
    ensure
      worker&.join(10)
      AccountAccessEvent.where(account_type: "Client", account_id: account.id).delete_all if account
      AppIdentityAuthenticationEvent.where(actor_ref: account.id.to_s).delete_all if account
      account&.delete
      operator&.delete
    end
  end
end
