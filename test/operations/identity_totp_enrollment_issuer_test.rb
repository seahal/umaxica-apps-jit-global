# frozen_string_literal: true

require "test_helper"

class IdentityTotpEnrollmentIssuerTest < ActiveSupport::TestCase
  # This operation owns enrollment data; unrelated credential fixtures are outside its boundary.
  self.fixture_table_names = []
  fixtures :clients, :client_statuses

  test "pending encrypted enrollment retains its exact permission and never creates a credential" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
      required_scope: "settings_totp", required_aal: "none", allowed_methods: ["totp"],
    )
    record = ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )
    before = actor.client_totp_credentials.count
    candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    repeated = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)

    assert_equal candidate.id, repeated.id
    assert_nil candidate.last_otp_at
    assert_operator candidate.expires_at, :<=, transaction.expires_at
    assert_equal transaction.transaction_id, candidate.step_up_ceremony_transaction_ref
    assert_equal before, actor.client_totp_credentials.count
    assert_nil token.reload.last_step_up_at
    assert_equal transaction.expires_at, record.reload.discard_at
    stored = IdentityTotpCeremonyCandidate.where(id: candidate.id).select(:id, "private_key AS stored_secret").first

    assert_not_includes stored[:stored_secret], candidate.private_key
    assert_equal candidate.private_key, candidate.reload.private_key
    assert_equal 1, ClientTotpCeremonyTransaction.where(
      step_up_ceremony_transaction_ref: transaction.transaction_id,
    ).count
    transaction.update!(status: "canceled", canceled_at: ClientStepUpCeremonyTransaction.database_now)

    assert_raises(IdentityTotpCeremonyContract::Error) do
      IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
    end
  end

  test "enrollment rejects the deadline and its next microsecond but accepts the previous microsecond" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    now = ClientStepUpCeremonyTransaction.database_now + 1.second
    [-1, 0, 1].each do |microseconds|
      transaction = ClientStepUpCeremonyTransaction.create_transaction!(
        actor_ref: actor.public_id, session_ref: token.public_id, purpose: "credential_registration",
        required_scope: "settings_totp", required_aal: "none", allowed_methods: ["totp"],
        expires_at: now + Rational(microseconds, 1_000_000),
      )
      record = ClientStepUpSession.find_or_initialize_by(user_token: token)
      record.update!(
        scope: "settings_totp", return_to: "/identity", status: "PENDING",
        step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
      )
      ClientStepUpCeremonyTransaction.stub(:database_now, now) do
        if microseconds.positive?
          candidate = IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)

          assert_equal transaction.expires_at, candidate.expires_at
        else
          assert_raises(IdentityTotpCeremonyContract::Error) do
            IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
          end
        end
      end
    end
  end

  test "ordinary step-up permission and a different root session cannot start enrollment" do
    actor = clients(:one)
    token = ClientToken.create!(user: actor)
    transaction = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: actor.public_id, session_ref: token.public_id, purpose: "step_up",
      required_scope: "settings_totp", required_aal: "none", allowed_methods: ["totp"],
    )
    ClientStepUpSession.create!(
      user_token: token, scope: "settings_totp", return_to: "/identity", status: "PENDING",
      step_up_ceremony_transaction_ref: transaction.transaction_id, discard_at: transaction.expires_at,
    )

    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
      end
    end
    transaction.update!(purpose: "credential_registration", session_ref: "another-root-session")

    assert_no_difference("IdentityTotpCeremonyCandidate.count") do
      assert_raises(IdentityTotpCeremonyContract::Error) do
        IdentityTotpEnrollmentIssuer.call!(actor: actor, token: token, transaction: transaction)
      end
    end
    assert_nil token.reload.last_step_up_at
  end
end
