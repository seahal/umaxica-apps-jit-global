# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: logout_transactions
#
#  id            :bigint           not null, primary key
#  audience      :string           not null
#  consumed_at   :datetime
#  created_at    :datetime         not null
#  expires_at    :datetime         not null
#  failed_at     :datetime
#  failure_code  :string
#  issuer        :string           not null
#  lock_version  :integer          default(0), not null
#  public_id     :string           not null
#  purpose       :string           not null
#  revoked_at    :datetime
#  token_digest  :binary           not null
#  updated_at    :datetime         not null
#
class LogoutTransaction < AppTicketRecord
  include OneTimeUrlTokenShared

  MAX_PUBLIC_ID_COLLISION_RETRIES = PublicId::MAX_COLLISION_RETRIES
  PUBLIC_ID_UNIQUE_INDEX = "index_logout_transactions_on_public_id"

  Result = Data.define(:status)

  validates :public_id, :token_digest, :issuer, :audience, :purpose, :expires_at, presence: true
  validates :public_id, :token_digest, uniqueness: true
  validate :public_id_immutable_after_create, on: :update

  def self.issue!(issuer:, audience:, purpose:, expires_in: 2.minutes, now: Time.current)
    retries = 0

    begin
      transaction(requires_new: true) do
        public_id = PublicId.generate
        raw_token, verifier = generate_one_time_url_token(public_id: public_id)
        transaction_record = create!(
          public_id: public_id,
          issuer: issuer.to_s,
          audience: audience.to_s,
          purpose: purpose.to_s,
          expires_at: now + expires_in,
          token_digest: digest_one_time_url_verifier(verifier),
        )
        [transaction_record, raw_token]
      end
    rescue ActiveRecord::RecordInvalid => e
      raise unless public_id_collision_validation?(e)

      retries += 1
      raise if retries > MAX_PUBLIC_ID_COLLISION_RETRIES

      retry
    rescue ActiveRecord::RecordNotUnique => e
      raise unless public_id_collision?(e)

      retries += 1
      raise if retries > MAX_PUBLIC_ID_COLLISION_RETRIES

      retry
    end
  end

  def self.consume_one_time_url_token!(raw_token:, issuer:, audience:, purpose:, now: Time.current)
    parsed = parse_one_time_url_token(raw_token)
    return Result.new(:invalid) unless parsed

    public_id, verifier = parsed
    transaction = find_by(public_id: public_id)
    return Result.new(:invalid) unless transaction

    transaction.consume!(verifier: verifier, issuer: issuer, audience: audience, purpose: purpose, now: now)
  rescue ActiveRecord::RecordNotFound
    Result.new(:invalid)
  end

  def expired?(now: Time.current)
    expires_at <= now
  end

  def revoked?
    revoked_at.present?
  end

  def consumed?
    consumed_at.present?
  end

  def valid_for_consumption?(now: Time.current, issuer:, audience:, purpose:)
    return false unless issuer == self.issuer
    return false unless audience == self.audience
    return false unless purpose == self.purpose
    return false if revoked?
    return false if expired?(now: now)

    true
  end

  def token_digest_matches?(verifier)
    return false if verifier.blank? || token_digest.blank?

    secure_compare?(token_digest, digest_one_time_url_verifier(verifier))
  end

  def consume!(verifier:, issuer:, audience:, purpose:, now: Time.current)
    with_lock do
      return consumption_result(:invalid) unless valid_for_consumption?(
        now: now, issuer: issuer, audience: audience,
        purpose: purpose,
      )
      return consumption_result(:invalid) unless token_digest_matches?(verifier)
      return consumption_result(:consumed) if consumed?

      update!(consumed_at: now)
      consumption_result(:consumed_now)
    end
  rescue ActiveRecord::StaleObjectError
    reload
    consumed? ? consumption_result(:consumed) : consumption_result(:invalid)
  end

  def revoke!(now: Time.current, failure_code: nil)
    update!(revoked_at: now, failed_at: now, failure_code: failure_code)
  end

  private

  def public_id_immutable_after_create
    return unless persisted? && will_save_change_to_public_id?

    errors.add(:public_id, "cannot be changed after creation")
  end
  private :public_id_immutable_after_create

  def self.public_id_collision_validation?(error)
    error.record.errors.of_kind?(:public_id, :taken)
  end
  private_class_method :public_id_collision_validation?

  def self.public_id_collision?(error)
    result = error.cause&.result
    return false unless result

    result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == PUBLIC_ID_UNIQUE_INDEX
  end
  private_class_method :public_id_collision?

  def consumption_result(status)
    Result.new(status)
  end
end
