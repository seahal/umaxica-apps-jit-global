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

  private

  def record_stop
    Client.transaction do
      @client.lock!
      IdentityAuthenticationStopRecorder.call(actor: @client, reason: "withdrawal_suspend")
    end
  end
end
