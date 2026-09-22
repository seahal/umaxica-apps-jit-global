# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_emails
# Database name: app_principal
#
#  id                        :bigint           not null, primary key
#  address                   :string           default(""), not null
#  address_digest            :string
#  discard_at              :datetime         default(Infinity), not null
#  locked_at                 :datetime         default(Infinity), not null
#  notifiable                :boolean          default(TRUE), not null
#  otp_attempts_count        :integer          default(0), not null
#  otp_counter               :text             default(""), not null
#  otp_expires_at            :datetime         default(-Infinity), not null
#  otp_last_sent_at          :datetime         default(-Infinity), not null
#  otp_private_key           :string           default(""), not null
#  promotional               :boolean          default(TRUE), not null
#  purge_eligible_at                 :datetime         default(Infinity), not null
#  subscribable              :boolean          default(TRUE), not null
#  undeletable               :boolean          default(FALSE), not null
#  verification_token_digest :binary
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  public_id                 :string(21)       not null
#  user_email_status_id      :bigint           default(1), not null
#  user_id                   :bigint           not null
#
# Indexes
#
#  index_client_emails_on_active_address_digest  (address_digest) UNIQUE WHERE ((address_digest IS NOT NULL) AND (user_email_status_id <> 4))
#  index_client_emails_on_discard_at           (discard_at)
#  index_client_emails_on_otp_last_sent_at       (otp_last_sent_at)
#  index_client_emails_on_public_id              (public_id) UNIQUE
#  index_client_emails_on_purge_eligible_at              (purge_eligible_at)
#  index_client_emails_on_user_email_status_id   (user_email_status_id)
#  index_client_emails_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_email_status_id => client_email_statuses.id)
#  fk_rails_...  (user_id => clients.id)
#
require "test_helper"

class ClientEmailTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_email_statuses
  uses_transaction \
    :test_concurrent_creates_for_same_normalized_address_commit_at_most_one_active_email,
    :test_concurrent_creates_for_case_and_whitespace_equivalent_address_commit_at_most_one_active_email,
    :test_active_delete_transaction_versus_same_address_create_keeps_active_email_invariant,
    :test_rolled_back_concurrent_email_conflict_leaves_one_active_email,
    :test_concurrent_email_create_while_competing_insert_rolls_back_does_not_commit_duplicates

  setup do
    ClientEmail.delete_all
    @user = clients(:none_user)
    @identifier_race_digests = []
    @identifier_race_client_ids = []
    @valid_attributes = {
      address: "test@example.com",
      confirm_policy: true,
      user: @user,
    }.freeze
  end

  teardown do
    next if @identifier_race_digests.blank?

    ClientEmail.where(address_digest: @identifier_race_digests).delete_all
    Client.where(id: @identifier_race_client_ids).delete_all if @identifier_race_client_ids.present?
  end

  test "should inherit from AppPrincipalRecord" do
    assert_operator ClientEmail, :<, AppPrincipalRecord
  end

  test "should include Email concern" do
    assert_includes ClientEmail.included_modules, Email
  end

  test "should be valid with valid email and policy confirmation" do
    user_email = ClientEmail.new(@valid_attributes)

    assert_predicate user_email, :valid?
  end

  test "should require valid email format" do
    user_email = ClientEmail.new(@valid_attributes.merge(address: "invalid-email"))

    assert_not user_email.valid?
    assert_not_empty user_email.errors[:address]
  end

  test "should require email presence" do
    user_email = ClientEmail.new(@valid_attributes.except(:address))
    user_email.address = ""

    assert_not user_email.valid?
    assert_not_empty user_email.errors[:address]
  end

  test "should require policy confirmation" do
    user_email = ClientEmail.new(@valid_attributes.merge(confirm_policy: false))

    assert_not user_email.valid?
    assert_not_empty user_email.errors[:confirm_policy]
  end

  test "should require unique email addresses" do
    ClientEmail.create!(@valid_attributes)
    duplicate_email = ClientEmail.new(@valid_attributes)

    assert_not duplicate_email.valid?
    assert_not_empty duplicate_email.errors[:address]
  end

  test "deleted sign-up email does not reserve address forever" do
    ClientEmail.create!(
      @valid_attributes.merge(
        address: "cancelled-retry@example.com",
        user_email_status_id: ClientEmailStatus::DELETED,
        discard_at: 1.minute.ago,
        purge_eligible_at: 29.minutes.from_now,
      ),
    )
    retry_email = ClientEmail.new(@valid_attributes.merge(address: "cancelled-retry@example.com"))

    assert_predicate retry_email, :valid?
    assert_difference "ClientEmail.count", 1 do
      retry_email.save!
    end
  end

  test "sets address_digest from normalized input" do
    user_email = ClientEmail.create!(
      raw_address: "TEST@EXAMPLE.COM",
      confirm_policy: true,
      user: @user,
    )

    expected = IdentifierBlindIndex.bidx_for_email("test@example.com")

    assert_equal expected, user_email.address_digest
  end

  test "normalizes address before deriving digest" do
    user_email = ClientEmail.create!(
      raw_address: "  Digest-Order@EXAMPLE.COM  ",
      confirm_policy: true,
      user: @user,
    )

    assert_equal "digest-order@example.com", user_email.address
    assert_equal IdentifierBlindIndex.bidx_for_email("digest-order@example.com"), user_email.address_digest
  end

  test "initializes otp defaults for new records" do
    user_email = ClientEmail.new(@valid_attributes)

    assert_equal "0", user_email.otp_counter
    assert_not_empty user_email.otp_private_key
    assert_equal 0, user_email.otp_attempts_count
  end

  test "finds by normalized address" do
    user_email = ClientEmail.create!(
      raw_address: "user-find@example.com",
      confirm_policy: true,
      user: @user,
    )

    assert_equal user_email,
                 ClientEmail.find_by(address_digest: IdentifierBlindIndex.bidx_for_email("USER-FIND@example.com"))
    assert_nil ClientEmail.find_by(address_digest: IdentifierBlindIndex.bidx_for_email(""))
  end

  test "should downcase email address before saving" do
    user_email = ClientEmail.new(@valid_attributes.merge(address: "TEST@EXAMPLE.COM"))
    user_email.save!

    assert_equal "test@example.com", user_email.address
  end

  test "should be valid when pass_code is present and address is valid" do
    user_email = ClientEmail.new(address: "test@example.com", pass_code: "123456", user: @user)

    assert_predicate user_email, :valid?
    assert_not user_email.errors[:confirm_policy].any?
  end

  test "should encrypt email address" do
    user_email = ClientEmail.create!(@valid_attributes)
    query = "SELECT address FROM #{ClientEmail.table_name} WHERE id = '#{user_email.id}'"
    raw_data = ClientEmail.connection.execute(query).first
    assert_not_equal @valid_attributes[:address], raw_data["address"] if raw_data
  end

  test "blocks destroying an undeletable email" do
    user_email = ClientEmail.create!(@valid_attributes.merge(undeletable: true))

    assert_raises(ActiveRecord::RecordNotDestroyed) { user_email.destroy! }
    assert_includes user_email.errors[:base], "cannot delete a protected email address"
    assert_predicate user_email.reload, :undeletable?
  end

  test "enforces maximum emails per user" do
    user = clients(:one)
    Prosopite.pause do
      ClientEmail::MAX_EMAILS_PER_USER.times do |i|
        ClientEmail.create!(
          address: "user#{i}@example.com",
          confirm_policy: true,
          user: user,
        )
      end
    end

    extra_email = ClientEmail.new(
      address: "overflow@example.com",
      confirm_policy: true,
      user: user,
    )

    assert_not extra_email.valid?
    assert_includes extra_email.errors[:base], "exceeds maximum emails per user (#{ClientEmail::MAX_EMAILS_PER_USER})"
  end

  test "verification token generation and verification" do
    user_email = ClientEmail.create!(@valid_attributes)

    token = user_email.generate_verification_token

    assert_not_nil token
    assert_not_nil user_email.verification_token_digest

    assert user_email.verify_verification_token(token)
    assert_not user_email.verify_verification_token("wrong-token")
    assert_not user_email.verify_verification_token("")
  end

  test "subscription preferences are locked until the email is verified" do
    locked_email = ClientEmail.new(@valid_attributes.merge(user_email_status_id: ClientEmailStatus::UNVERIFIED))
    unlocked_email = ClientEmail.new(@valid_attributes.merge(user_email_status_id: ClientEmailStatus::VERIFIED))

    assert_predicate locked_email, :subscription_preferences_locked?
    assert_not unlocked_email.subscription_preferences_locked?
  end

  test "to_param returns public_id" do
    user_email = ClientEmail.create!(@valid_attributes)

    assert_equal user_email.public_id, user_email.to_param
  end

  test "otp is active just before expiry and expired exactly at expiry" do
    user_email = ClientEmail.create!(@valid_attributes.merge(address: "otp-expiry@example.com"))
    now = Time.zone.parse("2026-05-25 12:00:00")

    ClientEmail.stub(:database_now, now) do
      user_email.store_otp("SECRET", "2", (now + 30.seconds).to_i)
    end

    ClientEmail.stub(:database_now, now + 29.seconds) do
      assert_predicate user_email.reload, :otp_active?
      assert_not user_email.otp_expired?
    end

    ClientEmail.stub(:database_now, now + 30.seconds) do
      assert_predicate user_email.reload, :otp_expired?
      assert_not user_email.otp_active?
    end
  end

  test "fifth failed otp attempt locks but fourth does not" do
    user_email = ClientEmail.create!(@valid_attributes.merge(address: "otp-lock@example.com"))
    now = Time.zone.parse("2026-05-25 12:00:00")

    ClientEmail.stub(:database_now, now) do
      user_email.update!(otp_attempts_count: 3, otp_last_sent_at: now)
      user_email.increment_attempts!

      assert_equal 4, user_email.otp_attempts_count
      assert_not user_email.locked?

      user_email.increment_attempts!

      assert_equal 5, user_email.otp_attempts_count
      assert_predicate user_email, :locked?
      assert_in_delta (now + 15.minutes).to_i, user_email.locked_at.to_i, 1
    end
  end

  test "otp attempt window resets just after fifteen minutes" do
    user_email = ClientEmail.create!(@valid_attributes.merge(address: "otp-window@example.com"))
    now = Time.zone.parse("2026-05-25 12:00:00")

    ClientEmail.stub(:database_now, now) do
      user_email.update!(otp_attempts_count: 4, otp_last_sent_at: now - 15.minutes - 1.second)
      user_email.increment_attempts!

      assert_equal 1, user_email.otp_attempts_count
      assert_not user_email.locked?
    end
  end

  test "concurrent creates for same normalized address commit at most one active email" do
    address = "email-race-#{SecureRandom.hex(4)}@example.com"
    results = create_emails_concurrently(address, address)

    assert_identifier_race_protected(results, IdentifierBlindIndex.bidx_for_email(address))
  end

  test "concurrent creates for case and whitespace equivalent address commit at most one active email" do
    local = "email-equivalent-#{SecureRandom.hex(4)}"
    first = "  #{local}@EXAMPLE.COM  "
    second = "#{local}@example.com"
    results = create_emails_concurrently(first, second)

    assert_identifier_race_protected(results, IdentifierBlindIndex.bidx_for_email(second))
  end

  test "active delete transaction versus same address create keeps active email invariant" do
    address = "email-delete-race-#{SecureRandom.hex(4)}@example.com"
    track_email_race_address(address)
    existing = ClientEmail.create!(@valid_attributes.merge(address: address))

    ready = Queue.new
    release = Queue.new
    results = Queue.new
    updater =
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        ClientEmail.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ClientEmail.transaction do
            locked = ClientEmail.lock.find(existing.id)
            ready << true
            release.pop
            locked.update!(user_email_status_id: ClientEmailStatus::DELETED, discard_at: Time.current)
          end
          results << { status: :deleted }
        rescue StandardError => e
          results << { status: :error, error: "#{e.class}: #{e.message}" }
        end
      end
    creator =
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        ClientEmail.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ready.pop
          release << true
          create_email_record(address)
          results << { status: :created }
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::LockWaitTimeout => e
          results << { status: :conflict, error: "#{e.class}: #{e.message}" }
        rescue StandardError => e
          results << { status: :error, error: "#{e.class}: #{e.message}" }
        end
      end

    [updater, creator].each(&:join)
    race_results = 2.times.map { results.pop }

    assert race_results.none? { |result| result[:status] == :error }
    assert_operator active_email_digest_count(address), :<=, 1
  end

  test "rolled back concurrent email conflict leaves one active email" do
    address = "email-rollback-race-#{SecureRandom.hex(4)}@example.com"
    digest = IdentifierBlindIndex.bidx_for_email(address)
    track_email_race_address(address)

    ClientEmail.transaction do
      create_email_record(address)

      assert_equal 1, ClientEmail.where(address_digest: digest).count
      raise ActiveRecord::Rollback
    end

    assert_nothing_raised do
      create_email_record(address)
    end

    assert_operator ClientEmail.where(address_digest: digest).where.not(user_email_status_id: ClientEmailStatus::DELETED).count,
                    :<=,
                    1
  end

  test "concurrent email create while competing insert rolls back does not commit duplicates" do
    address = "email-rollback-concurrent-#{SecureRandom.hex(4)}@example.com"
    digest = IdentifierBlindIndex.bidx_for_email(address)
    track_email_race_address(address)
    ready = Queue.new
    release = Queue.new
    results = Queue.new

    holder =
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        ClientEmail.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ClientEmail.transaction do
            create_email_record(address)
            ready << true
            release.pop
            raise ActiveRecord::Rollback
          end
          results << { status: :rolled_back }
        rescue StandardError => e
          results << { status: :error, error: "#{e.class}: #{e.message}" }
        end
      end
    releaser =
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        ready.pop
        release << true
        results << { status: :released }
      rescue StandardError => e
        results << { status: :error, error: "#{e.class}: #{e.message}" }
      end

    [holder, releaser].each(&:join)
    race_results = 2.times.map { results.pop }

    assert race_results.none? { |result| result[:status] == :error }
    assert_nothing_raised do
      create_email_record(address)
    end
    assert_operator ClientEmail.where(address_digest: digest).where.not(user_email_status_id: ClientEmailStatus::DELETED).count,
                    :<=,
                    1
  end

  private

  def create_emails_concurrently(first_address, second_address)
    track_email_race_address(first_address)
    track_email_race_address(second_address)
    ready = Queue.new
    release = Queue.new
    results = Queue.new

    [first_address, second_address].map do |address|
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        ClientEmail.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ready << true
          release.pop
          record = create_email_record(address)
          results << { status: :created, id: record.id }
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::LockWaitTimeout => e
          results << { status: :conflict, error: "#{e.class}: #{e.message}" }
        rescue StandardError => e
          results << { status: :error, error: "#{e.class}: #{e.message}" }
        end
      end
    end.tap do |threads|
      2.times { ready.pop }
      2.times { release << true }
      threads.each(&:join)
    end

    2.times.map { results.pop }
  end

  def create_email_record(address)
    client = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @identifier_race_client_ids << client.id

    ClientEmail.create!(
      raw_address: address,
      confirm_policy: true,
      user: client,
    )
  end

  def track_email_race_address(address)
    @identifier_race_digests << IdentifierBlindIndex.bidx_for_email(address)
    @identifier_race_digests.uniq!
  end

  def configure_identifier_race_connection!(connection)
    connection.execute("SET lock_timeout = '2000ms'")
  end

  def assert_identifier_race_protected(results, digest)
    assert_equal 2, results.size
    assert results.none? { |result| result[:status] == :error }
    assert_equal 1, results.count { |result| result[:status] == :created }, results.inspect
    assert_equal 1, results.count { |result| result[:status] == :conflict }, results.inspect
    assert_operator ClientEmail.where(address_digest: digest).where.not(user_email_status_id: ClientEmailStatus::DELETED).count,
                    :<=,
                    1
  end

  def active_email_digest_count(address)
    ClientEmail
      .where(address_digest: IdentifierBlindIndex.bidx_for_email(address))
      .where.not(user_email_status_id: ClientEmailStatus::DELETED)
      .count
  end
end
