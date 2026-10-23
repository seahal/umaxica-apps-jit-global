# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_telephones
# Database name: app_principal
#
#  id                                :bigint           not null, primary key
#  discard_at                      :datetime         default(Infinity), not null
#  locked_at                         :datetime         default(-Infinity), not null
#  number                            :string           default(""), not null
#  number_digest                     :string
#  otp_attempts_count                :integer          default(0), not null
#  otp_last_sent_at                  :datetime
#  purge_eligible_at                         :datetime         default(Infinity), not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  public_id                         :string(21)       not null
#  user_id                           :bigint           not null
#  user_identity_telephone_status_id :bigint           default(2), not null
#
# Indexes
#
#  index_client_telephones_on_active_number_digest               (number_digest) UNIQUE WHERE ((number_digest IS NOT NULL) AND (user_identity_telephone_status_id <> 4))
#  index_client_telephones_on_discard_at                       (discard_at)
#  index_client_telephones_on_public_id                          (public_id) UNIQUE
#  index_client_telephones_on_purge_eligible_at                          (purge_eligible_at)
#  index_client_telephones_on_user_id                            (user_id)
#  index_client_telephones_on_user_identity_telephone_status_id  (user_identity_telephone_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => clients.id)
#  fk_rails_...  (user_identity_telephone_status_id => client_telephone_statuses.id)
#

require "test_helper"

