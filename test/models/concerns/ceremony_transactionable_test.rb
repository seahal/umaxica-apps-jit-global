# typed: false
# frozen_string_literal: true

require "test_helper"

class CeremonyTransactionableTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  TRANSACTION_CLASSES = [
    ClientTelephoneCeremonyTransaction,
    ClientSecretCredentialCeremonyTransaction,
    ClientTotpCeremonyTransaction,
    ClientPasskeyCeremonyTransaction,
    ClientEmailCeremonyTransaction,
  ].freeze

  CEREMONY_ERRORS = [
    IdentityTelephoneCeremony::Error,
    IdentitySecretCredentialCeremonyContract::Error,
    IdentityTotpCeremonyContract::Error,
    IdentityPasskeyCeremonyContract::Error,
    IdentityEmailCeremonyContract::Error,
  ].freeze

  CEREMONY_OPERATIONS = %w(registration enrollment registration registration registration).freeze

  setup do
    @now = Time.zone.parse("2026-07-15 12:00:00")
  end

  teardown do
    travel_back
  end

  test "transaction classes create pending records with claims and expiry behavior" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        transaction = transaction_class.create_transaction!(
          actor_ref: "actor-#{index}",
          session_ref: "session-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          now: @now,
        )

        assert_equal "app", transaction.surface
        assert_equal "pending", transaction.status
        assert_equal CEREMONY_OPERATIONS[index], transaction.operation
        assert_equal @now + 10.minutes, transaction.expires_at
        assert_not transaction.expired?(now: @now)
        assert transaction.expired?(now: transaction.expires_at)
        assert_not transaction.consumed?
        assert_equal "actor-#{index}", transaction.grant_claims.fetch("actor_ref")
        assert_equal "session-#{index}", transaction.grant_claims.fetch("session_ref")
        assert_predicate transaction.transaction_id, :present?
        assert_predicate transaction.grant_jti, :present?
        assert_equal transaction.grant_jti, transaction.grant_claims.fetch("jti")
        assert_equal transaction.transaction_id, transaction.grant_claims.fetch("transaction_id")
      end
    end
  end

  test "passkey ceremony transactions issue separate NanoID references" do
    transaction = ClientPasskeyCeremonyTransaction.create_transaction!(
      actor_ref: "passkey-actor-reference",
      session_ref: "passkey-session-reference",
      operation: "registration",
      now: @now,
    )

    assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.transaction_id)
    assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.grant_jti)
    assert_not_equal transaction.transaction_id, transaction.grant_jti
  end

  test "passkey ceremony transactions retry generated transaction collisions" do
    ClientPasskeyCeremonyTransaction.create_transaction!(
      actor_ref: "passkey-collision-actor",
      session_ref: "passkey-collision-session",
      operation: "registration",
      transaction_id: "a" * 21,
      grant_jti: "existing-grant-reference",
      now: @now,
    )
    generated = ["a" * 21, "first-grant-reference", "b" * 21, "second-grant-reference"]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientPasskeyCeremonyTransaction.create_transaction!(
          actor_ref: "passkey-new-actor",
          session_ref: "passkey-new-session",
          operation: "registration",
          now: @now,
        )
      end

    assert_equal "b" * 21, transaction.transaction_id
    assert_equal "second-grant-reference", transaction.grant_jti
  end

  test "passkey ceremony transactions retry generated grant collisions" do
    ClientPasskeyCeremonyTransaction.create_transaction!(
      actor_ref: "passkey-grant-collision-actor",
      session_ref: "passkey-grant-collision-session",
      operation: "registration",
      transaction_id: "existing-transaction-reference",
      grant_jti: "i" * 21,
      now: @now,
    )
    generated = ["first-transaction-reference", "i" * 21, "second-transaction-reference", "m" * 21]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientPasskeyCeremonyTransaction.create_transaction!(
          actor_ref: "passkey-new-grant-actor",
          session_ref: "passkey-new-grant-session",
          operation: "registration",
          now: @now,
        )
      end

    assert_equal "second-transaction-reference", transaction.transaction_id
    assert_equal "m" * 21, transaction.grant_jti
  end

  test "email ceremony transactions issue separate NanoID references" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "email-actor-reference",
      session_ref: "email-session-reference",
      operation: "registration",
      now: @now,
    )

    assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.transaction_id)
    assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.grant_jti)
    assert_not_equal transaction.transaction_id, transaction.grant_jti
  end

  test "email ceremony transactions retry generated transaction collisions" do
    ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "email-collision-actor",
      session_ref: "email-collision-session",
      operation: "registration",
      transaction_id: "a" * 21,
      grant_jti: "existing-email-grant-reference",
      now: @now,
    )
    generated = ["a" * 21, "first-email-grant-reference", "b" * 21, "second-email-grant-reference"]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientEmailCeremonyTransaction.create_transaction!(
          actor_ref: "email-new-actor",
          session_ref: "email-new-session",
          operation: "registration",
          now: @now,
        )
      end

    assert_equal "b" * 21, transaction.transaction_id
    assert_equal "second-email-grant-reference", transaction.grant_jti
  end

  test "email ceremony transactions retry generated grant collisions" do
    ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "email-grant-collision-actor",
      session_ref: "email-grant-collision-session",
      operation: "registration",
      transaction_id: "existing-email-transaction-reference",
      grant_jti: "i" * 21,
      now: @now,
    )
    generated = ["first-email-transaction-reference", "i" * 21,
                 "second-email-transaction-reference", "m" * 21,]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientEmailCeremonyTransaction.create_transaction!(
          actor_ref: "email-new-grant-actor",
          session_ref: "email-new-grant-session",
          operation: "registration",
          now: @now,
        )
      end

    assert_equal "second-email-transaction-reference", transaction.transaction_id
    assert_equal "m" * 21, transaction.grant_jti
  end

  test "telephone ceremony transactions issue separate NanoID references" do
    transaction = ClientTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "telephone-actor-reference",
      session_ref: "telephone-session-reference",
      operation: "registration",
      now: @now,
    )

    assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.transaction_id)
    assert_match(/\A[A-Za-z0-9_-]{21}\z/, transaction.grant_jti)
    assert_not_equal transaction.transaction_id, transaction.grant_jti
  end

  test "telephone ceremony transactions retry generated transaction collisions" do
    ClientTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "telephone-collision-actor",
      session_ref: "telephone-collision-session",
      operation: "registration",
      transaction_id: "a" * 21,
      grant_jti: "existing-telephone-grant-reference",
      now: @now,
    )
    generated = ["a" * 21, "first-telephone-grant-reference", "b" * 21,
                 "second-telephone-grant-reference",]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientTelephoneCeremonyTransaction.create_transaction!(
          actor_ref: "telephone-new-actor",
          session_ref: "telephone-new-session",
          operation: "registration",
          now: @now,
        )
      end

    assert_equal "b" * 21, transaction.transaction_id
    assert_equal "second-telephone-grant-reference", transaction.grant_jti
  end

  test "telephone ceremony transactions retry generated grant collisions" do
    ClientTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "telephone-grant-collision-actor",
      session_ref: "telephone-grant-collision-session",
      operation: "registration",
      transaction_id: "existing-telephone-transaction-reference",
      grant_jti: "i" * 21,
      now: @now,
    )
    generated = ["first-telephone-transaction-reference", "i" * 21,
                 "second-telephone-transaction-reference", "m" * 21,]

    transaction =
      PublicId.stub(:generate, -> { generated.shift }) do
        ClientTelephoneCeremonyTransaction.create_transaction!(
          actor_ref: "telephone-new-grant-actor",
          session_ref: "telephone-new-grant-session",
          operation: "registration",
          now: @now,
        )
      end

    assert_equal "second-telephone-transaction-reference", transaction.transaction_id
    assert_equal "m" * 21, transaction.grant_jti
  end

  test "transaction classes consume a pending record exactly once" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        transaction = transaction_class.create_transaction!(
          actor_ref: "actor-consume-#{index}",
          session_ref: "session-consume-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-consume-#{index}",
          grant_jti: "grant-consume-#{index}",
          now: @now,
        )

        consumed = transaction.consume_result!(
          result_jti: "result-#{index}",
          consumed_at: @now,
        )

        assert_predicate consumed, :consumed?
        assert_equal "result-#{index}", consumed.result_jti
        assert_equal @now, consumed.consumed_at

        error =
          assert_raises(CEREMONY_ERRORS[index]) do
            consumed.consume_result!(result_jti: "result-again-#{index}", consumed_at: @now)
          end
        assert_match(/already consumed/, error.message)
      end
    end
  end

  test "email OTP issuance rejects a purpose that does not belong to the transaction operation" do
    now = Time.current
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "email-purpose-actor",
      session_ref: "email-purpose-session",
      operation: "sign_up",
      email_candidate_ref: "email-purpose-candidate",
      now: now,
    )

    error =
      assert_raises(ArgumentError) do
        transaction.issue_email_otp!(purpose: "withdrawal")
      end

    assert_equal "email OTP purpose does not match operation", error.message
    transaction.reload

    assert_nil transaction.otp_generation
    assert_nil transaction.otp_verifier
  end

  test "email OTP issuance reloads operation before issuing" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "email-stale-operation-actor",
      session_ref: "email-stale-operation-session",
      operation: "registration",
      email_candidate_ref: "email-stale-operation-candidate",
      normalized_email_digest: "e" * 64,
      now: Time.current,
    )
    transaction.update_column(:operation, "withdrawal")

    assert_raises(ArgumentError, "the locked row must supply the authoritative operation") do
      transaction.issue_email_otp!(purpose: "credential_registration")
    end

    transaction.reload

    assert_nil transaction.otp_generation
    assert_nil transaction.otp_verifier
  end

  test "telephone OTP issuance rejects a purpose that does not belong to the transaction operation" do
    now = Time.current
    transaction = ClientTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "telephone-purpose-actor",
      session_ref: "telephone-purpose-session",
      operation: "sign_up",
      telephone_candidate_ref: "telephone-purpose-candidate",
      now: now,
    )

    error =
      assert_raises(ArgumentError) do
        transaction.issue_telephone_otp!(purpose: "withdrawal")
      end

    assert_equal "telephone OTP purpose does not match operation", error.message
    transaction.reload

    assert_nil transaction.otp_generation
    assert_nil transaction.otp_verifier
  end

  test "telephone OTP issuance reloads operation before issuing" do
    transaction = ClientTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "telephone-stale-operation-actor",
      session_ref: "telephone-stale-operation-session",
      operation: "registration",
      telephone_candidate_ref: "telephone-stale-operation-candidate",
      normalized_number_digest: "t" * 64,
      now: Time.current,
    )
    transaction.update_column(:operation, "withdrawal")

    assert_raises(ArgumentError, "the locked row must supply the authoritative operation") do
      transaction.issue_telephone_otp!(purpose: "credential_registration")
    end

    transaction.reload

    assert_nil transaction.otp_generation
    assert_nil transaction.otp_verifier
  end

  test "transaction classes reject mismatched and incomplete consumed records" do
    TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
      mismatched = transaction_class.new(
        surface: "com",
        actor_ref: "actor-invalid-#{index}",
        session_ref: "session-invalid-#{index}",
        operation: CEREMONY_OPERATIONS[index],
        status: "pending",
        transaction_id: "transaction-invalid-#{index}",
        grant_jti: "grant-invalid-#{index}",
        expires_at: 10.minutes.from_now,
      )

      assert_not mismatched.valid?
      assert_includes mismatched.errors.attribute_names, :surface

      consumed_without_result = transaction_class.new(
        surface: "app",
        actor_ref: "actor-consumed-#{index}",
        session_ref: "session-consumed-#{index}",
        operation: CEREMONY_OPERATIONS[index],
        status: "consumed",
        transaction_id: "transaction-consumed-#{index}",
        grant_jti: "grant-consumed-#{index}",
        expires_at: 10.minutes.from_now,
      )

      assert_not consumed_without_result.valid?
      assert_includes consumed_without_result.errors.attribute_names, :result_jti
    end
  end

  test "transaction classes expose scopes and preserve optional claims" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        options = {
          actor_ref: "actor-scope-#{index}",
          session_ref: "session-scope-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-scope-#{index}",
          grant_jti: "grant-scope-#{index}",
          expires_at: @now + 1.hour,
          now: @now,
        }
        options[:telephone_candidate_ref] =
          "telephone-candidate-#{index}" if transaction_class.column_names.include?("telephone_candidate_ref")
        options[:normalized_number_digest] =
          "number-digest-#{index}" if transaction_class.column_names.include?("normalized_number_digest")
        options[:credential_candidate_ref] =
          "credential-candidate-#{index}" if transaction_class.column_names.include?("credential_candidate_ref")
        options[:credential_candidate_digest] =
          "credential-digest-#{index}" if transaction_class.column_names.include?("credential_candidate_digest")
        options[:email_candidate_ref] =
          "email-candidate-#{index}" if transaction_class.column_names.include?("email_candidate_ref")
        options[:normalized_email_digest] =
          "email-digest-#{index}" if transaction_class.column_names.include?("normalized_email_digest")
        if transaction_class.column_names.include?("evp_nonce_digest")
          options[:evp_nonce_digest] = "evp-nonce-#{index}"
          options[:evp_outcome] = "pending"
        end

        transaction = transaction_class.create_transaction!(**options)

        assert_includes transaction_class.pending, transaction
        assert_includes transaction_class.active_at(@now), transaction
        assert_includes transaction_class.expired_at(@now + 2.hours), transaction
        assert_includes transaction_class.purgeable_at(@now + 8.days), transaction
        assert_not_includes transaction_class.consumed, transaction
        assert_equal "telephone-candidate-#{index}",
                     transaction.grant_claims["telephone_candidate_ref"] \
                       if transaction.respond_to?(:telephone_candidate_ref)
        assert_equal "credential-candidate-#{index}",
                     transaction.grant_claims["credential_candidate_ref"] \
                       if transaction.respond_to?(:credential_candidate_ref)
        assert_equal "email-candidate-#{index}",
                     transaction.grant_claims["email_candidate_ref"] if transaction.respond_to?(:email_candidate_ref)
        assert_equal "pending", transaction.evp_outcome if transaction.respond_to?(:evp_outcome)
      end
    end
  end

  test "transaction classes reject consuming expired and duplicate result records" do
    travel_to(@now) do
      TRANSACTION_CLASSES.each_with_index do |transaction_class, index|
        expired = transaction_class.create_transaction!(
          actor_ref: "actor-expired-#{index}",
          session_ref: "session-expired-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-expired-#{index}",
          grant_jti: "grant-expired-#{index}",
          expires_at: @now - 1.minute,
          now: @now,
        )

        assert_raises(CEREMONY_ERRORS[index]) do
          expired.consume_result!(result_jti: "result-expired-#{index}", consumed_at: @now)
        end

        first = transaction_class.create_transaction!(
          actor_ref: "actor-duplicate-#{index}",
          session_ref: "session-duplicate-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-first-#{index}",
          grant_jti: "grant-first-#{index}",
          now: @now,
        )
        second = transaction_class.create_transaction!(
          actor_ref: "actor-duplicate-#{index}",
          session_ref: "session-duplicate-#{index}",
          operation: CEREMONY_OPERATIONS[index],
          transaction_id: "transaction-second-#{index}",
          grant_jti: "grant-second-#{index}",
          now: @now,
        )

        first.consume_result!(result_jti: "result-duplicate-#{index}", consumed_at: @now)

        assert_raises(CEREMONY_ERRORS[index]) do
          second.consume_result!(result_jti: "result-duplicate-#{index}", consumed_at: @now)
        end
      end
    end
  end

  test "transaction classes select the correct writing connection owner" do
    assert_equal AppTicketRecord, ClientTelephoneCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorTelephoneCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorTelephoneCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientSecretCredentialCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorSecretCredentialCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorSecretCredentialCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientTotpCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientPasskeyCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorPasskeyCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorPasskeyCeremonyTransaction.connection_owner

    assert_equal AppTicketRecord, ClientEmailCeremonyTransaction.connection_owner
    assert_equal OrgTicketRecord, OperatorEmailCeremonyTransaction.connection_owner
    assert_equal ComTicketRecord, VisitorEmailCeremonyTransaction.connection_owner

    [
      TelephoneCeremonyTransactionable,
      SecretCredentialCeremonyTransactionable,
      TotpCeremonyTransactionable,
      PasskeyCeremonyTransactionable,
      EmailCeremonyTransactionable,
    ].each do |transactionable|
      generic_transaction_class =
        Class.new(ApplicationRecord) do
          include transactionable
        end

      assert_equal ActiveRecord::Base, generic_transaction_class.connection_owner
    end
  end
end
