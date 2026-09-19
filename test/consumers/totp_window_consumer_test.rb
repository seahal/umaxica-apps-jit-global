# typed: false
# frozen_string_literal: true

require "test_helper"

# TOTP retry protection is authenticator state, so PostgreSQL holds it. These tests pin the
# observable contract of TotpWindowConsumer: every failed guess is recorded on the account's
# active TOTP credentials, the account locks at the threshold, a locked account rejects even a
# correct code, and a successful verification clears the failure state.
class TotpWindowConsumerTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_totp_credential_statuses

  setup do
    @now = Time.zone.parse("2026-09-19 12:00:00")
    @user = Client.create!(mfa_level_enabled: true)
    @credential = create_credential!
  end

  test "a wrong code is recorded as a failed attempt in PostgreSQL" do
    result = consume(wrong_code)

    assert_equal :mismatch, result.status
    assert_equal 1, @credential.reload.otp_attempts_count
  end

  test "a failed attempt is recorded on every active credential of the account" do
    second = create_credential!

    consume(wrong_code)

    assert_equal 1, @credential.reload.otp_attempts_count
    assert_equal 1, second.reload.otp_attempts_count
  end

  test "the account locks when failures reach the threshold within the attempt window" do
    (ClientTotpCredential::MAX_TOTP_ATTEMPTS - 1).times { consume(wrong_code) }

    assert_equal :mismatch, consume(wrong_code).status

    result = consume(wrong_code)

    assert_equal :locked, result.status
    assert_not_predicate result, :accepted?
    assert_equal @now + ClientTotpCredential::TOTP_LOCKOUT_DURATION, result.locked_until
  end

  test "a locked account rejects a correct code without consuming it" do
    ClientTotpCredential::MAX_TOTP_ATTEMPTS.times { consume(wrong_code) }

    result = consume(code_at(@now))

    assert_equal :locked, result.status
    assert_predicate @credential.reload.last_otp_at, :infinite?
  end

  test "failed attempts made while locked do not extend the lock" do
    ClientTotpCredential::MAX_TOTP_ATTEMPTS.times { consume(wrong_code) }
    locked_until = consume(wrong_code).locked_until

    later = @now + 5.minutes

    assert_equal locked_until, consume(wrong_code, at: later).locked_until
  end

  test "the lock expires after the lockout duration and a correct code is then accepted" do
    ClientTotpCredential::MAX_TOTP_ATTEMPTS.times { consume(wrong_code) }
    after_lock = @now + ClientTotpCredential::TOTP_LOCKOUT_DURATION + 1.second

    result = consume(code_at(after_lock), at: after_lock)

    assert_predicate result, :accepted?
  end

  test "failures older than the attempt window do not accumulate toward the lock" do
    (ClientTotpCredential::MAX_TOTP_ATTEMPTS - 1).times { consume(wrong_code) }
    later = @now + ClientTotpCredential::TOTP_ATTEMPT_WINDOW + 1.second

    assert_equal :mismatch, consume(wrong_code, at: later).status
    assert_equal 1, @credential.reload.otp_attempts_count
  end

  test "a successful verification resets the failure state" do
    3.times { consume(wrong_code) }

    assert_predicate consume(code_at(@now)), :accepted?
    assert_equal 0, @credential.reload.otp_attempts_count
  end

  test "a replayed code counts as a failed attempt" do
    assert_predicate consume(code_at(@now)), :accepted?

    result = consume(code_at(@now))

    assert_predicate result, :replay?
    assert_equal 1, @credential.reload.otp_attempts_count
  end

  test "an account without active credentials records nothing and does not lock" do
    @credential.update!(user_totp_credential_status_id: ClientTotpCredentialStatus::INACTIVE)

    result = consume(wrong_code)

    assert_equal :mismatch, result.status
    assert_equal 0, @credential.reload.otp_attempts_count
  end

  private

  def consume(token, at: @now)
    TotpWindowConsumer.call(credentials: active_credentials, token: token, now: at)
  end

  def active_credentials
    @user.client_totp_credentials
      .where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
      .order(created_at: :desc)
  end

  def create_credential!
    ClientTotpCredential.create!(
      user: @user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
  end

  def code_at(time)
    ROTP::TOTP.new(@credential.private_key).at(time.to_i)
  end

  # A six-digit code that no active credential accepts at @now (or within drift).
  def wrong_code
    valid =
      active_credentials.flat_map do |credential|
        totp = ROTP::TOTP.new(credential.private_key)
        [-30, 0, 30].map { |offset| totp.at(@now.to_i + offset) }
      end
    ("000000".."999999").find { |candidate| valid.exclude?(candidate) }
  end
end
