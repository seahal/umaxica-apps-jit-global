# typed: false
# frozen_string_literal: true

require "test_helper"

# Channel policies retain independent failure and lockout behavior.
class OtpLockableTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :operators, :operator_statuses

  test "Email and Telephone activate independent OTP policies" do
    assert_includes ClientEmail.included_modules, EmailOtpPolicy
    assert_not_includes ClientEmail.included_modules, TelephoneOtpPolicy
    assert_includes OperatorTelephone.included_modules, TelephoneOtpPolicy
    assert_not_includes OperatorTelephone.included_modules, EmailOtpPolicy
  end

  test "successful email consumption clears lockout only after its finite deadline" do
    owner = Client.create!(status_id: ClientStatus::ACTIVE)
    root = ClientToken.create!(user: owner)
    root.rotate_refresh_token!
    email = ClientEmail.create!(
      user: owner,
      address: "lockable@example.com",
      confirm_policy: true,
    )
    email.update!(locked_at: email.class.database_now + 1.minute, otp_attempts_count: EmailOtpPolicy::MAX_OTP_ATTEMPTS)
    binding = { actor: owner, token: root, email: email, browser_nonce: SecureRandom.urlsafe_base64(32) }
    denied = EmailCredentialRegistrationOtpIssuer.call(**binding)

    assert_equal :locked, denied.status
    assert_nil denied.transaction
    assert_equal EmailOtpPolicy::MAX_OTP_ATTEMPTS, email.reload.otp_attempts_count
    email.update!(locked_at: email.class.database_now - Rational(1, 1_000_000))
    issued = EmailCredentialRegistrationOtpIssuer.call(**binding)
    verified = EmailCredentialRegistrationOtpVerificationCommitter.call(
      **binding, transaction: issued.transaction, code: issued.code,
    )

    assert_predicate verified, :success?
    assert_equal 0, email.reload.otp_attempts_count
    assert_not email.locked?
    assert_nil email.lockout_expires_at
  end

  test "successful telephone consumption clears lockout only after its finite deadline" do
    owner = Operator.create!(status_id: OperatorStatus::ACTIVE)
    root = OperatorToken.create!(staff: owner)
    root.rotate_refresh_token!
    telephone = OperatorTelephone.create!(
      number: "+819012345678", staff: owner, confirm_policy: true, confirm_using_mfa: true,
    )
    telephone.update!(
      locked_at: telephone.class.database_now + 1.minute, otp_attempts_count: TelephoneOtpPolicy::MAX_OTP_ATTEMPTS,
    )
    binding = { actor: owner, token: root, telephone: telephone, browser_nonce: SecureRandom.urlsafe_base64(32) }
    denied = TelephoneCredentialRegistrationOtpIssuer.call(**binding)

    assert_equal :locked, denied.status
    assert_nil denied.transaction
    assert_equal TelephoneOtpPolicy::MAX_OTP_ATTEMPTS, telephone.reload.otp_attempts_count
    telephone.update!(locked_at: telephone.class.database_now - Rational(1, 1_000_000))
    issued = TelephoneCredentialRegistrationOtpIssuer.call(**binding)
    verified = TelephoneCredentialRegistrationOtpVerificationCommitter.call(
      **binding, transaction: issued.transaction, code: issued.code,
    )

    assert_predicate verified, :success?
    assert_equal 0, telephone.reload.otp_attempts_count
    assert_not telephone.locked?
    assert_nil telephone.lockout_expires_at
  end

  test "increment_attempts! does not run model validations" do
    # confirm_policy: false makes the record fail acceptance validation, so a
    # plain save! would raise. increment_attempts! must still succeed.
    telephone = OperatorTelephone.new(
      number: "+819012345678",
      staff: operators(:none_staff),
      confirm_policy: false,
    )
    telephone.save!(validate: false)

    assert_not telephone.valid?, "fixture should be invalid so the validate: false path is meaningful"

    # valid? dirties in-memory attributes (e.g. number_digest); discard them so
    # the row lock in increment_attempts! sees a clean persisted record.
    telephone.reload

    assert_nothing_raised { telephone.increment_attempts! }
    assert_equal 1, telephone.reload.otp_attempts_count
  end

  test "cooldown stays email-only so the resend ceremony branch is preserved" do
    assert_respond_to ClientEmail.new(user: clients(:none_user)), :otp_cooldown_active?
    assert_not OperatorTelephone.new(staff: operators(:none_staff)).respond_to?(:otp_cooldown_active?)
  end

  test "a positive infinity expiry cannot make an OTP usable" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "browser", operation: "sign_in", email_candidate_ref: "candidate",
    )
    code = transaction.issue_email_otp!(purpose: "sign_in")
    transaction.update_columns(otp_expires_at: Float::INFINITY)

    assert_not transaction.email_otp_deliverable?(
      generation: transaction.otp_generation, at: transaction.class.database_now,
    ), "a positive infinity timestamp is invalid for an authentication OTP"
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_in", actor_ref: "actor", session_ref: "browser",
      operation: "sign_in", candidate_ref: "candidate",
    )
    assert_nil transaction.reload.otp_consumed_at
  end

  test "otp expiry predicates use the owning writer database clock" do
    application_now = Time.current
    database_now = application_now - 1.hour
    transaction = nil
    ClientEmailCeremonyTransaction.stub(:database_now, database_now) do
      transaction = ClientEmailCeremonyTransaction.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "sign_in", email_candidate_ref: "candidate",
        now: database_now, expires_at: application_now + 5.minutes,
      )
      code = transaction.issue_email_otp!(purpose: "sign_in")

      assert transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: database_now)
      assert transaction.deliver_email_otp!(generation: transaction.otp_generation, code: code) { true }
    end

    assert_not transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: application_now)
  end

  test "the lockout timestamp uses the same writer database clock as the failure increment" do
    database_now = Time.utc(2026, 9, 21, 14, 0, 0)
    email = ClientEmail.create!(
      user: clients(:none_user),
      address: "otp-lockout-database-clock@example.com",
      confirm_policy: true,
    )
    email.update_columns(
      otp_attempts_count: EmailOtpPolicy::MAX_OTP_ATTEMPTS - 1,
      otp_last_sent_at: database_now,
      locked_at: -Float::INFINITY,
    )

    ClientEmail.stub(:database_now, database_now) do
      email.increment_attempts!
    end

    assert_equal database_now + EmailOtpPolicy::OTP_LOCKOUT_DURATION, email.reload.locked_at
  end
end
