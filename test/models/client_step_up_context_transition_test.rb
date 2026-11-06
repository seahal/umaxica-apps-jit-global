# frozen_string_literal: true

require "test_helper"

class ClientStepUpContextTransitionTest < ActiveSupport::TestCase
  test "the database rejects a reason code outside the closed contract set" do
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        ClientStepUpContextTransition.insert!(
          {
            owner_id: -1,
            from_state_id: ClientStepUpContextState::PENDING,
            to_state_id: ClientStepUpContextState::COMMITTED,
            reason_code: "future_reason",
            occurred_at: Time.utc(2026, 11, 3, 12),
          },
        )
      end

    assert_includes error.message, "chk_client_step_up_transition_reason"
  end

  test "a transition cannot outlive its context owner" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientStepUpContextTransition.insert!(
        {
          owner_id: -1,
          from_state_id: ClientStepUpContextState::PENDING,
          to_state_id: ClientStepUpContextState::COMMITTED,
          reason_code: "completed",
          occurred_at: Time.utc(2026, 11, 3, 12),
        },
      )
    end
  end
end
