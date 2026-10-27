# typed: false
# frozen_string_literal: true

require "test_helper"

class R5ProtocolFoundationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REALMS = [
    {
      realm: "app",
      consumed_jti: OpAppConsumedJti,
      stop: OpAppAuthorityStop,
      participant: OpAppAuthorityStopParticipant,
      inbound: OpAppInboundEventReceipt,
    },
    {
      realm: "com",
      consumed_jti: OpComConsumedJti,
      stop: OpComAuthorityStop,
      participant: OpComAuthorityStopParticipant,
      inbound: OpComInboundEventReceipt,
    },
    {
      realm: "org",
      consumed_jti: OpOrgConsumedJti,
      stop: OpOrgAuthorityStop,
      participant: OpOrgAuthorityStopParticipant,
      inbound: OpOrgInboundEventReceipt,
    },
  ].freeze

  test "each realm has separated protocol tables" do
    REALMS.each do |entry|
      assert_equal "op_consumed_jtis", entry.fetch(:consumed_jti).table_name
      realm = entry.fetch(:realm)

      assert_equal "op_#{realm}_authority_stops", entry.fetch(:stop).table_name
      assert_equal "op_#{realm}_authority_stop_participants", entry.fetch(:participant).table_name
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
    stop = OpAppAuthorityStop.new(
      public_id: "stop-app",
      realm: "com",
      cause_id: OpAuthorityStopReference.cause_id("browser_logout"),
      scope_id: OpAuthorityStopReference.scope_id("root"),
      principal_public_id: "principal",
      authority_evidence_ref: "audit",
      idempotency_digest: "i" * 32,
      occurred_at: Time.current,
    )

    assert_not_predicate stop, :valid?
    assert stop.errors.of_kind?(:realm, :inclusion)

    participant = OpAppAuthorityStopParticipant.new(
      issuer: "https://op.example.test",
      client_id: "base-app-ww",
      sid: "sid",
      endpoint_identity: "base-app-ww/logout",
      delivery_attempts: -1,
      next_attempt_at: Time.current,
      deadline_at: Time.current,
      lease_expires_at: Time.current,
      last_outcome: "none",
    )

    assert_not_predicate participant, :valid?
    assert participant.errors.of_kind?(:delivery_attempts, :greater_than_or_equal_to)
  end
end
