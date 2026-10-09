# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# Challenge references and raw secrets must not appear in failed assertion output.
class StepUpSessionRevocationTest < ActiveSupport::TestCase
  %i(app com org).each do |surface|
    %i(pending consumed).each do |challenge_state|
      %i(early before_discard at_discard after_discard).each do |boundary_case|
        test "#{surface} root revocation retains #{challenge_state} challenge facts #{boundary_case}" do
          actor, token, transaction_model, session_model, token_key, rp_id =
            case surface
            when :app
              owner = Client.create!(status_id: ClientStatus::ACTIVE)
              [owner, ClientToken.create!(user: owner, discard_at: 1.day.from_now),
               ClientStepUpCeremonyTransaction, ClientStepUpSession, :user_token,
               ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),]
            when :com
              owner = Visitor.create!(status_id: VisitorStatus::ACTIVE)
              [owner, VisitorToken.create!(visitor: owner, discard_at: 1.day.from_now),
               VisitorStepUpCeremonyTransaction, VisitorStepUpSession, :visitor_token,
               ENV.fetch("PUBLIC_AUTH_CORPORATE_URL"),]
            when :org
              owner = Operator.create!
              [owner, OperatorToken.create!(staff: owner, discard_at: 1.day.from_now),
               OperatorStepUpCeremonyTransaction, OperatorStepUpSession, :staff_token,
               ENV.fetch("PUBLIC_AUTH_STAFF_URL"),]
            end
          token.rotate_refresh_token!
          transaction = transaction_model.create_transaction!(
            actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_passkey",
            allowed_methods: ["passkey"], return_to: "/identity/passkeys",
          )
          record = session_model.create!(
            token_key => token, :scope => transaction.required_scope, :return_to => transaction.return_to,
            :status => "PENDING", :discard_at => transaction.expires_at,
            :step_up_ceremony_transaction_ref => transaction.transaction_id,
          )
          origin = "https://#{rp_id}"
          challenge = SecureRandom.urlsafe_base64(32)
          reference = record.issue_bound_passkey_challenge!(transaction:, challenge:, rp_id:, origin:)
          if challenge_state == :consumed
            consumed = record.consume_bound_passkey_challenge!(transaction:, reference:, rp_id:, origin:)

            assert_withheld("Public consumption must return the original bound challenge") { consumed == challenge }
          end
          original = record.reload.attributes
          original_deadline = record.discard_at
          original_consumed_at = record.passkey_challenge_consumed_at
          decision_time =
            case boundary_case
            when :early then session_model.database_now
            # PostgreSQL timestamptz(6) supplies both nearest representable discard boundary neighbors.
            when :before_discard then original_deadline - Rational(1, 1_000_000)
            when :at_discard then original_deadline
            when :after_discard then original_deadline + Rational(1, 1_000_000)
            end
          session_model.stub(:database_now, decision_time) do
            # A distinct Root decision proves the Session writer owns its own consumption clock.
            token.revoke!(now: decision_time + 1.second)
          end

          assert_predicate token.reload, :revoked?
          record.reload

          assert_nil record.passkey_challenge
          assert_equal original_consumed_at || decision_time, record.passkey_challenge_consumed_at
          assert_equal [original_deadline, decision_time].min, record.discard_at
          assert_withheld(
            "Root revocation must retain status, reference, RP, origin, original deadline and all other facts",
          ) {
            original.except(
              "discard_at", "passkey_challenge", "passkey_challenge_consumed_at", "updated_at",
            ) ==
              record.attributes.except("discard_at", "passkey_challenge", "passkey_challenge_consumed_at", "updated_at")
          }
          assert_not record.accessible?(decision_time)
          assert_equal "revoked", transaction.reload.status
          retained = record.attributes.except("updated_at")

          session_model.stub(:database_now, decision_time + 1.second) do
            assert_same record, record.revoke_authority!
          end

          assert_withheld(
            "Repeated authority revocation must never extend discard or replace the original challenge burn",
          ) {
            retained == record.reload.attributes.except("updated_at")
          }
          assert_raises(StepUpSessionConsumable::ChallengeError) do
            record.consume_bound_passkey_challenge!(transaction:, reference:, rp_id:, origin:)
          end

          assert_withheld("A revoked challenge must remain unavailable without replacing binding evidence") {
            retained == record.reload.attributes.except("updated_at")
          }
        end
      end
    end
  end
end
