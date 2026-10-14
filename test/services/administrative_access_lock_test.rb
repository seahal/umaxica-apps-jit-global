# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AdministrativeAccessLockTest < ActiveSupport::TestCase
  test "locks client access, revokes sessions, and records account access event" do
    client = clients(:one)
    operator = operators(:one)
    token = client_tokens(:one)
    rp_session = ClientRpSession.create!(
      client_token: token,
      oidc_client_id: "core-app",
      oidc_scope: "openid profile",
      refresh_token_expires_at: 1.hour.from_now,
    )

    AdministrativeAccessLock.lock!(
      account: client,
      operator: operator,
      reason_code: "security_incident",
      reason_note: "credential report",
      ticket_id: "SEC-1",
      metadata: { "source" => "test" },
    )

    client.reload
    token.reload
    event = AccountAccessEvent.order(:created_at).last

    assert_predicate client, :admin_locked?
    assert_equal operator.id, client.admin_locked_by_operator_id
    assert_equal "security_incident", client.admin_locked_reason_code
    assert_predicate client.token_valid_after_at, :present?
    assert_predicate token, :revoked?
    assert_predicate rp_session.reload, :revoked?
    assert_equal "Client", event.account_type
    assert_equal client.id, event.account_id
    assert_equal "admin_lock", event.event_type
    assert_equal "enabled", event.previous_access_state
    assert_equal "admin_locked", event.next_access_state
    assert_equal "SEC-1", event.ticket_id
  end

  test "unlock clears lock metadata and advances token validity" do
    client = clients(:one)
    operator = operators(:one)
    AdministrativeAccessLock.lock!(account: client, operator: operator, reason_code: "support_request")
    locked_threshold = client.reload.token_valid_after_at

    travel 1.second do
      AdministrativeAccessLock.unlock!(
        account: client,
        operator: operator,
        reason_code: "operator_error_recovery",
      )
    end

    client.reload
    event = AccountAccessEvent.order(:created_at).last

    assert_predicate client, :access_enabled?
    assert_nil client.admin_locked_at
    assert_nil client.admin_locked_by_operator_id
    assert_nil client.admin_locked_reason_code
    assert_predicate client.reactivated_at, :present?
    assert_operator client.token_valid_after_at, :>, locked_threshold
    assert_equal "admin_unlock", event.event_type
    assert_equal "admin_locked", event.previous_access_state
    assert_equal "enabled", event.next_access_state
  end

  test "does not lock the last enabled operator" do
    operator = operators(:one)

    Operator.where.not(id: operator.id).find_each do |other|
      other.update!(
        access_state: AdministrativeAccessLockable::ACCESS_STATE_ADMIN_LOCKED,
        admin_locked_at: Time.current,
        admin_locked_by_operator_id: operator.id,
        admin_locked_reason_code: "security_incident",
      )
    end

    assert_raises(AdministrativeAccessLock::LastEnabledOperatorError) do
      AdministrativeAccessLock.lock!(
        account: operator,
        operator: operator,
        reason_code: "security_incident",
      )
    end
  end

  test "an unregistered reason code is refused before anything is written" do
    client = clients(:one)
    operator = operators(:one)

    error =
      assert_no_difference -> { AccountAccessEvent.count } do
        assert_raises(ArgumentError) do
          AdministrativeAccessLock.lock!(account: client, operator: operator, reason_code: "not_a_reason")
        end
      end

    assert_equal "reason_code is invalid", error.message
  end
end
