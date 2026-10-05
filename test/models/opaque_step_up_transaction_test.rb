# frozen_string_literal: true

require "test_helper"

class OpaqueStepUpTransactionTest < ActiveSupport::TestCase
  # Each test creates its authoritative transaction through the public model API.
  self.fixture_table_names = []

  [ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
    %w(bootstrap credential_registration).each do |purpose|
      test "#{model.name} #{purpose} evidence cannot become ordinary step-up evidence" do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
          required_aal: "none", allowed_methods: ["passkey"], purpose: purpose,
        )
        # Synthetic evidence exercises the purpose boundary, not WebAuthn cryptography.
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          transaction.record_verification!(
            method: "passkey", aal: "aal1", phishing_resistant: true,
            verified_at: model.database_now, verified_credential_ref: "existing-credential",
          )
        end
        assert_equal "pending", transaction.reload.status
        transaction.record_registration_verification!(method: "passkey", verified_at: model.database_now)

        assert_equal "none", transaction.aal
        assert_not transaction.phishing_resistant
        assert_nil transaction.verified_credential_ref
        [
          { purpose: "step_up" }, { verified_credential_ref: "existing-credential" }, { aal: "aal1" },
          { phishing_resistant: true }, { required_aal: "aal1" }, { phishing_resistant_required: true },
        ].each do |attributes|
          # Bypass model validations through the public ORM API to prove the writer DB constraint.
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) { transaction.update_columns(attributes) }
          end
          assert_equal purpose, transaction.reload.purpose
          assert_equal "none", transaction.aal
          assert_nil transaction.verified_credential_ref
        end
      end
    end
  end

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
