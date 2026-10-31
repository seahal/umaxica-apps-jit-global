# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySecretCredentialCeremonyTransactionPurgerTest < ActiveSupport::TestCase
  test "deletes purgeable secret credential ceremony transactions across surfaces" do
    now = Time.utc(2026, 8, 10, 12, 0, 0)
    retention = SecretCredentialCeremonyTransactionable::RETENTION_PERIOD

    stale_app = create_sc_tx!(ClientSecretCredentialCeremonyTransaction, expires_at: now - retention - 1.hour)
    fresh_app = create_sc_tx!(ClientSecretCredentialCeremonyTransaction, expires_at: now + 1.hour)
    stale_org = create_sc_tx!(OperatorSecretCredentialCeremonyTransaction, expires_at: now - retention - 3.hours)

    result = IdentitySecretCredentialCeremonyTransactionPurger.new(now: now, retention_period: retention).call

    assert_equal({ app: 1, org: 1 }, result)
    assert_nil ClientSecretCredentialCeremonyTransaction.find_by(id: stale_app.id)
    assert_nil OperatorSecretCredentialCeremonyTransaction.find_by(id: stale_org.id)
    assert ClientSecretCredentialCeremonyTransaction.exists?(fresh_app.id)
  end

  private

  def create_sc_tx!(model, expires_at:)
    model.create_transaction!(
      actor_ref: "actor-#{SecureRandom.hex(4)}",
      session_ref: "session-#{SecureRandom.hex(4)}",
      operation: "enrollment",
      expires_at: expires_at,
    )
  end
end
