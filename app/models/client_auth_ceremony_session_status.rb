# frozen_string_literal: true

class ClientAuthCeremonySessionStatus < OpBaseAppRecord
  include ReferenceRecord

  ISSUED = AuthCeremonySession::STATUS_ISSUED
  ADMITTED = AuthCeremonySession::STATUS_ADMITTED
  EVIDENCE_RECORDED = AuthCeremonySession::STATUS_EVIDENCE_RECORDED
  REPLACED = AuthCeremonySession::STATUS_REPLACED
  REVOKED = AuthCeremonySession::STATUS_REVOKED
  COMPLETED = AuthCeremonySession::STATUS_COMPLETED
  CANCELLED_BEFORE_PROGRESS = AuthCeremonySession::STATUS_CANCELLED_BEFORE_PROGRESS
  CANCELLED_AFTER_PROGRESS = AuthCeremonySession::STATUS_CANCELLED_AFTER_PROGRESS

  DEFAULTS = AuthCeremonySession::STATUS_IDS

  has_many :client_auth_ceremony_sessions,
           class_name: "ClientAuthCeremonySession",
           foreign_key: :status_id,
           inverse_of: :status,
           dependent: :restrict_with_error
end
