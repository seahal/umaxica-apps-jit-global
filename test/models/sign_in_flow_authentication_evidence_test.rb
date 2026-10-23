# frozen_string_literal: true

require "test_helper"

class SignInFlowAuthenticationEvidenceTest < ActiveSupport::TestCase
  test "only primary and MFA pending flows can record authentication evidence on each surface" do
    [
      [ClientSignInFlow, Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_117_000_000_000)],
      [VisitorSignInFlow, Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, id: 9_117_000_000_000)],
      [OperatorSignInFlow,
       Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED, id: 9_117_000_000_000),],
    ].each do |model, actor|
      model::STATES.each do |state_name, state_id|
        flow = model.create!(
          principal_id: actor.id, state_id: state_id,
          nonce_digest: model.digest_nonce(SecureRandom.urlsafe_base64(32)),
          completed_at: (state_name == "COMPLETED") ? Time.current : nil,
        )
        if %w(PRIMARY_PENDING MFA_PENDING).include?(state_name)
          flow.record_authentication_evidence!(method: "passkey")

          assert_equal "passkey", flow.reload.authentication_method
          assert_not_nil flow.authentication_event_at
        else
          assert_raises(AuthCeremonySession::InvalidTransition, "#{model} #{state_name}") do
            flow.record_authentication_evidence!(method: "passkey")
          end
          assert_nil flow.reload.authentication_event_at
          assert_nil flow.authentication_method
          assert_equal state_name, model.state_name_for(flow.state_id)
        end
      end
    end
  end

  test "authentication evidence cannot be replaced or recorded without a principal" do
    flow = ClientSignInFlow.create!(
      state_id: ClientSignInFlow.state_id_for("PRIMARY_PENDING"),
      nonce_digest: ClientSignInFlow.digest_nonce("base-browser-nonce"),
    )
    assert_raises(AuthCeremonySession::InvalidTransition) do
      flow.record_authentication_evidence!(method: "passkey")
    end
    flow.update!(principal: clients(:one))
    flow.record_authentication_evidence!(method: "passkey")
    verified_at = flow.reload.authentication_event_at
    assert_raises(AuthCeremonySession::InvalidTransition) do
      flow.record_authentication_evidence!(method: "email")
    end
    assert_equal "passkey", flow.reload.authentication_method
    assert_equal verified_at, flow.authentication_event_at
  end

  test "Emergency authentication evidence preserves its context and rejects unknown contexts" do
    flow = OperatorSignInFlow.create!(
      state_id: OperatorSignInFlow.state_id_for("PRIMARY_PENDING"),
      principal: operators(:one), nonce_digest: OperatorSignInFlow.digest_nonce("base-browser-nonce"),
    )
    [nil, "", "unknown", "normal\0", 0].each do |context|
      assert_raises(AuthCeremonySession::InvalidTransition) do
        flow.record_authentication_evidence!(method: "passkey", authentication_context: context)
      end
      assert_nil flow.reload.authentication_event_at
    end
    flow.record_authentication_evidence!(method: "passkey", authentication_context: "standby")

    assert_equal "standby", flow.reload.authentication_context
  end
end
