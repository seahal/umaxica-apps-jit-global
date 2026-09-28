# typed: false
# frozen_string_literal: true

require "test_helper"

# Operator#capability? is the single grant check every org administrative policy uses.
class OperatorCapabilityTest < ActiveSupport::TestCase
  setup do
    @operator = operators(:one)
    @granter = operators(:two)
  end

  test "an operator with no grant holds no capability" do
    assert_not @operator.capability?(OperatorCapabilityGrant::SUPPORT_CONSOLE_READ)
  end

  test "an in-force grant confers exactly its own capability" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    assert @operator.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)
    assert_not @operator.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM)
    assert_not @operator.capability?(OperatorCapabilityGrant::SUPPORT_SESSION_REVOKE_APP)
  end

  test "an expired, not-yet-started, or revoked grant confers nothing" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: 2.days.ago,
      expires_at: 1.day.ago,
    )
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM,
      reason_code: "duty_assignment",
      starts_at: 1.day.from_now,
      expires_at: 2.days.from_now,
    )
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
      revoked_at: Time.current,
      revoked_by_operator: @granter,
      revoke_reason_code: "duty_ended",
    )

    assert_not @operator.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP)
    assert_not @operator.capability?(OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_COM)
    assert_not @operator.capability?(OperatorCapabilityGrant::SUPPORT_CONSOLE_READ)
  end

  test "an admin-locked operator holds no capability even with an in-force grant" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    AdministrativeAccessLock.lock!(account: @operator, operator: @granter, reason_code: "security_incident")

    assert_not @operator.reload.capability?(OperatorCapabilityGrant::SUPPORT_CONSOLE_READ)
  end

  test "an operator whose withdrawal has started holds no capability" do
    OperatorCapabilityGrant.create!(
      operator: @operator,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    @operator.update_columns(withdrawal_started_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    assert_not @operator.reload.capability?(OperatorCapabilityGrant::SUPPORT_CONSOLE_READ)
  end

  test "an unknown capability identifier raises instead of answering false" do
    assert_raises(ArgumentError) { @operator.capability?("support.*") }
    assert_raises(ArgumentError) { @operator.capability?("") }
    assert_raises(ArgumentError) { @operator.capability?(nil) }
  end
end
