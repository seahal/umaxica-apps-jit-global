# typed: false
# frozen_string_literal: true

module SignFlow
  extend ActiveSupport::Concern

  included do
    include ::PublicId
    include ::Retainable

    self.belongs_to_required_by_default = false

    attribute :issued_at, :datetime, default: -> { Time.current }
    attribute :expires_at, :datetime, default: -> { default_ttl.from_now }

    validates :nonce_digest, presence: true
    validates :issued_at, :expires_at, presence: true
    validate :expires_after_issued_at

    scope :recent_first, -> { order(created_at: :desc) }
    scope :current,
          -> do
            where(arel_table[:discard_at].gt(Time.current))
              .where(arel_table[:expires_at].gt(Time.current))
          end
  end

  class_methods do
    def digest_nonce(nonce)
      OpenSSL::Digest::SHA256.hexdigest(nonce.to_s)
    end

    def default_ttl
      15.minutes
    end
  end

  def default_expires_at
    self.class.default_ttl.from_now
  end

  # True only when the auth-flow TTL has lapsed. Distinct from `lapsed?`
  # (logical deletion) which Retainable owns; the two used to be merged here
  # but conflating them made callers reject events on rows that were merely
  # discarded for audit hold. State-machine code that wants the union should
  # check `expired? || lapsed?` explicitly.
  def expired?(now = Time.current)
    expires_at.present? && expires_at <= now
  end

  def nonce_matches?(nonce)
    return false if nonce.blank? || nonce_digest.blank?

    ActiveSupport::SecurityUtils.secure_compare(nonce_digest, self.class.digest_nonce(nonce))
  end

  def discard!(now: Time.current)
    update!(discard_at: now)
  end

  private

  def expires_after_issued_at
    return if issued_at.blank? || expires_at.blank?
    return if issued_at < expires_at

    errors.add(:expires_at, "must be after issued_at")
  end
end
