# typed: false
# frozen_string_literal: true

require "test_helper"

class AdministrativeAccessLockableTest < ActiveSupport::TestCase
  test "defaults access state to enabled" do
    assert_predicate Client.new(security_mode_id: SecurityModeConfigurable::NORMAL), :access_enabled?
    assert_predicate Visitor.new(security_mode_id: SecurityModeConfigurable::NORMAL), :access_enabled?
    assert_predicate Operator.new(security_mode_id: SecurityModeConfigurable::ADVANCED), :access_enabled?
  end

  test "requires lock metadata when admin locked" do
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED)

    assert_not client.valid?
    assert_includes client.errors[:admin_locked_at], "must be present when access is admin locked"
    assert_includes client.errors[:admin_locked_by_operator_id], "must be present when access is admin locked"
    assert_includes client.errors[:admin_locked_reason_code], "must be present when access is admin locked"
  end

  test "rejects invalid reason codes" do
    client = Client.new(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: 1,
      admin_locked_reason_code: "invalid",
    )

    assert_not client.valid?
    assert_includes client.errors.details[:admin_locked_reason_code].pluck(:error), :inclusion
  end

  test "treats access tokens issued before token_valid_after_at as stale" do
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, token_valid_after_at: Time.current)

    assert client.access_token_stale_for_administrative_lock?("iat" => 1.minute.ago.to_i)
    assert_not client.access_token_stale_for_administrative_lock?("iat" => 1.minute.from_now.to_i)
  end

  test "access_locked? mirrors admin_locked?" do
    locked = Client.new(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
      admin_locked_at: Time.current,
      admin_locked_by_operator_id: 1,
      admin_locked_reason_code: "other",
    )

    assert_predicate locked, :access_locked?

    enabled = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL)

    assert_not enabled.access_locked?
  end

  test "lock metadata without admin_locked state is inconsistent" do
    client = Client.new(security_mode_id: SecurityModeConfigurable::NORMAL, admin_locked_at: Time.current)

    assert_not client.valid?
    assert_includes client.errors[:access_state], "must be admin_locked when lock metadata is present"
  end
end
