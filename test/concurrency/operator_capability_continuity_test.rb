# typed: false
# frozen_string_literal: true

require "test_helper"

# adr/operator-capability-authorization.md, Granting: two operators revoking each other's
# iam.capability.grant at the same moment must not both succeed. Transactional tests would share
# one connection, so this test commits real rows, runs two threads on separate connections, and
# removes its own rows afterwards.
class OperatorCapabilityContinuityTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @operators =
      Array.new(2) do
        Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
      end
    @grants =
      @operators.map do |operator|
        OperatorCapabilityGrant.create!(
          operator: operator, origin: "bootstrap", capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
          reason_code: "bootstrap", starts_at: 1.minute.ago, expires_at: 1.day.from_now,
        )
      end
  end

  teardown do
    OperatorCapabilityGrant.where(id: @grants.map(&:id)).delete_all
    Operator.where(id: @operators.map(&:id)).delete_all
  end

  test "concurrent revocations of the last two holders leave at least one holder" do
    start = Queue.new
    outcomes = Queue.new
    threads =
      [[@grants[0], @operators[1]], [@grants[1], @operators[0]]].map do |grant, revoker|
        Thread.new do # rubocop:disable ThreadSafety/NewThread -- two connections are the point of this test
          OperatorCapabilityGrant.connection_pool.with_connection do
            start.pop
            OperatorCapabilityGrant.find(grant.id).revoke!(by: Operator.find(revoker.id), reason_code: "duty_ended")
            outcomes << :revoked
          rescue OperatorCapabilityGrant::LastCapabilityHolderError
            outcomes << :refused
          rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout
            outcomes << :lock_failure
          end
        end
      end
    2.times { start << true }
    threads.each(&:join)
    results = Array.new(2) { outcomes.pop }.sort

    remaining = OperatorCapabilityGrant.where(id: @grants.map(&:id)).in_force.count

    assert_operator remaining, :>=, 1, "outcomes were #{results.inspect}"
    assert_equal 1, results.count(:revoked), "exactly one revocation may win: #{results.inspect}"
  end
end
