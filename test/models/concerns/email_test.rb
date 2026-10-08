# typed: false
# frozen_string_literal: true

require "test_helper"

# Test with ClientEmail which includes Email
class EmailTest < ActiveSupport::TestCase
  fixtures :clients, :operators, :client_statuses, :operator_statuses

  setup do
    @user = clients(:none_user)
    @otp_actor = Client.create!(status_id: ClientStatus::ACTIVE)
    @otp_token = ClientToken.create!(user: @otp_actor)
    @otp_token.rotate_refresh_token!
    @otp_email = ClientEmail.create!(user: @otp_actor, raw_address: "ceremony-model@example.test", confirm_policy: true)
    @otp_browser_nonce = SecureRandom.urlsafe_base64(32)
    issued = EmailCredentialRegistrationOtpIssuer.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, browser_nonce: @otp_browser_nonce,
    )
    @otp_transaction = issued.transaction
    @otp_code = issued.code
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

  test "durable Email ceremony stores a keyed verifier rather than a plaintext code or reconstructible secret" do
    raw = ClientEmailCeremonyTransaction.where(transaction_id: @otp_transaction.transaction_id).pick(:otp_verifier)

    assert_equal @otp_transaction.reload.otp_verifier, raw
    assert_not_equal @otp_code, raw
    assert_not_includes @otp_transaction.attributes.values, @otp_code
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

  test "effective Email bindings enforce address uniqueness case insensitively at finalization" do
    existing = ClientEmail.create!(user: @user, address: "test@example.com", confirm_policy: true).finalize_binding!
    duplicate = ClientEmail.create!(user: @user, address: "TEST@EXAMPLE.COM", confirm_policy: true)

    assert_equal existing.address_digest, duplicate.address_digest
    assert_predicate duplicate, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.finalize_binding! }
    assert_nil duplicate.reload.binding_finalized_at
    assert_predicate existing.reload, :binding_effective?
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

  test "attempts outside observation window are retained and still reach lockout" do
    email = create_email(address: "test@example.com", confirm_policy: true)
    email.update!(
      otp_attempts_count: Email::MAX_OTP_ATTEMPTS - 1,
      otp_last_sent_at: (Email::OTP_ATTEMPT_WINDOW + 1.second).ago,
    )

    email.increment_attempts!

    assert_equal Email::MAX_OTP_ATTEMPTS, email.reload.otp_attempts_count
    assert_predicate email, :locked?
  end

  test "fresh Email proof consumption after finite lockout expiry resets failures and lock state" do
    Email::MAX_OTP_ATTEMPTS.times { @otp_email.increment_attempts! }
    deadline = ClientEmail.database_now + 1.minute
    @otp_email.update!(locked_at: deadline)
    verified =
      ClientEmail.stub(:database_now, deadline + Rational(1, 1_000_000)) do
        EmailCredentialRegistrationOtpVerificationCommitter.call(
          actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
          browser_nonce: @otp_browser_nonce, code: @otp_code,
        )
      end

    assert_predicate verified, :success?
    assert_equal 0, @otp_email.reload.otp_attempts_count
    assert_not @otp_email.locked?
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

  test "own Email issuance stores keyed verifier generation and bounded expiry without resetting failures" do
    assert_match(/\A[0-9]{6}\z/, @otp_code)
    assert_predicate @otp_transaction.otp_verifier, :present?
    assert_predicate @otp_transaction.otp_generation, :present?
    assert_equal @otp_email.public_id, @otp_transaction.email_candidate_ref
    assert_operator @otp_transaction.otp_expires_at, :<=, @otp_transaction.expires_at
    assert_equal 0, @otp_email.otp_attempts_count
    assert_not @otp_email.locked?
  end

  test "own Email form admits the original current typed ceremony proof" do
    assert EmailCredentialRegistrationOtpFormQuery.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
      browser_nonce: @otp_browser_nonce,
    )
    assert_equal @otp_actor.public_id, @otp_transaction.actor_ref
    assert_equal @otp_email.public_id, @otp_transaction.email_candidate_ref
  end

  test "own Email form refuses expired proof at the exact OTP deadline" do
    ClientEmailCeremonyTransaction.stub(:database_now, @otp_transaction.otp_expires_at) do
      assert_not EmailCredentialRegistrationOtpFormQuery.call(
        actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
        browser_nonce: @otp_browser_nonce,
      )
    end
  end

  test "own Email verifier refuses a locked candidate without consuming proof" do
    @otp_email.update!(locked_at: 1.minute.from_now)
    refused = EmailCredentialRegistrationOtpVerificationCommitter.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
      browser_nonce: @otp_browser_nonce, code: @otp_code,
    )

    assert_equal :locked, refused.status
    assert_nil @otp_transaction.reload.otp_consumed_at
  end

  test "own Email form refuses a missing active verifier" do
    @otp_transaction.update!(otp_verifier: nil)

    assert_not EmailCredentialRegistrationOtpFormQuery.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
      browser_nonce: @otp_browser_nonce,
    )
  end

  test "unissued Email ceremony has nil expiry and cannot be delivered because issued nil expiry is forbidden" do
    unissued = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: @otp_actor.public_id, session_ref: "unissued-email-model-browser", operation: "registration",
      email_candidate_ref: @otp_email.public_id, normalized_email_digest: @otp_email.address_digest,
    )

    assert_nil unissued.otp_expires_at
    assert_not unissued.email_otp_deliverable?(generation: nil, at: ClientEmailCeremonyTransaction.database_now)
  end

  test "Email ceremony proof is expired immediately above its finite expiry" do
    assert_not @otp_transaction.email_otp_deliverable?(
      generation: @otp_transaction.otp_generation, at: @otp_transaction.otp_expires_at + Rational(1, 1_000_000),
    )
  end

  test "Email ceremony proof is active immediately below its finite expiry" do
    assert @otp_transaction.email_otp_deliverable?(
      generation: @otp_transaction.otp_generation, at: @otp_transaction.otp_expires_at - Rational(1, 1_000_000),
    )
  end

  test "own Email verifier consumes current unlocked proof exactly once" do
    verified = EmailCredentialRegistrationOtpVerificationCommitter.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
      browser_nonce: @otp_browser_nonce, code: @otp_code,
    )
    retained = EmailCredentialRegistrationOtpVerificationCommitter.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
      browser_nonce: @otp_browser_nonce, code: @otp_code,
    )

    assert_predicate verified, :success?
    assert_not retained.success?
    assert_predicate retained, :verified_evidence?
  end

  test "own Email verification at exact OTP expiry refuses consumption without adding failures" do
    refused =
      ClientEmailCeremonyTransaction.stub(:database_now, @otp_transaction.otp_expires_at) do
        EmailCredentialRegistrationOtpVerificationCommitter.call(
          actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
          browser_nonce: @otp_browser_nonce, code: @otp_code,
        )
      end

    assert_not refused.success?
    assert_nil @otp_transaction.reload.otp_consumed_at
    assert_equal 0, @otp_email.reload.otp_attempts_count
  end

  test "own Email issuance refuses active lockout without replacing proof or resetting failures" do
    @otp_email.update!(locked_at: 1.minute.from_now, otp_attempts_count: 2)
    facts = @otp_transaction.attributes.slice("otp_generation", "otp_verifier", "otp_expires_at")
    refused = EmailCredentialRegistrationOtpIssuer.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, browser_nonce: @otp_browser_nonce,
    )

    assert_equal :locked, refused.status
    assert_nil refused.code
    assert_equal facts, @otp_transaction.reload.attributes.slice(*facts.keys)
    assert_equal 2, @otp_email.reload.otp_attempts_count
    assert_predicate @otp_email, :locked?
  end

  test "fresh Email consumption clears active verifier and failures while retaining a bounded receipt" do
    @otp_email.update!(otp_attempts_count: 2)
    generation = @otp_transaction.otp_generation
    verified = EmailCredentialRegistrationOtpVerificationCommitter.call(
      actor: @otp_actor, token: @otp_token, email: @otp_email, transaction: @otp_transaction,
      browser_nonce: @otp_browser_nonce, code: @otp_code,
    )

    assert_predicate verified, :success?
    assert_nil @otp_transaction.reload.otp_verifier
    assert_equal generation, @otp_transaction.otp_generation
    assert_predicate @otp_transaction.otp_receipt_verifier, :present?
    assert_equal @otp_transaction.otp_consumed_at + 60.seconds, @otp_transaction.otp_result_expires_at
    assert_equal 0, @otp_email.reload.otp_attempts_count
    assert_not @otp_email.locked?
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
