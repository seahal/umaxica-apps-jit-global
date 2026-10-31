# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityTelephoneCeremonyTransactionPurgerTest < ActiveSupport::TestCase
  test "deletes purgeable telephone ceremony transactions across surfaces" do
    now = Time.utc(2026, 8, 10, 12, 0, 0)
    retention = TelephoneCeremonyTransactionable::RETENTION_PERIOD

    stale_app = create_tel_tx!(ClientTelephoneCeremonyTransaction, expires_at: now - retention - 1.hour)
    fresh_app = create_tel_tx!(ClientTelephoneCeremonyTransaction, expires_at: now + 1.hour)
    stale_org = create_tel_tx!(OperatorTelephoneCeremonyTransaction, expires_at: now - retention - 3.hours)

    result = IdentityTelephoneCeremonyTransactionPurger.new(now: now, retention_period: retention, batch_size: 1).call

    assert_equal({ app: 1, org: 1 }, result)
    assert_nil ClientTelephoneCeremonyTransaction.find_by(id: stale_app.id)
    assert_nil OperatorTelephoneCeremonyTransaction.find_by(id: stale_org.id)
    assert ClientTelephoneCeremonyTransaction.exists?(fresh_app.id)
  end

  private

  def create_tel_tx!(model, expires_at:)
    model.create_transaction!(
      actor_ref: "actor-#{SecureRandom.hex(4)}",
      session_ref: "session-#{SecureRandom.hex(4)}",
      operation: "registration",
      expires_at: expires_at,
    )
  end
end
