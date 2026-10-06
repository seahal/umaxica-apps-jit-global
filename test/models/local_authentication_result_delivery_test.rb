# frozen_string_literal: true

require "test_helper"

class LocalAuthenticationResultDeliveryTest < ActiveSupport::TestCase
  test "only primary and MFA pending flows can record local authentication evidence on each surface" do
    [
      [ClientSignInFlow, Client.create!(id: 9_117_000_000_000)],
      [VisitorSignInFlow, Visitor.create!(id: 9_117_000_000_000)],
      [OperatorSignInFlow, Operator.create!(id: 9_117_000_000_000)],
    ].each do |model, actor|
      model::STATES.each do |state_name, state_id|
        flow = model.create!(
          principal_id: actor.id, state_id: state_id,
          nonce_digest: model.digest_nonce(SecureRandom.urlsafe_base64(32)),
          completed_at: (state_name == "COMPLETED") ? Time.current : nil,
        )
        if %w(PRIMARY_PENDING MFA_PENDING).include?(state_name)
          flow.record_local_authentication_evidence!(method: "passkey")

          assert_equal "passkey", flow.reload.authentication_method
          assert_not_nil flow.authentication_event_at
        else
          assert_raises(AuthCeremonySession::InvalidTransition, "#{model} #{state_name}") do
            flow.record_local_authentication_evidence!(method: "passkey")
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
      flow.record_local_authentication_evidence!(method: "passkey")
    end
    flow.update!(principal: clients(:one))
    flow.record_local_authentication_evidence!(method: "passkey")
    verified_at = flow.reload.authentication_event_at
    assert_raises(AuthCeremonySession::InvalidTransition) do
      flow.record_local_authentication_evidence!(method: "email")
    end
    assert_equal "passkey", flow.reload.authentication_method
    assert_equal verified_at, flow.authentication_event_at
  end

  test "a new result generation invalidates the old digest without refreshing authentication" do
    flow = ClientSignInFlow.create!(
      state_id: ClientSignInFlow.state_id_for("PRIMARY_PENDING"),
      principal: clients(:one), nonce_digest: ClientSignInFlow.digest_nonce("base-browser-nonce"),
    )
    flow.record_local_authentication_evidence!(method: "passkey")
    flow.advance_sign_in_to_guardrail!
    flow.advance_sign_in_to_checkpoint!
    flow.advance_sign_in_to_selector!
    flow.advance_sign_in_to_session_issuance!
    authenticated_at = flow.reload.authentication_event_at

    flow.prepare_local_result_delivery!(digest: "a" * 64, ttl: 60.seconds)

    assert flow.local_result_delivery_matches?(digest: "a" * 64, generation: 1)
    flow.prepare_local_result_delivery!(digest: "b" * 64, ttl: 60.seconds)

    assert_not flow.local_result_delivery_matches?(digest: "a" * 64, generation: 1)
    assert flow.local_result_delivery_matches?(digest: "b" * 64, generation: 2)
    assert_equal authenticated_at, flow.reload.authentication_event_at
    assert_equal 2, flow.result_generation
  end

  test "result validity rejects exactly at expiry and one microsecond after it" do
    now = Time.utc(2026, 10, 3, 12)
    flow = ClientSignInFlow.create!(
      state_id: ClientSignInFlow.state_id_for("PRIMARY_PENDING"),
      principal: clients(:one), nonce_digest: ClientSignInFlow.digest_nonce("base-browser-nonce"),
      issued_at: now, expires_at: now + 15.minutes,
      authentication_method: "passkey", authentication_event_at: now,
      result_digest: "a" * 64, result_generation: 1, result_expires_at: now + 60.seconds,
    )

    [-1, 0, 1].each do |microseconds|
      assert_equal microseconds < 0,
                   flow.local_result_delivery_matches?(
                     digest: "a" * 64, generation: 1, now: now + 60.seconds + Rational(microseconds, 1_000_000),
                   )
    end
  end

  test "Emergency authentication evidence preserves its context and rejects unknown contexts" do
    flow = OperatorSignInFlow.create!(
      state_id: OperatorSignInFlow.state_id_for("PRIMARY_PENDING"),
      principal: operators(:one), nonce_digest: OperatorSignInFlow.digest_nonce("base-browser-nonce"),
    )
    [nil, "", "unknown", "normal\0", 0].each do |context|
      assert_raises(AuthCeremonySession::InvalidTransition) do
        flow.record_local_authentication_evidence!(method: "passkey", authentication_context: context)
      end
      assert_nil flow.reload.authentication_event_at
    end
    flow.record_local_authentication_evidence!(method: "passkey", authentication_context: "emergency")

    assert_equal "emergency", flow.reload.authentication_context
  end
end
