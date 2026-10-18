# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawableTest < ActiveSupport::TestCase
  test "recovery and permanent deletion boundary at purge deadline" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 31.days.ago,
      discard_at: 31.days.ago,
      purge_eligible_at: Time.current,
    )

    assert_not user.can_recover?, "Client should not be able to recover at exact boundary"
    assert_predicate user, :permanently_deletable?
  end

  test "withdrawable methods available on user" do
    user = Client.find_by!(public_id: "one_id")

    assert_respond_to user, :withdrawn?
    assert_respond_to user, :active?
    assert_respond_to user, :recovery_deadline
  end

  test "withdrawable methods available on staff" do
    staff = Operator.create!

    assert_respond_to staff, :withdrawn?
    assert_respond_to staff, :active?
    assert_respond_to staff, :recovery_deadline
  end

  # withdrawn? tests
  test "withdrawn? returns true when withdrawn_at is set" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: Time.current)

    assert_predicate user, :withdrawn?
  end

  test "withdrawn? returns false when withdrawn_at is nil" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_not user.withdrawn?
  end

  # active? tests
  test "active? returns true when withdrawn_at is nil" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_predicate user, :active?
  end

  test "active? returns false when withdrawn_at is set" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: Time.current)

    assert_not user.active?
  end

  test "active? returns false when deactivated_at is set" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil, deactivated_at: Time.current)

    assert_not user.active?
  end

  test "suspended? returns true between deactivation and purge" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(
      withdrawn_at: nil, deactivated_at: Time.current, discard_at: Time.current,
      purge_eligible_at: 31.days.from_now,
    )

    assert_predicate user, :suspended?
    assert_not user.terminated?
    assert_not user.active?
  end

  test "closing? returns true after withdrawal starts before suspension" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil, withdrawal_started_at: Time.current, deactivated_at: nil)

    assert_predicate user, :closing?
    assert_not user.active?
  end

  test "can_recover? waits one hour after suspension" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 30.minutes.ago,
      discard_at: 30.minutes.ago,
      purge_eligible_at: 30.days.from_now,
    )

    assert_not user.can_recover?

    user.update_columns(deactivated_at: 61.minutes.ago, discard_at: 61.minutes.ago)

    assert_predicate user, :can_recover?
  end

  test "early_terminatable? waits seven days after suspension" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 6.days.ago,
      discard_at: 6.days.ago,
      purge_eligible_at: 25.days.from_now,
    )

    assert_not user.early_terminatable?

    user.update_columns(deactivated_at: 8.days.ago, discard_at: 8.days.ago)

    assert_predicate user, :early_terminatable?
  end

  test "terminated? returns true after purge deadline" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 32.days.ago,
      discard_at: 32.days.ago,
      purge_eligible_at: 1.day.ago,
    )

    assert_predicate user, :terminated?
    assert_not user.suspended?
    assert_not user.can_recover?
    assert_predicate user, :permanently_deletable?
  end

  # recovery_deadline tests
  test "recovery_deadline returns nil when not suspended" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_nil user.recovery_deadline
  end

  test "recovery_deadline returns purge_eligible_at while suspended" do
    user = Client.find_by!(public_id: "one_id")
    deadline = 30.days.from_now
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 1.hour.ago,
      discard_at: 1.hour.ago,
      purge_eligible_at: deadline,
    )

    assert_in_delta deadline.to_i, user.recovery_deadline.to_i, 1
  end

  # can_recover? tests
  test "can_recover? returns true during suspended recovery window" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 2.hours.ago,
      discard_at: 2.hours.ago,
      purge_eligible_at: 30.days.from_now,
    )

    assert_predicate user, :can_recover?
  end

  test "can_recover? returns false when not suspended" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_not user.can_recover?
  end

  test "can_recover? returns false at purge deadline" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 31.days.ago,
      discard_at: 31.days.ago,
      purge_eligible_at: Time.current,
    )

    assert_not user.can_recover?
  end

  test "can_recover? returns false after purge deadline" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 32.days.ago,
      discard_at: 32.days.ago,
      purge_eligible_at: 1.day.ago,
    )

    assert_not user.can_recover?
  end

  test "can_recover? returns true when 1 second before purge deadline" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 31.days.ago,
      discard_at: 31.days.ago,
      purge_eligible_at: 1.second.from_now,
    )

    assert_predicate user, :can_recover?
  end

  # permanently_deletable? tests
  test "permanently_deletable? returns false when active" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil)

    assert_not user.permanently_deletable?
  end

  test "permanently_deletable? returns false for withdrawn marker without purge eligibility" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: 15.days.ago)

    assert_not user.permanently_deletable?
  end

  test "permanently_deletable? returns true at purge deadline" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 31.days.ago,
      discard_at: 31.days.ago,
      purge_eligible_at: Time.current,
    )

    assert_predicate user, :permanently_deletable?
  end

  test "permanently_deletable? returns true after purge deadline" do
    user = Client.find_by!(public_id: "one_id")
    user.update_columns(
      withdrawn_at: nil,
      deactivated_at: 32.days.ago,
      discard_at: 32.days.ago,
      purge_eligible_at: 1.day.ago,
    )

    assert_predicate user, :permanently_deletable?
  end

  # withdrawn scope test
  test "withdrawn scope returns only withdrawn clients" do
    user1 = Client.find_by!(public_id: "one_id")
    user1.update!(withdrawn_at: 1.day.ago)

    user2 = Client.find_by!(public_id: "two_id")
    user2.update!(withdrawn_at: nil)

    withdrawn_users = Client.withdrawn

    assert_includes withdrawn_users, user1
    assert_not_includes withdrawn_users, user2
  end

  test "withdrawn scope returns empty when no clients are withdrawn" do
    Client.update_all(withdrawn_at: nil)

    withdrawn_users = Client.withdrawn

    assert_empty withdrawn_users
  end

  # Staff integration tests
  test "staff withdrawn? works correctly" do
    staff = Operator.create!
    staff.update!(withdrawn_at: Time.current)

    assert_predicate staff, :withdrawn?

    staff.update!(withdrawn_at: nil)

    assert_not staff.withdrawn?
  end

  test "staff active? works correctly" do
    staff = Operator.create!
    staff.update!(withdrawn_at: nil)

    assert_predicate staff, :active?

    staff.update!(withdrawn_at: Time.current)

    assert_not staff.active?
  end

  test "staff can_recover? works correctly" do
    staff = Operator.create!
    staff.update_columns(deactivated_at: 15.days.ago, discard_at: 15.days.ago, purge_eligible_at: 16.days.from_now)

    assert_predicate staff, :can_recover?

    staff.update_columns(deactivated_at: 32.days.ago, discard_at: 32.days.ago, purge_eligible_at: 1.day.ago)

    assert_not staff.can_recover?
  end

  test "staff permanently_deletable? works correctly" do
    staff = Operator.create!
    staff.update_columns(deactivated_at: 15.days.ago, discard_at: 15.days.ago, purge_eligible_at: 16.days.from_now)

    assert_not staff.permanently_deletable?

    staff.update_columns(deactivated_at: 32.days.ago, discard_at: 32.days.ago, purge_eligible_at: 1.day.ago)

    assert_predicate staff, :permanently_deletable?
  end

  test "staff suspended? works with the same retention columns as app and com actors" do
    staff = Operator.create!
    staff.update_columns(deactivated_at: 2.hours.ago, discard_at: 2.hours.ago, purge_eligible_at: 31.days.from_now)

    assert_predicate staff, :suspended?
    assert_not staff.active?
    assert_predicate staff, :can_recover?
  end

  test "operator withdrawal_in_progress? delegates to withdrawable concern" do
    staff = Operator.create!
    staff.update_columns(withdrawal_started_at: Time.current, deactivated_at: nil)

    assert_predicate staff, :withdrawal_in_progress?
    assert_predicate staff, :withdrawal_in_progress?
  end

  test "withdrawal_in_progress? returns true when closing" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil, withdrawal_started_at: Time.current, deactivated_at: nil)

    assert_predicate user, :withdrawal_in_progress?
  end

  test "withdrawal_in_progress? returns true when suspended" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(
      withdrawn_at: nil, deactivated_at: Time.current, discard_at: Time.current,
      purge_eligible_at: 31.days.from_now,
    )

    assert_predicate user, :withdrawal_in_progress?
  end

  test "withdrawal_in_progress? returns false when neither closing nor suspended" do
    user = Client.find_by!(public_id: "one_id")
    user.update!(withdrawn_at: nil, withdrawal_started_at: nil, deactivated_at: nil)

    assert_not user.withdrawal_in_progress?
  end
end
