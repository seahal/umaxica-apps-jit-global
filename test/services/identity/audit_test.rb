# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityAuditTest < ActiveSupport::TestCase
  fixtures :clients, :client_chronicle_events, :client_chronicle_levels

  test "records client chronicle with request context" do
    actor = clients(:one)

    assert_difference("ClientChronicle.count", 1) do
      IdentityAudit.record!(
        actor: actor,
        event_id: ClientChronicleEvent::PASSKEY_REGISTERED,
        action: "passkey.register",
        ip_address: "192.0.2.10",
        user_agent: "Example Browser",
        metadata: { result: "success" },
      )
    end

    chronicle = ClientChronicle.order(:created_at).last

    assert_equal actor.id, chronicle.actor_id
    assert_equal "Client", chronicle.subject_type
    assert_equal actor.id.to_s, chronicle.subject_id.to_s
    assert_equal ClientChronicleEvent::PASSKEY_REGISTERED, chronicle.event_id
    assert_equal ClientChronicleLevel::NOTHING, chronicle.level_id
    assert_equal "192.0.2.10", chronicle.ip_address.to_s
    assert_equal "passkey.register", chronicle.context["action"]
    assert_equal "Example Browser", chronicle.context["user_agent"]
    assert_equal "success", chronicle.context["result"]
  end
end
