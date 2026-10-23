# frozen_string_literal: true

require "test_helper"

class OpIdentityEventInvalidatorTest < ActiveSupport::TestCase
  fixtures :clients

  setup do
    @client = clients(:one)
    @client.update_columns(authentication_epoch: 0)
  end

  test "recording a stop advances the actor epoch and appends one Zenith event in the actor transaction" do
    event = record_stop

    assert_equal 1, @client.reload.authentication_epoch
    assert_equal [@client.id.to_s, "app", 1, "withdrawal_suspend", "all_sessions"],
                 [event.actor_ref, event.realm, event.cutoff_epoch, event.reason, event.scope]
  end

  test "applying the event revokes roots issued before the cutoff, including unrecorded ones" do
    old_root = ClientToken.create!(user: @client, authentication_epoch: 0)
    legacy_root = ClientToken.create!(authentication_epoch: 0, user: @client)
    event = record_stop

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    assert_predicate old_root.reload, :revoked?
    assert_predicate legacy_root.reload, :revoked?
  end

  test "a delayed stop event never revokes a root established after recovery under a newer epoch" do
    event = record_stop
    recovered_root = ClientToken.create!(user: @client, authentication_epoch: 1)

    OpIdentityEventInvalidator.call(event:)

    assert_not_predicate recovered_root.reload, :revoked?
  end

  test "the same event is applied once; a redelivery is a duplicate" do
    event = record_stop

    assert_equal :applied, OpIdentityEventInvalidator.call(event:)
    assert_equal :duplicate, OpIdentityEventInvalidator.call(event:)
    assert_equal 1, OpAppInboundEventReceipt.where(event_id: event.event_id).count
  end

  test "an unavailable OP leaves a durable retry instead of losing the stop" do
    event = record_stop

    OpIdentityEventInvalidator.stub(:call, ->(**) { raise ActiveRecord::ConnectionNotEstablished }) do
      assert_enqueued_with(job: OpIdentityEventDeliveryJob, args: [event.class.name, event.id]) do
        assert_equal :enqueued, OpIdentityEventInvalidator.deliver(event:)
      end
    end
  end

  private

  include ActiveJob::TestHelper

  def record_stop
    Client.transaction do
      @client.lock!
      IdentityAuthenticationStopRecorder.call(actor: @client, reason: "withdrawal_suspend")
    end
  end
end
