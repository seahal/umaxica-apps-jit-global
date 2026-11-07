# frozen_string_literal: true

require "test_helper"

class IdentitySocialCeremonyTransactionPurgerBehaviorTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "purges expired and consumed social transactions at the retention boundary only" do
    now = ClientSocialCeremonyTransaction.database_now
    cutoff = now - SocialCeremonyTransactionable::RETENTION_PERIOD

    expired_before_cutoff = ClientSocialCeremonyTransaction.create_transaction!(
      actor_ref: PublicId.generate,
      session_ref: PublicId.generate,
      operation: "link",
      provider: "google",
      expires_at: cutoff - 1.second,
      now:,
    )
    expired_at_cutoff = ClientSocialCeremonyTransaction.create_transaction!(
      actor_ref: PublicId.generate,
      session_ref: PublicId.generate,
      operation: "link",
      provider: "google",
      expires_at: cutoff,
      now:,
    )
    expired_after_cutoff = ClientSocialCeremonyTransaction.create_transaction!(
      actor_ref: PublicId.generate,
      session_ref: PublicId.generate,
      operation: "link",
      provider: "google",
      expires_at: cutoff + 1.second,
      now:,
    )
    consumed_at_cutoff = ClientSocialCeremonyTransaction.create!(
      transaction_id: PublicId.generate,
      surface: "app",
      actor_ref: PublicId.generate,
      session_ref: PublicId.generate,
      operation: "link",
      provider: "google",
      grant_jti: PublicId.generate,
      expires_at: now + 1.hour,
      consumed_at: cutoff,
      status: SocialCeremonyTransactionable::STATUS_CONSUMED,
      result_jti: PublicId.generate,
      created_at: cutoff,
      updated_at: cutoff,
    )

    purged = IdentitySocialCeremonyTransactionPurger.new(now:).call

    assert_equal 3, purged.fetch("app")
    assert_not ClientSocialCeremonyTransaction.exists?(expired_before_cutoff.id)
    assert_not ClientSocialCeremonyTransaction.exists?(expired_at_cutoff.id)
    assert_not ClientSocialCeremonyTransaction.exists?(consumed_at_cutoff.id)
    assert ClientSocialCeremonyTransaction.exists?(expired_after_cutoff.id)
  end

  test "class entry point returns a zero count when no transaction is purgeable" do
    now = ClientSocialCeremonyTransaction.database_now

    result = IdentitySocialCeremonyTransactionPurger.call(now:)

    assert_equal({ "app" => 0 }, result)
  end
end
