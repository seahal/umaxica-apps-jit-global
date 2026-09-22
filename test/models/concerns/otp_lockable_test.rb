# typed: false
# frozen_string_literal: true

require "test_helper"

# OtpLockable centralizes the OTP attempt/lock/expiry mechanics shared by the
# Email and Telephone concerns. The Email and Telephone concern tests already
# exercise the mechanics in depth through their real models; these tests pin the
# cross-channel invariants and the asymmetries that were normalized when the
# logic was unified:
#   - the unlocked sentinel is "-infinity" for both channels
#   - increment_attempts! never runs model validations (save!(validate: false))
#   - cooldown stays email-only (telephone lacks otp_last_sent_at), which the
#     OTP resend ceremony relies on via respond_to?(:otp_cooldown_active?)
class OtpLockableTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :operators, :operator_statuses

  test "both Email and Telephone include OtpLockable" do
    assert_includes ClientEmail.included_modules, OtpLockable
    assert_includes OperatorTelephone.included_modules, OtpLockable
  end

  test "clear_otp leaves an email unlocked through the shared sentinel" do
    email = ClientEmail.create!(
      user: clients(:none_user),
      address: "lockable@example.com",
      confirm_policy: true,
    )
    email.update!(locked_at: 1.minute.from_now, otp_attempts_count: OtpLockable::MAX_OTP_ATTEMPTS)

    email.clear_otp

    assert_not email.locked?
    assert_nil email.lockout_expires_at
  end

  test "clear_otp leaves a telephone unlocked through the shared sentinel" do
    telephone = OperatorTelephone.new(number: "+819012345678", staff: operators(:none_staff))
    telephone.save!(validate: false)
    telephone.update!(locked_at: 1.minute.from_now, otp_attempts_count: OtpLockable::MAX_OTP_ATTEMPTS)

    telephone.clear_otp

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
    email = ClientEmail.create!(
      user: clients(:none_user),
      address: "otp-positive-infinity@example.com",
      confirm_policy: true,
    )
    email.update_columns(
      otp_private_key: ROTP::Base32.random_base32,
      otp_counter: "1",
      otp_expires_at: Float::INFINITY,
      locked_at: -Float::INFINITY,
    )

    email.reload

    assert_predicate email, :otp_expired?,
                     "a positive infinity timestamp is invalid for an authentication OTP"
    assert_not_predicate email, :otp_active?
    assert_nil email.get_otp
  end

  test "otp expiry predicates use the owning writer database clock" do
    application_now = Time.current
    database_now = application_now - 1.hour
    expiry = application_now - 30.minutes
    email = ClientEmail.create!(
      user: clients(:none_user),
      address: "otp-database-clock@example.com",
      confirm_policy: true,
    )
    email.update_columns(
      otp_private_key: ROTP::Base32.random_base32,
      otp_counter: "1",
      otp_expires_at: expiry,
      locked_at: -Float::INFINITY,
    )

    ClientEmail.stub(:database_now, database_now) do
      assert_not_predicate email, :otp_expired?
      assert_predicate email, :otp_active?
    end
  end

  test "the lockout timestamp uses the same writer database clock as the failure increment" do
    database_now = Time.utc(2026, 9, 21, 14, 0, 0)
    email = ClientEmail.create!(
      user: clients(:none_user),
      address: "otp-lockout-database-clock@example.com",
      confirm_policy: true,
    )
    email.update_columns(
      otp_attempts_count: OtpLockable::MAX_OTP_ATTEMPTS - 1,
      otp_last_sent_at: database_now,
      locked_at: -Float::INFINITY,
    )

    ClientEmail.stub(:database_now, database_now) do
      email.increment_attempts!
    end

    assert_equal database_now + OtpLockable::OTP_LOCKOUT_DURATION, email.reload.locked_at
  end
end
