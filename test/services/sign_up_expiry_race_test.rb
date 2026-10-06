# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpExpiryRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @flow = ClientSignUpFlow.create!(
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::FINALIZING,
      step: "finalizing",
      nonce_digest: ClientSignUpFlow.digest_nonce("expiry-race-nonce"),
      issued_at: 1.minute.ago,
      expires_at: 1.minute.from_now,
      entry_method: "email",
    )
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  teardown do
    ClientSignUpFlow.where(id: @flow&.id).delete_all
  end

  test "expiry rechecks a stale row and does not terminalize a completed flow" do
    stale_flow = ClientSignUpFlow.find(@flow.id)

    ClientSignUpFlow.connection_pool.with_connection do
      ClientSignUpFlow.find(@flow.id).complete_sign_up!
    end

    result = nil
    travel_to(@flow.expires_at + 1.second) do
      result = SignUpTermination.call(cycle: stale_flow, event: :expire)
    end

    assert_equal :invalid_transition, result.status
    assert_equal ClientSignUpFlowStatus::COMPLETED, @flow.reload.status_id
    assert_predicate @flow, :sign_up_completed?
  end
end
