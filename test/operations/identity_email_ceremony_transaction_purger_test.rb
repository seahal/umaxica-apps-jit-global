# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityEmailCeremonyTransactionPurgerTest < ActiveSupport::TestCase
  test "deletes purgeable email ceremony transactions across surfaces and leaves fresh rows" do
    now = Time.utc(2026, 8, 10, 12, 0, 0)
    retention = EmailCeremonyTransactionable::RETENTION_PERIOD

    stale_app = create_email_tx!(ClientEmailCeremonyTransaction, expires_at: now - retention - 1.hour)
    fresh_app = create_email_tx!(ClientEmailCeremonyTransaction, expires_at: now + 1.hour)
    stale_org = create_email_tx!(OperatorEmailCeremonyTransaction, expires_at: now - retention - 3.hours)

    result = IdentityEmailCeremonyTransactionPurger.new(now: now, retention_period: retention, batch_size: 1).call

    assert_equal({ app: 1, org: 1 }, result)
    assert_nil ClientEmailCeremonyTransaction.find_by(id: stale_app.id)
    assert_nil OperatorEmailCeremonyTransaction.find_by(id: stale_org.id)
    assert ClientEmailCeremonyTransaction.exists?(fresh_app.id)
  end

  test "returns zero counts when nothing is purgeable" do
    now = Time.utc(2026, 8, 10, 12, 0, 0)
    create_email_tx!(ClientEmailCeremonyTransaction, expires_at: now + 1.day)

    result = IdentityEmailCeremonyTransactionPurger.new(now: now, retention_period: 30.days).call

    assert_equal({ app: 0, org: 0 }, result)
  end

  private

  def create_email_tx!(model, expires_at:)
    model.create_transaction!(
      actor_ref: "actor-#{SecureRandom.hex(4)}",
      session_ref: "session-#{SecureRandom.hex(4)}",
      operation: "registration",
      expires_at: expires_at,
    )
  end
end
