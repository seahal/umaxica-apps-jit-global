# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorCapabilityGrantTest < ActiveSupport::TestCase
  setup do
    @now = Time.zone.parse("2026-09-26 12:00:00")
    @grantee = operators(:one)
    @granter = operators(:two)
  end

  test "a delegated grant with a granter other than the grantee is valid" do
    grant = OperatorCapabilityGrant.new(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 30.days,
    )

    assert_predicate grant, :valid?
  end

  test "a delegated grant naming the grantee as granter is rejected by the model and the database" do
    grant = OperatorCapabilityGrant.new(
      operator: @grantee,
      granted_by_operator: @grantee,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 30.days,
    )

    assert_not grant.valid?
    assert_raises(ActiveRecord::StatementInvalid) { grant.save!(validate: false) }
  end

  test "a delegated grant without a granter is rejected" do
    grant = OperatorCapabilityGrant.new(
      operator: @grantee,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_ACCOUNT_READ_APP,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 30.days,
    )

    assert_not grant.valid?
  end

  test "an IAM capability cannot be delegated, only bootstrapped" do
    delegated = OperatorCapabilityGrant.new(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 30.days,
    )
    bootstrapped = OperatorCapabilityGrant.new(
      operator: @grantee,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
      reason_code: "bootstrap",
      starts_at: @now,
      expires_at: @now + 30.days,
    )

    assert_not delegated.valid?
    assert_predicate bootstrapped, :valid?
  end

  test "a bootstrap grant naming a granter is rejected" do
    grant = OperatorCapabilityGrant.new(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "bootstrap",
      starts_at: @now,
      expires_at: @now + 30.days,
    )

    assert_not grant.valid?
  end

  test "unknown, wildcard, empty, and NUL-bearing capabilities are rejected by the model and the database" do
    ["support.*", "*", "", "support.console.read\u0000", "support.account.read.org", nil].each do |capability|
      grant = OperatorCapabilityGrant.new(
        operator: @grantee,
        granted_by_operator: @granter,
        origin: "grant",
        capability: capability,
        reason_code: "duty_assignment",
        starts_at: @now,
        expires_at: @now + 30.days,
      )

      assert_not grant.valid?, "expected #{capability.inspect} to be rejected"
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorCapabilityGrant.new(
        operator: @grantee,
        granted_by_operator: @granter,
        origin: "grant",
        capability: "support.*",
        reason_code: "duty_assignment",
        starts_at: @now,
        expires_at: @now + 30.days,
      ).save!(validate: false)
    end
  end

  test "validity window boundary: expiry equal to start is rejected, one second later is accepted" do
    at_start = OperatorCapabilityGrant.new(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now,
    )
    after_start = OperatorCapabilityGrant.new(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 1.second,
    )

    assert_not at_start.valid?
    assert_predicate after_start, :valid?
  end

  test "maximum validity boundary: 366 days less one second and 366 days pass, one second more fails" do
    below, at, above =
      [-1, 0, 1].map do |offset|
      OperatorCapabilityGrant.new(
        operator: @grantee,
        granted_by_operator: @granter,
        origin: "grant",
        capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
        reason_code: "duty_assignment",
        starts_at: @now,
        expires_at: @now + 366.days + offset.seconds,
      )
    end

    assert_predicate below, :valid?
    assert_predicate at, :valid?
    assert_not above.valid?
  end

  test "the database also enforces the maximum validity: 366 days is stored, one second more is refused" do
    at_limit = OperatorCapabilityGrant.new(
      operator: @grantee, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: @now, expires_at: @now + 366.days,
    )
    over_limit = OperatorCapabilityGrant.new(
      operator: @grantee, granted_by_operator: @granter, origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ, reason_code: "duty_assignment",
      starts_at: @now, expires_at: @now + 366.days + 1.second,
    )

    at_limit.save!(validate: false)

    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorCapabilityGrant.transaction(requires_new: true) { over_limit.save!(validate: false) }
    end
  end

  test "in_force boundaries: before start, at start, just before expiry, at expiry" do
    grant = OperatorCapabilityGrant.create!(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 1.hour,
    )

    assert_not grant.in_force?(@now - 1.second)
    assert grant.in_force?(@now)
    assert grant.in_force?(@now + 1.hour - 1.second)
    assert_not grant.in_force?(@now + 1.hour)
    assert_equal [grant], OperatorCapabilityGrant.in_force(@now).to_a
    assert_empty OperatorCapabilityGrant.in_force(@now + 1.hour).to_a
  end

  test "a revoked grant is not in force and must carry a known revoke reason" do
    grant = OperatorCapabilityGrant.create!(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 1.hour,
    )

    # The savepoint keeps the surrounding test transaction usable after the CHECK violation.
    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorCapabilityGrant.transaction(requires_new: true) do
        grant.update_columns(revoked_at: @now) # rubocop:disable Rails/SkipsModelValidations
      end
    end

    grant.reload.update!(revoked_at: @now, revoked_by_operator: @granter, revoke_reason_code: "duty_ended")

    assert_not grant.in_force?(@now + 1.minute)
    assert_empty OperatorCapabilityGrant.in_force(@now + 1.minute).to_a
  end

  test "ticket id rejects free text and accepts a bounded identifier" do
    grant = OperatorCapabilityGrant.new(
      operator: @grantee,
      granted_by_operator: @granter,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: @now,
      expires_at: @now + 1.hour,
    )

    grant.ticket_id = "SEC-635"

    assert_predicate grant, :valid?

    grant.ticket_id = "SEC 635 <script>"

    assert_not grant.valid?

    grant.ticket_id = "A" * 65

    assert_not grant.valid?
  end
