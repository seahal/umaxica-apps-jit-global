# frozen_string_literal: true

require "test_helper"

class BaseBootstrapAdmissionIssuerTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Base bootstrap is registration-only and retains the original protected return and deadline" do
    actor = Client.create!(status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(user: actor)
    requirement = StepUpRequirement.new(
      step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
      audience: "step_up:app", allowed_methods: %i(passkey totp),
      session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
    )
    first = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: first.transaction.transaction_id)
    record.update!(attempt_count: 2)
    repeated = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
    )

    assert_equal first.transaction.id, repeated.transaction.id
    assert_equal first.transaction.expires_at, repeated.transaction.expires_at
    assert_equal "bootstrap", first.transaction.purpose
    assert_equal "settings_birthdate", first.transaction.required_scope
    assert_equal "/identity/birthdate", first.transaction.return_to
    assert_equal "none", first.transaction.required_aal
    assert_not first.transaction.phishing_resistant_required
    assert_equal 2, record.reload.attempt_count
    assert_nil token.reload.last_step_up_at
    assert_equal "bootstrap_handoff", BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: repeated.reference, surface: "app", expected_intent: "bootstrap",
    ).fetch("purpose")
    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseAuthAdmissionCoordinator.consume_entry_reference!(
        reference: first.reference, surface: "app", expected_intent: "step_up",
      )
    end
  end

  test "verified Email is configured and unavailable Passkey or TOTP history requires recovery rather than bootstrap" do
    %i(verified_email revoked_passkey inactive_totp revoked_totp).each do |state|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      case state
      when :verified_email
        actor.client_emails.create!(
          address: "#{SecureRandom.hex(8)}@example.com",
          user_email_status_id: ClientEmailStatus::VERIFIED,
        )
      when :revoked_passkey
        actor.client_passkeys.create!(
          webauthn_id: SecureRandom.uuid, public_key: "public",
          status_id: ClientPasskeyStatus::REVOKED,
        )
      when :inactive_totp, :revoked_totp
        actor.client_totp_credentials.create!(
          private_key: ROTP::Base32.random_base32,
          user_totp_credential_status_id: (state == :inactive_totp) ?
            ClientTotpCredentialStatus::INACTIVE : ClientTotpCredentialStatus::REVOKED,
        )
      end
      token = ClientToken.create!(user: actor)
      requirement = StepUpRequirement.new(
        step_up_required: false, scope: "settings_birthdate", purpose: "bootstrap",
        audience: "step_up:app", allowed_methods: %i(passkey totp),
        session_binding: token.public_id, token_binding: token.public_id, require_session_binding: true,
      )

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
          )
        end
      end
      assert_nil token.reload.last_step_up_at
    end
  end

  test "bootstrap refuses assurance claims and methods outside the registration matrix" do
    [
      { required_aal: :aal1 }, { phishing_resistant_required: true }, { step_up_required: true },
      { allowed_methods: [:email_otp] }, { allowed_methods: %i(passkey email_otp) },
    ].each do |attributes|
      actor = Client.create!(status_id: ClientStatus::ACTIVE)
      token = ClientToken.create!(user: actor)
      requirement = StepUpRequirement.new(
        **{
          step_up_required: false,
          scope: "settings_birthdate",
          purpose: "bootstrap",
          audience: "step_up:app",
          allowed_methods: %i(passkey totp),
          session_binding: token.public_id,
          token_binding: token.public_id,
          require_session_binding: true,
        }.merge(attributes),
      )

      assert_no_difference("ClientStepUpCeremonyTransaction.count") do
        assert_raises(BaseAuthAdmissionCoordinator::Denied) do
          BaseStepUpAdmissionIssuer.call!(
            actor: actor, token: token, requirement: requirement, return_to: "/identity/birthdate",
          )
        end
      end
    end
  end
end
