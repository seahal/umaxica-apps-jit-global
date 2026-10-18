# typed: false
# frozen_string_literal: true

require "test_helper"

class SocialCeremonyTransactionableTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @now = Time.zone.parse("2026-07-15 12:00:00")
  end

  teardown do
    travel_back
  end

  test "social transactions create claims, expose scopes, and consume once" do
    travel_to(@now) do
      transaction = ClientSocialCeremonyTransaction.create_transaction!(
        actor_ref: "actor-social",
        session_ref: "session-social",
        operation: "link",
        provider: "google",
        resource_ref: "resource-1",
        return_to: "/settings/social",
        provider_subject_ref: "provider-subject",
        provider_subject_digest: "provider-digest",
        now: @now,
      )

      assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.transaction_id)
      assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.grant_jti)
      assert_not_equal transaction.transaction_id, transaction.grant_jti
      assert_equal "/settings/social", transaction.grant_claims.fetch("return_to")
      assert_equal "provider-subject", transaction.grant_claims.fetch("provider_subject_ref")
      assert_includes ClientSocialCeremonyTransaction.pending, transaction
      assert_includes ClientSocialCeremonyTransaction.active_at(@now), transaction
      assert_includes ClientSocialCeremonyTransaction.purgeable_at(@now + 8.days), transaction

      consumed = transaction.consume_result!(
        result_jti: "social-result",
        provider_subject_ref: "provider-subject",
        provider_subject_digest: "provider-digest",
        consumed_at: @now,
      )

      assert_predicate consumed, :consumed?
      assert_equal "social-result", consumed.result_jti
      assert_includes ClientSocialCeremonyTransaction.consumed, consumed

      assert_raises(IdentitySocialCeremonyContract::Error) do
        consumed.consume_result!(
          result_jti: "social-result-2",
          provider_subject_ref: "provider-subject",
          provider_subject_digest: "provider-digest",
          consumed_at: @now,
        )
      end
    end
  end

  test "retries a generated social transaction reference collision at the database boundary" do
    ClientSocialCeremonyTransaction.create_transaction!(
      transaction_id: "a" * 21, grant_jti: "e" * 21,
      actor_ref: "existing-actor", session_ref: "existing-session", operation: "link", provider: "google",
    )
    generated = ["a" * 21, "g" * 21, "b" * 21, "h" * 21]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientSocialCeremonyTransaction.create_transaction!(
          actor_ref: "new-actor", session_ref: "new-session", operation: "link", provider: "google",
        )
      end

    assert_equal "b" * 21, transaction.transaction_id
    assert_equal "h" * 21, transaction.grant_jti
  end

  test "retries a generated social grant reference collision at the database boundary" do
    ClientSocialCeremonyTransaction.create_transaction!(
      transaction_id: "j" * 21, grant_jti: "i" * 21,
      actor_ref: "existing-actor", session_ref: "existing-session", operation: "link", provider: "google",
    )
    generated = ["k" * 21, "i" * 21, "l" * 21, "m" * 21]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientSocialCeremonyTransaction.create_transaction!(
          actor_ref: "new-actor", session_ref: "new-session", operation: "link", provider: "google",
        )
      end

    assert_equal "l" * 21, transaction.transaction_id
    assert_equal "m" * 21, transaction.grant_jti
  end

  test "social transactions reject invalid surface, incomplete consumption, and expiry" do
    invalid = ClientSocialCeremonyTransaction.new(
      surface: "com",
      actor_ref: "actor-invalid",
      session_ref: "session-invalid",
      operation: "link",
      provider: "google",
      status: "pending",
      transaction_id: "transaction-invalid",
      grant_jti: "grant-invalid",
      expires_at: 10.minutes.from_now,
    )

    assert_not invalid.valid?
    assert_includes invalid.errors.attribute_names, :surface

    consumed_without_result = ClientSocialCeremonyTransaction.new(
      surface: "app",
      actor_ref: "actor-consumed",
      session_ref: "session-consumed",
      operation: "link",
      provider: "google",
      status: "consumed",
      transaction_id: "transaction-consumed",
      grant_jti: "grant-consumed",
      expires_at: 10.minutes.from_now,
    )

    assert_not consumed_without_result.valid?
    assert_includes consumed_without_result.errors.attribute_names, :result_jti

    travel_to(@now) do
      expired = ClientSocialCeremonyTransaction.create_transaction!(
        actor_ref: "actor-expired",
        session_ref: "session-expired",
        operation: "link",
        provider: "google",
        expires_at: @now - 1.minute,
        now: @now,
      )

      assert_predicate expired, :expired?
      assert_raises(IdentitySocialCeremonyContract::Error) do
        expired.consume_result!(
          result_jti: "expired-result",
          provider_subject_ref: "provider-subject",
          provider_subject_digest: "provider-digest",
          consumed_at: @now,
        )
      end

      first = ClientSocialCeremonyTransaction.create_transaction!(
        actor_ref: "actor-duplicate",
        session_ref: "session-duplicate",
        operation: "link",
        provider: "google",
        now: @now,
      )
      second = ClientSocialCeremonyTransaction.create_transaction!(
        actor_ref: "actor-duplicate",
        session_ref: "session-duplicate",
        operation: "link",
        provider: "google",
        now: @now,
      )
      first.consume_result!(
        result_jti: "duplicate-result",
        provider_subject_ref: "provider-subject",
        provider_subject_digest: "provider-digest",
        consumed_at: @now,
      )

      assert_raises(IdentitySocialCeremonyContract::Error) do
        second.consume_result!(
          result_jti: "duplicate-result",
          provider_subject_ref: "provider-subject",
          provider_subject_digest: "provider-digest",
          consumed_at: @now,
        )
      end
    end
  end

  test "social transaction connection owner falls back for a generic model" do
    generic_transaction_class =
      Class.new(ApplicationRecord) do
        include SocialCeremonyTransactionable
      end

    assert_equal OpBaseAppRecord, ClientSocialCeremonyTransaction.connection_owner

    org_transaction_class =
      Class.new(OpBaseOrgRecord) do
        include SocialCeremonyTransactionable
      end
    com_transaction_class =
      Class.new(OpBaseComRecord) do
        include SocialCeremonyTransactionable
      end

    assert_equal ActiveRecord::Base, generic_transaction_class.connection_owner
    assert_equal OpBaseOrgRecord, org_transaction_class.connection_owner
    assert_equal OpBaseComRecord, com_transaction_class.connection_owner
  end
end
