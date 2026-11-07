# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAuthAdmissionRegistrationRestartBrowserTest < ActiveSupport::TestCase
  fixtures :client_tokens

  test "registration restart accepts only the original browser and exact registration intent" do
    token = client_tokens(:one)
    nonce = SecureRandom.urlsafe_base64(32)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: token.user.public_id,
      session_ref: token.public_id,
      required_scope: "settings_passkey",
      required_aal: StepUpRequirement::NO_AAL,
      allowed_methods: ["passkey"],
      purpose: "credential_registration",
      audience: "step_up:app",
      token_binding: token.public_id,
      require_session_binding: true,
    )
    issuance = BaseAuthAdmissionCoordinator.issue_handoff!(
      transaction:,
      base_browser_nonce: nonce,
      base_token: token,
    )
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(
      surface: "app",
      reference: issuance.reference,
    )

    validated = BaseAuthAdmissionCoordinator.validate_registration_restart_browser!(
      binding:,
      surface: "app",
      base_browser_nonce: nonce,
      base_token: token,
      scope: "settings_passkey",
      method: "passkey",
    )

    assert_equal binding.id, validated.id
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_registration_restart_browser!(
        binding:,
        surface: "app",
        base_browser_nonce: SecureRandom.urlsafe_base64(32),
        base_token: token,
        scope: "settings_passkey",
        method: "passkey",
      )
    end
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.validate_registration_restart_browser!(
        binding:,
        surface: "app",
        base_browser_nonce: nonce,
        base_token: token,
        scope: "settings_totp",
        method: "passkey",
      )
    end
  end
end
