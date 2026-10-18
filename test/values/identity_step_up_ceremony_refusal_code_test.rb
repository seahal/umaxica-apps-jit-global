# frozen_string_literal: true

require "test_helper"

class IdentityStepUpCeremonyRefusalCodeTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [IdentityStepUpCeremonyContract::Error, BaseAuthAdmissionCoordinator::Denied].each do |error_class|
    test "#{error_class.name} raised with only a message carries the unclassified code" do
      error = assert_raises(error_class) { raise error_class, "refused" }

      assert_equal "unclassified", error.code
      assert_equal "refused", error.message
    end

    test "#{error_class.name} carries a code from the refusal taxonomy" do
      error = error_class.new("refused", code: "transaction_conflict")

      assert_equal "transaction_conflict", error.code
    end

    # Sentinels: missing, empty, a Symbol spelling of a valid code, and an unknown word.
    [nil, "", :transaction_conflict, "not_a_code"].each do |code|
      test "#{error_class.name} rejects the code #{code.inspect} instead of logging it" do
        assert_raises(ArgumentError) { error_class.new("refused", code: code) }
      end
    end
  end

  [ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
    {
      "consumed" => "transaction_already_completed",
      "canceled" => "transaction_canceled",
      "revoked" => "transaction_revoked",
      "expired" => "transaction_expired",
    }.each do |status, code|
      test "#{model.name} in #{status} reports #{code}" do
        transaction = model.create_transaction!(
          actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
          required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
        )
        # The stored status is the input under test; the transitions that reach it are covered elsewhere.
        transaction.update_columns(
          status: status, revoked_at: ((status == "revoked") ? transaction.created_at : nil),
          consumed_at: ((status == "consumed") ? transaction.created_at : nil),
        )

        assert_equal code, transaction.unavailable_refusal_code(
          expected_purposes: ["step_up"], now: transaction.created_at,
        )
      end
    end

    test "#{model.name} pending reports expiry only from its expiry instant onward" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )
      boundary = transaction.expires_at

      # Boundary: one microsecond below, at, and one microsecond above expires_at.
      assert_equal "transaction_unavailable", transaction.unavailable_refusal_code(
        expected_purposes: ["step_up"], now: boundary - 0.000001,
      )
      assert_equal "transaction_expired", transaction.unavailable_refusal_code(
        expected_purposes: ["step_up"], now: boundary,
      )
      assert_equal "transaction_expired", transaction.unavailable_refusal_code(
        expected_purposes: ["step_up"], now: boundary + 0.000001,
      )
    end

    test "#{model.name} reports a malformed request when the purpose is not the expected one" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "bootstrap",
      )

      assert_equal "malformed_request", transaction.unavailable_refusal_code(
        expected_purposes: %w(step_up reauthentication), now: transaction.created_at,
      )
    end
  end
end
