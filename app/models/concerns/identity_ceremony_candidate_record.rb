# typed: false
# frozen_string_literal: true

module IdentityCeremonyCandidateRecord
  extend ActiveSupport::Concern

  included do
    scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time), consumed_at: nil) }

    validates :ref, :digest, :surface, :actor_ref, :session_ref, :expires_at, presence: true
    validates :ref, uniqueness: true
  end

  class_methods do
    def connection_owner
      return AppTicketRecord if self <= AppTicketRecord
      return ComTicketRecord if self <= ComTicketRecord
      return OrgTicketRecord if self <= OrgTicketRecord

      raise ArgumentError, "unsupported ceremony candidate database: #{name}"
    end

    def find_active_by_ref!(ref, now:, error_class:, not_found_message:, expired_message:)
      connection_owner.connected_to(role: :writing) do
        record = find_by(ref: ref.to_s)
        raise error_class, not_found_message if record.blank? || record.consumed_at.present?
        raise error_class, expired_message if record.expires_at.to_i <= now.to_i

        record
      end
    end
  end

  def consume!(now:, error_class:, not_found_message:, expired_message:)
    self.class.connection_owner.connected_to(role: :writing) do
      self.class.transaction do
        locked = self.class.lock.find_by(ref: ref)
        raise error_class, not_found_message if locked.blank? || locked.consumed_at.present?
        raise error_class, expired_message if locked.expires_at.to_i <= now.to_i

        locked.update!(consumed_at: now)
        locked
      end
    end
  end
end
