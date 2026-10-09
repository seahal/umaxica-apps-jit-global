# typed: false
# frozen_string_literal: true

require "test_helper"

class TelephoneTest < ActiveSupport::TestCase
  fixtures :operators, :operator_statuses

  setup do
    @actor = Operator.create!(status_id: OperatorStatus::ACTIVE)
    @token = OperatorToken.create!(staff: @actor)
    @token.rotate_refresh_token!
    @telephone = OperatorTelephone.create!(
      raw_number: "+1234567890", staff: @actor, confirm_policy: true, confirm_using_mfa: true,
    )
    @browser_nonce = SecureRandom.urlsafe_base64(32)
    issued = TelephoneCredentialRegistrationOtpIssuer.call(
      actor: @actor, token: @token, telephone: @telephone, browser_nonce: @browser_nonce,
    )
    @transaction = issued.transaction
    @code = issued.code
  end

  test "own registration issuance stores keyed verifier generation and finite expiry on the typed ceremony" do
    assert_match(/\A[0-9]{6}\z/, @code)
    assert_predicate @transaction.otp_verifier, :present?
    assert_predicate @transaction.otp_generation, :present?
    assert_equal @telephone.id.to_s, @transaction.telephone_candidate_ref
    assert_operator @transaction.otp_expires_at, :<=, @transaction.expires_at
    assert_operator @transaction.otp_expires_at, :>, @transaction.created_at
    assert_equal 0, @telephone.otp_attempts_count
    # unlocked sentinel
    locked = @telephone.locked_at

    assert locked.nil? || locked.to_s == "-infinity" || (locked.is_a?(Float) && locked == -Float::INFINITY)
  end

  test "durable ceremony stores a keyed verifier rather than a plaintext code or reconstructible private key" do
    raw = OperatorTelephoneCeremonyTransaction.where(transaction_id: @transaction.transaction_id).pick(:otp_verifier)

    assert_equal @transaction.reload.otp_verifier, raw
    assert_not_equal @code, raw
    assert_not_includes @transaction.attributes.values, @code
  end

  test "registration issuance refuses active lockout without clearing Source failures" do
    lockout_expires_at = 10.minutes.from_now
    @telephone.update!(
      locked_at: lockout_expires_at,
      otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS,
    )

    refused = TelephoneCredentialRegistrationOtpIssuer.call(
      actor: @actor, token: @token, telephone: @telephone, browser_nonce: @browser_nonce,
    )

    assert_equal :locked, refused.status
    assert_nil refused.code
    assert_equal Telephone::MAX_OTP_ATTEMPTS, @telephone.reload.otp_attempts_count
    assert_equal lockout_expires_at.to_i, @telephone.locked_at.to_i
    assert_predicate @telephone, :locked?
  end

  test "registration form admits the original typed current proof" do
    assert TelephoneCredentialRegistrationOtpFormQuery.call(
      actor: @actor, token: @token, telephone: @telephone, transaction: @transaction,
      browser_nonce: @browser_nonce,
    )
  end

  test "registration form refuses canceled proof because the database forbids a missing active verifier" do
    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorTelephoneCeremonyTransaction.transaction(requires_new: true) { @transaction.update!(otp_verifier: nil) }
    end
    @transaction.reload.cancel_telephone_otp!

    assert_not TelephoneCredentialRegistrationOtpFormQuery.call(
      actor: @actor, token: @token, telephone: @telephone, transaction: @transaction,
      browser_nonce: @browser_nonce,
    )
  end

  test "registration form refuses proof exactly at OTP expiry" do
    OperatorTelephoneCeremonyTransaction.stub(:database_now, @transaction.otp_expires_at) do
      assert_not TelephoneCredentialRegistrationOtpFormQuery.call(
        actor: @actor, token: @token, telephone: @telephone, transaction: @transaction,
        browser_nonce: @browser_nonce,
      )
    end
  end

  test "registration verification refuses a locked candidate without consuming its typed proof" do
    @telephone.update!(locked_at: 1.minute.from_now)

    refused = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
      actor: @actor, token: @token, telephone: @telephone, transaction: @transaction,
      browser_nonce: @browser_nonce, code: @code,
    )

    assert_equal :locked, refused.status
    assert_nil @transaction.reload.otp_consumed_at
  end

  test "ceremony cancellation clears active verifier but retains generation expiry and Source failures" do
    @telephone.update!(otp_attempts_count: 2, locked_at: 1.minute.from_now)
    source_facts = @telephone.attributes.slice("otp_attempts_count", "locked_at", "otp_last_sent_at")
    proof_facts = @transaction.attributes.slice("otp_generation", "otp_expires_at")

    assert @transaction.cancel_telephone_otp!
    assert_nil @transaction.reload.otp_verifier
    assert_predicate @transaction.otp_cancelled_at, :present?
    assert_equal proof_facts, @transaction.attributes.slice(*proof_facts.keys)
    assert_equal source_facts, @telephone.reload.attributes.slice(*source_facts.keys)
  end

  test "unissued ceremony has nil expiry and cannot be delivered because issued nil expiry is forbidden" do
    unissued = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: @actor.public_id, session_ref: "unissued-model-browser", operation: "registration",
      telephone_candidate_ref: @telephone.id.to_s, normalized_number_digest: @telephone.number_digest,
    )

    assert_nil unissued.otp_expires_at
    assert_not unissued.telephone_otp_deliverable?(
      generation: nil, at: OperatorTelephoneCeremonyTransaction.database_now,
    )
  end

  test "ceremony proof is deliverable immediately below but not at or above OTP expiry" do
    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      assert_equal offset.negative?, @transaction.telephone_otp_deliverable?(
        generation: @transaction.otp_generation, at: @transaction.otp_expires_at + offset,
      )
    end
  end

  test "locked? returns true if lockout active or attempts exceeded in window" do
    assert_not @telephone.locked?

    @telephone.update!(locked_at: 1.minute.from_now)

    assert_predicate @telephone, :locked?

    @telephone.update!(
      locked_at: "-infinity", otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS,
      otp_last_sent_at: Time.current,
    )

    assert_predicate @telephone, :locked?
  end

  test "increment_attempts! increments counter and locks if threshold reached" do
    (Telephone::MAX_OTP_ATTEMPTS - 1).times do |index|
      @telephone.increment_attempts!

      assert_equal index + 1, @telephone.otp_attempts_count
      assert_not @telephone.locked?
    end

    @telephone.increment_attempts!

    assert_equal Telephone::MAX_OTP_ATTEMPTS, @telephone.otp_attempts_count
    assert_predicate @telephone, :locked?
    assert_not_nil @telephone.locked_at
  end

  test "increment_attempts! sets locked_at timestamp when threshold is reached" do
    # Initially locked_at should be a sentinel (-infinity)
    locked = @telephone.locked_at

    assert locked.nil? || locked.to_s == "-infinity" || (locked.is_a?(Float) && locked == -Float::INFINITY)

    Telephone::MAX_OTP_ATTEMPTS.times { @telephone.increment_attempts! }
    @telephone.reload

    assert_predicate @telephone.locked_at, :present?
    assert_not_equal @telephone.locked_at, -Float::INFINITY
    assert_operator @telephone.locked_at, :>, Time.current
    assert_operator @telephone.locked_at, :<=, Telephone::OTP_LOCKOUT_DURATION.from_now
  end

  test "increment_attempts! keeps locked_at stable when incrementing beyond threshold" do
    Telephone::MAX_OTP_ATTEMPTS.times { @telephone.increment_attempts! }
    @telephone.reload

    first_locked_at = @telephone.locked_at

    assert_predicate first_locked_at, :present?
    assert_not_equal first_locked_at, -Float::INFINITY

    # Increment again beyond threshold
    @telephone.increment_attempts!
    @telephone.reload

    # locked_at should remain the same (idempotent)
    assert_equal first_locked_at.to_i, @telephone.locked_at.to_i
  end

  test "increment_attempts! does not change locked_at if already set" do
    initial_lock_time = 1.hour.from_now
    @telephone.update!(locked_at: initial_lock_time, otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS)

    # Increment again
    @telephone.increment_attempts!
    @telephone.reload

    # locked_at should remain unchanged (idempotent)
    assert_equal initial_lock_time.to_i, @telephone.locked_at.to_i
  end

  test "locked? returns false after lockout expires" do
    @telephone.update!(locked_at: 1.second.ago, otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS)

    assert_not @telephone.locked?
  end

  test "attempts outside observation window are retained and still reach lockout" do
    @telephone.update!(
      otp_attempts_count: Telephone::MAX_OTP_ATTEMPTS - 1,
      otp_last_sent_at: (Telephone::OTP_ATTEMPT_WINDOW + 1.second).ago,
    )

    @telephone.increment_attempts!

    assert_equal Telephone::MAX_OTP_ATTEMPTS, @telephone.reload.otp_attempts_count
    assert_predicate @telephone, :locked?
  end

  test "validate_number_format adds specific error for country code" do
    zero_country = OperatorTelephone.new(number: "+0123456789", staff: operators(:none_staff))

    assert_not zero_country.valid?
    assert_includes zero_country.errors.details[:number].pluck(:error),
                    :country_code_cannot_start_with_zero
  end

  test "reregistration_window_active? uses the explicit issuance timestamp and independent ten second window" do
    @telephone.update!(otp_last_sent_at: 9.seconds.ago)

    assert_predicate @telephone, :reregistration_window_active?

    @telephone.update!(otp_last_sent_at: 11.seconds.ago)

    assert_not @telephone.reregistration_window_active?
  end

  # Address/number handling pins (current behavior fixed before any future split).
  # These cover the concern integration the OTP-heavy tests above leave unfixed:
  # E.164 normalization, blind-index digest assignment, and digest-based lookups.

  test "normalize_number_from_raw converts a formatted raw number to E.164 before validation" do
    telephone = OperatorTelephone.new(
      staff: operators(:none_staff),
      raw_number: "090-1234-5678",
      confirm_policy: true,
      confirm_using_mfa: true,
    )

    assert_predicate telephone, :valid?
    assert_equal "+819012345678", telephone.number
  end

  test "normalize_number_from_raw is a no-op when raw_number is blank" do
    telephone = OperatorTelephone.new(staff: operators(:none_staff))
    telephone.raw_number = ""
    telephone.number = "+819012345678"
    telephone.valid?

    assert_equal "+819012345678", telephone.number
  end

  test "set_number_digests stores the blind-index digest on save" do
    telephone = OperatorTelephone.create!(
      staff: operators(:none_staff),
      raw_number: "090-1234-5678",
      confirm_policy: true,
      confirm_using_mfa: true,
    )

    assert_equal IdentifierBlindIndex.bidx_for_telephone("090-1234-5678", realm: :org),
                 telephone.number_digest
  end

  test "find_by_number locates a record through the blind-index digest" do
    telephone = OperatorTelephone.create!(
      staff: operators(:none_staff),
      raw_number: "090-1234-5678",
      confirm_policy: true,
      confirm_using_mfa: true,
    )

    # Distinct surface formatting normalizes to the same E.164 digest.
    assert_equal telephone, OperatorTelephone.public_send(:find_by_number, "+81 90-1234-5678")
    assert_nil OperatorTelephone.public_send(:find_by_number, "080-0000-0000")
  end

  test "with_number scope filters by the blind-index digest" do
    telephone = OperatorTelephone.create!(
      staff: operators(:none_staff),
      raw_number: "090-1234-5678",
      confirm_policy: true,
      confirm_using_mfa: true,
    )

    assert_includes OperatorTelephone.with_number("090-1234-5678"), telephone
    assert_empty OperatorTelephone.with_number("080-0000-0000")
  end

  test "confirm_using_mfa acceptance is required when a raw number is present" do
    telephone = OperatorTelephone.new(
      staff: operators(:none_staff),
      raw_number: "090-1234-5678",
      confirm_policy: true,
      confirm_using_mfa: false,
    )

    assert_not telephone.valid?
    assert_predicate telephone.errors[:confirm_using_mfa], :any?
  end
end
