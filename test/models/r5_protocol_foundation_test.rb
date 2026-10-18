# typed: false
# frozen_string_literal: true

require "test_helper"

class R5ProtocolFoundationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REALMS = [
    {
      realm: "app",
      epoch: OpAppProtocolEpoch,
      consumed_jti: OpAppConsumedJti,
      flow: OpAppLogoutFlow,
      participant: OpAppLogoutFlowParticipant,
      receipt: OpAppLogoutReceipt,
      outbox: OpAppOutboxEvent,
      inbound: OpAppInboundEventReceipt,
    },
    {
      realm: "com",
      epoch: OpComProtocolEpoch,
      consumed_jti: OpComConsumedJti,
      flow: OpComLogoutFlow,
      participant: OpComLogoutFlowParticipant,
      receipt: OpComLogoutReceipt,
      outbox: OpComOutboxEvent,
      inbound: OpComInboundEventReceipt,
    },
    {
      realm: "org",
      epoch: OpOrgProtocolEpoch,
      consumed_jti: OpOrgConsumedJti,
      flow: OpOrgLogoutFlow,
      participant: OpOrgLogoutFlowParticipant,
      receipt: OpOrgLogoutReceipt,
      outbox: OpOrgOutboxEvent,
      inbound: OpOrgInboundEventReceipt,
    },
  ].freeze

  test "each realm has an initialized current contract epoch and separated protocol tables" do
    REALMS.each do |entry|
      assert_equal 1, entry.fetch(:epoch).find(1).contract_epoch
      assert_equal entry.fetch(:realm), entry.fetch(:epoch).find(1).realm
      assert_equal "op_consumed_jtis", entry.fetch(:consumed_jti).table_name
      assert_equal "logout_flows", entry.fetch(:flow).table_name
      assert_equal "logout_flow_participants", entry.fetch(:participant).table_name
      assert_equal "logout_receipts", entry.fetch(:receipt).table_name
      assert_equal "op_outbox_events", entry.fetch(:outbox).table_name
      assert_equal "op_inbound_event_receipts", entry.fetch(:inbound).table_name
    end
  end

  test "each realm consumed JTI record is once-only for its scoped purpose" do
    REALMS.each do |entry|
      model = entry.fetch(:consumed_jti)
      attributes = {
        purpose: "logout_token",
        issuer: "https://op.example.test",
        client_id: "base-app-ww",
        jti: "jti-#{entry.fetch(:realm)}",
        expires_at: 1.minute.from_now,
      }

      assert model.consume!(**attributes)
      assert_not model.consume!(**attributes)
      assert_equal 1, model.where(jti_digest: model.digest_jti(attributes.fetch(:jti))).count
    end
  end

  test "realm model validations reject cross-realm and negative delivery state" do
    flow = OpAppLogoutFlow.new(
      public_id: "flow-app",
      realm: "com",
      target_root_ref: "root",
      idempotency_digest: "i" * 32,
      browser_binding_digest: "b" * 32,
      expires_at: 1.minute.from_now,
      audit_ref: "audit",
    )

    assert_not_predicate flow, :valid?
    assert flow.errors.of_kind?(:realm, :inclusion)

    participant = OpAppLogoutFlowParticipant.new(
      issuer: "https://op.example.test",
      realm: "app",
      client_id: "base-app-ww",
      sid: "sid",
      endpoint_identity: "base-app-ww/logout",
      delivery_attempts: -1,
    )

    assert_not_predicate participant, :valid?
    assert participant.errors.of_kind?(:delivery_attempts, :greater_than_or_equal_to)
  end
end
