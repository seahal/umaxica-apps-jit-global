# frozen_string_literal: true

require "test_helper"

class RpStepUpStateTransitionTest < ActiveSupport::TestCase
  test "a transition cannot duplicate its target state for one ceremony" do
    result = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_base_app"),
      issuer: "https://www.umaxica.app",
      subject: "step-up-transition-subject",
      sid: "step-up-transition-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )
    owner = RpStepUpState.create!(
      public_id: "123456789abcdefghijkl",
      rp_session: result.session,
      state_digest: Digest::SHA256.hexdigest("transition-state"),
      browser_binding_digest: Digest::SHA256.hexdigest("transition-browser"),
      nonce_digest: Digest::SHA256.hexdigest("transition-nonce"),
      pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      pkce_verifier_ciphertext: "ciphertext:v1:test-value",
      issuer: "https://www.umaxica.app",
      realm: "APP",
      client_id: "base-app-ww",
      return_target: "/settings/security",
      initiating_generation: 0,
      state: RpStepUpStateStatus.find(RpStepUpStateStatus::PENDING),
      expires_at: Time.utc(2099, 1, 1),
    )
    attributes = {
      owner: owner,
      from_state: RpStepUpStateStatus.find(RpStepUpStateStatus::PENDING),
      to_state: RpStepUpStateStatus.find(RpStepUpStateStatus::DISPATCHING),
      reason_code: "dispatch_started",
      occurred_at: Time.utc(2026, 11, 3, 12),
    }
    RpStepUpStateTransition.create!(attributes)

    assert_raises(ActiveRecord::RecordNotUnique) { RpStepUpStateTransition.create!(attributes) }
  end

  test "the database rejects a reason code outside the closed contract set" do
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpStepUpStateTransition.insert!(
          {
            owner_id: -1,
            from_state_id: RpStepUpStateStatus::PENDING,
            to_state_id: RpStepUpStateStatus::DISPATCHING,
            reason_code: "future_reason",
            occurred_at: Time.utc(2026, 11, 3, 12),
          },
        )
      end

    assert_includes error.message, "chk_rp_step_up_transition_reason"
  end
end
