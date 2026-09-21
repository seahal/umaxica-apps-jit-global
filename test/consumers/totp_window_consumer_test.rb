# typed: false
# frozen_string_literal: true

require "test_helper"

# TOTP retry protection belongs to one authenticator, not to the account as a whole.
# These tests exercise the public consumer contract, including the actor-scoped selector
# used when an account has more than one active authenticator.
class TotpWindowConsumerTest < ActiveSupport::TestCase
  fixtures :client_statuses, :client_totp_credential_statuses

  setup do
    @now = Time.zone.parse("2026-09-19 12:00:00")
    @user = Client.create!(mfa_level_enabled: true)
    @credential = create_credential!
  end

  test "a wrong code increments only the selected credential" do
    second = create_credential!(title: "second")

    result = consume(wrong_code_for(@credential), credential_public_id: @credential.public_id)

    assert_equal :mismatch, result.status
    assert_equal 1, @credential.reload.otp_attempts_count
    assert_equal 0, second.reload.otp_attempts_count
  end

  test "one active credential is selected automatically" do
    result = consume(wrong_code_for(@credential))

    assert_equal :mismatch, result.status
    assert_equal @credential.public_id, result.credential.public_id
    assert_equal 1, @credential.reload.otp_attempts_count
  end

  test "multiple active credentials require an actor-scoped public selector" do
    create_credential!(title: "second")

    result = consume(wrong_code_for(@credential))

    assert_equal :credential_required, result.status
    assert_nil result.credential
    assert_equal 0, @user.client_totp_credentials.sum(:otp_attempts_count)
  end

  test "a selector for another client does not bind an attempt" do
    other = Client.create!(mfa_level_enabled: true)
    foreign = create_credential_for!(other)

    result = consume(wrong_code_for(@credential), credential_public_id: foreign.public_id)

    assert_equal :mismatch, result.status
    assert_nil result.credential
    assert_equal 0, @credential.reload.otp_attempts_count
    assert_equal 0, foreign.reload.otp_attempts_count
  end

  test "98 failures become 99 and remain active" do
    @credential.update!(otp_attempts_count: 98)

    result = consume(wrong_code_for(@credential))

    assert_equal :mismatch, result.status
    assert_equal 99, @credential.reload.otp_attempts_count
    assert_equal ClientTotpCredentialStatus::ACTIVE, @credential.user_identity_totp_credential_status_id
  end

  test "the 100th failure permanently revokes the credential" do
    @credential.update!(otp_attempts_count: 99)

    result = consume(wrong_code_for(@credential))

    assert_equal :revoked, result.status
    @credential.reload

    assert_equal 100, @credential.otp_attempts_count
    assert_equal ClientTotpCredentialStatus::REVOKED, @credential.user_identity_totp_credential_status_id
  end

  test "a revoked credential never advances or becomes usable again" do
    @credential.update!(
      otp_attempts_count: 100,
      user_identity_totp_credential_status_id: ClientTotpCredentialStatus::REVOKED,
    )

    result = consume(code_at(@credential, @now))

    assert_equal :mismatch, result.status
    @credential.reload

    assert_equal 100, @credential.otp_attempts_count
    assert_equal ClientTotpCredentialStatus::REVOKED, @credential.user_identity_totp_credential_status_id
    assert_predicate @credential.last_otp_at, :infinite?
  end

  test "a successful verification resets only the selected credential" do
    second = create_credential!(title: "second")
    @credential.update!(otp_attempts_count: 99)

    result = consume(code_at(@credential, @now), credential_public_id: @credential.public_id)

    assert_predicate result, :accepted?
    assert_equal 0, @credential.reload.otp_attempts_count
    assert_equal 0, second.reload.otp_attempts_count
  end

  test "a replayed code is a failed attempt on the selected credential" do
    code = code_at(@credential, @now)

    assert_predicate consume(code), :accepted?

    result = consume(code)

    assert_predicate result, :replay?
    assert_equal 1, @credential.reload.otp_attempts_count
  end

  test "failure count does not reset when time passes" do
    @credential.update!(otp_attempts_count: 3)

    result = consume(wrong_code_for(@credential), at: @now + 30.days)

    assert_equal :mismatch, result.status
    assert_equal 4, @credential.reload.otp_attempts_count
  end

  test "an inactive credential is not an attempt target" do
    @credential.update!(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::INACTIVE)

    result = consume(wrong_code_for(@credential), credential_public_id: @credential.public_id)

    assert_equal :mismatch, result.status
    assert_nil result.credential
    assert_equal 0, @credential.reload.otp_attempts_count
  end

  private

  def consume(token, credential_public_id: nil, at: @now)
    TotpWindowConsumer.call(
      credentials: active_credentials,
      token: token,
      credential_public_id: credential_public_id,
      now: at,
    )
  end

  def active_credentials
    @user.client_totp_credentials
      .where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)
      .order(created_at: :desc)
  end

  def create_credential!(title: "totp")
    create_credential_for!(@user, title: title)
  end

  def create_credential_for!(user, title: "totp")
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: title,
    )
  end

  def code_at(credential, time)
    ROTP::TOTP.new(credential.private_key).at(time.to_i)
  end

  def wrong_code_for(credential, at: @now)
    valid = [-30, 0, 30].map { |offset| ROTP::TOTP.new(credential.private_key).at(at.to_i + offset) }
    ("000000".."999999").find { |candidate| valid.exclude?(candidate) }
  end
end
