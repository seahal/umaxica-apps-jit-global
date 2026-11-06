# frozen_string_literal: true

require "test_helper"

class RpStepUpStateTest < ActiveSupport::TestCase
  test "the database rejects a state stored in the other realm" do
    result = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_base_app"),
      issuer: "https://www.umaxica.app",
      subject: "step-up-state-subject",
      sid: "step-up-state-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )

    assert_predicate result, :success?
    state = {
      public_id: "123456789abcdefghijkl",
      rp_session_id: result.session.id,
      state_digest: Digest::SHA256.hexdigest("state-digest"),
      browser_binding_digest: Digest::SHA256.hexdigest("browser-binding"),
      nonce_digest: Digest::SHA256.hexdigest("nonce"),
      pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      pkce_verifier_ciphertext: "ciphertext:v1:test-value",
      issuer: "https://www.umaxica.app",
      realm: "ORG",
      client_id: "base-app-ww",
      return_target: "/settings/security",
      initiating_generation: 0,
      state_id: RpStepUpStateStatus::PENDING,
      expires_at: Time.utc(2099, 1, 1),
      created_at: Time.utc(2026, 11, 3, 12),
      updated_at: Time.utc(2026, 11, 3, 12),
    }

    error = assert_raises(ActiveRecord::StatementInvalid) { RpStepUpState.insert!(state) }

    assert_includes error.message, "chk_rp_step_up_states_realm"
  end

  test "the state digest is unique" do
    result = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_base_app"),
      issuer: "https://www.umaxica.app",
      subject: "step-up-digest-subject",
      sid: "step-up-digest-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )
    state = RpStepUpState.create!(
      public_id: "123456789abcdefghijkl",
      rp_session: result.session,
      state_digest: Digest::SHA256.hexdigest("duplicate-state-digest"),
      browser_binding_digest: Digest::SHA256.hexdigest("browser-binding"),
      nonce_digest: Digest::SHA256.hexdigest("nonce"),
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

    assert_raises(ActiveRecord::RecordNotUnique) do
      RpStepUpState.create!(
        public_id: "223456789abcdefghijkl",
        rp_session: result.session,
        state_digest: state.state_digest,
        browser_binding_digest: Digest::SHA256.hexdigest("other-browser-binding"),
        nonce_digest: Digest::SHA256.hexdigest("other-nonce"),
        pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        pkce_verifier_ciphertext: "ciphertext:v1:other-value",
        issuer: "https://www.umaxica.app",
        realm: "APP",
        client_id: "base-app-ww",
        return_target: "/settings/security",
        initiating_generation: 0,
        state: RpStepUpStateStatus.find(RpStepUpStateStatus::PENDING),
        expires_at: Time.utc(2099, 1, 1),
      )
    end
  end
end
