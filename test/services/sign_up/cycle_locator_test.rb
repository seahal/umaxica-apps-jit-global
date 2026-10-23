# typed: false
# frozen_string_literal: true

require "test_helper"

module SignUp
  class CycleLocatorTest < ActiveSupport::TestCase
    test "issue stores a session locator and current resolves the cycle of the admitted owner" do
      session = {}
      cycle = create_cycle(nonce: "old-nonce")
      locator = SignUpCycleLocator.new(session, surface: :app)

      locator.issue!(cycle, nonce: "fresh-nonce")

      assert_equal cycle.public_id, session.dig(:app_sign_up_flow_locator, "public_id")
      assert_equal "fresh-nonce", session.dig(:app_sign_up_flow_locator, "nonce")
      assert_equal cycle, current_for(locator, cycle)
      assert cycle.reload.nonce_matches?("fresh-nonce")
      assert_not cycle.nonce_matches?("old-nonce")
    end

    test "bad nonce is an ownership mismatch and leaves the cycle state unchanged" do
      session = {}
      cycle = create_cycle(nonce: "correct-nonce")
      locator = SignUpCycleLocator.new(session, surface: :app)
      locator.issue!(cycle, nonce: "correct-nonce")

      session[:app_sign_up_flow_locator]["nonce"] = "bad-nonce"

      assert_raises(SignUpCycleLocator::OwnershipMismatch) { current_for(locator, cycle) }
      assert_equal ClientSignUpFlowStatus::STARTED, cycle.reload.status_id
    end

    test "a hint naming an expired cycle is a mismatch and one naming its own ended attempt resolves nothing" do
      session = {}
      locator = SignUpCycleLocator.new(session, surface: :app)
      expired = create_cycle(nonce: "expired", issued_at: 2.minutes.ago, expires_at: 1.minute.ago)
      locator.issue!(expired, nonce: "expired")

      assert_raises(SignUpCycleLocator::OwnershipMismatch) { current_for(locator, expired) }

      completed = create_cycle(
        nonce: "completed",
        status_id: ClientSignUpFlowStatus::COMPLETED,
        step: "completed",
        completed_at: Time.current,
      )
      locator.issue!(completed, nonce: "completed")

      assert_nil current_for(locator, completed)
      session[:app_sign_up_flow_locator]["nonce"] = "other-browser"

      assert_raises(SignUpCycleLocator::OwnershipMismatch) { current_for(locator, completed) }
    end

    test "a locator of another surface refuses this surface's admission" do
      cycle = create_cycle(nonce: "nonce")
      locator = SignUpCycleLocator.new({}, surface: :com)

      assert_raises(SignUpCycleLocator::OwnershipMismatch) { current_for(locator, cycle) }
    end

    private

    def current_for(locator, cycle)
      binding = cycle.class.find(cycle.id).association(:auth_admission_binding).scope.take
      ceremony = binding.class.auth_admission_session_class.find(binding.admitted_auth_ceremony_session_id)
      locator.current(admission_binding: binding, ceremony_session: ceremony)
    end

    def create_cycle(nonce:, **overrides)
      ClientSignUpFlow.create!(
        {
          auth_admission_binding: SignUpAdmissionTestFactory.binding_for!(ClientSignUpFlow),
          status_id: ClientSignUpFlowStatus::STARTED,
          step: "start",
          nonce_digest: ClientSignUpFlow.digest_nonce(nonce),
          issued_at: Time.current,
          expires_at: 15.minutes.from_now,
          entry_method: "telephone",
        }.merge(overrides),
      )
    end
  end
end
