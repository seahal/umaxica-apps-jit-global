# typed: false
# frozen_string_literal: true

module PasskeyCeremonyTransactionable
  extend ActiveSupport::Concern

  DEFAULT_TTL = 10.minutes
  STATUS_PENDING = "pending"
  STATUS_CONSUMED = "consumed"
  STATUSES = [STATUS_PENDING, STATUS_CONSUMED].freeze
  RETENTION_PERIOD = 7.days

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
              :rp_id, :origin,
              presence: true
    validates :transaction_id, uniqueness: true
    validates :grant_jti, uniqueness: true
    validates :result_jti, uniqueness: true, allow_nil: true
    validates :surface, inclusion: { in: IdentityPasskeyCeremonyContract::SURFACES }
    validates :operation, inclusion: { in: IdentityPasskeyCeremonyContract::OPERATIONS }
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
                            grant_jti: nil, credential_candidate_ref: nil, credential_candidate_digest: nil,
                            expires_at: nil, now: Time.current)
      transaction_id = transaction_id.presence
      grant_jti = grant_jti.presence
      generated_attributes = []
      generated_attributes << :transaction_id if transaction_id.nil?
      generated_attributes << :grant_jti if grant_jti.nil?
      retries = 0
      relying_party_config = Webauthn::RelyingPartyConfigResolver.resolve(surface.to_sym)

      connection_owner.connected_to(role: :writing) do
        loop do
          generated_transaction_id = transaction_id || PublicId.generate
          generated_grant_jti = grant_jti || PublicId.generate
          attributes = passkey_transaction_attributes(
            transaction_id: generated_transaction_id, surface: surface, rp_id: relying_party_config.rp_id,
            origin: relying_party_config.origin, actor_ref: actor_ref, session_ref: session_ref,
            operation: operation, grant_jti: generated_grant_jti,
            credential_candidate_ref: credential_candidate_ref,
            credential_candidate_digest: credential_candidate_digest, expires_at: expires_at, now: now,
          )

          begin
            return transaction(requires_new: true) { create!(attributes) }
          rescue ActiveRecord::RecordInvalid => e
            raise unless generated_reference_collision_validation?(e, generated_attributes)
          rescue ActiveRecord::RecordNotUnique => e
            raise unless generated_reference_collision?(e, generated_attributes)
          end

          retries += 1
          raise if retries > PublicId::MAX_COLLISION_RETRIES
        end
      end
    end

    def connection_owner
      if self <= OpBaseAppRecord
        OpBaseAppRecord
      elsif self <= OpBaseOrgRecord
        OpBaseOrgRecord
      elsif self <= OpBaseComRecord
        OpBaseComRecord
      else
        ActiveRecord::Base
      end
    end

    private

    def passkey_transaction_attributes(transaction_id:, surface:, rp_id:, origin:, actor_ref:, session_ref:,
                                       operation:, grant_jti:, credential_candidate_ref:,
                                       credential_candidate_digest:, expires_at:, now:)
      {
        transaction_id: transaction_id,
        surface: surface.to_s,
        rp_id: rp_id,
        origin: origin,
        actor_ref: actor_ref,
        session_ref: session_ref,
        operation: operation,
        grant_jti: grant_jti,
        credential_candidate_ref: credential_candidate_ref,
        credential_candidate_digest: credential_candidate_digest,
        expires_at: expires_at || (now + DEFAULT_TTL),
        created_at: now,
        updated_at: now,
      }
    end

    def generated_reference_collision_validation?(error, generated_attributes)
      generated_attributes.any? { |attribute| error.record.errors.of_kind?(attribute, :taken) }
    end

    def generated_reference_collision?(error, generated_attributes)
      result = error.cause&.result
      return false unless result

      constraint = result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
      lease_connection.schema_cache.indexes(table_name).any? do |index|
        index.name == constraint && index.unique && index.where.nil? && index.columns.one? &&
          generated_attributes.include?(index.columns.first.to_sym)
      end
    end
  end

  def grant_claims(now: Time.current)
    {
      "surface" => surface,
      "rp_id" => rp_id,
      "origin" => origin,
      "actor_ref" => actor_ref,
      "session_ref" => session_ref,
      "transaction_id" => transaction_id,
      "jti" => grant_jti,
      "operation" => operation,
      "credential_candidate_ref" => credential_candidate_ref,
      "credential_candidate_digest" => credential_candidate_digest,
      "exp" => expires_at.to_i,
      "iat" => now.to_i,
    }.compact
  end

  def expired?(now: Time.current)
    expires_at.to_i <= now.to_i
  end

  def consumed? = status == STATUS_CONSUMED

  def consume_result!(result_jti:, consumed_at: Time.current)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find(id)
        raise IdentityPasskeyCeremonyContract::Error, "transaction is already consumed" if locked.consumed?
        raise IdentityPasskeyCeremonyContract::Error, "transaction is expired" if locked.expired?(now: consumed_at)

        locked.update!(result_jti: result_jti, consumed_at: consumed_at, status: STATUS_CONSUMED)
        locked
      end
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    raise IdentityPasskeyCeremonyContract::Error, "result_jti has already been consumed: #{e.message}"
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
