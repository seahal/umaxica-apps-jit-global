# frozen_string_literal: true

class ClientIdentifierRotationAudit < AppZenithRecord
  validates :operation_ref, :channel, :record_id, :actor_role, :occurred_at, presence: true
  validates :channel, inclusion: { in: %w(email telephone) }
  validates :record_id, numericality: { only_integer: true, greater_than: 0 }
  before_update :reject_audit_update

  private

  def reject_audit_update
    raise ActiveRecord::ReadOnlyRecord, "identifier rotation audit is append-only"
  end
end
