# frozen_string_literal: true

require "test_helper"

class StepUpPasskeyChallengeTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses

  test "challenge expiry rejects at and after the deadline and accepts one microsecond before" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at,
    )
    reference = record.issue_bound_passkey_challenge!(
      transaction: transaction, challenge: "public", rp_id: "app.example", origin: "https://app.example",
    )

    [nil, "", 0, "\0", "another-reference"].each do |invalid_reference|
      assert_raises(StepUpSessionConsumable::ChallengeError) do
        record.consume_bound_passkey_challenge!(
          transaction: transaction, reference: invalid_reference, rp_id: "app.example", origin: "https://app.example",
        )
      end
    end
    assert_nil record.reload.passkey_challenge_consumed_at

    [-1, 0, 1].each do |offset|
      record.update!(passkey_challenge_consumed_at: nil)
      # Substitute only the writer clock so PostgreSQL's microsecond boundary can be reached exactly.
      ClientStepUpCeremonyTransaction.stub(
        :database_now, record.passkey_challenge_expires_at + Rational(offset, 1_000_000),
      ) do
        if offset.negative?
          assert_equal "public", record.consume_bound_passkey_challenge!(
            transaction: transaction, reference: reference, rp_id: "app.example", origin: "https://app.example",
          )
        else
          assert_raises(StepUpSessionConsumable::ChallengeError) do
            record.consume_bound_passkey_challenge!(
              transaction: transaction, reference: reference, rp_id: "app.example", origin: "https://app.example",
            )
          end
        end
      end

      assert_not_nil record.reload.passkey_challenge_consumed_at
    end
  end

  test "a challenge is bound to the concrete transaction and consumed once" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    issuance = issue_base_step_up_admission!(
      actor: actor, token: token,
      requirement: StepUpRequirement.new(
        scope: "settings_birthdate", allowed_methods: [:passkey], purpose: "step_up",
        audience: "step_up:app", session_binding: token.public_id, token_binding: token.public_id,
        require_session_binding: true,
      ),
      return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.find_by!(step_up_ceremony_transaction_ref: issuance.transaction.transaction_id)
    reference = record.issue_bound_passkey_challenge!(
      transaction: issuance.transaction, challenge: "public-challenge", rp_id: "app.example",
      origin: "https://app.example",
    )

    assert_equal "public-challenge", record.consume_bound_passkey_challenge!(
      transaction: issuance.transaction, reference: reference, rp_id: "app.example", origin: "https://app.example",
    )
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      record.consume_bound_passkey_challenge!(
        transaction: issuance.transaction, reference: reference, rp_id: "app.example", origin: "https://app.example",
      )
    end
    assert_not_nil record.reload.passkey_challenge_consumed_at
    assert_equal 0, record.attempt_count
  end

  test "a matching challenge reference is burned on origin mismatch and its deadline is not extended" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, required_scope: "settings_birthdate",
      required_aal: "none", allowed_methods: ["passkey"], return_to: "/identity/birthdate",
    )
    record = ClientStepUpSession.create!(
      user_token: token, step_up_ceremony_transaction_ref: transaction.transaction_id,
      scope: transaction.required_scope, return_to: transaction.return_to,
      status: "PENDING", discard_at: transaction.expires_at, attempt_count: 3,
    )
    first = record.issue_bound_passkey_challenge!(
      transaction: transaction, challenge: "first", rp_id: "app.example", origin: "https://app.example",
    )
    deadline = record.passkey_challenge_expires_at
    second = record.issue_bound_passkey_challenge!(
      transaction: transaction, challenge: "second", rp_id: "app.example", origin: "https://app.example",
    )

    assert_not_equal first, second
    assert_equal deadline, record.reload.passkey_challenge_expires_at
    assert_equal 3, record.attempt_count
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      record.consume_bound_passkey_challenge!(
        transaction: transaction, reference: second, rp_id: "app.example", origin: "https://other.example",
      )
    end
    assert_not_nil record.reload.passkey_challenge_consumed_at
    assert_raises(StepUpSessionConsumable::ChallengeError) do
      record.consume_bound_passkey_challenge!(
        transaction: transaction, reference: second, rp_id: "app.example", origin: "https://app.example",
      )
    end
  end
end
