# typed: false
# frozen_string_literal: true

require "test_helper"

class WithdrawalLifecycleTest < ActiveSupport::TestCase
  fixtures :clients, :visitors, :operators, :operator_statuses

  setup do
    @request = ActionDispatch::Request.new({})
    @session_public_id = "test-session-public-id"
  end

  class WithdrawalLifecycleTest::TestTokenScope
    class Filter < Struct.new(:scope)
      def not(**) = scope
    end

    def initialize(records = []) = @records = records

    def find_each(&) = @records.each(&)

    def klass = ClientToken

    def where(**) = Filter.new(self)

    def column_names = []
  end

  test "start! creates a requested withdrawal flow for a client" do
    client = clients(:one)

    result = WithdrawalLifecycle.start!(actor: client, current_session_public_id: @session_public_id, request: @request)

    assert_same client, result
    assert_equal 1, client.client_withdrawal_flows.count
    assert_predicate client.client_withdrawal_flows.first, :withdrawal_requested?
  end

  test "start! returns existing requested flow without creating another" do
    client = clients(:one)
    flow = client.client_withdrawal_flows.create!(
      status_id: ClientWithdrawalFlowStatus::REQUESTED,
      began_at: Time.current,
    )

    assert_no_difference -> { client.client_withdrawal_flows.count } do
      WithdrawalLifecycle.start!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    assert_equal flow.id, client.client_withdrawal_flows.recent_first.first.id
  end

  test "start! returns existing closing flow" do
    client = clients(:one)
    flow = client.client_withdrawal_flows.create!(
      status_id: ClientWithdrawalFlowStatus::CLOSING,
      began_at: Time.current,
    )

    assert_no_difference -> { client.client_withdrawal_flows.count } do
      WithdrawalLifecycle.start!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    assert_equal flow.id, client.client_withdrawal_flows.recent_first.first.id
  end

  test "start! returns existing discarded flow" do
    client = clients(:one)
    flow = client.client_withdrawal_flows.create!(
      status_id: ClientWithdrawalFlowStatus::DISCARDED,
      began_at: Time.current,
      discarded_at: 1.day.from_now,
    )

    assert_no_difference -> { client.client_withdrawal_flows.count } do
      WithdrawalLifecycle.start!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    assert_equal flow.id, client.client_withdrawal_flows.recent_first.first.id
  end

  test "start! creates a new requested flow when existing flow is terminal" do
    client = clients(:one)
    client.client_withdrawal_flows.create!(
      status_id: ClientWithdrawalFlowStatus::RECOVERED,
      began_at: Time.current,
      completed_at: Time.current,
    )

    assert_difference -> { client.client_withdrawal_flows.count }, 1 do
      WithdrawalLifecycle.start!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    assert_predicate client.client_withdrawal_flows.recent_first.first, :withdrawal_requested?
  end

  test "suspend! creates and discards a flow and deactivates a client" do
    client = clients(:one)

    AuthenticationSessionRevoker.stub(:tokens_for, TestTokenScope.new) do
      WithdrawalLifecycle.suspend!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    assert_not_nil client.reload.withdrawal_started_at
    assert_not_nil client.deactivated_at
    assert_not_nil client.discarded_at
    assert_predicate client, :suspended?

    flow = client.client_withdrawal_flows.recent_first.first

    assert_predicate flow, :withdrawal_discarded?
  end

  test "suspend! confirms a requested flow before discarding" do
    client = clients(:one)
    client.client_withdrawal_flows.create!(status_id: ClientWithdrawalFlowStatus::REQUESTED, began_at: Time.current)

    AuthenticationSessionRevoker.stub(:tokens_for, TestTokenScope.new) do
      WithdrawalLifecycle.suspend!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    assert_predicate client.reload, :suspended?
    assert_predicate client.client_withdrawal_flows.recent_first.first, :withdrawal_discarded?
  end

  test "suspend! preserves existing finite future purged_at" do
    client = clients(:one)
    future_purged_at = 10.days.from_now
    client.update_columns(deactivated_at: nil, purged_at: future_purged_at)

    AuthenticationSessionRevoker.stub(:tokens_for, TestTokenScope.new) do
      WithdrawalLifecycle.suspend!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    assert_in_delta Float(future_purged_at), Float(client.reload.purged_at), 1
  end

  test "suspend! computes purged_at from deactivated_at when existing purged_at is infinite" do
    client = clients(:one)
    deactivated_at = 2.days.ago
    client.update_columns(created_at: 3.days.ago, deactivated_at: deactivated_at, purged_at: Float::INFINITY)

    AuthenticationSessionRevoker.stub(:tokens_for, TestTokenScope.new) do
      WithdrawalLifecycle.suspend!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end

    client.reload

    assert_in_delta Float(deactivated_at), Float(client.deactivated_at), 1
    assert_in_delta Float((deactivated_at + WithdrawalLifecycle::RECOVERY_PERIOD)), Float(client.purged_at), 1
  end

  test "recover! raises when recovery is not available" do
    client = clients(:one)

    I18n.stub(:t, "recovery not available") do
      assert_raises(Sign::WithdrawalRecoveryNotAvailableError) do
        WithdrawalLifecycle.recover!(actor: client, request: @request)
      end
    end
  end

  test "recover! raises when privacy request blocks recovery" do
    client = clients(:one)
    client.update_columns(
      withdrawal_started_at: 2.days.ago,
      deactivated_at: 2.days.ago,
      discarded_at: 2.days.ago,
      purged_at: 29.days.from_now,
    )
    client.client_privacy_requests.create!(
      status_id: ClientPrivacyRequestStatus::VERIFIED,
      request_kind: "erasure",
      jurisdiction: "jp",
      request_source: "self_service",
      received_at: Time.current,
      response_due_at: 30.days.from_now,
    )

    I18n.stub(:t, "recovery not available") do
      assert_raises(Sign::WithdrawalRecoveryNotAvailableError) do
        WithdrawalLifecycle.recover!(actor: client, request: @request)
      end
    end
  end

  test "recover! cancels received privacy requests and recovers account" do
    client = clients(:one)
    client.update_columns(
      withdrawal_started_at: 2.days.ago,
      deactivated_at: 2.days.ago,
      discarded_at: 2.days.ago,
      purged_at: 29.days.from_now,
    )
    privacy_request = client.client_privacy_requests.create!(
      status_id: ClientPrivacyRequestStatus::RECEIVED,
      request_kind: "erasure",
      jurisdiction: "jp",
      request_source: "self_service",
      received_at: Time.current,
      response_due_at: 30.days.from_now,
    )
    client.client_withdrawal_flows.create!(
      status_id: ClientWithdrawalFlowStatus::DISCARDED,
      began_at: 2.days.ago,
      discarded_at: 2.days.ago,
    )

    WithdrawalLifecycle.recover!(actor: client, request: @request)

    assert_equal ClientPrivacyRequestStatus::CANCELLED, privacy_request.reload.status_id
    assert_nil client.reload.withdrawal_started_at
    assert_nil client.deactivated_at
    assert_equal Float::INFINITY, client.discarded_at
    assert_equal Float::INFINITY, client.purged_at
  end

  test "recover! creates a discarded flow when none exists" do
    client = clients(:one)
    client.update_columns(
      withdrawal_started_at: 2.days.ago,
      deactivated_at: 2.days.ago,
      discarded_at: 2.days.ago,
      purged_at: 29.days.from_now,
    )

    assert_difference -> { client.client_withdrawal_flows.count }, 1 do
      WithdrawalLifecycle.recover!(actor: client, request: @request)
    end

    assert_predicate client.client_withdrawal_flows.recent_first.first, :withdrawal_recovered?
  end

  test "recover! recovers a visitor" do
    visitor = visitors(:reserved_visitor)
    visitor.update_columns(
      withdrawal_started_at: 2.days.ago,
      deactivated_at: 2.days.ago,
      discarded_at: 2.days.ago,
      purged_at: 29.days.from_now,
    )

    WithdrawalLifecycle.recover!(actor: visitor, request: @request)

    assert_nil visitor.reload.withdrawal_started_at
    assert_nil visitor.deactivated_at
  end

  test "terminate! raises when actor is not early terminatable" do
    client = clients(:one)

    I18n.stub(:t, "invalid state") do
      error =
        assert_raises(Sign::InvalidWithdrawalStateError) do
          WithdrawalLifecycle.terminate!(actor: client, request: @request)
        end

      assert_equal "Client", error.context[:current_status]
    end
  end

  test "terminate! anonymizes and terminates a suspended client" do
    client = clients(:one)
    client.update_columns(
      withdrawal_started_at: 10.days.ago,
      deactivated_at: 10.days.ago,
      discarded_at: 10.days.ago,
      purged_at: 21.days.from_now,
      withdrawn_at: 10.days.ago,
    )
    client.client_withdrawal_flows.create!(
      status_id: ClientWithdrawalFlowStatus::DISCARDED,
      began_at: 10.days.ago,
      discarded_at: 10.days.ago,
    )

    AuthenticationSessionRevoker.stub(:tokens_for, TestTokenScope.new) do
      WithdrawalPersonalDataAnonymizer.stub(:call, ->(actor:) { actor }) do
        WithdrawalLifecycle.terminate!(actor: client, request: @request)
      end
    end

    assert_predicate client.reload, :terminated?
    flow = client.client_withdrawal_flows.recent_first.first

    assert_predicate flow, :withdrawal_terminated?
  end

  test "start! creates a requested withdrawal flow for a visitor" do
    visitor = visitors(:reserved_visitor)

    WithdrawalLifecycle.start!(actor: visitor, current_session_public_id: @session_public_id, request: @request)

    assert_equal 1, visitor.visitor_withdrawal_flows.count
    assert_predicate visitor.visitor_withdrawal_flows.first, :withdrawal_requested?
  end

  test "suspend! deactivates a visitor" do
    visitor = visitors(:reserved_visitor)

    AuthenticationSessionRevoker.stub(:tokens_for, TestTokenScope.new) do
      WithdrawalLifecycle.suspend!(actor: visitor, current_session_public_id: @session_public_id, request: @request)
    end

    assert_predicate visitor.reload, :suspended?
    assert_predicate visitor.visitor_withdrawal_flows.recent_first.first, :withdrawal_discarded?
  end

  test "recover! raises when visitor recovery is not available" do
    visitor = visitors(:reserved_visitor)

    I18n.stub(:t, "recovery not available") do
      assert_raises(Sign::WithdrawalRecoveryNotAvailableError) do
        WithdrawalLifecycle.recover!(actor: visitor, request: @request)
      end
    end
  end

  test "terminate! terminates a suspended visitor" do
    visitor = visitors(:reserved_visitor)
    visitor.update_columns(
      withdrawal_started_at: 10.days.ago,
      deactivated_at: 10.days.ago,
      discarded_at: 10.days.ago,
      purged_at: 21.days.from_now,
      withdrawn_at: 10.days.ago,
    )
    visitor.visitor_withdrawal_flows.create!(
      status_id: VisitorWithdrawalFlowStatus::DISCARDED,
      began_at: 10.days.ago,
      discarded_at: 10.days.ago,
    )

    AuthenticationSessionRevoker.stub(:tokens_for, TestTokenScope.new) do
      WithdrawalPersonalDataAnonymizer.stub(:call, ->(actor:) { actor }) do
        WithdrawalLifecycle.terminate!(actor: visitor, request: @request)
      end
    end

    assert_predicate visitor.reload, :terminated?
    assert_predicate visitor.visitor_withdrawal_flows.recent_first.first, :withdrawal_terminated?
  end

  test "class methods delegate to instance methods" do
    client = clients(:one)

    assert_difference -> { client.client_withdrawal_flows.count }, 1 do
      WithdrawalLifecycle.start!(actor: client, current_session_public_id: @session_public_id, request: @request)
    end
  end

  test "start! refuses an actor with no withdrawal flow of its own" do
    assert_raises(Sign::InvalidWithdrawalStateError) do
      WithdrawalLifecycle.start!(actor: operators(:one), request: @request)
    end
  end
end
