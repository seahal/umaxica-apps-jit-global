# frozen_string_literal: true

require "test_helper"

class RpBaseOrgStepUpStateTest < ActiveSupport::TestCase
  test "the database rejects a state stored in the other realm" do
    result = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_base_org"),
      issuer: "https://www.umaxica.org",
      subject: "step-up-state-subject",
      sid: "step-up-state-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )

    assert_predicate result, :success?
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgStepUpState.insert!(
          {
            public_id: "123456789abcdefghijkl",
            rp_session_id: result.session.id,
            state_digest: Digest::SHA256.hexdigest("state-digest"),
            browser_binding_digest: Digest::SHA256.hexdigest("browser-binding"),
            nonce_digest: Digest::SHA256.hexdigest("nonce"),
            pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            pkce_verifier_ciphertext: "ciphertext:v1:test-value",
            issuer: "https://www.umaxica.org",
            realm: "APP",
            client_id: "base-org-ww",
            return_target: "/settings/security",
            initiating_generation: 0,
            state_id: RpBaseOrgStepUpStateStatus::PENDING,
            expires_at: Time.utc(2099, 1, 1),
            created_at: Time.utc(2026, 11, 3, 12),
            updated_at: Time.utc(2026, 11, 3, 12),
          },
        )
      end

    assert_includes error.message, "chk_rp_step_up_states_realm"
  end

  test "the state digest is unique" do
    result = RpCallbackCommitter.call(
      cell: RpCellBinding.fetch("rp_base_org"),
      issuer: "https://www.umaxica.org",
      subject: "step-up-digest-subject",
      sid: "step-up-digest-sid",
      absolute_expires_at: Time.utc(2099, 1, 1),
    )
    state = RpBaseOrgStepUpState.create!(
      public_id: "123456789abcdefghijkl",
      rp_session: result.session,
      state_digest: Digest::SHA256.hexdigest("duplicate-state-digest"),
      browser_binding_digest: Digest::SHA256.hexdigest("browser-binding"),
      nonce_digest: Digest::SHA256.hexdigest("nonce"),
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

    assert_raises(ActiveRecord::RecordNotUnique) do
      RpBaseOrgStepUpState.create!(
        public_id: "223456789abcdefghijkl",
        rp_session: result.session,
        state_digest: state.state_digest,
        browser_binding_digest: Digest::SHA256.hexdigest("other-browser-binding"),
        nonce_digest: Digest::SHA256.hexdigest("other-nonce"),
        pkce_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        pkce_verifier_ciphertext: "ciphertext:v1:other-value",
        issuer: "https://www.umaxica.org",
        realm: "ORG",
        client_id: "base-org-ww",
        return_target: "/settings/security",
        initiating_generation: 0,
        state: RpBaseOrgStepUpStateStatus.find(RpBaseOrgStepUpStateStatus::PENDING),
        expires_at: Time.utc(2099, 1, 1),
      )
    end
  end
end
