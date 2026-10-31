# frozen_string_literal: true

require "test_helper"

# R5-WU06 recoverable sweep: a committed identity stop event that never reached the OP (crash after
# the Zenith commit, lost enqueue) is applied regardless of age; applied events are not repeated.
class OpIdentityEventSweepJobTest < ActiveJob::TestCase
  fixtures :clients

  setup do
    @client = clients(:one)
    @client.update_columns(authentication_epoch: 0)
  end

  test "an event with no OP receipt is applied and its old roots revoked" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event = record_stop

    OpIdentityEventSweepJob.perform_now

    assert OpAppInboundEventReceipt.exists?(event_id: event.event_id)
    assert_predicate root.reload, :revoked?
  end

  test "an already applied event is not applied again" do
    event = record_stop
    OpIdentityEventInvalidator.call(event:)

    assert_no_difference -> { OpAppInboundEventReceipt.where(event_id: event.event_id).count } do
      OpIdentityEventSweepJob.perform_now
    end
  end

  test "a different sender's receipt does not suppress a pending stop during a sweep" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event = record_stop
    foreign = OpAppInboundEventReceipt.create!(
      event_id: event.event_id, issuer: OidcIssuer.for_resource_type("client"), realm: "app",
      client_id: "other-client", event_type: "identity_authentication_stop", committed_at: event.committed_at,
    )

    OpIdentityEventSweepJob.perform_now

    assert_predicate root.reload, :revoked?
    assert_predicate foreign.reload, :persisted?
    assert_equal 2, OpAppInboundEventReceipt.where(event_id: event.event_id).count
  end

  test "a same-sender receipt with a conflicting event type is reported during a sweep" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event = record_stop
    OpAppInboundEventReceipt.create!(
      event_id: event.event_id, issuer: OidcIssuer.for_resource_type("client"), realm: "app",
      client_id: "base-app-ww", event_type: "other_event", committed_at: event.committed_at,
    )
    reports = []

    Rails.error.stub(:report, ->(error, **options) { reports << [error, options] }) do
      assert_raises(ArgumentError) { OpIdentityEventSweepJob.perform_now }
    end

    assert_not_predicate root.reload, :revoked?
    assert_equal 1, reports.length
    assert_same false, reports.first.last.fetch(:handled)
  end

  test "a changed source cutoff is not hidden by an existing receipt during a sweep" do
    event = record_stop

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    event.update!(cutoff_epoch: event.cutoff_epoch + 1)
    reports = []

    Rails.error.stub(:report, ->(error, **options) { reports << [error, options] }) do
      assert_raises(ArgumentError) { OpIdentityEventSweepJob.perform_now }
    end

    assert_equal 1, reports.length
    assert_same false, reports.first.last.fetch(:handled)
  end

  test "an unapplied stop survives a prolonged outage rather than aging out of recovery" do
    root = ClientToken.create!(user: @client, authentication_epoch: 0)
    event =
      Client.transaction do
        @client.lock!
        IdentityAuthenticationStopRecorder.call(actor: @client, reason: "withdrawal_suspend")
      end
    event.update!(committed_at: 30.days.ago)

    OpIdentityEventSweepJob.perform_now

    assert OpAppInboundEventReceipt.exists?(event_id: event.event_id)
    assert_predicate root.reload, :revoked?
    assert AppIdentityAuthenticationEvent.exists?(event_id: event.event_id)
  end

  test "with no events the sweep does nothing" do
    assert_no_difference -> { OpAppInboundEventReceipt.count } do
      OpIdentityEventSweepJob.perform_now
    end
  end

  test "an unavailable APP receipt store does not prevent ORG stop recovery" do
    app_root = ClientToken.create!(user: @client, authentication_epoch: 0)
    app_event = record_stop
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    org_root = OperatorToken.create!(staff: operator, authentication_epoch: 0)
    org_event =
      Operator.transaction do
        operator.lock!
        IdentityAuthenticationStopRecorder.call(actor: operator, reason: "administrative_access_lock")
      end
    reports = []

    Rails.error.stub(:report, ->(error, **options) { reports << [error, options] }) do
      OpAppInboundEventReceipt.stub(:where, ->(*) { raise ActiveRecord::ConnectionNotEstablished }) do
        OpIdentityEventSweepJob.perform_now
      end
    end

    assert_equal 1, reports.length
    assert_instance_of ActiveRecord::ConnectionNotEstablished, reports.first.first
    assert_not OpAppInboundEventReceipt.exists?(event_id: app_event.event_id)
    assert_not_predicate app_root.reload, :revoked?
    assert OpOrgInboundEventReceipt.exists?(event_id: org_event.event_id)
    assert_predicate org_root.reload, :revoked?

    OpIdentityEventSweepJob.perform_now

    assert OpAppInboundEventReceipt.exists?(event_id: app_event.event_id)
    assert_predicate app_root.reload, :revoked?
  end

  test "an invalid APP event is reported after later APP and ORG stops are processed" do
    poison = record_stop
    poison.update!(reason: "unsupported_reason")
    app_root = ClientToken.create!(user: @client, authentication_epoch: 1)
    valid_app = record_stop
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, status_id: OperatorStatus::ACTIVE)
    org_root = OperatorToken.create!(staff: operator, authentication_epoch: 0)
    valid_org =
      Operator.transaction do
        operator.lock!
        IdentityAuthenticationStopRecorder.call(actor: operator, reason: "administrative_access_lock")
      end
    reports = []

    Rails.error.stub(:report, ->(error, **options) { reports << [error, options] }) do
      assert_raises(ArgumentError) { OpIdentityEventSweepJob.perform_now }
    end

    assert_not OpAppInboundEventReceipt.exists?(event_id: poison.event_id)
    assert OpAppInboundEventReceipt.exists?(event_id: valid_app.event_id)
    assert OpOrgInboundEventReceipt.exists?(event_id: valid_org.event_id)
    assert_predicate app_root.reload, :revoked?
    assert_predicate org_root.reload, :revoked?
    assert_equal 1, reports.length
    assert_same false, reports.first.last.fetch(:handled)
  end

  private

  def record_stop
    Client.transaction do
      @client.lock!
      IdentityAuthenticationStopRecorder.call(actor: @client, reason: "withdrawal_suspend")
    end
  end
end
