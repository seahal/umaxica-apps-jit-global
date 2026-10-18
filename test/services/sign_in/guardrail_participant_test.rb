# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module SignIn
  class GuardrailParticipantTest < ActiveSupport::TestCase
    test "empty guardrail stack advances cycle to checkpoint" do
      actor = create_client
      cycle = create_cycle(actor)

      result = SignInGuardrailParticipant.new(cycle: cycle, actor: actor, evaluators: []).advance_if_clear!

      assert_predicate result, :empty?
      assert_predicate result, :cleared?
      assert_not_predicate result, :blocking?
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
      assert_equal "CHECKPOINT_PENDING", cycle.state_name_for(cycle.state_id)
    end

    test "blocking evaluator stops without advancing" do
      actor = create_client
      cycle = create_cycle(actor)
      evaluator =
        lambda do |**|
          SignInParticipantItem.new(key: :blocked_for_test, blocking: true, cleared: false)
        end

      result = SignInGuardrailParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).advance_if_clear!

      assert_predicate result, :blocking?
      assert_equal [:blocked_for_test], result.stack.map(&:key)
      assert_predicate cycle.reload, :sign_in_guardrail_pending?
      assert_equal "GUARDRAIL_PENDING", cycle.state_name_for(cycle.state_id)
    end

    test "cleared blocking evaluator advances" do
      actor = create_client
      cycle = create_cycle(actor)
      evaluator =
        lambda do |**|
          SignInParticipantItem.new(key: :cleared_for_test, blocking: true, cleared: true)
        end

      result = SignInGuardrailParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).advance_if_clear!

      assert_not_predicate result, :blocking?
      assert_equal [:cleared_for_test], result.stack.map(&:key)
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
    end

    test "login blocked actor becomes guardrail blocking item" do
      actor = create_client(status_id: ClientStatus::RESERVED)
      cycle = create_cycle(actor)

      result = SignInGuardrailParticipant.new(cycle: cycle, actor: actor).advance_if_clear!

      assert_predicate result, :blocking?
      assert_includes result.stack.map(&:key), :actor_login_not_allowed
      assert_predicate cycle.reload, :sign_in_guardrail_pending?
    end

    # The retired session-limit placeholder no longer blocks the whole account: a pending flow
    # elsewhere must not hold every other sign-in hostage.
    test "a leftover restricted session does not block the guardrail" do
      actor = create_client
      ClientToken.create!(user: actor, user_token_status_id: ClientTokenStatus::RESTRICTED)
      cycle = create_cycle(actor)

      result = SignInGuardrailParticipant.new(cycle: cycle, actor: actor).advance_if_clear!

      assert_not_predicate result, :blocking?
      assert_predicate cycle.reload, :sign_in_checkpoint_pending?
    end

    test "raises when evaluator returns non-item" do
      actor = create_client
      cycle = create_cycle(actor)
      evaluator = ->(**) { "not_an_item" }

      assert_raises(ArgumentError, match: /guardrail evaluator must return SignInParticipantItem/) do
        SignInGuardrailParticipant.new(cycle: cycle, actor: actor, evaluators: [evaluator]).advance_if_clear!
      end
    end

    test "default guardrail advances for visitor and operator without blocking items" do
      [
        [VisitorSignInFlow, create_visitor],
        [OperatorSignInFlow, create_operator],
      ].each do |cycle_class, actor|
        cycle = create_cycle(actor, cycle_class: cycle_class)

        result = SignInGuardrailParticipant.new(cycle: cycle, actor: actor).advance_if_clear!

        assert_predicate result, :cleared?
        assert_predicate cycle.reload, :sign_in_checkpoint_pending?
      end
    end

    test "expired guardrail persists expiry and returns refusal after its outer transaction commits" do
      now = ClientSignInFlow.database_now
      cycle = ClientSignInFlow.create!(
        state_id: ClientSignInFlow.state_id_for("GUARDRAIL_PENDING"),
        nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.hex(16)),
        issued_at: now - 2.minutes, expires_at: now - 1.minute,
      )

      outcome =
        ClientSignInFlow.transaction(requires_new: true) do
          SignInGuardrailParticipant.new(cycle: cycle, actor: nil, evaluators: []).advance_if_clear!
        end

      assert_predicate outcome, :expired?
      assert_predicate cycle.reload, :sign_in_expired?
      assert_raises(FlowInvalidTransition) { outcome.value! }
    end

    private

    def create_client(status_id: ClientStatus::ACTIVE)
      Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: status_id)
    end

    def create_visitor
      Visitor.create!(public_id: "v_#{SecureRandom.hex(8)}", status_id: VisitorStatus::ACTIVE)
    end

    def create_operator
      Operator.create!(status_id: OperatorStatus::ACTIVE)
    end

    def create_cycle(actor, cycle_class: ClientSignInFlow)
      cycle_class.create!(
        principal_id: actor.id,
        state_id: cycle_class.state_id_for("GUARDRAIL_PENDING"),
        return_to: "/dashboard",
        nonce_digest: cycle_class.digest_nonce("nonce"),
        issued_at: Time.current,
        expires_at: 15.minutes.from_now,
      )
    end
  end
end
