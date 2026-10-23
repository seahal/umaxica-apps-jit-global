# frozen_string_literal: true

# E1 (WU-24h): a Sign-up Flow names the redeemed Admission Binding of its sign-up ceremony. Model and
# service tests that create a Flow directly obtain that Binding here, through the same public
# admission steps an OIDC sign-up entry takes (issue, attach, confirm, consume, admit, redeem).
module SignUpAdmissionTestFactory
  module_function

  SURFACES = { ClientSignUpFlow => "app", VisitorSignUpFlow => "com" }.freeze

  def binding_for!(flow_class)
    binding!(surface: SURFACES.fetch(flow_class))
  end

  def binding!(surface:)
    nonce = SecureRandom.urlsafe_base64(32)
    issuance = OidcTestEntry.issue!(surface:, intent: "sign_up", base_browser_nonce: nonce, base_token: nil)
    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: issuance.reference)
    model = binding.class.auth_admission_session_class
    attached, raw_sid = model.issue!
    binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
    binding.confirm_base!(
      base_token: nil,
      browser_digest: AuthAdmissionBinding.browser_digest(surface:, entry_ref: issuance.reference, nonce:),
    )
    BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: issuance.reference, surface:, expected_intent: "sign_up", binding:, raw_auth_sid: raw_sid,
    )
    admitted, = model.rotate_and_admit!(
      admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
      authorization_transaction_ref: issuance.transaction.transaction_id,
    )
    binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
    binding.reload
  end
end
