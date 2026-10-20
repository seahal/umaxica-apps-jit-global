# typed: false
# frozen_string_literal: true

require "test_helper"

class DeviceSessionableTest < ActiveSupport::TestCase
  setup do
    ClientStatus.ensure_defaults!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    @user = Client.create!(public_id: PublicId.generate, status_id: ClientStatus::ACTIVE)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
  end

  test "active scope returns only active unreleased sessions" do
    active = create_device_session(status_id: DeviceSessionable::STATUS_ACTIVE)
    revoked = ClientDeviceSession.create!(
      user: @user,
      current_refresh_token: @token,
      status_id: DeviceSessionable::STATUS_REVOKED,
      revoked_at: Time.current,
    )

    active_sessions = ClientDeviceSession.active.to_a

    assert_includes active_sessions, active
    assert_not_includes active_sessions, revoked
  end

  test "revoked? is true when status or revoked_at is revoked" do
    active = ClientDeviceSession.new(status_id: DeviceSessionable::STATUS_ACTIVE)
    revoked_by_status = ClientDeviceSession.new(status_id: DeviceSessionable::STATUS_REVOKED)
    revoked_by_time = ClientDeviceSession.new(status_id: DeviceSessionable::STATUS_ACTIVE, revoked_at: Time.current)

    assert_not_predicate active, :revoked?
    assert_predicate revoked_by_status, :revoked?
    assert_predicate revoked_by_time, :revoked?
  end

  test "dbsc bound and fallback predicates reflect bound timestamp" do
    fallback = ClientDeviceSession.new
    bound = ClientDeviceSession.new(dbsc_bound_at: Time.current)

    assert_predicate fallback, :fallback_session?
    assert_not_predicate fallback, :dbsc_bound?

    assert_predicate bound, :dbsc_bound?
    assert_not_predicate bound, :fallback_session?
  end

  test "revoke! persists revoked state and reason without replacing existing revoked_at" do
    revoked_at = 1.hour.ago
    session = ClientDeviceSession.create!(
      user: @user,
      current_refresh_token: @token,
      status_id: DeviceSessionable::STATUS_ACTIVE,
      revoked_at: revoked_at,
    )

    session.revoke!(reason: "manual_review")

    assert_equal DeviceSessionable::STATUS_REVOKED, session.reload.status_id
    assert_equal "manual_review", session.revoke_reason
    assert_equal revoked_at.to_i, session.revoked_at.to_i
  end

  test "bind_dbsc! persists session digest and public key thumbprint" do
    session = create_device_session(status_id: DeviceSessionable::STATUS_ACTIVE)

    session.bind_dbsc!(session_id: "dbsc-session-id", public_key_thumbprint: "thumbprint")

    session.reload

    assert_predicate session, :dbsc_bound?
    assert_equal "thumbprint", session.dbsc_public_key_thumbprint
    assert_equal ClientDeviceSession.digest_session_identifier("dbsc-session-id"), session.dbsc_session_id_digest
  end

  private

  def create_device_session(attributes)
    ClientDeviceSession.create!(
      {
        user: @user,
        current_refresh_token: @token,
      }.merge(attributes),
    )
  end
end
