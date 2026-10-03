# frozen_string_literal: true

require "test_helper"

class BaseStepUpAdmissionIssuerTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :visitors, :visitor_statuses

  test "a repeated Base start preserves the concrete transaction deadline and attempt count" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    requirement = StepUpRequirement.new(
      scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
      audience: "step_up:app", session_binding: token.public_id,
      token_binding: token.public_id, require_session_binding: true,
    )
    first = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
    )
    session_record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: first.transaction.transaction_id)
    session_record.update!(attempt_count: 3)
    deadline = first.transaction.expires_at
    second = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token, requirement: requirement,
      return_to: "/identity/birthdate",
    )

    assert_not_equal first.reference, second.reference
    assert_equal first.transaction.transaction_id, second.transaction.transaction_id
    assert_equal deadline, second.transaction.expires_at
    assert_equal 3, session_record.reload.attempt_count
    assert_equal "step_up", second.transaction.purpose
    payload = BaseAuthAdmissionCoordinator.consume_entry_reference!(
      reference: second.reference, surface: "app", expected_intent: "step_up",
    )

    assert_equal second.transaction.transaction_id, payload.fetch("subject_ref")
    assert_equal "step_up_handoff", payload.fetch("purpose")
  end

  test "another scope cannot rewrite a pending transaction" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    first = BaseStepUpAdmissionIssuer.call!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id,
        token_binding: token.public_id, require_session_binding: true,
      ),
      return_to: "/identity/birthdate",
    )

    assert_raises(BaseAuthAdmissionCoordinator::Denied) do
      BaseStepUpAdmissionIssuer.call!(
        actor: actor, token: token,
        requirement: StepUpRequirement.new(
          scope: "settings_telephone", allowed_methods: [:passkey], purpose: "step_up",
          audience: "step_up:app", session_binding: token.public_id,
          token_binding: token.public_id, require_session_binding: true,
        ),
        return_to: "/identity/telephones",
      )
    end
    assert_equal "settings_birthdate", first.transaction.reload.required_scope
  end

  test "COM rejects TOTP and Base actor mismatch before creating a transaction" do
    actor = Visitor.create!(status_id: VisitorStatus::ACTIVE)
    token = VisitorToken.create!(visitor: actor)

    assert_no_difference("VisitorStepUpCeremonyTransaction.count") do
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: actor, token: token,
          requirement: StepUpRequirement.new(
            scope: "settings_birthdate", allowed_methods: [:totp], purpose: "step_up",
            audience: "step_up:com", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true,
          ),
          return_to: "/identity/birthdate",
        )
      end
      assert_raises(BaseAuthAdmissionCoordinator::Denied) do
        BaseStepUpAdmissionIssuer.call!(
          actor: clients(:one), token: token,
          requirement: StepUpRequirement.new(
            scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
            audience: "step_up:app", session_binding: token.public_id,
            token_binding: token.public_id, require_session_binding: true,
          ),
          return_to: "/identity/birthdate",
        )
      end
    end
  end
end
