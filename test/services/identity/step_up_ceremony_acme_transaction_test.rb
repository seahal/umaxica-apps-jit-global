# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityStepUpCeremonyAcmeTransactionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :clients, :client_statuses, :client_token_kinds, :client_token_statuses

  setup do
    @now = Time.zone.parse("2026-06-03 12:00:00")
    @client = clients(:one)
    @token = ClientToken.create!(
      user: @client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
  end

  teardown do
    travel_back
  end

  test "grant issuance creates durable step up transaction and valid grant" do
    travel_to @now do
      issuance = issue_transaction!
      grant = IdentityStepUpCeremonyGrant.decode(
        issuance.grant,
        issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
        now: @now,
      )

      assert_equal issuance.transaction.transaction_id, grant["transaction_id"]
      assert_equal issuance.transaction.grant_jti, grant["jti"]
      assert_equal @client.public_id, grant["actor_ref"]
      assert_equal @token.public_id, grant["session_ref"]
      assert_equal %w(totp passkey), grant["allowed_methods"]
    end
  end

  test "transaction scopes and purger retain recent records and purge old records" do
    travel_to @now do
      active = issue_transaction!(transaction_id: "active-txn").transaction
      expired_recent = create_transaction!("expired-recent", expires_at: @now - 1.hour)
      expired_old = create_transaction!("expired-old", expires_at: @now - 8.days)
      consumed_old = issue_transaction!(transaction_id: "consumed-old").transaction
      # A week-old consumed row cannot be produced through the database-clocked transitions, so the
      # stored state is written directly; the transitions themselves are covered by the model tests.
      # The purger removes a row only once both its expiry and its terminal time are past retention.
      consumed_old.update_columns(
        status: "consumed", result_jti: "consumed-old-result", method: "totp", aal: "aal1",
        verified_at: @now - 8.days, consumed_at: @now - 8.days, expires_at: @now - 8.days,
      )

      assert_includes ClientStepUpCeremonyTransaction.active_at(@now), active
      assert_includes ClientStepUpCeremonyTransaction.expired_at(@now), expired_recent
      assert_includes ClientStepUpCeremonyTransaction.purgeable_at(@now), expired_old
      assert_includes ClientStepUpCeremonyTransaction.purgeable_at(@now), consumed_old.reload
      assert_not_includes ClientStepUpCeremonyTransaction.purgeable_at(@now), active
      assert_not_includes ClientStepUpCeremonyTransaction.purgeable_at(@now), expired_recent

      counts = IdentityStepUpCeremonyTransactionPurger.new(now: @now).call

      assert_equal 2, counts[:app]
      assert_not ClientStepUpCeremonyTransaction.exists?(expired_old.id)
      assert_not ClientStepUpCeremonyTransaction.exists?(consumed_old.id)
      assert ClientStepUpCeremonyTransaction.exists?(active.id)
      assert ClientStepUpCeremonyTransaction.exists?(expired_recent.id)
      assert_equal({ app: 0, com: 0, org: 0 }, IdentityStepUpCeremonyTransactionPurger.new(now: @now).call)
    end
  end

  test "transaction storage does not persist credential or token secrets" do
    forbidden_columns = %w(
      auth_token authorization downstream_token otp otp_digest otp_private_key raw_otp refresh_token session_token
      totp_secret webauthn_private_key
    )

    assert_empty ClientStepUpCeremonyTransaction.column_names & forbidden_columns
    assert_empty VisitorStepUpCeremonyTransaction.column_names & forbidden_columns
    assert_empty OperatorStepUpCeremonyTransaction.column_names & forbidden_columns
  end

  test "surface validation rejects surface that does not match ceremony surface" do
    txn = ClientStepUpCeremonyTransaction.new(
      surface: "com",
      actor_ref: @client.public_id,
      session_ref: @token.public_id,
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: "totp,passkey",
      transaction_id: SecureRandom.uuid,
      grant_jti: SecureRandom.uuid,
      expires_at: 10.minutes.from_now,
    )

    assert_not txn.valid?
    assert_includes txn.errors.attribute_names, :surface
  end

  private

  def issue_transaction!(transaction_id: nil, expires_at: nil)
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @token.public_id,
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: %w(totp passkey),
      transaction_id: transaction_id,
      expires_at: expires_at,
      now: @now,
    )
  end

  def create_transaction!(transaction_id, expires_at:)
    ClientStepUpCeremonyTransaction.create_transaction!(
      surface: "app",
      actor_ref: @client.public_id,
      session_ref: @token.public_id,
      required_scope: "settings_email",
      required_aal: "aal2",
      allowed_methods: %w(totp passkey),
      transaction_id: transaction_id,
      expires_at: expires_at,
      now: @now,
    )
  end

  def result_for(transaction, overrides = {})
    IdentityStepUpCeremonyResult.issue(
      {
        "typ" => IdentityStepUpCeremonyResult::TOKEN_TYPE,
        "iss" => IdentityStepUpCeremonyContract.sign_issuer("app"),
        "aud" => IdentityStepUpCeremonyContract.acme_audience("app"),
        "purpose" => IdentityStepUpCeremonyResult::PURPOSE,
        "surface" => transaction.surface,
        "actor_ref" => transaction.actor_ref,
        "session_ref" => transaction.session_ref,
        "transaction_id" => transaction.transaction_id,
        "grant_jti" => transaction.grant_jti,
        "result_jti" => overrides.fetch("result_jti", "result-1"),
        "scope" => transaction.required_scope,
        "aal" => "aal2",
        "method" => "totp",
        "verified_at" => @now.to_i,
        "challenge_id" => "challenge-1",
        "expires_at" => transaction.expires_at.to_i,
        "iat" => @now.to_i,
        "exp" => transaction.expires_at.to_i,
      }.merge(overrides),
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
      now: @now,
    )
  end

  def assert_step_up_error(message)
    error = assert_raises(IdentityStepUpCeremonyContract::Error) { yield }
    assert_includes error.message, message
  end
end
