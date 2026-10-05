# frozen_string_literal: true

require "test_helper"

# The transition contract of a step-up transaction: which states are open, which are terminal, and
# which writes each purpose and method permits.
class StepUpCeremonyTransactionTransitionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
    test "#{model.name} verification moves a pending step-up to verified and records its evidence" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )
      verified_at = model.database_now

      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: verified_at, verified_credential_ref: "credential",
      )

      transaction.reload

      assert_equal "verified", transaction.status
      assert_equal "passkey", transaction.method
      assert_equal "aal1", transaction.aal
      assert transaction.phishing_resistant
      assert_equal "credential", transaction.verified_credential_ref
      assert_predicate transaction.result_jti, :present?
      assert_nil transaction.consumed_at
      assert_nil transaction.canceled_at
    end

    test "#{model.name} verification is refused once the transaction is already verified" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: model.database_now, verified_credential_ref: "credential",
      )
      result_jti = transaction.reload.result_jti

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          transaction.record_verification!(
            method: "passkey", aal: "aal1", phishing_resistant: true,
            verified_at: model.database_now, verified_credential_ref: "other-credential",
          )
        end

      assert_equal "transaction_unavailable", error.code
      assert_equal "verified", transaction.reload.status
      assert_equal result_jti, transaction.result_jti
      assert_equal "credential", transaction.verified_credential_ref
    end

    test "#{model.name} verification is refused after the expiry instant has passed" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
        now: model.database_now - 16.minutes,
      )

      # The decision clock is the database's, so only "clearly past" is reachable here; the exact
      # instant is pinned through the caller-supplied clock of unavailable_refusal_code.
      # Refusing an expired transaction is a logical decision: the stored status stays pending.
      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          transaction.record_verification!(
            method: "passkey", aal: "aal1", phishing_resistant: true,
            verified_at: transaction.created_at, verified_credential_ref: "credential",
          )
        end

      assert_equal "transaction_expired", error.code
      assert_equal "pending", transaction.reload.status
    end

    test "#{model.name} registration evidence moves a pending bootstrap to verified without assurance" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "bootstrap",
      )

      transaction.record_registration_verification!(method: "passkey", verified_at: model.database_now)

      transaction.reload

      assert_equal "verified", transaction.status
      assert_equal "none", transaction.aal
      assert_not transaction.phishing_resistant
      assert_nil transaction.verified_credential_ref
      assert_nil transaction.consumed_at
    end

    test "#{model.name} registration evidence is refused for a step-up transaction" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )

      assert_raises(IdentityStepUpCeremonyContract::Error) do
        transaction.record_registration_verification!(method: "passkey", verified_at: model.database_now)
      end
      assert_equal "pending", transaction.reload.status
    end

    test "#{model.name} cancellation closes a pending transaction and stamps canceled_at" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )
      now = model.database_now

      transaction.commit_cancellation!(now: now)

      assert_equal "canceled", transaction.reload.status
      assert_equal now, transaction.canceled_at
    end

    test "#{model.name} cancellation closes a verified transaction" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )
      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: model.database_now, verified_credential_ref: "credential",
      )

      transaction.commit_cancellation!(now: model.database_now)

      assert_equal "canceled", transaction.reload.status
    end

    test "#{model.name} cancellation repeated on a canceled transaction converges on the first result" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )
      first = model.database_now
      transaction.commit_cancellation!(now: first)

      transaction.commit_cancellation!(now: first + 1.minute)

      assert_equal "canceled", transaction.reload.status
      assert_equal first, transaction.canceled_at
    end

    # Every terminal state refuses every other terminal state and a return to an open state.
    {
      "consumed" => "transaction_already_completed",
      "canceled" => "transaction_canceled",
      "expired" => "transaction_expired",
      "revoked" => "transaction_revoked",
    }.each do |terminal, code|
      test "#{model.name} in #{terminal} refuses every transition to another state with #{code}" do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
          required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
        )
        now = model.database_now
        transaction.record_verification!(
          method: "passkey", aal: "aal1", phishing_resistant: true, verified_at: now,
          verified_credential_ref: "credential",
        )
        case terminal
        when "consumed" then transaction.commit_consumption!(now: now)
        when "canceled" then transaction.commit_cancellation!(now: now)
        when "expired" then transaction.commit_expiry!
        when "revoked" then transaction.commit_revocation!(now: now)
        end
        snapshot = transaction.reload.attributes

        attempts = {
          "canceled" => -> { transaction.commit_cancellation!(now: now + 1.second) },
          "consumed" => -> { transaction.commit_consumption!(now: now + 1.second) },
          "expired" => -> { transaction.commit_expiry! },
          "revoked" => -> { transaction.commit_revocation!(now: now + 1.second) },
          "verified" => lambda {
            transaction.record_verification!(
              method: "passkey", aal: "aal1", phishing_resistant: true, verified_at: now,
              verified_credential_ref: "credential",
            )
          },
        }
        attempts.except((terminal == "canceled") ? "canceled" : nil).each do |target, attempt|
          next if target == terminal && terminal == "canceled"

          error = assert_raises(IdentityStepUpCeremonyContract::Error, "#{terminal} -> #{target}", &attempt)

          assert_equal code, error.code, "#{terminal} -> #{target}"
          assert_equal snapshot, transaction.reload.attributes, "#{terminal} -> #{target}"
        end
      end
    end

    test "#{model.name} expiry and revocation close an open transaction" do
      %w(pending verified).each do |open_state|
        expired = model.create_transaction!(
          actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
          required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
        )
        revoked = model.create_transaction!(
          actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
          required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
        )
        now = model.database_now
        if open_state == "verified"
          [expired, revoked].each do |transaction|
            transaction.record_verification!(
              method: "passkey", aal: "aal1", phishing_resistant: true, verified_at: now,
              verified_credential_ref: "credential",
            )
          end
        end

        expired.commit_expiry!
        revoked.commit_revocation!(now: now)

        assert_equal "expired", expired.reload.status, open_state
        assert_equal "revoked", revoked.reload.status, open_state
        assert_equal now, revoked.revoked_at, open_state
      end
    end

    test "#{model.name} consumption requires verified evidence for a step-up" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )
      now = model.database_now

      error = assert_raises(IdentityStepUpCeremonyContract::Error) { transaction.commit_consumption!(now: now) }

      assert_equal "transaction_unavailable", error.code
      assert_equal "pending", transaction.reload.status
      assert_nil transaction.consumed_at

      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true, verified_at: now,
        verified_credential_ref: "credential",
      )
      transaction.commit_consumption!(now: now)

      assert_equal "consumed", transaction.reload.status
      assert_equal now, transaction.consumed_at
    end

    test "#{model.name} email bootstrap is consumed directly from pending without assurance" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_email",
        required_aal: "none", allowed_methods: ["email_otp"], purpose: "bootstrap",
      )
      now = model.database_now

      transaction.commit_registration_consumption!(now: now, method: "email_otp", registered_credential_ref: "email")

      transaction.reload

      assert_equal "consumed", transaction.status
      assert_equal "email_otp", transaction.method
      assert_equal "none", transaction.aal
      assert_not transaction.phishing_resistant
      assert_equal now, transaction.consumed_at
      assert_equal "email", transaction.verified_credential_ref
    end

    %w(passkey totp).each do |method|
      test "#{model.name} #{method} bootstrap cannot be consumed before its registration evidence" do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "session", required_scope: "settings_email",
          required_aal: "none", allowed_methods: %w(passkey totp), purpose: "bootstrap",
        )

        error =
          assert_raises(IdentityStepUpCeremonyContract::Error) do
            transaction.commit_registration_consumption!(
              now: model.database_now, method: method, registered_credential_ref: "credential",
            )
          end

        assert_equal "transaction_unavailable", error.code
        assert_equal "pending", transaction.reload.status
      end
    end

    test "#{model.name} a pending step-up cannot use the email bootstrap shortcut" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_email",
        required_aal: "none", allowed_methods: ["email_otp"], purpose: "step_up",
      )

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          transaction.commit_registration_consumption!(
            now: model.database_now, method: "email_otp", registered_credential_ref: "email",
          )
        end

      assert_equal "transaction_unavailable", error.code
      assert_equal "pending", transaction.reload.status
    end

    test "#{model.name} result delivery is prepared only for a verified transaction and counts generations" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )

      error =
        assert_raises(IdentityStepUpCeremonyContract::Error) do
          transaction.prepare_result_delivery!(result_digest: "a" * 64, ttl: 60.seconds)
        end

      assert_equal "transaction_unavailable", error.code
      assert_equal 0, transaction.reload.result_generation

      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true,
        verified_at: model.database_now, verified_credential_ref: "credential",
      )
      _, first_generation = transaction.prepare_result_delivery!(result_digest: "a" * 64, ttl: 60.seconds)
      _, second_generation = transaction.prepare_result_delivery!(result_digest: "b" * 64, ttl: 60.seconds)

      assert_equal [1, 2], [first_generation, second_generation]
      assert_equal "verified", transaction.reload.status
      assert_equal "b" * 64, transaction.result_digest
    end
  end
end
