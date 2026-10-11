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

  test "valid result consumes once and commits freshness through acme service" do
    travel_to @now do
      issuance = issue_transaction!
      result_token = result_for(issuance.transaction)

      consumption = IdentityStepUpCeremonyResultConsumer.new(transaction: issuance.transaction, now: @now)
        .call(result_token)

      assert_predicate consumption.transaction.reload, :consumed?
      assert_equal "result-1", consumption.transaction.result_jti
      assert_equal "totp", consumption.transaction.method
      assert_equal "aal2", consumption.transaction.aal

      IdentityStepUpCeremonyFreshnessCommitter.call!(
        result_token: result_token,
        token: @token,
        expected_scope: "settings_email",
        expected_aal: "aal2",
        expected_method: "totp",
        audience: "step_up:app",
        surface: "app",
        now: @now,
      )

      assert_equal @now.to_i, @token.reload.last_step_up_at.to_i
      assert_equal "settings_email", @token.last_step_up_scope
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyResultConsumer.new(transaction: issuance.transaction.reload, now: @now)
          .call(result_token)
      end
    end
  end

  test "result consumer rejects wrong binding insufficient aal disallowed method and expired transaction" do
    travel_to @now do
      issuance = issue_transaction!

      assert_step_up_error("actor_ref does not match transaction") do
        IdentityStepUpCeremonyResultConsumer.new(transaction: issuance.transaction, now: @now)
          .call(result_for(issuance.transaction, "actor_ref" => "wrong"))
      end

      assert_step_up_error("scope does not match transaction") do
        IdentityStepUpCeremonyResultConsumer.new(transaction: issuance.transaction, now: @now)
          .call(result_for(issuance.transaction, "scope" => "settings_phone"))
      end

      assert_step_up_error("AAL is insufficient") do
        IdentityStepUpCeremonyResultConsumer.new(transaction: issuance.transaction, now: @now)
          .call(result_for(issuance.transaction, "aal" => "aal1"))
      end

      assert_step_up_error("method is not allowed") do
        IdentityStepUpCeremonyResultConsumer.new(transaction: issuance.transaction, now: @now)
          .call(result_for(issuance.transaction, "method" => "email_otp"))
      end

      expired = create_transaction!("expired-txn", expires_at: @now - 1.minute)
      assert_step_up_error("transaction is expired") do
        IdentityStepUpCeremonyResultConsumer.new(transaction: expired, now: @now)
          .call(result_for(expired, "expires_at" => (@now + 1.minute).to_i))
      end
    end
  end

  test "transaction scopes and purger retain recent records and purge old records" do
    travel_to @now do
      active = issue_transaction!(transaction_id: "active-txn").transaction
      expired_recent = create_transaction!("expired-recent", expires_at: @now - 1.hour)
      expired_old = create_transaction!("expired-old", expires_at: @now - 8.days)
      consumed_old = issue_transaction!(transaction_id: "consumed-old").transaction
      consumed_old.consume_result!(
        result_jti: "consumed-old-result",
        method: "totp",
        aal: "aal2",
        verified_at: @now - 8.days,
        consumed_at: @now - 8.days,
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

  test "consume_result raises when result_jti collides with an existing consumed transaction" do
    travel_to @now do
      first = issue_transaction!(transaction_id: "collide-first").transaction
      first.consume_result!(
        result_jti: "step-up-colliding",
        method: "totp",
        aal: "aal2",
        verified_at: @now,
        consumed_at: @now,
      )

      second = create_transaction!("collide-second", expires_at: @now + 1.hour)

      assert_step_up_error("result_jti has already been consumed") do
        second.consume_result!(
          result_jti: "step-up-colliding",
          method: "totp",
          aal: "aal2",
          verified_at: @now,
          consumed_at: @now,
        )
      end
    end
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
