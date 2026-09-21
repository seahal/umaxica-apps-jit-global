# typed: false
# frozen_string_literal: true

require "test_helper"

# Test with ClientEmail which includes Email
class EmailTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :client_statuses, :operator_statuses

  setup do
    @user = clients(:none_user)
  end

  def build_email(attrs = {})
    ClientEmail.new({ user: @user }.merge(attrs))
  end

  def create_email(attrs = {})
    ClientEmail.create!({ user: @user }.merge(attrs))
  end

  test "concern can be included in a class" do
    assert_includes ClientEmail.included_modules, Email
  end

  test "concern adds confirm_policy accessor" do
    email = build_email

    assert_respond_to email, :confirm_policy
    assert_respond_to email, :confirm_policy=
  end

  test "concern adds pass_code accessor" do
    email = build_email

    assert_respond_to email, :pass_code
    assert_respond_to email, :pass_code=
  end

  test "downcases address before save" do
    email = build_email(address: "TEST@EXAMPLE.COM", confirm_policy: true)
    email.save!

    assert_equal "test@example.com", email.address
  end

  test "stores distinct ciphertexts for distinct addresses" do
    email1 = create_email(address: "test1@example.com", confirm_policy: true)
    email2 = create_email(address: "test2@example.com", confirm_policy: true)
    sql = "SELECT address FROM #{ClientEmail.table_name} WHERE id = :id"

    # Different emails should have different encrypted values
    raw1 = ClientEmail.connection.execute(
      ClientEmail.sanitize_sql_array([sql, { id: email1.id }]),
    ).first
    raw2 = ClientEmail.connection.execute(
      ClientEmail.sanitize_sql_array([sql, { id: email2.id }]),
    ).first

    assert_not_equal raw1["address"], raw2["address"]
  end

  test "encrypts the OTP private key at rest" do
    email = create_email(address: "otp-secret@example.test", confirm_policy: true)
    secret = "otp-private-key-#{SecureRandom.hex(12)}"

    email.store_otp(secret, 123, 5.minutes.from_now.to_i)

    raw = ClientEmail.connection.select_value(
      "SELECT otp_private_key FROM #{ClientEmail.connection.quote_table_name(ClientEmail.table_name)} " \
      "WHERE id = #{Integer(email.id)}",
    )

    assert_equal secret, email.reload.otp_private_key
    assert_not_equal secret, raw
    assert_not_includes raw.to_s, secret
  end

  test "validates email format with basic formats" do
    assert_predicate build_email(address: "test@example.com", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user+tag@example.co.jp", confirm_policy: true), :valid?
  end

  test "validates email format with consecutive special characters" do
    assert_predicate build_email(address: "user+tag@example.co.uk", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user+tag+123@example.com", confirm_policy: true), :valid?
  end

  test "validates email format with dots and underscores" do
    assert_predicate build_email(address: "user.name@example.com", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user_name@example.co.uk", confirm_policy: true), :valid?
  end

  test "validates email format with multiple domain levels" do
    assert_predicate build_email(address: "user@mail.example.co.uk", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user.tag@sub.example.com", confirm_policy: true), :valid?
  end

  test "validates email format with Gmail-style addressing" do
    assert_predicate build_email(address: "user+mailbox@gmail.com", confirm_policy: true), :valid?
  end

  test "validates email format with mixed special characters" do
    assert_predicate build_email(address: "user-name_tag+123@example.co.uk", confirm_policy: true), :valid?
  end

  test "validates email format with numeric addresses" do
    assert_predicate build_email(address: "1234567890@example.com", confirm_policy: true), :valid?
  end

  test "validates email format with single label domains and localhost" do
    assert_predicate build_email(address: "user@localhost", confirm_policy: true), :valid?
    assert_predicate build_email(address: "user@example", confirm_policy: true), :valid?
  end

  test "rejects invalid email formats" do
    assert_not build_email(address: "invalid-email", confirm_policy: true).valid?
    assert_not build_email(address: "user@", confirm_policy: true).valid?
    assert_not build_email(address: "@example.com", confirm_policy: true).valid?
  end

  test "rejects email with spaces" do
    assert_not build_email(address: "user @example.com", confirm_policy: true).valid?
  end

  test "validates email presence" do
    email = build_email(address: nil, confirm_policy: true)

    assert_not email.valid?
    assert_predicate email.errors[:address], :any?
  end

  test "validates uniqueness of address case insensitively" do
    create_email(address: "test@example.com", confirm_policy: true)
    duplicate = build_email(address: "TEST@EXAMPLE.COM", confirm_policy: true)

    assert_not duplicate.valid?
    assert_predicate duplicate.errors[:address], :any?
  end

  test "validates confirm_policy acceptance" do
    email = build_email(address: "test@example.com", confirm_policy: false)

    assert_not email.valid?
    assert_predicate email.errors[:confirm_policy], :any?
  end

  test "increment_attempts! increases otp_attempts_count atomically" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    initial_count = email.otp_attempts_count

    email.increment_attempts!

    assert_equal initial_count + 1, email.reload.otp_attempts_count
  end

  test "locked? returns false when attempts are below threshold" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    assert_not email.locked?

    (Email::MAX_OTP_ATTEMPTS - 1).times do
      email.increment_attempts!

      assert_not email.locked?
    end
  end

  test "locked? returns true when attempts reach threshold within observation window" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    Email::MAX_OTP_ATTEMPTS.times { email.increment_attempts! }

    assert_predicate email, :locked?
  end

  test "increment_attempts! sets lockout expiry when threshold is reached" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    # Initially locked_at should be a sentinel (infinity or nil)
    assert email.locked_at.nil? || email.locked_at == Float::INFINITY || email.locked_at.to_s == "infinity"

    Email::MAX_OTP_ATTEMPTS.times { email.increment_attempts! }
    email.reload

    assert_predicate email.locked_at, :present?
    assert_not_equal email.locked_at, Float::INFINITY
    assert_not_equal email.locked_at, -Float::INFINITY
    assert_operator email.locked_at, :>, Time.current
    assert_operator email.locked_at, :<=, Email::OTP_LOCKOUT_DURATION.from_now
  end

  test "increment_attempts! keeps locked_at stable when incrementing beyond threshold" do
    email = create_email(address: "test@example.com", confirm_policy: true)

    Email::MAX_OTP_ATTEMPTS.times { email.increment_attempts! }
    email.reload

    first_locked_at = email.locked_at

    assert_predicate first_locked_at, :present?
    assert_not_equal first_locked_at, Float::INFINITY
    assert_not_equal first_locked_at, -Float::INFINITY

    # Increment again beyond threshold
    email.increment_attempts!
    email.reload

    # locked_at should remain the same (idempotent)
    assert_equal first_locked_at.to_i, email.locked_at.to_i
  end

  test "increment_attempts! does not change locked_at if already set" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    initial_lock_time = 1.hour.from_now
    email.update!(locked_at: initial_lock_time, otp_attempts_count: Email::MAX_OTP_ATTEMPTS)

    # Increment again
    email.increment_attempts!
    email.reload

    # locked_at should remain unchanged (idempotent)
    assert_equal initial_lock_time.to_i, email.locked_at.to_i
  end

  test "locked? returns true when locked_at is set" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    email.update!(locked_at: 1.minute.from_now)

    assert_predicate email, :locked?
  end

  test "locked? returns false after lockout expires" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    email.update!(locked_at: 1.second.ago, otp_attempts_count: Email::MAX_OTP_ATTEMPTS)

    assert_not email.locked?
  end

  test "attempts outside observation window reset before lockout" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    email.update!(
      otp_attempts_count: Email::MAX_OTP_ATTEMPTS - 1,
      otp_last_sent_at: (Email::OTP_ATTEMPT_WINDOW + 1.second).ago,
    )

    email.increment_attempts!

    assert_equal 1, email.reload.otp_attempts_count
    assert_not email.locked?
  end

  test "clear_otp resets attempts and locked_at" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    Email::MAX_OTP_ATTEMPTS.times { email.increment_attempts! }
    email.update!(locked_at: 1.minute.from_now)

    email.clear_otp

    assert_equal 0, email.otp_attempts_count
    assert_not email.locked?
  end

  test "increment_attempts! is thread-safe under concurrent access" do
    email = create_email(address: "concurrent@example.com", confirm_policy: true)

    futures =
      10.times.map do
        Concurrent::Promises.future do
          10.times do
            ActiveRecord::Base.connection_pool.with_connection do
              # Use a fresh instance to better simulate concurrent requests
              ClientEmail.find(email.id).increment_attempts!
            end
          end
        end
      end

    Concurrent::Promises.zip(*futures).value!

    assert_equal Email::MAX_OTP_ATTEMPTS, email.reload.otp_attempts_count
    assert_predicate email, :locked?
  end

  # OTP method tests

  test "store_otp stores OTP configuration" do
    email = create_email(address: "otp@example.com", confirm_policy: true)
    otp_key = "secret_key_123"
    otp_counter = 10
    expires_at = 1.hour.from_now.to_i

    email.store_otp(otp_key, otp_counter, expires_at)

    assert_equal otp_key, email.otp_private_key
    assert_equal otp_counter.to_s, email.otp_counter.to_s
    assert_equal 0, email.otp_attempts_count
    assert_not email.locked?
  end

  test "get_otp returns OTP configuration when valid" do
    email = create_email(address: "otp2@example.com", confirm_policy: true)
    otp_key = "secret_key_456"
    otp_counter = 20
    expires_at = 1.hour.from_now.to_i

    email.store_otp(otp_key, otp_counter, expires_at)
    otp_data = email.get_otp

    assert_not_nil otp_data
    assert_equal otp_key, otp_data[:otp_private_key]
    assert_equal otp_counter, otp_data[:otp_counter]
  end

  test "get_otp returns nil when OTP is expired" do
    email = create_email(address: "otp3@example.com", confirm_policy: true)
    otp_key = "secret_key_789"
    otp_counter = 30
    expires_at = 1.hour.ago.to_i # Already expired

    email.store_otp(otp_key, otp_counter, expires_at)
    otp_data = email.get_otp

    assert_nil otp_data
  end

  test "get_otp returns nil when OTP is locked" do
    email = create_email(address: "otp4@example.com", confirm_policy: true)
    otp_key = "secret_key_101"
    otp_counter = 40
    expires_at = 1.hour.from_now.to_i

    email.store_otp(otp_key, otp_counter, expires_at)
    email.update!(locked_at: 1.minute.from_now)

    otp_data = email.get_otp

    assert_nil otp_data
  end

  test "get_otp returns nil when otp_private_key is blank" do
    email = create_email(address: "otp5@example.com", confirm_policy: true)

    otp_data = email.get_otp

    assert_nil otp_data
  end

  test "otp_expired? returns true when otp_expires_at is nil" do
    email = create_email(address: "otp6@example.com", confirm_policy: true)

    assert_predicate email, :otp_expired?
  end

  test "otp_expired? returns true when otp_expires_at is in the past" do
    email = create_email(address: "otp7@example.com", confirm_policy: true)
    email.update!(otp_expires_at: 1.hour.ago)

    assert_predicate email, :otp_expired?
  end

  test "otp_expired? returns false when otp_expires_at is in the future" do
    email = create_email(address: "otp8@example.com", confirm_policy: true)
    email.update!(otp_expires_at: 1.hour.from_now)

    assert_not email.otp_expired?
  end

  test "otp_active? returns true when OTP is not expired and not locked" do
    email = create_email(address: "otp9@example.com", confirm_policy: true)
    email.update!(otp_expires_at: 1.hour.from_now, locked_at: -Float::INFINITY) # Use sentinel

    assert_predicate email, :otp_active?
  end

  test "otp_active? returns false when OTP is expired" do
    email = create_email(address: "otp10@example.com", confirm_policy: true)
    email.update!(otp_expires_at: 1.hour.ago)

    assert_not email.otp_active?
  end

  test "otp_active? returns false when OTP is locked" do
    email = create_email(address: "otp11@example.com", confirm_policy: true)
    email.update!(otp_expires_at: 1.hour.from_now, locked_at: 1.minute.from_now)

    assert_not email.otp_active?
  end

  test "clear_otp clears all OTP data" do
    email = create_email(address: "otp12@example.com", confirm_policy: true)
    email.store_otp("key", 50, 1.hour.from_now.to_i)
    email.update!(locked_at: 1.minute.from_now, otp_attempts_count: 2)

    email.clear_otp

    # clear_otp resets counter, expiry, attempts, and lock state but intentionally
    # keeps otp_private_key (the column is NOT NULL, and the key is safe to reuse).
    assert_equal "key", email.otp_private_key
    assert_equal "0", email.otp_counter
    # otp_expires_at is reset to the "-infinity" sentinel ("never valid").
    assert(
      email.otp_expires_at.is_a?(Time) ||
      email.otp_expires_at.to_s == "-infinity" ||
      (email.otp_expires_at.is_a?(Float) && email.otp_expires_at == -Float::INFINITY),
    )
    assert_equal 0, email.otp_attempts_count
    assert_not email.locked?
  end

  test "validates pass_code presence when pass_code is not nil" do
    email = build_email(address: nil, pass_code: nil)

    assert_not email.valid?
  end

  test "validates pass_code length exactly 6" do
    email = build_email(address: "test@example.com", pass_code: "12345")

    assert_not email.valid?

    email = build_email(address: "test@example.com", pass_code: "1234567")

    assert_not email.valid?
  end

  test "validates pass_code is integer" do
    email = build_email(address: "test@example.com", pass_code: "12345a")

    assert_not email.valid?
  end

  test "otp_cooldown_active? and remaining" do
    email = create_email(address: "cooldown@example.com", confirm_policy: true)

    # Not active initially
    assert_not email.otp_cooldown_active?
    assert_equal 0, email.otp_cooldown_remaining

    # Active after send
    email.update!(otp_last_sent_at: Time.current)

    assert_predicate email, :otp_cooldown_active?
    assert_operator email.otp_cooldown_remaining, :>, 0

    # Not active after cooldown period
    email.update!(otp_last_sent_at: 2.minutes.ago)

    assert_not email.otp_cooldown_active?
    assert_equal 0, email.otp_cooldown_remaining

    # Handles sentinel -infinity
    email.update!(otp_last_sent_at: -Float::INFINITY)

    assert_not email.otp_cooldown_active?
  end

  test "reregistration_window_active? uses independent ten second window" do
    email = create_email(address: "rereg-window@example.com", confirm_policy: true)

    email.update!(otp_last_sent_at: 9.seconds.ago)

    assert_predicate email, :reregistration_window_active?

    email.update!(otp_last_sent_at: 11.seconds.ago)

    assert_not email.reregistration_window_active?

    email.update!(otp_last_sent_at: -Float::INFINITY)

    assert_not email.reregistration_window_active?
  end

  test "find_by_address returns the matching email or nil" do
    created = create_email(address: "findable@example.com", confirm_policy: true)

    assert_equal created, ClientEmail.public_send(:find_by_address, "findable@example.com")
    assert_nil ClientEmail.public_send(:find_by_address, "")
    assert_nil ClientEmail.public_send(:find_by_address, "missing@example.com")
  end
end