end

class OperatorCapabilityGrantTransitionTest < ActiveSupport::TestCase
  setup do
    @first = operators(:one)
    @second = operators(:two)
  end

  test "issue! starts now and expires after the requested duration" do
    now = Time.zone.parse("2026-09-26 12:00:00")
    grant = OperatorCapabilityGrant.issue!(
      operator: @first,
      granted_by: @second,
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      ticket_id: nil,
      duration: 30.days,
      now: now,
    )

    assert_equal [now, now + 30.days], [grant.starts_at, grant.expires_at]
    assert_equal "grant", grant.origin
  end

  test "revoking the last in-force holder of a continuity capability is refused" do
    only = OperatorCapabilityGrant.create!(
      operator: @first,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    assert_raises(OperatorCapabilityGrant::LastCapabilityHolderError) do
      only.revoke!(by: @second, reason_code: "duty_ended")
    end
    assert_nil only.reload.revoked_at
  end

  test "an expired or ineligible other holder does not count toward continuity" do
    target = OperatorCapabilityGrant.create!(
      operator: @first,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    OperatorCapabilityGrant.create!(
      operator: @second,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
      reason_code: "bootstrap",
      starts_at: 2.days.ago,
      expires_at: 1.day.ago,
    )
    other_eligible_but_locked = OperatorCapabilityGrant.create!(
      operator: operators(:sample_staff),
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_GRANT,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    other_eligible_but_locked.operator.update_columns( # rubocop:disable Rails/SkipsModelValidations
      access_state: "admin_locked", admin_locked_at: Time.current, admin_locked_reason_code: "security_incident",
    )

    assert_raises(OperatorCapabilityGrant::LastCapabilityHolderError) do
      target.revoke!(by: @second, reason_code: "duty_ended")
    end
  end

  test "with two eligible holders, the first revocation succeeds and the second is refused" do
    first = OperatorCapabilityGrant.create!(
      operator: @first,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )
    second = OperatorCapabilityGrant.create!(
      operator: @second,
      origin: "bootstrap",
      capability: OperatorCapabilityGrant::IAM_CAPABILITY_REVOKE,
      reason_code: "bootstrap",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    first.revoke!(by: @second, reason_code: "duty_ended")

    assert_predicate first.reload, :revoked?
    assert_raises(OperatorCapabilityGrant::LastCapabilityHolderError) do
      second.revoke!(by: @first, reason_code: "duty_ended")
    end
  end

  test "a non-continuity capability can be revoked from its only holder, but only once" do
    grant = OperatorCapabilityGrant.create!(
      operator: @first,
      granted_by_operator: @second,
      origin: "grant",
      capability: OperatorCapabilityGrant::SUPPORT_CONSOLE_READ,
      reason_code: "duty_assignment",
      starts_at: 1.minute.ago,
      expires_at: 1.day.from_now,
    )

    grant.revoke!(by: @second, reason_code: "duty_ended")

    assert_equal @second, grant.reload.revoked_by_operator
    assert_raises(OperatorCapabilityGrant::AlreadyRevokedError) do
      grant.revoke!(by: @second, reason_code: "duty_ended")
    end
  end

  test "bootstrap! grants only to an eligible operator and only known capabilities" do
    grants = OperatorCapabilityGrant.bootstrap!(
      operator: @first,
      capabilities: [OperatorCapabilityGrant::IAM_CAPABILITY_READ, OperatorCapabilityGrant::IAM_CAPABILITY_GRANT],
      ticket_id: "OPS-1",
      expires_at: 30.days.from_now,
    )

    assert_equal %w(bootstrap bootstrap), grants.map(&:origin)
    assert_raises(ArgumentError) do
      OperatorCapabilityGrant.bootstrap!(
        operator: @first,
        capabilities: ["iam.*"],
        ticket_id: "OPS-1",
        expires_at: 30.days.from_now,
      )
    end
    assert_raises(ArgumentError) do
      OperatorCapabilityGrant.bootstrap!(
        operator: @first,
        capabilities: [],
        ticket_id: "OPS-1",
        expires_at: 30.days.from_now,
      )
    end
    @second.update_columns(withdrawal_started_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    assert_raises(ArgumentError) do
      OperatorCapabilityGrant.bootstrap!(
        operator: @second.reload,
        capabilities: [OperatorCapabilityGrant::IAM_CAPABILITY_READ],
        ticket_id: "OPS-1",
        expires_at: 30.days.from_now,
      )
    end
  end
end
