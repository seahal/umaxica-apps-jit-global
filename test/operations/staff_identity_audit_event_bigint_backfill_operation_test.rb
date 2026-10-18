# frozen_string_literal: true

require "test_helper"

class StaffIdentityAuditEventBigintBackfillOperationTest < ActiveSupport::TestCase
  test "post-cutover maintenance is an idempotent no-op" do
    result = StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: false, batch_size: 1)

    assert result.fetch(:cutover)
    assert_not result.fetch(:dry_run)
    assert_equal 0, result.fetch(:events_assigned)
    assert_equal 0, result.fetch(:audit_references_assigned)
    assert_equal 0, result.fetch(:events_missing)
    assert_equal 0, result.fetch(:audit_references_missing)
    assert_equal 0, result.fetch(:unresolved_audit_references)

    repeated = StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: false, batch_size: 1)

    assert_equal result, repeated
  end

  test "post-cutover dry run reports no writable legacy mapping" do
    result = StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: true, batch_size: 100)

    assert result.fetch(:dry_run)
    assert result.fetch(:cutover)
    assert_equal 0, result.fetch(:events_missing)
    assert_equal 0, result.fetch(:audit_references_missing)
    assert_equal 0, result.fetch(:unresolved_audit_references)
  end

  test "rejects an unspecified mode or an unbounded batch" do
    assert_raises(ArgumentError) do
      StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: nil, batch_size: 1)
    end
    assert_raises(ArgumentError) do
      StaffIdentityAuditEventBigintBackfillOperation.call(dry_run: true, batch_size: 0)
    end
  end
end
