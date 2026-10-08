# typed: false
# frozen_string_literal: true

module EmailCeremonyTransactionable
  extend ActiveSupport::Concern

  include EmailVerificationChallengeable

  DEFAULT_TTL = 10.minutes
  STATUS_PENDING = "pending"
  STATUS_CONSUMED = "consumed"
  STATUSES = [STATUS_PENDING, STATUS_CONSUMED].freeze
  RETENTION_PERIOD = 7.days
  OPERATIONS = %w(registration replacement sign_up sign_in recovery withdrawal credential_registration).freeze

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    class_attribute :ceremony_surface_name, instance_accessor: false
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    scope :expired_at, ->(time) { where(arel_table[:expires_at].lteq(time)) }
    scope :consumed, -> { where.not(consumed_at: nil).or(where(status: STATUS_CONSUMED)) }
    scope :active_at, ->(time) {
      where(arel_table[:expires_at].gt(time)).where(consumed_at: nil, status: STATUS_PENDING)
    }
    scope :pending, -> { where(status: STATUS_PENDING, consumed_at: nil) }
    scope :purgeable_at, lambda { |time, retention_period: RETENTION_PERIOD|
      cutoff = time - retention_period
      where(arel_table[:expires_at].lteq(cutoff))
        .or(where(arel_table[:consumed_at].lteq(cutoff)))
    }

    validates :transaction_id, :surface, :actor_ref, :session_ref, :operation, :status, :grant_jti, :expires_at,
              presence: true
    validates :transaction_id, uniqueness: true
    validates :grant_jti, uniqueness: true
    validates :result_jti, uniqueness: true, allow_nil: true
    validates :surface, inclusion: { in: IdentityEmailCeremonyContract::SURFACES }
    validates :operation, inclusion: { in: OPERATIONS }
    validates :status, inclusion: { in: STATUSES }
    validate :surface_matches_transaction_class
    validate :consumed_transaction_has_result
  end

  class_methods do
    def ceremony_surface(value = nil)
      self.ceremony_surface_name = value.to_s if value
      ceremony_surface_name
    end

    def create_transaction!(surface: ceremony_surface, actor_ref:, session_ref:, operation:, transaction_id: nil,
                            grant_jti: nil, email_candidate_ref: nil, normalized_email_digest: nil,
                            expires_at: nil, now: Time.current, evp_nonce_digest: nil, evp_outcome: nil)
      connection_owner.connected_to(role: :writing) do
        create!(
          transaction_id: transaction_id.presence || SecureRandom.uuid,
          surface: surface.to_s,
          actor_ref: actor_ref,
          session_ref: session_ref,
          operation: operation,
          grant_jti: grant_jti.presence || SecureRandom.uuid,
          email_candidate_ref: email_candidate_ref,
          normalized_email_digest: normalized_email_digest,
          evp_nonce_digest: evp_nonce_digest,
          evp_outcome: evp_outcome,
          expires_at: expires_at || (now + DEFAULT_TTL),
          created_at: now,
          updated_at: now,
        )
      end
    end

    def connection_owner
      if self <= AppTicketRecord
        AppTicketRecord
      elsif self <= OrgTicketRecord
        OrgTicketRecord
      elsif self <= ComTicketRecord
        ComTicketRecord
      else
        ActiveRecord::Base
      end
    end
  end

  public

  def grant_claims(now: Time.current)
    {
      "surface" => surface,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction_id,
      "jti" => grant_jti,
      "operation" => operation,
      "email_candidate_ref" => email_candidate_ref,
      "normalized_email_digest" => normalized_email_digest,
      "exp" => expires_at.to_i,
      "iat" => now.to_i,
    }.compact
  end

  def expired?(now: Time.current)
    expires_at.to_i <= now.to_i
  end

  def consumed? = status == STATUS_CONSUMED

  def consume_registration_result!
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        unless operation == "registration" && status == STATUS_PENDING && !consumed_at && expires_at > now
          raise IdentityEmailCeremonyContract::Error, "registration receipt is unavailable"
        end

        update!(result_jti: SecureRandom.uuid, consumed_at: now, status: STATUS_CONSUMED)
        self
      end
    end
  end

  def consume_result!(result_jti:, consumed_at: Time.current)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        raise IdentityEmailCeremonyContract::Error, "transaction is already consumed" if locked.consumed?
        raise IdentityEmailCeremonyContract::Error, "transaction is expired" if locked.expired?(now: consumed_at)

        locked.update!(result_jti: result_jti, consumed_at: consumed_at, status: STATUS_CONSUMED)
        locked
      end
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    raise IdentityEmailCeremonyContract::Error, "result_jti has already been consumed: #{e.message}"
  end

  private

  def surface_matches_transaction_class
    return if self.class.ceremony_surface.blank? || surface == self.class.ceremony_surface

    errors.add(:surface, "does not match transaction store")
  end

  def consumed_transaction_has_result
    return unless status == STATUS_CONSUMED && result_jti.blank?

    errors.add(:result_jti, "is required for consumed transaction")
  end
end
