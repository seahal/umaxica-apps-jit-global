# frozen_string_literal: true

require "test_helper"

class SignUpCompletedCancellationBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    ClientStatus.ensure_defaults!
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
  end

  %w(email telephone google apple).each do |method|
    test "#{method} completed signup refuses cancellation and preserves the registered actor" do
      actor = Client.create!(
        security_mode_id: ClientSecurityMode::NORMAL, status_id: ClientStatus::ACTIVE,
      )
      binding = SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow)
      now = ClientSignUpFlow.database_now
      flow = ClientSignUpFlow.create!(
        auth_admission_binding: binding, principal_id: actor.id,
        status_id: ClientSignUpFlowStatus::COMPLETED, step: "completed",
        nonce_digest: ClientSignUpFlow.digest_nonce("completed-cancel-boundary"),
        issued_at: now, expires_at: now + 15.minutes, completed_at: now,
        entry_method: method, social_provider: %w(google apple).include?(method) ? method : nil,
      )
      before_flow = flow.attributes
      before_actor = actor.attributes
      result = SignUpCancellation.call(cycle: flow, actor_context: nil)

      assert_predicate result, :failure?
      assert_equal before_flow, flow.reload.attributes
      assert_equal before_actor, actor.reload.attributes
      assert_predicate flow, :sign_up_completed?
    end
  end
end
