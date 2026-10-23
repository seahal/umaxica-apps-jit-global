# frozen_string_literal: true

require "test_helper"

class StepUpNullableEvidenceContractTest < ActiveSupport::TestCase
  TRANSACTIONS = [
    ClientStepUpCeremonyTransaction, VisitorStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction,
  ].freeze

  TRANSACTIONS.each do |model|
    test "#{model.name} retains absent user verification until actual evidence is recorded" do
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )

      assert_equal "pending", transaction.reload.status
      assert_nil transaction.user_verified

      transaction.record_verification!(
        method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: true,
        verified_at: model.database_now, verified_credential_ref: "credential",
      )

      assert_equal "verified", transaction.reload.status
      assert transaction.user_verified
    end
  end

  %i(app com org).each do |surface|
    test "#{surface} token authority revocation clears boolean evidence to nil without revoking root token" do
      token =
        case surface
        when :app
          actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
          ClientToken.create!(authentication_epoch: 0, user: actor, discard_at: 1.day.from_now)
        when :com
          actor = Visitor.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: VisitorStatus::ACTIVE)
          VisitorToken.create!(authentication_epoch: 0, visitor: actor, discard_at: 1.day.from_now)
        when :org
          actor = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
          OperatorToken.create!(authentication_epoch: 0, staff: actor, discard_at: 1.day.from_now)
        end
      token.update!(last_step_up_user_verified: true, last_step_up_full_reauthentication: false)
      original_status = token.attributes.slice(
        "user_token_status_id", "visitor_token_status_id",
        "staff_token_status_id",
      )
      original_deadline = token.reload.discard_at

      token.revoke_step_up_authority!

      assert_nil token.reload.last_step_up_user_verified
      assert_nil token.last_step_up_full_reauthentication
      assert_equal original_status,
                   token.attributes.slice("user_token_status_id", "visitor_token_status_id", "staff_token_status_id")
      assert_equal original_deadline, token.discard_at
      assert_predicate token, :persisted?
    end
  end
end
