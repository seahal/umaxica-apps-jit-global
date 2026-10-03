# frozen_string_literal: true

require "test_helper"

class OpaqueStepUpTransactionTest < ActiveSupport::TestCase
  test "verified evidence is immutable and replacement result generations reject the previous delivery" do
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "session", required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"],
    )
    transaction.record_verification!(
      method: "passkey", aal: "aal1", phishing_resistant: true, verified_credential_ref: "key",
      verified_at: ClientStepUpCeremonyTransaction.database_now,
    )
    verified_at = transaction.verified_at
    transaction.prepare_result_delivery!(result_digest: "a" * 64, ttl: 1.minute)

    assert transaction.result_delivery_matches?(result_digest: "a" * 64, result_generation: 1)
    assert_raises(IdentityStepUpCeremonyContract::Error) do
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true, verified_credential_ref: "key",
        verified_at: ClientStepUpCeremonyTransaction.database_now,
      )
    end
    transaction.prepare_result_delivery!(result_digest: "b" * 64, ttl: 1.minute)

    assert_not transaction.result_delivery_matches?(result_digest: "a" * 64, result_generation: 1)
    assert transaction.result_delivery_matches?(result_digest: "b" * 64, result_generation: 2)
    assert_equal verified_at, transaction.reload.verified_at
    [-1, 0, 1].each do |offset|
      assert_equal offset.negative?, transaction.result_delivery_matches?(
        result_digest: "b" * 64, result_generation: 2,
        now: transaction.result_expires_at + Rational(offset, 1_000_000),
      )
    end
  end

  test "ORG rejects methods outside Passkey even if a transaction contains a forbidden method" do
    transaction = OperatorStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: %w(passkey totp email_otp),
    )

    %w(totp email_otp).each do |method|
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        transaction.record_verification!(
          method: method, aal: (method == "totp") ? "aal1" : "none",
          phishing_resistant: false, verified_credential_ref: "key",
          verified_at: OperatorStepUpCeremonyTransaction.database_now,
        )
      end
    end
    assert_equal "pending", transaction.reload.status
  end

  test "Email OTP cannot assert phishing resistance or AAL1" do
    transaction = VisitorStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "session", required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["email_otp"],
    )

    [["none", true], ["aal1", false]].each do |aal, resistant|
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        transaction.record_verification!(
          method: "email_otp", aal: aal, phishing_resistant: resistant, verified_credential_ref: "key",
          verified_at: VisitorStepUpCeremonyTransaction.database_now,
        )
      end
    end
    transaction.record_verification!(
      method: "email_otp", aal: "none", phishing_resistant: false, verified_credential_ref: "key",
      verified_at: VisitorStepUpCeremonyTransaction.database_now,
    )

    assert_equal "none", transaction.reload.aal
  end
end