class ClientTelephoneTest < ActiveSupport::TestCase
  fixtures :clients, :client_statuses, :client_visibilities, :client_security_modes,
           :client_mfa_statuses, :client_telephone_statuses
  uses_transaction \
    :test_concurrent_creates_for_same_normalized_number_commit_at_most_one_active_telephone,
    :test_concurrent_creates_for_equivalent_formatted_number_commit_at_most_one_active_telephone,
    :test_active_delete_transaction_versus_same_number_create_keeps_active_telephone_invariant,
    :test_rolled_back_concurrent_telephone_conflict_leaves_one_active_telephone,
    :test_concurrent_telephone_create_while_competing_insert_rolls_back_does_not_commit_duplicates

  setup do
    ClientTelephone.delete_all
    @user = clients(:none_user)
    @identifier_race_digests = []
    @identifier_race_client_ids = []
    @valid_attributes = {
      raw_number: "+1234567890",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    }.freeze
  end

  teardown do
    next if @identifier_race_digests.blank?

    ClientTelephone.where(number_digest: @identifier_race_digests).delete_all
    ClientAuthorityLock.where(client_id: @identifier_race_client_ids).delete_all if @identifier_race_client_ids.present?
    Client.where(id: @identifier_race_client_ids).delete_all if @identifier_race_client_ids.present?
  end

  # Basic model structure tests
  test "should inherit from AppPrincipalRecord" do
    assert_operator ClientTelephone, :<, AppPrincipalRecord
  end

  test "should include Telephone concern" do
    assert_includes ClientTelephone.included_modules, Telephone
  end

  test "to_param returns the public id" do
    phone = ClientTelephone.create!(@valid_attributes)

    assert_equal phone.public_id, phone.to_param
  end

  # Telephone concern validation tests
  test "should be valid with valid phone number and policy confirmations" do
    user_telephone = ClientTelephone.new(@valid_attributes)

    assert_predicate user_telephone, :valid?
  end

  test "should require valid phone number format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "invalid!@#"))

    I18n.with_locale(:ja) do
      assert_not user_telephone.valid?
      # Error message will be in the current locale (Japanese)
      assert_includes user_telephone.errors[:number], "はE.164形式（例：+819012345678）である必要があります"
    end
  end

  test "should accept phone number with country code" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+81-90-1234-5678"))

    assert_predicate user_telephone, :valid?
  end

  test "should accept phone number with parentheses" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+1 (555) 123-4567"))

    assert_predicate user_telephone, :valid?
  end

  test "should reject phone number that is too short" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "12"))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "should reject phone number that is too long" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+1234567890123456789012"))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "should require policy confirmation" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(confirm_policy: false))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:confirm_policy], :any?
  end

  test "should require MFA confirmation" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(confirm_using_mfa: false))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:confirm_using_mfa], :any?
  end

  test "should assign numeric id before creation" do
    user_telephone = ClientTelephone.new(@valid_attributes)

    assert_nil user_telephone.id
    user_telephone.save!

    assert_not_nil user_telephone.id
    assert_kind_of Integer, user_telephone.id
  end

  test "finds by normalized number" do
    user_telephone = ClientTelephone.create!(
      raw_number: "+1 (555) 765-4321",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    )

    assert_equal user_telephone,
                 ClientTelephone.find_by(
                   number_digest: IdentifierBlindIndex.bidx_for_telephone("+15557654321", realm: :app),
                 )
    assert_nil ClientTelephone.find_by(number_digest: IdentifierBlindIndex.bidx_for_telephone("", realm: :app))
  end

  test "deleted sign-up telephone does not reserve number forever" do
    ClientTelephone.create!(
      @valid_attributes.merge(
        raw_number: "+15557654322",
        user_telephone_status_id: ClientTelephoneStatus::DELETED,
        discard_at: 1.minute.ago,
        purge_eligible_at: 29.minutes.from_now,
      ),
    )
    retry_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+1 (555) 765-4322"))

    assert_predicate retry_telephone, :valid?
    assert_difference "ClientTelephone.count", 1 do
      retry_telephone.save!
    end
  end

  test "number is invalid when blank" do
    @valid_attributes.merge(raw_number: nil).then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "number is invalid when empty" do
    @valid_attributes.merge(raw_number: "").then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "number is invalid when only whitespace" do
    @valid_attributes.merge(raw_number: "   ").then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "number is invalid when too long (exceeding 255)" do
    @valid_attributes.merge(raw_number: "1" * 256).then do |attr|
      ClientTelephone.new(attr).tap do |m|
        assert_not m.valid?
        assert_not_empty m.errors[:number]
      end
    end
  end

  test "association: belongs_to user" do
    phone = ClientTelephone.create!(@valid_attributes)

    assert_equal @user, phone.user
  end

  test "association deletion: cleanup when user is destroyed" do
    phone = ClientTelephone.create!(@valid_attributes)
    @user.update!(discard_at: @user.created_at, purge_eligible_at: @user.created_at)
    @user.destroy!

    assert_raise(ActiveRecord::RecordNotFound) { phone.reload }
  end

  test "pending telephone rows do not reserve capacity and the database permits only one effective binding" do
    owner = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)

    assert_equal 0, owner.client_telephones.effective_binding.count
    candidates =
      5.times.map do |index|
        ClientTelephone.create!(user: owner, number: "+81903333000#{index}", confirm_policy: "1")
      end

    assert candidates.none?(&:binding_effective?)
    first, second = candidates
    first.update!(user_telephone_status_id: ClientTelephoneStatus::VERIFIED)
    assert_difference -> { ClientTelephone.effective_binding.where(user_id: owner.id).count }, 1 do
      first.finalize_binding!
    end
    second.update!(user_telephone_status_id: ClientTelephoneStatus::VERIFIED)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientTelephone.transaction(requires_new: true) { second.finalize_binding! }
    end
    assert_predicate first.reload, :binding_effective?
    assert_not_predicate second.reload, :binding_effective?
    assert_equal 1, ClientTelephone.effective_binding.where(user_id: owner.id).count
    first.release_binding!
    second.finalize_binding!

    assert_predicate first.reload, :binding_released?
    assert_predicate second.reload, :binding_effective?
    assert_equal 1, ClientTelephone.effective_binding.where(user_id: owner.id).count
  end

  # E.164 normalization tests
  test "normalizes domestic Japanese number to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "090-1234-5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes number with spaces to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "090 1234 5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes number with parentheses to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "(090)1234-5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes international prefix 00 to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "0081 90 1234 5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "normalizes international prefix 010 to E.164 format" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "010 81 90 1234 5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "removes domestic 0 after country code from international prefix" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "0081(0)90-1234-5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "preserves already E.164 formatted number" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+819012345678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  # E.164 validation error tests
  test "rejects number without leading 0 or + (ambiguous domestic)" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "9012345678"))

    assert_not user_telephone.valid?
    assert_includes user_telephone.errors[:number], I18n.t("activerecord.errors.messages.invalid_e164_format")
  end

  test "rejects number with country code starting with 0" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+0123456789"))

    assert_not user_telephone.valid?
    expected_error = I18n.t("activerecord.errors.messages.country_code_cannot_start_with_zero")

    assert_includes user_telephone.errors[:number], expected_error
  end

  test "rejects number exceeding E.164 maximum length" do
    # E.164 allows max 15 digits (excluding +)
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+1234567890123456")) # 16 digits

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "rejects number with only formatting characters" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "(---)"))

    assert_not user_telephone.valid?
    assert_predicate user_telephone.errors[:number], :any?
  end

  test "accepts maximum length E.164 number" do
    # E.164 max: +[15 digits]
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "+999999999999999"))

    assert_predicate user_telephone, :valid?
    assert_equal "+999999999999999", user_telephone.number
  end

  test "handles full-width characters in normalization" do
    user_telephone = ClientTelephone.new(@valid_attributes.merge(raw_number: "（090）1234　5678"))

    assert_predicate user_telephone, :valid?
    assert_equal "+819012345678", user_telephone.number
  end

  test "effective telephone numbers are unique at finalization" do
    # Create first telephone
    ClientTelephone.create!(@valid_attributes.merge(raw_number: "+819012345678")).finalize_binding!

    # Try to create with same number but different formatting
    duplicate = ClientTelephone.create!(@valid_attributes.merge(raw_number: "090-1234-5678"))

    assert_predicate duplicate, :valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.finalize_binding! }
  end

  test "sets number_digest from normalized input" do
    user_telephone = ClientTelephone.create!(
      raw_number: "090-1234-5678",
      confirm_policy: true,
      confirm_using_mfa: true,
      user: @user,
    )

    expected = IdentifierBlindIndex.bidx_for_telephone("+819012345678", realm: :app)

    assert_equal expected, user_telephone.number_digest
  end

  test "ceremony OTP is deliverable immediately below but not at or above its finite expiry" do
    user_telephone = ClientTelephone.create!(@valid_attributes.merge(raw_number: "+819012345600"))
    now = ClientTelephoneCeremonyTransaction.database_now
    ceremony = ClientTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: @user.public_id, session_ref: "client-telephone-model-browser", operation: "registration",
      telephone_candidate_ref: user_telephone.public_id, normalized_number_digest: user_telephone.number_digest,
      now: now, expires_at: now + 30.seconds,
    )
    ClientTelephoneCeremonyTransaction.stub(:database_now, now) do
      ceremony.issue_telephone_otp!(purpose: "credential_registration")
    end

    [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
      assert_equal offset.negative?, ceremony.reload.telephone_otp_deliverable?(
        generation: ceremony.otp_generation, at: now + 30.seconds + offset,
      )
    end
  end

  test "fifth failed otp attempt locks but fourth does not" do
    user_telephone = ClientTelephone.create!(@valid_attributes.merge(raw_number: "+819012345601"))
    now = Time.zone.parse("2026-05-25 12:00:00")

    ClientTelephone.stub(:database_now, now) do
      user_telephone.update!(otp_attempts_count: 3, otp_last_sent_at: now)
      user_telephone.increment_attempts!

      assert_equal 4, user_telephone.otp_attempts_count
      assert_not user_telephone.locked?

      user_telephone.increment_attempts!

      assert_equal 5, user_telephone.otp_attempts_count
      assert_predicate user_telephone, :locked?
      assert_in_delta (now + 15.minutes).to_i, user_telephone.locked_at.to_i, 1
    end
  end

  [-1, 0, 1].each do |microseconds|
    test "telephone failures survive fifteen minute issuance age boundary #{microseconds} microseconds" do
      user_telephone = ClientTelephone.create!(@valid_attributes.merge(raw_number: "+819012345602"))
      now = Time.zone.parse("2026-05-25 12:00:00")

      ClientTelephone.stub(:database_now, now) do
        user_telephone.update!(
          otp_attempts_count: TelephoneOtpPolicy::MAX_OTP_ATTEMPTS - 1,
          otp_last_sent_at: now - TelephoneOtpPolicy::OTP_ATTEMPT_WINDOW - Rational(microseconds, 1_000_000),
        )
        user_telephone.increment_attempts!

        assert_equal TelephoneOtpPolicy::MAX_OTP_ATTEMPTS, user_telephone.otp_attempts_count
        assert_predicate user_telephone, :locked?
      end
    end
  end

  test "concurrent creates for same normalized number commit at most one active telephone" do
    number = "+1555#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}"
    results = create_telephones_concurrently(number, number)

    begin
      fv5021 = results
      fv5019 = IdentifierBlindIndex.bidx_for_telephone(
        number,
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
                   ClientTelephone.where(number_digest: fv5019).where(binding_finalized_at: nil).count
    end
  end

  test "concurrent creates for equivalent formatted number commit at most one active telephone" do
    suffix = SecureRandom.random_number(10_000).to_s.rjust(4, "0")
    formatted = "+1 (555) 777-#{suffix}"
    normalized = "+1555777#{suffix}"
    results = create_telephones_concurrently(formatted, normalized)

    begin
      fv5018 = results
      fv5016 = IdentifierBlindIndex.bidx_for_telephone(
        normalized,
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
                   ClientTelephone.where(number_digest: fv5016).where(binding_finalized_at: nil).count
    end
  end

  test "concurrent finalization for one destination leaves one effective telephone binding" do
    number = "+1555#{SecureRandom.random_number(10_000_000).to_s.rjust(7, "0")}"
    first = create_telephone_record(number)
    second = create_telephone_record(number)

    results =
      begin
        fv5015 = first
        fv5014 = second
        track_telephone_race_number(fv5015.number)
        track_telephone_race_number(fv5014.number)
        fv5011 = Queue.new
        fv5010 = Queue.new
        fv5008 = Queue.new
        ActiveRecord::Base.connection_handler.clear_active_connections!

        fv5009 =
          [fv5015.id, fv5014.id].map do |fv5012|
            Thread.new do
              ClientTelephone.connection_pool.with_connection do |fv5013|
                configure_identifier_race_connection!(fv5013)
                fv5011 << true
                fv5010.pop
                ClientTelephone.find(fv5012).finalize_binding!
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
    assert_equal 1, ClientTelephone.effective_binding.where(number_digest: first.number_digest).count
  end

  test "concurrent finalization for one client leaves one effective telephone binding" do
    first = ClientTelephone.create!(
      @valid_attributes.merge(
        raw_number: "+1555123#{SecureRandom.random_number(1000).to_s.rjust(
          3, "0",
        )}",
      ),
    )
    second = ClientTelephone.create!(
      @valid_attributes.merge(
        raw_number: "+1555456#{SecureRandom.random_number(1000).to_s.rjust(
          3, "0",
        )}",
      ),
    )

    results =
      begin
        fv5007 = first
        fv5006 = second
        track_telephone_race_number(fv5007.number)
        track_telephone_race_number(fv5006.number)
        fv5003 = Queue.new
        fv5002 = Queue.new
        fv5000 = Queue.new
        ActiveRecord::Base.connection_handler.clear_active_connections!

        fv5001 =
          [fv5007.id, fv5006.id].map do |fv5004|
            Thread.new do
              ClientTelephone.connection_pool.with_connection do |fv5005|
                configure_identifier_race_connection!(fv5005)
                fv5003 << true
                fv5002.pop
                ClientTelephone.find(fv5004).finalize_binding!
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
    assert_equal 1, ClientTelephone.effective_binding.where(user_id: @user.id).count
  end

  test "released telephone binding can be reattached without reactivating its history" do
    original = ClientTelephone.create!(@valid_attributes).finalize_binding!
    original.release_binding!
    replacement = ClientTelephone.create!(@valid_attributes.merge(raw_number: original.number))

    replacement.finalize_binding!

    assert_not_predicate original.reload, :binding_effective?
    assert_predicate replacement.reload, :binding_effective?
  end

  test "active delete transaction versus same number create keeps active telephone invariant" do
    number = "+1555888#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}"
    track_telephone_race_number(number)
    existing = ClientTelephone.create!(@valid_attributes.merge(raw_number: number))

    ready = Queue.new
    release = Queue.new
    results = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    updater =
      Thread.new do
        ClientTelephone.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ClientTelephone.transaction do
            locked = ClientTelephone.lock.find(existing.id)
            ready << true
            release.pop
            locked.update!(
              user_telephone_status_id: ClientTelephoneStatus::DELETED,
              discard_at: Time.current,
            )
          end
          results << { status: :deleted }
        rescue StandardError => e
          results << { status: :error, error: "#{e.class}: #{e.message}" }
        end
      end
    creator =
      Thread.new do
        ClientTelephone.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ready.pop
          release << true
          create_telephone_record(number)
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
    assert_operator active_telephone_digest_count(number), :<=, 1
  end

  test "rolled back concurrent telephone conflict leaves one active telephone" do
    number = "+1555999#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}"
    digest = IdentifierBlindIndex.bidx_for_telephone(number, realm: :app)
    track_telephone_race_number(number)

    ClientTelephone.transaction do
      create_telephone_record(number)

      assert_equal 1, ClientTelephone.where(number_digest: digest).count
      raise ActiveRecord::Rollback
    end

    assert_nothing_raised do
      create_telephone_record(number)
    end

    assert_operator ClientTelephone
      .where(number_digest: digest)
      .where.not(user_telephone_status_id: ClientTelephoneStatus::DELETED)
      .count,
                    :<=,
                    1
  end

  test "concurrent telephone create while competing insert rolls back does not commit duplicates" do
    number = "+1555666#{SecureRandom.random_number(10_000).to_s.rjust(4, "0")}"
    digest = IdentifierBlindIndex.bidx_for_telephone(number, realm: :app)
    track_telephone_race_number(number)
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    holder =
      Thread.new do
        ClientTelephone.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ClientTelephone.transaction do
            create_telephone_record(number)
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
      create_telephone_record(number)
    end
    assert_operator ClientTelephone
      .where(number_digest: digest)
      .where.not(user_telephone_status_id: ClientTelephoneStatus::DELETED)
      .count,
                    :<=,
                    1
  end

  test "public_id is a fixed 21-character NanoID" do
    assert_public_id_fixed_length(::ClientTelephone)
  end

  private

  def create_telephones_concurrently(first_number, second_number)
    track_telephone_race_number(first_number)
    track_telephone_race_number(second_number)
    ready = Queue.new
    release = Queue.new
    results = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    [first_number, second_number].map do |number|
      Thread.new do
        ClientTelephone.connection_pool.with_connection do |connection|
          configure_identifier_race_connection!(connection)
          ready << true
          release.pop
          record = create_telephone_record(number)
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

  def create_telephone_record(number)
    client = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE,
      visibility_id: ClientVisibility::USER,
    )
    @identifier_race_client_ids << client.id

    ClientTelephone.create!(
      raw_number: number,
      confirm_policy: true,
      confirm_using_mfa: true,
      user: client,
    )
  end

  def track_telephone_race_number(number)
    @identifier_race_digests << IdentifierBlindIndex.bidx_for_telephone(number, realm: :app)
    @identifier_race_digests.uniq!
  end

  def configure_identifier_race_connection!(connection)
    connection.execute("SET lock_timeout = '2000ms'")
  end

  def active_telephone_digest_count(number)
    ClientTelephone.effective_binding.where(
      number_digest: IdentifierBlindIndex.bidx_for_telephone(number, realm: :app),
    ).count
  end
end
