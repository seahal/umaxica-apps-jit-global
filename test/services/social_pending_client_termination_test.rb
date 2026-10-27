# frozen_string_literal: true

require "test_helper"

class SocialPendingClientTerminationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "A05-6: cancel expiry and halt retire an unlinked pending social client" do
    client = OidcClientRegistry.find!("core-app-jp")
    { cancel: ClientSignUpFlowStatus::CANCELLED,
      expire: ClientSignUpFlowStatus::EXPIRED,
      halt: ClientSignUpFlowStatus::HALTED, }.each do |event, terminal_status|
      nonce = SecureRandom.urlsafe_base64(32)
      issuance = OidcAuthorizationTransactionCoordinator.issue_with_handoff!(
        surface: "app", intent: "sign_up", base_browser_nonce: nonce, base_token: nil,
        params: {
          client_id: client.client_id,
          response_type: "code",
          scope: "openid profile",
          redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
          state: SecureRandom.urlsafe_base64(24),
          nonce: SecureRandom.urlsafe_base64(24),
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
          code_challenge_method: "S256",
        },
      )
      binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.handoff.reference)
      attached, raw_sid = ClientAuthCeremonySession.issue!
      binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
      binding.confirm_base!(
        base_token: nil, browser_digest: AuthAdmissionBinding.browser_digest(
          surface: "app", entry_ref: binding.entry_ref, nonce: nonce,
        ),
      )
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: binding.entry_ref, surface: "app", expected_intent: "sign_up", binding: binding, raw_auth_sid: raw_sid,
      )
      admitted, = ClientAuthCeremonySession.rotate_and_admit!(
        admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
        authorization_transaction_ref: issuance.transaction.transaction_id,
      )
      binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
      actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::UNVERIFIED_WITH_SIGN_UP)
      now = ClientSignUpFlow.database_now
      flow = ClientSignUpFlow.create!(
        auth_admission_binding: binding, principal_id: actor.id, entry_method: "google", social_provider: "google",
        pending_contact_type: "social_identity", pending_contact_id: nil,
        nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
        status_id: ClientSignUpFlowStatus::CHECKPOINT_PENDING, step: "checkpoint", issued_at: now,
        expires_at: now + 15.minutes,
      )

      SignUpTermination.call(cycle: flow, event: event)

      assert_equal terminal_status, flow.reload.status_id, event
      assert_equal ClientSignUpFlowCleanupStatus::COMPLETED, flow.cleanup_status_id, event
      assert_operator actor.reload.discard_at, :<=, Client.database_now, event
      assert_not actor.accessible?, event
      assert_not ClientExternalIdentity.exists?(client_id: actor.id), event
      assert_equal 0, ClientToken.where(user_id: actor.id).count, event
    end
  end
end
