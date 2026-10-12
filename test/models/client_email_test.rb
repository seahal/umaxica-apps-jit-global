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
#  otp_last_sent_at          :datetime         default(-Infinity), not null
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
    ClientAuthorityLock.where(client_id: @identifier_race_client_ids).delete_all if @identifier_race_client_ids.present?
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

  test "effective email addresses are unique at finalization" do
    ClientEmail.create!(@valid_attributes).finalize_binding!
    duplicate_email = ClientEmail.create!(@valid_attributes)

    assert_predicate duplicate_email, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate_email.finalize_binding! }
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

    expected = IdentifierBlindIndex.bidx_for_email("test@example.com", realm: :app)

    assert_equal expected, user_email.address_digest
  end

  test "normalizes address before deriving digest" do
    user_email = ClientEmail.create!(
      raw_address: "  Digest-Order@EXAMPLE.COM  ",
      confirm_policy: true,
      user: @user,
    )

    assert_equal "digest-order@example.com", user_email.address
    assert_equal IdentifierBlindIndex.bidx_for_email("digest-order@example.com", realm: :app), user_email.address_digest
  end

  test "new Email candidates initialize failures while only a typed ceremony owns OTP proof defaults" do
    user_email = ClientEmail.new(@valid_attributes)
    ceremony = ClientEmailCeremonyTransaction.new

    assert_nil ceremony.otp_generation
    assert_nil ceremony.otp_verifier
    assert_nil ceremony.otp_expires_at
    assert_equal 0, user_email.otp_attempts_count
  end

  test "finds by normalized address" do
    user_email = ClientEmail.create!(
      raw_address: "user-find@example.com",
      confirm_policy: true,
      user: @user,
    )

    assert_equal user_email,
                 ClientEmail.find_by(
                   address_digest: IdentifierBlindIndex.bidx_for_email("USER-FIND@example.com", realm: :app),
                 )
    assert_nil ClientEmail.find_by(address_digest: IdentifierBlindIndex.bidx_for_email("", realm: :app))
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

  test "pending email rows do not reserve capacity and the database permits only one effective binding" do
    owner = Client.create!

    assert_equal 0, owner.client_emails.effective_binding.count
    candidates =
      5.times.map do |index|
        ClientEmail.create!(
          user: owner, address: "contact-limit-#{SecureRandom.hex(4)}-#{index}@example.test",
          confirm_policy: "1",
        )
      end

    assert candidates.none?(&:binding_effective?)
    first, second = candidates
    first.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
    assert_difference -> { ClientEmail.effective_binding.where(user_id: owner.id).count }, 1 do
      first.finalize_binding!
    end
    second.update!(user_email_status_id: ClientEmailStatus::VERIFIED)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientEmail.transaction(requires_new: true) { second.finalize_binding! }
    end
    assert_predicate first.reload, :binding_effective?
    assert_not_predicate second.reload, :binding_effective?
    assert_equal 1, ClientEmail.effective_binding.where(user_id: owner.id).count
    first.release_binding!
    second.finalize_binding!

    assert_predicate first.reload, :binding_released?
    assert_predicate second.reload, :binding_effective?
    assert_equal 1, ClientEmail.effective_binding.where(user_id: owner.id).count
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

  test "Email ceremony OTP is active immediately below but not at or above its finite expiry" do
    user_email = ClientEmail.create!(@valid_attributes.merge(address: "otp-expiry@example.com"))
    now = ClientEmailCeremonyTransaction.database_now
    ceremony = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: @user.public_id, session_ref: "client-email-model-browser", operation: "registration",
      email_candidate_ref: user_email.public_id, normalized_email_digest: user_email.address_digest,
      now: now, expires_at: now + 30.seconds,
    )
    ClientEmailCeremonyTransaction.stub(:database_now, now) do
      ceremony.issue_email_otp!(purpose: "credential_registration")
    end

    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      assert_equal offset.negative?, ceremony.reload.email_otp_deliverable?(
        generation: ceremony.otp_generation, at: now + 30.seconds + offset,
      )
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

  [-1, 0, 1].each do |microseconds|
    test "email failures survive fifteen minute issuance age boundary #{microseconds} microseconds" do
      user_email = ClientEmail.create!(@valid_attributes.merge(address: "otp-window@example.com"))
      now = Time.zone.parse("2026-05-25 12:00:00")

      ClientEmail.stub(:database_now, now) do
        user_email.update!(
          otp_attempts_count: EmailOtpPolicy::MAX_OTP_ATTEMPTS - 1,
          otp_last_sent_at: now - EmailOtpPolicy::OTP_ATTEMPT_WINDOW - Rational(microseconds, 1_000_000),
        )
        user_email.increment_attempts!

        assert_equal EmailOtpPolicy::MAX_OTP_ATTEMPTS, user_email.otp_attempts_count
        assert_predicate user_email, :locked?
      end
    end
  end

  test "concurrent creates for same normalized address commit at most one active email" do
    address = "email-race-#{SecureRandom.hex(4)}@example.com"
    results = create_emails_concurrently(address, address)

    begin
      fv5021 = results
      fv5019 = IdentifierBlindIndex.bidx_for_email(
        address,
        realm: :app,
      )

      assert_equal 2, fv5021.size
      assert fv5021.none? { |fv5020|
        fv5020[:status] == :error
      }
      assert_equal 2, fv5021.count { |fv5020|
        fv5020[:status] == :created
      }, fv5021.inspect
      assert_empty fv5021.select { |fv5020|
        fv5020[:status] == :conflict
      }
      assert_equal 2,
                   ClientEmail.where(address_digest: fv5019).where(binding_finalized_at: nil).count
    end
  end

  test "concurrent creates for case and whitespace equivalent address commit at most one active email" do
    local = "email-equivalent-#{SecureRandom.hex(4)}"
    first = "  #{local}@EXAMPLE.COM  "
    second = "#{local}@example.com"
    results = create_emails_concurrently(first, second)

    begin
      fv5018 = results
      fv5016 = IdentifierBlindIndex.bidx_for_email(
        second,
        realm: :app,
      )

      assert_equal 2, fv5018.size
      assert fv5018.none? { |fv5017|
        fv5017[:status] == :error
      }
      assert_equal 2, fv5018.count { |fv5017|
        fv5017[:status] == :created
      }, fv5018.inspect
      assert_empty fv5018.select { |fv5017|
        fv5017[:status] == :conflict
      }
      assert_equal 2,
                   ClientEmail.where(address_digest: fv5016).where(binding_finalized_at: nil).count
    end
  end

  test "concurrent finalization for one destination leaves one effective email binding" do
    address = "email-finalize-destination-#{SecureRandom.hex(4)}@example.com"
    first = create_email_record(address)
    second = create_email_record(address)

    results =
      begin
        fv5015 = first
        fv5014 = second
        track_email_race_address(fv5015.address)
        track_email_race_address(fv5014.address)
        fv5011 = Queue.new
        fv5010 = Queue.new
        fv5008 = Queue.new
        ActiveRecord::Base.connection_handler.clear_active_connections!

        fv5009 =
          [fv5015.id, fv5014.id].map do |fv5012|
            Thread.new do
              ClientEmail.connection_pool.with_connection do |fv5013|
                configure_identifier_race_connection!(fv5013)
                fv5011 << true
                fv5010.pop
                ClientEmail.find(fv5012).finalize_binding!
                fv5008 << { status: :finalized }
              rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::LockWaitTimeout => e
                fv5008 << {
                  status: :conflict,
                  error: "#{e.class}: #{e.message}",
                }
              rescue StandardError => e
                fv5008 << {
                  status: :error,
                  error: "#{e.class}: #{e.message}",
                }
              end
            end
          end
        2.times { fv5011.pop }
        2.times { fv5010 << true }
        fv5009.each(&:join)
        2.times.map { fv5008.pop }
      end

    assert_equal 1, results.count { |result| result[:status] == :finalized }, results.inspect
    assert_equal 1, results.count { |result| result[:status] == :conflict }, results.inspect
    assert_equal 1, ClientEmail.effective_binding.where(address_digest: first.address_digest).count
  end

  test "concurrent finalization for one client leaves one effective email binding" do
    first = ClientEmail.create!(@valid_attributes.merge(address: "owner-first-#{SecureRandom.hex(4)}@example.com"))
    second = ClientEmail.create!(@valid_attributes.merge(address: "owner-second-#{SecureRandom.hex(4)}@example.com"))

    results =
      begin
        fv5007 = first
        fv5006 = second
        track_email_race_address(fv5007.address)
        track_email_race_address(fv5006.address)
        fv5003 = Queue.new
        fv5002 = Queue.new
        fv5000 = Queue.new
        ActiveRecord::Base.connection_handler.clear_active_connections!

        fv5001 =
          [fv5007.id, fv5006.id].map do |fv5004|
            Thread.new do
              ClientEmail.connection_pool.with_connection do |fv5005|
                configure_identifier_race_connection!(fv5005)
                fv5003 << true
                fv5002.pop
                ClientEmail.find(fv5004).finalize_binding!
                fv5000 << { status: :finalized }
              rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::LockWaitTimeout => e
                fv5000 << {
                  status: :conflict,
                  error: "#{e.class}: #{e.message}",
                }
              rescue StandardError => e
                fv5000 << {
                  status: :error,
                  error: "#{e.class}: #{e.message}",
                }
              end
            end
          end
        2.times { fv5003.pop }
        2.times { fv5002 << true }
        fv5001.each(&:join)
        2.times.map { fv5000.pop }
      end

    assert_equal 1, results.count { |result| result[:status] == :finalized }, results.inspect
    assert_equal 1, results.count { |result| result[:status] == :conflict }, results.inspect
    assert_equal 1, ClientEmail.effective_binding.where(user_id: @user.id).count
  end

  test "released email binding can be reattached without reactivating its history" do
    original = ClientEmail.create!(@valid_attributes).finalize_binding!
    original.release_binding!
    replacement = ClientEmail.create!(@valid_attributes.merge(address: original.address))

    replacement.finalize_binding!

    assert_not_predicate original.reload, :binding_effective?
    assert_predicate replacement.reload, :binding_effective?
  end

  test "active delete transaction versus same address create keeps active email invariant" do
    address = "email-delete-race-#{SecureRandom.hex(4)}@example.com"
    track_email_race_address(address)
    existing = ClientEmail.create!(@valid_attributes.merge(address: address))

    ready = Queue.new
    release = Queue.new
    results = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    updater =
      Thread.new do
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
      Thread.new do
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
    digest = IdentifierBlindIndex.bidx_for_email(address, realm: :app)
    track_email_race_address(address)

    ClientEmail.transaction do
      create_email_record(address)

      assert_equal 1, ClientEmail.where(address_digest: digest).count
      raise ActiveRecord::Rollback
    end

    assert_nothing_raised do
      create_email_record(address)
    end

    assert_operator ClientEmail.effective_binding.where(address_digest: digest).count, :<=, 1
  end

  test "concurrent email create while competing insert rolls back does not commit duplicates" do
    address = "email-rollback-concurrent-#{SecureRandom.hex(4)}@example.com"
    digest = IdentifierBlindIndex.bidx_for_email(address, realm: :app)
    track_email_race_address(address)
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    holder =
      Thread.new do
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
      Thread.new do
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
    assert_operator ClientEmail.effective_binding.where(address_digest: digest).count, :<=, 1
  end

  private

  def create_emails_concurrently(first_address, second_address)
    track_email_race_address(first_address)
    track_email_race_address(second_address)
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    [first_address, second_address].map do |address|
      Thread.new do
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
    @identifier_race_digests << IdentifierBlindIndex.bidx_for_email(address, realm: :app)
    @identifier_race_digests.uniq!
  end

  def configure_identifier_race_connection!(connection)
    connection.execute("SET lock_timeout = '2000ms'")
  end

  def active_email_digest_count(address)
    ClientEmail.effective_binding.where(address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app)).count
  end
end
