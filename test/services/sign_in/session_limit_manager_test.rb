# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module SignIn
  class SessionLimitManagerTest < ActiveSupport::TestCase
    test "issues restricted client token and binds it to session-limit cycle" do
      actor = create_client
      cycle = create_cycle(ClientSignInFlow, actor)

      result = SignInSessionLimitManager.new(cycle: cycle, actor: actor).issue_restricted!

      assert_instance_of ClientToken, result.token
      assert_predicate result.token, :restricted?
      assert_equal actor.id, result.token.user_id
      assert_equal result.token, result.cycle.token
      assert_predicate result.refresh_token, :present?
      assert_in_delta TokenStatusManagement::RESTRICTED_TTL.from_now.to_i, result.token.discard_at.to_i, 2
      assert_predicate result.cycle, :sign_in_session_limit_pending?
    end

    test "issues restricted visitor and operator tokens on their own surfaces" do
      [
        [VisitorSignInFlow, create_visitor, VisitorToken, :visitor_id],
        [OperatorSignInFlow, create_operator, OperatorToken, :staff_id],
      ].each do |cycle_class, actor, token_class, foreign_key|
        cycle = create_cycle(cycle_class, actor)

        result = SignInSessionLimitManager.new(cycle: cycle, actor: actor).issue_restricted!

        assert_instance_of token_class, result.token
        assert_predicate result.token, :restricted?
        assert_equal actor.id, result.token.public_send(foreign_key)
        assert_equal result.token, result.cycle.token
      end
    end

    test "promotes pending cycle without issuing a token and advances cycle to guardrail" do
      actor = create_client
      cycle = create_cycle(ClientSignInFlow, actor)

      result = SignInSessionLimitManager.new(cycle: cycle.reload, actor: actor).promote!

      assert_nil result.token
      assert_predicate result.cycle, :sign_in_guardrail_pending?
      assert_equal "guardrail", result.cycle.step
    end

    test "promotion is blocked while active session limit is still full" do
      actor = create_client
      create_active_client_token(actor)
      create_active_client_token(actor)
      cycle = create_cycle(ClientSignInFlow, actor)

      assert_raises(SignInSessionLimitManager::PromotionBlocked) do
        SignInSessionLimitManager.new(cycle: cycle.reload, actor: actor).promote!
      end

      assert_predicate cycle.reload, :sign_in_session_limit_pending?
    end

    test "cancel fails pending cycle without requiring a restricted token" do
      actor = create_client
      cycle = create_cycle(ClientSignInFlow, actor)

      result = SignInSessionLimitManager.new(cycle: cycle.reload, actor: actor).cancel!

      assert_nil result.token
      assert_predicate result.cycle, :sign_in_failed?
      assert_equal "failed", result.cycle.step
    end

    test "rejects actor mismatch without issuing restricted token" do
      actor = create_client
      other = create_client
      cycle = create_cycle(ClientSignInFlow, actor)

      assert_no_difference("ClientToken.count") do
        assert_raises(SignInSessionLimitManager::ActorMismatch) do
          SignInSessionLimitManager.new(cycle: cycle, actor: other).issue_restricted!
        end
      end

      assert_predicate cycle.reload, :sign_in_session_limit_pending?
      assert_nil cycle.token_id
    end

    test "rejects non-session-limit cycle without issuing token" do
      actor = create_client
      cycle = create_cycle(ClientSignInFlow, actor, status_name: "GUARDRAIL_PENDING")

      assert_no_difference("ClientToken.count") do
        assert_raises(SignInSessionLimitManager::InvalidCycle) do
          SignInSessionLimitManager.new(cycle: cycle, actor: actor).issue_restricted!
        end
      end

      assert_predicate cycle.reload, :sign_in_guardrail_pending?
      assert_nil cycle.token_id
    end

    test "rejects expired session-limit cycle without issuing token" do
      actor = create_client
      cycle = create_cycle(ClientSignInFlow, actor, issued_at: 20.minutes.ago, expires_at: 1.second.ago)

      assert_no_difference("ClientToken.count") do
        assert_raises(SignInSessionLimitManager::InvalidCycle) do
          SignInSessionLimitManager.new(cycle: cycle, actor: actor).issue_restricted!
        end
      end

      assert_predicate cycle.reload, :sign_in_session_limit_pending?
      assert_nil cycle.token_id
    end

    test "rejects issuing a second restricted token for an already bound cycle" do
      actor = create_client
      cycle = create_cycle(ClientSignInFlow, actor)
      SignInSessionLimitManager.new(cycle: cycle, actor: actor).issue_restricted!

      assert_no_difference("ClientToken.count") do
        assert_raises(SignInSessionLimitManager::InvalidCycle) do
          SignInSessionLimitManager.new(cycle: cycle.reload, actor: actor).issue_restricted!
        end
      end
    end

    private

    def create_client
      Client.create!(public_id: "u_#{SecureRandom.hex(8)}", status_id: ClientStatus::ACTIVE)
    end

    def create_visitor
      Visitor.create!(public_id: "v_#{SecureRandom.hex(8)}", status_id: VisitorStatus::ACTIVE)
    end

    def create_operator
      Operator.create!(status_id: OperatorStatus::ACTIVE)
    end

    def create_active_client_token(actor)
      ClientToken.create!(user: actor)
    end

    def create_cycle(cycle_class, actor, status_name: "SESSION_LIMIT_PENDING", **overrides)
      cycle_class.create!(
        {
          principal_id: actor.id,
          status_id: cycle_class.status_id_for(status_name),
          step: step_for(status_name),
          return_to: "/dashboard",
          nonce_digest: cycle_class.digest_nonce("nonce"),
          issued_at: Time.current,
          expires_at: 15.minutes.from_now,
        }.merge(overrides),
      )
    end

    def step_for(status_name)
      {
        "SESSION_LIMIT_PENDING" => "session_limit",
        "GUARDRAIL_PENDING" => "guardrail",
      }.fetch(status_name)
    end
  end
end
