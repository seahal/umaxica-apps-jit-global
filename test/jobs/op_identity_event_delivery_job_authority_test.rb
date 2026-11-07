# typed: false
# frozen_string_literal: true

require "test_helper"

class OpIdentityEventDeliveryJobAuthorityTest < ActiveSupport::TestCase
  fixtures :clients

  test "delivery applies the persisted APP stop event through the OP invalidator" do
    actor = clients(:one)
    actor.update_columns(authentication_epoch: 0)
    root = ClientToken.create!(user: actor, authentication_epoch: 0)
    event =
      Client.transaction do
        actor.lock!
        IdentityAuthenticationStopRecorder.call(actor:, reason: "withdrawal_suspend")
      end

    OpIdentityEventDeliveryJob.perform_now(event.class.name, event.id)

    assert_predicate root.reload, :revoked?
    assert OpAppInboundEventReceipt.exists?(event_id: event.event_id)
  end

  test "delivery rejects an unregistered event class before resolving it" do
    assert_no_difference -> { OpAppInboundEventReceipt.count } do
      assert_raises(ArgumentError) do
        OpIdentityEventDeliveryJob.perform_now("Object", 1)
      end
    end
  end
end
