# typed: false
# frozen_string_literal: true

module IdentityCeremonyCandidateRecord
  extend ActiveSupport::Concern

  class << self
    public

    # Candidate references are self-controlled opaque identifiers. The database unique index is
    # authoritative; only a collision on that named ref index may receive a bounded fresh value.
    def create_with_generated_ref(candidate_class, attributes)
      retries = 0

      loop do
        begin
          candidate = candidate_class.new(attributes.merge(ref: PublicId.generate))
          raise ActiveRecord::RecordInvalid.new(candidate) unless candidate.valid? || ref_taken_only?(candidate)

          return candidate.tap { |record| record.save!(validate: false) }
        rescue ActiveRecord::RecordNotUnique => e
          raise unless ref_unique_constraint_names(candidate_class).include?(postgres_constraint_name(e))

          retries += 1
          raise if retries > PublicId::MAX_COLLISION_RETRIES
        end
      end
    end

    private

    def ref_unique_constraint_names(candidate_class)
      candidate_class.lease_connection.schema_cache.indexes(candidate_class.table_name).filter_map do |index|
        index.name if index.unique && index.where.nil? && index.columns == ["ref"]
      end
    end

    def postgres_constraint_name(error)
      result = error.cause&.result
      return unless result

      result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end

    def ref_taken_only?(candidate)
      details = candidate.errors.details
      details.keys == [:ref] && details.fetch(:ref).all? { |detail| detail.fetch(:error) == :taken }
    end
  end

  # FIXME: Violates Umaxica/NoConcernInclusionHooks; move the declarations in this block into each class that includes this concern.
  included do
    scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time), consumed_at: nil) }

    validates :ref, :digest, :surface, :actor_ref, :session_ref, :expires_at, presence: true
    validates :ref, uniqueness: true
  end

  class_methods do
    def connection_owner
      return OpBaseAppRecord if self <= OpBaseAppRecord
      return OpBaseComRecord if self <= OpBaseComRecord
      return OpBaseOrgRecord if self <= OpBaseOrgRecord

      raise ArgumentError, "unsupported ceremony candidate database: #{name}"
    end

    def find_active_by_ref!(ref, now:, error_class:, not_found_message:, expired_message:)
      connection_owner.connected_to(role: :writing) do
        record = find_by(ref: ref.to_s)
        raise error_class, not_found_message if record.blank? || record.consumed_at.present?
        raise error_class, expired_message if record.expires_at <= now

        record
      end
    end
  end

  def consume!(now:, error_class:, not_found_message:, expired_message:)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find_by(ref: ref)
        raise error_class, not_found_message if locked.blank? || locked.consumed_at.present?
        raise error_class, expired_message if locked.expires_at <= now

        locked.update!(consumed_at: now)
        locked
      end
    end
  end

  public

  def expire!
    self.class.connection_owner.connected_to(role: :writing) do
      with_lock do
        now = self.class.database_now
        update!(expires_at: now) if expires_at > now
        self
      end
    end
  end
end
