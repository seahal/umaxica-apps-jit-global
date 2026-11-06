# frozen_string_literal: true

require "test_helper"

class RpBaseOrgStepUpStateTransitionTest < ActiveSupport::TestCase
  test "a transition cannot duplicate its target state for one ceremony" do
    result = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_base_org"),
      issuer: "https://www.umaxica.org",
      subject: "step-up-transition-subject",
      sid: "step-up-transition-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )
    owner = RpBaseOrgStepUpState.create!(
      public_id: "123456789abcdefghijkl",
      rp_session: result.session,
      state_digest: Digest::SHA256.hexdigest("transition-state"),
      browser_binding_digest: Digest::SHA256.hexdigest("transition-browser"),
      nonce_digest: Digest::SHA256.hexdigest("transition-nonce"),
      pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      pkce_verifier_ciphertext: "ciphertext:v1:test-value",
      issuer: "https://www.umaxica.org",
      realm: "ORG",
      client_id: "base-org-ww",
      return_target: "/settings/security",
      initiating_generation: 0,
      state: RpBaseOrgStepUpStateStatus.find(RpBaseOrgStepUpStateStatus::PENDING),
      expires_at: Time.utc(2099, 1, 1),
    )
    attributes = {
      owner: owner,
      from_state: RpBaseOrgStepUpStateStatus.find(RpBaseOrgStepUpStateStatus::PENDING),
      to_state: RpBaseOrgStepUpStateStatus.find(RpBaseOrgStepUpStateStatus::DISPATCHING),
      reason_code: "dispatch_started",
      occurred_at: Time.utc(2026, 11, 3, 12),
    }
    RpBaseOrgStepUpStateTransition.create!(attributes)

    assert_raises(ActiveRecord::RecordNotUnique) { RpBaseOrgStepUpStateTransition.create!(attributes) }
  end

  test "the database rejects a reason code outside the closed contract set" do
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgStepUpStateTransition.insert!(
          {
            owner_id: -1,
            from_state_id: RpBaseOrgStepUpStateStatus::PENDING,
            to_state_id: RpBaseOrgStepUpStateStatus::DISPATCHING,
            reason_code: "future_reason",
            occurred_at: Time.utc(2026, 11, 3, 12),
          },
        )
      end

    assert_includes error.message, "chk_rp_step_up_transition_reason"
  end
end
