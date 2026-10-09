# frozen_string_literal: true

require "test_helper"

# Synthetic recorded evidence isolates result application from WebAuthn verification. The
# admission, opaque result, current requirement and finalization are all real production APIs.
class BaseStepUpResultBindingNegativesTest < ActiveSupport::TestCase
  %w(app com org).each do |surface|
    {
      actor_ref: "another-actor",
      session_binding: "another-session",
      token_binding: "another-token",
      scope: "settings_email",
      audience: "another-operation-audience",
      resource_ref: "another-resource",
      tenant_ref: "another-tenant",
      purpose: "credential_change",
      allowed_methods: [:totp],
    }.each do |field, replacement|
      test "#{surface} issued result cannot satisfy a current requirement with foreign #{field}" do
        actor, token, credential =
          case surface
          when "app"
            actor = Client.create!(id: SecureRandom.random_number(1 << 60), status_id: ClientStatus::ACTIVE)
            [actor, ClientToken.create!(user: actor),
             actor.client_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public"),]
          when "com"
            actor = Visitor.create!(id: SecureRandom.random_number(1 << 60), status_id: VisitorStatus::ACTIVE)
            [actor, VisitorToken.create!(visitor: actor),
             actor.visitor_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public"),]
          when "org"
            actor = Operator.create!(id: SecureRandom.random_number(1 << 60))
            [actor, OperatorToken.create!(staff: actor),
             actor.operator_passkeys.create!(webauthn_id: SecureRandom.uuid, public_key: "public"),]
          end
        requirement = StepUpRequirement.new(
          scope: "settings_passkey", purpose: "step_up", step_up_required: true, allowed_methods: [:passkey],
          phishing_resistant_required: false, user_verification_required: false, full_reauthentication_required: false,
          audience: "step_up:#{surface}", session_binding: token.public_id, token_binding: token.public_id,
          require_session_binding: true, ttl: 15.minutes, actor_ref: actor.public_id,
          resource_ref: "original-resource", tenant_ref: "original-tenant",
        )
        admission = BaseStepUpAdmissionIssuer.call!(
          actor:, token:, requirement:, return_to: "/identity/passkeys",
          base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: token,
        )
        transaction = admission.transaction
        binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface:, reference: admission.reference)
        ceremony_model = binding.class.auth_admission_session_class
        attached, sid = ceremony_model.issue!
        binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
        binding.confirm_base!(base_token: token, browser_digest: binding.base_browser_digest)
        BaseAuthAdmissionCoordinator.consume_entry_reference!(
          reference: admission.reference, surface:, expected_intent: "step_up", binding:, raw_auth_sid: sid,
        )
        ceremony, = ceremony_model.rotate_and_admit!(
          admission_purpose: "step_up_handoff", previous_raw_sid: sid,
          step_up_ceremony_transaction_ref: transaction.transaction_id,
        )
        binding.redeem!(auth_session: attached, admitted_auth_session: ceremony)
        credential_ref = (surface == "org") ? credential.external_id : credential.public_id
        transaction.record_verification!(
          method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
          verified_at: transaction.class.database_now, verified_credential_ref: credential_ref,
        )
        result = BaseAuthAdmissionCoordinator.issue_result!(transaction:, ceremony_session_ref: ceremony.id.to_s)
        before = transaction.reload.attributes
        token_before = token.reload.attributes
        ceremony_before = ceremony.reload.attributes
        changed = StepUpRequirement.new(
          step_up_required: true,
          phishing_resistant_required: false,
          user_verification_required: false,
          full_reauthentication_required: false,
          **requirement.to_h.merge(field => replacement),
        )

        assert_raises(IdentityStepUpCeremonyContract::Error) do
          IdentityStepUpCeremonyFreshnessCommitter.call!(
            actor:, token:, transaction:, requirement: changed, result_reference: result.reference,
          )
        end

        assert_equal before, transaction.reload.attributes
        assert_equal token_before, token.reload.attributes
        assert_equal ceremony_before, ceremony.reload.attributes
        assert_nil token.last_step_up_at
        # Refusal leaves the original authorized result usable, not consumed or rebound.
        IdentityStepUpCeremonyFreshnessCommitter.call!(
          actor:, token:, transaction:, requirement:, result_reference: result.reference,
        )

        assert_equal "consumed", transaction.reload.status
        assert_equal transaction.verified_at, token.reload.last_step_up_at
        assert_predicate ceremony.reload, :completed?
      end
    end
  end
end
