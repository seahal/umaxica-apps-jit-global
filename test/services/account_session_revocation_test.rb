# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AccountSessionRevocationTest < ActiveSupport::TestCase
  test "purges client sessions and records a non-sensitive account access event" do
    client = clients(:one)
    operator = operators(:one)
    AuthenticationSessionRevoker.tokens_for(client).find_each(&:revoke!)
    token = ClientToken.create!(authentication_epoch: 0, user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)

    assert_difference -> { ClientSignOutFlow.count }, 1 do
      result = AccountSessionRevocation.purge!(
        account: client,
        operator: operator,
        reason_code: "security_incident",
        reason_note: "reported compromise",
        ticket_id: "SEC-633",
      )

      assert_equal 1, result.revoked_count
      assert_equal AccountAccessEvent::EVENT_TYPE_SESSION_PURGE, result.event.event_type
    end

    event = AccountAccessEvent.order(:created_at).last

    assert_predicate token.reload, :revoked?
    assert_equal "Client", event.account_type
    assert_equal client.id, event.account_id
    assert_equal client.access_state, event.previous_access_state
    assert_equal client.access_state, event.next_access_state
    assert_equal operator.id, event.operator_id
    assert_equal "SEC-633", event.ticket_id
    assert_equal 1, event.metadata.fetch("revoked_count")
    assert_equal({ "ClientToken" => 1 }, event.metadata.fetch("token_classes"))
    assert_not_includes event.metadata.to_s, token.public_id
  end

  test "emergency revoke records an event when there are no live tokens" do
    client = clients(:two)
    operator = operators(:one)
    AuthenticationSessionRevoker.tokens_for(client).find_each(&:revoke!)

    assert_no_difference -> { ClientSignOutFlow.count } do
      result = AccountSessionRevocation.emergency_revoke!(
        account: client,
        operator: operator,
        reason_code: "support_request",
      )

      assert_equal 0, result.revoked_count
      assert_equal AccountAccessEvent::EVENT_TYPE_EMERGENCY_SESSION_REVOKE, result.event.event_type
    end

    event = AccountAccessEvent.order(:created_at).last

    assert_equal 0, event.metadata.fetch("revoked_count")
    assert_equal({}, event.metadata.fetch("token_classes"))
  end

  test "revokes visitor and operator sessions through the shared primitive" do
    visitor = visitors(:reserved_visitor)
    operator = operators(:one)
    target_operator = operators(:two)
    visitor_token = VisitorToken.create!(authentication_epoch: 0, visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    operator_token = OperatorToken.create!(authentication_epoch: 0, staff: target_operator, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    AccountSessionRevocation.purge!(
      account: visitor,
      operator: operator,
      reason_code: "security_incident",
    )
    AccountSessionRevocation.emergency_revoke!(
      account: target_operator,
      operator: operator,
      reason_code: "security_incident",
    )

    assert_predicate visitor_token.reload, :revoked?
    assert_predicate operator_token.reload, :revoked?
    assert_equal AccountAccessEvent::EVENT_TYPE_EMERGENCY_SESSION_REVOKE,
                 AccountAccessEvent.order(:created_at).last.event_type
  end

  test "rejects invalid inputs without recording an event" do
    assert_no_difference -> { AccountAccessEvent.count } do
      assert_raises(ArgumentError) do
        AccountSessionRevocation.purge!(
          account: clients(:one),
          operator: clients(:two),
          reason_code: "security_incident",
        )
      end
    end

    assert_no_difference -> { AccountAccessEvent.count } do
      assert_raises(ArgumentError) do
        AccountSessionRevocation.purge!(
          account: clients(:one),
          operator: operators(:one),
          reason_code: "not_a_reason",
        )
      end
    end
  end
end
