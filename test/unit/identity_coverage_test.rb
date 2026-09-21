# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityCoverageTest < ActiveSupport::TestCase
  setup do
    ClientStatus.find_or_create_by!(id: 1)
    ClientVisibility.find_or_create_by!(id: 1)
    @user = Client.create!(status_id: 1, visibility_id: 1)
  end

  test "login_allowed?" do
    assert_predicate @user, :login_allowed?

    # Blocked status
    @user.update!(status_id: ClientStatus::RESERVED)

    assert_not @user.login_allowed?
  end

  test "recovery_deadline and can_recover?" do
    assert_nil @user.recovery_deadline

    now = Time.current
    deadline = now + 31.days
    @user.update!(deactivated_at: now, discard_at: now, purge_eligible_at: deadline)
    @user.reload

    assert_equal deadline.to_i, @user.recovery_deadline.to_i
    assert_not @user.can_recover?

    @user.update!(deactivated_at: 2.hours.ago)

    assert_predicate @user, :can_recover?
  end
end
