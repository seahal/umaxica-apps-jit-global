# frozen_string_literal: true

require "test_helper"

class SessionLimitResolutionUniquenessTest < ActiveSupport::TestCase
  SURFACES = [
    [Client, ClientStatus::ACTIVE, ClientVisibility::USER, ClientSignInFlow, ClientSessionLimitResolutionTransaction],
    [Visitor, VisitorStatus::ACTIVE, VisitorVisibility::VISITOR, VisitorSignInFlow,
     VisitorSessionLimitResolutionTransaction,],
    [Operator, OperatorStatus::ACTIVE, OperatorVisibility::STAFF, OperatorSignInFlow,
     OperatorSessionLimitResolutionTransaction,],
  ].freeze

  SURFACES.each do |principal_class, status, visibility, flow_class, resolution_class|
    test "#{resolution_class.name} retains issue replay refusal raw uniqueness and terminal history" do
      actor = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      now = flow_class.database_now
      flow = flow_class.create!(
        principal_id: actor.id, state_id: flow_class.state_id_for("SESSION_ISSUANCE_PENDING"),
        nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)), issued_at: now, expires_at: now + 300,
      )
      first = resolution_class.issue!(sign_in_flow: flow, actor: actor, browser_binding_digest: "a" * 64)
      replay = resolution_class.issue!(sign_in_flow: flow, actor: actor, browser_binding_digest: "a" * 64)

      assert_equal first.transaction.id, replay.transaction.id
      assert_equal 1, resolution_class.where(sign_in_flow_id: flow.id).count
      attributes = replay.transaction.attributes.except("id", "created_at", "updated_at")
      assert_raises(ActiveRecord::RecordNotUnique) do
        resolution_class.transaction(requires_new: true) do
          raw_duplicate = resolution_class.new(
            attributes.merge(challenge_digest: resolution_class.digest_challenge("different")),
          )
          raw_duplicate.save!(validate: false)
        end
      end
      other_flow = flow_class.create!(
        principal_id: actor.id, state_id: flow_class.state_id_for("SESSION_ISSUANCE_PENDING"),
        nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)), issued_at: now, expires_at: now + 300,
      )
      assert_raises(SessionLimitResolutionTransactionable::WaitingSlotOccupied) do
        resolution_class.issue!(sign_in_flow: other_flow, actor: actor, browser_binding_digest: "b" * 64)
      end
      replay.transaction.cancel!(actor: actor, challenge: replay.challenge, browser_binding_digest: "a" * 64)
      replacement = resolution_class.issue!(sign_in_flow: flow, actor: actor, browser_binding_digest: "a" * 64)

      assert_not_equal replay.transaction.id, replacement.transaction.id
      assert_predicate replay.transaction.reload, :cancelled?
      assert_predicate replacement.transaction, :pending?
    end

    test "#{resolution_class.name} preflights both exact partial keys on creation" do
      actor = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      now = flow_class.database_now
      flow = flow_class.create!(
        principal_id: actor.id, state_id: flow_class.state_id_for("SESSION_ISSUANCE_PENDING"),
        nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)), issued_at: now, expires_at: now + 300,
      )
      first = resolution_class.issue!(sign_in_flow: flow, actor: actor, browser_binding_digest: "a" * 64).transaction
      attributes = first.attributes.except("id", "created_at", "updated_at")
      duplicate = resolution_class.new(
        attributes.merge(challenge_digest: resolution_class.digest_challenge("different")),
      )

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:sign_in_flow_id, :taken)
      assert duplicate.errors.of_kind?(:actor_ref, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
      other_actor = principal_class.create!(
        security_mode_id: SecurityModeConfigurable::NORMAL, status_id: status,
        visibility_id: visibility,
      )
      same_parent = resolution_class.new(
        attributes.merge(
          actor_ref: other_actor.public_id,
          challenge_digest: resolution_class.digest_challenge("other-actor"),
        ),
      )

      assert_not same_parent.valid?
      assert same_parent.errors.of_kind?(:sign_in_flow_id, :taken)
      assert_not same_parent.errors.of_kind?(:actor_ref, :taken)
      other_flow = flow_class.create!(
        principal_id: actor.id, state_id: flow_class.state_id_for("SESSION_ISSUANCE_PENDING"),
        nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)), issued_at: now, expires_at: now + 300,
      )
      same_actor = resolution_class.new(
        attributes.merge(
          sign_in_flow_id: other_flow.id,
          challenge_digest: resolution_class.digest_challenge("other-flow"),
        ),
      )

      assert_not same_actor.valid?
      assert_not same_actor.errors.of_kind?(:sign_in_flow_id, :taken)
      assert same_actor.errors.of_kind?(:actor_ref, :taken)
      elapsed = resolution_class.new(
        attributes.merge(
          expires_at: now - 1,
          challenge_digest: resolution_class.digest_challenge("elapsed"),
        ),
      )

      assert_not elapsed.valid?
      assert elapsed.errors.of_kind?(:sign_in_flow_id, :taken)
      assert elapsed.errors.of_kind?(:actor_ref, :taken)
      closed = resolution_class.new(
        attributes.merge(
          challenge_digest: resolution_class.digest_challenge("closed"),
          state_id: SessionLimitResolutionTransactionable::CANCELLED,
          waiting_slot: nil, cancelled_at: now,
        ),
      )

      assert_predicate closed, :valid?
    end
  end
end
